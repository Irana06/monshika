import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/google_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../core/widgets/ui_kit.dart';
import '../../providers/providers.dart';
import '../../services/backup_service.dart';
import '../../services/drive_service.dart';
import '../../services/export_service.dart';
import '../../services/security_service.dart';
import '../common/pickers.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key, this.fromOnboarding = false});

  final bool fromOnboarding;

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;
  String? _busyLabel;
  List<DriveBackupFile>? _driveFiles;
  bool _hasPassword = false;
  String _rangeKey = 'this_month';
  DateRange? _custom;

  @override
  void initState() {
    super.initState();
    SecurityService.instance.getBackupPassword().then((p) {
      if (mounted) setState(() => _hasPassword = p != null);
    });
    if (GoogleConfig.isConfigured && ref.read(settingsProvider).driveEmail != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadDrive(interactive: false));
    }
  }

  Future<void> _run(String label, Future<void> Function() job) async {
    setState(() {
      _busy = true;
      _busyLabel = label;
    });
    try {
      await job();
    } on DriveNotConfigured catch (e) {
      if (mounted) showSnack(context, e.toString());
    } catch (e) {
      if (mounted) showSnack(context, 'Gagal: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyLabel = null;
        });
      }
    }
  }

  Future<void> _loadDrive({bool interactive = true}) async {
    try {
      final files = await DriveService.instance.list(interactive: interactive);
      if (mounted) setState(() => _driveFiles = files);
    } catch (e) {
      if (interactive && mounted) showSnack(context, 'Tidak bisa membaca Google Drive: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Restore
  // ---------------------------------------------------------------------------

  Future<String?> _askPassword({String title = 'Sandi backup'}) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, obscureText: true, autofocus: true, decoration: const InputDecoration(hintText: 'Sandi')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _restoreBytes(Uint8List bytes) async {
    Map<String, dynamic> json;
    String? password;
    if (BackupService.isEncrypted(bytes)) {
      password = await SecurityService.instance.getBackupPassword();
    }
    while (true) {
      try {
        json = await BackupService.read(bytes, password: password);
        break;
      } on BackupPasswordRequired {
        password = await _askPassword(title: 'Backup terenkripsi — masukkan sandi');
        if (password == null) return;
      } on BackupWrongPassword {
        password = await _askPassword(title: 'Sandi salah, coba lagi');
        if (password == null) return;
      }
    }
    final info = BackupService.info(json);
    if (!mounted) return;
    final ok = await confirmDialog(
      context,
      title: 'Pulihkan backup?',
      message: 'Backup ${DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(info.createdAt)} berisi ${info.accounts} dompet '
          'dan ${info.transactions} transaksi.\n\nSemua data di HP ini akan DIGANTI dengan isi backup.',
      confirm: 'Pulihkan',
    );
    if (!ok) return;
    final db = ref.read(databaseProvider);
    await BackupService.restore(db, json);
    db.refreshAllStreams();
    await ref.read(settingsProvider.notifier).reload();
    if (!mounted) return;
    await showHanko(context, glyph: '復', label: 'Data dipulihkan');
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _share(Uint8List bytes, String name, String mime) async {
    await SharePlus.instance.share(ShareParams(files: [XFile.fromData(bytes, mimeType: mime)], fileNameOverrides: [name]));
  }

  Future<void> _deliver(Uint8List bytes, String name, String mime, {bool printable = false}) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.save_alt), title: const Text('Simpan ke perangkat'), onTap: () => Navigator.pop(ctx, 'save')),
          ListTile(leading: const Icon(Icons.share), title: const Text('Bagikan (WhatsApp, email, Drive…)'), onTap: () => Navigator.pop(ctx, 'share')),
          if (printable) ListTile(leading: const Icon(Icons.print), title: const Text('Pratinjau / cetak'), onTap: () => Navigator.pop(ctx, 'print')),
        ]),
      ),
    );
    switch (action) {
      case 'save':
        final uri = await FilePicker.saveFile(fileName: name, bytes: bytes, mimeType: mime);
        if (uri != null && mounted) showSnack(context, 'Tersimpan: $name');
      case 'share':
        await _share(bytes, name, mime);
      case 'print':
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
    }
  }

  DateRange _exportRange() {
    final s = ref.read(settingsProvider);
    final now = DateTime.now();
    return switch (_rangeKey) {
      'last_month' => monthRange(now, startDay: s.monthStartDay).shift(-1, 'monthly'),
      'this_year' => yearRange(now),
      'all' => DateRange(DateTime(2000), DateTime(2100)),
      'custom' => _custom ?? monthRange(now, startDay: s.monthStartDay),
      _ => monthRange(now, startDay: s.monthStartDay),
    };
  }

  String _stamp() => DateFormat('yyyyMMdd').format(DateTime.now());

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final db = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(title: Text(widget.fromOnboarding ? 'Pulihkan Data' : 'Backup & Export · 保管')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            children: [
              const SectionHeader(title: 'Google Drive', jp: '雲'),
              if (!GoogleConfig.isConfigured)
                WaCard(
                  child: Text(
                    'Backup Google Drive belum aktif di build ini (Client ID OAuth belum diisi). Gunakan backup file lokal di bawah.',
                    style: AppTheme.sans(size: 13, color: WaColors.washiMuted),
                  ),
                )
              else if (s.driveEmail == null)
                WaCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Simpan backup terenkripsi ke folder tersembunyi khusus Monshika di Google Drive-mu. '
                        'Monshika tidak bisa melihat file lain di Drive.',
                        style: AppTheme.sans(size: 13, color: WaColors.washiMuted)),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.login),
                      label: const Text('Login dengan Google'),
                      onPressed: _busy
                          ? null
                          : () => _run('Menghubungkan…', () async {
                                final acc = await DriveService.instance.signIn();
                                await ref.read(settingsProvider.notifier).setDriveEmail(acc.email);
                                await _loadDrive();
                              }),
                    ),
                  ]),
                )
              else
                WaCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.cloud_done_outlined, color: WaColors.income),
                      const SizedBox(width: 10),
                      Expanded(child: Text(s.driveEmail!, style: AppTheme.sans(weight: FontWeight.w600))),
                      TextButton(
                        onPressed: () async {
                          await DriveService.instance.signOut();
                          await ref.read(settingsProvider.notifier).setDriveEmail(null);
                          await ref.read(settingsProvider.notifier).setAutoBackup('off');
                          setState(() => _driveFiles = null);
                        },
                        child: const Text('Putuskan'),
                      ),
                    ]),
                    Text(
                      s.lastBackupAt == null
                          ? 'Belum pernah backup'
                          : 'Backup terakhir ${DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(s.lastBackupAt!)}',
                      style: AppTheme.sans(size: 12, color: WaColors.washiMuted),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.cloud_upload_outlined),
                          label: const Text('Backup sekarang'),
                          onPressed: _busy
                              ? null
                              : () => _run('Mengunggah backup…', () async {
                                    final bytes = await BackupService.create(db, password: await SecurityService.instance.getBackupPassword());
                                    await DriveService.instance.upload(bytes, BackupService.fileName(), interactive: true);
                                    await ref.read(settingsProvider.notifier).setLastBackupAt(DateTime.now());
                                    await _loadDrive();
                                    if (mounted) await showHanko(context, glyph: '蔵', label: 'Backup tersimpan di Drive');
                                  }),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Backup otomatis'),
                      trailing: DropdownButton<String>(
                        value: s.autoBackup,
                        items: const [
                          DropdownMenuItem(value: 'off', child: Text('Mati')),
                          DropdownMenuItem(value: 'daily', child: Text('Harian')),
                          DropdownMenuItem(value: 'weekly', child: Text('Mingguan')),
                        ],
                        onChanged: (v) => ref.read(settingsProvider.notifier).setAutoBackup(v ?? 'off'),
                      ),
                    ),
                    const Divider(),
                    Row(children: [
                      Text('File di Drive', style: AppTheme.sans(size: 13, weight: FontWeight.w600)),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: () => _run('Memuat…', () => _loadDrive())),
                    ]),
                    if (_driveFiles == null)
                      Text('Ketuk muat ulang untuk melihat daftar backup', style: AppTheme.sans(size: 12, color: WaColors.washiMuted))
                    else if (_driveFiles!.isEmpty)
                      Text('Belum ada backup', style: AppTheme.sans(size: 12, color: WaColors.washiMuted))
                    else
                      for (final f in _driveFiles!)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.inventory_2_outlined),
                          title: Text(DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(f.createdAt.toLocal())),
                          subtitle: Text('${(f.size / 1024).toStringAsFixed(1)} KB'),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'restore') {
                                _run('Mengunduh…', () async => _restoreBytes(await DriveService.instance.download(f.id, interactive: true)));
                              } else {
                                _run('Menghapus…', () async {
                                  await DriveService.instance.delete(f.id);
                                  await _loadDrive();
                                });
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'restore', child: Text('Pulihkan')),
                              PopupMenuItem(value: 'delete', child: Text('Hapus')),
                            ],
                          ),
                        ),
                  ]),
                ),
              const SizedBox(height: 10),
              WaCard(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: SwitchListTile(
                  title: const Text('Enkripsi backup dengan sandi'),
                  subtitle: Text(
                    _hasPassword ? 'AES-256. Simpan sandinya — tanpa sandi backup tidak bisa dibuka.' : 'Backup tidak dienkripsi sandi',
                    style: AppTheme.sans(size: 12, color: WaColors.washiMuted),
                  ),
                  value: _hasPassword,
                  onChanged: (v) async {
                    if (v) {
                      final p = await _askPassword(title: 'Buat sandi backup');
                      if (p == null || p.length < 4) {
                        if (mounted && p != null) showSnack(context, 'Sandi minimal 4 karakter');
                        return;
                      }
                      await SecurityService.instance.setBackupPassword(p);
                    } else {
                      await SecurityService.instance.setBackupPassword(null);
                    }
                    setState(() => _hasPassword = v);
                  },
                ),
              ),
              const SectionHeader(title: 'File lokal', jp: '箱'),
              WaCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(children: [
                  ListTile(
                    leading: const Icon(Icons.save_alt),
                    title: const Text('Buat file backup (.msk)'),
                    subtitle: const Text('Simpan ke perangkat atau bagikan'),
                    onTap: _busy
                        ? null
                        : () => _run('Membuat backup…', () async {
                              final bytes = await BackupService.create(db, password: await SecurityService.instance.getBackupPassword());
                              await _deliver(bytes, BackupService.fileName(), 'application/octet-stream');
                            }),
                  ),
                  ListTile(
                    leading: const Icon(Icons.restore),
                    title: const Text('Pulihkan dari file backup'),
                    onTap: _busy
                        ? null
                        : () => _run('Membaca file…', () async {
                              final file = await FilePicker.pickFile();
                              if (file == null) return;
                              await _restoreBytes(await file.readAsBytes());
                            }),
                  ),
                ]),
              ),
              if (!widget.fromOnboarding) ...[
                const SectionHeader(title: 'Export laporan', jp: '出'),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final e in const {
                    'this_month': 'Bulan ini',
                    'last_month': 'Bulan lalu',
                    'this_year': 'Tahun ini',
                    'all': 'Semua',
                    'custom': 'Pilih tanggal',
                  }.entries)
                    ChoiceChip(
                      label: Text(e.key == 'custom' && _custom != null ? fmtRange(_custom!) : e.value),
                      selected: _rangeKey == e.key,
                      onSelected: (_) async {
                        if (e.key == 'custom') {
                          final r = await showDateRangePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 365)));
                          if (r == null) return;
                          _custom = DateRange(r.start, r.end.add(const Duration(days: 1)));
                        }
                        setState(() => _rangeKey = e.key);
                      },
                    ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.table_rows_outlined),
                      label: const Text('CSV'),
                      onPressed: _busy
                          ? null
                          : () => _run('Membuat CSV…', () async {
                                final bytes = await ExportService(db).csvBytes(_exportRange());
                                await _deliver(bytes, 'monshika-${_stamp()}.csv', 'text/csv');
                              }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.grid_on),
                      label: const Text('Excel'),
                      onPressed: _busy
                          ? null
                          : () => _run('Membuat Excel…', () async {
                                final bytes = await ExportService(db).excelBytes(_exportRange(), baseCurrency: s.baseCurrency, rates: ref.read(ratesProvider));
                                await _deliver(bytes, 'monshika-${_stamp()}.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
                              }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('PDF'),
                      onPressed: _busy
                          ? null
                          : () => _run('Membuat PDF…', () async {
                                final bytes = await ExportService(db).pdfBytes(_exportRange(),
                                    baseCurrency: s.baseCurrency, rates: ref.read(ratesProvider), userName: s.userName);
                                await _deliver(bytes, 'monshika-laporan-${_stamp()}.pdf', 'application/pdf', printable: true);
                              }),
                    ),
                  ),
                ]),
                const SectionHeader(title: 'Import transaksi', jp: '入'),
                WaCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(children: [
                    ListTile(
                      leading: const Icon(Icons.upload_file),
                      title: const Text('Import dari CSV'),
                      subtitle: const Text('Format sama dengan hasil export CSV'),
                      onTap: _busy
                          ? null
                          : () async {
                              final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['csv']);
                              if (file == null || !context.mounted) return;
                              final accountId = await showAccountPicker(context, ref, title: 'Dompet cadangan (jika nama dompet tidak dikenali)');
                              if (accountId == null) return;
                              await _run('Mengimpor…', () async {
                                final n = await ExportService(db).importCsv(await file.readAsBytes(), fallbackAccountId: accountId);
                                if (mounted) showSnack(context, '$n transaksi berhasil diimpor');
                              });
                            },
                    ),
                    ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: const Text('Template CSV'),
                      onTap: () => _share(
                        Uint8List.fromList(utf8.encode('${ExportService.csvHeader.join(',')}\n2026-09-10,12:30,Pengeluaran,Makan & Minum,,Tunai,,25000,IDR,,,Makan siang,Warteg,\n')),
                        'monshika-template.csv',
                        'text/csv',
                      ),
                    ),
                  ]),
                ),
                const SectionHeader(title: 'Zona bahaya', jp: '危'),
                WaCard(
                  borderColor: WaColors.expense.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: const Icon(Icons.delete_forever, color: WaColors.expense),
                    title: const Text('Hapus semua data', style: TextStyle(color: WaColors.expense)),
                    subtitle: const Text('Kategori bawaan akan dibuat ulang'),
                    onTap: () async {
                      final ctrl = TextEditingController();
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Hapus semua data?'),
                          content: Column(mainAxisSize: MainAxisSize.min, children: [
                            const Text('Tindakan ini tidak bisa dibatalkan. Ketik HAPUS untuk melanjutkan.'),
                            const SizedBox(height: 12),
                            TextField(controller: ctrl, autofocus: true),
                          ]),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: WaColors.expense),
                              onPressed: () => Navigator.pop(ctx, ctrl.text.trim().toUpperCase() == 'HAPUS'),
                              child: const Text('Hapus'),
                            ),
                          ],
                        ),
                      );
                      if (ok != true) return;
                      await db.wipeAll();
                      await ref.read(settingsProvider.notifier).setDefaultAccount(null);
                      await ref.read(settingsProvider.notifier).setOnboardingDone(false);
                      if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                    },
                  ),
                ),
              ],
            ],
          ),
          if (_busy)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(_busyLabel ?? 'Memproses…', style: AppTheme.sans()),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
