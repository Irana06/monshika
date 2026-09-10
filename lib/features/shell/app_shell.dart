import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../home/home_screen.dart';
import '../more/more_screen.dart';
import '../stats/stats_screen.dart';
import '../transactions/quick_input_sheet.dart';
import '../transactions/transaction_form_screen.dart';
import '../transactions/transactions_screen.dart';

final shellTabProvider = NotifierProvider<ShellTabNotifier, int>(ShellTabNotifier.new);

class ShellTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void go(int i) => state = i;
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const _tabs = [
    ('家', 'Beranda'),
    ('記', 'Transaksi'),
    ('析', 'Statistik'),
    ('他', 'Lainnya'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(shellTabProvider);
    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(shellTabProvider.notifier).go(0);
      },
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(
          index: index,
          children: const [HomeScreen(), TransactionsScreen(), StatsScreen(), MoreScreen()],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: GestureDetector(
          onLongPress: () {
            HapticFeedback.mediumImpact();
            showQuickInputSheet(context);
          },
          child: FloatingActionButton(
            heroTag: 'add-tx',
            tooltip: 'Tambah transaksi (tahan untuk input cepat)',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionFormScreen())),
            child: const Icon(Icons.add, size: 30),
          ),
        ),
        bottomNavigationBar: BottomAppBar(
          color: WaColors.keshizumi,
          surfaceTintColor: Colors.transparent,
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          height: 68,
          padding: EdgeInsets.zero,
          child: Row(
            children: [
              for (var i = 0; i < _tabs.length; i++) ...[
                if (i == 2) const SizedBox(width: 72),
                Expanded(
                  child: _TabButton(
                    kanji: _tabs[i].$1,
                    label: _tabs[i].$2,
                    selected: i == index,
                    onTap: () => ref.read(shellTabProvider.notifier).go(i),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.kanji, required this.label, required this.selected, required this.onTap});

  final String kanji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? WaColors.accent : WaColors.washiMuted;
    return InkResponse(
      onTap: onTap,
      radius: 36,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: AppTheme.serif(size: selected ? 22 : 19, weight: FontWeight.w700, color: color),
            child: Text(kanji),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTheme.sans(size: 10.5, color: color, weight: selected ? FontWeight.w700 : FontWeight.w500)),
        ],
      ),
    );
  }
}
