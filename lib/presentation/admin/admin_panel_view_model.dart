import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/viewmodels/view_state.dart';

class AdminPanelViewModel extends BaseViewModel {
  bool _isCreatingUser = false;
  bool _isChangingPassword = false;

  bool get isCreatingUser => _isCreatingUser;
  bool get isChangingPassword => _isChangingPassword;

  void setCreatingUser(bool value) {
    _isCreatingUser = value;
    notifyListeners();
  }

  void setChangingPassword(bool value) {
    _isChangingPassword = value;
    notifyListeners();
  }
}

