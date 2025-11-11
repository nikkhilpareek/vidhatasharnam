import 'package:firebase_auth/firebase_auth.dart';

import '../logger/app_logger.dart';
import 'app_exception.dart';

class ExceptionHandler {
  const ExceptionHandler();

  String handle(Object error, [StackTrace? stackTrace]) {
    if (error is AppException) {
      AppLogger.error('AppException intercepted', error: error, stackTrace: stackTrace);
      return error.message;
    }

    // Check for approval pending message
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('pending approval') || errorString.contains('wait for admin')) {
      return 'Your account is pending approval by admin. Please try again later.';
    }

    if (error is FirebaseAuthException) {
      AppLogger.warning('FirebaseAuthException intercepted', error: error, stackTrace: stackTrace);
      switch (error.code) {
        case 'wrong-password':
        case 'user-not-found':
        case 'invalid-credential':
          return 'Incorrect email or password. Please try again.';
        case 'user-disabled':
          return 'Your account is disabled. Contact the administrator.';
        case 'too-many-requests':
          return 'Too many unsuccessful attempts. Please wait and try again later.';
        case 'invalid-email':
          return 'The email address is invalid. Check the format and try again.';
        default:
          return 'Login failed. Please verify your credentials and try again.';
      }
    }

    AppLogger.error('Unhandled exception intercepted', error: error, stackTrace: stackTrace);
    return 'Something went wrong. Please try again later.';
  }
}

