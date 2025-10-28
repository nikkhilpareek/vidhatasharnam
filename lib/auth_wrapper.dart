import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
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
            // Initialize community notification service when authenticated
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final communityService = Provider.of<CommunityNotificationService>(
                context, 
                listen: false
              );
              if (!communityService.isInitialized) {
                communityService.initialize();
              }
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
            // Reset community service on logout
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final communityService = Provider.of<CommunityNotificationService>(
                context, 
                listen: false
              );
              communityService.reset();
            });
            
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
