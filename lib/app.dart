import 'dart:async';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import 'core/theme/app_theme.dart';
import 'features/lock/lock_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/shell/app_shell.dart';
import 'features/transactions/quick_input_sheet.dart';
import 'features/transactions/transaction_form_screen.dart';
import 'features/update/update_ui.dart';
import 'l10n/strings.dart';
import 'providers/providers.dart';
import 'services/app_services.dart';
import 'services/home_widget_sync.dart';
import 'services/update_service.dart';

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
  bool _updateSheetOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locked = ref.read(settingsProvider).lockEnabled;

    final db = ref.read(databaseProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      runStartupTasks(db, ref.read(settingsProvider), first: true);
      _checkForUpdate();
    });

    // Setiap data berubah, perbarui widget beranda (dengan jeda singkat).
    _dbChanges = db.tableUpdates(TableUpdateQuery.onAllTables(db.allTables)).listen((_) {
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

  /// Cek rilis baru di GitHub; tampilkan dialog kecuali versi itu sudah ditunda.
  Future<void> _checkForUpdate({bool force = false}) async {
    if (!isMobile) return;
    final release = await ref.read(updateProvider.notifier).check(force: force);
    if (release == null || _updateSheetOpen) return;
    if (await UpdateService.isDismissed(release.version)) return;
    final settings = ref.read(settingsProvider);
    if (!settings.onboardingDone || (_locked && settings.lockEnabled)) return;
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    _updateSheetOpen = true;
    await showUpdateSheet(ctx, release);
    _updateSheetOpen = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final settings = ref.read(settingsProvider);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final db = ref.read(databaseProvider);
      // Widget atau dialog catat cepat mungkin menulis data dari engine lain.
      db.refreshAllStreams();
      ref.read(settingsProvider.notifier).reload();
      if (settings.lockEnabled &&
          _pausedAt != null &&
          DateTime.now().difference(_pausedAt!).inSeconds >= settings.lockDelaySeconds) {
        setState(() => _locked = true);
      }
      _pausedAt = null;
      runStartupTasks(db, settings);
      _checkForUpdate();
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
    final s = settings.strings;
    S.current = s;
    Intl.defaultLocale = s.dateLocale;

    Widget home;
    if (!settings.onboardingDone) {
      home = const OnboardingScreen();
    } else if (_locked && settings.lockEnabled) {
      home = LockScreen(onUnlocked: () {
        setState(() => _locked = false);
        WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
      });
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
      locale: s.locale,
      supportedLocales: const [Locale('id'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => SScope(s: s, child: child ?? const SizedBox.shrink()),
      home: AnimatedSwitcher(duration: const Duration(milliseconds: 350), child: home),
    );
  }
}
