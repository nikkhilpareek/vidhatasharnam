import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/viewmodels/view_state.dart';
import '../../../core/logger/app_logger.dart';
import '../../../domain/repositories/local_storage.dart';
import '../../../core/config/app_constants.dart';

class SplashViewModel extends BaseViewModel {
  final LocalStorageService _localStorage = LocalStorageService();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<Map<String, dynamic>> checkLoginStatus() async {
    setState(ViewState.loading);
    try {
      await Future.delayed(const Duration(milliseconds: 800));

      final isLoggedIn = _localStorage.getBool(AppConstants.prefIsLoggedIn) ?? false;
      final userRole = _localStorage.getString(AppConstants.prefUserRole) ?? '';
      final userName = _localStorage.getString(AppConstants.prefUserEmail)?.split('@')[0] ?? 'Admin';

      _isInitialized = true;
      setState(ViewState.success);

      return {
        'isLoggedIn': isLoggedIn,
        'userRole': userRole,
        'userName': userName,
      };
    } catch (e, stackTrace) {
      AppLogger.error('Error checking login status', error: e, stackTrace: stackTrace);
      setState(ViewState.error);
      return {
        'isLoggedIn': false,
        'userRole': '',
        'userName': '',
      };
    }
  }
}

