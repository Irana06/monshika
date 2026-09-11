import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../core/utils/smart_parser.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/database/database.dart';
import '../../l10n/strings.dart';
import '../../providers/providers.dart';
import '../../services/money_actions.dart';
import '../common/pickers.dart';
import 'transaction_form_screen.dart';

Future<void> showQuickInputSheet(BuildContext context, {String? type}) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => QuickInputPanel(initialType: type),
    );

/// Catat cepat lewat teks, contoh "kopi 25rb", "gojek 18.500 ovo", "+8jt gaji".
class QuickInputPanel extends ConsumerStatefulWidget {
  const QuickInputPanel({super.key, this.initialType, this.onSaved, this.onOpenForm});

  final String? initialType;

  /// Dipanggil setelah tersimpan. Default: tutup sheet.
  final VoidCallback? onSaved;

  /// Ganti aksi tombol form lengkap.
  final void Function(ParsedInput parsed, int? accountId, int? categoryId)? onOpenForm;

  @override
  ConsumerState<QuickInputPanel> createState() => _QuickInputPanelState();
}

class _QuickInputPanelState extends ConsumerState<QuickInputPanel> {
  final _ctrl = TextEditingController();
  String? _forcedType;
  int? _manualCategory;
  int? _manualAccount;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _forcedType = widget.initialType;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  ParsedInput _parse() => parseQuickInput(
        _ctrl.text,
        categories: ref.read(categoriesProvider).value ?? const [],
        accounts: ref.read(accountsProvider).value ?? const [],
        forcedType: _forcedType,
      );

  int? _resolveAccount(ParsedInput p) {
    final accounts = ref.read(accountsProvider).value ?? const <Account>[];
    if (_manualAccount != null) return _manualAccount;
    if (p.accountId != null) return p.accountId;
    final def = ref.read(settingsProvider).defaultAccountId;
    if (accounts.any((a) => a.id == def)) return def;
    return accounts.isEmpty ? null : accounts.first.id;
  }

  Future<void> _done(String label, String glyph) async {
    if (!mounted) return;
    if (ref.read(settingsProvider).hankoAnimation) await showHanko(context, glyph: glyph, label: label);
    if (!mounted) return;
    if (widget.onSaved != null) {
      widget.onSaved!();
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _save() async {
    final t = S.of(context);
    final parsed = _parse();
    final accountId = _resolveAccount(parsed);
    if (parsed.amount == null || parsed.amount! <= 0) {
      return showSnack(context, t.t('Nominalnya belum kebaca. Coba tulis: kopi 25rb', "Couldn't find an amount. Try: coffee 5"));
    }
    if (accountId == null) return showSnack(context, t.t('Belum ada dompet', 'No wallet yet'));
    setState(() => _saving = true);
    await ref.read(databaseProvider).saveTransaction(TransactionsCompanion.insert(
          type: parsed.type,
          amount: parsed.amount!,
          accountId: accountId,
          categoryId: Value(_manualCategory ?? parsed.categoryId),
          date: DateTime.now(),
          note: Value(parsed.note),
        ));
    await _done(t.t('Tersimpan', 'Saved'), parsed.type == 'income' ? '入' : '済');
  }

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final parsed = _parse();
    final accounts = ref.watch(accountMapProvider);
    final categories = ref.watch(categoryMapProvider);
    final presets = (ref.watch(presetsProvider).value ?? const <Preset>[]).where((p) => p.showInWidget).toList();
    final accountId = _resolveAccount(parsed);
    final account = accounts[accountId];
    final categoryId = _manualCategory ?? parsed.categoryId;
    final cat = categoryId == null ? null : categories[categoryId];
    final color = WaColors.forType(parsed.type);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (t.jp) ...[
                Text('速記', style: AppTheme.serif(size: 18, color: WaColors.accent, weight: FontWeight.w700)),
                const SizedBox(width: 8),
              ],
              Text(t.t('Catat cepat', 'Quick add'), style: AppTheme.serif(size: 18, weight: FontWeight.w600)),
              const Spacer(),
              SegmentedButton<String>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(value: 'auto', label: Text('Auto')),
                  ButtonSegment(value: 'expense', label: Text('-')),
                  ButtonSegment(value: 'income', label: Text('+')),
                ],
                selected: {_forcedType ?? 'auto'},
                onSelectionChanged: (s) => setState(() {
                  _forcedType = s.first == 'auto' ? null : s.first;
                  _manualCategory = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
            style: AppTheme.sans(size: 17),
            decoration: InputDecoration(
              hintText: t.t('Contoh: kopi 25rb, gojek 18.500 ovo, +8jt gaji', 'e.g. coffee 5, lunch 12 cash, +3000 salary'),
              prefixIcon: const Icon(Icons.bolt, color: WaColors.accent),
            ),
          ),
          const SizedBox(height: 12),
          WaCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () async {
                    final id = await showCategoryPicker(context, type: parsed.type, selectedId: categoryId);
                    if (id != null) setState(() => _manualCategory = id);
                  },
                  child: KanjiBadge(glyph: cat?.icon ?? '？', color: Color(cat?.color ?? WaColors.nezumi.toARGB32()), size: 44),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        parsed.amount == null ? '-' : formatMoney(parsed.amount!, account?.currency ?? 'IDR'),
                        style: AppTheme.serif(size: 22, weight: FontWeight.w700, color: color),
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 6,
                        children: [
                          _MiniChip(
                            label: categoryLabel(categories, categoryId, empty: t.chooseCategory),
                            onTap: () async {
                              final id = await showCategoryPicker(context, type: parsed.type, selectedId: categoryId);
                              if (id != null) setState(() => _manualCategory = id);
                            },
                          ),
                          _MiniChip(
                            label: account?.name ?? t.chooseWallet,
                            onTap: () async {
                              final id = await showAccountPicker(context, ref, selectedId: accountId);
                              if (id != null) setState(() => _manualAccount = id);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (presets.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(t.t('Sekali tap', 'One tap'), style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: presets.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final p = presets[i];
                  return ActionChip(
                    avatar: Text(p.icon),
                    label: Text('${p.name} ${formatMoney(p.amount, accounts[p.accountId]?.currency ?? 'IDR', compact: true)}'),
                    onPressed: () async {
                      await MoneyActions(ref.read(databaseProvider)).recordPreset(p);
                      await _done(t.t('${p.name} dicatat', '${p.name} added'), p.type == 'income' ? '入' : '済');
                    },
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    if (widget.onOpenForm != null) {
                      widget.onOpenForm!(parsed, accountId, categoryId);
                      return;
                    }
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TransactionFormScreen(
                          initialType: parsed.type,
                          initialAmount: parsed.amount,
                          initialAccountId: accountId,
                          initialCategoryId: categoryId,
                          initialNote: parsed.note,
                        ),
                      ),
                    );
                  },
                  child: Text(t.t('Form lengkap', 'Full form')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: color),
                  onPressed: _saving ? null : _save,
                  child: Text(t.save),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: WaColors.border),
        ),
        child: Text(label, style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
      ),
    );
  }
}
