import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/kanji_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/database/database.dart';
import '../../providers/providers.dart';
import '../common/pickers.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kategori · 分類'),
          bottom: const TabBar(
            indicatorColor: WaColors.accent,
            labelColor: WaColors.accent,
            unselectedLabelColor: WaColors.washiMuted,
            tabs: [Tab(text: 'Pengeluaran'), Tab(text: 'Pemasukan')],
          ),
        ),
        floatingActionButton: Builder(
          builder: (ctx) => FloatingActionButton(
            heroTag: 'add-cat',
            onPressed: () => Navigator.push(
              ctx,
              MaterialPageRoute(builder: (_) => CategoryFormScreen(type: DefaultTabController.of(ctx).index == 0 ? 'expense' : 'income')),
            ),
            child: const Icon(Icons.add),
          ),
        ),
        body: const TabBarView(children: [_CatList(type: 'expense'), _CatList(type: 'income')]),
      ),
    );
  }
}

class _CatList extends ConsumerWidget {
  const _CatList({required this.type});

  final String type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = (ref.watch(categoriesProvider).value ?? const <TxCategory>[]).where((c) => c.type == type && !c.isSystem).toList();
    final roots = all.where((c) => c.parentId == null).toList();

    Widget tile(TxCategory c, {bool child = false}) => ListTile(
          contentPadding: EdgeInsets.only(left: child ? 56 : 16, right: 8),
          leading: KanjiBadge(glyph: c.icon, color: Color(c.color), size: child ? 32 : 40),
          title: Text(c.name, style: AppTheme.sans(size: child ? 14 : 15, weight: child ? FontWeight.w500 : FontWeight.w600, color: c.archived ? WaColors.washiFaint : null)),
          subtitle: type == 'expense' && c.pillar != null
              ? Text('${kPillars[c.pillar]?.$2} ${kPillars[c.pillar]?.$1}', style: AppTheme.sans(size: 11, color: WaColors.washiMuted))
              : null,
          trailing: c.archived ? const Icon(Icons.inventory_2_outlined, size: 18) : const Icon(Icons.chevron_right, color: WaColors.washiFaint),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryFormScreen(type: type, existing: c))),
        );

    return ListView(
      padding: const EdgeInsets.only(bottom: 100, top: 8),
      children: [
        for (final r in roots) ...[
          tile(r),
          for (final c in all.where((x) => x.parentId == r.id)) tile(c, child: true),
          const Divider(indent: 16, endIndent: 16),
        ],
      ],
    );
  }
}

class CategoryFormScreen extends ConsumerStatefulWidget {
  const CategoryFormScreen({super.key, required this.type, this.existing});

  final String type;
  final TxCategory? existing;

  @override
  ConsumerState<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends ConsumerState<CategoryFormScreen> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late String _icon = widget.existing?.icon ?? '他';
  late int _color = widget.existing?.color ?? WaColors.shu.toARGB32();
  late int? _parentId = widget.existing?.parentId;
  late String? _pillar = widget.existing?.pillar ?? (widget.type == 'expense' ? 'needs' : null);
  late bool _archived = widget.existing?.archived ?? false;

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return showSnack(context, 'Nama kategori wajib diisi');
    await ref.read(databaseProvider).saveCategory(CategoriesCompanion(
          id: widget.existing == null ? const Value.absent() : Value(widget.existing!.id),
          name: Value(_name.text.trim()),
          type: Value(widget.type),
          parentId: Value(_parentId),
          icon: Value(_icon),
          color: Value(_color),
          pillar: Value(widget.type == 'expense' ? _pillar : null),
          archived: Value(_archived),
        ));
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final c = widget.existing!;
    final cats = (ref.read(categoriesProvider).value ?? const <TxCategory>[])
        .where((x) => x.type == c.type && x.id != c.id && !x.isSystem && x.parentId != c.id)
        .toList();
    final moveTo = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
        child: ListView(shrinkWrap: true, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Pindahkan transaksinya ke…', style: AppTheme.serif(size: 18, weight: FontWeight.w600)),
          ),
          ListTile(leading: const Icon(Icons.block), title: const Text('Tanpa kategori'), onTap: () => Navigator.pop(ctx, -1)),
          for (final x in cats)
            ListTile(
              leading: KanjiBadge(glyph: x.icon, color: Color(x.color), size: 32),
              title: Text(categoryLabel(ref.read(categoryMapProvider), x.id)),
              onTap: () => Navigator.pop(ctx, x.id),
            ),
        ]),
      ),
    );
    if (moveTo == null) return;
    await ref.read(databaseProvider).deleteCategory(c.id, moveTo: moveTo == -1 ? null : moveTo);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final roots = (ref.watch(categoriesProvider).value ?? const <TxCategory>[])
        .where((c) => c.type == widget.type && c.parentId == null && !c.isSystem && c.id != widget.existing?.id)
        .toList();
    final hasChildren = widget.existing != null &&
        (ref.watch(categoriesProvider).value ?? const <TxCategory>[]).any((c) => c.parentId == widget.existing!.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Kategori Baru' : 'Ubah Kategori'),
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
          const SizedBox(height: 16),
          LabeledField(label: 'Nama', child: TextField(controller: _name)),
          if (!hasChildren)
            LabeledField(
              label: 'Induk (opsional — jadikan sub-kategori)',
              child: DropdownButtonFormField<int?>(
                initialValue: _parentId,
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('— Kategori utama —')),
                  for (final r in roots) DropdownMenuItem<int?>(value: r.id, child: Text('${r.icon}  ${r.name}')),
                ],
                onChanged: (v) => setState(() => _parentId = v),
              ),
            ),
          if (widget.type == 'expense')
            LabeledField(
              label: 'Pilar Kakeibo',
              child: Column(children: [
                for (final e in kPillars.entries)
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: e.key,
                    groupValue: _pillar,
                    onChanged: (v) => setState(() => _pillar = v),
                    title: Text('${e.value.$2}  ${e.value.$1}'),
                    subtitle: Text(e.value.$3, style: AppTheme.sans(size: 11, color: WaColors.washiMuted)),
                  ),
              ]),
            ),
          LabeledField(label: 'Warna', child: ColorPickerRow(value: _color, onChanged: (c) => setState(() => _color = c))),
          if (widget.existing != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Arsipkan'),
              subtitle: Text('Tidak muncul saat memilih kategori', style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
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
