import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UsersTab extends StatelessWidget {
  final VoidCallback onCreateUser;
  const UsersTab({super.key, required this.onCreateUser});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade50,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Users', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: onCreateUser,
                  icon: const Icon(Icons.add),
                  label: const Text('Add User'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No users found'));

                final docs = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final user = doc.data() as Map<String, dynamic>;
                    final uid = doc.id;
                    return _UserCard(uid: uid, user: user);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> user;
  const _UserCard({required this.uid, required this.user});

  void _showChangePasswordDialog(BuildContext context, String userId, String username, String email) {
    bool _isSendingReset = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setStateDialog) {
        return AlertDialog(
          title: Text('Reset Password for $username'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('User: $username', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('Email: $email', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.email_outlined, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'A password reset email will be sent to the user\'s email address. They will need to follow the instructions in the email to set a new password.',
                          style: TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: _isSendingReset
                  ? null
                  : () async {
                setStateDialog(() {
                  _isSendingReset = true;
                });

                try {
                  // Send password reset email to the user
                  await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

                  // Store admin action in Firestore for audit trail
                  await FirebaseFirestore.instance.collection('users').doc(userId).update({
                    'passwordResetSentBy': FirebaseAuth.instance.currentUser?.uid,
                    'passwordResetSentAt': FieldValue.serverTimestamp(),
                    'adminRequestedPasswordChange': true,
                  });

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Password reset email sent to $email. User will receive instructions to reset their password.'),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                } on FirebaseAuthException catch (e) {
                  String errorMessage = 'Failed to send password reset email';
                  if (e.code == 'user-not-found') {
                    errorMessage = 'No user found with this email address';
                  } else if (e.code == 'invalid-email') {
                    errorMessage = 'Invalid email address';
                  }

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(errorMessage),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } finally {
                  setStateDialog(() {
                    _isSendingReset = false;
                  });
                }
              },
              child: _isSendingReset
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Send Reset Email'),
            ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final username = (user['username'] ?? user['email']?.split('@')?.first ?? 'Unknown').toString();
    final email = (user['email'] ?? '').toString();
    final activeBool = (user['active'] ?? (user['status'] == 'Active')) as bool;
    final statusText = activeBool ? 'Active' : 'Deactivated';
    String createdAtText = '';
    if (user['createdAt'] != null && user['createdAt'] is Timestamp) {
      createdAtText = (user['createdAt'] as Timestamp).toDate().toString().split(' ')[0];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    if (createdAtText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        "Created: $createdAtText",
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          /// ===========================
          /// SECOND ROW: 3 Equal Columns
          /// ===========================
          Row(
            children: [
              // 1️⃣ Status Badge
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: activeBool ? Colors.green.withOpacity(0.12) : Colors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: activeBool ? Colors.green.shade700 : Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),

              // 2️⃣ Lock Button
              Expanded(
                child: Center(
                  child: IconButton(
                    icon: const Icon(Icons.lock_reset, color: Colors.blue, size: 22),
                    onPressed: () => _showChangePasswordDialog(context, uid, username, email),
                  ),
                ),
              ),

              // 3️⃣ Switch Button
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Switch(
                    value: activeBool,
                    onChanged: (val) async {
                      try {
                        await FirebaseFirestore.instance.collection('users').doc(uid).update({
                          'active': val,
                          'status': val ? 'Active' : 'Deactivated',
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Status updated')),
                        );
                      } on FirebaseException catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Update failed: ${e.message}')),
                        );
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}