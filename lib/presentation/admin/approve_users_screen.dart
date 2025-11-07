import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:vidhatasharnam/core/theme/app_theme.dart';
import 'package:vidhatasharnam/config/supabase_config.dart';
import 'package:vidhatasharnam/core/logger/app_logger.dart';

/*
 * Supabase Schema SQL:
 * 
 * CREATE TABLE users (
 *   id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
 *   name TEXT NOT NULL,
 *   email TEXT NOT NULL UNIQUE,
 *   phone TEXT NOT NULL,
 *   isApproved BOOLEAN DEFAULT false,
 *   createdAt TIMESTAMP DEFAULT now()
 * );
 * 
 * Note: Password is stored in Supabase Auth (auth.users table), not in this table for security.
 * The id field references auth.users(id) to link with Supabase Auth.
 * 
 * CREATE INDEX idx_users_email ON users(email);
 * CREATE INDEX idx_users_isApproved ON users(isApproved);
 * 
 * Enable Row Level Security (RLS) policies as needed for your use case.
 */

class ApproveUsersScreen extends StatefulWidget {
  const ApproveUsersScreen({super.key});

  @override
  State<ApproveUsersScreen> createState() => _ApproveUsersScreenState();
}

class _ApproveUsersScreenState extends State<ApproveUsersScreen> {
  List<Map<String, dynamic>> _pendingUsers = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPendingUsers();
  }

  Future<void> _loadPendingUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabase = SupabaseConfig.client;
      final response = await supabase
          .from('users')
          .select('*')
          .eq('isApproved', false)
          .order('createdAt', ascending: false);

      if (mounted) {
        setState(() {
          _pendingUsers = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error loading pending users', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load pending users: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _approveUser(String userId, String email) async {
    try {
      final supabase = SupabaseConfig.client;
      
      // Update approval status in Supabase
      await supabase
          .from('users')
          .update({'isApproved': true})
          .eq('id', userId);

      // Get user data to sync with Firestore
      final userData = await supabase
          .from('users')
          .select('name, email, phone')
          .eq('id', userId)
          .single();

      // Update Firestore user to active (user was created during registration)
      try {
        // Find Firestore user by email
        final firestoreUsers = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: email.toLowerCase())
            .limit(1)
            .get();

        if (firestoreUsers.docs.isNotEmpty) {
          // Update existing Firestore user to active
          await firestoreUsers.docs.first.reference.update({
            'active': true,
          });
        } else {
          // If not found, user might have been created in Firebase Auth during registration
          // Try to find by Firebase Auth user
          try {
            // Note: We can't directly query Firebase Auth, so we'll update on next login
            AppLogger.info('Firestore user not found, will be created/updated on first login');
          } catch (e) {
            AppLogger.warning('Error checking Firebase Auth: $e');
          }
        }

        AppLogger.info('User approved and Firestore synced: $email');
      } catch (e) {
        AppLogger.warning('Could not sync with Firestore for $email: $e');
        // Continue - Supabase approval is the primary source
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh the list
        _loadPendingUsers();
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error approving user', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectUser(String userId, String email) async {
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
      final supabase = SupabaseConfig.client;
      // Delete user from Supabase
      await supabase.from('users').delete().eq('id', userId);

      // Also delete from Supabase Auth if possible
      try {
        // Note: This requires admin privileges or backend API
        AppLogger.info('User rejected and deleted: $email');
      } catch (e) {
        AppLogger.warning('Could not delete Supabase Auth user for $email: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User rejected and removed'),
            backgroundColor: Colors.orange,
          ),
        );
        // Refresh the list
        _loadPendingUsers();
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error rejecting user', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        title: const Text('Approve Users'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadPendingUsers,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _pendingUsers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No pending approvals',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadPendingUsers,
                      child: Column(
                        children: [
                          // Pending count header
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            child: Text(
                              'Pending Approvals: ${_pendingUsers.length}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          // Users list
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _pendingUsers.length,
                              itemBuilder: (context, index) {
                                final user = _pendingUsers[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.person,
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                user['name'] ?? 'N/A',
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        _buildInfoRow(
                                          Icons.email,
                                          'Email',
                                          user['email'] ?? 'N/A',
                                        ),
                                        const SizedBox(height: 8),
                                        _buildInfoRow(
                                          Icons.phone,
                                          'Phone',
                                          user['phone'] ?? 'N/A',
                                        ),
                                        const SizedBox(height: 8),
                                        _buildInfoRow(
                                          Icons.calendar_today,
                                          'Registered',
                                          _formatDate(user['createdAt']),
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            // Reject button
                                            OutlinedButton.icon(
                                              onPressed: () => _rejectUser(
                                                user['id'],
                                                user['email'],
                                              ),
                                              icon: const Icon(Icons.close, size: 18),
                                              label: const Text('Reject'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.red,
                                                side: const BorderSide(color: Colors.red),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            // Approve button
                                            ElevatedButton.icon(
                                              onPressed: () => _approveUser(
                                                user['id'],
                                                user['email'],
                                              ),
                                              icon: const Icon(Icons.check, size: 18),
                                              label: const Text('Approve'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                foregroundColor: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}

