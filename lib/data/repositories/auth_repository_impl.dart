import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:vidhatasharnam/core/exceptions/app_exception.dart';
import 'package:vidhatasharnam/core/logger/app_logger.dart';
import 'package:vidhatasharnam/data/datasources/auth/auth_service.dart';
import 'package:vidhatasharnam/domain/repositories/auth_repository.dart';
import 'package:vidhatasharnam/config/supabase_config.dart';

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
      AppLogger.info('Registering user in Supabase: $email');
      
      final supabase = SupabaseConfig.client;
      
      // Check if user already exists in users table
      final existingUser = await supabase
          .from('users')
          .select('id, email')
          .eq('email', email.toLowerCase())
          .maybeSingle();
      
      if (existingUser != null) {
        throw const ValidationException('An account with this email already exists.');
      }
      
      // Check Firebase Auth for existing user (for backward compatibility)
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.toLowerCase(),
          password: password,
        );
        // If successful, user already exists in Firebase
        throw const ValidationException('An account with this email already exists.');
      } on FirebaseAuthException catch (e) {
        // If user not found, that's expected - continue with registration
        if (e.code != 'user-not-found' && e.code != 'wrong-password') {
          // Other errors should be handled
          if (e.code == 'invalid-email') {
            throw const ValidationException('The email address is invalid.');
          }
        }
      }
      
      // Create user in Supabase Auth (handles password hashing automatically)
      final response = await supabase.auth.signUp(
        email: email.toLowerCase(),
        password: password,
        data: {
          'name': name,
          'phone': phone,
        },
      );
      
      if (response.user == null) {
        throw const ValidationException('Failed to create user account. Please try again.');
      }
      
      final userId = response.user!.id;
      
      // Insert user data into Supabase users table
      // Note: Password is stored in Supabase Auth, not in the users table for security
      await supabase.from('users').insert({
        'id': userId,
        'name': name,
        'email': email.toLowerCase(),
        'phone': phone,
        'isApproved': false,
        'createdAt': DateTime.now().toIso8601String(),
      });
      
      // Also create Firebase Auth user for compatibility with existing login system
      // User won't be able to login until approved (checked in AuthService.signIn)
      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email.toLowerCase(),
          password: password,
        );
        
        // Create Firestore user document
        final firebaseUser = FirebaseAuth.instance.currentUser;
        if (firebaseUser != null) {
          await FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid).set({
            'name': name,
            'email': email.toLowerCase(),
            'phone': phone,
            'role': 'user',
            'active': false, // Inactive until approved
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          
          // Sign out immediately - user needs approval before they can login
          await FirebaseAuth.instance.signOut();
        }
      } catch (e) {
        // If Firebase Auth creation fails, log but don't fail registration
        // Supabase registration is primary
        AppLogger.warning('Could not create Firebase Auth user during registration: $e');
      }
      
      AppLogger.info('User registered successfully in Supabase: $email');
      
    } catch (error, stackTrace) {
      AppLogger.error('Registration failed in repository', error: error, stackTrace: stackTrace);
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
        case 'email-already-in-use':
          return const ValidationException('An account with this email already exists.');
        default:
          return UnknownAppException(error.message ?? 'Authentication failed', stackTrace: stackTrace);
      }
    }

    if (error is AuthException) {
      // Supabase Auth errors
      if (error.message.contains('already registered') || 
          error.message.contains('already exists')) {
        return const ValidationException('An account with this email already exists.');
      }
      if (error.message.contains('password') && error.message.contains('weak')) {
        return const ValidationException('Password is too weak. Please choose a stronger password.');
      }
      return ValidationException('Registration error: ${error.message}');
    }

    if (error is PostgrestException) {
      // Supabase database errors
      if (error.code == '23505') { // Unique constraint violation
        return const ValidationException('An account with this email already exists.');
      }
      return ValidationException('Database error: ${error.message}');
    }

    if (error is AppException) {
      return error;
    }

    return UnknownAppException(error.toString(), stackTrace: stackTrace);
  }
}

