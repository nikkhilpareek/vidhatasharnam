import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/viewmodels/view_state.dart';

class HomeViewModel extends BaseViewModel {
  int _notificationCount = 12; // Default value

  int get notificationCount => _notificationCount;

  void clearNotifications() {
    _notificationCount = 0;
    notifyListeners();
  }

  void setNotificationCount(int count) {
    _notificationCount = count;
    notifyListeners();
  }
}

