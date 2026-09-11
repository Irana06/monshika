import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_kit.dart';
import '../../l10n/strings.dart';
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
import '../update/update_ui.dart';
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

  List<(String, String, List<_Item>)> _groups(S t) => [
        ('金', t.t('Keuangan', 'Money'), [
          _Item('財', t.wallets, WaColors.kin, (_) => const AccountsScreen()),
          _Item('算', 'Budget', WaColors.yamabuki, (_) => const BudgetsScreen()),
          _Item('夢', t.t('Target', 'Goals'), WaColors.sakura, (_) => const GoalsScreen()),
          _Item('借', t.t('Utang & piutang', 'Debts'), WaColors.asagi, (_) => const DebtsScreen()),
          _Item('定', t.t('Rutin & langganan', 'Recurring'), WaColors.ruri, (_) => const RecurringScreen()),
          _Item('返', t.t('Cicilan', 'Installments'), WaColors.momiji, (_) => const InstallmentsScreen()),
          _Item('割', t.t('Bagi tagihan', 'Split bill'), WaColors.shu, (_) => const SplitBillScreen()),
          _Item('簿', 'Kakeibo', WaColors.matcha, (_) => const KakeiboScreen()),
        ]),
        ('整', t.t('Atur', 'Setup'), [
          _Item('類', t.categories, WaColors.fuji, (_) => const CategoriesScreen()),
          _Item('札', t.t('Preset & tag', 'Presets & tags'), WaColors.cha, (_) => const PresetsScreen()),
          _Item('替', t.t('Mata uang', 'Currencies'), WaColors.wakatake, (_) => const CurrencyScreen()),
          _Item('窓', 'Widget', WaColors.ai, (_) => const WidgetsGuideScreen()),
        ]),
        ('蔵', t.t('Data & aplikasi', 'Data & app'), [
          _Item('蔵', t.t('Backup & ekspor', 'Backup & export'), WaColors.kohaku, (_) => const BackupScreen()),
          _Item('設', t.t('Pengaturan', 'Settings'), WaColors.nezumi, (_) => const SettingsScreen()),
        ]),
      ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = S.of(context);
    final s = ref.watch(settingsProvider);
    final streak = ref.watch(streakProvider).value ?? 0;
    final version = ref.watch(appVersionProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(t.withJp('その他', t.t('Lainnya', 'More')))),
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
                  child: const GlyphIcon('鹿', color: WaColors.washi, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.userName.isEmpty ? t.t('Halo!', 'Hi there!') : s.userName, style: AppTheme.serif(size: 18, weight: FontWeight.w600)),
                      Text(
                        streak == 0
                            ? t.t('Catat sesuatu hari ini untuk mulai streak', 'Log something today to start a streak')
                            : t.t('Sudah $streak hari berturut-turut mencatat 🔥', '$streak days in a row 🔥'),
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
          const UpdateBanner(),
          for (final g in _groups(t)) ...[
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
          Center(
            child: Text(
              '${t.jp ? 'Monshika · 紋鹿' : 'Monshika'}${version == null ? '' : ' · v$version'}',
              style: AppTheme.serif(size: 12, color: WaColors.washiFaint),
            ),
          ),
        ],
      ),
    );
  }
}
