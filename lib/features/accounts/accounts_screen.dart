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
import '../../l10n/strings.dart';
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
    final t = S.of(context);
    final s = ref.watch(settingsProvider);
    final f = ref.watch(financeProvider);
    final all = ref.watch(allAccountsProvider).value ?? const <Account>[];
    final visible = all.where((a) => _showArchived || !a.archived).toList();
    final groups = groupBy(visible, (Account a) => a.type);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.withJp('財布', t.wallets)),
        actions: [
          IconButton(
            tooltip: _showArchived ? t.t('Sembunyikan arsip', 'Hide archived') : t.t('Tampilkan arsip', 'Show archived'),
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
                Expanded(child: _Metric(t.withJp('総資産', 'Total'), formatMoney(f.totalBalance, s.baseCurrency, hidden: s.hideBalance), WaColors.washi)),
                Expanded(child: _Metric(t.withJp('資', t.t('Aset', 'Assets')), formatMoney(f.assets, s.baseCurrency, compact: true, hidden: s.hideBalance), WaColors.income)),
                Expanded(child: _Metric(t.withJp('負', t.t('Utang', 'Debts')), formatMoney(f.liabilities, s.baseCurrency, compact: true, hidden: s.hideBalance), WaColors.expense)),
              ],
            ),
          ),
          if (visible.isEmpty)
            EmptyState(
              kanji: '財',
              title: t.t('Belum ada dompet', 'No wallets yet'),
              subtitle: t.t('Tambahkan uang tunai, rekening bank, atau e-wallet.', 'Add your cash, bank account, or e-wallet.'),
            ),
          for (final type in kAccountTypeKeys)
            if (groups[type] != null) ...[
              SectionHeader(title: accountTypeLabel(t, type), jp: accountTypeGlyph(type)),
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
    final t = S.of(context);
    final a = ref.watch(accountMapProvider)[accountId];
    final s = ref.watch(settingsProvider);
    final f = ref.watch(financeProvider);
    final txs = ref.watch(transactionsProvider(TxFilter(accountIds: {accountId}, limit: 300))).value ?? const <TxEntry>[];
    if (a == null) return Scaffold(body: Center(child: Text(t.t('Dompet tidak ditemukan', 'Wallet not found'))));
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
                  Text('${accountTypeLabel(t, a.type)} · ${a.currency}', style: AppTheme.sans(color: WaColors.washiMuted)),
                ]),
                const SizedBox(height: 14),
                Text(isCredit ? t.t('Tagihan berjalan', 'Current bill') : t.t('Saldo', 'Balance'),
                    style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
                Text(formatMoney(balance, a.currency, hidden: s.hideBalance), style: AppTheme.serif(size: 30, weight: FontWeight.w700)),
                if (isCredit && a.creditLimit != null && a.creditLimit! > 0) ...[
                  const SizedBox(height: 10),
                  InkBar(value: (-balance) / a.creditLimit!, height: 7),
                  const SizedBox(height: 4),
                  Text(
                    t.t(
                      'Terpakai ${formatMoney(-balance, a.currency, compact: true, hidden: s.hideBalance)} dari limit ${formatMoney(a.creditLimit!, a.currency, compact: true, hidden: s.hideBalance)}',
                      '${formatMoney(-balance, a.currency, compact: true, hidden: s.hideBalance)} used of ${formatMoney(a.creditLimit!, a.currency, compact: true, hidden: s.hideBalance)} limit',
                    ),
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
                  label: Text(t.transfer),
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
                  label: Text(t.t('Koreksi saldo', 'Fix balance')),
                  onPressed: () => _adjust(context, ref, a, balance),
                ),
              ),
            ],
          ),
          SectionHeader(title: t.t('Riwayat', 'History'), jp: '歴'),
          if (txs.isEmpty)
            EmptyState(kanji: '無', title: t.t('Dompet ini belum punya transaksi', 'No transactions in this wallet yet'))
          else
            WaCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [for (final tx in txs) TransactionTile(tx: tx, showDate: true)]),
            ),
        ],
      ),
    );
  }

  Future<void> _adjust(BuildContext context, WidgetRef ref, Account a, double current) async {
    final t = S.of(context);
    final ctrl = TextEditingController(text: current.toStringAsFixed(currencyInfo(a.currency).decimals));
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.t('Koreksi saldo', 'Fix balance')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t.t('Isi saldo yang sebenarnya. Selisihnya dicatat sebagai penyesuaian dan tidak dihitung di statistik.',
                  "Enter the real balance. The difference is saved as an adjustment and won't show up in stats."),
              style: AppTheme.sans(size: 13, color: WaColors.washiMuted),
            ),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, parseAmount(ctrl.text)), child: Text(t.save)),
        ],
      ),
    );
    if (value == null) return;
    await MoneyActions(ref.read(databaseProvider)).adjustBalance(a, currentBalance: current, actualBalance: value);
    if (context.mounted) showSnack(context, t.t('Saldo sudah dikoreksi', 'Balance updated'));
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
  late String _icon = widget.existing?.icon ?? accountTypeGlyph(_type);
  late int _color = widget.existing?.color ?? WaColors.ai.toARGB32();
  late bool _include = widget.existing?.includeInTotal ?? true;
  late bool _archived = widget.existing?.archived ?? false;

  Future<void> _save() async {
    final t = S.of(context);
    if (_name.text.trim().isEmpty) return showSnack(context, t.t('Nama dompet belum diisi', 'Give the wallet a name'));
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
    final t = S.of(context);
    final ok = await confirmDialog(
      context,
      title: t.t('Hapus dompet ini?', 'Delete this wallet?'),
      message: t.t(
        'Semua transaksi, preset, dan jadwal rutin yang memakai dompet ini juga ikut terhapus. Kalau cuma ingin disembunyikan, pakai Arsipkan.',
        'All transactions, presets, and schedules that use this wallet will be deleted too. If you just want to hide it, archive it instead.',
      ),
    );
    if (!ok) return;
    await ref.read(databaseProvider).deleteAccount(widget.existing!.id);
    if (mounted) Navigator.of(context)..pop()..maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final info = currencyInfo(_currency);
    final isCredit = _type == 'credit' || _type == 'paylater';
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? t.t('Dompet baru', 'New wallet') : t.t('Ubah dompet', 'Edit wallet')),
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
          Center(child: Text(t.t('Ketuk untuk ganti ikon', 'Tap to change icon'), style: AppTheme.sans(size: 11, color: WaColors.washiMuted))),
          const SizedBox(height: 16),
          LabeledField(
            label: t.name,
            child: TextField(controller: _name, decoration: InputDecoration(hintText: t.t('Contoh: BCA, GoPay, Dompet', 'e.g. Chase, PayPal, Cash'))),
          ),
          LabeledField(
            label: t.t('Jenis', 'Type'),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final key in kAccountTypeKeys)
                  ChoiceChip(
                    avatar: GlyphIcon(accountTypeGlyph(key), color: WaColors.washi, size: 15),
                    label: Text(accountTypeLabel(t, key)),
                    selected: _type == key,
                    onSelected: (_) => setState(() {
                      if (_icon == accountTypeGlyph(_type)) _icon = accountTypeGlyph(key);
                      _type = key;
                    }),
                  ),
              ],
            ),
          ),
          LabeledField(
            label: t.currency,
            child: PickerTile(
              leading: Text(info.flag, style: const TextStyle(fontSize: 24)),
              title: '${info.code} · ${info.name(t)}',
              onTap: () async {
                final c = await pickCurrency(context, current: _currency);
                if (c != null) setState(() => _currency = c);
              },
            ),
          ),
          LabeledField(
            label: isCredit
                ? t.t('Tagihan awal (tulis minus, contoh -500000)', 'Starting bill (use a minus, e.g. -500)')
                : t.t('Saldo awal', 'Starting balance'),
            child: TextField(
              controller: _balance,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: InputDecoration(prefixText: '${info.symbol} '),
            ),
          ),
          if (isCredit)
            LabeledField(
              label: t.t('Limit kartu', 'Credit limit'),
              child: TextField(
                controller: _limit,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(prefixText: '${info.symbol} '),
              ),
            ),
          LabeledField(label: t.color, child: ColorPickerRow(value: _color, onChanged: (c) => setState(() => _color = c))),
          LabeledField(
            label: t.note,
            child: TextField(controller: _note, decoration: InputDecoration(hintText: t.t('No. rekening atau lainnya (opsional)', 'Account number or anything else (optional)'))),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t.t('Masukkan ke total saldo', 'Include in total balance')),
            value: _include,
            onChanged: (v) => setState(() => _include = v),
          ),
          if (widget.existing != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t.archive),
              subtitle: Text(t.t('Disembunyikan dari daftar, riwayatnya tetap ada', 'Hidden from the list, history stays'),
                  style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
              value: _archived,
              onChanged: (v) => setState(() => _archived = v),
            ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: Text(t.save)),
        ],
      ),
    );
  }
}
