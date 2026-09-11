import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
import '../../services/notification_service.dart';
import '../common/pickers.dart';
import '../split_bill/split_bill_screen.dart';
import 'calc_pad.dart';

class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({
    super.key,
    this.existing,
    this.initialType = 'expense',
    this.initialAccountId,
    this.initialCategoryId,
    this.initialAmount,
    this.initialNote,
    this.onSaved,
  });

  final TxEntry? existing;
  final String initialType;
  final int? initialAccountId;
  final int? initialCategoryId;
  final double? initialAmount;
  final String? initialNote;

  /// Bila diisi, dipanggil setelah simpan (mis. dialog catat cepat menutup activity).
  final VoidCallback? onSaved;

  @override
  ConsumerState<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  late String _type;
  late CalcController _calc;
  int? _accountId;
  int? _toAccountId;
  double? _toAmount;
  bool _toAmountEdited = false;
  double _fee = 0;
  int? _categoryId;
  late DateTime _date;
  final _note = TextEditingController();
  final _payee = TextEditingController();
  final _toAmountCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();
  List<int> _tagIds = [];
  String? _receiptPath;
  bool _exclude = false;
  bool _showPad = true;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? widget.initialType;
    _calc = CalcController(initial: e?.amount ?? widget.initialAmount)..addListener(_onAmountChanged);
    _accountId = e?.accountId ?? widget.initialAccountId;
    _toAccountId = e?.toAccountId;
    _toAmount = e?.toAmount;
    _toAmountEdited = e?.toAmount != null;
    if (_toAmount != null) _toAmountCtrl.text = _plain(_toAmount!);
    _fee = e?.fee ?? 0;
    if (_fee > 0) _feeCtrl.text = _plain(_fee);
    _categoryId = e?.categoryId ?? widget.initialCategoryId;
    _date = e?.date ?? DateTime.now();
    _note.text = e?.note ?? widget.initialNote ?? '';
    _payee.text = e?.payee ?? '';
    _receiptPath = e?.receiptPath;
    _exclude = e?.excludeFromStats ?? false;
    _showPad = !_isEdit;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (e != null) {
        final tags = await ref.read(databaseProvider).getTagIdsFor(e.id);
        if (mounted) setState(() => _tagIds = tags);
      } else if (_accountId == null) {
        final accounts = ref.read(accountsProvider).value ?? await ref.read(databaseProvider).getAccounts();
        final def = ref.read(settingsProvider).defaultAccountId;
        if (!mounted || accounts.isEmpty) return;
        setState(() => _accountId = accounts.any((a) => a.id == def) ? def : accounts.first.id);
      }
    });
  }

  @override
  void dispose() {
    _calc.dispose();
    _note.dispose();
    _payee.dispose();
    _toAmountCtrl.dispose();
    _feeCtrl.dispose();
    super.dispose();
  }

  String _plain(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  void _onAmountChanged() {
    if (_type == 'transfer' && !_toAmountEdited) _syncToAmount();
    setState(() {});
  }

  void _syncToAmount() {
    final accounts = ref.read(accountMapProvider);
    final from = accounts[_accountId]?.currency;
    final to = accounts[_toAccountId]?.currency;
    if (from == null || to == null || from == to) {
      _toAmount = null;
      _toAmountCtrl.clear();
      return;
    }
    _toAmount = convert(_calc.value, from, to, ref.read(ratesProvider));
    _toAmountCtrl.text = _toAmount!.toStringAsFixed(currencyInfo(to).decimals);
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (d != null) setState(() => _date = DateTime(d.year, d.month, d.day, _date.hour, _date.minute));
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_date));
    if (time != null) setState(() => _date = DateTime(_date.year, _date.month, _date.day, time.hour, time.minute));
  }

  Future<void> _pickReceipt() async {
    final t = S.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera), title: Text(t.t('Kamera', 'Camera')), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library), title: Text(t.t('Galeri', 'Gallery')), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
          if (_receiptPath != null)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: WaColors.expense),
              title: Text(t.t('Hapus foto', 'Remove photo')),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _receiptPath = null);
              },
            ),
        ]),
      ),
    );
    if (source == null) return;
    final file = await ImagePicker().pickImage(source: source, imageQuality: 70, maxWidth: 1600);
    if (file == null) return;
    final dir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'receipts'));
    await dir.create(recursive: true);
    final dest = p.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}${p.extension(file.path)}');
    await File(file.path).copy(dest);
    setState(() => _receiptPath = dest);
  }

  Future<void> _pickTags() async {
    final t = S.of(context);
    final tags = ref.read(tagsProvider).value ?? const <Tag>[];
    final selected = {..._tagIds};
    final newTag = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tag', style: AppTheme.serif(size: 18, weight: FontWeight.w600)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in ref.read(tagsProvider).value ?? tags)
                    FilterChip(
                      selected: selected.contains(tag.id),
                      avatar: CircleAvatar(backgroundColor: Color(tag.color), radius: 5),
                      label: Text('#${tag.name}'),
                      onSelected: (v) => setSheet(() => v ? selected.add(tag.id) : selected.remove(tag.id)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newTag,
                decoration: InputDecoration(
                  hintText: t.t('Tag baru', 'New tag'),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () async {
                      final name = newTag.text.trim().replaceAll('#', '');
                      if (name.isEmpty) return;
                      final id = await ref.read(databaseProvider).saveTag(TagsCompanion.insert(
                            name: name,
                            color: WaColors.palette[DateTime.now().millisecond % WaColors.palette.length].toARGB32(),
                          ));
                      newTag.clear();
                      await Future<void>.delayed(const Duration(milliseconds: 150));
                      setSheet(() => selected.add(id));
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(t.done)),
              ),
            ],
          ),
        ),
      ),
    );
    setState(() => _tagIds = selected.toList());
  }

  Future<void> _save() async {
    final t = S.of(context);
    final amount = _calc.value;
    if (amount <= 0) return showSnack(context, t.t('Isi nominalnya dulu', 'Enter an amount first'));
    if (_accountId == null) return showSnack(context, t.chooseWallet);
    if (_type == 'transfer' && (_toAccountId == null || _toAccountId == _accountId)) {
      return showSnack(context, t.t('Pilih dompet tujuan yang lain', 'Pick a different destination wallet'));
    }
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final data = TransactionsCompanion(
      id: _isEdit ? Value(widget.existing!.id) : const Value.absent(),
      type: Value(_type),
      amount: Value(amount),
      accountId: Value(_accountId!),
      toAccountId: Value(_type == 'transfer' ? _toAccountId : null),
      toAmount: Value(_type == 'transfer' ? _toAmount : null),
      fee: Value(_type == 'transfer' ? _fee : 0),
      categoryId: Value(_type == 'transfer' ? null : _categoryId),
      date: Value(_date),
      note: Value(_note.text.trim()),
      payee: Value(_payee.text.trim()),
      receiptPath: Value(_receiptPath),
      excludeFromStats: Value(_exclude),
    );
    final id = await db.saveTransaction(data, tagIds: _tagIds);
    final settings = ref.read(settingsProvider);
    if (settings.defaultAccountId == null) {
      await ref.read(settingsProvider.notifier).setDefaultAccount(_accountId);
    }

    // Peringatan budget
    if (_type == 'expense' && settings.budgetAlerts && !_isEdit) {
      final saved = await db.getTransaction(id);
      if (saved != null) {
        final f = Finance(
          accounts: ref.read(accountMapProvider),
          balances: ref.read(balancesProvider).value ?? const {},
          categories: ref.read(categoryMapProvider),
          rates: ref.read(ratesProvider),
          baseCurrency: settings.baseCurrency,
        );
        final crossed = await MoneyActions(db).budgetsCrossed(saved, f, monthStartDay: settings.monthStartDay);
        for (final (b, ratio) in crossed) {
          await NotificationService.instance.showBudgetAlert(budgetId: b.id, name: b.name, ratio: ratio);
        }
      }
    }

    if (!mounted) return;
    if (settings.hankoAnimation) {
      await showHanko(
        context,
        glyph: _type == 'income' ? '入' : (_type == 'transfer' ? '移' : '済'),
        label: _isEdit ? t.t('Diperbarui', 'Updated') : t.t('Tersimpan', 'Saved'),
      );
    } else {
      HapticFeedback.lightImpact();
    }
    if (!mounted) return;
    if (widget.onSaved != null) {
      widget.onSaved!();
    } else {
      Navigator.pop(context, true);
    }
  }

  Future<void> _delete() async {
    final t = S.of(context);
    final ok = await confirmDialog(
      context,
      title: t.t('Hapus transaksi ini?', 'Delete this transaction?'),
      message: t.t('Transaksinya akan dihapus permanen.', 'It will be deleted for good.'),
    );
    if (!ok) return;
    await ref.read(databaseProvider).deleteTransaction(widget.existing!.id);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final accounts = ref.watch(accountMapProvider);
    final categories = ref.watch(categoryMapProvider);
    final account = accounts[_accountId];
    final toAccount = accounts[_toAccountId];
    final currency = account?.currency ?? ref.watch(settingsProvider).baseCurrency;
    final typeColor = WaColors.forType(_type);
    final cat = _categoryId == null ? null : categories[_categoryId];
    final tagMap = {for (final tag in ref.watch(tagsProvider).value ?? const <Tag>[]) tag.id: tag};

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? t.t('Ubah transaksi', 'Edit transaction') : t.t('Transaksi baru', 'New transaction')),
        actions: [
          if (_isEdit) ...[
            IconButton(
              tooltip: t.t('Duplikat', 'Duplicate'),
              icon: const Icon(Icons.copy_all_outlined),
              onPressed: () async {
                await MoneyActions(ref.read(databaseProvider)).duplicateTransaction(widget.existing!);
                if (context.mounted) {
                  showSnack(context, t.t('Disalin ke hari ini', 'Copied to today'));
                  Navigator.pop(context);
                }
              },
            ),
            IconButton(tooltip: t.delete, icon: const Icon(Icons.delete_outline), onPressed: _delete),
          ],
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'expense', label: Text(t.expense)),
                  ButtonSegment(value: 'income', label: Text(t.income)),
                  ButtonSegment(value: 'transfer', label: Text(t.transfer)),
                ],
                selected: {_type},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() {
                  final newType = s.first;
                  if (_categoryId != null && categories[_categoryId]?.type != newType) _categoryId = null;
                  _type = newType;
                  if (_type == 'transfer') _syncToAmount();
                }),
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
              setState(() => _showPad = true);
            },
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _showPad ? typeColor.withValues(alpha: 0.6) : WaColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_calc.hasOperator)
                    Text(_calc.expression, style: AppTheme.sans(size: 14, color: WaColors.washiMuted)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatMoney(_calc.value, currency),
                      style: AppTheme.serif(size: 38, weight: FontWeight.w700, color: typeColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              children: [
                LabeledField(
                  label: _type == 'transfer' ? t.t('Dari dompet', 'From wallet') : t.wallet,
                  child: PickerTile(
                    leading: KanjiBadge(glyph: account?.icon ?? '財', color: Color(account?.color ?? WaColors.nezumi.toARGB32()), size: 36),
                    title: account?.name ?? t.chooseWallet,
                    subtitle: account == null ? null : currency,
                    onTap: () async {
                      final id = await showAccountPicker(context, ref, selectedId: _accountId);
                      if (id != null) {
                        setState(() {
                          _accountId = id;
                          if (_type == 'transfer') _syncToAmount();
                        });
                      }
                    },
                  ),
                ),
                if (_type == 'transfer') ...[
                  LabeledField(
                    label: t.t('Ke dompet', 'To wallet'),
                    child: PickerTile(
                      leading: KanjiBadge(glyph: toAccount?.icon ?? '財', color: Color(toAccount?.color ?? WaColors.nezumi.toARGB32()), size: 36),
                      title: toAccount?.name ?? t.t('Pilih dompet tujuan', 'Choose destination'),
                      subtitle: toAccount?.currency,
                      onTap: () async {
                        final id = await showAccountPicker(context, ref,
                            selectedId: _toAccountId, excludeId: _accountId, title: t.t('Dompet tujuan', 'Destination wallet'));
                        if (id != null) {
                          setState(() {
                            _toAccountId = id;
                            _toAmountEdited = false;
                            _syncToAmount();
                          });
                        }
                      },
                    ),
                  ),
                  if (toAccount != null && account != null && toAccount.currency != account.currency)
                    LabeledField(
                      label: t.t('Jumlah yang diterima (${toAccount.currency}), dihitung dari kurs dan bisa diubah',
                          'Amount received (${toAccount.currency}), based on the rate and editable'),
                      child: TextField(
                        controller: _toAmountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onTap: () => setState(() => _showPad = false),
                        onChanged: (v) {
                          _toAmountEdited = true;
                          _toAmount = parseAmount(v);
                        },
                        decoration: InputDecoration(prefixText: '${currencyInfo(toAccount.currency).symbol} '),
                      ),
                    ),
                  LabeledField(
                    label: t.t('Biaya admin (opsional)', 'Transfer fee (optional)'),
                    child: TextField(
                      controller: _feeCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onTap: () => setState(() => _showPad = false),
                      onChanged: (v) => _fee = parseAmount(v) ?? 0,
                      decoration: InputDecoration(prefixText: '${currencyInfo(currency).symbol} '),
                    ),
                  ),
                ] else
                  LabeledField(
                    label: t.category,
                    child: PickerTile(
                      leading: KanjiBadge(glyph: cat?.icon ?? '？', color: Color(cat?.color ?? WaColors.nezumi.toARGB32()), size: 36),
                      title: categoryLabel(categories, _categoryId, empty: t.chooseCategory),
                      onTap: () async {
                        final id = await showCategoryPicker(context, type: _type, selectedId: _categoryId);
                        if (id != null) setState(() => _categoryId = id);
                      },
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: ActionChip(
                        avatar: const Icon(Icons.calendar_today, size: 16),
                        label: Text(fmtRelativeDay(_date).length > 12 ? fmtDate(_date) : fmtRelativeDay(_date)),
                        onPressed: _pickDate,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: const Icon(Icons.schedule, size: 16),
                      label: Text(fmtTime(_date)),
                      onPressed: _pickTime,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _note,
                  textCapitalization: TextCapitalization.sentences,
                  onTap: () => setState(() => _showPad = false),
                  decoration: InputDecoration(hintText: t.note, prefixIcon: const Icon(Icons.edit_note)),
                ),
                const SizedBox(height: 10),
                if (_type != 'transfer')
                  TextField(
                    controller: _payee,
                    onTap: () => setState(() => _showPad = false),
                    decoration: InputDecoration(
                      hintText: _type == 'income' ? t.t('Dari siapa (opsional)', 'From who (optional)') : t.t('Toko atau penerima (opsional)', 'Store or payee (optional)'),
                      prefixIcon: const Icon(Icons.storefront_outlined),
                    ),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.sell_outlined, size: 16),
                      label: Text(_tagIds.isEmpty ? 'Tag' : _tagIds.map((id) => '#${tagMap[id]?.name ?? ''}').join(' ')),
                      onPressed: _pickTags,
                    ),
                    ActionChip(
                      avatar: Icon(_receiptPath == null ? Icons.add_a_photo_outlined : Icons.receipt_long, size: 16),
                      label: Text(_receiptPath == null ? t.t('Foto struk', 'Receipt photo') : t.t('Ada foto struk', 'Receipt attached')),
                      onPressed: _pickReceipt,
                    ),
                    if (_type == 'expense' && !_isEdit)
                      ActionChip(
                        avatar: const Icon(Icons.call_split, size: 16),
                        label: Text(t.t('Bagi tagihan', 'Split bill')),
                        onPressed: () async {
                          final done = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SplitBillScreen(
                                total: _calc.value,
                                accountId: _accountId,
                                categoryId: _categoryId,
                                title: _note.text,
                              ),
                            ),
                          );
                          if (done == true && context.mounted) Navigator.pop(context, true);
                        },
                      ),
                  ],
                ),
                if (_receiptPath != null && File(_receiptPath!).existsSync()) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (_) => Dialog(child: InteractiveViewer(child: Image.file(File(_receiptPath!)))),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(File(_receiptPath!), height: 140, width: double.infinity, fit: BoxFit.cover),
                    ),
                  ),
                ],
                if (_type != 'transfer')
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(t.t('Jangan masukkan ke statistik', 'Leave out of stats')),
                    subtitle: Text(t.t('Misalnya uang titipan atau reimburse kantor', 'Like money held for someone or a work reimbursement'),
                        style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
                    value: _exclude,
                    onChanged: (v) => setState(() => _exclude = v),
                  ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            child: _showPad
                ? CalcPad(controller: _calc, accent: typeColor, onDone: () => setState(() => _showPad = false))
                : const SizedBox(width: double.infinity),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: typeColor, foregroundColor: WaColors.sumi),
                  onPressed: _saving ? null : _save,
                  child: Text(_isEdit ? t.saveChanges : t.save),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
