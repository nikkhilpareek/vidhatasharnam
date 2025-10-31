import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

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
  WidgetsFlutterBinding.ensureInitialized();

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
  
  runZonedGuarded(
    () => runApp(const MyApp()),
    (error, stackTrace) {
      AppLogger.critical(
        'Uncaught zone error',
        error: error,
        stackTrace: stackTrace,
      );
    },
  );
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
    // Schedule the initialization after the first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    try {
      // Initialize Firebase first
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      // Initialize Supabase
      await SupabaseConfig.initialize();
      
      // Wait for AuthService to complete initialization
      // This ensures authentication state is determined before navigation
      final authService = AuthService.instance;
      while (!authService.isInitialized) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      
      // Initialize Community Notification Service if user is authenticated
      if (authService.isAuthenticated) {
        await CommunityNotificationService.instance.initialize();
      }
      
      // Add minimum splash duration for better UX (only if auth check was very fast)
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Navigate to AuthWrapper after all initialization is complete
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const AuthWrapper(),
            transitionDuration: const Duration(milliseconds: 300),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'App initialization error',
        error: e,
        stackTrace: stackTrace,
      );
      // If initialization fails, still navigate to AuthWrapper
      // AuthWrapper will handle auth errors gracefully
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const AuthWrapper(),
            transitionDuration: const Duration(milliseconds: 300),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
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
