import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/database/database.dart';
import '../../l10n/strings.dart';
import '../../providers/providers.dart';
import '../../services/finance.dart';
import '../../services/money_actions.dart';
import '../common/pickers.dart';

class InstallmentsScreen extends ConsumerWidget {
  const InstallmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = S.of(context);
    final items = ref.watch(installmentsProvider).value ?? const <Installment>[];
    final accounts = ref.watch(accountMapProvider);
    final s = ref.watch(settingsProvider);
    final active = items.where((i) => i.active);
    final monthly = active.fold(0.0, (v, i) => v + i.monthlyAmount);
    final remaining = active.fold(0.0, (v, i) => v + i.monthlyAmount * (i.tenor - i.paidCount));

    return Scaffold(
      appBar: AppBar(title: Text(t.withJp('分割', t.t('Cicilan', 'Installments')))),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add-inst',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InstallmentFormScreen())),
        child: const Icon(Icons.add),
      ),
      body: items.isEmpty
          ? EmptyState(
              kanji: '返',
              title: t.t('Belum ada cicilan', 'No installments yet'),
              subtitle: t.t('Kartu kredit, paylater, KPR, kendaraan, atau gadget.', 'Credit cards, pay later, mortgage, car, or gadgets.'),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              children: [
                WaCard(
                  pattern: true,
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t.t('Cicilan per bulan', 'Per month'), style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
                        Text(formatMoney(monthly, s.baseCurrency, hidden: s.hideBalance), style: AppTheme.serif(size: 22, weight: FontWeight.w700, color: WaColors.expense)),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(t.t('Sisa semuanya', 'Total left'), style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
                      Text(formatMoney(remaining, s.baseCurrency, compact: true, hidden: s.hideBalance), style: AppTheme.serif(size: 18, weight: FontWeight.w700)),
                    ]),
                  ]),
                ),
                const SizedBox(height: 12),
                for (final i in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Opacity(
                      opacity: i.active ? 1 : 0.55,
                      child: WaCard(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InstallmentFormScreen(existing: i))),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            const KanjiBadge(glyph: '返', color: WaColors.momiji, size: 42),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(i.name, style: AppTheme.sans(size: 15, weight: FontWeight.w600)),
                                Text(
                                  i.active
                                      ? t.t('Ke-${i.paidCount + 1} dari ${i.tenor} · jatuh tempo ${fmtRelativeDay(installmentDueDate(i))}',
                                          '${i.paidCount + 1} of ${i.tenor} · due ${fmtRelativeDay(installmentDueDate(i))}')
                                      : t.t('Lunas ✓', 'Paid off ✓'),
                                  style: AppTheme.sans(size: 12, color: WaColors.washiMuted),
                                ),
                                if (i.accountId != null)
                                  Text(accounts[i.accountId]?.name ?? '', style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
                              ]),
                            ),
                            Text(formatMoney(i.monthlyAmount, accounts[i.accountId]?.currency ?? s.baseCurrency, hidden: s.hideBalance),
                                style: AppTheme.sans(size: 14, weight: FontWeight.w700)),
                          ]),
                          const SizedBox(height: 10),
                          InkBar(value: i.paidCount / i.tenor, color: WaColors.income, height: 7),
                          if (i.active)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                icon: const Icon(Icons.payments_outlined, size: 18),
                                label: Text(t.t('Bayar cicilan', 'Pay installment')),
                                onPressed: () async {
                                  final accountId = i.accountId ?? await showAccountPicker(context, ref, title: t.t('Bayar pakai', 'Pay from'));
                                  if (accountId == null) return;
                                  await MoneyActions(ref.read(databaseProvider)).payInstallment(i, accountId: accountId);
                                  if (context.mounted) await showHanko(context, glyph: '済', label: t.t('Cicilan dibayar', 'Installment paid'));
                                },
                              ),
                            ),
                        ]),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class InstallmentFormScreen extends ConsumerStatefulWidget {
  const InstallmentFormScreen({super.key, this.existing});

  final Installment? existing;

  @override
  ConsumerState<InstallmentFormScreen> createState() => _InstallmentFormScreenState();
}

class _InstallmentFormScreenState extends ConsumerState<InstallmentFormScreen> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _principal = TextEditingController(text: widget.existing?.principal.toStringAsFixed(0) ?? '');
  late final _monthly = TextEditingController(text: widget.existing?.monthlyAmount.toStringAsFixed(0) ?? '');
  late final _rate = TextEditingController(text: widget.existing == null || widget.existing!.interestRate == 0 ? '' : '${widget.existing!.interestRate}');
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late int _tenor = widget.existing?.tenor ?? 12;
  late int _paid = widget.existing?.paidCount ?? 0;
  late int _dueDay = widget.existing?.dueDay ?? DateTime.now().day;
  late DateTime _start = widget.existing?.startDate ?? DateTime.now();
  late int? _accountId = widget.existing?.accountId;
  late int? _categoryId = widget.existing?.categoryId;

  void _recalc() {
    final p = parseAmount(_principal.text);
    if (p == null || p <= 0) return;
    final rate = parseAmount(_rate.text) ?? 0;
    // Bunga flat per tahun.
    final total = p * (1 + rate / 100 * _tenor / 12);
    _monthly.text = (total / _tenor).ceilToDouble().toStringAsFixed(0);
  }

  Future<void> _save() async {
    final t = S.of(context);
    final principal = parseAmount(_principal.text);
    final monthly = parseAmount(_monthly.text);
    if (_name.text.trim().isEmpty || principal == null || monthly == null) {
      return showSnack(context, t.t('Nama, pokok, dan cicilan per bulan belum lengkap', 'Fill in the name, principal, and monthly amount'));
    }
    await ref.read(databaseProvider).saveInstallment(InstallmentsCompanion(
          id: widget.existing == null ? const Value.absent() : Value(widget.existing!.id),
          name: Value(_name.text.trim()),
          accountId: Value(_accountId),
          categoryId: Value(_categoryId),
          principal: Value(principal),
          monthlyAmount: Value(monthly),
          tenor: Value(_tenor),
          paidCount: Value(_paid.clamp(0, _tenor)),
          interestRate: Value(parseAmount(_rate.text) ?? 0),
          startDate: Value(_start),
          dueDay: Value(_dueDay),
          note: Value(_note.text.trim()),
          active: Value(_paid < _tenor),
        ));
    if (mounted) Navigator.pop(context);
  }

  Widget _stepper(String label, int value, int min, int max, ValueChanged<int> onChanged) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(onPressed: value > min ? () => onChanged(value - 1) : null, icon: const Icon(Icons.remove)),
          Text('$value', style: AppTheme.serif(size: 18, weight: FontWeight.w700)),
          IconButton(onPressed: value < max ? () => onChanged(value + 1) : null, icon: const Icon(Icons.add)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final acc = ref.watch(accountMapProvider)[_accountId];
    final cats = ref.watch(categoryMapProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? t.t('Cicilan baru', 'New installment') : t.t('Ubah cicilan', 'Edit installment')),
        actions: [
          if (widget.existing != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (!await confirmDialog(context,
                    title: t.t('Hapus cicilan ini?', 'Delete this installment?'),
                    message: t.t('Pembayaran yang sudah dicatat tetap ada.', 'Payments already recorded will stay.'))) {
                  return;
                }
                await ref.read(databaseProvider).deleteInstallment(widget.existing!.id);
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LabeledField(label: t.name, child: TextField(controller: _name, decoration: InputDecoration(hintText: t.t('Contoh: iPhone pakai kartu kredit', 'e.g. iPhone on credit card')))),
          LabeledField(
            label: t.t('Pokok pinjaman', 'Principal'),
            child: TextField(controller: _principal, keyboardType: TextInputType.number, onChanged: (_) => setState(_recalc)),
          ),
          LabeledField(
            label: t.t('Bunga flat per tahun (%), kosongkan kalau 0%', 'Flat yearly interest (%), leave empty for 0%'),
            child: TextField(controller: _rate, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(_recalc)),
          ),
          _stepper(t.t('Tenor (bulan)', 'Term (months)'), _tenor, 1, 360, (v) => setState(() {
                _tenor = v;
                _recalc();
              })),
          LabeledField(
            label: t.t('Cicilan per bulan (dihitung otomatis, bisa diubah)', 'Monthly payment (calculated, you can change it)'),
            child: TextField(controller: _monthly, keyboardType: TextInputType.number),
          ),
          _stepper(t.t('Sudah dibayar berapa kali', 'Payments made'), _paid, 0, _tenor, (v) => setState(() => _paid = v)),
          _stepper(t.t('Tanggal jatuh tempo', 'Due day'), _dueDay, 1, 31, (v) => setState(() => _dueDay = v)),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t.t('Mulai', 'Start date')),
            trailing: Text(fmtDate(_start)),
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _start, firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (d != null) setState(() => _start = d);
            },
          ),
          LabeledField(
            label: t.t('Dibayar dari dompet (opsional)', 'Paid from wallet (optional)'),
            child: PickerTile(
              leading: acc == null
                  ? const Icon(Icons.account_balance_wallet_outlined, color: WaColors.washiMuted)
                  : KanjiBadge(glyph: acc.icon, color: Color(acc.color), size: 34),
              title: acc?.name ?? t.t('Pilih saat bayar', 'Choose when paying'),
              onTap: () async {
                final id = await showAccountPicker(context, ref, selectedId: _accountId);
                setState(() => _accountId = id);
              },
            ),
          ),
          LabeledField(
            label: t.category,
            child: PickerTile(
              leading: KanjiBadge(glyph: cats[_categoryId]?.icon ?? '返', color: Color(cats[_categoryId]?.color ?? WaColors.momiji.toARGB32()), size: 34),
              title: categoryLabel(cats, _categoryId, empty: t.t('Cicilan (bawaan)', 'Installments (default)')),
              onTap: () async {
                final id = await showCategoryPicker(context, type: 'expense', selectedId: _categoryId);
                if (id != null) setState(() => _categoryId = id);
              },
            ),
          ),
          LabeledField(label: t.note, child: TextField(controller: _note)),
          FilledButton(onPressed: _save, child: Text(t.save)),
        ],
      ),
    );
  }
}
