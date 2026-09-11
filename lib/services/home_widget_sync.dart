import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/kanji_icons.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/dates.dart';
import '../core/utils/money.dart';
import '../data/database/database.dart';
import '../l10n/strings.dart';
import '../providers/providers.dart' show ratesFromRows;
import 'finance.dart';

/// Menyiapkan data untuk semua widget beranda (Android & iOS).
abstract final class HomeWidgetSync {
  static const appGroupId = 'group.com.shicomp.monshika';
  static const androidPackage = 'com.shicomp.monshika.widgets';

  /// Nama kelas provider Android == nama "kind" widget iOS.
  static const widgets = [
    'QuickAddWidget',
    'SummaryWidget',
    'SafeSpendWidget',
    'ChartWidget',
    'PresetWidget',
    'BudgetWidget',
    'UpcomingWidget',
    'GoalWidget',
  ];

  static Future<void> refresh(AppDatabase db, {bool renderChart = true, String? lastAction}) async {
    try {
      await _refresh(db, renderChart: renderChart, lastAction: lastAction);
    } catch (e, st) {
      debugPrint('HomeWidgetSync failed: $e\n$st');
    }
  }

  static Future<void> _refresh(AppDatabase db, {required bool renderChart, String? lastAction}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final s = S.fromPrefs(prefs);
    S.current = s;
    Intl.defaultLocale = s.dateLocale;
    // Glyph kanji hanya dikirim saat gaya Jepang aktif. Emoji buatan pengguna tetap dikirim.
    String glyph(String g) => s.jp || iconForGlyph(g) == null ? g : '';
    final base = prefs.getString('baseCurrency') ?? 'IDR';
    final hidden = prefs.getBool('hideOnWidget') ?? false;
    final startDay = prefs.getInt('monthStartDay') ?? 1;

    final accounts = {for (final a in await db.getAccounts(includeArchived: true)) a.id: a};
    final categories = {for (final c in await db.getCategories()) c.id: c};
    final rates = ratesFromRows(await db.getRates());
    final f = Finance(
      accounts: accounts,
      balances: await db.getBalances(),
      categories: categories,
      rates: rates,
      baseCurrency: base,
    );

    final now = DateTime.now();
    final month = monthRange(now, startDay: startDay);
    final txs = await db.getTransactions(from: month.start, to: month.end);
    final summary = f.summarize(txs);

    final recurrings = await db.getActiveRecurrings();
    final installments = await db.getActiveInstallments();
    final debts = await db.getOpenDebts();
    final paidRows = await db
        .customSelect('SELECT debt_id AS id, SUM(amount) AS total FROM debt_payments GROUP BY debt_id')
        .get();
    final debtPaid = {for (final r in paidRows) r.read<int>('id'): r.read<double>('total')};
    final billsInPeriod = upcomingBills(
      recurrings: recurrings,
      installments: installments,
      debts: debts,
      debtPaid: debtPaid,
      accounts: accounts,
      until: month.end,
    );
    final kakeibo = await (db.select(db.kakeiboMonths)..where((k) => k.month.equals(fmtMonthKey(month.start))))
        .getSingleOrNull();
    final safe = f.safeToSpend(
      periodTxs: txs,
      range: month,
      upcomingBills: billsInPeriod.fold(0.0, (s, b) => s + f.toBase(b.amount, b.currency)),
      plannedIncome: kakeibo?.plannedIncome ?? 0,
      savingsTarget: kakeibo?.savingsTarget ?? 0,
    );

    String m(double v, {bool compact = false}) => formatMoney(v, base, hidden: hidden, compact: compact);

    await HomeWidget.saveWidgetData<String>('currency', base);
    await HomeWidget.saveWidgetData<bool>('hidden', hidden);
    await HomeWidget.saveWidgetData<String>('total_balance', m(f.totalBalance));
    await HomeWidget.saveWidgetData<String>('month_label', fmtMonthYear(month.start));
    await HomeWidget.saveWidgetData<String>('income', m(summary.income, compact: true));
    await HomeWidget.saveWidgetData<String>('expense', m(summary.expense, compact: true));
    await HomeWidget.saveWidgetData<String>('net', m(summary.income - summary.expense, compact: true));
    await HomeWidget.saveWidgetData<String>('safe_per_day', m(math.max(0, safe.perDay)));
    await HomeWidget.saveWidgetData<String>('safe_today_left', m(safe.todayLeft));
    await HomeWidget.saveWidgetData<bool>('safe_over', safe.todayLeft < 0);
    await HomeWidget.saveWidgetData<int>('safe_ratio', (safe.usedRatio * 100).round());
    await HomeWidget.saveWidgetData<String>('today_spent', m(safe.todaySpent));
    await HomeWidget.saveWidgetData<String>('updated', s.t('Diperbarui ${DateFormat('HH:mm').format(now)}', 'Updated ${DateFormat('HH:mm').format(now)}'));
    if (lastAction != null) await HomeWidget.saveWidgetData<String>('last_action', lastAction);

    // Teks label widget, sudah sesuai bahasa dan gaya Jepang.
    final labels = <String, String>{
      'txt_open_app': s.t('Buka Monshika', 'Open Monshika'),
      'txt_summary_title': s.jp ? '総資産 · Monshika' : s.t('Total saldo', 'Total balance'),
      'txt_income': '${s.jp ? '入' : s.t('Masuk', 'In')} ${m(summary.income, compact: true)}',
      'txt_expense': '${s.jp ? '出' : s.t('Keluar', 'Out')} ${m(summary.expense, compact: true)}',
      'txt_safe_line': '${s.jp ? '今日 ' : ''}${s.t('Aman dipakai', 'Safe to spend')} ${m(safe.todayLeft)}',
      'txt_btn_expense': s.jp ? '- 出' : s.t('- Keluar', '- Out'),
      'txt_btn_income': s.jp ? '+ 入' : s.t('+ Masuk', '+ In'),
      'txt_btn_quick': s.jp ? '速' : '⚡',
      'txt_safe_title': s.jp ? '今日 · ${s.t('aman dipakai', 'safe to spend')}' : s.t('Aman dipakai hari ini', 'Safe to spend today'),
      'txt_per_day': s.t('Jatah ${m(math.max(0, safe.perDay))}/hari', '${m(math.max(0, safe.perDay))}/day'),
      'txt_spent': s.t('Terpakai ${m(safe.todaySpent)}', 'Spent ${m(safe.todaySpent)}'),
      'txt_chart_title': s.jp ? '図 ${s.t('7 hari', '7 days')}' : s.t('7 hari terakhir', 'Last 7 days'),
      'txt_chart_empty': s.t('Buka Monshika untuk memuat grafik', 'Open Monshika to load the chart'),
      'txt_preset_empty': s.withJp('札', s.t('Buat preset di Monshika', 'Add presets in Monshika')),
      'txt_budget_title': s.withJp('算', 'Budget'),
      'txt_budget_empty': s.t('Belum ada budget', 'No budgets yet'),
      'txt_upcoming_title': s.withJp('予', s.t('Tagihan terdekat', 'Upcoming bills')),
      'txt_upcoming_empty': s.t('Tidak ada tagihan', 'No bills coming up'),
      'txt_goal_icon': s.jp ? '夢' : '🎯',
      'txt_goal_empty': s.t('Belum ada target', 'No goal yet'),
      'txt_goal_hint': s.t('Buat di Monshika', 'Create one in Monshika'),
    };
    for (final e in labels.entries) {
      await HomeWidget.saveWidgetData<String>(e.key, e.value);
    }

    // Preset sekali tap
    final presets = (await db.getPresets()).where((p) => p.showInWidget).take(4).map((p) => {
          'id': p.id,
          'name': p.name,
          'icon': p.icon,
          'type': p.type,
          'amount': formatMoney(p.amount, accounts[p.accountId]?.currency ?? base, compact: true),
        });
    await HomeWidget.saveWidgetData<String>('presets', jsonEncode(presets.toList()));

    // Budget
    final budgetItems = <Map<String, Object>>[];
    for (final b in await db.getBudgets()) {
      final r = periodRange(b.period, now, monthStartDay: startDay);
      final bt = b.period == 'monthly' ? txs : await db.getTransactions(from: r.start, to: r.end, type: 'expense');
      final spent = f.budgetSpent(b, bt, r);
      final left = formatMoney(b.amount - spent, b.currency, compact: true, hidden: hidden);
      budgetItems.add({
        'name': b.name,
        'icon': glyph(b.icon),
        'color': b.color,
        'pct': b.amount <= 0 ? 0 : (spent / b.amount * 100).round(),
        'left': s.t('Sisa $left', '$left left'),
      });
    }
    budgetItems.sort((a, b) => (b['pct'] as int).compareTo(a['pct'] as int));
    await HomeWidget.saveWidgetData<String>('budgets', jsonEncode(budgetItems.take(3).toList()));

    // Tagihan 14 hari ke depan
    final soon = upcomingBills(
      recurrings: recurrings,
      installments: installments,
      debts: debts,
      debtPaid: debtPaid,
      accounts: accounts,
      until: dateOnly(now).add(const Duration(days: 15)),
      includeIncome: true,
    ).take(4).map((b) => {
          'title': b.title,
          'date': fmtRelativeDay(b.date).startsWith(RegExp(r'[A-Z][a-z]+,')) ? fmtDateShort(b.date) : fmtRelativeDay(b.date),
          'amount': formatMoney(b.amount, b.currency, compact: true, hidden: hidden),
          'icon': glyph(b.icon),
          'income': b.isIncome,
        });
    await HomeWidget.saveWidgetData<String>('upcoming', jsonEncode(soon.toList()));

    // Target tabungan (yang dipin, atau progres tertinggi)
    final goals = await db.getGoals();
    final saved = await db.getGoalSaved();
    Goal? goal = goals.where((g) => g.pinned).firstOrNull;
    if (goal == null && goals.isNotEmpty) {
      goals.sort((a, b) => ((saved[b.id] ?? 0) / b.targetAmount).compareTo((saved[a.id] ?? 0) / a.targetAmount));
      goal = goals.first;
    }
    await HomeWidget.saveWidgetData<String>(
      'goal',
      goal == null
          ? ''
          : jsonEncode({
              'name': goal.name,
              'icon': glyph(goal.icon),
              'color': goal.color,
              'pct': goal.targetAmount <= 0 ? 0 : ((saved[goal.id] ?? 0) / goal.targetAmount * 100).clamp(0, 100).round(),
              'saved': formatMoney(saved[goal.id] ?? 0, goal.currency, compact: true, hidden: hidden),
              'target': formatMoney(goal.targetAmount, goal.currency, compact: true, hidden: hidden),
            }),
    );

    // Grafik 7 hari
    final week = DateRange(dateOnly(now).subtract(const Duration(days: 6)), dateOnly(now).add(const Duration(days: 1)));
    final weekTxs = await db.getTransactions(from: week.start, to: week.end);
    final expenses = f.dailyTotals(weekTxs, week, 'expense');
    final incomes = f.dailyTotals(weekTxs, week, 'income');
    await HomeWidget.saveWidgetData<String>('week_total', m(expenses.fold(0.0, (s, v) => s + v), compact: true));
    if (renderChart) {
      try {
        await HomeWidget.renderFlutterWidget(
          WidgetChartImage(
            expenses: expenses,
            incomes: incomes,
            labels: [for (var i = 0; i < 7; i++) weekdayShort(week.start.add(Duration(days: i)).weekday)],
            emptyText: s.t('Belum ada\npengeluaran', 'No spending\nyet'),
            breakdown: f
                .breakdown(txs, 'expense')
                .take(4)
                .map((e) => (categories[e.key]?.name ?? s.t('Lainnya', 'Other'), e.value, Color(categories[e.key]?.color ?? 0xFF8C8C96)))
                .toList(),
          ),
          key: 'chart_image',
          logicalSize: const Size(360, 170),
        );
      } catch (e) {
        debugPrint('Chart render skipped: $e');
      }
    }

    for (final w in widgets) {
      await HomeWidget.updateWidget(qualifiedAndroidName: '$androidPackage.$w', iOSName: w);
    }
  }
}

/// Gambar grafik yang dirender offscreen untuk widget beranda.
class WidgetChartImage extends StatelessWidget {
  const WidgetChartImage({
    super.key,
    required this.expenses,
    required this.incomes,
    required this.labels,
    required this.breakdown,
    this.emptyText = '',
  });

  final String emptyText;
  final List<double> expenses;
  final List<double> incomes;
  final List<String> labels;
  final List<(String, double, Color)> breakdown;

  @override
  Widget build(BuildContext context) {
    final maxV = [...expenses, ...incomes, 1.0].reduce(math.max);
    final totalBreak = breakdown.fold(0.0, (s, e) => s + e.$2);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        width: 360,
        height: 170,
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < expenses.length; i++)
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _bar(incomes[i] / maxV, WaColors.income.withValues(alpha: 0.55)),
                                const SizedBox(width: 2),
                                _bar(expenses[i] / maxV, i == expenses.length - 1 ? WaColors.beni : WaColors.expense.withValues(alpha: 0.85)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      for (final l in labels)
                        Expanded(
                          child: Text(l,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11, color: WaColors.washiMuted, decoration: TextDecoration.none)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (breakdown.isEmpty)
                    Text(emptyText,
                        style: const TextStyle(fontSize: 12, color: WaColors.washiMuted, decoration: TextDecoration.none)),
                  for (final b in breakdown)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${b.$1} · ${totalBreak == 0 ? 0 : (b.$2 / totalBreak * 100).round()}%',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: WaColors.washi, decoration: TextDecoration.none),
                          ),
                          const SizedBox(height: 3),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: SizedBox(
                              height: 5,
                              child: Stack(children: [
                                Container(color: WaColors.border),
                                FractionallySizedBox(
                                  widthFactor: totalBreak == 0 ? 0 : (b.$2 / totalBreak).clamp(0.02, 1),
                                  child: Container(color: b.$3),
                                ),
                              ]),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar(double ratio, Color color) => Container(
        width: 9,
        height: math.max(3, 118 * ratio.clamp(0, 1)),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
      );
}
