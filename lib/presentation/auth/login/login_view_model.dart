import '../../../core/logger/app_logger.dart';
import '../../../core/exceptions/exception_handler.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/viewmodels/view_state.dart';
import '../../../domain/repositories/auth_repository.dart';

class LoginViewModel extends BaseViewModel {
  LoginViewModel({
    required AuthRepository authRepository,
    required ExceptionHandler exceptionHandler,
  })  : _authRepository = authRepository,
        _exceptionHandler = exceptionHandler;

  final AuthRepository _authRepository;
  final ExceptionHandler _exceptionHandler;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<bool> login({required String email, required String password}) async {
    setState(ViewState.loading);
    try {
      AppLogger.info('Attempting login via LoginViewModel');
      await _authRepository.signIn(email: email, password: password);
      _errorMessage = null;
      setState(ViewState.success);
      AppLogger.info('Login succeeded via LoginViewModel');
      return true;
    } catch (error, stackTrace) {
      _errorMessage = _exceptionHandler.handle(error, stackTrace);
      setState(ViewState.error);
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    reset();
  }
}

