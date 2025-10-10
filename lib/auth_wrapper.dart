import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'my_home_page.dart';
import 'admin/admin_panel.dart';
import 'splash_screen.dart';
import 'services/auth_service.dart';
import 'services/community_notification_service.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late AuthService _authService;
  String? _inactiveMessage;

  @override
  void initState() {
    super.initState();
    _authService = AuthService.instance;
    _authService.addListener(_onAuthStateChanged);
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthStateChanged);
    super.dispose();
  }

  void _onAuthStateChanged() {
    if (mounted) {
      setState(() {
        // Clear any previous inactive message when auth state changes
        if (_authService.status == AuthStatus.authenticated) {
          _inactiveMessage = null;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show splash screen while auth service is initializing
    if (!_authService.isInitialized) {
      return const SplashScreen();
    }

    switch (_authService.status) {
      case AuthStatus.loading:
        return const SplashScreen();
      
      case AuthStatus.authenticated:
        // Initialize community notifications when user is authenticated
        WidgetsBinding.instance.addPostFrameCallback((_) {
          CommunityNotificationService.instance.initialize();
        });
        
        final userData = _authService.userData!;
        if (userData.role == "admin") {
          return AdminPanel(username: userData.displayName);
        } else {
          return const MyHomePage(title: "Vidhatasharanam");
        }
      
      case AuthStatus.unauthenticated:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_inactiveMessage != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_inactiveMessage!),
                backgroundColor: Colors.red,
              ),
            );
            _inactiveMessage = null;
          }
        });
        return const LoginScreen();
      
      case AuthStatus.unknown:
        return const SplashScreen();
    }
  }

  void showInactiveAccountMessage() {
    _inactiveMessage = "Your account has been deactivated. Contact admin.";
  }
}
