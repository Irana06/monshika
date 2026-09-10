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
import '../../services/finance.dart';
import '../../services/money_actions.dart';
import '../common/pickers.dart';

class InstallmentsScreen extends ConsumerWidget {
  const InstallmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(installmentsProvider).value ?? const <Installment>[];
    final accounts = ref.watch(accountMapProvider);
    final s = ref.watch(settingsProvider);
    final active = items.where((i) => i.active);
    final monthly = active.fold(0.0, (v, i) => v + i.monthlyAmount);
    final remaining = active.fold(0.0, (v, i) => v + i.monthlyAmount * (i.tenor - i.paidCount));

    return Scaffold(
      appBar: AppBar(title: const Text('Cicilan · 分割')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add-inst',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InstallmentFormScreen())),
        child: const Icon(Icons.add),
      ),
      body: items.isEmpty
          ? const EmptyState(kanji: '返', title: 'Belum ada cicilan', subtitle: 'Kartu kredit, paylater, KPR, kendaraan, gadget…')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              children: [
                WaCard(
                  pattern: true,
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Cicilan / bulan', style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
                        Text(formatMoney(monthly, s.baseCurrency, hidden: s.hideBalance), style: AppTheme.serif(size: 22, weight: FontWeight.w700, color: WaColors.expense)),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('Sisa total', style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
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
                                      ? 'Ke-${i.paidCount + 1} dari ${i.tenor} · jatuh tempo ${fmtRelativeDay(installmentDueDate(i))}'
                                      : 'Lunas ✓',
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
                                label: const Text('Bayar cicilan'),
                                onPressed: () async {
                                  final accountId = i.accountId ?? await showAccountPicker(context, ref, title: 'Bayar dari');
                                  if (accountId == null) return;
                                  await MoneyActions(ref.read(databaseProvider)).payInstallment(i, accountId: accountId);
                                  if (context.mounted) await showHanko(context, glyph: '済', label: 'Cicilan dibayar');
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
    final principal = parseAmount(_principal.text);
    final monthly = parseAmount(_monthly.text);
    if (_name.text.trim().isEmpty || principal == null || monthly == null) return showSnack(context, 'Lengkapi nama, pokok, dan cicilan/bulan');
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
    final acc = ref.watch(accountMapProvider)[_accountId];
    final cats = ref.watch(categoryMapProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Cicilan Baru' : 'Ubah Cicilan'),
        actions: [
          if (widget.existing != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (!await confirmDialog(context, title: 'Hapus cicilan?', message: 'Transaksi pembayaran yang sudah tercatat tetap ada.')) return;
                await ref.read(databaseProvider).deleteInstallment(widget.existing!.id);
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LabeledField(label: 'Nama', child: TextField(controller: _name, decoration: const InputDecoration(hintText: 'mis. iPhone via kartu kredit'))),
          LabeledField(
            label: 'Pokok pinjaman',
            child: TextField(controller: _principal, keyboardType: TextInputType.number, onChanged: (_) => setState(_recalc)),
          ),
          LabeledField(
            label: 'Bunga flat per tahun (%) — kosongkan jika 0%',
            child: TextField(controller: _rate, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(_recalc)),
          ),
          _stepper('Tenor (bulan)', _tenor, 1, 360, (v) => setState(() {
                _tenor = v;
                _recalc();
              })),
          LabeledField(label: 'Cicilan per bulan (otomatis, bisa diubah)', child: TextField(controller: _monthly, keyboardType: TextInputType.number)),
          _stepper('Sudah dibayar (kali)', _paid, 0, _tenor, (v) => setState(() => _paid = v)),
          _stepper('Tanggal jatuh tempo', _dueDay, 1, 31, (v) => setState(() => _dueDay = v)),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mulai'),
            trailing: Text(fmtDate(_start)),
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _start, firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (d != null) setState(() => _start = d);
            },
          ),
          LabeledField(
            label: 'Dibayar dari dompet (opsional)',
            child: PickerTile(
              leading: KanjiBadge(glyph: acc?.icon ?? '―', color: Color(acc?.color ?? WaColors.nezumi.toARGB32()), size: 34),
              title: acc?.name ?? 'Pilih saat membayar',
              onTap: () async {
                final id = await showAccountPicker(context, ref, selectedId: _accountId);
                setState(() => _accountId = id);
              },
            ),
          ),
          LabeledField(
            label: 'Kategori',
            child: PickerTile(
              leading: KanjiBadge(glyph: cats[_categoryId]?.icon ?? '返', color: Color(cats[_categoryId]?.color ?? WaColors.momiji.toARGB32()), size: 34),
              title: categoryLabel(cats, _categoryId, empty: 'Cicilan (bawaan)'),
              onTap: () async {
                final id = await showCategoryPicker(context, type: 'expense', selectedId: _categoryId);
                if (id != null) setState(() => _categoryId = id);
              },
            ),
          ),
          LabeledField(label: 'Catatan', child: TextField(controller: _note)),
          FilledButton(onPressed: _save, child: const Text('Simpan')),
        ],
      ),
    );
  }
}
