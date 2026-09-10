import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_kit.dart';
import '../../providers/derived.dart';
import '../../providers/providers.dart';
import '../accounts/accounts_screen.dart';
import '../backup/backup_screen.dart';
import '../budgets/budgets_screen.dart';
import '../categories/categories_screen.dart';
import '../currency/currency_screen.dart';
import '../debts/debts_screen.dart';
import '../goals/goals_screen.dart';
import '../installments/installments_screen.dart';
import '../kakeibo/kakeibo_screen.dart';
import '../presets/presets_screen.dart';
import '../recurring/recurring_screen.dart';
import '../settings/settings_screen.dart';
import '../split_bill/split_bill_screen.dart';
import '../widgets_guide/widgets_guide_screen.dart';

class _Item {
  const _Item(this.kanji, this.label, this.color, this.builder);
  final String kanji;
  final String label;
  final Color color;
  final WidgetBuilder builder;
}

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  static final _groups = <(String, String, List<_Item>)>[
    ('金', 'Keuangan', [
      _Item('財', 'Dompet', WaColors.kin, (_) => const AccountsScreen()),
      _Item('算', 'Budget', WaColors.yamabuki, (_) => const BudgetsScreen()),
      _Item('夢', 'Target', WaColors.sakura, (_) => const GoalsScreen()),
      _Item('借', 'Utang & Piutang', WaColors.asagi, (_) => const DebtsScreen()),
      _Item('定', 'Berulang & Langganan', WaColors.ruri, (_) => const RecurringScreen()),
      _Item('返', 'Cicilan', WaColors.momiji, (_) => const InstallmentsScreen()),
      _Item('割', 'Split Bill', WaColors.shu, (_) => const SplitBillScreen()),
      _Item('簿', 'Kakeibo', WaColors.matcha, (_) => const KakeiboScreen()),
    ]),
    ('整', 'Atur', [
      _Item('類', 'Kategori', WaColors.fuji, (_) => const CategoriesScreen()),
      _Item('札', 'Preset & Tag', WaColors.cha, (_) => const PresetsScreen()),
      _Item('替', 'Mata Uang & Kurs', WaColors.wakatake, (_) => const CurrencyScreen()),
      _Item('窓', 'Widget Beranda', WaColors.ai, (_) => const WidgetsGuideScreen()),
    ]),
    ('蔵', 'Data & Aplikasi', [
      _Item('蔵', 'Backup & Export', WaColors.kohaku, (_) => const BackupScreen()),
      _Item('設', 'Pengaturan', WaColors.nezumi, (_) => const SettingsScreen()),
    ]),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final streak = ref.watch(streakProvider).value ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Lainnya · その他')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        children: [
          WaCard(
            pattern: true,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            child: Row(
              children: [
                EnsoRing(
                  progress: (streak / 30).clamp(0.05, 1),
                  size: 64,
                  color: WaColors.beni,
                  child: Text('鹿', style: AppTheme.serif(size: 26, weight: FontWeight.w700)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.userName.isEmpty ? 'Pengguna Monshika' : s.userName, style: AppTheme.serif(size: 18, weight: FontWeight.w600)),
                      Text(
                        streak == 0 ? 'Mulai catat hari ini untuk membangun streak' : '連続 $streak hari berturut-turut mencatat 🔥',
                        style: AppTheme.sans(size: 12, color: WaColors.washiMuted),
                      ),
                      if (s.driveEmail != null)
                        Text('☁ ${s.driveEmail}', style: AppTheme.sans(size: 11, color: WaColors.washiMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (final g in _groups) ...[
            SectionHeader(title: g.$2, jp: g.$1),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.82,
              children: [
                for (final item in g.$3)
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: item.builder)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        KanjiBadge(glyph: item.kanji, color: item.color, size: 50),
                        const SizedBox(height: 6),
                        Text(item.label, textAlign: TextAlign.center, maxLines: 2, style: AppTheme.sans(size: 11.5, height: 1.15)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Center(child: Text('Monshika · 紋鹿 · v1.0.0', style: AppTheme.serif(size: 12, color: WaColors.washiFaint))),
        ],
      ),
    );
  }
}
