import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';
import 'package:vidhatasharnam/presentation/auth/auth_wrapper.dart';
import 'package:vidhatasharnam/presentation/splash/splash_screen.dart';
import 'config/supabase_config.dart';
import 'package:vidhatasharnam/data/datasources/auth/auth_service.dart';
import 'package:vidhatasharnam/data/datasources/community/community_notification_service.dart';
import 'package:vidhatasharnam/core/theme/app_theme.dart';
import 'package:vidhatasharnam/core/logger/app_logger.dart';
import 'package:vidhatasharnam/core/exceptions/exception_handler.dart';
import 'package:vidhatasharnam/data/repositories/auth_repository_impl.dart';
import 'package:vidhatasharnam/domain/repositories/auth_repository.dart';
import 'package:vidhatasharnam/presentation/auth/login/login_view_model.dart';

Future<void> main() async {
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Configure global error handlers inside the same zone
    FlutterError.onError = (FlutterErrorDetails details) {
      AppLogger.critical(
        'Uncaught Flutter framework error',
        error: details.exception,
        stackTrace: details.stack,
      );
    };

    WidgetsBinding.instance.platformDispatcher.onError = (error, stackTrace) {
      AppLogger.critical(
        'Uncaught platform error',
        error: error,
        stackTrace: stackTrace,
      );
      return true;
    };

    // Avoid runtime font fetches (works offline; falls back if not bundled)
    GoogleFonts.config.allowRuntimeFetching = false;

    runApp(const MyApp());
  }, (error, stackTrace) {
    AppLogger.critical(
      'Uncaught zone error',
      error: error,
      stackTrace: stackTrace,
    );
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: AuthService.instance),
        Provider<ExceptionHandler>(create: (_) => const ExceptionHandler()),
        ProxyProvider<AuthService, AuthRepository>(
          update: (_, authService, __) => AuthRepositoryImpl(authService: authService),
        ),
        ChangeNotifierProvider<LoginViewModel>(
          create: (context) => LoginViewModel(
            authRepository: context.read<AuthRepository>(),
            exceptionHandler: context.read<ExceptionHandler>(),
          ),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Vidhatasharanam',
        theme: AppTheme.lightTheme,
        home: const AppInitializer(),
      ),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeApp());
  }

  Future<void> _initializeApp() async {
    try {
      // Try Firebase (but don’t block if it fails)
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (e) {
        debugPrint('⚠️ Firebase init failed: $e');
      }

      await AuthService.instance.init();

      // ✅ Ensure HTTPS in SupabaseConfig
      await SupabaseConfig.initialize();

      final authService = AuthService.instance;

      // Wait until AuthService finishes setup
      while (!authService.isInitialized) {
        await Future.delayed(const Duration(milliseconds: 50));
      }

      if (authService.isAuthenticated) {
        await CommunityNotificationService.instance.initialize();
      }

      // Short splash delay for smoother UX
      await Future.delayed(const Duration(milliseconds: 600));

      // ✅ Always navigate after init (even if partial failure)
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const AuthWrapper(),
            transitionDuration: const Duration(milliseconds: 400),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error('App initialization error', error: e, stackTrace: stackTrace);

      // ✅ Fail-safe navigation (never stay on blank screen)
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const AuthWrapper(),
            transitionDuration: const Duration(milliseconds: 400),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}
