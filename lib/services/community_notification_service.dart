import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class CommunityNotificationService extends ChangeNotifier {
  static CommunityNotificationService? _instance;
  static CommunityNotificationService get instance => _instance ??= CommunityNotificationService._();

  CommunityNotificationService._();

  int _unreadCount = 0;
  String? _latestAdminMessage;
  String? _latestChannelName;
  DateTime? _lastChecked;
  bool _isInitialized = false;
  
  // Stream subscriptions for cleanup
  final List<StreamSubscription> _subscriptions = [];

  int get unreadCount => _unreadCount;
  String? get latestAdminMessage => _latestAdminMessage;
  String? get latestChannelName => _latestChannelName;
  bool get hasUnreadMessages => _unreadCount > 0;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return; // Prevent multiple initializations
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Get user's last checked time
    await _loadLastCheckedTime(user.uid);
    
    // Start listening for new admin messages
    _listenForAdminMessages(user.uid);
    
    _isInitialized = true;
    notifyListeners();
  }

  void dispose() {
    // Clean up all stream subscriptions
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _isInitialized = false;
    super.dispose();
  }

  void reset() {
    // Cancel all subscriptions
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    
    // Reset state
    _unreadCount = 0;
    _latestAdminMessage = null;
    _latestChannelName = null;
    _lastChecked = null;
    _isInitialized = false;
    
    notifyListeners();
  }

  Future<void> _loadLastCheckedTime(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('user_community_state')
          .doc(userId)
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        if (data['lastChecked'] is Timestamp) {
          _lastChecked = (data['lastChecked'] as Timestamp).toDate();
        }
      }
      
      // If no last checked time, use current time
      _lastChecked ??= DateTime.now();
    } catch (e) {
      print('Error loading last checked time: $e');
      _lastChecked = DateTime.now();
    }
  }

  void _listenForAdminMessages(String userId) {
    // Listen for channels the user is a member of
    final channelsSubscription = FirebaseFirestore.instance
        .collection('channels')
        .where('members', arrayContains: userId)
        .snapshots()
        .listen((channelsSnapshot) async {
      
      if (channelsSnapshot.docs.isEmpty) {
        // No channels, no unread messages
        _updateNotificationState(0, null, null);
        return;
      }

      int totalUnread = 0;
      String? latestMessage;
      String? latestChannel;
      DateTime? latestTime;

      // Process each channel
      for (final channelDoc in channelsSnapshot.docs) {
        final channelData = channelDoc.data();
        final channelName = channelData['name'] ?? 'Unknown Channel';
        
        try {
          // Get messages newer than last checked time
          final messagesSnapshot = await FirebaseFirestore.instance
              .collection('channels')
              .doc(channelDoc.id)
              .collection('messages')
              .where('createdAt', isGreaterThan: Timestamp.fromDate(_lastChecked!))
              .orderBy('createdAt', descending: true)
              .get();

          if (messagesSnapshot.docs.isEmpty) continue;

          // Get all unique sender IDs
          final senderIds = messagesSnapshot.docs
              .map((doc) => doc.data()['userId'] as String?)
              .where((id) => id != null && id != userId)
              .toSet();

          if (senderIds.isEmpty) continue;

          // Batch get all user documents to check roles
          final usersSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .where(FieldPath.documentId, whereIn: senderIds.toList())
              .get();

          // Create a map of userId -> isAdmin
          final adminMap = <String, bool>{};
          for (final userDoc in usersSnapshot.docs) {
            if (userDoc.exists) {
              final role = (userDoc.data()['role'] ?? 'user').toString().toLowerCase();
              adminMap[userDoc.id] = (role == 'admin');
            }
          }

          // Count messages from admin users
          for (final messageDoc in messagesSnapshot.docs) {
            final messageData = messageDoc.data();
            final senderId = messageData['userId'] as String?;
            
            if (senderId != null && 
                senderId != userId && 
                adminMap[senderId] == true) {
              totalUnread++;
              
              // Track latest admin message
              final messageTime = (messageData['createdAt'] as Timestamp).toDate();
              if (latestTime == null || messageTime.isAfter(latestTime)) {
                latestTime = messageTime;
                latestMessage = messageData['text'] ?? 'New message';
                latestChannel = channelName;
              }
            }
          }
        } catch (e) {
          print('Error processing channel ${channelDoc.id}: $e');
        }
      }

      // Update state with final count
      _updateNotificationState(totalUnread, latestMessage, latestChannel);
    });
    
    // Add channels subscription to cleanup list
    _subscriptions.add(channelsSubscription);
  }

  void _updateNotificationState(int count, String? message, String? channel) {
    _unreadCount = count;
    _latestAdminMessage = message;
    _latestChannelName = channel;
    notifyListeners();
  }

  Future<void> markAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Update last checked time
      await FirebaseFirestore.instance
          .collection('user_community_state')
          .doc(user.uid)
          .set({
        'lastChecked': FieldValue.serverTimestamp(),
        'userId': user.uid,
      }, SetOptions(merge: true));

      // Reset counters
      _unreadCount = 0;
      _latestAdminMessage = null;
      _latestChannelName = null;
      _lastChecked = DateTime.now();
      
      notifyListeners();
    } catch (e) {
      print('Error marking as read: $e');
    }
  }

  // Stream that provides unread count
  Stream<int> getUnreadCountStream(String userId) {
    return FirebaseFirestore.instance
        .collection('user_community_state')
        .doc(userId)
        .snapshots()
        .asyncMap((doc) async {
      try {
        // Initialize user state if it doesn't exist
        if (!doc.exists) {
          await FirebaseFirestore.instance
              .collection('user_community_state')
              .doc(userId)
              .set({
            'lastChecked': FieldValue.serverTimestamp(),
          });
          return 0;
        }

        final data = doc.data()!;
        final lastChecked = data['lastChecked'] as Timestamp?;
        
        if (lastChecked == null) return 0;

        // Get channels user is member of
        final channelsSnapshot = await FirebaseFirestore.instance
            .collection('channels')
            .where('members', arrayContains: userId)
            .get();

        if (channelsSnapshot.docs.isEmpty) return 0;

        int totalUnread = 0;

        // Get all admin users first to avoid repeated queries
        final adminUsers = <String>{};
        final usersSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'admin')
            .get();
        
        for (final userDoc in usersSnapshot.docs) {
          adminUsers.add(userDoc.id);
        }

        if (adminUsers.isEmpty) return 0;

        // Check each channel for unread admin messages
        for (final channelDoc in channelsSnapshot.docs) {
          final messagesSnapshot = await FirebaseFirestore.instance
              .collection('channels')
              .doc(channelDoc.id)
              .collection('messages')
              .where('createdAt', isGreaterThan: lastChecked)
              .where('userId', whereIn: adminUsers.toList())
              .get();
          
          // Count messages from admins (excluding the current user if they're admin)
          totalUnread += messagesSnapshot.docs.where((doc) {
            final messageData = doc.data();
            final senderId = messageData['userId'] as String?;
            return senderId != null && senderId != userId;
          }).length;
        }

        return totalUnread;
      } catch (e) {
        print('Error in getUnreadCountStream: $e');
        return 0;
      }
    });
  }
}
