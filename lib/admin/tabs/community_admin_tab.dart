import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/community/new_channel_screen.dart';
import '../../community.dart';

class CommunityAdminTab extends StatelessWidget {
  const CommunityAdminTab({super.key});

  @override
  Widget build(BuildContext context) {
    final channels = FirebaseFirestore.instance
        .collection('channels')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Community', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const NewChannelScreen()));
                },
                icon: const Icon(Icons.add),
                label: const Text('New Channel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 0),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: channels,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}'));
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('No channels found'));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final d = docs[i];
                  final c = d.data();
                  final name = (c['name'] ?? 'Channel').toString();
                  final preview = (c['lastMessagePreview'] ?? 'No messages yet').toString();
                  final members = (c['members'] is List) ? (c['members'] as List).length : 0;

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        child: const Icon(Icons.campaign),
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100, 
                                  borderRadius: BorderRadius.circular(12)
                                ),
                                child: Text(
                                  '$members members', 
                                  style: TextStyle(color: Colors.grey.shade700, fontSize: 11)
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _showChannelInfo(context, d.id, name, c),
                            icon: const Icon(Icons.info_outline),
                            tooltip: 'Channel Info',
                            color: Colors.blue,
                          ),
                          IconButton(
                            onPressed: () => _showDeleteConfirmation(context, d.id, name),
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Delete Channel',
                            color: Colors.red,
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CommunityChannelScreen(
                              channelId: d.id,
                              channelName: name,
                              isAdmin: true,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showChannelInfo(BuildContext context, String channelId, String channelName, Map<String, dynamic> channelData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChannelInfoScreen(
          channelId: channelId,
          channelName: channelName,
          channelData: channelData,
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String channelId, String channelName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Channel'),
          content: Text('Are you sure you want to delete "$channelName"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteChannel(context, channelId, channelName);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteChannel(BuildContext context, String channelId, String channelName) async {
    // Store the navigator to ensure we can always close the dialog
    final navigator = Navigator.of(context);
    bool dialogShown = false;
    
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Deleting channel...'),
            ],
          ),
        ),
      );
      dialogShown = true;

      // Add timeout to prevent infinite loading
      await Future.any([
        _performChannelDeletion(channelId),
        Future.delayed(const Duration(seconds: 30), () => throw TimeoutException('Delete operation timed out')),
      ]);

      // Close loading dialog
      if (dialogShown) {
        navigator.pop();
        dialogShown = false;
      }

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Channel "$channelName" deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if it was shown
      if (dialogShown) {
        try {
          navigator.pop();
        } catch (_) {
          // Ignore if pop fails
        }
      }
      
      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting channel: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _performChannelDeletion(String channelId) async {
    // Delete all messages in the channel first
    final messages = await FirebaseFirestore.instance
        .collection('channels')
        .doc(channelId)
        .collection('messages')
        .get();
    
    // Delete messages in smaller batches to avoid timeout issues
    const batchSize = 100;
    for (int i = 0; i < messages.docs.length; i += batchSize) {
      final batch = FirebaseFirestore.instance.batch();
      final endIndex = (i + batchSize < messages.docs.length) ? i + batchSize : messages.docs.length;
      
      for (int j = i; j < endIndex; j++) {
        batch.delete(messages.docs[j].reference);
      }
      
      await batch.commit();
    }

    // Delete the channel document
    await FirebaseFirestore.instance
        .collection('channels')
        .doc(channelId)
        .delete();
  }
}

class ChannelInfoScreen extends StatefulWidget {
  final String channelId;
  final String channelName;
  final Map<String, dynamic> channelData;

  const ChannelInfoScreen({
    super.key,
    required this.channelId,
    required this.channelName,
    required this.channelData,
  });

  @override
  State<ChannelInfoScreen> createState() => _ChannelInfoScreenState();
}

class _ChannelInfoScreenState extends State<ChannelInfoScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.channelName;
    _descriptionController.text = widget.channelData['description'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Channel Info'),
        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.8),
        foregroundColor: Colors.white,
        actions: [
          if (_isEditing)
            TextButton(
              onPressed: _saveChanges,
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            )
          else
            IconButton(
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Channel Name
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Channel Name',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    if (_isEditing)
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Enter channel name',
                        ),
                      )
                    else
                      Text(
                        widget.channelName,
                        style: const TextStyle(fontSize: 16),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Channel Description
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Description',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    if (_isEditing)
                      TextField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Enter channel description',
                        ),
                        maxLines: 3,
                      )
                    else
                      Text(
                        widget.channelData['description']?.isNotEmpty == true
                            ? widget.channelData['description']
                            : 'No description provided',
                        style: TextStyle(
                          fontSize: 16,
                          color: widget.channelData['description']?.isNotEmpty == true
                              ? Colors.black
                              : Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Members Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Members',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        ElevatedButton.icon(
                          onPressed: _showAddMemberDialog,
                          icon: const Icon(Icons.person_add, size: 18),
                          label: const Text('Add Member'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildMembersList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersList() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('channels')
          .doc(widget.channelId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Text('Channel not found');
        }

        final channelData = snapshot.data!.data() as Map<String, dynamic>;
        final members = List<String>.from(channelData['members'] ?? []);

        if (members.isEmpty) {
          return const Text('No members in this channel');
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final userMap = <String, Map<String, dynamic>>{};
            if (userSnapshot.hasData) {
              for (final doc in userSnapshot.data!.docs) {
                userMap[doc.id] = doc.data() as Map<String, dynamic>;
              }
            }

            return Column(
              children: members.map((memberId) {
                final userData = userMap[memberId];
                final userName = userData?['username'] ?? userData?['email']?.split('@')?.first ?? 'Unknown User';

                return ListTile(
                  leading: CircleAvatar(
                    child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : '?'),
                  ),
                  title: Text(userName),
                  subtitle: Text(userData?['email'] ?? ''),
                  trailing: IconButton(
                    onPressed: () => _removeMember(memberId, userName),
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                    tooltip: 'Remove Member',
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  void _showAddMemberDialog() {
    showDialog(
      context: context,
      builder: (context) => AddMemberDialog(channelId: widget.channelId),
    );
  }

  Future<void> _removeMember(String memberId, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Remove $userName from this channel?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('channels')
            .doc(widget.channelId)
            .update({
          'members': FieldValue.arrayRemove([memberId]),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$userName removed from channel'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error removing member: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _saveChanges() async {
    try {
      await FirebaseFirestore.instance
          .collection('channels')
          .doc(widget.channelId)
          .update({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() => _isEditing = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Channel info updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating channel: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

class AddMemberDialog extends StatefulWidget {
  final String channelId;

  const AddMemberDialog({super.key, required this.channelId});

  @override
  State<AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<AddMemberDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  List<String> _currentMembers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentMembers();
  }

  Future<void> _loadCurrentMembers() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('channels')
          .doc(widget.channelId)
          .get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _currentMembers = List<String>.from(data['members'] ?? []);
        setState(() {});
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query.toLowerCase())
          .where('username', isLessThanOrEqualTo: '${query.toLowerCase()}\uf8ff')
          .limit(10)
          .get();

      final results = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        results.add(data);
      }

      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final maxDialogHeight = screenHeight * 0.7 - keyboardHeight;
    
    return AlertDialog(
      title: const Text('Add Member'),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxDialogHeight > 200 ? maxDialogHeight : 200,
          maxWidth: double.maxFinite,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search users',
                  hintText: 'Enter username to search',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: _searchUsers,
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                )
              else if (_searchResults.isNotEmpty)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: (maxDialogHeight - 120).clamp(150.0, 300.0),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final user = _searchResults[index];
                      final userId = user['id'] as String;
                      final userName = user['username'] ?? user['email']?.split('@')?.first ?? 'Unknown';
                      final isAlreadyMember = _currentMembers.contains(userId);

                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : '?'),
                        ),
                        title: Text(userName),
                        subtitle: Text(user['email'] ?? ''),
                        trailing: isAlreadyMember
                            ? const Icon(Icons.check, color: Colors.green)
                            : IconButton(
                                onPressed: () => _addMember(userId, userName),
                                icon: const Icon(Icons.add),
                              ),
                      );
                    },
                  ),
                )
              else if (_searchController.text.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No users found'),
                )
              else
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Start typing to search for users'),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Future<void> _addMember(String userId, String userName) async {
    try {
      await FirebaseFirestore.instance
          .collection('channels')
          .doc(widget.channelId)
          .update({
        'members': FieldValue.arrayUnion([userId]),
      });

      setState(() {
        _currentMembers.add(userId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$userName added to channel'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding member: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
