import '../../../core/logger/app_logger.dart';
import '../../../core/exceptions/exception_handler.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/viewmodels/view_state.dart';
import '../../../domain/repositories/auth_repository.dart';

class RegisterViewModel extends BaseViewModel {
  RegisterViewModel({
    required AuthRepository authRepository,
    required ExceptionHandler exceptionHandler,
  })  : _authRepository = authRepository,
        _exceptionHandler = exceptionHandler;

  final AuthRepository _authRepository;
  final ExceptionHandler _exceptionHandler;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<bool> registerUser({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    setState(ViewState.loading);
    try {
      AppLogger.info('Attempting registration via RegisterViewModel for: $email');
      
      // Validate input
      if (name.trim().isEmpty) {
        _errorMessage = 'Please enter your full name';
        setState(ViewState.error);
        return false;
      }
      
      if (email.trim().isEmpty || !email.contains('@')) {
        _errorMessage = 'Please enter a valid email address';
        setState(ViewState.error);
        return false;
      }

      
      if (password.length < 6) {
        _errorMessage = 'Password must be at least 6 characters';
        setState(ViewState.error);
        return false;
      }

      // Call repository to register user
      await _authRepository.registerUser(
        name: name.trim(),
        email: email.trim().toLowerCase(),
        phone: phone.trim(),
        password: password,
      );
      
      _errorMessage = null;
      setState(ViewState.success);
      AppLogger.info('Registration succeeded via RegisterViewModel');
      return true;
    } catch (error, stackTrace) {
      _errorMessage = _exceptionHandler.handle(error, stackTrace);
      setState(ViewState.error);
      AppLogger.error('Registration failed', error: error, stackTrace: stackTrace);
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    reset();
  }
}

