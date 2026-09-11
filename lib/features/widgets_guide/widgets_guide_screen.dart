import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_kit.dart';
import '../../l10n/strings.dart';
import '../../providers/providers.dart';
import '../../services/home_widget_sync.dart';

class _WidgetInfo {
  const _WidgetInfo(this.id, this.kanji, this.title, this.size, this.desc, this.color);
  final String id;
  final String kanji;
  final String title;
  final String size;
  final String desc;
  final Color color;
}

List<_WidgetInfo> _widgets(S t) => [
      _WidgetInfo('QuickAddWidget', '速', t.t('Catat cepat', 'Quick add'), '2×1',
          t.t('Tombol keluar, masuk, dan ketik. Muncul dialog kecil di atas layar, tidak perlu buka aplikasi.',
              'Out, in, and type buttons. A small dialog pops up so you never have to open the app.'),
          WaColors.beni),
      _WidgetInfo('SummaryWidget', '総', t.t('Ringkasan bulan', 'Monthly summary'), '4×2',
          t.t('Total saldo, uang masuk dan keluar bulan ini, sisa aman hari ini, plus tombol cepat.',
              "Total balance, this month's in and out, today's safe-to-spend, and quick buttons."),
          WaColors.kin),
      _WidgetInfo('SafeSpendWidget', '安', t.t('Aman dipakai hari ini', 'Safe to spend today'), '2×2',
          t.t('Sisa jatah belanja hari ini. Warnanya jadi merah kalau sudah lewat.', "What's left of today's spending money. Turns red when you go over."),
          WaColors.matcha),
      _WidgetInfo('ChartWidget', '図', t.t('Grafik 7 hari', '7-day chart'), '4×2',
          t.t('Grafik uang masuk dan keluar seminggu terakhir, plus kategori terbesar bulan ini.',
              "Money in and out over the past week, plus this month's top category."),
          WaColors.asagi),
      _WidgetInfo('PresetWidget', '札', t.t('Sekali tap', 'One tap'), '4×1',
          t.t('4 preset favorit. Sekali tap langsung tercatat.', 'Your top 4 presets. One tap and it is saved.'), WaColors.shu),
      _WidgetInfo('BudgetWidget', '算', 'Budget', '4×2',
          t.t('3 budget yang paling banyak terpakai, beserta sisanya.', 'Your 3 most used budgets and what is left.'), WaColors.yamabuki),
      _WidgetInfo('UpcomingWidget', '予', t.t('Tagihan terdekat', 'Upcoming bills'), '4×2',
          t.t('Tagihan rutin, cicilan, dan utang dalam 14 hari ke depan.', 'Recurring bills, installments, and debts in the next 14 days.'), WaColors.ruri),
      _WidgetInfo('GoalWidget', '夢', t.t('Target tabungan', 'Savings goal'), '2×2',
          t.t('Progres target yang kamu pilih untuk widget.', 'Progress on the goal you picked for the widget.'), WaColors.sakura),
    ];

class WidgetsGuideScreen extends ConsumerStatefulWidget {
  const WidgetsGuideScreen({super.key});

  @override
  ConsumerState<WidgetsGuideScreen> createState() => _WidgetsGuideScreenState();
}

class _WidgetsGuideScreenState extends ConsumerState<WidgetsGuideScreen> {
  bool _pinSupported = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      HomeWidget.isRequestPinWidgetSupported().then((v) {
        if (mounted) setState(() => _pinSupported = v ?? false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final s = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.withJp('窓', t.t('Widget layar utama', 'Home screen widgets')))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          WaCard(
            pattern: true,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.t('Pasang widget Monshika', 'Add a Monshika widget'), style: AppTheme.serif(size: 17, weight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(
                Platform.isIOS
                    ? t.t('Tahan layar utama, ketuk + di pojok, cari Monshika, lalu pilih ukurannya.',
                        'Press and hold your home screen, tap + in the corner, search for Monshika, and pick a size.')
                    : t.t('Ketuk Pasang di bawah. Atau tahan layar utama, pilih Widget, cari Monshika, lalu seret ke layar.',
                        'Tap Add below. Or press and hold your home screen, open Widgets, find Monshika, and drag it over.'),
                style: AppTheme.sans(size: 13, color: WaColors.washiMuted),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: Text(t.t('Segarkan semua widget', 'Refresh all widgets')),
                    onPressed: () async {
                      await HomeWidgetSync.refresh(ref.read(databaseProvider));
                      if (context.mounted) showSnack(context, t.t('Widget sudah diperbarui', 'Widgets refreshed'));
                    },
                  ),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: Text(t.t('Sembunyikan nominal di widget', 'Hide amounts on widgets')),
            subtitle: Text(t.t('Angka diganti titik-titik. Cocok kalau HP-mu sering dilihat orang.', 'Numbers show as dots. Handy if people often see your phone.'),
                style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
            value: s.hideOnWidget,
            onChanged: (v) async {
              await ref.read(settingsProvider.notifier).setHideOnWidget(v);
              await HomeWidgetSync.refresh(ref.read(databaseProvider));
            },
          ),
          for (final w in _widgets(t))
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: WaCard(
                child: Row(children: [
                  KanjiBadge(glyph: w.kanji, color: w.color, size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(w.title, style: AppTheme.serif(size: 16, weight: FontWeight.w600))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(border: Border.all(color: WaColors.border), borderRadius: BorderRadius.circular(6)),
                          child: Text(w.size, style: AppTheme.sans(size: 11, color: WaColors.washiMuted)),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Text(w.desc, style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
                      if (_pinSupported)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: const Icon(Icons.add_to_home_screen, size: 18),
                            label: Text(t.t('Pasang', 'Add')),
                            onPressed: () => HomeWidget.requestPinWidget(qualifiedAndroidName: '${HomeWidgetSync.androidPackage}.${w.id}'),
                          ),
                        ),
                    ]),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}
