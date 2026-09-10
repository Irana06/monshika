import 'package:flutter/material.dart';
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
import '../common/pickers.dart';

class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Utang & Piutang · 貸借'),
          bottom: const TabBar(
            indicatorColor: WaColors.accent,
            labelColor: WaColors.accent,
            unselectedLabelColor: WaColors.washiMuted,
            tabs: [Tab(text: 'Piutang (dipinjam orang)'), Tab(text: 'Utang saya')],
          ),
        ),
        floatingActionButton: Builder(
          builder: (ctx) => FloatingActionButton(
            heroTag: 'add-debt',
            onPressed: () => Navigator.push(
              ctx,
              MaterialPageRoute(builder: (_) => DebtFormScreen(direction: DefaultTabController.of(ctx).index == 0 ? 'lend' : 'borrow')),
            ),
            child: const Icon(Icons.add),
          ),
        ),
        body: const TabBarView(children: [_DebtList(direction: 'lend'), _DebtList(direction: 'borrow')]),
      ),
    );
  }
}

class _DebtList extends ConsumerWidget {
  const _DebtList({required this.direction});

  final String direction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debts = (ref.watch(debtsProvider).value ?? const <Debt>[]).where((d) => d.direction == direction).toList();
    final paid = ref.watch(debtPaidProvider).value ?? const {};
    final f = ref.watch(financeProvider);
    final s = ref.watch(settingsProvider);
    final open = debts.where((d) => !d.settled);
    final totalLeft = open.fold(0.0, (v, d) => v + f.toBase(d.amount - (paid[d.id] ?? 0), d.currency));
    final color = direction == 'lend' ? WaColors.income : WaColors.expense;

    if (debts.isEmpty) {
      return EmptyState(
        kanji: direction == 'lend' ? '貸' : '借',
        title: direction == 'lend' ? 'Tidak ada piutang' : 'Tidak ada utang',
        subtitle: direction == 'lend' ? 'Catat uang yang dipinjam teman supaya tidak lupa ditagih.' : 'Catat utang agar pembayaran terpantau.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        WaCard(
          pattern: true,
          child: Row(children: [
            KanjiBadge(glyph: direction == 'lend' ? '貸' : '借', color: color, size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(direction == 'lend' ? 'Total belum kembali' : 'Total belum dibayar', style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
                Text(formatMoney(totalLeft, s.baseCurrency, hidden: s.hideBalance), style: AppTheme.serif(size: 24, weight: FontWeight.w700, color: color)),
                Text('${open.length} catatan aktif', style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        for (final d in debts)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Opacity(
              opacity: d.settled ? 0.55 : 1,
              child: WaCard(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DebtDetailScreen(debtId: d.id))),
                child: Builder(builder: (_) {
                  final p = paid[d.id] ?? 0;
                  final left = d.amount - p;
                  final overdue = !d.settled && d.dueDate != null && d.dueDate!.isBefore(dateOnly(DateTime.now()));
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: color.withValues(alpha: 0.15),
                          child: Text(d.person.isEmpty ? '?' : d.person[0].toUpperCase(), style: AppTheme.serif(size: 16, color: color, weight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(d.person, style: AppTheme.sans(size: 15, weight: FontWeight.w600)),
                            Text(
                              d.settled
                                  ? 'Lunas ✓'
                                  : d.dueDate == null
                                      ? 'Sejak ${fmtDate(d.date)}'
                                      : '${overdue ? 'Lewat jatuh tempo' : 'Jatuh tempo'} ${fmtDate(d.dueDate!)}',
                              style: AppTheme.sans(size: 12, color: overdue ? WaColors.expense : WaColors.washiMuted),
                            ),
                          ]),
                        ),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(formatMoney(left, d.currency, hidden: s.hideBalance), style: AppTheme.sans(size: 15, weight: FontWeight.w700, color: color)),
                          Text('dari ${formatMoney(d.amount, d.currency, compact: true, hidden: s.hideBalance)}',
                              style: AppTheme.sans(size: 11, color: WaColors.washiMuted)),
                        ]),
                      ]),
                      const SizedBox(height: 10),
                      InkBar(value: d.amount == 0 ? 0 : p / d.amount, color: WaColors.income),
                      if (d.note.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(d.note, style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
                      ],
                    ],
                  );
                }),
              ),
            ),
          ),
      ],
    );
  }
}

final _paymentsProvider = StreamProvider.family<List<DebtPayment>, int>((ref, id) => ref.watch(databaseProvider).watchDebtPayments(id));

class DebtDetailScreen extends ConsumerWidget {
  const DebtDetailScreen({super.key, required this.debtId});

  final int debtId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = (ref.watch(debtsProvider).value ?? const <Debt>[]).where((x) => x.id == debtId).firstOrNull;
    if (d == null) return const Scaffold(body: Center(child: Text('Data tidak ditemukan')));
    final payments = ref.watch(_paymentsProvider(d.id)).value ?? const <DebtPayment>[];
    final paid = payments.fold(0.0, (v, p) => v + p.amount);
    final left = d.amount - paid;
    final hidden = ref.watch(settingsProvider).hideBalance;
    final isLend = d.direction == 'lend';

    return Scaffold(
      appBar: AppBar(
        title: Text(d.person),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (!await confirmDialog(context, title: 'Hapus catatan?', message: 'Catatan, pembayaran, dan transaksi dompet terkait akan dihapus.')) return;
              await ref.read(databaseProvider).deleteDebt(d.id);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          WaCard(
            pattern: true,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isLend ? '貸 Piutang — ${d.person} berutang padamu' : '借 Utang — kamu berutang ke ${d.person}',
                  style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
              const SizedBox(height: 8),
              Text(formatMoney(left, d.currency, hidden: hidden),
                  style: AppTheme.serif(size: 30, weight: FontWeight.w700, color: isLend ? WaColors.income : WaColors.expense)),
              Text('Sisa dari ${formatMoney(d.amount, d.currency, hidden: hidden)}', style: AppTheme.sans(size: 13, color: WaColors.washiMuted)),
              const SizedBox(height: 10),
              InkBar(value: d.amount == 0 ? 0 : paid / d.amount, color: WaColors.income, height: 8),
              const SizedBox(height: 10),
              Text('Tanggal: ${fmtDate(d.date)}${d.dueDate != null ? ' · Jatuh tempo ${fmtDate(d.dueDate!)}' : ''}',
                  style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
              if (d.note.isNotEmpty) Text(d.note, style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
            ]),
          ),
          const SizedBox(height: 12),
          if (!d.settled)
            FilledButton.icon(
              icon: const Icon(Icons.payments_outlined),
              label: Text(isLend ? 'Catat uang kembali' : 'Catat pembayaran'),
              onPressed: () => _pay(context, ref, d, left),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tandai lunas'),
            value: d.settled,
            onChanged: (v) => MoneyActions(ref.read(databaseProvider)).setDebtSettled(d.id, v),
          ),
          const SectionHeader(title: 'Riwayat pembayaran', jp: '歴'),
          if (payments.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('Belum ada pembayaran')))
          else
            WaCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                for (final p in payments)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.check_circle_outline, color: WaColors.income),
                    title: Text(formatMoney(p.amount, d.currency, hidden: hidden), style: AppTheme.sans(weight: FontWeight.w700)),
                    subtitle: Text('${fmtDate(p.date)}${p.note.isEmpty ? '' : ' · ${p.note}'}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () async {
                        final db = ref.read(databaseProvider);
                        if (p.transactionId != null) {
                          await db.deleteTransaction(p.transactionId!);
                        } else {
                          await (db.delete(db.debtPayments)..where((x) => x.id.equals(p.id))).go();
                        }
                        await MoneyActions(db).setDebtSettled(d.id, false);
                      },
                    ),
                  ),
              ]),
            ),
        ],
      ),
    );
  }

  Future<void> _pay(BuildContext context, WidgetRef ref, Debt d, double left) async {
    final amount = TextEditingController(text: left.toStringAsFixed(currencyInfo(d.currency).decimals));
    int? accountId = d.accountId;
    DateTime date = DateTime.now();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        final acc = ref.read(accountMapProvider)[accountId];
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Pembayaran', style: AppTheme.serif(size: 18, weight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(prefixText: '${currencyInfo(d.currency).symbol} '),
            ),
            const SizedBox(height: 10),
            PickerTile(
              leading: KanjiBadge(glyph: acc?.icon ?? '―', color: Color(acc?.color ?? WaColors.nezumi.toARGB32()), size: 34),
              title: acc?.name ?? 'Tanpa dompet (catat saja)',
              onTap: () async {
                final id = await showAccountPicker(ctx, ref, selectedId: accountId);
                setSheet(() => accountId = id);
              },
            ),
            const SizedBox(height: 10),
            ActionChip(
              avatar: const Icon(Icons.calendar_today, size: 16),
              label: Text(fmtDate(date)),
              onPressed: () async {
                final picked = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime.now());
                if (picked != null) setSheet(() => date = picked);
              },
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
          ]),
        );
      }),
    );
    final v = parseAmount(amount.text);
    if (ok != true || v == null || v <= 0) return;
    await MoneyActions(ref.read(databaseProvider)).addDebtPayment(d, amount: v, date: date, accountId: accountId);
    if (context.mounted) await showHanko(context, glyph: '済', label: 'Pembayaran tercatat');
  }
}

class DebtFormScreen extends ConsumerStatefulWidget {
  const DebtFormScreen({super.key, this.direction = 'lend'});

  final String direction;

  @override
  ConsumerState<DebtFormScreen> createState() => _DebtFormScreenState();
}

class _DebtFormScreenState extends ConsumerState<DebtFormScreen> {
  late String _direction = widget.direction;
  final _person = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late String _currency = ref.read(settingsProvider).baseCurrency;
  DateTime _date = DateTime.now();
  DateTime? _due;
  int? _accountId;

  Future<void> _save() async {
    final amount = parseAmount(_amount.text);
    if (_person.text.trim().isEmpty || amount == null || amount <= 0) return showSnack(context, 'Isi nama & nominal');
    await MoneyActions(ref.read(databaseProvider)).createDebt(
      person: _person.text.trim(),
      direction: _direction,
      amount: amount,
      currency: _accountId == null ? _currency : ref.read(accountMapProvider)[_accountId]!.currency,
      date: _date,
      dueDate: _due,
      note: _note.text.trim(),
      accountId: _accountId,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final acc = ref.watch(accountMapProvider)[_accountId];
    return Scaffold(
      appBar: AppBar(title: const Text('Catatan Baru')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'lend', label: Text('Saya meminjamkan')),
              ButtonSegment(value: 'borrow', label: Text('Saya meminjam')),
            ],
            selected: {_direction},
            onSelectionChanged: (v) => setState(() => _direction = v.first),
          ),
          const SizedBox(height: 16),
          LabeledField(label: 'Nama orang', child: TextField(controller: _person, textCapitalization: TextCapitalization.words)),
          LabeledField(
            label: 'Nominal',
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(prefixText: '${currencyInfo(acc?.currency ?? _currency).symbol} '),
                ),
              ),
              if (acc == null) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () async {
                    final c = await pickCurrency(context, current: _currency);
                    if (c != null) setState(() => _currency = c);
                  },
                  child: Text(_currency),
                ),
              ],
            ]),
          ),
          LabeledField(
            label: _direction == 'lend' ? 'Uang keluar dari dompet (opsional)' : 'Uang masuk ke dompet (opsional)',
            child: PickerTile(
              leading: KanjiBadge(glyph: acc?.icon ?? '―', color: Color(acc?.color ?? WaColors.nezumi.toARGB32()), size: 34),
              title: acc?.name ?? 'Tidak dicatat ke dompet',
              onTap: () async {
                final id = await showAccountPicker(context, ref, selectedId: _accountId);
                setState(() => _accountId = id);
              },
            ),
          ),
          Row(children: [
            Expanded(
              child: ActionChip(
                avatar: const Icon(Icons.calendar_today, size: 16),
                label: Text('Tanggal ${fmtDateShort(_date)}'),
                onPressed: () async {
                  final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: DateTime.now());
                  if (d != null) setState(() => _date = d);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ActionChip(
                avatar: const Icon(Icons.alarm, size: 16),
                label: Text(_due == null ? 'Jatuh tempo' : fmtDateShort(_due!)),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _due ?? DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  setState(() => _due = d);
                },
              ),
            ),
          ]),
          const SizedBox(height: 16),
          LabeledField(label: 'Catatan', child: TextField(controller: _note, maxLines: 2)),
          FilledButton(onPressed: _save, child: const Text('Simpan')),
        ],
      ),
    );
  }
}
