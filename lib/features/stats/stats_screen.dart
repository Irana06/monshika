import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/kanji_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/database/database.dart';
import '../../l10n/strings.dart';
import '../../providers/derived.dart';
import '../../providers/providers.dart';
import '../common/pickers.dart';
import '../transactions/transaction_tile.dart';
import '../transactions/transactions_screen.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = S.of(context);
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.withJp('分析', t.t('Statistik', 'Stats'))),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: WaColors.accent,
            labelColor: WaColors.accent,
            unselectedLabelColor: WaColors.washiMuted,
            dividerColor: WaColors.border,
            tabs: [
              Tab(text: t.t('Ringkasan', 'Overview')),
              Tab(text: t.categories),
              Tab(text: t.t('Tren', 'Trends')),
              Tab(text: t.t('Kalender', 'Calendar')),
              Tab(text: t.t('Kekayaan', 'Net worth')),
              const Tab(text: 'Kakeibo'),
            ],
          ),
        ),
        body: const Column(
          children: [
            _PeriodBar(),
            Expanded(
              child: TabBarView(
                children: [_SummaryTab(), _CategoryTab(), _TrendTab(), _CalendarTab(), _NetWorthTab(), _PillarTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodBar extends ConsumerWidget {
  const _PeriodBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = S.of(context);
    final type = ref.watch(periodTypeProvider);
    final range = ref.watch(currentRangeProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(onPressed: () => ref.read(periodOffsetProvider.notifier).prev(), icon: const Icon(Icons.chevron_left)),
          Expanded(
            child: GestureDetector(
              onTap: () => ref.read(periodOffsetProvider.notifier).reset(),
              child: Text(fmtRange(range), textAlign: TextAlign.center, style: AppTheme.serif(size: 15, weight: FontWeight.w600)),
            ),
          ),
          IconButton(onPressed: () => ref.read(periodOffsetProvider.notifier).next(), icon: const Icon(Icons.chevron_right)),
          PopupMenuButton<String>(
            initialValue: type,
            onSelected: (v) {
              ref.read(periodTypeProvider.notifier).set(v);
              ref.read(periodOffsetProvider.notifier).reset();
            },
            itemBuilder: (_) => [
              for (final p in const ['weekly', 'monthly', 'yearly']) PopupMenuItem(value: p, child: Text(t.periodLabel(p))),
            ],
            child: Chip(label: Text(t.periodLabel(type))),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Ringkasan
// -----------------------------------------------------------------------------

class _SummaryTab extends ConsumerWidget {
  const _SummaryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = S.of(context);
    final s = ref.watch(settingsProvider);
    final f = ref.watch(financeProvider);
    final range = ref.watch(currentRangeProvider);
    final type = ref.watch(periodTypeProvider);
    final all = ref.watch(yearTransactionsProvider).value ?? const <TxEntry>[];
    final txs = ref.watch(periodTransactionsProvider).value ?? const <TxEntry>[];
    final sum = f.summarize(txs);
    final prevRange = range.shift(-1, type);
    final prev = f.summarize(all.where((x) => prevRange.contains(x.date)));
    final today = dateOnly(DateTime.now());
    final elapsed = range.contains(today) ? today.difference(range.start).inDays + 1 : range.days;
    final avgDaily = sum.expense / math.max(1, elapsed);

    // 6 periode terakhir
    final periods = [for (var i = 5; i >= 0; i--) range.shift(-i, type)];
    final bars = [for (final p in periods) f.summarize(all.where((x) => p.contains(x.date)))];
    final maxY = [...bars.map((b) => b.income), ...bars.map((b) => b.expense), 1.0].reduce(math.max);

    String? pct(double now, double before) {
      if (before == 0) return null;
      final v = (now - before) / before * 100;
      return '${v >= 0 ? '▲' : '▼'} ${v.abs().toStringAsFixed(0)}%';
    }

    String m(double v) => formatMoney(v, s.baseCurrency, hidden: s.hideBalance, compact: true);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        Row(children: [
          Expanded(child: _KpiCard(label: t.withJp('入', t.income), value: m(sum.income), delta: pct(sum.income, prev.income), color: WaColors.income)),
          const SizedBox(width: 10),
          Expanded(
            child: _KpiCard(label: t.withJp('出', t.expense), value: m(sum.expense), delta: pct(sum.expense, prev.expense), color: WaColors.expense, invert: true),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _KpiCard(label: t.withJp('差', t.t('Selisih', 'Net')), value: m(sum.income - sum.expense), color: WaColors.washi)),
          const SizedBox(width: 10),
          Expanded(
            child: _KpiCard(
              label: t.withJp('率', t.t('Porsi ditabung', 'Savings rate')),
              value: sum.income == 0 ? '-' : '${((sum.income - sum.expense) / sum.income * 100).toStringAsFixed(0)}%',
              color: WaColors.accent,
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _KpiCard(label: t.withJp('日', t.t('Rata-rata per hari', 'Daily average')), value: m(avgDaily), color: WaColors.washi)),
          const SizedBox(width: 10),
          Expanded(
            child: _KpiCard(label: t.withJp('件', t.t('Jumlah transaksi', 'Transactions')), value: '${txs.where((x) => x.type != 'transfer').length}', color: WaColors.washi),
          ),
        ]),
        SectionHeader(title: t.t('6 periode terakhir', 'Last 6 periods'), jp: '比'),
        WaCard(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
          child: SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                maxY: maxY * 1.15,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 3,
                  getDrawingHorizontalLine: (_) => const FlLine(color: WaColors.border, strokeWidth: 1, dashArray: [4, 4]),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, meta) {
                        final p = periods[v.toInt()];
                        final label = switch (type) {
                          'weekly' => fmtDateShort(p.start),
                          'yearly' => '${p.start.year}',
                          _ => monthShort(p.start),
                        };
                        return SideTitleWidget(meta: meta, child: Text(label, style: AppTheme.serif(size: 11, color: WaColors.washiMuted)));
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => WaColors.surfaceHigh,
                    getTooltipItem: (group, _, rod, rodIndex) => BarTooltipItem(
                      '${rodIndex == 0 ? t.t('Masuk', 'In') : t.t('Keluar', 'Out')}\n${m(rod.toY)}',
                      AppTheme.sans(size: 12, weight: FontWeight.w600),
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < bars.length; i++)
                    BarChartGroupData(
                      x: i,
                      barsSpace: 4,
                      barRods: [
                        BarChartRodData(toY: bars[i].income, color: WaColors.income, width: 12, borderRadius: BorderRadius.circular(4)),
                        BarChartRodData(toY: bars[i].expense, color: WaColors.expense, width: 12, borderRadius: BorderRadius.circular(4)),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        SectionHeader(title: t.t('Pengeluaran terbesar', 'Biggest expenses'), jp: '大'),
        WaCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (final x in (txs.where((x) => x.type == 'expense' && f.countsInStats(x)).toList()
                    ..sort((a, b) => f.txBase(b).compareTo(f.txBase(a))))
                  .take(5))
                TransactionTile(tx: x, showDate: true),
              if (txs.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text(t.noData)),
            ],
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.label, required this.value, required this.color, this.delta, this.invert = false});

  final String label;
  final String value;
  final Color color;
  final String? delta;
  final bool invert;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final up = delta?.startsWith('▲') ?? false;
    final down = delta?.startsWith('▼') ?? false;
    final deltaColor = (up && !invert) || (down && invert) ? WaColors.income : (up || down ? WaColors.expense : WaColors.washiMuted);
    return WaCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTheme.serif(size: 12, color: WaColors.washiMuted)),
          const SizedBox(height: 6),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: AppTheme.sans(size: 18, weight: FontWeight.w700, color: color))),
          if (delta != null) ...[
            const SizedBox(height: 2),
            Text('$delta ${t.t('dari sebelumnya', 'vs last')}', style: AppTheme.sans(size: 11, color: deltaColor)),
          ],
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Kategori
// -----------------------------------------------------------------------------

class _CategoryTab extends ConsumerStatefulWidget {
  const _CategoryTab();

  @override
  ConsumerState<_CategoryTab> createState() => _CategoryTabState();
}

class _CategoryTabState extends ConsumerState<_CategoryTab> {
  String _type = 'expense';
  int? _touched;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final s = ref.watch(settingsProvider);
    final f = ref.watch(financeProvider);
    final cats = ref.watch(categoryMapProvider);
    final range = ref.watch(currentRangeProvider);
    final txs = ref.watch(periodTransactionsProvider).value ?? const <TxEntry>[];
    final data = f.breakdown(txs, _type);
    final total = data.fold(0.0, (v, e) => v + e.value);

    Color colorOf(int? id) => Color(cats[id]?.color ?? WaColors.nezumi.toARGB32());
    String nameOf(int? id) => cats[id] == null ? t.noCategory : categoryName(cats[id]!, t);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: 'expense', label: Text(t.expense)),
            ButtonSegment(value: 'income', label: Text(t.income)),
          ],
          selected: {_type},
          onSelectionChanged: (v) => setState(() {
            _type = v.first;
            _touched = null;
          }),
        ),
        const SizedBox(height: 16),
        if (data.isEmpty)
          EmptyState(kanji: '空', title: t.t('Belum ada data di periode ini', 'Nothing recorded in this period'))
        else ...[
          SizedBox(
            height: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 72,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, res) {
                        if (!event.isInterestedForInteractions || res?.touchedSection == null) return;
                        setState(() => _touched = res!.touchedSection!.touchedSectionIndex);
                      },
                    ),
                    sections: [
                      for (var i = 0; i < data.length; i++)
                        PieChartSectionData(
                          value: data[i].value,
                          color: colorOf(data[i].key),
                          radius: _touched == i ? 40 : 32,
                          showTitle: false,
                        ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _touched != null && _touched! < data.length ? nameOf(data[_touched!].key) : 'Total',
                      style: AppTheme.sans(size: 12, color: WaColors.washiMuted),
                    ),
                    Text(
                      formatMoney(_touched != null && _touched! < data.length ? data[_touched!].value : total, s.baseCurrency,
                          compact: true, hidden: s.hideBalance),
                      style: AppTheme.serif(size: 22, weight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          WaCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (final e in data)
                  InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TransactionsScreen(
                          title: nameOf(e.key),
                          initialFilter: TxFilter(
                            from: range.start,
                            to: range.end,
                            type: _type,
                            categoryIds: e.key == null ? const {} : {e.key!},
                          ),
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          KanjiBadge(glyph: cats[e.key]?.icon ?? '他', color: colorOf(e.key), size: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Expanded(child: Text(nameOf(e.key), style: AppTheme.sans(size: 14, weight: FontWeight.w600))),
                                  Text(formatMoney(e.value, s.baseCurrency, hidden: s.hideBalance), style: AppTheme.sans(size: 13, weight: FontWeight.w700)),
                                ]),
                                const SizedBox(height: 6),
                                Row(children: [
                                  Expanded(child: InkBar(value: e.value / total, color: colorOf(e.key), height: 5)),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 42,
                                    child: Text('${(e.value / total * 100).toStringAsFixed(1)}%',
                                        textAlign: TextAlign.end, style: AppTheme.sans(size: 11, color: WaColors.washiMuted)),
                                  ),
                                ]),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Tren kumulatif
// -----------------------------------------------------------------------------

class _TrendTab extends ConsumerWidget {
  const _TrendTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = S.of(context);
    final s = ref.watch(settingsProvider);
    final f = ref.watch(financeProvider);
    final range = ref.watch(currentRangeProvider);
    final type = ref.watch(periodTypeProvider);
    final all = ref.watch(yearTransactionsProvider).value ?? const <TxEntry>[];
    final prevRange = range.shift(-1, type);

    List<FlSpot> cumulative(DateRange r) {
      final daily = f.dailyTotals(all, r, 'expense');
      final spots = <FlSpot>[];
      var acc = 0.0;
      final today = dateOnly(DateTime.now());
      for (var i = 0; i < daily.length; i++) {
        if (r.start.add(Duration(days: i)).isAfter(today)) break;
        acc += daily[i];
        spots.add(FlSpot(i.toDouble(), acc));
      }
      return spots;
    }

    final now = cumulative(range);
    final before = cumulative(prevRange);
    final maxY = [...now.map((e) => e.y), ...before.map((e) => e.y), 1.0].reduce(math.max);
    final daily = f.dailyTotals(all, range, 'expense');
    final weekdayTotals = List<double>.filled(7, 0);
    final weekdayCounts = List<int>.filled(7, 0);
    for (var i = 0; i < daily.length; i++) {
      final d = range.start.add(Duration(days: i));
      if (d.isAfter(DateTime.now())) break;
      weekdayTotals[d.weekday - 1] += daily[i];
      weekdayCounts[d.weekday - 1]++;
    }
    final weekdayAvg = [for (var i = 0; i < 7; i++) weekdayCounts[i] == 0 ? 0.0 : weekdayTotals[i] / weekdayCounts[i]];
    final maxW = [...weekdayAvg, 1.0].reduce(math.max);

    String m(double v) => formatMoney(v, s.baseCurrency, compact: true, hidden: s.hideBalance);

    LineChartBarData line(List<FlSpot> spots, Color color, {bool area = false, bool dashed = false}) => LineChartBarData(
          spots: spots.isEmpty ? [const FlSpot(0, 0)] : spots,
          isCurved: true,
          preventCurveOverShooting: true,
          color: color,
          barWidth: dashed ? 2 : 3,
          dashArray: dashed ? [6, 4] : null,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: area,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0)],
            ),
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        SectionHeader(title: t.t('Total pengeluaran berjalan', 'Running total of spending'), jp: '累'),
        Row(children: [
          _Legend(color: WaColors.expense, label: t.t('Periode ini', 'This period')),
          const SizedBox(width: 16),
          _Legend(color: WaColors.washiMuted, label: t.t('Periode lalu', 'Last period')),
        ]),
        const SizedBox(height: 12),
        WaCard(
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
          child: SizedBox(
            height: 240,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY * 1.1,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (_) => const FlLine(color: WaColors.border, strokeWidth: 1, dashArray: [4, 4]),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      interval: maxY / 4,
                      getTitlesWidget: (v, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text(formatMoney(v, s.baseCurrency, compact: true, symbol: false), style: AppTheme.sans(size: 10, color: WaColors.washiMuted)),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: math.max(1, (range.days / 6).floorToDouble()),
                      getTitlesWidget: (v, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text('${range.start.add(Duration(days: v.toInt())).day}', style: AppTheme.sans(size: 10, color: WaColors.washiMuted)),
                      ),
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => WaColors.surfaceHigh,
                    getTooltipItems: (spots) => spots
                        .map((sp) => LineTooltipItem(m(sp.y), AppTheme.sans(size: 12, weight: FontWeight.w600, color: sp.bar.color)))
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  line(before, WaColors.washiMuted, dashed: true),
                  line(now, WaColors.expense, area: true),
                ],
              ),
            ),
          ),
        ),
        SectionHeader(title: t.t('Rata-rata tiap hari dalam seminggu', 'Average by day of the week'), jp: '曜'),
        WaCard(
          child: Column(
            children: [
              for (var i = 0; i < 7; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    SizedBox(width: 40, child: Text(weekdayShort(i + 1), style: AppTheme.serif(size: 14, weight: FontWeight.w700))),
                    Expanded(child: InkBar(value: weekdayAvg[i] / maxW, height: 8, color: weekdayAvg[i] == maxW ? WaColors.beni : WaColors.accent)),
                    const SizedBox(width: 10),
                    SizedBox(width: 90, child: Text(m(weekdayAvg[i]), textAlign: TextAlign.end, style: AppTheme.sans(size: 12))),
                  ]),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 12, height: 4, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
      ]);
}

// -----------------------------------------------------------------------------
// Kalender heatmap
// -----------------------------------------------------------------------------

class _CalendarTab extends ConsumerWidget {
  const _CalendarTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = S.of(context);
    final s = ref.watch(settingsProvider);
    final f = ref.watch(financeProvider);
    final range = ref.watch(currentRangeProvider);
    final txs = ref.watch(periodTransactionsProvider).value ?? const <TxEntry>[];
    final cal = range.days > 45 ? monthRange(DateTime.now(), startDay: 1) : range;
    final expense = f.dailyTotals(txs, cal, 'expense');
    final income = f.dailyTotals(txs, cal, 'income');
    final maxV = [...expense, 1.0].reduce(math.max);
    final leading = (cal.start.weekday - s.firstWeekday) % 7;
    final labels = [for (var i = 0; i < 7; i++) weekdayShort((s.firstWeekday - 1 + i) % 7 + 1)];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        if (range.days > 45)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(t.t('Kalender menampilkan bulan ini.', 'The calendar shows this month.'), style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
          ),
        Row(children: [
          for (final l in labels)
            Expanded(child: Center(child: Text(l, style: AppTheme.serif(size: 13, color: WaColors.washiMuted, weight: FontWeight.w700)))),
        ]),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 6, crossAxisSpacing: 6, childAspectRatio: 0.8),
          itemCount: leading + cal.days,
          itemBuilder: (_, i) {
            if (i < leading) return const SizedBox.shrink();
            final idx = i - leading;
            final day = cal.start.add(Duration(days: idx));
            final v = expense[idx];
            final intensity = v == 0 ? 0.0 : (0.15 + 0.85 * math.sqrt(v / maxV));
            final isToday = dateOnly(day) == dateOnly(DateTime.now());
            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _showDay(context, ref, day),
              child: Container(
                decoration: BoxDecoration(
                  color: v == 0 ? WaColors.keshizumi : WaColors.beni.withValues(alpha: intensity * 0.75),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isToday ? WaColors.accent : WaColors.border, width: isToday ? 1.5 : 1),
                ),
                padding: const EdgeInsets.all(4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${day.day}', style: AppTheme.serif(size: 13, weight: FontWeight.w700)),
                    const Spacer(),
                    if (income[idx] > 0) Container(width: 6, height: 6, decoration: const BoxDecoration(color: WaColors.income, shape: BoxShape.circle)),
                    if (v > 0)
                      FittedBox(
                        child: Text(formatMoney(v, s.baseCurrency, compact: true, symbol: false, hidden: s.hideBalance),
                            style: AppTheme.sans(size: 10, weight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(t.t('Sedikit', 'Less'), style: AppTheme.sans(size: 11, color: WaColors.washiMuted)),
            for (final a in const [0.12, 0.3, 0.5, 0.75])
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 18,
                height: 12,
                decoration: BoxDecoration(color: WaColors.beni.withValues(alpha: a), borderRadius: BorderRadius.circular(3)),
              ),
            Text(t.t('Banyak', 'More'), style: AppTheme.sans(size: 11, color: WaColors.washiMuted)),
          ],
        ),
      ],
    );
  }

  void _showDay(BuildContext context, WidgetRef ref, DateTime day) {
    final t = S.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Consumer(builder: (ctx, ref, _) {
        final r = dayRange(day);
        final list = ref.watch(transactionsProvider(TxFilter(from: r.start, to: r.end))).value ?? const <TxEntry>[];
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(fmtDateLong(day), style: AppTheme.serif(size: 18, weight: FontWeight.w600)),
              ),
              if (list.isEmpty)
                Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(t.t('Tidak ada transaksi', 'No transactions')))),
              for (final x in list) TransactionTile(tx: x),
              const SizedBox(height: 24),
            ],
          ),
        );
      }),
    );
  }
}

// -----------------------------------------------------------------------------
// Kekayaan bersih
// -----------------------------------------------------------------------------

class _NetWorthTab extends ConsumerWidget {
  const _NetWorthTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = S.of(context);
    final s = ref.watch(settingsProvider);
    final f = ref.watch(financeProvider);
    final all = ref.watch(yearTransactionsProvider).value ?? const <TxEntry>[];
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];

    // Hitung mundur dari saldo sekarang: saldo akhir bulan X = saldo sekarang dikurangi arus kas sesudahnya.
    double flow(TxEntry x) => switch (x.type) {
          'income' => f.txBase(x),
          'expense' => -f.txBase(x),
          _ => -f.toBase(x.fee, f.currencyOf(x.accountId)),
        };
    final now = DateTime.now();
    final points = <(DateTime, double)>[];
    for (var i = 11; i >= 0; i--) {
      final end = DateTime(now.year, now.month - i + 1, 1);
      final after = all.where((x) => !x.date.isBefore(end)).fold(0.0, (v, x) => v + flow(x));
      points.add((DateTime(now.year, now.month - i, 1), f.totalBalance - after));
    }
    final minY = points.map((p) => p.$2).reduce(math.min);
    final maxY = points.map((p) => p.$2).reduce(math.max);
    final pad = math.max(1.0, (maxY - minY) * 0.15);
    final first = points.first.$2;
    final change = f.totalBalance - first;
    final changeText = formatMoney(change.abs(), s.baseCurrency, compact: true, hidden: s.hideBalance);

    final byType = groupBy(accounts.where((a) => !a.archived), (Account a) => a.type);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        WaCard(
          pattern: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.withJp('純資産', t.t('Kekayaan bersih', 'Net worth')), style: AppTheme.serif(size: 13, color: WaColors.accent)),
              const SizedBox(height: 4),
              Text(formatMoney(f.totalBalance, s.baseCurrency, hidden: s.hideBalance), style: AppTheme.serif(size: 28, weight: FontWeight.w700)),
              Text(
                '${change >= 0 ? '▲' : '▼'} $changeText ${t.t('dalam 12 bulan', 'in 12 months')}',
                style: AppTheme.sans(size: 12, color: change >= 0 ? WaColors.income : WaColors.expense),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    minY: minY - pad,
                    maxY: maxY + pad,
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 2,
                          reservedSize: 24,
                          getTitlesWidget: (v, meta) => SideTitleWidget(
                            meta: meta,
                            child: Text(monthShort(points[v.toInt()].$1), style: AppTheme.serif(size: 10, color: WaColors.washiMuted)),
                          ),
                        ),
                      ),
                    ),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => WaColors.surfaceHigh,
                        getTooltipItems: (spots) => spots
                            .map((sp) => LineTooltipItem(
                                  '${fmtMonthYear(points[sp.x.toInt()].$1)}\n${formatMoney(sp.y, s.baseCurrency, compact: true, hidden: s.hideBalance)}',
                                  AppTheme.sans(size: 12, weight: FontWeight.w600),
                                ))
                            .toList(),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].$2)],
                        isCurved: true,
                        preventCurveOverShooting: true,
                        color: WaColors.accent,
                        barWidth: 3,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [WaColors.accent.withValues(alpha: 0.3), WaColors.accent.withValues(alpha: 0)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SectionHeader(title: t.t('Isi kekayaanmu', 'Where your money sits'), jp: '構'),
        WaCard(
          child: Column(
            children: [
              for (final e in byType.entries)
                Builder(builder: (_) {
                  final total = e.value.fold(0.0, (v, a) => v + f.toBase(f.accountBalance(a.id), a.currency));
                  final share = f.assets == 0 ? 0.0 : (total.clamp(0, double.infinity) / f.assets);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      KanjiBadge(glyph: accountTypeGlyph(e.key), color: WaColors.accent, size: 32),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text(accountTypeLabel(t, e.key), style: AppTheme.sans(size: 13, weight: FontWeight.w600))),
                            Text(formatMoney(total, s.baseCurrency, compact: true, hidden: s.hideBalance),
                                style: AppTheme.sans(size: 13, weight: FontWeight.w700, color: total < 0 ? WaColors.expense : WaColors.washi)),
                          ]),
                          const SizedBox(height: 4),
                          InkBar(value: share, height: 5, color: total < 0 ? WaColors.expense : WaColors.accent),
                        ]),
                      ),
                    ]),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Kakeibo: 4 jenis pengeluaran
// -----------------------------------------------------------------------------

class _PillarTab extends ConsumerWidget {
  const _PillarTab();

  static const _colors = {
    'needs': WaColors.ai,
    'wants': WaColors.sakura,
    'culture': WaColors.matcha,
    'unexpected': WaColors.beni,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = S.of(context);
    final s = ref.watch(settingsProvider);
    final f = ref.watch(financeProvider);
    final txs = ref.watch(periodTransactionsProvider).value ?? const <TxEntry>[];
    final pillars = f.pillarBreakdown(txs);
    final total = pillars.values.fold(0.0, (a, b) => a + b);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        Text(
          t.t(
            'Kakeibo membagi pengeluaran jadi 4 jenis. Sebaiknya kebutuhan paling besar, keinginan tetap terkontrol, dan ada sedikit untuk pengembangan diri.',
            'Kakeibo sorts spending into 4 types. Ideally needs take the biggest share, wants stay in check, and a little goes to growing yourself.',
          ),
          style: AppTheme.sans(size: 13, color: WaColors.washiMuted),
        ),
        const SizedBox(height: 16),
        if (total == 0)
          EmptyState(kanji: '簿', title: t.t('Belum ada pengeluaran', 'No spending yet'))
        else ...[
          SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                centerSpaceRadius: 56,
                sectionsSpace: 3,
                sections: [
                  for (final e in pillars.entries.where((e) => e.value > 0))
                    PieChartSectionData(
                      value: e.value,
                      color: _colors[e.key],
                      radius: 44,
                      showTitle: t.jp,
                      title: pillarGlyph(e.key),
                      titleStyle: AppTheme.serif(size: 16, weight: FontWeight.w700, color: WaColors.washi),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final e in pillars.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: WaCard(
                child: Row(children: [
                  KanjiBadge(glyph: pillarGlyph(e.key), color: _colors[e.key]!, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(pillarLabel(t, e.key), style: AppTheme.serif(size: 15, weight: FontWeight.w600))),
                        Text('${(e.value / total * 100).toStringAsFixed(0)}%', style: AppTheme.sans(size: 13, weight: FontWeight.w700, color: _colors[e.key])),
                      ]),
                      Text(formatMoney(e.value, s.baseCurrency, hidden: s.hideBalance), style: AppTheme.sans(size: 13)),
                      const SizedBox(height: 4),
                      Text(pillarDesc(t, e.key), style: AppTheme.sans(size: 11, color: WaColors.washiMuted)),
                    ]),
                  ),
                ]),
              ),
            ),
          Text(
            t.t('Jenis tiap kategori bisa diatur di Lainnya › Kategori.', 'You can set the type of each category in More › Categories.'),
            style: AppTheme.sans(size: 12, color: WaColors.washiMuted),
          ),
        ],
      ],
    );
  }
}
