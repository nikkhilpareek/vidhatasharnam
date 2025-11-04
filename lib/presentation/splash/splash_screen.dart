import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/config/app_constants.dart';
import '../../data/datasources/auth/auth_service.dart';
import '../../data/datasources/community/community_notification_service.dart';
import '../../config/supabase_config.dart';
import '../../core/logger/app_logger.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    try {
      // Initialize Supabase
      await SupabaseConfig.initialize();

      // Initialize AuthService
      await AuthService.instance.init();

      // Wait for AuthService to complete initialization
      final authService = AuthService.instance;
      while (!authService.isInitialized) {
        await Future.delayed(const Duration(milliseconds: 50));
      }

      // Add minimum splash duration for better UX
      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;

      // Navigate based on auth status
      if (authService.isAuthenticated) {
        // Initialize Community Notification Service
        await CommunityNotificationService.instance.initialize();

        final userData = authService.userData!;
        if (userData.role == "admin") {
          Navigator.of(context).pushReplacementNamed(
            AppConstants.navigateToAdminPanel,
            arguments: userData.displayName,
          );
        } else {
          Navigator.of(context).pushReplacementNamed(
            AppConstants.navigateToHomeScreen,
          );
        }
      } else {
        Navigator.of(context).pushReplacementNamed(
          AppConstants.navigateToLoginScreen,
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'App initialization error',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(
          AppConstants.navigateToLoginScreen,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
