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
import '../../l10n/strings.dart';
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

  S get _t => S.of(context);

  String _stampLong(DateTime d) => DateFormat('d MMM yyyy, HH:mm', _t.dateLocale).format(d);

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
      if (mounted) showSnack(context, _t.t('Gagal: $e', 'Failed: $e'));
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
      if (interactive && mounted) showSnack(context, _t.t('Google Drive tidak bisa dibuka: $e', "Couldn't read Google Drive: $e"));
    }
  }

  // ---------------------------------------------------------------------------
  // Pulihkan
  // ---------------------------------------------------------------------------

  Future<String?> _askPassword({String? title}) async {
    final t = _t;
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title ?? t.t('Sandi backup', 'Backup password')),
        content: TextField(controller: ctrl, obscureText: true, autofocus: true, decoration: InputDecoration(hintText: t.t('Sandi', 'Password'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: Text(t.ok)),
        ],
      ),
    );
  }

  Future<void> _restoreBytes(Uint8List bytes) async {
    final t = _t;
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
        password = await _askPassword(title: t.t('Backup ini dikunci sandi', 'This backup is password protected'));
        if (password == null) return;
      } on BackupWrongPassword {
        password = await _askPassword(title: t.t('Sandinya salah, coba lagi', 'Wrong password, try again'));
        if (password == null) return;
      }
    }
    final info = BackupService.info(json);
    if (!mounted) return;
    final ok = await confirmDialog(
      context,
      title: t.t('Pulihkan backup ini?', 'Restore this backup?'),
      message: t.t(
        'Backup tanggal ${_stampLong(info.createdAt)} berisi ${info.accounts} dompet dan ${info.transactions} transaksi.\n\nSemua data di HP ini akan diganti dengan isi backup.',
        'Backup from ${_stampLong(info.createdAt)} has ${info.accounts} wallets and ${info.transactions} transactions.\n\nEverything on this phone will be replaced with it.',
      ),
      confirm: t.t('Pulihkan', 'Restore'),
    );
    if (!ok) return;
    final db = ref.read(databaseProvider);
    await BackupService.restore(db, json);
    db.refreshAllStreams();
    await ref.read(settingsProvider.notifier).reload();
    if (!mounted) return;
    await showHanko(context, glyph: '復', label: t.t('Data sudah dipulihkan', 'Data restored'));
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _share(Uint8List bytes, String name, String mime) async {
    await SharePlus.instance.share(ShareParams(files: [XFile.fromData(bytes, mimeType: mime)], fileNameOverrides: [name]));
  }

  Future<void> _deliver(Uint8List bytes, String name, String mime, {bool printable = false}) async {
    final t = _t;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.save_alt), title: Text(t.t('Simpan ke HP', 'Save to device')), onTap: () => Navigator.pop(ctx, 'save')),
          ListTile(leading: const Icon(Icons.share), title: Text(t.t('Bagikan (WhatsApp, email, Drive)', 'Share (email, messaging, Drive)')), onTap: () => Navigator.pop(ctx, 'share')),
          if (printable) ListTile(leading: const Icon(Icons.print), title: Text(t.t('Lihat atau cetak', 'Preview or print')), onTap: () => Navigator.pop(ctx, 'print')),
        ]),
      ),
    );
    switch (action) {
      case 'save':
        final uri = await FilePicker.saveFile(fileName: name, bytes: bytes, mimeType: mime);
        if (uri != null && mounted) showSnack(context, t.t('Tersimpan: $name', 'Saved: $name'));
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
    final t = S.of(context);
    final s = ref.watch(settingsProvider);
    final db = ref.watch(databaseProvider);
    final muted = AppTheme.sans(size: 12, color: WaColors.washiMuted);
    final templateRow = t.t(
      '2026-09-10,12:30,Pengeluaran,Makan & minum,,Tunai,,25000,IDR,,,Makan siang,Warteg,',
      '2026-09-10,12:30,Expense,Food & drinks,,Cash,,12.5,USD,,,Lunch,Deli,',
    );

    return Scaffold(
      appBar: AppBar(title: Text(widget.fromOnboarding ? t.t('Pulihkan data', 'Restore data') : t.withJp('保管', t.t('Backup & ekspor', 'Backup & export')))),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            children: [
              const SectionHeader(title: 'Google Drive', jp: '雲'),
              if (!GoogleConfig.isConfigured)
                WaCard(
                  child: Text(
                    t.t('Backup ke Google Drive belum tersedia di versi ini. Pakai backup file di bawah dulu.',
                        "Google Drive backup isn't available in this build. Use a backup file below instead."),
                    style: AppTheme.sans(size: 13, color: WaColors.washiMuted),
                  ),
                )
              else if (s.driveEmail == null)
                WaCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      t.t('Backup disimpan terenkripsi di folder tersembunyi khusus Monshika di Google Drive-mu. Monshika tidak bisa melihat file lain.',
                          "Backups are saved encrypted in a hidden Monshika folder on your Google Drive. Monshika can't see your other files."),
                      style: AppTheme.sans(size: 13, color: WaColors.washiMuted),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.login),
                      label: Text(t.t('Masuk dengan Google', 'Sign in with Google')),
                      onPressed: _busy
                          ? null
                          : () => _run(t.t('Menghubungkan', 'Connecting'), () async {
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
                        child: Text(t.t('Putuskan', 'Disconnect')),
                      ),
                    ]),
                    Text(
                      s.lastBackupAt == null
                          ? t.t('Belum pernah backup', 'No backups yet')
                          : t.t('Backup terakhir ${_stampLong(s.lastBackupAt!)}', 'Last backup ${_stampLong(s.lastBackupAt!)}'),
                      style: muted,
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.cloud_upload_outlined),
                          label: Text(t.t('Backup sekarang', 'Back up now')),
                          onPressed: _busy
                              ? null
                              : () => _run(t.t('Mengunggah backup', 'Uploading backup'), () async {
                                    final bytes = await BackupService.create(db, password: await SecurityService.instance.getBackupPassword());
                                    await DriveService.instance.upload(bytes, BackupService.fileName(), interactive: true);
                                    await ref.read(settingsProvider.notifier).setLastBackupAt(DateTime.now());
                                    await _loadDrive();
                                    if (mounted) await showHanko(context, glyph: '蔵', label: t.t('Backup tersimpan di Drive', 'Backup saved to Drive'));
                                  }),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(t.t('Backup otomatis', 'Auto backup')),
                      trailing: DropdownButton<String>(
                        value: s.autoBackup,
                        underline: const SizedBox.shrink(),
                        items: [
                          DropdownMenuItem(value: 'off', child: Text(t.t('Mati', 'Off'))),
                          DropdownMenuItem(value: 'daily', child: Text(t.t('Tiap hari', 'Daily'))),
                          DropdownMenuItem(value: 'weekly', child: Text(t.t('Tiap minggu', 'Weekly'))),
                        ],
                        onChanged: (v) => ref.read(settingsProvider.notifier).setAutoBackup(v ?? 'off'),
                      ),
                    ),
                    const Divider(),
                    Row(children: [
                      Text(t.t('File di Drive', 'Files on Drive'), style: AppTheme.sans(size: 13, weight: FontWeight.w600)),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: () => _run(t.t('Memuat', 'Loading'), () => _loadDrive())),
                    ]),
                    if (_driveFiles == null)
                      Text(t.t('Ketuk tombol muat ulang untuk melihat daftar backup', 'Tap refresh to see your backups'), style: muted)
                    else if (_driveFiles!.isEmpty)
                      Text(t.t('Belum ada backup', 'No backups yet'), style: muted)
                    else
                      for (final f in _driveFiles!)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.inventory_2_outlined),
                          title: Text(_stampLong(f.createdAt.toLocal())),
                          subtitle: Text('${(f.size / 1024).toStringAsFixed(1)} KB'),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'restore') {
                                _run(t.t('Mengunduh', 'Downloading'), () async => _restoreBytes(await DriveService.instance.download(f.id, interactive: true)));
                              } else {
                                _run(t.t('Menghapus', 'Deleting'), () async {
                                  await DriveService.instance.delete(f.id);
                                  await _loadDrive();
                                });
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(value: 'restore', child: Text(t.t('Pulihkan', 'Restore'))),
                              PopupMenuItem(value: 'delete', child: Text(t.delete)),
                            ],
                          ),
                        ),
                  ]),
                ),
              const SizedBox(height: 10),
              WaCard(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: SwitchListTile(
                  title: Text(t.t('Kunci backup dengan sandi', 'Protect backups with a password')),
                  subtitle: Text(
                    _hasPassword
                        ? t.t('Pakai AES-256. Jangan sampai lupa sandinya, tanpa sandi backup tidak bisa dibuka.',
                            "Uses AES-256. Don't lose the password, the backup can't be opened without it.")
                        : t.t('Backup tidak dikunci sandi', 'Backups are not password protected'),
                    style: muted,
                  ),
                  value: _hasPassword,
                  onChanged: (v) async {
                    if (v) {
                      final p = await _askPassword(title: t.t('Buat sandi backup', 'Create a backup password'));
                      if (p == null || p.length < 4) {
                        if (mounted && p != null) showSnack(context, t.t('Sandi paling sedikit 4 karakter', 'Password needs at least 4 characters'));
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
              SectionHeader(title: t.t('File backup', 'Backup file'), jp: '箱'),
              WaCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(children: [
                  ListTile(
                    leading: const Icon(Icons.save_alt),
                    title: Text(t.t('Buat file backup (.msk)', 'Create backup file (.msk)')),
                    subtitle: Text(t.t('Simpan ke HP atau bagikan', 'Save to device or share')),
                    onTap: _busy
                        ? null
                        : () => _run(t.t('Membuat backup', 'Creating backup'), () async {
                              final bytes = await BackupService.create(db, password: await SecurityService.instance.getBackupPassword());
                              await _deliver(bytes, BackupService.fileName(), 'application/octet-stream');
                            }),
                  ),
                  ListTile(
                    leading: const Icon(Icons.restore),
                    title: Text(t.t('Pulihkan dari file backup', 'Restore from backup file')),
                    onTap: _busy
                        ? null
                        : () => _run(t.t('Membaca file', 'Reading file'), () async {
                              final file = await FilePicker.pickFile();
                              if (file == null) return;
                              await _restoreBytes(await file.readAsBytes());
                            }),
                  ),
                ]),
              ),
              if (!widget.fromOnboarding) ...[
                SectionHeader(title: t.t('Ekspor laporan', 'Export report'), jp: '出'),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final e in {
                    'this_month': t.t('Bulan ini', 'This month'),
                    'last_month': t.t('Bulan lalu', 'Last month'),
                    'this_year': t.t('Tahun ini', 'This year'),
                    'all': t.all,
                    'custom': t.t('Pilih tanggal', 'Pick dates'),
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
                          : () => _run(t.t('Membuat CSV', 'Creating CSV'), () async {
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
                          : () => _run(t.t('Membuat Excel', 'Creating Excel'), () async {
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
                          : () => _run(t.t('Membuat PDF', 'Creating PDF'), () async {
                                final bytes = await ExportService(db).pdfBytes(_exportRange(),
                                    baseCurrency: s.baseCurrency, rates: ref.read(ratesProvider), userName: s.userName);
                                await _deliver(bytes, 'monshika-${t.t('laporan', 'report')}-${_stamp()}.pdf', 'application/pdf', printable: true);
                              }),
                    ),
                  ),
                ]),
                SectionHeader(title: t.t('Impor transaksi', 'Import transactions'), jp: '入'),
                WaCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(children: [
                    ListTile(
                      leading: const Icon(Icons.upload_file),
                      title: Text(t.t('Impor dari CSV', 'Import from CSV')),
                      subtitle: Text(t.t('Formatnya sama dengan hasil ekspor CSV', 'Same format as the CSV export')),
                      onTap: _busy
                          ? null
                          : () async {
                              final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['csv']);
                              if (file == null || !context.mounted) return;
                              final accountId = await showAccountPicker(context, ref,
                                  title: t.t('Pakai dompet ini kalau nama dompet di file tidak dikenali', "Use this wallet when a wallet name isn't recognized"));
                              if (accountId == null) return;
                              await _run(t.t('Mengimpor', 'Importing'), () async {
                                final n = await ExportService(db).importCsv(await file.readAsBytes(), fallbackAccountId: accountId);
                                if (mounted) showSnack(context, t.t('$n transaksi berhasil diimpor', '$n transactions imported'));
                              });
                            },
                    ),
                    ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text(t.t('Contoh file CSV', 'CSV template')),
                      onTap: () => _share(
                        Uint8List.fromList(utf8.encode('${ExportService(db).csvHeader.join(',')}\n$templateRow\n')),
                        'monshika-template.csv',
                        'text/csv',
                      ),
                    ),
                  ]),
                ),
                SectionHeader(title: t.t('Hati-hati', 'Danger zone'), jp: '危'),
                WaCard(
                  borderColor: WaColors.expense.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: const Icon(Icons.delete_forever, color: WaColors.expense),
                    title: Text(t.t('Hapus semua data', 'Delete all data'), style: const TextStyle(color: WaColors.expense)),
                    subtitle: Text(t.t('Kategori bawaan akan dibuat lagi', 'Default categories will be recreated')),
                    onTap: () async {
                      final word = t.t('HAPUS', 'DELETE');
                      final ctrl = TextEditingController();
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(t.t('Hapus semua data?', 'Delete all data?')),
                          content: Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(t.t('Ini tidak bisa dibatalkan. Ketik $word untuk lanjut.', "This can't be undone. Type $word to continue.")),
                            const SizedBox(height: 12),
                            TextField(controller: ctrl, autofocus: true),
                          ]),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: WaColors.expense),
                              onPressed: () => Navigator.pop(ctx, ctrl.text.trim().toUpperCase() == word),
                              child: Text(t.delete),
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
                    Text(_busyLabel ?? t.t('Sebentar', 'One moment'), style: AppTheme.sans()),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
