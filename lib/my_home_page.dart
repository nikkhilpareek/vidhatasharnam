import 'package:flutter/material.dart';
import 'new_visit.dart';
import 'pending_visit.dart';
import 'profile_page.dart';
import 'total_visits.dart';
import 'total_gaj_sold.dart';
import 'community.dart';
import 'app_theme.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';


class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String? userName;
  @override
void initState() {
  super.initState();
  _loadUserData();
}

Future<void> _loadUserData() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists) {
      setState(() {
        userName = doc['username']; // 👈 make sure your Firestore has a "name" field
      });
    }
  }
}

  // Simple notification state
  int _notificationCount = 12; // Hardcoded for testing - matches your image

  void _updateNotificationCount() {
    // You can call this method to update the count
    setState(() {
      _notificationCount = _notificationCount > 0 ? 0 : 12;
    });
  }

  Widget _buildCardButton({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 40,
              color: AppTheme.iconColor,
            ),
            SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          // Drawer Header with Logo
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Color(0xFFFFF4E8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 20,),
                Image.asset(
                  'assets/images/logo.png',
                  width: 170,
                  height: 100,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.business,
                    size: 50,
                    color: AppTheme.iconColor,
                  );
                  },
                ),
                SizedBox(height: 8,),
                Text(
                  'Turning land into legacy',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.black.withOpacity(0.9),
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10,),
              ],
            ),
          ),
          
          // Drawer Items with padding
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.person_outline,
                      color: AppTheme.iconColor,
                      size: 28,
                    ),
                    title: Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ProfilePage()),
                      );
                    },

                  ),
                  SizedBox(height: 10),
                  
                  ExpansionTile(
                    leading: Icon(
                      Icons.business_outlined,
                      color: AppTheme.iconColor,
                      size: 28,
                    ),
                    title: Text(
                      'Our Projects',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.web,
                          color: AppTheme.iconColor,
                          size: 24,
                        ),
                        title: Text(
                          'View More Projects',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        onTap: () async {
                          Navigator.pop(context);
                          try {
                            final url = Uri.parse('https://vidhatasharanam.com');
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Could not open website: $e')),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  
                  // Contact Us Section
                  ExpansionTile(
                    leading: Icon(
                      Icons.contact_support_outlined,
                      color: AppTheme.iconColor,
                      size: 28,
                    ),
                    title: Text(
                      'Contact Us',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.email_outlined,
                          color: AppTheme.iconColor,
                          size: 20,
                        ),
                        title: Text(
                          'vidhatasharanam@gmail.com',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        onTap: () async {
                          Navigator.pop(context);
                          try {
                            final url = Uri.parse('mailto:vidhatasharanam@gmail.com');
                            await launchUrl(url);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Could not open email app: $e')),
                              );
                            }
                          }
                        },
                      ),
                      ListTile(
                        leading: Icon(
                          Icons.phone_outlined,
                          color: AppTheme.iconColor,
                          size: 20,
                        ),
                        title: Text(
                          '+91-9460067878',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        onTap: () async {
                          Navigator.pop(context);
                          try {
                            final url = Uri.parse('tel:+919460067878');
                            await launchUrl(url);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Could not open phone app: $e')),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Logout Button at Bottom
          Container(
            padding: EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showLogoutDialog();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'LOG OUT',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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
              child: Text(
                'Logout',
                style: TextStyle(color: Colors.red),
              ),
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      // Use AuthService to sign out
      await AuthService.instance.signOut();
      
      // Close loading dialog
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      // AuthService will handle navigation through AuthWrapper
      // No manual navigation needed
    } catch (e) {
      // Close loading dialog
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      // Show error message
      if (context.mounted) {
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
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 24,
                color: Colors.black, // Black for main heading
              ),
            ),
            Text(
              "Turning land into legacy",
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.black54, // Lighter black for subheading
                letterSpacing: 0.3,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            onPressed: () {
              _scaffoldKey.currentState?.openEndDrawer();
            }, 
            icon: Icon(Icons.menu)
          ),
          SizedBox(width: 16),
        ],
      ),
      endDrawer: _buildDrawer(),
      floatingActionButton: FloatingActionButton.large(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NewVisitScreen(),
            ),
          );
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        shape: CircleBorder(),
        child: Icon(Icons.add, size: 35),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome back, ${userName ?? 'User'}",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildCardButton(
                    title: "Create New Visit",
                    icon: Icons.add_circle_outline_rounded,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NewVisitScreen(),
                        ),
                      );
                    },
                  ),
                  _buildCardButton(
                    title: "Pending Visits",
                    icon: Icons.pending_actions_outlined,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PendingVisitsScreen(),
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
                          builder: (context) => TotalVisitsScreen(),
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
                          builder: (context) => TotalGajSoldScreen(),
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
        shape: CircularNotchedRectangle(),
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
                    print("Home tapped");
                  },
                  icon: Icon(Icons.home, size: 26, color: AppTheme.iconColor),
                ),
                Text(
                  "Home",
                  style: TextStyle(
                    fontSize: 12, 
                    color: Theme.of(context).colorScheme.primary, 
                    fontWeight: FontWeight.w600
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
                        setState(() {
                          _notificationCount = 0;
                        });
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CommunityScreen(),
                          ),
                        );
                      },
                      icon: Icon(Icons.group, size: 26, color: Colors.grey.shade600),
                    ),
                    // Simple notification badge - like in your image
                    if (_notificationCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          constraints: BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          child: Text(
                            _notificationCount > 99 ? '99+' : _notificationCount.toString(),
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
                    fontWeight: FontWeight.w600
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
