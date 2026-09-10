import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/database/database.dart';
import '../../providers/providers.dart';
import '../common/pickers.dart';
import 'transaction_form_screen.dart';

class TransactionTile extends ConsumerWidget {
  const TransactionTile({super.key, required this.tx, this.showDate = false, this.onTap});

  final TxEntry tx;
  final bool showDate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountMapProvider);
    final categories = ref.watch(categoryMapProvider);
    final tags = {for (final t in ref.watch(tagsProvider).value ?? const <Tag>[]) t.id: t};
    final tagIds = (ref.watch(txTagMapProvider).value ?? const {})[tx.id] ?? const [];
    final hidden = ref.watch(settingsProvider).hideBalance;

    final account = accounts[tx.accountId];
    final cat = tx.categoryId == null ? null : categories[tx.categoryId];
    final isTransfer = tx.type == 'transfer';
    final glyph = isTransfer ? '移' : (cat?.icon ?? '他');
    final color = isTransfer ? WaColors.transfer : Color(cat?.color ?? WaColors.nezumi.toARGB32());

    final title = tx.note.isNotEmpty
        ? tx.note
        : isTransfer
            ? 'Transfer'
            : (cat?.name ?? 'Tanpa kategori');
    final subtitleParts = <String>[
      if (isTransfer) '${account?.name ?? '?'} → ${accounts[tx.toAccountId]?.name ?? '?'}'
      else ...[
        if (tx.note.isNotEmpty) categoryLabel(categories, tx.categoryId),
        account?.name ?? '?',
      ],
      showDate ? fmtDateShort(tx.date) : fmtTime(tx.date),
    ];

    return InkWell(
      onTap: onTap ??
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => TransactionFormScreen(existing: tx))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            KanjiBadge(glyph: glyph, color: color, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.sans(size: 14.5, weight: FontWeight.w600)),
                      ),
                      if (tx.recurringId != null) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.repeat, size: 13, color: WaColors.washiMuted),
                      ],
                      if (tx.receiptPath != null) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.receipt_long, size: 13, color: WaColors.washiMuted),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          subtitleParts.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.sans(size: 12, color: WaColors.washiMuted),
                        ),
                      ),
                      for (final id in tagIds.take(3))
                        if (tags[id] != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(color: Color(tags[id]!.color), shape: BoxShape.circle),
                            ),
                          ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatMoney(
                    tx.type == 'expense' ? -tx.amount : tx.amount,
                    account?.currency ?? 'IDR',
                    showSign: tx.type == 'income',
                    hidden: hidden,
                  ),
                  style: AppTheme.sans(
                    size: 14.5,
                    weight: FontWeight.w700,
                    color: tx.excludeFromStats && !isTransfer ? WaColors.washiMuted : WaColors.forType(tx.type),
                  ),
                ),
                if (tx.fee > 0)
                  Text('biaya ${formatMoney(tx.fee, account?.currency ?? 'IDR', hidden: hidden)}',
                      style: AppTheme.sans(size: 11, color: WaColors.washiMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Header grup tanggal dengan total harian.
class DayHeader extends StatelessWidget {
  const DayHeader({super.key, required this.date, required this.income, required this.expense, required this.currency, this.hidden = false});

  final DateTime date;
  final double income;
  final double expense;
  final String currency;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: WaColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${date.day}', style: AppTheme.serif(size: 16, weight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fmtRelativeDay(date), style: AppTheme.sans(size: 13, weight: FontWeight.w600)),
                Text('${kJpWeekdays[date.weekday - 1]}曜日', style: AppTheme.serif(size: 11, color: WaColors.washiMuted)),
              ],
            ),
          ),
          if (income > 0)
            Text(formatMoney(income, currency, compact: true, hidden: hidden, showSign: true),
                style: AppTheme.sans(size: 12, color: WaColors.income, weight: FontWeight.w600)),
          if (income > 0 && expense > 0) const SizedBox(width: 10),
          if (expense > 0)
            Text(formatMoney(-expense, currency, compact: true, hidden: hidden),
                style: AppTheme.sans(size: 12, color: WaColors.expense, weight: FontWeight.w600)),
        ],
      ),
    );
  }
}
