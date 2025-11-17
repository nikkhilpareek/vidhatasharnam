import 'dart:async';

import '../../../core/viewmodels/base_view_model.dart';
import '../../../data/datasources/community/community_notification_service.dart';

class HomeViewModel extends BaseViewModel {
  HomeViewModel();

  final CommunityNotificationService _communityNotificationService =
      CommunityNotificationService.instance;

  int _notificationCount = 0;
  StreamSubscription<int>? _communityCountSubscription;
  String? _listeningUserId;

  int get notificationCount => _notificationCount;
  bool get isListeningToCommunity => _communityCountSubscription != null;

  /// Clears the locally stored count and marks the community messages as read.
  void clearNotifications() {
    _notificationCount = 0;
    notifyListeners();
    // Ensure Firestore/local state are reset as well.
    unawaited(_communityNotificationService.markAsRead());
  }

  void setNotificationCount(int count) {
    if (_notificationCount == count) return;
    _notificationCount = count;
    notifyListeners();
  }

  /// Starts listening to unread community notification count for the given user.
  Future<void> startCommunityNotificationListener(String userId) async {
    if (_listeningUserId == userId && _communityCountSubscription != null) {
      return;
    }

    _communityCountSubscription?.cancel();
    _listeningUserId = userId;

    // Sync current value immediately
    setNotificationCount(_communityNotificationService.unreadCount);

    _communityCountSubscription = _communityNotificationService
        .getUnreadCountStream(userId)
        .listen(setNotificationCount, onError: (error) {
      // If stream fails, fall back to zero so badge doesn't get stuck.
      setNotificationCount(0);
    });
  }

  void stopCommunityNotificationListener() {
    _communityCountSubscription?.cancel();
    _communityCountSubscription = null;
    _listeningUserId = null;
  }

  @override
  void dispose() {
    stopCommunityNotificationListener();
    super.dispose();
  }
}

