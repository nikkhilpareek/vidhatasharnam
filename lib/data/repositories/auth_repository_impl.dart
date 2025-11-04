import 'package:firebase_auth/firebase_auth.dart';

import 'package:vidhatasharnam/core/exceptions/app_exception.dart';
import 'package:vidhatasharnam/core/logger/app_logger.dart';
import 'package:vidhatasharnam/data/datasources/auth/auth_service.dart';
import 'package:vidhatasharnam/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required AuthService authService}) : _authService = authService;

  final AuthService _authService;

  @override
  Future<void> refreshUser() async {
    try {
      await _authService.refreshUserData();
    } catch (error, stackTrace) {
      AppLogger.error('Failed to refresh user data', error: error, stackTrace: stackTrace);
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _authService.signIn(email, password);
    } catch (error, stackTrace) {
      AppLogger.warning('Sign in failed via repository', error: error, stackTrace: stackTrace);
      throw _mapError(error, stackTrace);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _authService.signOut();
    } catch (error, stackTrace) {
      AppLogger.warning('Sign out failed via repository', error: error, stackTrace: stackTrace);
      throw _mapError(error, stackTrace);
    }
  }

  AppException _mapError(Object error, StackTrace stackTrace) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-disabled':
          return const UnauthorizedException('Your account is disabled. Contact the administrator.');
        case 'wrong-password':
        case 'user-not-found':
        case 'invalid-credential':
          return const UnauthorizedException('Incorrect email or password. Please try again.');
        case 'too-many-requests':
          return const NetworkException('Too many unsuccessful attempts. Please wait and try again later.');
        case 'invalid-email':
          return const ValidationException('The email address is invalid. Check the format and try again.');
        default:
          return UnknownAppException(error.message ?? 'Authentication failed', stackTrace: stackTrace);
      }
    }

    if (error is AppException) {
      return error;
    }

    return UnknownAppException(error.toString(), stackTrace: stackTrace);
  }
}

