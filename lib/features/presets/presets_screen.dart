import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/database/database.dart';
import '../../l10n/strings.dart';
import '../../providers/providers.dart';
import '../common/pickers.dart';

class PresetsScreen extends ConsumerWidget {
  const PresetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = S.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.withJp('札', t.t('Preset & tag', 'Presets & tags'))),
          bottom: TabBar(
            indicatorColor: WaColors.accent,
            labelColor: WaColors.accent,
            unselectedLabelColor: WaColors.washiMuted,
            tabs: [Tab(text: t.t('Sekali tap', 'One tap')), const Tab(text: 'Tag')],
          ),
        ),
        floatingActionButton: Builder(
          builder: (ctx) => FloatingActionButton(
            heroTag: 'add-preset',
            onPressed: () {
              if (DefaultTabController.of(ctx).index == 0) {
                Navigator.push(ctx, MaterialPageRoute(builder: (_) => const PresetFormScreen()));
              } else {
                _editTag(ctx, ref, null);
              }
            },
            child: const Icon(Icons.add),
          ),
        ),
        body: const TabBarView(children: [_PresetList(), _TagList()]),
      ),
    );
  }
}

Future<void> _editTag(BuildContext context, WidgetRef ref, Tag? tag) async {
  final t = S.of(context);
  final name = TextEditingController(text: tag?.name ?? '');
  var color = tag?.color ?? WaColors.asagi.toARGB32();
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tag == null ? t.t('Tag baru', 'New tag') : t.t('Ubah tag', 'Edit tag'), style: AppTheme.serif(size: 18, weight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextField(controller: name, autofocus: true, decoration: const InputDecoration(prefixText: '#')),
          const SizedBox(height: 12),
          ColorPickerRow(value: color, onChanged: (c) => setSheet(() => color = c)),
          const SizedBox(height: 16),
          Row(children: [
            if (tag != null)
              TextButton(
                onPressed: () async {
                  await ref.read(databaseProvider).deleteTag(tag.id);
                  if (ctx.mounted) Navigator.pop(ctx, false);
                },
                child: Text(t.delete, style: const TextStyle(color: WaColors.expense)),
              ),
            const Spacer(),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t.save)),
          ]),
        ]),
      ),
    ),
  );
  if (ok != true || name.text.trim().isEmpty) return;
  await ref.read(databaseProvider).saveTag(TagsCompanion(
        id: tag == null ? const Value.absent() : Value(tag.id),
        name: Value(name.text.trim().replaceAll('#', '')),
        color: Value(color),
      ));
}

class _PresetList extends ConsumerWidget {
  const _PresetList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = S.of(context);
    final presets = ref.watch(presetsProvider).value ?? const <Preset>[];
    final accounts = ref.watch(accountMapProvider);
    final cats = ref.watch(categoryMapProvider);
    if (presets.isEmpty) {
      return EmptyState(
        kanji: '札',
        title: t.t('Belum ada preset', 'No presets yet'),
        subtitle: t.t('Preset bisa dipakai dari beranda, catat cepat, dan widget.', 'Presets show up on Home, quick add, and widgets.'),
      );
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(
          t.t(
            'Nyalakan saklarnya supaya preset muncul di catat cepat, beranda, dan widget (widget cuma menampilkan 4 teratas). Tahan lalu geser untuk mengatur urutan.',
            'Turn on the switch to show a preset in quick add, Home, and widgets (widgets show the top 4). Press and drag to reorder.',
          ),
          style: AppTheme.sans(size: 12, color: WaColors.washiMuted),
        ),
      ),
      Expanded(
        child: ReorderableListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: presets.length,
          onReorder: (oldIndex, newIndex) async {
            final list = [...presets];
            if (newIndex > oldIndex) newIndex--;
            list.insert(newIndex, list.removeAt(oldIndex));
            final db = ref.read(databaseProvider);
            for (final (i, p) in list.indexed) {
              await db.savePreset(PresetsCompanion(id: Value(p.id), sortOrder: Value(i)));
            }
          },
          itemBuilder: (_, i) {
            final p = presets[i];
            return ListTile(
              key: ValueKey(p.id),
              leading: CircleAvatar(backgroundColor: WaColors.surfaceHigh, child: Text(p.icon, style: const TextStyle(fontSize: 20))),
              title: Text(p.name, style: AppTheme.sans(weight: FontWeight.w600)),
              subtitle: Text(
                '${formatMoney(p.amount, accounts[p.accountId]?.currency ?? 'IDR')} · ${categoryLabel(cats, p.categoryId)} · ${accounts[p.accountId]?.name ?? '?'}',
                style: AppTheme.sans(size: 12, color: WaColors.washiMuted),
              ),
              trailing: Switch(
                value: p.showInWidget,
                onChanged: (v) => ref.read(databaseProvider).savePreset(PresetsCompanion(id: Value(p.id), showInWidget: Value(v))),
              ),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PresetFormScreen(existing: p))),
            );
          },
        ),
      ),
    ]);
  }
}

class _TagList extends ConsumerWidget {
  const _TagList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = S.of(context);
    final tags = ref.watch(tagsProvider).value ?? const <Tag>[];
    final usage = ref.watch(txTagMapProvider).value ?? const {};
    final counts = <int, int>{};
    for (final list in usage.values) {
      for (final id in list) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }
    if (tags.isEmpty) return EmptyState(kanji: '印', title: t.t('Belum ada tag', 'No tags yet'));
    return ListView(
      padding: const EdgeInsets.only(bottom: 100, top: 8),
      children: [
        for (final tag in tags)
          ListTile(
            leading: CircleAvatar(radius: 8, backgroundColor: Color(tag.color)),
            title: Text('#${tag.name}'),
            subtitle: Text(t.t('${counts[tag.id] ?? 0} transaksi', '${counts[tag.id] ?? 0} transactions'), style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
            onTap: () => _editTag(context, ref, tag),
          ),
      ],
    );
  }
}

class PresetFormScreen extends ConsumerStatefulWidget {
  const PresetFormScreen({super.key, this.existing});

  final Preset? existing;

  @override
  ConsumerState<PresetFormScreen> createState() => _PresetFormScreenState();
}

class _PresetFormScreenState extends ConsumerState<PresetFormScreen> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _icon = TextEditingController(text: widget.existing?.icon ?? '☕');
  late final _amount = TextEditingController(text: widget.existing?.amount.toStringAsFixed(0) ?? '');
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late String _type = widget.existing?.type ?? 'expense';
  late int? _accountId = widget.existing?.accountId ?? ref.read(settingsProvider).defaultAccountId;
  late int? _categoryId = widget.existing?.categoryId;
  late bool _widget = widget.existing?.showInWidget ?? true;

  static const _emojis = ['☕', '🍱', '🍜', '🧋', '🛵', '🚌', '⛽', '🅿️', '🛒', '💊', '🎮', '🎬', '📱', '💡', '🏠', '💰', '🎁', '🍺', '🚬', '🐱'];

  Future<void> _save() async {
    final t = S.of(context);
    final amount = parseAmount(_amount.text);
    if (_name.text.trim().isEmpty || amount == null || amount <= 0 || _accountId == null) {
      return showSnack(context, t.t('Nama, nominal, dan dompet belum lengkap', 'Fill in the name, amount, and wallet'));
    }
    await ref.read(databaseProvider).savePreset(PresetsCompanion(
          id: widget.existing == null ? const Value.absent() : Value(widget.existing!.id),
          name: Value(_name.text.trim()),
          icon: Value(_icon.text.trim().isEmpty ? '•' : _icon.text.trim()),
          type: Value(_type),
          amount: Value(amount),
          accountId: Value(_accountId!),
          categoryId: Value(_categoryId),
          note: Value(_note.text.trim()),
          showInWidget: Value(_widget),
          sortOrder: widget.existing == null ? const Value(999) : const Value.absent(),
        ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final acc = ref.watch(accountMapProvider)[_accountId];
    final cats = ref.watch(categoryMapProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? t.t('Preset baru', 'New preset') : t.t('Ubah preset', 'Edit preset')),
        actions: [
          if (widget.existing != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await ref.read(databaseProvider).deletePreset(widget.existing!.id);
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            SizedBox(
              width: 72,
              child: TextField(controller: _icon, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26), maxLength: 2, decoration: const InputDecoration(counterText: '')),
            ),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _name, decoration: InputDecoration(hintText: t.t('Nama, contoh: Kopi pagi', 'Name, e.g. Morning coffee')))),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 4, children: [
            for (final e in _emojis)
              InkWell(onTap: () => setState(() => _icon.text = e), child: Padding(padding: const EdgeInsets.all(6), child: Text(e, style: const TextStyle(fontSize: 22)))),
          ]),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [ButtonSegment(value: 'expense', label: Text(t.expense)), ButtonSegment(value: 'income', label: Text(t.income))],
            selected: {_type},
            onSelectionChanged: (v) => setState(() {
              _type = v.first;
              _categoryId = null;
            }),
          ),
          const SizedBox(height: 16),
          LabeledField(
            label: t.amount,
            child: TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(prefixText: '${currencyInfo(acc?.currency ?? 'IDR').symbol} '),
            ),
          ),
          LabeledField(
            label: t.wallet,
            child: PickerTile(
              leading: KanjiBadge(glyph: acc?.icon ?? '財', color: Color(acc?.color ?? WaColors.nezumi.toARGB32()), size: 34),
              title: acc?.name ?? t.chooseWallet,
              onTap: () async {
                final id = await showAccountPicker(context, ref, selectedId: _accountId);
                if (id != null) setState(() => _accountId = id);
              },
            ),
          ),
          LabeledField(
            label: t.category,
            child: PickerTile(
              leading: KanjiBadge(glyph: cats[_categoryId]?.icon ?? '？', color: Color(cats[_categoryId]?.color ?? WaColors.nezumi.toARGB32()), size: 34),
              title: categoryLabel(cats, _categoryId, empty: t.chooseCategory),
              onTap: () async {
                final id = await showCategoryPicker(context, type: _type, selectedId: _categoryId);
                if (id != null) setState(() => _categoryId = id);
              },
            ),
          ),
          LabeledField(label: t.t('Catatan di transaksi (opsional)', 'Transaction note (optional)'), child: TextField(controller: _note)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t.active),
            subtitle: Text(t.t('Muncul di catat cepat, beranda, dan widget', 'Shows in quick add, Home, and widgets'), style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
            value: _widget,
            onChanged: (v) => setState(() => _widget = v),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _save, child: Text(t.save)),
        ],
      ),
    );
  }
}
