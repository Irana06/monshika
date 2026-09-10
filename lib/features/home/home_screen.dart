import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/database/database.dart';
import '../../providers/derived.dart';
import '../../providers/providers.dart';
import '../../services/money_actions.dart';
import '../../services/rates_service.dart';
import '../accounts/accounts_screen.dart';
import '../budgets/budgets_screen.dart';
import '../kakeibo/kakeibo_screen.dart';
import '../presets/presets_screen.dart';
import '../recurring/recurring_screen.dart';
import '../settings/settings_screen.dart';
import '../shell/app_shell.dart';
import '../transactions/quick_input_sheet.dart';
import '../transactions/transaction_tile.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final (jp, id) = greeting();
    final season = seasonOf(DateTime.now());

    return Scaffold(
      body: RefreshIndicator(
        color: WaColors.accent,
        onRefresh: () async {
          final db = ref.read(databaseProvider);
          await MoneyActions(db).processDueRecurrings();
          await RatesService.refresh(db, force: true);
          db.refreshAllStreams();
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              toolbarHeight: 72,
              titleSpacing: 20,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$jp${settings.seasonalMotif ? '  ${season.motif}' : ''}',
                    style: AppTheme.serif(size: 13, color: WaColors.accent),
                  ),
                  Text(
                    settings.userName.isEmpty ? id : '$id, ${settings.userName}',
                    style: AppTheme.serif(size: 21, weight: FontWeight.w600),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: settings.hideBalance ? 'Tampilkan saldo' : 'Sembunyikan saldo',
                  icon: Icon(settings.hideBalance ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => ref.read(settingsProvider.notifier).toggleHideBalance(),
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                ),
                const SizedBox(width: 8),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
              sliver: SliverList.list(
                children: [
                  const _BalanceCard(),
                  const SizedBox(height: 12),
                  const _SafeToSpendCard(),
                  if (settings.kakeiboMode) const _KakeiboPrompt(),
                  const _QuickActions(),
                  const _AccountsStrip(),
                  const _BudgetsStrip(),
                  const _UpcomingSection(),
                  const _RecentSection(),
                ].animate(interval: 40.ms).fadeIn(duration: 300.ms).slideY(begin: 0.04, end: 0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends ConsumerWidget {
  const _BalanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final f = ref.watch(financeProvider);
    final txs = ref.watch(thisMonthTransactionsProvider).value ?? const <TxEntry>[];
    final sum = f.summarize(txs);
    final range = ref.watch(thisMonthRangeProvider);
    final streak = ref.watch(streakProvider).value ?? 0;
    final maxFlow = [sum.income, sum.expense, 1.0].reduce((a, b) => a > b ? a : b);

    return WaCard(
      pattern: true,
      padding: const EdgeInsets.all(20),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1C2233), Color(0xFF15151C)],
      ),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountsScreen())),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('総資産', style: AppTheme.serif(size: 13, color: WaColors.accent, weight: FontWeight.w700)),
              const SizedBox(width: 6),
              Text('Total saldo', style: AppTheme.sans(size: 13, color: WaColors.washiMuted)),
              const Spacer(),
              if (streak > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: WaColors.beni.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('🔥 $streak hari', style: AppTheme.sans(size: 11, weight: FontWeight.w700, color: WaColors.shu)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatMoney(f.totalBalance, s.baseCurrency, hidden: s.hideBalance),
              style: AppTheme.serif(size: 34, weight: FontWeight.w700),
            ),
          ),
          if (f.liabilities > 0)
            Text(
              'Aset ${formatMoney(f.assets, s.baseCurrency, compact: true, hidden: s.hideBalance)} · '
              'Utang kartu ${formatMoney(f.liabilities, s.baseCurrency, compact: true, hidden: s.hideBalance)}',
              style: AppTheme.sans(size: 12, color: WaColors.washiMuted),
            ),
          const SizedBox(height: 18),
          Text(fmtRange(range), style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
          const SizedBox(height: 8),
          _FlowRow(label: '入 Masuk', value: sum.income, max: maxFlow, color: WaColors.income, currency: s.baseCurrency, hidden: s.hideBalance),
          const SizedBox(height: 8),
          _FlowRow(label: '出 Keluar', value: sum.expense, max: maxFlow, color: WaColors.expense, currency: s.baseCurrency, hidden: s.hideBalance),
        ],
      ),
    );
  }
}

class _FlowRow extends StatelessWidget {
  const _FlowRow({required this.label, required this.value, required this.max, required this.color, required this.currency, required this.hidden});

  final String label;
  final double value;
  final double max;
  final Color color;
  final String currency;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 72, child: Text(label, style: AppTheme.serif(size: 13, color: color, weight: FontWeight.w600))),
        Expanded(child: InkBar(value: value / max, color: color, height: 6)),
        const SizedBox(width: 10),
        SizedBox(
          width: 110,
          child: Text(
            formatMoney(value, currency, hidden: hidden),
            textAlign: TextAlign.end,
            style: AppTheme.sans(size: 13, weight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _SafeToSpendCard extends ConsumerWidget {
  const _SafeToSpendCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final safe = ref.watch(safeToSpendProvider);
    final s = ref.watch(settingsProvider);
    if (safe == null) return const SizedBox.shrink();
    final over = safe.todayLeft < 0;
    return WaCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          EnsoRing(
            progress: safe.perDay <= 0 ? 1 : safe.todaySpent / safe.perDay,
            size: 78,
            child: Text('今日', style: AppTheme.serif(size: 17, weight: FontWeight.w700)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sisa aman hari ini', style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
                const SizedBox(height: 2),
                Text(
                  formatMoney(safe.todayLeft, s.baseCurrency, hidden: s.hideBalance),
                  style: AppTheme.serif(size: 24, weight: FontWeight.w700, color: over ? WaColors.expense : WaColors.washi),
                ),
                const SizedBox(height: 4),
                Text(
                  safe.perDay <= 0
                      ? 'Anggaran periode ini sudah habis — rem pengeluaran ya.'
                      : 'Jatah ${formatMoney(safe.perDay, s.baseCurrency, compact: true, hidden: s.hideBalance)}/hari · '
                          'terpakai ${formatMoney(safe.todaySpent, s.baseCurrency, compact: true, hidden: s.hideBalance)} · '
                          '${safe.remainingDays} hari lagi',
                  style: AppTheme.sans(size: 12, color: WaColors.washiMuted),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, size: 20, color: WaColors.washiMuted),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Sisa aman · 安全'),
                content: Text(
                  safe.basis == 'income'
                      ? 'Dihitung dari pemasukan periode ini (atau rencana pemasukan Kakeibo), dikurangi target nabung, '
                          'tagihan yang belum dibayar sampai akhir periode, dan pengeluaran sebelum hari ini — lalu dibagi sisa hari.'
                      : 'Belum ada pemasukan tercatat, jadi dihitung dari saldo dompet likuid (tunai, bank, e-wallet) '
                          'dikurangi tagihan mendatang dan target nabung, dibagi sisa hari periode ini.',
                  style: AppTheme.sans(size: 14, color: WaColors.washiMuted),
                ),
                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Mengerti'))],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KakeiboPrompt extends ConsumerWidget {
  const _KakeiboPrompt();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(thisMonthRangeProvider);
    final entry = ref.watch(kakeiboMonthProvider(fmtMonthKey(range.start)));
    if (entry.isLoading || entry.value != null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: WaCard(
        borderColor: WaColors.accent.withValues(alpha: 0.4),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KakeiboScreen())),
        child: Row(
          children: [
            const KanjiBadge(glyph: '簿', color: WaColors.accent, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mulai Kakeibo bulan ini', style: AppTheme.serif(size: 16, weight: FontWeight.w600)),
                  Text('Tentukan rencana pemasukan & target nabung supaya "sisa aman" makin akurat.',
                      style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: WaColors.washiMuted),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends ConsumerWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(presetsProvider).value ?? const <Preset>[];
    final accounts = ref.watch(accountMapProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Catat sekali tap',
          jp: '速',
          action: 'Atur',
          onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PresetsScreen())),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ActionChip(
                avatar: const Icon(Icons.bolt, size: 18, color: WaColors.accent),
                label: const Text('Ketik cepat'),
                onPressed: () => showQuickInputSheet(context),
              ),
              for (final p in presets) ...[
                const SizedBox(width: 8),
                ActionChip(
                  avatar: Text(p.icon),
                  label: Text('${p.name} · ${formatMoney(p.amount, accounts[p.accountId]?.currency ?? 'IDR', compact: true)}'),
                  onPressed: () async {
                    await MoneyActions(ref.read(databaseProvider)).recordPreset(p);
                    if (context.mounted) {
                      if (ref.read(settingsProvider).hankoAnimation) {
                        await showHanko(context, glyph: p.type == 'income' ? '入' : '済', label: '${p.name} tercatat');
                      } else {
                        showSnack(context, '${p.name} tercatat');
                      }
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountsStrip extends ConsumerWidget {
  const _AccountsStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final f = ref.watch(financeProvider);
    final hidden = ref.watch(settingsProvider).hideBalance;
    return Column(
      children: [
        SectionHeader(
          title: 'Dompet',
          jp: '財',
          action: 'Kelola',
          onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountsScreen())),
        ),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: accounts.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              if (i == accounts.length) {
                return SizedBox(
                  width: 90,
                  child: WaCard(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountFormScreen())),
                    child: const Center(child: Icon(Icons.add, color: WaColors.washiMuted)),
                  ),
                );
              }
              final a = accounts[i];
              final bal = f.accountBalance(a.id);
              return SizedBox(
                width: 150,
                child: WaCard(
                  padding: const EdgeInsets.all(12),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AccountDetailScreen(accountId: a.id))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        KanjiBadge(glyph: a.icon, color: Color(a.color), size: 28),
                        const SizedBox(width: 8),
                        Expanded(child: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(size: 13, weight: FontWeight.w600))),
                      ]),
                      const Spacer(),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          formatMoney(bal, a.currency, hidden: hidden),
                          style: AppTheme.sans(size: 15, weight: FontWeight.w700, color: bal < 0 ? WaColors.expense : WaColors.washi),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BudgetsStrip extends ConsumerWidget {
  const _BudgetsStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = (ref.watch(budgetsProvider).value ?? const <Budget>[]).where((b) => b.active).toList();
    final f = ref.watch(financeProvider);
    final s = ref.watch(settingsProvider);
    final monthTxs = ref.watch(yearTransactionsProvider).value ?? const <TxEntry>[];
    return Column(
      children: [
        SectionHeader(
          title: 'Budget',
          jp: '算',
          action: budgets.isEmpty ? 'Buat' : 'Semua',
          onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BudgetsScreen())),
        ),
        if (budgets.isEmpty)
          WaCard(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BudgetFormScreen())),
            child: Row(children: [
              const EnsoRing(progress: 0.35, size: 44, stroke: 5),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Belum ada budget. Buat batas pengeluaran per kategori agar tidak kebablasan.',
                    style: AppTheme.sans(size: 13, color: WaColors.washiMuted)),
              ),
            ]),
          )
        else
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: budgets.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final b = budgets[i];
                final range = periodRange(b.period, DateTime.now(), monthStartDay: s.monthStartDay, firstWeekday: s.firstWeekday);
                final spent = f.budgetSpent(b, monthTxs, range);
                final ratio = b.amount <= 0 ? 0.0 : spent / b.amount;
                return SizedBox(
                  width: 120,
                  child: WaCard(
                    padding: const EdgeInsets.all(10),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BudgetDetailScreen(budgetId: b.id))),
                    child: Column(
                      children: [
                        EnsoRing(
                          progress: ratio,
                          size: 62,
                          stroke: 6,
                          child: Text(b.icon, style: AppTheme.serif(size: 20, color: Color(b.color), weight: FontWeight.w700)),
                        ),
                        const SizedBox(height: 6),
                        Text(b.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(size: 12, weight: FontWeight.w600)),
                        Text('${(ratio * 100).round()}%',
                            style: AppTheme.sans(size: 11, color: ratio >= 1 ? WaColors.expense : WaColors.washiMuted)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _UpcomingSection extends ConsumerWidget {
  const _UpcomingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bills = ref.watch(upcomingBillsProvider(7));
    final hidden = ref.watch(settingsProvider).hideBalance;
    if (bills.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        SectionHeader(
          title: '7 hari ke depan',
          jp: '予',
          action: 'Jadwal',
          onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecurringScreen())),
        ),
        WaCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              for (final b in bills.take(5))
                ListTile(
                  dense: true,
                  leading: KanjiBadge(glyph: b.icon, color: Color(b.color), size: 34),
                  title: Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(size: 14, weight: FontWeight.w600)),
                  subtitle: Text(fmtRelativeDay(b.date), style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
                  trailing: Text(
                    formatMoney(b.isIncome ? b.amount : -b.amount, b.currency, hidden: hidden, showSign: b.isIncome),
                    style: AppTheme.sans(size: 13, weight: FontWeight.w700, color: b.isIncome ? WaColors.income : WaColors.expense),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecentSection extends ConsumerWidget {
  const _RecentSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentTransactionsProvider);
    return Column(
      children: [
        SectionHeader(
          title: 'Transaksi terakhir',
          jp: '記',
          action: 'Semua',
          onAction: () => ref.read(shellTabProvider.notifier).go(1),
        ),
        recent.when(
          loading: () => const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
          error: (e, _) => Text('$e'),
          data: (list) => list.isEmpty
              ? const EmptyState(kanji: '始', title: 'Belum ada catatan', subtitle: 'Ketuk + di bawah, atau tahan untuk input cepat.')
              : WaCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(children: [for (final t in list) TransactionTile(tx: t, showDate: true)]),
                ),
        ),
      ],
    );
  }
}
