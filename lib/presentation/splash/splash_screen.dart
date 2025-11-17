import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/config/app_constants.dart';
import '../../core/logger/app_logger.dart';
import 'splash_view_model.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final DateTime _splashStartTime;
  
  @override
  void initState() {
    super.initState();
    _splashStartTime = DateTime.now();
    debugPrint('⏱️ [TIMING] SplashScreen.initState() called: ${DateTime.now()}');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final firstFrameTime = DateTime.now();
      final timeToFirstFrame = firstFrameTime.difference(_splashStartTime);
      debugPrint('⏱️ [TIMING] SplashScreen first frame rendered: ${timeToFirstFrame.inMilliseconds}ms from widget init');
      _checkLoginStatus();
    });
  }

  Future<void> _checkLoginStatus() async {
    try {
      final viewModel = context.read<SplashViewModel>();
      final result = await viewModel.checkLoginStatus();

      if (!mounted) return;

      final isLoggedIn = result['isLoggedIn'] as bool;
      final userRole = result['userRole'] as String;
      final userName = result['userName'] as String;

      debugPrint('[SplashScreen] Login status: $isLoggedIn, Role: $userRole');

      if (isLoggedIn) {
        if (userRole.toLowerCase() == 'admin') {
          debugPrint('[SplashScreen] Navigating to AdminPanel as: $userName');
          Navigator.of(context).pushReplacementNamed(
            AppConstants.navigateToAdminPanel,
            arguments: userName,
          );
        } else {
          debugPrint('[SplashScreen] Navigating to HomeScreen');
          Navigator.of(context).pushReplacementNamed(
            AppConstants.navigateToHomeScreen,
          );
        }
      } else {
        debugPrint('[SplashScreen] Not logged in, navigating to LoginScreen');
        Navigator.of(context).pushReplacementNamed(
          AppConstants.navigateToLoginScreen,
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error checking login status in splash screen',
        error: e,
        stackTrace: stackTrace,
      );
      debugPrint('[SplashScreen] Error: $e');
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
