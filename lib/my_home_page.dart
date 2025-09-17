import 'package:flutter/material.dart';
import 'new_visit.dart';
import 'pending_visit.dart';
import 'profile_page.dart';
import 'total_visits.dart';
import 'total_gaj_sold.dart';
import 'community.dart';
import 'login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 5,
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
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
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
              color: Theme.of(context).colorScheme.inverseSurface,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 30,),
                Image.asset(
                  'assets/images/logo.png',
                  width: 170,
                  height: 120,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.business,
                    size: 50,
                    color: Theme.of(context).colorScheme.primary,
                  );
                  },
                ),
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
                      color: Theme.of(context).colorScheme.primary,
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
                      color: Theme.of(context).colorScheme.primary,
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
                          color: Theme.of(context).colorScheme.primary,
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
                      color: Theme.of(context).colorScheme.primary,
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
                          color: Theme.of(context).colorScheme.primary,
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
                          color: Theme.of(context).colorScheme.primary,
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

  void _performLogout() {
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

    // Simulate logout process and navigate to login screen
    Future.delayed(Duration(seconds: 1), () {
      Navigator.of(context).pop(); // Close loading dialog
      
      // Navigate to login screen and clear all previous routes
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (Route<dynamic> route) => false,
      );
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully logged out'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(
          widget.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 24,
          ),
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
                  icon: Icon(Icons.home, size: 26, color: Theme.of(context).colorScheme.primary),
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
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CommunityScreen(),
                      ),
                    );
                  },
                  icon: Icon(Icons.group, size: 26, color: Colors.grey.shade600),
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
