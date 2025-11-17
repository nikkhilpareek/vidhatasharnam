import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../core/config/app_constants.dart';
import '../data/datasources/auth/auth_service.dart';
import '../presentation/admin/admin_panel_view_model.dart';
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

  void _showAdminPasswordChangeDialog(AdminPanelViewModel viewModel) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool currentPasswordVisible = false;
    bool newPasswordVisible = false;
    bool confirmPasswordVisible = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setStateDialog) {
        return AlertDialog(
          title: const Text('Change Admin Password'),
          content: SizedBox(
            width: double.maxFinite,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: currentPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(currentPasswordVisible ? Icons.visibility : Icons.visibility_off),
                        onPressed: () {
                          setStateDialog(() {
                            currentPasswordVisible = !currentPasswordVisible;
                          });
                        },
                      ),
                    ),
                    obscureText: !currentPasswordVisible,
                    validator: (v) => v == null || v.isEmpty ? 'Enter current password' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: newPasswordController,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(newPasswordVisible ? Icons.visibility : Icons.visibility_off),
                        onPressed: () {
                          setStateDialog(() {
                            newPasswordVisible = !newPasswordVisible;
                          });
                        },
                      ),
                    ),
                    obscureText: !newPasswordVisible,
                    validator: (v) => v == null || v.length < 6 ? 'Use 6+ characters' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_clock),
                      suffixIcon: IconButton(
                        icon: Icon(confirmPasswordVisible ? Icons.visibility : Icons.visibility_off),
                        onPressed: () {
                          setStateDialog(() {
                            confirmPasswordVisible = !confirmPasswordVisible;
                          });
                        },
                      ),
                    ),
                    obscureText: !confirmPasswordVisible,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Confirm your password';
                      if (v != newPasswordController.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: viewModel.isChangingPassword
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;

                      viewModel.setChangingPassword(true);

                      try {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          // Reauthenticate with current password
                          final credential = EmailAuthProvider.credential(
                            email: user.email!,
                            password: currentPasswordController.text,
                          );
                          await user.reauthenticateWithCredential(credential);

                          // Update password
                          await user.updatePassword(newPasswordController.text);

                          if (!mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Password changed successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                        }
                      } on FirebaseAuthException catch (e) {
                        String errorMessage = 'Failed to change password';
                        if (e.code == 'wrong-password') {
                          errorMessage = 'Current password is incorrect';
                        } else if (e.code == 'weak-password') {
                          errorMessage = 'New password is too weak';
                        }
                        
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(errorMessage),
                              backgroundColor: Colors.red,
                            ),
                          );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                      } finally {
                        viewModel.setChangingPassword(false);
                      }
                    },
              child: viewModel.isChangingPassword
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Change Password'),
            ),
          ],
        );
        },
      ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(context).pop();
                
                try {
                  // Use AuthService to sign out (this will clear LocalStorageService)
                  await AuthService.instance.signOut();
                  
                  // Navigate to login screen and prevent back navigation
                  if (context.mounted) {
                    Navigator.of(context).pushReplacementNamed(
                      AppConstants.navigateToLoginScreen,
                    );
                  }
                } catch (e) {
                  // Show error message
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error logging out: $e'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showCreateUserDialog(AdminPanelViewModel viewModel) {
    final usernameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    String? phoneNumber;
    bool passwordVisible = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (dialogContext, setStateDialog) {
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
                              icon: Icon(passwordVisible ? Icons.visibility : Icons.visibility_off),
                              onPressed: () {
                                setStatePass(() {
                                  passwordVisible = !passwordVisible;
                                });
                              },
                            ),
                          ),
                          obscureText: !passwordVisible,
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
              onPressed: viewModel.isCreatingUser
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      formKey.currentState!.save();

                      viewModel.setCreatingUser(true);
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

                        // Create user in Firestore (admin-created users are auto-approved)
                        await FirebaseFirestore.instance.collection('users').doc(newUid).set({
                          'username': username,
                          'email': email,
                          'phone': phoneNumber,
                          'role': 'User',
                          'active': true,
                          'status': 'Active',
                          'isApproved': true, // Admin-created users are auto-approved
                          'createdAt': FieldValue.serverTimestamp(),
                        });

                        try {
                          await secondaryAuth.signOut();
                          await secondaryApp.delete();
                        } catch (_) {}

                        if (!mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('User created successfully')),
                        );
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
                        viewModel.setCreatingUser(false);
                        setStateDialog(() {});
                      }
                    },
              child: viewModel.isCreatingUser
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
    return Consumer<AdminPanelViewModel>(
      builder: (context, viewModel, _) {
        return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.8),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
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
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.admin_panel_settings, color: Colors.blue, size: 35),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Admin: ${widget.username}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Change Password'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                _showAdminPasswordChangeDialog(viewModel);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context); // Close drawer
                _logout();
              },
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          DashboardTab(
            onCreateUser: () => _showCreateUserDialog(viewModel),
            onManageVisits: () => _tabController.animateTo(2),
          ),
          UsersTab(onCreateUser: () => _showCreateUserDialog(viewModel)),
          const VisitsTab(),
          const CommunityAdminTab(),
        ],
      ),
        );
      },
    );
  }
}
