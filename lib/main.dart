import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'auth_wrapper.dart';
import 'splash_screen.dart';
import 'config/supabase_config.dart';
import 'services/auth_service.dart';
import 'services/community_notification_service.dart';
import 'app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Vidhatasharanam',
      theme: AppTheme.lightTheme, // Use the theme from app_theme.dart
      home: const AppInitializer(),
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
    _initializeApp();
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
    } catch (e) {
      print('App initialization error: $e');
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
