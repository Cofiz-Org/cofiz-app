import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'core/models/user_model.dart';
import 'core/config/relay_config.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'core/services/fcm_service.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/density_provider.dart';
import 'core/providers/audit_provider.dart';
import 'core/providers/daily_price_provider.dart';
import 'core/providers/worker_provider.dart';
import 'core/providers/settings_provider.dart';
import 'core/services/offline_sync_service.dart';
import 'core/services/notification_service.dart';
import 'core/providers/notification_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/providers/transaction_provider.dart';
import 'core/providers/income_provider.dart';
import 'core/providers/expense_provider.dart';
import 'core/services/income_service.dart';
import 'core/services/expense_service.dart';
import 'core/services/auth_backend.dart';
import 'core/services/auth_backend_firebase.dart';
import 'core/providers/phone_otp_auth_provider.dart';
import 'core/providers/update_provider.dart';
import 'core/services/pin_service.dart';
import 'core/providers/lock_state_provider.dart';
import 'core/services/idle_lock_service.dart';
import 'core/utils/app_navigator.dart';
import 'core/services/debt_service.dart';
import 'core/providers/debt_provider.dart';
import 'core/services/notification_trigger_service.dart';
import 'presentation/screens/auth/create_pin_screen.dart';
import 'presentation/screens/auth/pin_lock_screen.dart';
import 'presentation/widgets/custom_bottom_nav.dart';
import 'presentation/widgets/double_back_exit.dart';
import 'presentation/widgets/app_toast.dart';
import 'presentation/widgets/animated_splash_screen.dart';
import 'presentation/widgets/telegram_login_listener.dart';
import 'presentation/screens/auth/phone_login_screen.dart';
import 'presentation/widgets/background_pattern.dart';
import 'presentation/screens/reports/reports_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'presentation/screens/dashboard/dashboard_screen.dart';
import 'presentation/screens/worker_list/worker_list_screen.dart';
import 'presentation/screens/worker/worker_dashboard_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

bool shouldAnimateTabSwitch(int from, int to) => (to - from).abs() == 1;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    if (!e.toString().contains('duplicate-app')) {
      rethrow;
    }
  }
  debugPrint('[main] Firebase ready');

  debugPrint('[main] initializing RelayConfig...');
  await RelayConfig.init();
  debugPrint('[main] RelayConfig ready');

  FCMService().setup();

  final notificationService = NotificationService();
  debugPrint('[main] initializing NotificationService...');
  await notificationService.initialize();
  debugPrint('[main] NotificationService ready');

  final offlineSyncService = OfflineSyncService();
  debugPrint('[main] initializing OfflineSyncService...');
  await offlineSyncService.initialize();
  debugPrint('[main] OfflineSyncService ready');

  debugPrint('[main] runApp');
  runApp(StitchWorkerApp(
    notificationService: notificationService,
    offlineSyncService: offlineSyncService,
  ));
  debugPrint('[main] first frame scheduled; network services deferred');

  WidgetsBinding.instance.addPostFrameCallback((_) {
    _initializeNetworkServices();
  });
}

Future<void> _initializeNetworkServices() async {
  try {
    await Future.wait([
      FCMService().initialize(),
      IncomeService().initializeDefaultSaleCategories(),
      ExpenseService().initializeDefaultExpenseCategories(),
      DebtService().wipeLegacyCollectorDebtsOnce(),
    ]);
  } catch (e) {
    debugPrint('Background service initialization failed: $e');
  }
}

class StitchWorkerApp extends StatefulWidget {
  final NotificationService notificationService;
  final OfflineSyncService offlineSyncService;

  const StitchWorkerApp({
    super.key,
    required this.notificationService,
    required this.offlineSyncService,
  });

  @override
  State<StitchWorkerApp> createState() => _StitchWorkerAppState();
}

class _StitchWorkerAppState extends State<StitchWorkerApp> {
  late final PinService _pinService;
  late final LockStateProvider _lockState;
  late final IdleLockService _idleLock;
  late final PhoneOtpAuthProvider _phoneAuth;
  late final FocusNode _rootFocusNode;

  void _onFocusActivity() => _idleLock.onUserInteraction();

  @override
  void initState() {
    super.initState();
    _pinService = PinService();
    _lockState = LockStateProvider(pinService: _pinService);
    _rootFocusNode = FocusNode();
    _phoneAuth = PhoneOtpAuthProvider(
      backend: AuthBackend(
        baseUrl: RelayConfig.relayUrl.isNotEmpty ? RelayConfig.relayUrl : 'https://cofiz.natanim.dev',
        secret: RelayConfig.relaySecret,
      ),
      firebaseAuth: AuthBackendFirebase(),
      pinService: _pinService,
    );
    _idleLock = IdleLockService(lockState: _lockState);
    _lockState.initialize().whenComplete(() {
      if (mounted) _idleLock.attach();
    });
    FocusManager.instance.addListener(_onFocusActivity);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusActivity);
    _rootFocusNode.dispose();
    _idleLock.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: widget.notificationService),
        ChangeNotifierProvider<PhoneOtpAuthProvider>.value(value: _phoneAuth),
        ChangeNotifierProvider<LockStateProvider>.value(value: _lockState),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => WorkerProvider()),
        ChangeNotifierProxyProvider<WorkerProvider, TransactionProvider>(
          create: (_) => TransactionProvider(),
          update: (_, workerProvider, txProvider) {
            txProvider!.onTransactionApplied = (tx, direction) => workerProvider.applyTransactionDelta(tx, direction);
            return txProvider;
          },
        ),
        ChangeNotifierProvider(create: (_) => IncomeProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => DensityProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => DailyPriceProvider()),
        ChangeNotifierProvider(create: (_) => AuditProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => UpdateProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => DebtProvider(debtService: DebtService(), notificationService: NotificationTriggerService())..initialize()),
      ],
      child: Consumer3<ThemeProvider, SettingsProvider, DensityProvider>(
        builder: (context, themeProvider, settingsProvider, densityProvider, _) {
          return MaterialApp(
            title: 'Cofiz',
            navigatorKey: AppNavigator.key,
            locale: settingsProvider.locale,
            theme: AppTheme.lightTheme.copyWith(visualDensity: densityProvider.visualDensity),
            darkTheme: AppTheme.darkTheme.copyWith(visualDensity: densityProvider.visualDensity),
            themeMode: themeProvider.themeMode,
            debugShowCheckedModeBanner: false,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('am')],
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              final systemScale = mq.textScaler.scale(14) / 14;
              return ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: AppToastHost(
                  child: MediaQuery(
                    data: mq.copyWith(textScaler: TextScaler.linear(systemScale * densityProvider.textScaleFactor)),
                    child: Focus(
                      focusNode: _rootFocusNode,
                      onKeyEvent: (node, event) {
                        _idleLock.onUserInteraction();
                        return KeyEventResult.ignored;
                      },
                      child: Listener(
                        behavior: HitTestBehavior.translucent,
                        onPointerDown: (_) => _idleLock.onUserInteraction(),
                        onPointerMove: (_) => _idleLock.onUserInteraction(),
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (n) {
                            _idleLock.onUserInteraction();
                            return false;
                          },
                          child:
                              TelegramLoginListener(child: child!),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  static const Duration _minSplashDuration = Duration(milliseconds: 1400);

  bool _splashElapsed = false;
  String? _lastInitUid;

  @override
  void initState() {
    super.initState();
    Timer(_minSplashDuration, () {
      if (mounted) setState(() => _splashElapsed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<AuthProvider, LockStateProvider, PhoneOtpAuthProvider>(
      builder: (context, authProvider, lockState, otpProvider, _) {
        if (authProvider.isAuthenticated && authProvider.user != null) {
          final uid = authProvider.user!.uid;
          if (_lastInitUid != uid) {
            _lastInitUid = uid;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Provider.of<NotificationProvider>(context, listen: false).init(uid);
              lockState.initialize(uid: uid);
            });
          }
        } else {
          if (_lastInitUid != null) {
            _lastInitUid = null;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Provider.of<NotificationProvider>(context, listen: false).disposeListener();
              lockState.onSignedOut();
            });
          } else {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Provider.of<NotificationProvider>(context, listen: false).disposeListener();
            });
          }
        }
        if (authProvider.status == AuthStatus.uninitialized || !_splashElapsed) {
          return const AnimatedSplashScreen();
        }

        if (!authProvider.isAuthenticated &&
            (otpProvider.state == OtpAuthState.verifying ||
                otpProvider.state == OtpAuthState.awaitingTelegramReturn ||
                otpProvider.isAuthenticated)) {
          return const AnimatedSplashScreen();
        }

        if (authProvider.isAuthenticated &&
            lockState.state == PinLockState.awaitingFirstSetup) {
          return const CreatePinScreen();
        }

        if (authProvider.isAuthenticated && !lockState.isInitialized) {
          final theme = Theme.of(context);
          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: const Stack(
              children: [
                BackgroundPattern(),
                SafeArea(
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (authProvider.isAuthenticated &&
            lockState.state == PinLockState.locked) {
          return const PopScope(
            canPop: false,
            child: PinLockScreen(),
          );
        }

        final Widget content = (() {
        if (authProvider.isAuthenticated) {
          if (authProvider.userRole == null) {
            if (authProvider.status == AuthStatus.loading) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Account Not Set Up',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Your account has not been configured yet. Please contact an administrator to set up your account.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await authProvider.signOut();
                          if (context.mounted) {
                            await Provider.of<PhoneOtpAuthProvider>(context, listen: false).signOut();
                          }
                        },
                        icon: const Icon(Icons.logout),
                        label: const Text('Sign Out'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          switch (authProvider.userRole!) {
            case UserRole.admin:
              return MainLayout(
                  key: ValueKey('main-${authProvider.user!.uid}'));
            case UserRole.viewer:
              return MainLayout(
                  key: ValueKey('main-${authProvider.user!.uid}'));
            case UserRole.worker:
              if (authProvider.workerId != null) {
                return WorkerDashboardScreen(
                  key: ValueKey('worker-${authProvider.workerId}'),
                  workerId: authProvider.workerId!,
                );
              } else {
                return const Scaffold(
                  body: Center(
                    child: Text(
                        'Error: Collector account not properly configured'),
                  ),
                );
              }
          }
        }

        return const PhoneLoginScreen();
        })();

        final String switchKey;
        if (authProvider.isAuthenticated &&
            lockState.state == PinLockState.locked) {
          switchKey = 'locked';
        } else if (authProvider.isAuthenticated && !lockState.isInitialized) {
          switchKey = 'lock-loading';
        } else if (authProvider.isAuthenticated &&
            lockState.state == PinLockState.awaitingFirstSetup) {
          switchKey = 'pin-setup';
        } else if (authProvider.isAuthenticated) {
          switchKey = 'main-${authProvider.user?.uid}';
        } else {
          switchKey = 'login-${otpProvider.state}';
        }
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          layoutBuilder: (currentChild, previousChildren) => Stack(
            children: [...previousChildren, if (currentChild != null) currentChild],
          ),
          child: KeyedSubtree(
            key: ValueKey(switchKey),
            child: content,
          ),
        );
      },
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  static final GlobalKey<_MainLayoutState> _mainLayoutKey =
      GlobalKey<_MainLayoutState>();

  static void navigateTo(int index) {
    _mainLayoutKey.currentState?._onNavTap(index);
  }

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  late PageController _pageController;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const WorkerListScreen(),
    const ReportsScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onNavTap(int index) {
    if (shouldAnimateTabSwitch(_currentIndex, index)) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _pageController.jumpToPage(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DoubleBackExit(
      child: Scaffold(
        body: Stack(
          children: [
            const BackgroundPattern(),
            PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: _screens,
            ),

            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: CustomBottomNav(
                currentIndex: _currentIndex,
                onTap: _onNavTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
