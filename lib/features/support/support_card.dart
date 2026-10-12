// Monshika · pengelola keuangan pribadi oleh Shicomp
// Copyright (C) 2026 Irana06. Berlisensi GNU GPL-3.0, lihat berkas LICENSE.
// https://github.com/Irana06/monshika

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_kit.dart';
import '../../l10n/strings.dart';

const kSaweriaUrl = 'https://saweria.co/shicomp';
const kTrakteerUrl = 'https://trakteer.id/Yushika_';

Future<void> openSaweria(BuildContext context) => _open(context, kSaweriaUrl, 'saweria.co/shicomp');

Future<void> openTrakteer(BuildContext context) => _open(context, kTrakteerUrl, 'trakteer.id/Yushika_');

Future<void> _open(BuildContext context, String url, String shown) async {
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    showSnack(
      context,
      S.of(context).t('Link tidak bisa dibuka. Buka $shown di browser.', "Couldn't open the link. Visit $shown in your browser."),
    );
  }
}

/// Bagian dukungan dan kredit di halaman Lainnya.
class SupportCard extends StatelessWidget {
  const SupportCard({super.key});

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    return WaCard(
      borderColor: WaColors.accent.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            KanjiBadge(glyph: '茶', color: WaColors.accent, size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.t('Traktir kopi buat Monshika', 'Buy Monshika a coffee'), style: AppTheme.serif(size: 16, weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  t.t('Monshika gratis dan tanpa iklan. Dukunganmu bantu aplikasi ini terus berkembang.',
                      'Monshika is free with no ads. Your support keeps it growing.'),
                  style: AppTheme.sans(size: 12, color: WaColors.washiMuted),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => openSaweria(context),
                  icon: const Icon(Icons.favorite_outline, size: 18),
                  label: const Text('Saweria'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => openTrakteer(context),
                  icon: const Icon(Icons.local_cafe_outlined, size: 18),
                  label: const Text('Trakteer'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              t.t('Dibuat oleh Shicomp', 'Made by Shicomp'),
              style: AppTheme.sans(size: 11, color: WaColors.washiMuted),
            ),
          ),
        ],
      ),
    );
  }
}
