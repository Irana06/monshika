import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/database/database.dart';
import '../../l10n/strings.dart';
import '../../providers/derived.dart';
import '../../providers/providers.dart';
import '../../services/money_actions.dart';
import '../common/pickers.dart';

Widget _walletLeading(Account? acc) => acc == null
    ? const Icon(Icons.account_balance_wallet_outlined, color: WaColors.washiMuted)
    : KanjiBadge(glyph: acc.icon, color: Color(acc.color), size: 34);

class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = S.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.withJp('貸借', t.t('Utang & piutang', 'Debts'))),
          bottom: TabBar(
            indicatorColor: WaColors.accent,
            labelColor: WaColors.accent,
            unselectedLabelColor: WaColors.washiMuted,
            tabs: [Tab(text: t.t('Dipinjam orang', 'Owed to me')), Tab(text: t.t('Utang saya', 'I owe'))],
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
    final t = S.of(context);
    final debts = (ref.watch(debtsProvider).value ?? const <Debt>[]).where((d) => d.direction == direction).toList();
    final paid = ref.watch(debtPaidProvider).value ?? const {};
    final f = ref.watch(financeProvider);
    final s = ref.watch(settingsProvider);
    final open = debts.where((d) => !d.settled);
    final totalLeft = open.fold(0.0, (v, d) => v + f.toBase(d.amount - (paid[d.id] ?? 0), d.currency));
    final color = direction == 'lend' ? WaColors.income : WaColors.expense;
    final isLend = direction == 'lend';

    if (debts.isEmpty) {
      return EmptyState(
        kanji: isLend ? '貸' : '借',
        title: isLend ? t.t('Tidak ada yang pinjam uangmu', 'Nobody owes you money') : t.t('Kamu tidak punya utang', "You don't owe anything"),
        subtitle: isLend
            ? t.t('Catat uang yang dipinjam teman supaya tidak lupa ditagih.', 'Keep track of money you lend so you remember to collect it.')
            : t.t('Catat utangmu supaya pembayarannya terpantau.', 'Track what you owe so payments stay on schedule.'),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        WaCard(
          pattern: true,
          child: Row(children: [
            KanjiBadge(glyph: isLend ? '貸' : '借', color: color, size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isLend ? t.t('Belum kembali', 'Still out') : t.t('Belum dibayar', 'Still to pay'), style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
                Text(formatMoney(totalLeft, s.baseCurrency, hidden: s.hideBalance), style: AppTheme.serif(size: 24, weight: FontWeight.w700, color: color)),
                Text(t.t('${open.length} belum lunas', '${open.length} open'), style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
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
                                  ? t.t('Lunas ✓', 'Paid off ✓')
                                  : d.dueDate == null
                                      ? t.t('Sejak ${fmtDate(d.date)}', 'Since ${fmtDate(d.date)}')
                                      : overdue
                                          ? t.t('Telat, jatuh tempo ${fmtDate(d.dueDate!)}', 'Overdue since ${fmtDate(d.dueDate!)}')
                                          : t.t('Jatuh tempo ${fmtDate(d.dueDate!)}', 'Due ${fmtDate(d.dueDate!)}'),
                              style: AppTheme.sans(size: 12, color: overdue ? WaColors.expense : WaColors.washiMuted),
                            ),
                          ]),
                        ),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(formatMoney(left, d.currency, hidden: s.hideBalance), style: AppTheme.sans(size: 15, weight: FontWeight.w700, color: color)),
                          Text(t.t('dari ${formatMoney(d.amount, d.currency, compact: true, hidden: s.hideBalance)}', 'of ${formatMoney(d.amount, d.currency, compact: true, hidden: s.hideBalance)}'),
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
    final t = S.of(context);
    final d = (ref.watch(debtsProvider).value ?? const <Debt>[]).where((x) => x.id == debtId).firstOrNull;
    if (d == null) return Scaffold(body: Center(child: Text(t.t('Data tidak ditemukan', 'Not found'))));
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
              if (!await confirmDialog(context,
                  title: t.t('Hapus catatan ini?', 'Delete this record?'),
                  message: t.t('Catatan, pembayaran, dan transaksi dompet yang terkait akan dihapus.', 'The record, its payments, and linked wallet transactions will be deleted.'))) {
                return;
              }
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
              Text(
                isLend
                    ? t.withJp('貸', t.t('${d.person} pinjam uangmu', '${d.person} owes you'))
                    : t.withJp('借', t.t('Kamu pinjam dari ${d.person}', 'You owe ${d.person}')),
                style: AppTheme.sans(size: 12, color: WaColors.washiMuted),
              ),
              const SizedBox(height: 8),
              Text(formatMoney(left, d.currency, hidden: hidden),
                  style: AppTheme.serif(size: 30, weight: FontWeight.w700, color: isLend ? WaColors.income : WaColors.expense)),
              Text(t.t('Sisa dari ${formatMoney(d.amount, d.currency, hidden: hidden)}', 'Left of ${formatMoney(d.amount, d.currency, hidden: hidden)}'),
                  style: AppTheme.sans(size: 13, color: WaColors.washiMuted)),
              const SizedBox(height: 10),
              InkBar(value: d.amount == 0 ? 0 : paid / d.amount, color: WaColors.income, height: 8),
              const SizedBox(height: 10),
              Text(
                '${t.date}: ${fmtDate(d.date)}${d.dueDate != null ? ' · ${t.t('Jatuh tempo', 'Due')} ${fmtDate(d.dueDate!)}' : ''}',
                style: AppTheme.sans(size: 12, color: WaColors.washiMuted),
              ),
              if (d.note.isNotEmpty) Text(d.note, style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
            ]),
          ),
          const SizedBox(height: 12),
          if (!d.settled)
            FilledButton.icon(
              icon: const Icon(Icons.payments_outlined),
              label: Text(isLend ? t.t('Catat uang kembali', 'Record repayment') : t.t('Catat pembayaran', 'Record payment')),
              onPressed: () => _pay(context, ref, d, left),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t.t('Tandai lunas', 'Mark as paid off')),
            value: d.settled,
            onChanged: (v) => MoneyActions(ref.read(databaseProvider)).setDebtSettled(d.id, v),
          ),
          SectionHeader(title: t.t('Riwayat pembayaran', 'Payments'), jp: '歴'),
          if (payments.isEmpty)
            Padding(padding: const EdgeInsets.all(16), child: Center(child: Text(t.t('Belum ada pembayaran', 'No payments yet'))))
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
    final t = S.of(context);
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
            Text(t.t('Pembayaran', 'Payment'), style: AppTheme.serif(size: 18, weight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(prefixText: '${currencyInfo(d.currency).symbol} '),
            ),
            const SizedBox(height: 10),
            PickerTile(
              leading: _walletLeading(acc),
              title: acc?.name ?? t.t('Tanpa dompet (cuma dicatat)', 'No wallet (just record it)'),
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
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t.save)),
          ]),
        );
      }),
    );
    final v = parseAmount(amount.text);
    if (ok != true || v == null || v <= 0) return;
    await MoneyActions(ref.read(databaseProvider)).addDebtPayment(d, amount: v, date: date, accountId: accountId);
    if (context.mounted) await showHanko(context, glyph: '済', label: t.t('Pembayaran dicatat', 'Payment saved'));
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

  // Tenor / cicilan
  bool _useTenor = false;
  final _tenor = TextEditingController(text: '3');
  final _totalPay = TextEditingController();
  DateTime? _firstDue;

  String get _cur => ref.read(accountMapProvider)[_accountId]?.currency ?? _currency;

  int? get _tenorValue {
    final n = int.tryParse(_tenor.text.trim());
    return n == null || n < 2 || n > 360 ? null : n;
  }

  DateTime get _firstDueDate => _firstDue ?? addMonths(_date, 1);

  /// Nominal tiap cicilan. Selisih pembulatan masuk ke cicilan terakhir.
  List<double> _installments(double total, int n) {
    final factor = math.pow(10, currencyInfo(_cur).decimals).toDouble();
    final per = (total / n * factor).floorToDouble() / factor;
    return [for (var i = 0; i < n - 1; i++) per, double.parse((total - per * (n - 1)).toStringAsFixed(currencyInfo(_cur).decimals))];
  }

  Future<void> _save() async {
    final t = S.of(context);
    final amount = parseAmount(_amount.text);
    if (_person.text.trim().isEmpty || amount == null || amount <= 0) {
      return showSnack(context, t.t('Nama dan nominal belum diisi', 'Fill in the name and amount'));
    }
    final actions = MoneyActions(ref.read(databaseProvider));

    if (_useTenor) {
      final n = _tenorValue;
      if (n == null) return showSnack(context, t.t('Tenor paling sedikit 2 bulan', 'Term must be at least 2 months'));
      final total = parseAmount(_totalPay.text) ?? amount;
      if (total < amount) {
        return showSnack(context, t.t('Total bayar tidak boleh lebih kecil dari pinjamannya', "Total to pay can't be less than the loan"));
      }
      await actions.createDebtWithTenor(
        person: _person.text.trim(),
        direction: _direction,
        principal: amount,
        installments: _installments(total, n),
        currency: _cur,
        date: _date,
        firstDueDate: _firstDueDate,
        note: _note.text.trim(),
        accountId: _accountId,
      );
      if (!mounted) return;
      await showHanko(context, glyph: '割', label: t.t('$n cicilan dibuat', '$n installments added'));
    } else {
      await actions.createDebt(
        person: _person.text.trim(),
        direction: _direction,
        amount: amount,
        currency: _cur,
        date: _date,
        dueDate: _due,
        note: _note.text.trim(),
        accountId: _accountId,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final acc = ref.watch(accountMapProvider)[_accountId];
    final cur = acc?.currency ?? _currency;
    final amount = parseAmount(_amount.text) ?? 0;
    final total = parseAmount(_totalPay.text) ?? amount;
    final n = _tenorValue;
    final schedule = _useTenor && n != null && total > 0 ? _installments(total, n) : const <double>[];
    final hidden = ref.watch(settingsProvider).hideBalance;
    String m(double v) => formatMoney(v, cur, hidden: hidden);

    return Scaffold(
      appBar: AppBar(title: Text(t.t('Catatan baru', 'New record'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 'lend', label: Text(t.t('Aku meminjamkan', 'I lent'))),
              ButtonSegment(value: 'borrow', label: Text(t.t('Aku meminjam', 'I borrowed'))),
            ],
            selected: {_direction},
            onSelectionChanged: (v) => setState(() => _direction = v.first),
          ),
          const SizedBox(height: 16),
          LabeledField(
            label: t.t('Nama orang atau layanan', 'Person or service'),
            child: TextField(
              controller: _person,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(hintText: t.t('Contoh: Budi, GoPayLater, Kredivo', 'e.g. Alex, Klarna, Affirm')),
            ),
          ),
          LabeledField(
            label: t.t('Nominal pinjaman', 'Loan amount'),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(prefixText: '${currencyInfo(cur).symbol} '),
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
            label: _direction == 'lend'
                ? t.t('Uangnya keluar dari dompet (opsional)', 'Taken from wallet (optional)')
                : t.t('Uangnya masuk ke dompet (opsional)', 'Added to wallet (optional)'),
            child: PickerTile(
              leading: _walletLeading(acc),
              title: acc?.name ?? t.t('Tidak dicatat ke dompet', "Don't record in a wallet"),
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
                label: Text('${t.date} ${fmtDateShort(_date)}'),
                onPressed: () async {
                  final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: DateTime.now());
                  if (d != null) setState(() => _date = d);
                },
              ),
            ),
            if (!_useTenor) ...[
              const SizedBox(width: 8),
              Expanded(
                child: ActionChip(
                  avatar: const Icon(Icons.alarm, size: 16),
                  label: Text(_due == null ? t.t('Jatuh tempo', 'Due date') : fmtDateShort(_due!)),
                  onPressed: () async {
                    // Tenggat boleh di masa lalu (utang lama). Default: tanggal utang + 1 bulan.
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _due ?? addMonths(_date, 1),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 30)),
                    );
                    setState(() => _due = d);
                  },
                ),
              ),
            ],
          ]),
          const SizedBox(height: 8),
          WaCard(
            padding: const EdgeInsets.fromLTRB(16, 4, 12, 12),
            borderColor: _useTenor ? WaColors.accent.withValues(alpha: 0.5) : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _useTenor,
                  onChanged: (v) => setState(() => _useTenor = v),
                  title: Text(t.t('Dicicil', 'Pay in installments'), style: AppTheme.sans(size: 15, weight: FontWeight.w600)),
                  subtitle: Text(
                    t.t('Langsung dibagi jadi cicilan bulanan, masing-masing dengan tanggal jatuh tempo dan pengingat.',
                        'Split into monthly installments, each with its own due date and reminder.'),
                    style: AppTheme.sans(size: 12, color: WaColors.washiMuted),
                  ),
                ),
                if (_useTenor) ...[
                  Row(children: [
                    SizedBox(
                      width: 110,
                      child: TextField(
                        controller: _tenor,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(labelText: t.t('Tenor', 'Term'), suffixText: t.t('bulan', 'mo')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ActionChip(
                        avatar: const Icon(Icons.event, size: 16),
                        label: Text(t.t('Cicilan pertama ${fmtDateShort(_firstDueDate)}', 'First due ${fmtDateShort(_firstDueDate)}')),
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _firstDueDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now().add(const Duration(days: 365 * 30)),
                          );
                          if (d != null) setState(() => _firstDue = d);
                        },
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _totalPay,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: t.t('Total yang harus dibayar (opsional)', 'Total to pay back (optional)'),
                      helperText: t.t('Isi kalau ada bunga atau biaya admin. Kosongkan kalau sama dengan pinjaman.',
                          'Fill this in if there is interest or a fee. Leave empty if it matches the loan.'),
                      prefixText: '${currencyInfo(cur).symbol} ',
                    ),
                  ),
                  if (n == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(t.t('Tenor paling sedikit 2 bulan', 'Term must be at least 2 months'), style: AppTheme.sans(size: 12, color: WaColors.expense)),
                    )
                  else if (schedule.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      '$n× ${m(schedule.first)} / ${t.t('bulan', 'month')}'
                      '${total > amount && amount > 0 ? ' · ${t.t('bunga/biaya', 'interest/fees')} ${m(total - amount)}' : ''}',
                      style: AppTheme.serif(size: 15, weight: FontWeight.w600, color: WaColors.accent),
                    ),
                    const SizedBox(height: 6),
                    for (var i = 0; i < math.min(schedule.length, 12); i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(children: [
                          SizedBox(width: 44, child: Text('${i + 1}/$n', style: AppTheme.sans(size: 12, color: WaColors.washiMuted))),
                          Expanded(child: Text(fmtDate(addMonths(_firstDueDate, i)), style: AppTheme.sans(size: 12))),
                          Text(m(schedule[i]), style: AppTheme.sans(size: 12, weight: FontWeight.w600)),
                        ]),
                      ),
                    if (schedule.length > 12)
                      Text(
                        t.t('dan ${schedule.length - 12} cicilan lagi sampai ${fmtDate(addMonths(_firstDueDate, n - 1))}',
                            'and ${schedule.length - 12} more until ${fmtDate(addMonths(_firstDueDate, n - 1))}'),
                        style: AppTheme.sans(size: 12, color: WaColors.washiMuted),
                      ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          LabeledField(label: t.note, child: TextField(controller: _note, maxLines: 2)),
          FilledButton(
            onPressed: _save,
            child: Text(_useTenor && n != null ? t.t('Simpan $n cicilan', 'Save $n installments') : t.save),
          ),
        ],
      ),
    );
  }
}
