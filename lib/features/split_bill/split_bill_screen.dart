import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/ui_kit.dart';
import '../../providers/providers.dart';
import '../../services/money_actions.dart';
import '../common/pickers.dart';

class _Person {
  _Person(this.name, [double share = 0]) : share = TextEditingController(text: share == 0 ? '' : share.toStringAsFixed(0));
  String name;
  final TextEditingController share;
}

/// Bagi tagihan: bagian sendiri dicatat sebagai pengeluaran, bagian teman
/// otomatis menjadi piutang (dengan uang talangan keluar dari dompet).
class SplitBillScreen extends ConsumerStatefulWidget {
  const SplitBillScreen({super.key, this.total = 0, this.accountId, this.categoryId, this.title = ''});

  final double total;
  final int? accountId;
  final int? categoryId;
  final String title;

  @override
  ConsumerState<SplitBillScreen> createState() => _SplitBillScreenState();
}

class _SplitBillScreenState extends ConsumerState<SplitBillScreen> {
  late final TextEditingController _title = TextEditingController(text: widget.title);
  late final TextEditingController _total =
      TextEditingController(text: widget.total > 0 ? widget.total.toStringAsFixed(0) : '');
  final _mine = TextEditingController();
  final _people = <_Person>[];
  int? _accountId;
  int? _categoryId;
  DateTime? _due;

  @override
  void initState() {
    super.initState();
    _accountId = widget.accountId;
    _categoryId = widget.categoryId;
    _people.add(_Person('Teman 1'));
  }

  double get _totalValue => parseAmount(_total.text) ?? 0;
  double get _mineValue => parseAmount(_mine.text) ?? 0;
  double get _othersValue => _people.fold(0.0, (s, p) => s + (parseAmount(p.share.text) ?? 0));

  void _splitEqually() {
    final n = _people.length + 1;
    final each = (_totalValue / n).floorToDouble();
    final remainder = _totalValue - each * n;
    setState(() {
      _mine.text = (each + remainder).toStringAsFixed(0);
      for (final p in _people) {
        p.share.text = each.toStringAsFixed(0);
      }
    });
  }

  Future<void> _save() async {
    if (_accountId == null) return showSnack(context, 'Pilih dompet yang dipakai membayar');
    if (_totalValue <= 0) return showSnack(context, 'Isi total tagihan');
    final diff = _totalValue - _mineValue - _othersValue;
    if (diff.abs() > 1) return showSnack(context, 'Pembagian belum pas (selisih ${formatMoney(diff, 'IDR')})');
    final account = ref.read(accountMapProvider)[_accountId]!;
    await MoneyActions(ref.read(databaseProvider)).splitBill(
      title: _title.text.trim().isEmpty ? 'Split bill' : _title.text.trim(),
      total: _totalValue,
      accountId: _accountId!,
      currency: account.currency,
      categoryId: _categoryId,
      myShare: _mineValue,
      others: {for (final p in _people) p.name.trim().isEmpty ? 'Teman' : p.name.trim(): parseAmount(p.share.text) ?? 0},
      dueDate: _due,
    );
    if (!mounted) return;
    await showHanko(context, glyph: '割', label: 'Split bill tercatat');
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountMapProvider)[_accountId];
    final categories = ref.watch(categoryMapProvider);
    final cur = account?.currency ?? ref.watch(settingsProvider).baseCurrency;
    final diff = _totalValue - _mineValue - _othersValue;

    return Scaffold(
      appBar: AppBar(title: const Text('Split Bill · 割り勘')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LabeledField(label: 'Judul', child: TextField(controller: _title, decoration: const InputDecoration(hintText: 'Makan bareng'))),
          LabeledField(
            label: 'Total tagihan',
            child: TextField(
              controller: _total,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(prefixText: '${currencyInfo(cur).symbol} '),
            ),
          ),
          LabeledField(
            label: 'Dibayar dari',
            child: PickerTile(
              leading: KanjiBadge(glyph: account?.icon ?? '財', color: Color(account?.color ?? WaColors.nezumi.toARGB32()), size: 36),
              title: account?.name ?? 'Pilih dompet',
              onTap: () async {
                final id = await showAccountPicker(context, ref, selectedId: _accountId);
                if (id != null) setState(() => _accountId = id);
              },
            ),
          ),
          LabeledField(
            label: 'Kategori (untuk bagianmu)',
            child: PickerTile(
              leading: KanjiBadge(
                glyph: categories[_categoryId]?.icon ?? '食',
                color: Color(categories[_categoryId]?.color ?? WaColors.shu.toARGB32()),
                size: 36,
              ),
              title: categoryLabel(categories, _categoryId, empty: 'Pilih kategori'),
              onTap: () async {
                final id = await showCategoryPicker(context, type: 'expense', selectedId: _categoryId);
                if (id != null) setState(() => _categoryId = id);
              },
            ),
          ),
          Row(
            children: [
              Text('Pembagian', style: AppTheme.serif(size: 17, weight: FontWeight.w600)),
              const Spacer(),
              TextButton.icon(onPressed: _splitEqually, icon: const Icon(Icons.balance, size: 18), label: const Text('Bagi rata')),
            ],
          ),
          const SizedBox(height: 8),
          WaCard(
            child: Column(
              children: [
                Row(
                  children: [
                    const KanjiBadge(glyph: '私', color: WaColors.accent, size: 36),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('Saya')),
                    SizedBox(
                      width: 130,
                      child: TextField(
                        controller: _mine,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.end,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(isDense: true, hintText: '0'),
                      ),
                    ),
                  ],
                ),
                for (final p in _people) ...[
                  const Divider(height: 20),
                  Row(
                    children: [
                      const KanjiBadge(glyph: '友', color: WaColors.asagi, size: 36),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          initialValue: p.name,
                          onChanged: (v) => p.name = v,
                          decoration: const InputDecoration(isDense: true, border: InputBorder.none, filled: false),
                        ),
                      ),
                      SizedBox(
                        width: 130,
                        child: TextField(
                          controller: p.share,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.end,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(isDense: true, hintText: '0'),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: _people.length <= 1 ? null : () => setState(() => _people.remove(p)),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => setState(() => _people.add(_Person('Teman ${_people.length + 1}'))),
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('Tambah orang'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            diff.abs() <= 1 ? '✓ Pembagian pas' : 'Sisa belum dibagi: ${formatMoney(diff, cur)}',
            style: AppTheme.sans(size: 13, color: diff.abs() <= 1 ? WaColors.income : WaColors.yamabuki),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(_due == null ? 'Tanpa jatuh tempo penagihan' : 'Tagih sebelum ${MaterialLocalizations.of(context).formatMediumDate(_due!)}'),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                firstDate: DateTime(2000),
                lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                initialDate: DateTime.now().add(const Duration(days: 7)),
              );
              if (d != null) setState(() => _due = d);
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Bagian teman akan dicatat sebagai piutang di menu Utang & Piutang, lengkap dengan pengingat.',
            style: AppTheme.sans(size: 12, color: WaColors.washiMuted),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _save, child: const Text('Simpan Split Bill')),
        ],
      ),
    );
  }
}
