import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

import 'package:vidhatasharnam/core/logger/app_logger.dart';

enum AuthStatus {
  unknown,
  authenticated,
  unauthenticated,
  loading,
}

class UserData {
  final String uid;
  final String email;
  final String role;
  final bool isActive;
  final String displayName;

  UserData({
    required this.uid,
    required this.email,
    required this.role,
    required this.isActive,
    required this.displayName,
  });

  factory UserData.fromFirestore(String uid, Map<String, dynamic> data) {
    return UserData(
      uid: uid,
      email: data['email'] ?? '',
      role: (data['role'] ?? 'user').toString().toLowerCase(),
      isActive: data['active'] ?? false,
      displayName: data['name'] ?? data['email']?.split('@')[0] ?? 'User',
    );
  }
}

class AuthService extends ChangeNotifier {
  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._();

  AuthService._();

  AuthStatus _status = AuthStatus.unknown;
  UserData? _userData;
  User? _firebaseUser;
  bool _isInitialized = false;

  AuthStatus get status => _status;
  UserData? get userData => _userData;
  User? get firebaseUser => _firebaseUser;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isInitialized => _isInitialized;

  static const String _lastLoginKey = 'last_successful_login';
  static const String _userDataKey = 'cached_user_data';

  Future<void> init() async {
    _status = AuthStatus.loading;
    notifyListeners();

    FirebaseAuth.instance.authStateChanges().listen(_onAuthStateChanged);
    await _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastLogin = prefs.getString(_lastLoginKey);
      final cachedUserData = prefs.getString(_userDataKey);

      // Get current Firebase user
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null && lastLogin != null) {
        // User exists in Firebase Auth, verify with Firestore
        await _verifyAndSetUserData(currentUser);
      } else if (cachedUserData != null && currentUser != null) {
        // Fallback to cached data while verifying
        await _verifyAndSetUserData(currentUser);
      } else {
        // No valid session found
        await _clearSession();
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error checking existing session',
        error: e,
        stackTrace: stackTrace,
      );
      await _clearSession();
    }

    _isInitialized = true;
    notifyListeners();
  }

  void _onAuthStateChanged(User? user) async {
    _firebaseUser = user;
    
    if (user == null) {
      await _clearSession();
    } else if (_status != AuthStatus.authenticated) {
      // User signed in, verify their data
      await _verifyAndSetUserData(user);
    }
  }

  Future<void> _verifyAndSetUserData(User user) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception('User document not found');
      }

      final userData = UserData.fromFirestore(user.uid, userDoc.data()!);

      if (!userData.isActive) {
        // Sign out inactive user and notify UI
        await FirebaseAuth.instance.signOut();
        await _clearSession();
        throw Exception('User account is inactive');
      }

      // Save successful login
      await _saveUserSession(userData);
      
      _userData = userData;
      _firebaseUser = user;
      _status = AuthStatus.authenticated;
      notifyListeners();

    } catch (e, stackTrace) {
      AppLogger.error(
        'Error verifying user data for user ${user.uid}',
        error: e,
        stackTrace: stackTrace,
      );
      await _clearSession();
      rethrow;
    }
  }

  Future<void> _saveUserSession(UserData userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastLoginKey, DateTime.now().toIso8601String());
      await prefs.setString(_userDataKey, userData.uid); // Just store reference
    } catch (e, stackTrace) {
      AppLogger.warning(
        'Error saving user session for user ${userData.uid}',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastLoginKey);
      await prefs.remove(_userDataKey);
    } catch (e, stackTrace) {
      AppLogger.warning(
        'Error clearing session data',
        error: e,
        stackTrace: stackTrace,
      );
    }

    _userData = null;
    _firebaseUser = null;
    _status = AuthStatus.unauthenticated;
    if (_isInitialized) notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    try {
      _status = AuthStatus.loading;
      notifyListeners();

      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        throw Exception('Login failed');
      }

      // _onAuthStateChanged will handle the rest
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error during sign in for $email',
        error: e,
        stackTrace: stackTrace,
      );
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      await _clearSession();
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error signing out',
        error: e,
        stackTrace: stackTrace,
      );
      // Force clear session even if Firebase signOut fails
      await _clearSession();
    }
  }

  Future<void> refreshUserData() async {
    if (_firebaseUser == null) return;
    
    try {
      await _verifyAndSetUserData(_firebaseUser!);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error refreshing user data',
        error: e,
        stackTrace: stackTrace,
      );
      // If refresh fails, sign out user
      await signOut();
    }
  }
}
