// lib/presentation/community/new_channel_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:vidhatasharnam/presentation/community/new_channel_view_model.dart';

class NewChannelScreen extends StatefulWidget {
  const NewChannelScreen({super.key});

  @override
  State<NewChannelScreen> createState() => _NewChannelScreenState();
}

class _NewChannelScreenState extends State<NewChannelScreen> {
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      context.read<NewChannelViewModel>().setSearchQuery(_searchController.text);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NewChannelViewModel>(
      builder: (context, viewModel, _) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) {
          return const Scaffold(body: Center(child: Text('Not authenticated')));
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text("New Channel"),
            actions: [
              TextButton(
                onPressed: viewModel.isCreating ? null : () => _create(context, viewModel, uid),
                child: viewModel.isCreating
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
                    : const Text('Create', style: TextStyle(color: Colors.black)),
              )
            ],
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
          ),
      body: Column(
        children: [
          // Channel name field
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

          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Search users',
                border: OutlineInputBorder(),
              ),
            ),
          ),

          const SizedBox(height: 10),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Select members',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),

          // List of users
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream:
              FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No users'));
                }

                // Filter logic based on search query
                final filteredDocs = viewModel.searchQuery.isEmpty
                    ? docs
                    : docs.where((doc) {
                  final data = doc.data();
                  final name = (data['username'] ??
                      data['email'] ??
                      doc.id)
                      .toString()
                      .toLowerCase();
                  return name.contains(viewModel.searchQuery);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(
                      child: Text('No users match your search'));
                }

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, i) {
                    final doc = filteredDocs[i];
                    final data = doc.data();
                    final userId = doc.id;
                    final email = (data['email'] ?? '').toString();
                    final name = (data['username'] ??
                        data['email'] ??
                        userId)
                        .toString();
                    final selected = viewModel.selectedMembers.contains(userId);
                    return CheckboxListTile(
                      value: selected,
                      onChanged: (v) {
                        viewModel.toggleMember(userId);
                      },
                      title: Text(name),
                      subtitle: Text(
                        email,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
        );
      },
    );
  }

  Future<void> _create(BuildContext context, NewChannelViewModel viewModel, String adminUid) async {
    final name = _nameController.text.trim();
    if (name.isEmpty || viewModel.selectedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Name and at least one member required')));
      return;
    }

    final success = await viewModel.createChannel(name, adminUid);
    if (success && context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Channel "$name" created')));
    } else if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error creating channel')));
    }
  }
}
