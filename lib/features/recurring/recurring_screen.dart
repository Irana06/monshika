import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/ui_kit.dart';
import '../../data/database/database.dart';
import '../../providers/derived.dart';
import '../../providers/providers.dart';
import '../../services/money_actions.dart';
import '../common/pickers.dart';

const _freqLabel = {'daily': 'hari', 'weekly': 'minggu', 'monthly': 'bulan', 'yearly': 'tahun'};

double monthlyEquivalent(Recurring r) => switch (r.frequency) {
      'daily' => r.amount * 30.44 / r.interval,
      'weekly' => r.amount * 4.345 / r.interval,
      'yearly' => r.amount / 12 / r.interval,
      _ => r.amount / r.interval,
    };

class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Berulang · 定期'),
          bottom: const TabBar(
            indicatorColor: WaColors.accent,
            labelColor: WaColors.accent,
            unselectedLabelColor: WaColors.washiMuted,
            tabs: [Tab(text: 'Semua jadwal'), Tab(text: 'Langganan')],
          ),
        ),
        floatingActionButton: Builder(
          builder: (ctx) => FloatingActionButton(
            heroTag: 'add-rec',
            onPressed: () => Navigator.push(
              ctx,
              MaterialPageRoute(builder: (_) => RecurringFormScreen(subscription: DefaultTabController.of(ctx).index == 1)),
            ),
            child: const Icon(Icons.add),
          ),
        ),
        body: const TabBarView(children: [_List(subscriptionsOnly: false), _List(subscriptionsOnly: true)]),
      ),
    );
  }
}

class _List extends ConsumerWidget {
  const _List({required this.subscriptionsOnly});

  final bool subscriptionsOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(recurringsProvider).value ?? const <Recurring>[];
    final items = all.where((r) => !subscriptionsOnly || r.isSubscription).toList();
    final accounts = ref.watch(accountMapProvider);
    final f = ref.watch(financeProvider);
    final s = ref.watch(settingsProvider);
    final now = DateTime.now();
    final pending = items.where((r) => r.active && !r.autoPost && !r.nextDate.isAfter(now)).toList();
    final monthlyOut = items
        .where((r) => r.active && r.type == 'expense')
        .fold(0.0, (v, r) => v + f.toBase(monthlyEquivalent(r), accounts[r.accountId]?.currency ?? s.baseCurrency));
    final monthlyIn = items
        .where((r) => r.active && r.type == 'income')
        .fold(0.0, (v, r) => v + f.toBase(monthlyEquivalent(r), accounts[r.accountId]?.currency ?? s.baseCurrency));

    if (items.isEmpty) {
      return EmptyState(
        kanji: subscriptionsOnly ? '定' : '暦',
        title: subscriptionsOnly ? 'Belum ada langganan' : 'Belum ada jadwal berulang',
        subtitle: subscriptionsOnly ? 'Netflix, Spotify, iCloud, gym — pantau total biayanya.' : 'Gaji, kos, tagihan — dicatat otomatis sesuai jadwal.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        WaCard(
          pattern: true,
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(subscriptionsOnly ? 'Biaya langganan / bulan' : 'Keluar rutin / bulan', style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
                Text(formatMoney(monthlyOut, s.baseCurrency, hidden: s.hideBalance), style: AppTheme.serif(size: 22, weight: FontWeight.w700, color: WaColors.expense)),
                Text('≈ ${formatMoney(monthlyOut * 12, s.baseCurrency, compact: true, hidden: s.hideBalance)} / tahun',
                    style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
              ]),
            ),
            if (!subscriptionsOnly && monthlyIn > 0)
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('Masuk rutin', style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
                Text(formatMoney(monthlyIn, s.baseCurrency, compact: true, hidden: s.hideBalance),
                    style: AppTheme.serif(size: 18, weight: FontWeight.w700, color: WaColors.income)),
              ]),
          ]),
        ),
        if (pending.isNotEmpty) ...[
          const SectionHeader(title: 'Perlu dikonfirmasi', jp: '確'),
          for (final r in pending) _RecurringCard(r: r, pending: true),
        ],
        const SectionHeader(title: 'Jadwal', jp: '暦'),
        for (final r in items.where((r) => !pending.contains(r))) _RecurringCard(r: r),
      ],
    );
  }
}

class _RecurringCard extends ConsumerWidget {
  const _RecurringCard({required this.r, this.pending = false});

  final Recurring r;
  final bool pending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountMapProvider)[r.accountId];
    final hidden = ref.watch(settingsProvider).hideBalance;
    final actions = MoneyActions(ref.read(databaseProvider));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: r.active ? 1 : 0.5,
        child: WaCard(
          borderColor: pending ? WaColors.yamabuki.withValues(alpha: 0.6) : null,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecurringFormScreen(existing: r))),
          child: Column(
            children: [
              Row(children: [
                KanjiBadge(glyph: r.icon, color: Color(r.color), size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.name, style: AppTheme.sans(size: 15, weight: FontWeight.w600)),
                    Text(
                      'Tiap ${r.interval > 1 ? '${r.interval} ' : ''}${_freqLabel[r.frequency]} · ${account?.name ?? '?'}'
                      '${r.autoPost ? ' · otomatis' : ''}',
                      style: AppTheme.sans(size: 12, color: WaColors.washiMuted),
                    ),
                    Text(r.active ? 'Berikutnya: ${fmtRelativeDay(r.nextDate)}' : 'Dijeda',
                        style: AppTheme.sans(size: 12, color: pending ? WaColors.yamabuki : WaColors.washiMuted)),
                  ]),
                ),
                Text(
                  formatMoney(r.type == 'expense' ? -r.amount : r.amount, account?.currency ?? 'IDR', hidden: hidden, showSign: r.type == 'income'),
                  style: AppTheme.sans(size: 14, weight: FontWeight.w700, color: WaColors.forType(r.type)),
                ),
              ]),
              if (r.active) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => actions.skipRecurring(r), child: const Text('Lewati')),
                    TextButton(
                      onPressed: () => ref.read(databaseProvider).saveRecurring(RecurringsCompanion(id: Value(r.id), active: const Value(false))),
                      child: const Text('Jeda'),
                    ),
                    FilledButton.tonal(
                      onPressed: () async {
                        await actions.postRecurringNow(r);
                        if (context.mounted) await showHanko(context, label: '${r.name} tercatat');
                      },
                      child: const Text('Catat sekarang'),
                    ),
                  ],
                ),
              ] else
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => ref.read(databaseProvider).saveRecurring(RecurringsCompanion(id: Value(r.id), active: const Value(true))),
                    child: const Text('Aktifkan lagi'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class RecurringFormScreen extends ConsumerStatefulWidget {
  const RecurringFormScreen({super.key, this.existing, this.subscription = false});

  final Recurring? existing;
  final bool subscription;

  @override
  ConsumerState<RecurringFormScreen> createState() => _RecurringFormScreenState();
}

class _RecurringFormScreenState extends ConsumerState<RecurringFormScreen> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _amount = TextEditingController(text: widget.existing?.amount.toStringAsFixed(0) ?? '');
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late String _type = widget.existing?.type ?? 'expense';
  late int? _accountId = widget.existing?.accountId ?? ref.read(settingsProvider).defaultAccountId;
  late int? _toAccountId = widget.existing?.toAccountId;
  late int? _categoryId = widget.existing?.categoryId;
  late String _frequency = widget.existing?.frequency ?? 'monthly';
  late int _interval = widget.existing?.interval ?? 1;
  late DateTime _next = widget.existing?.nextDate ?? DateTime.now();
  late DateTime? _end = widget.existing?.endDate;
  late bool _auto = widget.existing?.autoPost ?? true;
  late bool _sub = widget.existing?.isSubscription ?? widget.subscription;
  late int _remind = widget.existing?.remindDaysBefore ?? 1;
  late String _icon = widget.existing?.icon ?? (widget.subscription ? '定' : '暦');
  late int _color = widget.existing?.color ?? WaColors.ruri.toARGB32();

  Future<void> _save() async {
    final amount = parseAmount(_amount.text);
    if (_name.text.trim().isEmpty || amount == null || amount <= 0 || _accountId == null) {
      return showSnack(context, 'Isi nama, nominal, dan dompet');
    }
    if (_type == 'transfer' && _toAccountId == null) return showSnack(context, 'Pilih dompet tujuan');
    await ref.read(databaseProvider).saveRecurring(RecurringsCompanion(
          id: widget.existing == null ? const Value.absent() : Value(widget.existing!.id),
          name: Value(_name.text.trim()),
          type: Value(_type),
          amount: Value(amount),
          accountId: Value(_accountId!),
          toAccountId: Value(_type == 'transfer' ? _toAccountId : null),
          categoryId: Value(_type == 'transfer' ? null : _categoryId),
          note: Value(_note.text.trim()),
          frequency: Value(_frequency),
          interval: Value(_interval),
          startDate: Value(widget.existing?.startDate ?? _next),
          nextDate: Value(_next),
          endDate: Value(_end),
          autoPost: Value(_auto),
          remindDaysBefore: Value(_remind),
          isSubscription: Value(_sub),
          active: const Value(true),
          icon: Value(_icon),
          color: Value(_color),
        ));
    await MoneyActions(ref.read(databaseProvider)).processDueRecurrings();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountMapProvider);
    final cats = ref.watch(categoryMapProvider);
    final acc = accounts[_accountId];
    final to = accounts[_toAccountId];
    final cat = cats[_categoryId];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Jadwal Baru' : 'Ubah Jadwal'),
        actions: [
          if (widget.existing != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (!await confirmDialog(context, title: 'Hapus jadwal?', message: 'Transaksi yang sudah tercatat tidak ikut terhapus.')) return;
                await ref.read(databaseProvider).deleteRecurring(widget.existing!.id);
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            GestureDetector(
              onTap: () async {
                final k = await pickKanji(context, current: _icon, color: Color(_color));
                if (k != null) setState(() => _icon = k);
              },
              child: KanjiBadge(glyph: _icon, color: Color(_color), size: 56),
            ),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _name, decoration: const InputDecoration(hintText: 'mis. Gaji, Kos, Netflix'))),
          ]),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'expense', label: Text('Keluar')),
              ButtonSegment(value: 'income', label: Text('Masuk')),
              ButtonSegment(value: 'transfer', label: Text('Transfer')),
            ],
            selected: {_type},
            onSelectionChanged: (v) => setState(() {
              _type = v.first;
              _categoryId = null;
            }),
          ),
          const SizedBox(height: 16),
          LabeledField(
            label: 'Nominal',
            child: TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(prefixText: '${currencyInfo(acc?.currency ?? 'IDR').symbol} '),
            ),
          ),
          LabeledField(
            label: 'Dompet',
            child: PickerTile(
              leading: KanjiBadge(glyph: acc?.icon ?? '財', color: Color(acc?.color ?? WaColors.nezumi.toARGB32()), size: 34),
              title: acc?.name ?? 'Pilih dompet',
              onTap: () async {
                final id = await showAccountPicker(context, ref, selectedId: _accountId);
                if (id != null) setState(() => _accountId = id);
              },
            ),
          ),
          if (_type == 'transfer')
            LabeledField(
              label: 'Ke dompet',
              child: PickerTile(
                leading: KanjiBadge(glyph: to?.icon ?? '財', color: Color(to?.color ?? WaColors.nezumi.toARGB32()), size: 34),
                title: to?.name ?? 'Pilih dompet tujuan',
                onTap: () async {
                  final id = await showAccountPicker(context, ref, selectedId: _toAccountId, excludeId: _accountId);
                  if (id != null) setState(() => _toAccountId = id);
                },
              ),
            )
          else
            LabeledField(
              label: 'Kategori',
              child: PickerTile(
                leading: KanjiBadge(glyph: cat?.icon ?? '？', color: Color(cat?.color ?? WaColors.nezumi.toARGB32()), size: 34),
                title: categoryLabel(cats, _categoryId, empty: 'Pilih kategori'),
                onTap: () async {
                  final id = await showCategoryPicker(context, type: _type, selectedId: _categoryId);
                  if (id != null) setState(() => _categoryId = id);
                },
              ),
            ),
          LabeledField(
            label: 'Frekuensi',
            child: Row(children: [
              Text('Setiap', style: AppTheme.sans()),
              IconButton(onPressed: _interval > 1 ? () => setState(() => _interval--) : null, icon: const Icon(Icons.remove)),
              Text('$_interval', style: AppTheme.serif(size: 18, weight: FontWeight.w700)),
              IconButton(onPressed: () => setState(() => _interval++), icon: const Icon(Icons.add)),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _frequency,
                  items: [for (final e in _freqLabel.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                  onChanged: (v) => setState(() => _frequency = v ?? 'monthly'),
                ),
              ),
            ]),
          ),
          Row(children: [
            Expanded(
              child: ActionChip(
                avatar: const Icon(Icons.event, size: 16),
                label: Text('Berikutnya ${fmtDateShort(_next)}'),
                onPressed: () async {
                  final d = await showDatePicker(context: context, initialDate: _next, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (d != null) setState(() => _next = d);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ActionChip(
                avatar: const Icon(Icons.event_busy, size: 16),
                label: Text(_end == null ? 'Tanpa akhir' : 'Sampai ${fmtDateShort(_end!)}'),
                onPressed: () async {
                  final d = await showDatePicker(context: context, initialDate: _end ?? _next.add(const Duration(days: 365)), firstDate: _next, lastDate: DateTime(2100));
                  setState(() => _end = d);
                },
              ),
            ),
          ]),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Catat otomatis saat jatuh tempo'),
            subtitle: Text('Jika mati, muncul di "Perlu dikonfirmasi"', style: AppTheme.sans(size: 12, color: WaColors.washiMuted)),
            value: _auto,
            onChanged: (v) => setState(() => _auto = v),
          ),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Ini langganan'), value: _sub, onChanged: (v) => setState(() => _sub = v)),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ingatkan'),
            trailing: DropdownButton<int>(
              value: _remind,
              items: const [
                DropdownMenuItem(value: 0, child: Text('Hari H')),
                DropdownMenuItem(value: 1, child: Text('1 hari sebelum')),
                DropdownMenuItem(value: 3, child: Text('3 hari sebelum')),
              ],
              onChanged: (v) => setState(() => _remind = v ?? 1),
            ),
          ),
          LabeledField(label: 'Warna', child: ColorPickerRow(value: _color, onChanged: (c) => setState(() => _color = c))),
          LabeledField(label: 'Catatan transaksi', child: TextField(controller: _note)),
          FilledButton(onPressed: _save, child: const Text('Simpan')),
        ],
      ),
    );
  }
}
