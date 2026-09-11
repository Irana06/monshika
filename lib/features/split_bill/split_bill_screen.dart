import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/ui_kit.dart';
import '../../l10n/strings.dart';
import '../../providers/providers.dart';
import '../../services/money_actions.dart';
import '../common/pickers.dart';

class _Person {
  _Person(this.name, [double share = 0]) : share = TextEditingController(text: share == 0 ? '' : share.toStringAsFixed(0));
  String name;
  final TextEditingController share;
}

/// Bagi tagihan: bagianmu dicatat sebagai pengeluaran, bagian teman
/// jadi piutang (uang talangannya keluar dari dompet).
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

  String _friend(int n) => S.current.t('Teman $n', 'Friend $n');

  @override
  void initState() {
    super.initState();
    _accountId = widget.accountId;
    _categoryId = widget.categoryId;
    _people.add(_Person(_friend(1)));
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
    final t = S.of(context);
    if (_accountId == null) return showSnack(context, t.t('Pilih dompet yang dipakai bayar', 'Pick the wallet you paid with'));
    if (_totalValue <= 0) return showSnack(context, t.t('Total tagihannya belum diisi', 'Enter the bill total'));
    final account = ref.read(accountMapProvider)[_accountId]!;
    final diff = _totalValue - _mineValue - _othersValue;
    if (diff.abs() > 1) {
      return showSnack(context, t.t('Pembagiannya belum pas (selisih ${formatMoney(diff, account.currency)})', "The split doesn't add up (off by ${formatMoney(diff, account.currency)})"));
    }
    await MoneyActions(ref.read(databaseProvider)).splitBill(
      title: _title.text.trim().isEmpty ? t.t('Bagi tagihan', 'Split bill') : _title.text.trim(),
      total: _totalValue,
      accountId: _accountId!,
      currency: account.currency,
      categoryId: _categoryId,
      myShare: _mineValue,
      others: {for (final p in _people) p.name.trim().isEmpty ? t.t('Teman', 'Friend') : p.name.trim(): parseAmount(p.share.text) ?? 0},
      dueDate: _due,
    );
    if (!mounted) return;
    await showHanko(context, glyph: '割', label: t.t('Tagihan sudah dibagi', 'Bill split saved'));
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final account = ref.watch(accountMapProvider)[_accountId];
    final categories = ref.watch(categoryMapProvider);
    final cur = account?.currency ?? ref.watch(settingsProvider).baseCurrency;
    final diff = _totalValue - _mineValue - _othersValue;

    return Scaffold(
      appBar: AppBar(title: Text(t.withJp('割り勘', t.t('Bagi tagihan', 'Split bill')))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LabeledField(label: t.t('Judul', 'Title'), child: TextField(controller: _title, decoration: InputDecoration(hintText: t.t('Makan bareng', 'Dinner with friends')))),
          LabeledField(
            label: t.t('Total tagihan', 'Bill total'),
            child: TextField(
              controller: _total,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(prefixText: '${currencyInfo(cur).symbol} '),
            ),
          ),
          LabeledField(
            label: t.t('Dibayar pakai', 'Paid with'),
            child: PickerTile(
              leading: KanjiBadge(glyph: account?.icon ?? '財', color: Color(account?.color ?? WaColors.nezumi.toARGB32()), size: 36),
              title: account?.name ?? t.chooseWallet,
              onTap: () async {
                final id = await showAccountPicker(context, ref, selectedId: _accountId);
                if (id != null) setState(() => _accountId = id);
              },
            ),
          ),
          LabeledField(
            label: t.t('Kategori untuk bagianmu', 'Category for your share'),
            child: PickerTile(
              leading: KanjiBadge(
                glyph: categories[_categoryId]?.icon ?? '食',
                color: Color(categories[_categoryId]?.color ?? WaColors.shu.toARGB32()),
                size: 36,
              ),
              title: categoryLabel(categories, _categoryId, empty: t.chooseCategory),
              onTap: () async {
                final id = await showCategoryPicker(context, type: 'expense', selectedId: _categoryId);
                if (id != null) setState(() => _categoryId = id);
              },
            ),
          ),
          Row(
            children: [
              Text(t.t('Pembagian', 'Shares'), style: AppTheme.serif(size: 17, weight: FontWeight.w600)),
              const Spacer(),
              TextButton.icon(onPressed: _splitEqually, icon: const Icon(Icons.balance, size: 18), label: Text(t.t('Bagi rata', 'Split evenly'))),
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
                    Expanded(child: Text(t.t('Aku', 'Me'))),
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
                  onPressed: () => setState(() => _people.add(_Person(_friend(_people.length + 1)))),
                  icon: const Icon(Icons.person_add_alt),
                  label: Text(t.t('Tambah orang', 'Add person')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            diff.abs() <= 1 ? t.t('✓ Pembagian sudah pas', '✓ Everything adds up') : t.t('Belum dibagi: ${formatMoney(diff, cur)}', 'Not assigned yet: ${formatMoney(diff, cur)}'),
            style: AppTheme.sans(size: 13, color: diff.abs() <= 1 ? WaColors.income : WaColors.yamabuki),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(_due == null ? t.t('Tanpa batas waktu penagihan', 'No collection date') : t.t('Tagih sebelum ${fmtDate(_due!)}', 'Collect by ${fmtDate(_due!)}')),
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
            t.t('Bagian teman dicatat sebagai piutang di menu Utang & piutang, lengkap dengan pengingatnya.',
                "Your friends' shares are saved under Debts as money owed to you, with reminders."),
            style: AppTheme.sans(size: 12, color: WaColors.washiMuted),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _save, child: Text(t.save)),
        ],
      ),
    );
  }
}
