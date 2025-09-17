import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            child: Text(username.isNotEmpty ? username[0].toUpperCase() : '?'),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(email, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                if (createdAtText.isNotEmpty)
                  Text('Created: $createdAtText', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: activeBool ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(statusText, style: TextStyle(color: activeBool ? Colors.green.shade700 : Colors.red.shade700, fontWeight: FontWeight.w600, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          Switch(
            value: activeBool,
            onChanged: (val) async {
              try {
                await FirebaseFirestore.instance.collection('users').doc(uid).update({
                  'active': val,
                  'status': val ? 'Active' : 'Deactivated',
                });
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status updated')));
              } on FirebaseException catch (e) {
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: ${e.message}')));
              }
            },
          ),
        ],
      ),
    );
  }
}
