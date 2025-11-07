import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:vidhatasharnam/domain/repositories/local_storage.dart';

import 'firebase_options.dart';
import 'package:vidhatasharnam/core/config/app_constants.dart';
import 'package:vidhatasharnam/core/routes/app_routes.dart';
import 'package:vidhatasharnam/admin/admin_panel.dart';
import 'package:vidhatasharnam/data/datasources/auth/auth_service.dart';
import 'package:vidhatasharnam/core/theme/app_theme.dart';
import 'package:vidhatasharnam/core/logger/app_logger.dart';
import 'package:vidhatasharnam/core/exceptions/exception_handler.dart';
import 'package:vidhatasharnam/data/repositories/auth_repository_impl.dart';
import 'package:vidhatasharnam/domain/repositories/auth_repository.dart';
import 'package:vidhatasharnam/presentation/auth/login/login_view_model.dart';
import 'package:vidhatasharnam/presentation/auth/register/register_view_model.dart';
import 'package:vidhatasharnam/config/supabase_config.dart';

// Global variable to track initialization state
bool _isInitialized = false;
final _initializationCompleter = Completer<void>();

Future<void> main() async {
  final mainStartTime = DateTime.now();
  debugPrint('⏱️ [TIMING] main() start: $mainStartTime');
  
  // Step 1: Initialize Flutter binding (required first)
  final bindingStartTime = DateTime.now();
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('⏱️ [TIMING] WidgetsFlutterBinding.ensureInitialized: ${DateTime.now().difference(bindingStartTime).inMilliseconds}ms');
  
  // Step 2: Initialize LocalStorage (lightweight, fast)
  final storageStartTime = DateTime.now();
  await LocalStorageService.init();
  debugPrint('⏱️ [TIMING] LocalStorageService.init: ${DateTime.now().difference(storageStartTime).inMilliseconds}ms');
  
  // Step 3: Set up error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    AppLogger.critical(
      'Uncaught Flutter framework error',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  // Step 4: Start async initialization (non-blocking)
  _initializeAsync().then((_) {
    final initDuration = DateTime.now().difference(mainStartTime);
    debugPrint('⏱️ [TIMING] Total initialization complete: ${initDuration.inMilliseconds}ms');
    debugPrint('✅ All services initialized');
  }).catchError((error, stackTrace) {
    AppLogger.critical(
      'Initialization error',
      error: error,
      stackTrace: stackTrace,
    );
  });

  // Step 5: Show app IMMEDIATELY (will show splash until initialization completes)
  final splashStartTime = DateTime.now();
  runApp(const _RootApp());
  debugPrint('⏱️ [TIMING] App shown: ${DateTime.now().difference(splashStartTime).inMilliseconds}ms');
  debugPrint('⏱️ [TIMING] Time to first UI: ${DateTime.now().difference(mainStartTime).inMilliseconds}ms');
}

/// Root app that conditionally shows splash or main app
class _RootApp extends StatefulWidget {
  const _RootApp();

  @override
  State<_RootApp> createState() => _RootAppState();
}

class _RootAppState extends State<_RootApp> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    debugPrint('⏱️ [TIMING] RootApp initState: ${DateTime.now()}');
    
    // Wait for initialization to complete
    _initializationCompleter.future.then((_) {
      if (mounted) {
        setState(() {
          _initialized = true;
        });
        debugPrint('⏱️ [TIMING] Swapped to main app: ${DateTime.now()}');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_initialized) {
      return const MyApp();
    }
    
    // Show lightweight splash while initializing
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Vidhatasharanam',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.grey.shade50, // Match LaunchScreen
        useMaterial3: true,
      ),
      home: const _SplashPlaceholder(),
    );
  }
}

/// Placeholder splash screen matching LaunchScreen background
class _SplashPlaceholder extends StatelessWidget {
  const _SplashPlaceholder();

  @override
  Widget build(BuildContext context) {
    debugPrint('⏱️ [TIMING] SplashPlaceholder built: ${DateTime.now()}');
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.business,
                      size: 60,
                      color: AppTheme.iconColor,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'VIDHATASHARANAM',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Turning land into legacy',
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary.withOpacity(0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Initialize heavy services asynchronously
Future<void> _initializeAsync() async {
  if (_isInitialized) return;
  
  try {
    // Initialize Firebase (may already be initialized by AppDelegate)
    final firebaseStartTime = DateTime.now();
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      debugPrint('⏱️ [TIMING] Firebase.initializeApp: ${DateTime.now().difference(firebaseStartTime).inMilliseconds}ms');
    } catch (e) {
      // Firebase may already be initialized by AppDelegate
      debugPrint('⚠️ Firebase init note: $e');
    }

    // Initialize Supabase
    final supabaseStartTime = DateTime.now();
    try {
      await SupabaseConfig.initialize();
      debugPrint('⏱️ [TIMING] Supabase.initialize: ${DateTime.now().difference(supabaseStartTime).inMilliseconds}ms');
    } catch (e) {
      debugPrint('⚠️ Supabase initialization error: $e');
      // Continue even if Supabase fails - it may be initialized elsewhere
    }

    // Initialize AuthService (if needed)
    final authStartTime = DateTime.now();
    // AuthService.instance.init() is called in SplashScreen if needed
    debugPrint('⏱️ [TIMING] AuthService ready: ${DateTime.now().difference(authStartTime).inMilliseconds}ms');

    _isInitialized = true;
    _initializationCompleter.complete();
  } catch (e, stackTrace) {
    _initializationCompleter.completeError(e, stackTrace);
    rethrow;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('⏱️ [TIMING] MyApp.build() called: ${DateTime.now()}');
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: AuthService.instance),
        Provider<ExceptionHandler>(create: (_) => const ExceptionHandler()),
        ProxyProvider<AuthService, AuthRepository>(
          update: (_, authService, __) =>
              AuthRepositoryImpl(authService: authService),
        ),
        ChangeNotifierProvider<LoginViewModel>(
          create: (context) => LoginViewModel(
            authRepository: context.read<AuthRepository>(),
            exceptionHandler: context.read<ExceptionHandler>(),
          ),
        ),
        ChangeNotifierProvider<RegisterViewModel>(
          create: (context) => RegisterViewModel(
            authRepository: context.read<AuthRepository>(),
            exceptionHandler: context.read<ExceptionHandler>(),
          ),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Vidhatasharanam',
        theme: AppTheme.lightTheme,
        initialRoute: AppConstants.navigateToSplashScreen,
        routes: AppRoutes.getRoutes(),
        onGenerateRoute: (settings) {
          // Handle arguments for admin panel
          if (settings.name == AppConstants.navigateToAdminPanel) {
            final username = settings.arguments as String? ?? 'Admin';
            return MaterialPageRoute(
              builder: (_) => AdminPanel(username: username),
            );
          }
          return null;
        },
      ),
    );
  }
}
