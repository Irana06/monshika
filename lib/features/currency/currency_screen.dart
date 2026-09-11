import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/database/database.dart';
import '../../l10n/strings.dart';
import '../../providers/providers.dart';
import '../../services/rates_service.dart';

class CurrencyScreen extends ConsumerStatefulWidget {
  const CurrencyScreen({super.key});

  @override
  ConsumerState<CurrencyScreen> createState() => _CurrencyScreenState();
}

class _CurrencyScreenState extends ConsumerState<CurrencyScreen> {
  final _amount = TextEditingController(text: '1');
  String _from = 'USD';
  bool _refreshing = false;

  Future<void> _refresh() async {
    final t = S.of(context);
    setState(() => _refreshing = true);
    final ok = await RatesService.refresh(ref.read(databaseProvider), force: true);
    await ref.read(settingsProvider.notifier).reload();
    if (!mounted) return;
    setState(() => _refreshing = false);
    showSnack(
      context,
      ok ? t.t('Kurs sudah diperbarui', 'Rates updated') : t.t('Kurs gagal diperbarui. Cek koneksi internet.', "Couldn't update rates. Check your connection."),
    );
  }

  Future<void> _manual(String code, String base, Map<String, double> rates, bool isManual) async {
    final t = S.of(context);
    final current = convert(1, code, base, rates);
    final ctrl = TextEditingController(text: current.toStringAsFixed(4));
    final result = await showDialog<(bool, double?)>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.t('Kurs $code', '$code rate')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('1 $code = ? $base', style: AppTheme.sans(color: WaColors.washiMuted)),
          const SizedBox(height: 8),
          TextField(controller: ctrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), autofocus: true),
        ]),
        actions: [
          if (isManual) TextButton(onPressed: () => Navigator.pop(ctx, (true, null)), child: Text(t.t('Pakai kurs online', 'Use live rate'))),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, (false, parseAmount(ctrl.text))), child: Text(t.save)),
        ],
      ),
    );
    if (result == null) return;
    final db = ref.read(databaseProvider);
    if (result.$1) {
      await db.setManualRate(code, null);
      await RatesService.refresh(db, force: true);
      return;
    }
    final v = result.$2;
    final basePerUsd = rates[base];
    if (v == null || v <= 0 || basePerUsd == null) return;
    await db.setManualRate(code, basePerUsd / v);
  }

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final s = ref.watch(settingsProvider);
    final rates = ref.watch(ratesProvider);
    final rows = ref.watch(rateRowsProvider).value ?? const <ExchangeRate>[];
    final manual = {for (final r in rows.where((r) => r.manual)) r.code};
    final base = s.baseCurrency;
    final amount = parseAmount(_amount.text) ?? 0;
    final updated = s.ratesUpdatedAt;
    final baseInfo = currencyInfo(base);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.withJp('為替', t.t('Mata uang', 'Currencies'))),
        actions: [
          IconButton(
            onPressed: _refreshing ? null : _refresh,
            icon: _refreshing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          children: [
            LabeledField(
              label: t.t('Mata uang utama (dipakai untuk total dan laporan)', 'Main currency (used for totals and reports)'),
              child: PickerTile(
                leading: Text(baseInfo.flag, style: const TextStyle(fontSize: 26)),
                title: '${baseInfo.code} · ${baseInfo.name(t)}',
                onTap: () async {
                  final c = await pickCurrency(context, current: base);
                  if (c != null) await ref.read(settingsProvider.notifier).setBaseCurrency(c);
                },
              ),
            ),
            Text(
              updated == null
                  ? t.t('Kurs belum pernah diperbarui', 'Rates have not been updated yet')
                  : t.t(
                      'Terakhir diperbarui ${DateFormat('d MMM yyyy, HH:mm', t.dateLocale).format(updated)}. Data dari Coinbase dan currency-api, diperbarui sendiri tiap 30 menit saat online.',
                      'Last updated ${DateFormat('d MMM yyyy, HH:mm', t.dateLocale).format(updated)}. Data from Coinbase and currency-api, refreshed every 30 minutes when online.',
                    ),
              style: AppTheme.sans(size: 12, color: WaColors.washiMuted),
            ),
            SectionHeader(title: t.t('Konversi cepat', 'Quick convert'), jp: '換'),
            WaCard(
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      style: AppTheme.serif(size: 22, weight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () async {
                      final c = await pickCurrency(context, current: _from);
                      if (c != null) setState(() => _from = c);
                    },
                    child: Text(_from),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  const Icon(Icons.south, color: WaColors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      formatMoney(convert(amount, _from, base, rates), base),
                      style: AppTheme.serif(size: 24, weight: FontWeight.w700, color: WaColors.accent),
                    ),
                  ),
                ]),
              ]),
            ),
            SectionHeader(title: t.t('Kurs ke mata uang utama', 'Rates in your main currency'), jp: '率'),
            Text(t.t('Ketuk salah satu untuk isi kurs sendiri, misalnya kurs money changer.', 'Tap one to set your own rate, like the one from your bank.'),
                style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
            const SizedBox(height: 8),
            WaCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                for (final c in kCurrencies.where((c) => c.code != base))
                  ListTile(
                    dense: true,
                    leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
                    title: Row(children: [
                      Text(c.code, style: AppTheme.sans(weight: FontWeight.w700)),
                      if (manual.contains(c.code)) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: WaColors.yamabuki.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                          child: Text('manual', style: AppTheme.sans(size: 10, color: WaColors.yamabuki)),
                        ),
                      ],
                    ]),
                    subtitle: Text(c.name(t), style: AppTheme.sans(size: 11, color: WaColors.washiMuted)),
                    trailing: rates[c.code] == null
                        ? Text('-', style: AppTheme.sans(color: WaColors.washiMuted))
                        : Text(formatMoney(convert(1, c.code, base, rates), base), style: AppTheme.sans(size: 13, weight: FontWeight.w600)),
                    onTap: rates[base] == null ? null : () => _manual(c.code, base, rates, manual.contains(c.code)),
                  ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
