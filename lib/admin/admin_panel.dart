import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../login_screen.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/users_tab.dart';
import 'tabs/visits_tab.dart';
import 'tabs/community_admin_tab.dart';

class AdminPanel extends StatefulWidget {
  final String username;
  const AdminPanel({super.key, required this.username});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _creatingUser = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop()),
            TextButton(
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(context).pop();
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showCreateUserDialog() {
    final usernameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    String? phoneNumber;
    bool _passwordVisible = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setStateDialog) {
        return AlertDialog(
          title: const Text('Create New User'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Enter username' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter email';
                        if (!v.contains('@')) return 'Enter valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Enter phone number' : null,
                      onSaved: (v) => phoneNumber = v?.trim(),
                    ),
                    const SizedBox(height: 12),
                    StatefulBuilder(
                      builder: (context, setStatePass) {
                        return TextFormField(
                          controller: passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_passwordVisible ? Icons.visibility : Icons.visibility_off),
                              onPressed: () {
                                setStatePass(() {
                                  _passwordVisible = !_passwordVisible;
                                });
                              },
                            ),
                          ),
                          obscureText: !_passwordVisible,
                          validator: (v) => v == null || v.length < 6 ? 'Use 6+ characters' : null,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: _creatingUser
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;

                      setState(() {
                        _creatingUser = true;
                      });
                      setStateDialog(() {});

                      try {
                        FirebaseApp secondaryApp;
                        try {
                          secondaryApp = Firebase.app('Secondary');
                        } catch (e) {
                          secondaryApp = await Firebase.initializeApp(
                            name: 'Secondary',
                            options: Firebase.app().options,
                          );
                        }

                        final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

                        final email = emailController.text.trim();
                        final password = passwordController.text;
                        final username = usernameController.text.trim();

                        final UserCredential newUserCred = await secondaryAuth
                            .createUserWithEmailAndPassword(email: email, password: password);

                        final newUid = newUserCred.user!.uid;

                        await FirebaseFirestore.instance.collection('users').doc(newUid).set({
                          'username': username,
                          'email': email,
                          'phone': phoneNumber,
                          'role': 'User',
                          'active': true,
                          'status': 'Active',
                          'createdAt': FieldValue.serverTimestamp(),
                        });

                        try {
                          await secondaryAuth.signOut();
                          await secondaryApp.delete();
                        } catch (_) {}

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('User created successfully')),
                          );
                        }
                      } on FirebaseAuthException catch (e) {
                        String msg = e.message ?? e.code;
                        if (e.code == 'email-already-in-use') {
                          msg = 'This email is already registered.';
                        }
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $msg')));
                      } on FirebaseException catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Firestore Error: ${e.message}')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      } finally {
                        setState(() {
                          _creatingUser = false;
                        });
                        setStateDialog(() {});
                      }
                    },
              child: _creatingUser
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Create'),
            ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle, color: Colors.white, size: 28),
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                enabled: false,
                value: 'profile',
                child: Row(children: [
                  const Icon(Icons.person, size: 20),
                  const SizedBox(width: 8),
                  Text('Welcome, ${widget.username}')
                ]),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(children: [
                  Icon(Icons.logout, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Logout', style: TextStyle(color: Colors.red))
                ]),
              ),
            ],
            onSelected: (value) {
              if (value == 'logout') _logout();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Dashboard', icon: Icon(Icons.dashboard)),
            Tab(text: 'Users', icon: Icon(Icons.people)),
            Tab(text: 'Visits', icon: Icon(Icons.location_on)),
            Tab(text: 'Community', icon: Icon(Icons.campaign)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          DashboardTab(
            onCreateUser: _showCreateUserDialog,
            onManageVisits: () => _tabController.animateTo(2),
          ),
          UsersTab(onCreateUser: _showCreateUserDialog),
          const VisitsTab(),
          const CommunityAdminTab(),
        ],
      ),
    );
  }
}
