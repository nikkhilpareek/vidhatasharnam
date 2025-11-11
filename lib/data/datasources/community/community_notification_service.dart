import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'package:vidhatasharnam/core/logger/app_logger.dart';
import 'package:vidhatasharnam/core/config/app_constants.dart';
import 'package:vidhatasharnam/domain/repositories/local_storage.dart';

class CommunityNotificationService extends ChangeNotifier {
  static CommunityNotificationService? _instance;
  static CommunityNotificationService get instance => _instance ??= CommunityNotificationService._();

  CommunityNotificationService._();

  int _unreadCount = 0;
  String? _latestAdminMessage;
  String? _latestChannelName;
  DateTime? _lastChecked;
  bool _firestoreAvailable = true; // Track if Firestore is available (permissions)

  final LocalStorageService _localStorage = LocalStorageService();

  int get unreadCount => _unreadCount;
  String? get latestAdminMessage => _latestAdminMessage;
  String? get latestChannelName => _latestChannelName;
  bool get hasUnreadMessages => _unreadCount > 0;

  Future<void> initialize() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Get user's last checked time
    await _loadLastCheckedTime(user.uid);
    
    // Start listening for new admin messages
    _listenForAdminMessages(user.uid);
  }

  Future<void> _loadLastCheckedTime(String userId) async {
    // First, try to load from LocalStorage (primary storage)
    _lastChecked = _localStorage.getDateTime(AppConstants.prefCommunityLastChecked);
    
    // If not in LocalStorage, try Firestore (if available)
    if (_lastChecked == null && _firestoreAvailable) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('user_community_state')
            .doc(userId)
            .get();
        
        if (doc.exists) {
          final data = doc.data()!;
          if (data['lastChecked'] is Timestamp) {
            _lastChecked = (data['lastChecked'] as Timestamp).toDate();
            // Save to LocalStorage for future use
            await _localStorage.saveDateTime(AppConstants.prefCommunityLastChecked, _lastChecked!);
          }
        }
      } catch (e) {
        // Check if it's a permission error
        final isPermissionError = _isPermissionError(e);
        if (isPermissionError) {
          // Silently handle permission errors - Firestore not available
          _firestoreAvailable = false;
          if (kDebugMode) {
            debugPrint('[CommunityNotificationService] Firestore permissions not available, using LocalStorage only');
          }
        } else {
          // Log other errors but don't fail
          AppLogger.error(
            'Error loading last checked time from Firestore for user $userId',
            error: e,
          );
        }
      }
    }
    
    // If still no last checked time, use current time
    _lastChecked ??= DateTime.now();
    
    // Save to LocalStorage if not already saved
    if (_lastChecked != null) {
      final saved = _localStorage.getDateTime(AppConstants.prefCommunityLastChecked);
      if (saved == null) {
        await _localStorage.saveDateTime(AppConstants.prefCommunityLastChecked, _lastChecked!);
      }
    }
  }

  void _listenForAdminMessages(String userId) {
    // Listen for channels the user is a member of
    FirebaseFirestore.instance
        .collection('channels')
        .where('members', arrayContains: userId)
        .snapshots()
        .listen(
          (channelsSnapshot) {
      
      int totalUnread = 0;
      String? latestMessage;
      String? latestChannel;
      DateTime? latestTime;

      for (final channelDoc in channelsSnapshot.docs) {
        final channelData = channelDoc.data();
        final channelName = channelData['name'] ?? 'Unknown Channel';
        
        // Listen for messages in this channel from admin
        FirebaseFirestore.instance
            .collection('channels')
            .doc(channelDoc.id)
            .collection('messages')
            .where('createdAt', isGreaterThan: Timestamp.fromDate(_lastChecked!))
            .orderBy('createdAt', descending: true)
            .snapshots()
            .listen(
              (messagesSnapshot) {
          
          int channelUnread = 0;
          
          for (final messageDoc in messagesSnapshot.docs) {
            final messageData = messageDoc.data();
            final senderId = messageData['userId'];
            
            // Check if sender is admin
            FirebaseFirestore.instance
                .collection('users')
                .doc(senderId)
                .get()
                .then((senderDoc) {
              if (senderDoc.exists) {
                final senderData = senderDoc.data()!;
                final senderRole = (senderData['role'] ?? 'user').toString().toLowerCase();
                
                if (senderRole == 'admin' && senderId != userId) {
                  channelUnread++;
                  
                  // Track latest admin message
                  final messageTime = (messageData['createdAt'] as Timestamp).toDate();
                  if (latestTime == null || messageTime.isAfter(latestTime!)) {
                    latestTime = messageTime;
                    latestMessage = messageData['text'] ?? 'New message';
                    latestChannel = channelName;
                  }
                }
              }
            });
          }
          
          // Update total count (simplified for demo)
          if (channelUnread > 0) {
            totalUnread += channelUnread;
            _updateNotificationState(totalUnread, latestMessage, latestChannel);
          }
        },
        onError: (error) {
          // Handle permission errors for message listeners gracefully
          if (_isPermissionError(error)) {
            if (kDebugMode) {
              debugPrint('[CommunityNotificationService] Permission denied for messages in channel ${channelDoc.id}');
            }
          }
        },
        );
      }
    },
    onError: (error) {
      // Handle permission errors gracefully
      if (_isPermissionError(error)) {
        if (kDebugMode) {
          debugPrint('[CommunityNotificationService] Permission denied for channels, skipping message listening');
        }
      } else {
        AppLogger.error(
          'Error listening for admin messages',
          error: error,
        );
      }
    },
    );
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

    // Always update LocalStorage (primary storage)
    _lastChecked = DateTime.now();
    await _localStorage.saveDateTime(AppConstants.prefCommunityLastChecked, _lastChecked!);

    // Try to update Firestore if available (optional)
    if (_firestoreAvailable) {
      try {
        await FirebaseFirestore.instance
            .collection('user_community_state')
            .doc(user.uid)
            .set({
          'lastChecked': FieldValue.serverTimestamp(),
          'userId': user.uid,
        }, SetOptions(merge: true));
      } catch (e) {
        // Check if it's a permission error
        final isPermissionError = _isPermissionError(e);
        if (isPermissionError) {
          // Silently handle permission errors - Firestore not available
          _firestoreAvailable = false;
          if (kDebugMode) {
            debugPrint('[CommunityNotificationService] Firestore permissions not available, using LocalStorage only');
          }
        } else {
          // Log other errors but don't fail
          AppLogger.error(
            'Error marking community messages as read in Firestore for user ${user.uid}',
            error: e,
          );
        }
      }
    }

    // Reset counters (always do this regardless of Firestore success)
    _unreadCount = 0;
    _latestAdminMessage = null;
    _latestChannelName = null;
    
    notifyListeners();
  }

  // Stream that provides unread count
  Stream<int> getUnreadCountStream(String userId) {
    // If Firestore is not available, return a stream that emits 0
    if (!_firestoreAvailable) {
      return Stream.value(0);
    }

    return FirebaseFirestore.instance
        .collection('user_community_state')
        .doc(userId)
        .snapshots()
        .asyncMap((doc) async {
      try {
        // Get lastChecked from LocalStorage first, then Firestore
        DateTime? lastChecked;
        final localLastChecked = _localStorage.getDateTime(AppConstants.prefCommunityLastChecked);
        
        if (doc.exists) {
          final data = doc.data()!;
          final firestoreLastChecked = data['lastChecked'] as Timestamp?;
          if (firestoreLastChecked != null) {
            lastChecked = firestoreLastChecked.toDate();
            // Sync to LocalStorage
            if (localLastChecked == null || lastChecked.isAfter(localLastChecked)) {
              await _localStorage.saveDateTime(AppConstants.prefCommunityLastChecked, lastChecked);
            }
          }
        }
        
        // Use LocalStorage value if Firestore doesn't have it
        lastChecked ??= localLastChecked;
        
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
      } catch (e, stackTrace) {
        // Check if it's a permission error
        final isPermissionError = _isPermissionError(e);
        if (isPermissionError) {
          // Silently handle permission errors - Firestore not available
          _firestoreAvailable = false;
          if (kDebugMode) {
            debugPrint('[CommunityNotificationService] Firestore permissions not available, using LocalStorage only');
          }
        } else {
          // Log other errors but don't fail
          AppLogger.error(
            'Error calculating unread count for user $userId',
            error: e,
            stackTrace: stackTrace,
          );
        }
        return 0;
      }
    }).handleError((error) {
      // Handle stream errors gracefully
      if (_isPermissionError(error)) {
        _firestoreAvailable = false;
        if (kDebugMode) {
          debugPrint('[CommunityNotificationService] Firestore permissions not available, using LocalStorage only');
        }
      }
      return 0;
    });
  }

  /// Helper method to check if an error is a permission error
  bool _isPermissionError(dynamic error) {
    if (error == null) return false;
    
    // Check for FirebaseException with permission-denied code
    if (error is FirebaseException) {
      return error.code == 'permission-denied';
    }
    
    // Check error string for permission-denied
    final errorString = error.toString().toLowerCase();
    return errorString.contains('permission-denied') || 
           errorString.contains('permission_denied');
  }
}
