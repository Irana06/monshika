import 'package:collection/collection.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/kanji_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/database/database.dart';
import '../../providers/derived.dart';
import '../../providers/providers.dart';
import '../../services/money_actions.dart';
import '../transactions/transaction_form_screen.dart';
import '../transactions/transaction_tile.dart';

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final f = ref.watch(financeProvider);
    final all = ref.watch(allAccountsProvider).value ?? const <Account>[];
    final visible = all.where((a) => _showArchived || !a.archived).toList();
    final groups = groupBy(visible, (Account a) => a.type);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dompet · 財布'),
        actions: [
          IconButton(
            tooltip: _showArchived ? 'Sembunyikan arsip' : 'Tampilkan arsip',
            icon: Icon(_showArchived ? Icons.inventory_2 : Icons.inventory_2_outlined),
            onPressed: () => setState(() => _showArchived = !_showArchived),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add-account',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountFormScreen())),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          WaCard(
            pattern: true,
            child: Row(
              children: [
                Expanded(child: _Metric('総資産 Total', formatMoney(f.totalBalance, s.baseCurrency, hidden: s.hideBalance), WaColors.washi)),
                Expanded(child: _Metric('資 Aset', formatMoney(f.assets, s.baseCurrency, compact: true, hidden: s.hideBalance), WaColors.income)),
                Expanded(child: _Metric('負 Utang', formatMoney(f.liabilities, s.baseCurrency, compact: true, hidden: s.hideBalance), WaColors.expense)),
              ],
            ),
          ),
          if (visible.isEmpty)
            const EmptyState(kanji: '財', title: 'Belum ada dompet', subtitle: 'Tambahkan tunai, rekening bank, atau e-wallet.'),
          for (final type in kAccountTypes.keys)
            if (groups[type] != null) ...[
              SectionHeader(title: kAccountTypes[type]!.$1, jp: kAccountTypes[type]!.$2),
              WaCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (final a in groups[type]!)
                      ListTile(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AccountDetailScreen(accountId: a.id))),
                        leading: KanjiBadge(glyph: a.icon, color: Color(a.color), size: 40),
                        title: Row(children: [
                          Flexible(child: Text(a.name, style: AppTheme.sans(size: 15, weight: FontWeight.w600))),
                          if (a.archived) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.inventory_2_outlined, size: 14, color: WaColors.washiMuted),
                          ],
                          if (!a.includeInTotal) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.visibility_off_outlined, size: 14, color: WaColors.washiMuted),
                          ],
                        ]),
                        subtitle: Text(
                          a.currency == s.baseCurrency
                              ? a.currency
                              : '${a.currency} ≈ ${formatMoney(f.toBase(f.accountBalance(a.id), a.currency), s.baseCurrency, compact: true, hidden: s.hideBalance)}',
                          style: AppTheme.sans(size: 12, color: WaColors.washiMuted),
                        ),
                        trailing: Text(
                          formatMoney(f.accountBalance(a.id), a.currency, hidden: s.hideBalance),
                          style: AppTheme.sans(size: 15, weight: FontWeight.w700, color: f.accountBalance(a.id) < 0 ? WaColors.expense : WaColors.washi),
                        ),
                      ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTheme.serif(size: 12, color: WaColors.washiMuted)),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: AppTheme.sans(size: 16, weight: FontWeight.w700, color: color))),
        ],
      );
}

class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({super.key, required this.accountId});

  final int accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(accountMapProvider)[accountId];
    final s = ref.watch(settingsProvider);
    final f = ref.watch(financeProvider);
    final txs = ref.watch(transactionsProvider(TxFilter(accountIds: {accountId}, limit: 300))).value ?? const <TxEntry>[];
    if (a == null) return const Scaffold(body: Center(child: Text('Dompet tidak ditemukan')));
    final balance = f.accountBalance(a.id);
    final isCredit = a.type == 'credit' || a.type == 'paylater';

    return Scaffold(
      appBar: AppBar(
        title: Text(a.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AccountFormScreen(existing: a))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          WaCard(
            pattern: true,
            gradient: LinearGradient(colors: [Color(a.color).withValues(alpha: 0.25), WaColors.keshizumi]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  KanjiBadge(glyph: a.icon, color: Color(a.color), size: 44),
                  const SizedBox(width: 12),
                  Text('${kAccountTypes[a.type]?.$1 ?? a.type} · ${a.currency}', style: AppTheme.sans(color: WaColors.washiMuted)),
                ]),
                const SizedBox(height: 14),
                Text(isCredit ? 'Tagihan berjalan' : 'Saldo', style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
                Text(formatMoney(balance, a.currency, hidden: s.hideBalance), style: AppTheme.serif(size: 30, weight: FontWeight.w700)),
                if (isCredit && a.creditLimit != null && a.creditLimit! > 0) ...[
                  const SizedBox(height: 10),
                  InkBar(value: (-balance) / a.creditLimit!, height: 7),
                  const SizedBox(height: 4),
                  Text(
                    'Terpakai ${formatMoney(-balance, a.currency, compact: true, hidden: s.hideBalance)} dari limit ${formatMoney(a.creditLimit!, a.currency, compact: true, hidden: s.hideBalance)}',
                    style: AppTheme.sans(size: 12, color: WaColors.washiMuted),
                  ),
                ],
                if (a.note.isNotEmpty) ...[const SizedBox(height: 8), Text(a.note, style: AppTheme.sans(size: 12, color: WaColors.washiMuted))],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Transfer'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => TransactionFormScreen(initialType: 'transfer', initialAccountId: a.id)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.tune),
                  label: const Text('Sesuaikan'),
                  onPressed: () => _adjust(context, ref, a, balance),
                ),
              ),
            ],
          ),
          const SectionHeader(title: 'Riwayat', jp: '歴'),
          if (txs.isEmpty)
            const EmptyState(kanji: '無', title: 'Belum ada transaksi di dompet ini')
          else
            WaCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [for (final t in txs) TransactionTile(tx: t, showDate: true)]),
            ),
        ],
      ),
    );
  }

  Future<void> _adjust(BuildContext context, WidgetRef ref, Account a, double current) async {
    final ctrl = TextEditingController(text: current.toStringAsFixed(currencyInfo(a.currency).decimals));
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sesuaikan saldo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Masukkan saldo sebenarnya. Selisihnya dicatat sebagai "Penyesuaian Saldo" (tidak masuk statistik).',
                style: AppTheme.sans(size: 13, color: WaColors.washiMuted)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: InputDecoration(prefixText: '${currencyInfo(a.currency).symbol} '),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, parseAmount(ctrl.text)), child: const Text('Simpan')),
        ],
      ),
    );
    if (value == null) return;
    await MoneyActions(ref.read(databaseProvider)).adjustBalance(a, currentBalance: current, actualBalance: value);
    if (context.mounted) showSnack(context, 'Saldo disesuaikan');
  }
}

class AccountFormScreen extends ConsumerStatefulWidget {
  const AccountFormScreen({super.key, this.existing});

  final Account? existing;

  @override
  ConsumerState<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends ConsumerState<AccountFormScreen> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _balance = TextEditingController(
    text: widget.existing == null || widget.existing!.initialBalance == 0 ? '' : widget.existing!.initialBalance.toString(),
  );
  late final _limit = TextEditingController(text: widget.existing?.creditLimit?.toStringAsFixed(0) ?? '');
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late String _type = widget.existing?.type ?? 'bank';
  late String _currency = widget.existing?.currency ?? ref.read(settingsProvider).baseCurrency;
  late String _icon = widget.existing?.icon ?? kAccountTypes[_type]!.$2;
  late int _color = widget.existing?.color ?? WaColors.ai.toARGB32();
  late bool _include = widget.existing?.includeInTotal ?? true;
  late bool _archived = widget.existing?.archived ?? false;

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return showSnack(context, 'Nama dompet wajib diisi');
    final db = ref.read(databaseProvider);
    await db.saveAccount(AccountsCompanion(
      id: widget.existing == null ? const Value.absent() : Value(widget.existing!.id),
      name: Value(_name.text.trim()),
      type: Value(_type),
      currency: Value(_currency),
      initialBalance: Value(parseAmount(_balance.text) ?? 0),
      creditLimit: Value(parseAmount(_limit.text)),
      color: Value(_color),
      icon: Value(_icon),
      note: Value(_note.text.trim()),
      includeInTotal: Value(_include),
      archived: Value(_archived),
    ));
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: 'Hapus dompet?',
      message: 'Semua transaksi, preset, dan jadwal berulang yang memakai dompet ini ikut terhapus. Pertimbangkan "Arsipkan" saja.',
    );
    if (!ok) return;
    await ref.read(databaseProvider).deleteAccount(widget.existing!.id);
    if (mounted) Navigator.of(context)..pop()..maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final info = currencyInfo(_currency);
    final isCredit = _type == 'credit' || _type == 'paylater';
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Dompet Baru' : 'Ubah Dompet'),
        actions: [if (widget.existing != null) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline))],
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
              child: KanjiBadge(glyph: _icon, color: Color(_color), size: 80),
            ),
          ),
          const SizedBox(height: 6),
          Center(child: Text('Ketuk untuk ganti ikon', style: AppTheme.sans(size: 11, color: WaColors.washiMuted))),
          const SizedBox(height: 16),
          LabeledField(label: 'Nama', child: TextField(controller: _name, decoration: const InputDecoration(hintText: 'mis. BCA, GoPay, Dompet'))),
          LabeledField(
            label: 'Jenis',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in kAccountTypes.entries)
                  ChoiceChip(
                    avatar: Text(e.value.$2, style: AppTheme.serif(size: 13)),
                    label: Text(e.value.$1),
                    selected: _type == e.key,
                    onSelected: (_) => setState(() {
                      if (_icon == kAccountTypes[_type]!.$2) _icon = e.value.$2;
                      _type = e.key;
                    }),
                  ),
              ],
            ),
          ),
          LabeledField(
            label: 'Mata uang',
            child: PickerTile(
              leading: Text(info.flag, style: const TextStyle(fontSize: 24)),
              title: '${info.code} · ${info.name}',
              onTap: () async {
                final c = await pickCurrency(context, current: _currency);
                if (c != null) setState(() => _currency = c);
              },
            ),
          ),
          LabeledField(
            label: isCredit ? 'Tagihan awal (isi negatif, mis. -500000)' : 'Saldo awal',
            child: TextField(
              controller: _balance,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: InputDecoration(prefixText: '${info.symbol} '),
            ),
          ),
          if (isCredit)
            LabeledField(
              label: 'Limit kredit',
              child: TextField(
                controller: _limit,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(prefixText: '${info.symbol} '),
              ),
            ),
          LabeledField(label: 'Warna', child: ColorPickerRow(value: _color, onChanged: (c) => setState(() => _color = c))),
          LabeledField(label: 'Catatan', child: TextField(controller: _note, decoration: const InputDecoration(hintText: 'No. rekening, dll (opsional)'))),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hitung di total saldo'),
            value: _include,
            onChanged: (v) => setState(() => _include = v),
          ),
          if (widget.existing != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Arsipkan'),
              subtitle: Text('Sembunyikan dari daftar tanpa menghapus riwayat', style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
              value: _archived,
              onChanged: (v) => setState(() => _archived = v),
            ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Simpan')),
        ],
      ),
    );
  }
}
