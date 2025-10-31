import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'package:vidhatasharnam/admin/admin_panel.dart';
import 'package:vidhatasharnam/data/datasources/auth/auth_service.dart';
import 'package:vidhatasharnam/data/datasources/community/community_notification_service.dart';
import 'package:vidhatasharnam/presentation/auth/login/login_screen.dart';
import 'package:vidhatasharnam/presentation/home/my_home_page.dart';
import 'package:vidhatasharnam/presentation/splash/splash_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _permissionsRequested = false;
  String? _inactiveMessage;

  Future<void> _requestPermissionsOnce() async {
    if (_permissionsRequested) return;
    _permissionsRequested = true;

    var locationStatus = await Permission.location.status;
    if (!locationStatus.isGranted) {
      locationStatus = await Permission.location.request();
      if (locationStatus.isPermanentlyDenied && mounted) {
        _showSettingsDialog('Location');
      }
    }

    var cameraStatus = await Permission.camera.status;
    if (!cameraStatus.isGranted) {
      cameraStatus = await Permission.camera.request();
      if (cameraStatus.isPermanentlyDenied && mounted) {
        _showSettingsDialog('Camera');
      }
    }
  }

  void _showSettingsDialog(String permissionName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$permissionName Permission Required'),
        content: Text(
          '$permissionName permission is required for the app to work properly. Please enable it in settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        if (!authService.isInitialized) {
          return const SplashScreen();
        }

        switch (authService.status) {
          case AuthStatus.loading:
            return const SplashScreen();
          
          case AuthStatus.authenticated:
            WidgetsBinding.instance.addPostFrameCallback((_) {
              CommunityNotificationService.instance.initialize();
            });
            
            final userData = authService.userData!;
            
            if (userData.role != "admin") {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _requestPermissionsOnce();
              });
            }
            
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
      },
    );
  }

  void showInactiveAccountMessage() {
    _inactiveMessage = "Your account has been deactivated. Contact admin.";
  }
}
