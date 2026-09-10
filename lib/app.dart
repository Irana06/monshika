import 'dart:async';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import 'core/theme/app_theme.dart';
import 'features/lock/lock_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/shell/app_shell.dart';
import 'features/transactions/quick_input_sheet.dart';
import 'features/transactions/transaction_form_screen.dart';
import 'providers/providers.dart';
import 'services/app_services.dart';
import 'services/home_widget_sync.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

class MonshikaApp extends ConsumerStatefulWidget {
  const MonshikaApp({super.key});

  @override
  ConsumerState<MonshikaApp> createState() => _MonshikaAppState();
}

class _MonshikaAppState extends ConsumerState<MonshikaApp> with WidgetsBindingObserver {
  bool _locked = false;
  DateTime? _pausedAt;
  StreamSubscription<Uri?>? _widgetClicks;
  StreamSubscription<Object>? _dbChanges;
  Timer? _widgetDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locked = ref.read(settingsProvider).lockEnabled;

    final db = ref.read(databaseProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      runStartupTasks(db, ref.read(settingsProvider), first: true);
    });

    // Setiap data berubah → perbarui widget beranda (di-debounce).
    _dbChanges = db
        .tableUpdates(TableUpdateQuery.onAllTables(db.allTables))
        .listen((_) {
      _widgetDebounce?.cancel();
      _widgetDebounce = Timer(const Duration(milliseconds: 1500), () {
        if (isMobile) HomeWidgetSync.refresh(db);
      });
    });

    if (isMobile) {
      HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleWidgetUri);
      _widgetClicks = HomeWidget.widgetClicked.listen(_handleWidgetUri);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _widgetClicks?.cancel();
    _dbChanges?.cancel();
    _widgetDebounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final settings = ref.read(settingsProvider);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final db = ref.read(databaseProvider);
      // Widget / dialog quick-add mungkin menulis data dari engine lain.
      db.refreshAllStreams();
      ref.read(settingsProvider.notifier).reload();
      if (settings.lockEnabled &&
          _pausedAt != null &&
          DateTime.now().difference(_pausedAt!).inSeconds >= settings.lockDelaySeconds) {
        setState(() => _locked = true);
      }
      _pausedAt = null;
      runStartupTasks(db, settings);
    }
  }

  void _handleWidgetUri(Uri? uri) {
    if (uri == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = rootNavigatorKey.currentState;
      final ctx = rootNavigatorKey.currentContext;
      if (nav == null || ctx == null || !ref.read(settingsProvider).onboardingDone) return;
      switch (uri.host) {
        case 'add':
          nav.push(MaterialPageRoute(
            builder: (_) => TransactionFormScreen(initialType: uri.queryParameters['type'] ?? 'expense'),
          ));
        case 'quick':
          showQuickInputSheet(ctx);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    Widget home;
    if (!settings.onboardingDone) {
      home = const OnboardingScreen();
    } else if (_locked && settings.lockEnabled) {
      home = LockScreen(onUnlocked: () => setState(() => _locked = false));
    } else {
      home = const AppShell();
    }

    return MaterialApp(
      title: 'Monshika',
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      locale: const Locale('id'),
      supportedLocales: const [Locale('id'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AnimatedSwitcher(duration: const Duration(milliseconds: 350), child: home),
    );
  }
}
