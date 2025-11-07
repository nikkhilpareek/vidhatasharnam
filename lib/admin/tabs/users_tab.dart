import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:vidhatasharnam/core/config/app_constants.dart';
import 'package:vidhatasharnam/core/logger/app_logger.dart';

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
                Column(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushNamed(
                          AppConstants.navigateToApproveUsers,
                        );
                      },
                      icon: const Icon(Icons.person_add_alt_1, size: 18),
                      label: const Text('Approve Users'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                      ),
                    ),
                    const SizedBox(height: 12),
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
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No users found'));
                }

                final docs = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final user = doc.data() as Map<String, dynamic>;
                    final uid = doc.id;
                    return _UserCard(
                      userId: uid,
                      user: user,
                      onApprove: _approveUser,
                      onReject: _rejectUser,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveUser(BuildContext context, String userId, String email) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve User'),
        content: Text('Are you sure you want to approve $email?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final currentAdminId = FirebaseAuth.instance.currentUser?.uid;
      
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isApproved': true,
        'active': true,
        'status': 'Active',
        'approvedAt': FieldValue.serverTimestamp(),
        if (currentAdminId != null) 'approvedBy': currentAdminId,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      FirebaseCrashlytics.instance.recordError(e, stackTrace, reason: 'Error approving user');
      AppLogger.error('Error approving user', error: e, stackTrace: stackTrace);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectUser(BuildContext context, String userId, String email) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject User'),
        content: Text('Are you sure you want to reject $email? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Delete user document from Firestore
      await FirebaseFirestore.instance.collection('users').doc(userId).delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User rejected and removed'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e, stackTrace) {
      FirebaseCrashlytics.instance.recordError(e, stackTrace, reason: 'Error rejecting user');
      AppLogger.error('Error rejecting user', error: e, stackTrace: stackTrace);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

}

class _UserCard extends StatelessWidget {
  final String userId;
  final Map<String, dynamic> user;
  final Function(BuildContext, String, String) onApprove;
  final Function(BuildContext, String, String) onReject;
  
  const _UserCard({
    required this.userId,
    required this.user,
    required this.onApprove,
    required this.onReject,
  });

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
    final name = (user['name'] ?? user['username'] ?? user['email']?.split('@')?.first ?? 'Unknown').toString();
    final email = (user['email'] ?? '').toString();
    final isApproved = user['isApproved'] ?? false;
    final phone = user['phone'] ?? 'N/A';
    
    String createdAtText = '';
    if (user['createdAt'] != null) {
      try {
        if (user['createdAt'] is Timestamp) {
          final date = (user['createdAt'] as Timestamp).toDate();
          createdAtText = '${date.day}/${date.month}/${date.year}';
        } else {
          final date = DateTime.parse(user['createdAt'].toString());
          createdAtText = '${date.day}/${date.month}/${date.year}';
        }
      } catch (e) {
        createdAtText = user['createdAt'].toString();
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(email, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                    if (phone != 'N/A')
                      Text('Phone: $phone', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    if (createdAtText.isNotEmpty)
                      Text('Created: $createdAtText', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ],
                ),
              ),
              // Approval Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isApproved 
                      ? Colors.green.withOpacity(0.1) 
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isApproved ? Icons.check_circle_outline : Icons.pending_outlined,
                      size: 16,
                      color: isApproved ? Colors.green.shade700 : Colors.orange.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isApproved ? 'Approved' : 'Pending',
                      style: TextStyle(
                        color: isApproved ? Colors.green.shade700 : Colors.orange.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Action buttons for pending users
          if (!isApproved) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Reject button
                OutlinedButton.icon(
                  onPressed: () => onReject(context, userId, email),
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
                const SizedBox(width: 12),
                // Approve button
                ElevatedButton.icon(
                  onPressed: () => onApprove(context, userId, email),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
