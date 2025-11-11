import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

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

  @override
  Future<void> registerUser({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      AppLogger.info('Registering user in Firestore: $email');
      
      final emailLower = email.toLowerCase().trim();
      
      // Check if user already exists in Firestore
      final existingUsers = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: emailLower)
          .limit(1)
          .get();
      
      if (existingUsers.docs.isNotEmpty) {
        throw const ValidationException('An account with this email already exists.');
      }
      
      // Check Firebase Auth for existing user
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailLower,
          password: password,
        );
        // If successful, user already exists in Firebase Auth
        await FirebaseAuth.instance.signOut(); // Sign out immediately
        throw const ValidationException('An account with this email already exists.');
      } on FirebaseAuthException catch (e) {
        // If user not found, that's expected - continue with registration
        if (e.code != 'user-not-found' && e.code != 'wrong-password') {
          // Other errors should be handled
          if (e.code == 'invalid-email') {
            throw const ValidationException('The email address is invalid.');
          }
          // Re-throw other unexpected errors
          throw const ValidationException('Registration failed. Please try again.');
        }
      }
      
      // Create user in Firebase Auth (matches admin pattern)
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: emailLower,
        password: password,
      );
      
      if (userCredential.user == null) {
        throw const ValidationException('Failed to create user account. Please try again.');
      }
      
      final newUid = userCredential.user!.uid;
      
      // Create Firestore user document (matches admin pattern exactly)
      // Admin uses: username, email, phone, role: 'User', active: true, status: 'Active'
      // Registration uses same fields but with isApproved: false, active: false
      await FirebaseFirestore.instance.collection('users').doc(newUid).set({
        'username': name, // Admin uses 'username' field
        'name': name, // Also include 'name' for consistency
        'email': emailLower,
        'phone': phone,
        'role': 'user', // Admin uses 'User' but we'll use lowercase for consistency
        'active': false, // Inactive until approved (admin sets to true)
        'status': 'Pending', // Status for pending approval (admin sets to 'Active')
        'isApproved': false, // NEW: registration default
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Sign out immediately - user needs approval before they can login
      await FirebaseAuth.instance.signOut();
      
      AppLogger.info('User registered successfully in Firestore: $email');
      
    } catch (error, stackTrace) {
      // Log to Crashlytics
      FirebaseCrashlytics.instance.recordError(error, stackTrace, reason: 'Registration failed');
      AppLogger.error('Registration failed in repository', error: error, stackTrace: stackTrace);
      throw _mapError(error, stackTrace);
    }
  }

  AppException _mapError(Object error, StackTrace stackTrace) {
    // Check for approval pending message first
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('pending approval')) {
      return const UnauthorizedException('Your account is pending approval by admin. Please try again later.');
    }
    
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
        case 'email-already-in-use':
          return const ValidationException('An account with this email already exists.');
        default:
          return UnknownAppException(error.message ?? 'Authentication failed', stackTrace: stackTrace);
      }
    }

    if (error is FirebaseException) {
      // Firestore errors
      if (error.code == 'permission-denied') {
        return const ValidationException('Permission denied. Please contact support.');
      }
      if (error.code == 'unavailable') {
        return const NetworkException('Network error. Please check your connection and try again.');
      }
      return ValidationException('Database error: ${error.message}');
    }

    if (error is AppException) {
      return error;
    }

    return UnknownAppException(error.toString(), stackTrace: stackTrace);
  }
}

