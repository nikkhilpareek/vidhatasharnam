import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin/tabs/community_admin_tab.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});
  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  String? _uid;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    _loadRole();
  }

  Future<void> _loadRole() async {
    final id = _uid;
    if (id == null) return;
    final snap = await FirebaseFirestore.instance.collection('users').doc(id).get();
    setState(() {
      _isAdmin = (snap.data()?['role'] ?? '').toString().toLowerCase() == 'admin';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return const Scaffold(body: Center(child: Text('Not authenticated')));
    }
    final q = FirebaseFirestore.instance
        .collection('channels')
        .where('members', arrayContains: _uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton(
              onPressed: () {
                Navigator.pushNamed(context, '/newChannel');
              },
              child: const Icon(Icons.add),
            )
          : null,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const _ChannelListSkeleton();
          }
            if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final docs = snap.data?.docs ?? [];
          docs.sort((a, b) {
            final ta = a.data()['lastMessageAt'] ?? a.data()['createdAt'];
            final tb = b.data()['lastMessageAt'] ?? b.data()['createdAt'];
            if (ta is Timestamp && tb is Timestamp) {
              return tb.toDate().compareTo(ta.toDate());
            }
            return 0;
          });
          if (docs.isEmpty) {
            return const Center(child: Text('No channels yet'));
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 0, indent: 72),
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data();
              final name = (data['name'] ?? 'Channel').toString();
              final preview = (data['lastMessagePreview'] ?? '').toString();
              final ts = (data['lastMessageAt'] ?? data['createdAt']);
              DateTime? dt;
              if (ts is Timestamp) dt = ts.toDate();
              final members = (data['members'] as List?)?.length ?? 0;
              final initials = _initials(name);
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                  child: Text(initials, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  preview.isEmpty ? 'No messages yet' : preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: preview.isEmpty ? Colors.grey : Colors.black54),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_relativeTime(dt), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$members', style: const TextStyle(fontSize: 10)),
                    )
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CommunityChannelScreen(
                        channelId: d.id,
                        channelName: name,
                        isAdmin: _isAdmin,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _initials(String s) {
    final parts = s.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  String _relativeTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays == 1) return 'yest';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}';
  }
}

class CommunityChannelScreen extends StatefulWidget {
  final String channelId;
  final String channelName;
  final bool isAdmin;
  const CommunityChannelScreen({
    super.key,
    required this.channelId,
    required this.channelName,
    required this.isAdmin,
  });

  @override
  State<CommunityChannelScreen> createState() => _CommunityChannelScreenState();
}

class _CommunityChannelScreenState extends State<CommunityChannelScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String? _uid;
  String? _openReactionFor;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
  }

  Future<void> _send() async {
    if (!widget.isAdmin) return;
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _uid == null) return;

    final channelRef = FirebaseFirestore.instance.collection('channels').doc(widget.channelId);
    final msgRef = channelRef.collection('messages').doc();

    await msgRef.set({
      'text': text,
      'senderId': _uid,
      'type': 'text',
      'createdAt': FieldValue.serverTimestamp(),
      'reactions': <String, dynamic>{},
    });

    await channelRef.update({
      'lastMessagePreview': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
    }).catchError((_) {});
    _msgCtrl.clear();
    _jumpToBottomSoon();
  }

  void _jumpToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleReaction(String messageId, String emoji) async {
    final uid = _uid;
    if (uid == null) return;
    final ref = FirebaseFirestore.instance
        .collection('channels')
        .doc(widget.channelId)
        .collection('messages')
        .doc(messageId);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      final reactions = Map<String, dynamic>.from(data['reactions'] ?? {});
      final list = List<String>.from(reactions[emoji] ?? []);
      if (list.contains(uid)) {
        list.remove(uid);
      } else {
        list.add(uid);
      }
      reactions[emoji] = list;
      tx.update(ref, {'reactions': reactions});
    });
  }

  void _openReactionPicker(String messageId, Map<String, dynamic> current) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        const all = ['👍', '❤️', '😂', '😮', '😢', '🙏', '🔥', '👏', '💯'];
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            childAspectRatio: 1.1,
          ),
          itemCount: all.length,
          itemBuilder: (_, i) {
            final e = all[i];
            final mine = (current[e] is List) && (current[e] as List).contains(_uid);
            return InkWell(
              onTap: () {
                Navigator.pop(context);
                _toggleReaction(messageId, e);
              },
              child: CircleAvatar(
                backgroundColor: mine ? Colors.green.withOpacity(0.2) : Colors.grey.shade100,
                child: Text(e, style: const TextStyle(fontSize: 20)),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showChannelInfo(BuildContext context) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('channels')
          .doc(widget.channelId)
          .get();
      
      if (doc.exists && mounted) {
        final channelData = doc.data() as Map<String, dynamic>;
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChannelInfoScreen(
              channelId: widget.channelId,
              channelName: widget.channelName,
              channelData: channelData,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading channel info: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final msgStream = FirebaseFirestore.instance
        .collection('channels')
        .doc(widget.channelId)
        .collection('messages')
        .orderBy('createdAt', descending: false) // ASCENDING
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.channelName),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          if (widget.isAdmin)
            IconButton(
              onPressed: () => _showChannelInfo(context),
              icon: const Icon(Icons.info_outline),
              tooltip: 'Channel Info',
            ),
        ],
      ),
      body: Column(
        children: [
          if (!widget.isAdmin)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(.15),
                border: Border(
                  bottom: BorderSide(color: Colors.amber.withOpacity(.3)),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock, size: 16, color: Colors.amber.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Read-only. Tap a message to react or long-press for more.',
                      style: TextStyle(fontSize: 12, color: Colors.amber.shade800),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: msgStream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No messages yet'));
                }

                WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottomSoon());

                final items = docs; // ascending oldest->newest
                DateTime? previousDate;

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
                  itemCount: items.length + 1, // +1 for bottom aesthetic placeholder
                  itemBuilder: (context, i) {
                    if (i == items.length) {
                      return _BottomPlaceholder(isAdmin: widget.isAdmin);
                    }
                    final d = items[i];
                    final data = d.data();
                    final text = (data['text'] ?? '').toString();
                    final ts = data['createdAt'];
                    DateTime? dt;
                    if (ts is Timestamp) dt = ts.toDate();
                    final reactions = Map<String, dynamic>.from(data['reactions'] ?? {});
                    final isMine = data['senderId'] == _uid;
                    final showSeparator = _needsSeparator(previousDate, dt);
                    if (dt != null) previousDate = dt;

                    return Column(
                      children: [
                        if (showSeparator && dt != null)
                          _DateSeparator(label: _dateLabel(dt)),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _openReactionFor = _openReactionFor == d.id ? null : d.id;
                            });
                          },
                          onLongPress: () => _openReactionPicker(d.id, reactions),
                          child: Align(
                            alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                            child: _MessageBubble(
                              messageId: d.id,
                              text: text,
                              time: dt,
                              isMine: isMine,
                              isAdminSender: isMine && widget.isAdmin,
                              reactions: reactions,
                              showQuickBar: _openReactionFor == d.id,
                              onQuickReact: (e) => _toggleReaction(d.id, e),
                              onOpenPicker: () => _openReactionPicker(d.id, reactions),
                              currentUid: _uid,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          if (widget.isAdmin)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _msgCtrl,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Broadcast a message…',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white, size: 19),
                        onPressed: _send,
                      ),
                    )
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _needsSeparator(DateTime? previous, DateTime? current) {
    if (current == null) return false;
    if (previous == null) return true;
    return !(previous.year == current.year &&
        previous.month == current.month &&
        previous.day == current.day);
  }

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${day.day.toString().padLeft(2, '0')} '
        '${_monthShort(day.month)} '
        '${day.year}';
  }

  String _monthShort(int m) {
    const names = [
      'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return names[m - 1];
  }
}

class _MessageBubble extends StatelessWidget {
  final String messageId;
  final String text;
  final DateTime? time;
  final bool isMine;
  final bool isAdminSender;
  final Map<String, dynamic> reactions;
  final bool showQuickBar;
  final void Function(String emoji) onQuickReact;
  final VoidCallback onOpenPicker;
  final String? currentUid;

  const _MessageBubble({
    required this.messageId,
    required this.text,
    required this.time,
    required this.isMine,
    required this.isAdminSender,
    required this.reactions,
    required this.showQuickBar,
    required this.onQuickReact,
    required this.onOpenPicker,
    required this.currentUid,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMine
        ? (isAdminSender
            ? Colors.green.shade600
            : Theme.of(context).colorScheme.primary.withOpacity(.85))
        : Colors.grey.shade200;
    final textColor = isMine ? Colors.white : Colors.black87;

    final aggregated = reactions.entries
        .where((e) => e.value is List && (e.value as List).isNotEmpty)
        .map((e) => MapEntry(e.key, (e.value as List).length))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final mineSet = reactions.map((k, v) => MapEntry(k, (v is List && v.contains(currentUid))));
    final quickEmojis = const ['👍', '❤️', '😂', '🙏'];

    return Column(
      crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMine ? 16 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: TextStyle(color: textColor, fontSize: 15, height: 1.25)),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isAdminSender)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'ADMIN',
                          style: TextStyle(fontSize: 9, letterSpacing: .5, color: Colors.white),
                        ),
                      ),
                    ),
                  Text(
                    _timeText(time),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMine ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (aggregated.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: aggregated.take(6).map((e) {
                final mine = mineSet[e.key] == true;
                return GestureDetector(
                  onTap: () => onQuickReact(e.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: mine
                          ? (isMine ? Colors.greenAccent.withOpacity(.25) : Colors.green.withOpacity(.15))
                          : Colors.black.withOpacity(.06),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text('${e.key} ${e.value}', style: const TextStyle(fontSize: 12)),
                  ),
                );
              }).toList(),
            ),
          ),
        if (showQuickBar)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...quickEmojis.map((e) => InkWell(
                      onTap: () => onQuickReact(e),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Text(e, style: const TextStyle(fontSize: 20)),
                      ),
                    )),
                InkWell(
                  onTap: onOpenPicker,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Icon(Icons.add_reaction_outlined, size: 20, color: Colors.grey.shade600),
                  ),
                )
              ],
            ),
          ),
      ],
    );
  }

  String _timeText(DateTime? dt) {
    if (dt == null) return '';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _DateSeparator extends StatelessWidget {
  final String label;
  const _DateSeparator({required this.label});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const Expanded(child: Divider(thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
                letterSpacing: .3,
              ),
            ),
          ),
          const Expanded(child: Divider(thickness: 1)),
        ],
      ),
    );
  }
}

class _BottomPlaceholder extends StatelessWidget {
  final bool isAdmin;
  const _BottomPlaceholder({required this.isAdmin});
  @override
  Widget build(BuildContext context) {
    final txt = isAdmin
        ? 'You have reached the beginning.'
        : 'End of channel • Only admins can post.\nTap a message to leave a reaction.';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Icon(Icons.horizontal_rule_rounded, color: Colors.grey, size: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              txt,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelListSkeleton extends StatelessWidget {
  const _ChannelListSkeleton();
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (_, i) => ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Color(0xFFE0E0E0),
            shape: BoxShape.circle,
          ),
        ),
        title: _shimmerBar(width: 160),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: _shimmerBar(width: 90),
        ),
      ),
    );
  }

  Widget _shimmerBar({required double width}) {
    return Container(
      height: 12,
      width: width,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
