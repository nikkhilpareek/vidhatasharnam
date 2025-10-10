// lib/services/community/new_channel_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NewChannelScreen extends StatefulWidget {
  const NewChannelScreen({super.key});

  @override
  State<NewChannelScreen> createState() => _NewChannelScreenState();
}

class _NewChannelScreenState extends State<NewChannelScreen> {
  final _nameController = TextEditingController();
  final _selected = <String>{};
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Not authenticated')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("New Channel"),
        actions: [
          TextButton(
            onPressed: _loading ? null : () => _create(uid),
            child: _loading
                ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2,color:Colors.black))
                : const Text('Create', style: TextStyle(color: Colors.black)),
          )
        ],
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Channel name',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Select members', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) return const Center(child: Text('No users'));
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final data = doc.data();
                    final userId = doc.id; // auth UID
                    final name = (data['username'] ?? data['email'] ?? userId).toString();
                    final selected = _selected.contains(userId);
                    return CheckboxListTile(
                      value: selected,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selected.add(userId);
                          } else {
                            _selected.remove(userId);
                          }
                        });
                      },
                      title: Text(name),
                      subtitle: Text(userId, style: const TextStyle(fontSize: 11,color: Colors.grey)),
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

  Future<void> _create(String adminUid) async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name and at least one member required')));
      return;
    }
    setState(() => _loading = true);
    try {
      final members = _selected.toSet();
      members.add(adminUid);
      await FirebaseFirestore.instance.collection('channels').add({
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': adminUid,
        'members': members.toList(),
        'admins': [adminUid],
        'lastMessagePreview': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'broadcast': true,
      });
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Channel "$name" created')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
