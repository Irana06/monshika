import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_kit.dart';
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

const _widgets = [
  _WidgetInfo('QuickAddWidget', '速', 'Catat Cepat', '2×1',
      'Tombol − / + / ketik. Membuka dialog kecil di atas beranda — catat tanpa membuka aplikasi.', WaColors.beni),
  _WidgetInfo('SummaryWidget', '総', 'Ringkasan Bulan', '4×2',
      'Total saldo, pemasukan & pengeluaran bulan ini, sisa aman hari ini, dan tombol cepat.', WaColors.kin),
  _WidgetInfo('SafeSpendWidget', '安', 'Sisa Aman Hari Ini', '2×2',
      'Jatah belanja harian yang masih tersisa — berubah merah kalau kelewatan.', WaColors.matcha),
  _WidgetInfo('ChartWidget', '図', 'Grafik 7 Hari', '4×2',
      'Batang pemasukan/pengeluaran seminggu terakhir + kategori terbesar bulan ini.', WaColors.asagi),
  _WidgetInfo('PresetWidget', '札', 'Preset Sekali Tap', '4×1',
      '4 preset favorit. Sekali tap langsung tercatat di latar belakang.', WaColors.shu),
  _WidgetInfo('BudgetWidget', '算', 'Budget', '4×2', '3 budget dengan pemakaian tertinggi beserta sisanya.', WaColors.yamabuki),
  _WidgetInfo('UpcomingWidget', '予', 'Tagihan Mendatang', '4×2',
      'Tagihan berulang, cicilan, dan utang/piutang 14 hari ke depan.', WaColors.ruri),
  _WidgetInfo('GoalWidget', '夢', 'Target Tabungan', '2×2', 'Progres target yang disematkan (omamori).', WaColors.sakura),
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
    final s = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Widget Beranda · 窓')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          WaCard(
            pattern: true,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Pasang widget Monshika di layar beranda', style: AppTheme.serif(size: 17, weight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(
                Platform.isIOS
                    ? 'Tahan layar beranda › tombol + di pojok › cari "Monshika" › pilih ukuran widget.'
                    : 'Tekan "Pasang" di bawah, atau tahan layar beranda › Widget › cari "Monshika" › seret ke beranda.',
                style: AppTheme.sans(size: 13, color: WaColors.washiMuted),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Perbarui semua widget'),
                    onPressed: () async {
                      await HomeWidgetSync.refresh(ref.read(databaseProvider));
                      if (context.mounted) showSnack(context, 'Widget diperbarui');
                    },
                  ),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Sembunyikan nominal di widget'),
            subtitle: Text('Tampil sebagai •••••• — cocok kalau HP sering dilihat orang', style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
            value: s.hideOnWidget,
            onChanged: (v) async {
              await ref.read(settingsProvider.notifier).setHideOnWidget(v);
              await HomeWidgetSync.refresh(ref.read(databaseProvider));
            },
          ),
          for (final w in _widgets)
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
                            label: const Text('Pasang'),
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
