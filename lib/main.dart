import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
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

Future<void> main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await LocalStorageService.init();
      FlutterError.onError = (FlutterErrorDetails details) {
        AppLogger.critical(
          'Uncaught Flutter framework error',
          error: details.exception,
          stackTrace: details.stack,
        );
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      };

      // Initialize Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      runApp(const MyApp());
    },
    (error, stackTrace) {
      AppLogger.critical(
        'Uncaught zone error',
        error: error,
        stackTrace: stackTrace,
      );
      FirebaseCrashlytics.instance.recordError(error, stackTrace, fatal: true);
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
          update: (_, authService, __) =>
              AuthRepositoryImpl(authService: authService),
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
