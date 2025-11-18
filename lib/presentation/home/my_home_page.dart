import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vidhatasharnam/core/config/app_constants.dart';
import 'package:vidhatasharnam/core/logger/app_logger.dart';
import 'package:vidhatasharnam/core/theme/app_theme.dart';
import 'package:vidhatasharnam/data/datasources/auth/auth_service.dart';
import 'package:vidhatasharnam/data/datasources/community/community_notification_service.dart';
import 'package:vidhatasharnam/domain/repositories/local_storage.dart';
import 'package:vidhatasharnam/presentation/about/about_us_screen.dart';
import 'package:vidhatasharnam/presentation/auth/login/login_screen.dart';
import 'package:vidhatasharnam/presentation/community/community_screen.dart';
import 'package:vidhatasharnam/presentation/home/home_view_model.dart';
import 'package:vidhatasharnam/presentation/profile/profile_page.dart';
import 'package:vidhatasharnam/presentation/user/user_view_model.dart';
import 'package:vidhatasharnam/presentation/visits/new_visit.dart';
import 'package:vidhatasharnam/presentation/visits/pending_visit.dart';
import 'package:vidhatasharnam/presentation/visits/total_gaj_sold.dart';
import 'package:vidhatasharnam/presentation/visits/total_visits.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final LocalStorageService _localStorage = LocalStorageService();
  bool _hasShownDeactivatedSnackBar = false;

  @override
  void initState() {
    super.initState();

    // Initialize background processes after the screen is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeBackgroundProcesses();

      final homeViewModel = context.read<HomeViewModel>();
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        homeViewModel.startCommunityNotificationListener(currentUser.uid);
      }

      // Ensure UserViewModel listener is started
      final userViewModel = context.read<UserViewModel>();
      if (!userViewModel.isListening) {
        userViewModel.startUserListener().catchError((e) {
          debugPrint('[MyHomePage] Warning: Failed to start UserViewModel: $e');
        });
      }
    });
  }

  String _getStatus(UserViewModel userViewModel) {
    // Use UserViewModel for real-time status
    if (!userViewModel.isActive) {
      return 'Deactivated';
    }

    // Check userData from ViewModel for status field
    final userData = userViewModel.userData;
    if (userData != null) {
      final statusField = userData['status'] as String?;
      if (statusField != null) {
        return statusField;
      }
    }

    return 'Active'; // Default
  }

  /// Initialize background processes like device registration and notification service
  Future<void> _initializeBackgroundProcesses() async {
    try {
      // Initialize Community Notification Service
      await CommunityNotificationService.instance.initialize();

      // Register device token if not already registered
      await _registerDeviceIfNeeded();
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error initializing background processes',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Register device token if not already registered
  Future<void> _registerDeviceIfNeeded() async {
    try {
      final isDeviceRegistered =
          _localStorage.getBool(AppConstants.prefDeviceRegistered) ?? false;
      final storedToken = _localStorage.getString(
        AppConstants.prefRegisteredDeviceToken,
      );

      // Check if device is already registered
      if (isDeviceRegistered && storedToken != null) {
        AppLogger.info('Device already registered with token: $storedToken');
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        AppLogger.warning('Cannot register device: User not logged in');
        return;
      }

      // TODO: Replace with actual FCM token retrieval
      // For now, this is a placeholder that you can integrate with firebase_messaging
      // Example:
      // final fcmToken = await FirebaseMessaging.instance.getToken();

      // Placeholder: Generate a mock token for demonstration
      // In production, replace this with actual FCM token from FirebaseMessaging
      final deviceToken =
          'mock_device_token_${DateTime.now().millisecondsSinceEpoch}';

      // Save registration status
      await _localStorage.saveBool(AppConstants.prefDeviceRegistered, true);
      await _localStorage.saveString(
        AppConstants.prefRegisteredDeviceToken,
        deviceToken,
      );

      // TODO: Send token to your backend/API
      // Example API call:
      // await HomeRepository.registerDevice(userId: user.uid, token: deviceToken);

      AppLogger.info('Device registered successfully with token: $deviceToken');
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error registering device',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Widget _buildCardButton({
    required String title,
    required IconData icon,
    VoidCallback? onTap,
    bool isEnabled = true,
  }) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.5,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: AppTheme.iconColor),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isEnabled
                      ? Colors.grey.shade800
                      : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          // Drawer Header
          Container(
            height: 180,
            width: double.infinity,
            decoration: const BoxDecoration(color: Color(0xFFFFF4E8)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 10),
                Image.asset(
                  'assets/images/logo.png',
                  width: 150,
                  height: 80,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(Icons.business, size: 48, color: AppTheme.iconColor),
                ),
                const SizedBox(height: 4),
                Text(
                  'Turning land into legacy',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Colors.black.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _drawerItem(
                  icon: Icons.person_outline,
                  title: "Profile",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
                  },
                ),
                _divider(),

                _drawerItem(
                  icon: Icons.delete_outline,
                  title: "Delete Profile",
                  titleColor: Colors.red,
                  iconColor: Colors.red,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Your profile has been deleted"),
                        backgroundColor: Colors.red,
                      ),
                    );
                    _performLogout();
                    Navigator.pop(context);
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                  },
                ),
                _divider(),

                _drawerItem(
                  icon: Icons.web,
                  title: "View More Projects",
                  onTap: () async {
                    Navigator.pop(context);
                    final url = Uri.parse('https://vidhatasharanam.com');
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  },
                ),
                _divider(),

                _drawerItem(
                  icon: Icons.email_outlined,
                  title: "vidhatasharanam@gmail.com",
                  iconSize: 20,
                  fontSize: 14,
                  onTap: () async {
                    Navigator.pop(context);
                    await launchUrl(Uri.parse('mailto:vidhatasharanam@gmail.com'));
                  },
                ),
                _divider(),

                _drawerItem(
                  icon: Icons.phone_outlined,
                  title: "+91-9460067878",
                  iconSize: 20,
                  fontSize: 14,
                  onTap: () async {
                    Navigator.pop(context);
                    await launchUrl(Uri.parse('tel:+919460067878'));
                  },
                ),
                _divider(),

                _drawerItem(
                  icon: Icons.info_outline,
                  title: "About Us",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutUsScreen()));
                  },
                ),
                _divider(),
              ],
            ),
          ),

          // Logout Button
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showLogoutDialog();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text(
                  'LOG OUT',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String title,
    double iconSize = 26,
    double fontSize = 15,
    Color? iconColor,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: iconSize, color: iconColor ?? AppTheme.iconColor),
      title: Text(
        title,
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500, color: titleColor ?? Colors.black),
      ),
      onTap: onTap,
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(color: Colors.grey.shade300, height: 1),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Logout'),
          content: Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Logout', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog first
                _performLogout();
              },
            ),
          ],
        );
      },
    );
  }

  void _performLogout() async {
    // Show loading indicator briefly
    if (!mounted) return;

    final homeViewModel = context.read<HomeViewModel>();
    homeViewModel.stopCommunityNotificationListener();
    homeViewModel.clearNotifications();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(height: 16),
                Text(
                  'Logging out...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      // Use AuthService to sign out (this will clear LocalStorageService)
      await AuthService.instance.signOut();

      // Close loading dialog
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      // Navigate to login screen and prevent back navigation
      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacementNamed(AppConstants.navigateToLoginScreen);
      }
    } catch (e) {
      // Close loading dialog
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging out: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use Consumer to reactively observe UserViewModel and HomeViewModel changes
    return Consumer2<UserViewModel, HomeViewModel>(
      builder: (context, userViewModel, homeViewModel, _) {
        // Show snackbar when user is deactivated (only once per state change)
        if (!userViewModel.isActive && !_hasShownDeactivatedSnackBar && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _hasShownDeactivatedSnackBar = true;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Your account has been deactivated by admin. Contact support.'),
                  backgroundColor: Colors.red.shade700,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          });
        }

        // Reset flag when user becomes active again
        if (userViewModel.isActive && _hasShownDeactivatedSnackBar) {
          _hasShownDeactivatedSnackBar = false;
        }

        // Determine background color based on active status
        final backgroundColor = userViewModel.isActive
            ? Colors
                  .grey
                  .shade50 // Normal background
            : Colors.red.shade50.withOpacity(0.3); // Red tint when deactivated

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: backgroundColor,
          appBar: AppBar(
            backgroundColor: const Color(0xFFF18F3B), // your orange color
            elevation: 2,
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                    color: Colors.black,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2), // subtle spacing
                Text(
                  "Turning land into legacy",
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.1,
                    letterSpacing: 0.2,
                    color: Colors.black.withOpacity(0.75),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            centerTitle: true,
          ),
          drawer: _buildDrawer(),
          // Floating Action Button - hidden when user is inactive
          floatingActionButton: userViewModel.isActive
              ? FloatingActionButton.large(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NewVisitScreen(),
                      ),
                    );
                  },
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                  child: const Icon(Icons.add, size: 35),
                )
              : null,
          // Hide FAB when inactive
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Deactivated warning banner
                if (!userViewModel.isActive)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade700, width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your account is currently deactivated. Please contact admin.',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Welcome row with username and status badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // USERNAME TEXT
                    Text(
                      "Welcome back, ${userViewModel.userName ?? 'User'}!",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                        letterSpacing: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(width: 12),

                    // STATUS BADGE - Updates in real-time via UserViewModel
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: userViewModel.isActive
                            ? Colors.green.withOpacity(0.15)
                            : Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: userViewModel.isActive
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                      child: Text(
                        _getStatus(userViewModel),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: userViewModel.isActive
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      // Create New Visit button - disabled when user is inactive
                      _buildCardButton(
                        title: "Create New Visit",
                        icon: Icons.add_circle_outline_rounded,
                        onTap: userViewModel.isActive
                            ? () {
                                if (userViewModel.isActive) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => NewVisitScreen(),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Your Profile is Disable by Admin!! Please Contact",
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            : null, // Disabled when inactive
                        isEnabled: userViewModel.isActive,
                      ),
                      // Other buttons use default isEnabled = true
                      _buildCardButton(
                        title: "Pending Visits",
                        icon: Icons.pending_actions_outlined,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PendingVisitsScreen(),
                            ),
                          );
                        },
                      ),
                      _buildCardButton(
                        title: "Total Visits",
                        icon: Icons.analytics_outlined,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TotalVisitsScreen(),
                            ),
                          );
                        },
                      ),
                      _buildCardButton(
                        title: "Total Gaj Sold",
                        icon: Icons.landscape_outlined,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TotalGajSoldScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: BottomAppBar(
            shape: const CircularNotchedRectangle(),
            notchMargin: 10,
            height: 100,
            color: Colors.white,
            elevation: 5,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () {
                        AppLogger.debug('Home tab tapped');
                      },
                      icon: Icon(
                        Icons.home,
                        size: 26,
                        color: AppTheme.iconColor,
                      ),
                    ),
                    Text(
                      "Home",
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 50), // Space for larger FAB
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      children: [
                        IconButton(
                          onPressed: () {
                            // Clear notifications when visiting community
                            homeViewModel.clearNotifications();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CommunityScreen(),
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.group,
                            size: 26,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        // Simple notification badge - like in your image
                        if (homeViewModel.notificationCount > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              constraints: BoxConstraints(
                                minWidth: 20,
                                minHeight: 20,
                              ),
                              child: Text(
                                homeViewModel.notificationCount > 99
                                    ? '99+'
                                    : homeViewModel.notificationCount
                                          .toString(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      "Community",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
