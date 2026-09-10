import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/database/database.dart';
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
    setState(() => _refreshing = true);
    final ok = await RatesService.refresh(ref.read(databaseProvider), force: true);
    await ref.read(settingsProvider.notifier).reload();
    if (!mounted) return;
    setState(() => _refreshing = false);
    showSnack(context, ok ? 'Kurs diperbarui' : 'Gagal memperbarui kurs — periksa koneksi');
  }

  Future<void> _manual(String code, String base, Map<String, double> rates, bool isManual) async {
    final current = convert(1, code, base, rates);
    final ctrl = TextEditingController(text: current.toStringAsFixed(4));
    final result = await showDialog<(bool, double?)>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Kurs manual $code'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('1 $code = ? $base', style: AppTheme.sans(color: WaColors.washiMuted)),
          const SizedBox(height: 8),
          TextField(controller: ctrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), autofocus: true),
        ]),
        actions: [
          if (isManual) TextButton(onPressed: () => Navigator.pop(ctx, (true, null)), child: const Text('Pakai kurs online')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, (false, parseAmount(ctrl.text))), child: const Text('Simpan')),
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
        title: const Text('Mata Uang · 為替'),
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
              label: 'Mata uang utama (untuk total & laporan)',
              child: PickerTile(
                leading: Text(baseInfo.flag, style: const TextStyle(fontSize: 26)),
                title: '${baseInfo.code} · ${baseInfo.name}',
                onTap: () async {
                  final c = await pickCurrency(context, current: base);
                  if (c != null) await ref.read(settingsProvider.notifier).setBaseCurrency(c);
                },
              ),
            ),
            Text(
              updated == null
                  ? 'Kurs belum pernah diperbarui'
                  : 'Kurs diperbarui ${DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(updated)} · sumber Coinbase & currency-api (otomatis tiap 30 menit saat online)',
              style: AppTheme.sans(size: 12, color: WaColors.washiMuted),
            ),
            const SectionHeader(title: 'Konversi cepat', jp: '換'),
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
            const SectionHeader(title: 'Kurs terhadap mata uang utama', jp: '率'),
            Text('Ketuk untuk isi kurs manual (mis. kurs money changer).', style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
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
                    subtitle: Text(c.name, style: AppTheme.sans(size: 11, color: WaColors.washiMuted)),
                    trailing: rates[c.code] == null
                        ? Text('—', style: AppTheme.sans(color: WaColors.washiMuted))
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
