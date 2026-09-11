import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/database/database.dart';
import '../../providers/providers.dart';
import '../../services/money_actions.dart';
import '../common/pickers.dart';

/// Jimat omamori (お守り) yang terisi sesuai progres tabungan.
class Omamori extends StatelessWidget {
  const Omamori({super.key, required this.progress, required this.color, required this.glyph, this.width = 90});

  final double progress;
  final Color color;
  final String glyph;
  final double width;

  @override
  Widget build(BuildContext context) {
    final h = width * 1.45;
    final p = progress.clamp(0, 1).toDouble();
    return SizedBox(
      width: width,
      height: h + width * 0.28,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // tali
          Positioned(
            top: 0,
            child: Container(
              width: width * 0.3,
              height: width * 0.3,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 3)),
            ),
          ),
          Positioned(
            top: width * 0.24,
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(width * 0.35), bottom: Radius.circular(width * 0.08)),
              child: Container(
                width: width,
                height: h,
                decoration: BoxDecoration(color: WaColors.surfaceHigh, border: Border.all(color: color.withValues(alpha: 0.5))),
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: p),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, _) => Container(
                          height: h * v,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0.9)],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(child: CustomPaint(painter: SeigaihaPainter(color: WaColors.washi.withValues(alpha: 0.06), radius: width * 0.14))),
                    Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: width * 0.08, horizontal: width * 0.06),
                        decoration: BoxDecoration(color: WaColors.sumi.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(4)),
                        child: Text(glyph, style: AppTheme.serif(size: width * 0.3, weight: FontWeight.w700, color: WaColors.washi)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = (ref.watch(goalsProvider).value ?? const <Goal>[]).where((g) => !g.archived).toList();
    final saved = ref.watch(goalSavedProvider).value ?? const {};
    final hidden = ref.watch(settingsProvider).hideBalance;

    return Scaffold(
      appBar: AppBar(title: const Text('Target · 夢')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add-goal',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalFormScreen())),
        child: const Icon(Icons.add),
      ),
      body: goals.isEmpty
          ? EmptyState(
              kanji: '夢',
              title: 'Belum ada target',
              subtitle: 'Nabung untuk HP baru, liburan ke Jepang, dana darurat…',
              action: 'Buat target',
              onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalFormScreen())),
            )
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.62,
              ),
              itemCount: goals.length,
              itemBuilder: (_, i) {
                final g = goals[i];
                final s = saved[g.id] ?? 0;
                final p = g.targetAmount <= 0 ? 0.0 : s / g.targetAmount;
                return WaCard(
                  padding: const EdgeInsets.all(12),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GoalDetailScreen(goalId: g.id))),
                  child: Column(
                    children: [
                      Row(children: [
                        if (g.pinned) const Icon(Icons.push_pin, size: 14, color: WaColors.accent),
                        const Spacer(),
                        if (g.completedAt != null) Text('達成', style: AppTheme.serif(size: 12, color: WaColors.income, weight: FontWeight.w700)),
                      ]),
                      Expanded(child: FittedBox(child: Omamori(progress: p, color: Color(g.color), glyph: g.icon))),
                      const SizedBox(height: 8),
                      Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.serif(size: 15, weight: FontWeight.w600)),
                      Text('${(p * 100).clamp(0, 999).toStringAsFixed(0)}% · ${formatMoney(s, g.currency, compact: true, hidden: hidden)}',
                          style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
                      const SizedBox(height: 6),
                      InkBar(value: p, color: Color(g.color)),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class GoalDetailScreen extends ConsumerWidget {
  const GoalDetailScreen({super.key, required this.goalId});

  final int goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = (ref.watch(goalsProvider).value ?? const <Goal>[]).where((x) => x.id == goalId).firstOrNull;
    if (g == null) return const Scaffold(body: Center(child: Text('Target tidak ditemukan')));
    final saved = (ref.watch(goalSavedProvider).value ?? const {})[g.id] ?? 0;
    final entries = ref.watch(_entriesProvider(g.id)).value ?? const <GoalEntry>[];
    final hidden = ref.watch(settingsProvider).hideBalance;
    final p = g.targetAmount <= 0 ? 0.0 : saved / g.targetAmount;
    final left = math.max(0.0, g.targetAmount - saved);
    String? plan;
    if (g.deadline != null && left > 0) {
      final days = g.deadline!.difference(DateTime.now()).inDays;
      if (days <= 0) {
        plan = 'Tenggat sudah lewat';
      } else {
        final months = math.max(1, (days / 30.4).ceil());
        plan = 'Nabung ${formatMoney(left / months, g.currency, compact: true, hidden: hidden)}/bulan '
            'atau ${formatMoney(left / math.max(1, days / 7), g.currency, compact: true, hidden: hidden)}/minggu agar tercapai ${fmtDate(g.deadline!)}';
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(g.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GoalFormScreen(existing: g))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Center(child: Omamori(progress: p, color: Color(g.color), glyph: g.icon, width: 130)),
          const SizedBox(height: 16),
          Center(child: Text('${(p * 100).toStringAsFixed(1)}%', style: AppTheme.serif(size: 30, weight: FontWeight.w700))),
          Center(
            child: Text(
              '${formatMoney(saved, g.currency, hidden: hidden)} dari ${formatMoney(g.targetAmount, g.currency, hidden: hidden)}',
              style: AppTheme.sans(color: WaColors.washiMuted),
            ),
          ),
          if (plan != null) ...[
            const SizedBox(height: 12),
            WaCard(child: Row(children: [
              const Icon(Icons.lightbulb_outline, color: WaColors.accent),
              const SizedBox(width: 10),
              Expanded(child: Text(plan, style: AppTheme.sans(size: 13))),
            ])),
          ],
          if (g.completedAt != null) ...[
            const SizedBox(height: 12),
            Center(child: Text('🎉 目標達成 — Target tercapai ${fmtDate(g.completedAt!)}', style: AppTheme.serif(size: 15, color: WaColors.income))),
          ],
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _entry(context, ref, g, deposit: true),
                icon: const Icon(Icons.add),
                label: const Text('Setor'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _entry(context, ref, g, deposit: false),
                icon: const Icon(Icons.remove),
                label: const Text('Tarik'),
              ),
            ),
          ]),
          const SectionHeader(title: 'Riwayat setoran', jp: '歴'),
          if (entries.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('Belum ada setoran')))
          else
            WaCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final e in entries)
                    ListTile(
                      dense: true,
                      leading: Icon(e.amount >= 0 ? Icons.south_west : Icons.north_east, color: e.amount >= 0 ? WaColors.income : WaColors.expense),
                      title: Text(formatMoney(e.amount, g.currency, showSign: true, hidden: hidden),
                          style: AppTheme.sans(weight: FontWeight.w700, color: e.amount >= 0 ? WaColors.income : WaColors.expense)),
                      subtitle: Text('${fmtDate(e.date)}${e.note.isEmpty ? '' : ' · ${e.note}'}', style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () async {
                          final db = ref.read(databaseProvider);
                          if (e.transactionId != null) {
                            await db.deleteTransaction(e.transactionId!);
                          } else {
                            await (db.delete(db.goalEntries)..where((x) => x.id.equals(e.id))).go();
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _entry(BuildContext context, WidgetRef ref, Goal g, {required bool deposit}) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    int? accountId;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        final acc = ref.read(accountMapProvider)[accountId];
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(deposit ? 'Setor ke ${g.name}' : 'Tarik dari ${g.name}', style: AppTheme.serif(size: 18, weight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(prefixText: '${currencyInfo(g.currency).symbol} ', hintText: 'Nominal'),
            ),
            const SizedBox(height: 10),
            TextField(controller: note, decoration: const InputDecoration(hintText: 'Catatan (opsional)')),
            const SizedBox(height: 10),
            PickerTile(
              leading: KanjiBadge(glyph: acc?.icon ?? '―', color: Color(acc?.color ?? WaColors.nezumi.toARGB32()), size: 34),
              title: acc?.name ?? 'Tanpa dompet (catat saja)',
              subtitle: 'Jika dipilih, saldo dompet ikut ${deposit ? 'berkurang' : 'bertambah'}',
              onTap: () async {
                final id = await showAccountPicker(ctx, ref, selectedId: accountId);
                setSheet(() => accountId = id);
              },
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
          ]),
        );
      }),
    );
    final value = parseAmount(amount.text);
    if (ok != true || value == null || value <= 0) return;
    await MoneyActions(ref.read(databaseProvider)).addGoalEntry(
      g,
      amount: deposit ? value : -value,
      date: DateTime.now(),
      accountId: accountId,
      note: note.text.trim(),
    );
    if (context.mounted && deposit) await showHanko(context, glyph: '貯', label: 'Tersimpan');
  }
}

final _entriesProvider = StreamProvider.family<List<GoalEntry>, int>((ref, id) => ref.watch(databaseProvider).watchGoalEntries(id));

class GoalFormScreen extends ConsumerStatefulWidget {
  const GoalFormScreen({super.key, this.existing});

  final Goal? existing;

  @override
  ConsumerState<GoalFormScreen> createState() => _GoalFormScreenState();
}

class _GoalFormScreenState extends ConsumerState<GoalFormScreen> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _target = TextEditingController(text: widget.existing?.targetAmount.toStringAsFixed(0) ?? '');
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late String _currency = widget.existing?.currency ?? ref.read(settingsProvider).baseCurrency;
  late DateTime? _deadline = widget.existing?.deadline;
  late String _icon = widget.existing?.icon ?? '夢';
  late int _color = widget.existing?.color ?? WaColors.sakura.toARGB32();
  late bool _pinned = widget.existing?.pinned ?? false;
  late bool _archived = widget.existing?.archived ?? false;

  Future<void> _save() async {
    final target = parseAmount(_target.text);
    if (_name.text.trim().isEmpty || target == null || target <= 0) return showSnack(context, 'Isi nama & nominal target');
    final db = ref.read(databaseProvider);
    if (_pinned) {
      await (db.update(db.goals)).write(const GoalsCompanion(pinned: Value(false)));
    }
    await db.saveGoal(GoalsCompanion(
      id: widget.existing == null ? const Value.absent() : Value(widget.existing!.id),
      name: Value(_name.text.trim()),
      targetAmount: Value(target),
      currency: Value(_currency),
      deadline: Value(_deadline),
      icon: Value(_icon),
      color: Value(_color),
      note: Value(_note.text.trim()),
      pinned: Value(_pinned),
      archived: Value(_archived),
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Target Baru' : 'Ubah Target'),
        actions: [
          if (widget.existing != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (!await confirmDialog(context, title: 'Hapus target?', message: 'Riwayat setoran ikut terhapus (transaksi dompet tetap).')) return;
                await ref.read(databaseProvider).deleteGoal(widget.existing!.id);
                if (context.mounted) Navigator.of(context)..pop()..maybePop();
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: GestureDetector(
              onTap: () async {
                final k = await pickKanji(context, current: _icon, color: Color(_color));
                if (k != null) setState(() => _icon = k);
              },
              child: Omamori(progress: 0.5, color: Color(_color), glyph: _icon, width: 80),
            ),
          ),
          const SizedBox(height: 16),
          LabeledField(label: 'Nama target', child: TextField(controller: _name, decoration: const InputDecoration(hintText: 'mis. Liburan ke Kyoto'))),
          LabeledField(
            label: 'Nominal target',
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _target,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(prefixText: '${currencyInfo(_currency).symbol} '),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () async {
                  final c = await pickCurrency(context, current: _currency);
                  if (c != null) setState(() => _currency = c);
                },
                child: Text(_currency),
              ),
            ]),
          ),
          LabeledField(
            label: 'Tenggat (opsional)',
            child: PickerTile(
              leading: const Icon(Icons.event, color: WaColors.accent),
              title: _deadline == null ? 'Tanpa tenggat' : fmtDateLong(_deadline!),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _deadline ?? DateTime.now().add(const Duration(days: 180)),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 30)),
                );
                setState(() => _deadline = d);
              },
            ),
          ),
          LabeledField(label: 'Warna', child: ColorPickerRow(value: _color, onChanged: (c) => setState(() => _color = c))),
          LabeledField(label: 'Catatan', child: TextField(controller: _note, maxLines: 2)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Sematkan di widget beranda'),
            value: _pinned,
            onChanged: (v) => setState(() => _pinned = v),
          ),
          if (widget.existing != null)
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Arsipkan'), value: _archived, onChanged: (v) => setState(() => _archived = v)),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Simpan')),
        ],
      ),
    );
  }
}
