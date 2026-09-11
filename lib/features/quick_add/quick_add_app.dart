import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/strings.dart';
import '../../providers/providers.dart';
import '../../services/home_widget_sync.dart';
import '../transactions/quick_input_sheet.dart';
import '../transactions/transaction_form_screen.dart';

/// Aplikasi mini untuk QuickAddActivity (dibuka dari widget beranda).
/// Latar transparan sehingga terasa seperti dialog di atas home screen.
class QuickAddApp extends ConsumerWidget {
  const QuickAddApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    S.current = s;
    final theme = AppTheme.dark();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme.copyWith(scaffoldBackgroundColor: Colors.transparent),
      locale: s.locale,
      supportedLocales: const [Locale('id'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => SScope(s: s, child: child ?? const SizedBox.shrink()),
      home: const _QuickAddHost(),
    );
  }
}

class _QuickAddHost extends ConsumerStatefulWidget {
  const _QuickAddHost();

  @override
  ConsumerState<_QuickAddHost> createState() => _QuickAddHostState();
}

class _QuickAddHostState extends ConsumerState<_QuickAddHost> {
  Uri? _uri;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
      if (!mounted) return;
      setState(() {
        _uri = uri;
        _ready = true;
      });
    }).catchError((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  Future<void> _close({bool saved = false}) async {
    // Jangan render grafik di engine dialog ini (bisa crash di sebagian GPU);
    // grafik diperbarui saat aplikasi utama dibuka.
    if (saved) await HomeWidgetSync.refresh(ref.read(databaseProvider), renderChart: false);
    await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final settings = ref.watch(settingsProvider);
    final accounts = ref.watch(accountsProvider);
    final type = _uri?.queryParameters['type'];
    final mode = _uri?.queryParameters['mode'] ?? 'quick';

    Widget content;
    if (!_ready || accounts.isLoading) {
      content = const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
    } else if (!settings.onboardingDone || (accounts.value ?? const []).isEmpty) {
      content = Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(s.t('Belum ada dompet', 'No wallet yet'), style: AppTheme.serif(size: 20, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            s.t('Buka Monshika dulu untuk membuat dompet pertama.', 'Open Monshika first to set up your first wallet.'),
            textAlign: TextAlign.center,
            style: AppTheme.sans(color: WaColors.washiMuted),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => _close(), child: Text(s.ok)),
        ]),
      );
    } else if (mode == 'form') {
      return Navigator(
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (_) => TransactionFormScreen(initialType: type ?? 'expense', onSaved: () => _close(saved: true)),
        ),
      );
    } else {
      content = QuickInputPanel(
        initialType: type,
        onSaved: () => _close(saved: true),
        onOpenForm: (parsed, accountId, categoryId) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => TransactionFormScreen(
              initialType: parsed.type,
              initialAmount: parsed.amount,
              initialAccountId: accountId,
              initialCategoryId: categoryId,
              initialNote: parsed.note,
              onSaved: () => _close(saved: true),
            ),
          ));
        },
      );
    }

    return Scaffold(
      backgroundColor: Colors.black54,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _close(),
        child: SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {},
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.only(top: 16),
                decoration: BoxDecoration(
                  color: WaColors.keshizumi,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: WaColors.border),
                ),
                child: Material(color: Colors.transparent, child: content),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
