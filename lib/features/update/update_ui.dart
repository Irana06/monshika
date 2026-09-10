import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_kit.dart';
import '../../services/update_service.dart';

final appVersionProvider = FutureProvider<String>((ref) => UpdateService.currentVersion());

final updateProvider = NotifierProvider<UpdateNotifier, AppRelease?>(UpdateNotifier.new);

class UpdateNotifier extends Notifier<AppRelease?> {
  @override
  AppRelease? build() => null;

  Future<AppRelease?> check({bool force = false}) async {
    try {
      state = await UpdateService.check(force: force);
    } catch (_) {
      // Offline / rate limit GitHub — abaikan, coba lagi nanti.
    }
    return state;
  }
}

/// Dialog pembaruan: catatan rilis + Perbarui / Nanti saja.
Future<void> showUpdateSheet(BuildContext context, AppRelease release) async {
  await UpdateService.markNotified(release.version);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    builder: (_) => _UpdateSheet(release: release),
  );
}

class _UpdateSheet extends ConsumerStatefulWidget {
  const _UpdateSheet({required this.release});

  final AppRelease release;

  @override
  ConsumerState<_UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends ConsumerState<_UpdateSheet> {
  double? _progress;
  String? _error;
  File? _downloaded;

  AppRelease get r => widget.release;

  Future<void> _update() async {
    if (!Platform.isAndroid || r.apkUrl == null) {
      await UpdateService.openInBrowser(r);
      return;
    }
    setState(() {
      _error = null;
      _progress = 0;
    });
    try {
      final file = _downloaded ?? await UpdateService.download(r, (p) => mounted ? setState(() => _progress = p) : null);
      _downloaded = file;
      final err = await UpdateService.install(file);
      if (!mounted) return;
      setState(() {
        _progress = null;
        _error = err == null
            ? null
            : 'Installer tidak bisa dibuka ($err). Izinkan "Install aplikasi tidak dikenal" untuk Monshika, lalu coba lagi.';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _progress = null;
          _error = 'Gagal mengunduh: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(appVersionProvider).value ?? '-';
    final downloading = _progress != null;
    final sizeMb = r.apkSize > 0 ? ' · ${(r.apkSize / 1048576).toStringAsFixed(1)} MB' : '';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      maxChildSize: 0.92,
      builder: (ctx, scroll) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const KanjiBadge(glyph: '新', color: WaColors.beni, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Pembaruan tersedia', style: AppTheme.serif(size: 20, weight: FontWeight.w700)),
                  Text('v$current  →  v${r.version}$sizeMb', style: AppTheme.sans(size: 13, color: WaColors.accent)),
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            Expanded(
              child: WaCard(
                padding: const EdgeInsets.all(14),
                child: SingleChildScrollView(
                  controller: scroll,
                  child: Text(
                    UpdateService.plainNotes(r.notes).isEmpty ? 'Tidak ada catatan rilis.' : UpdateService.plainNotes(r.notes),
                    style: AppTheme.sans(size: 13, height: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (downloading) ...[
              InkBar(value: _progress!, height: 8),
              const SizedBox(height: 6),
              Text('Mengunduh… ${(_progress! * 100).round()}%', textAlign: TextAlign.center, style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
              const SizedBox(height: 8),
            ],
            if (_error != null) ...[
              Text(_error!, style: AppTheme.sans(size: 12, color: WaColors.expense)),
              TextButton.icon(
                onPressed: () => UpdateService.openInBrowser(r),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Unduh lewat browser'),
              ),
            ],
            Text(
              'Data kamu aman — pembaruan di-install di atas versi lama tanpa menghapus catatan.',
              textAlign: TextAlign.center,
              style: AppTheme.sans(size: 11, color: WaColors.washiMuted),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: downloading
                      ? null
                      : () async {
                          await UpdateService.dismiss(r.version);
                          if (context.mounted) Navigator.pop(context);
                        },
                  child: const Text('Nanti saja'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: downloading ? null : _update,
                  icon: Icon(_downloaded != null ? Icons.install_mobile : Icons.system_update),
                  label: Text(_downloaded != null ? 'Pasang' : 'Perbarui'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Banner "Pembaruan tersedia" untuk halaman Lainnya & Pengaturan.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key, this.padding = const EdgeInsets.only(top: 12)});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final release = ref.watch(updateProvider);
    if (release == null) return const SizedBox.shrink();
    return Padding(
      padding: padding,
      child: WaCard(
        borderColor: WaColors.beni.withValues(alpha: 0.6),
        onTap: () => showUpdateSheet(context, release),
        child: Row(children: [
          const KanjiBadge(glyph: '新', color: WaColors.beni, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Pembaruan tersedia · v${release.version}', style: AppTheme.serif(size: 16, weight: FontWeight.w600)),
              Text('Ketuk untuk melihat yang baru & memperbarui', style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
            ]),
          ),
          const Icon(Icons.chevron_right, color: WaColors.washiMuted),
        ]),
      ),
    );
  }
}

/// Baris "Pembaruan aplikasi" di Pengaturan (cek manual).
class UpdateTile extends ConsumerStatefulWidget {
  const UpdateTile({super.key});

  @override
  ConsumerState<UpdateTile> createState() => _UpdateTileState();
}

class _UpdateTileState extends ConsumerState<UpdateTile> {
  bool _checking = false;

  @override
  Widget build(BuildContext context) {
    final version = ref.watch(appVersionProvider).value ?? '-';
    final release = ref.watch(updateProvider);
    return ListTile(
      leading: Icon(Icons.system_update, color: release != null ? WaColors.beni : null),
      title: const Text('Pembaruan aplikasi'),
      subtitle: Text(
        release != null ? 'Versi v${release.version} tersedia (terpasang v$version)' : 'Versi terpasang v$version',
        style: AppTheme.sans(size: 12, color: release != null ? WaColors.accent : WaColors.washiMuted),
      ),
      trailing: _checking
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : Text(release != null ? 'Perbarui' : 'Cek', style: AppTheme.sans(size: 13, color: WaColors.accent, weight: FontWeight.w600)),
      onTap: _checking
          ? null
          : () async {
              if (release != null) return showUpdateSheet(context, release);
              setState(() => _checking = true);
              final found = await ref.read(updateProvider.notifier).check(force: true);
              if (!context.mounted) return;
              setState(() => _checking = false);
              if (found != null) {
                await showUpdateSheet(context, found);
              } else {
                showSnack(context, 'Monshika sudah versi terbaru (v$version)');
              }
            },
    );
  }
}
