import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/kanji_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/database/database.dart';
import '../../providers/providers.dart';

Future<int?> showAccountPicker(
  BuildContext context,
  WidgetRef ref, {
  int? selectedId,
  int? excludeId,
  String title = 'Pilih Dompet',
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Consumer(
      builder: (ctx, ref, _) {
        final accounts = (ref.watch(accountsProvider).value ?? const []).where((a) => a.id != excludeId).toList();
        final balances = ref.watch(balancesProvider).value ?? const {};
        final hidden = ref.watch(settingsProvider).hideBalance;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text(title, style: AppTheme.serif(size: 18, weight: FontWeight.w600)),
              const SizedBox(height: 12),
              if (accounts.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Belum ada dompet. Tambahkan dulu di menu Dompet.',
                      style: AppTheme.sans(color: WaColors.washiMuted)),
                ),
              for (final a in accounts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: WaCard(
                    padding: const EdgeInsets.all(12),
                    borderColor: a.id == selectedId ? WaColors.accent : null,
                    onTap: () => Navigator.pop(ctx, a.id),
                    child: Row(
                      children: [
                        KanjiBadge(glyph: a.icon, color: Color(a.color), size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.name, style: AppTheme.sans(size: 15, weight: FontWeight.w600)),
                              Text('${kAccountTypes[a.type]?.$1 ?? a.type} · ${a.currency}',
                                  style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
                            ],
                          ),
                        ),
                        Text(
                          formatMoney(balances[a.id] ?? a.initialBalance, a.currency, hidden: hidden),
                          style: AppTheme.sans(size: 14, weight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

Future<int?> showCategoryPicker(BuildContext context, {required String type, int? selectedId}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _CategoryPickerSheet(type: type, selectedId: selectedId),
  );
}

class _CategoryPickerSheet extends ConsumerStatefulWidget {
  const _CategoryPickerSheet({required this.type, this.selectedId});

  final String type;
  final int? selectedId;

  @override
  ConsumerState<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends ConsumerState<_CategoryPickerSheet> {
  int? _expanded;

  @override
  void initState() {
    super.initState();
    final map = ref.read(categoryMapProvider);
    final sel = widget.selectedId == null ? null : map[widget.selectedId];
    _expanded = sel?.parentId ?? (sel != null && map.values.any((c) => c.parentId == sel.id) ? sel.id : null);
  }

  @override
  Widget build(BuildContext context) {
    final all = (ref.watch(categoriesProvider).value ?? const <TxCategory>[])
        .where((c) => c.type == widget.type && !c.isSystem && !c.archived)
        .toList();
    final roots = all.where((c) => c.parentId == null).toList();
    final children = _expanded == null ? const <TxCategory>[] : all.where((c) => c.parentId == _expanded).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(widget.type == 'income' ? 'Kategori Pemasukan' : 'Kategori Pengeluaran',
              style: AppTheme.serif(size: 18, weight: FontWeight.w600)),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 86,
              mainAxisSpacing: 10,
              crossAxisSpacing: 8,
              childAspectRatio: 0.78,
            ),
            itemCount: roots.length,
            itemBuilder: (_, i) {
              final c = roots[i];
              final hasChildren = all.any((x) => x.parentId == c.id);
              final selected = c.id == widget.selectedId || c.id == _expanded;
              return _CatTile(
                category: c,
                selected: selected,
                hasChildren: hasChildren,
                onTap: () {
                  if (hasChildren && _expanded != c.id) {
                    setState(() => _expanded = c.id);
                  } else {
                    Navigator.pop(context, c.id);
                  }
                },
              );
            },
          ),
          if (children.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Sub-kategori · ketuk induk sekali lagi untuk memilih induknya',
                style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in children)
                  ChoiceChip(
                    selected: c.id == widget.selectedId,
                    avatar: Text(c.icon, style: AppTheme.serif(size: 14, color: Color(c.color))),
                    label: Text(c.name),
                    onSelected: (_) => Navigator.pop(context, c.id),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CatTile extends StatelessWidget {
  const _CatTile({required this.category, required this.selected, required this.hasChildren, required this.onTap});

  final TxCategory category;
  final bool selected;
  final bool hasChildren;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(category.color);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
          border: Border.all(color: selected ? color : Colors.transparent),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                KanjiBadge(glyph: category.icon, color: color, size: 44),
                if (hasChildren)
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      padding: const EdgeInsets.all(1),
                      decoration: const BoxDecoration(color: WaColors.keshizumi, shape: BoxShape.circle),
                      child: const Icon(Icons.more_horiz, size: 14, color: WaColors.washiMuted),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              category.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.sans(size: 11, height: 1.15),
            ),
          ],
        ),
      ),
    );
  }
}

/// Label kategori: "Induk › Sub".
String categoryLabel(Map<int, TxCategory> map, int? id, {String empty = 'Tanpa kategori'}) {
  if (id == null) return empty;
  final c = map[id];
  if (c == null) return empty;
  final p = c.parentId == null ? null : map[c.parentId];
  return p == null ? c.name : '${p.name} › ${c.name}';
}
