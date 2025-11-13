import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:vidhatasharnam/core/logger/app_logger.dart';
import 'package:vidhatasharnam/core/config/app_constants.dart';
import 'package:vidhatasharnam/domain/repositories/local_storage.dart';

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
      displayName: data['username'] ?? data['name'] ?? data['email']?.split('@')[0] ?? 'User',
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

  final LocalStorageService _localStorage = LocalStorageService();

  Future<void> init() async {
    _status = AuthStatus.loading;
    notifyListeners();

    FirebaseAuth.instance.authStateChanges().listen(_onAuthStateChanged);
    await _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    try {
      // Check login status via LocalStorageService
      final isLoggedIn = _localStorage.getBool(AppConstants.prefIsLoggedIn) ?? false;
      final userId = _localStorage.getString(AppConstants.prefUserId);

      // Get current Firebase user
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null && isLoggedIn && userId != null && userId == currentUser.uid) {
        // User exists in Firebase Auth and is logged in, verify with Firestore
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
    debugPrint('[AuthService] _onAuthStateChanged called, user: ${user?.uid ?? "null"}, current status: $_status');
    
    if (user == null) {
      await _clearSession();
    } else if (_status != AuthStatus.authenticated) {
      // User signed in, verify their data
      // Note: This might be called from Firebase listener, but signIn also calls _verifyAndSetUserData
      // The method itself is idempotent, so it's safe to call multiple times
      debugPrint('[AuthService] _onAuthStateChanged: Verifying user data...');
      await _verifyAndSetUserData(user);
    } else {
      debugPrint('[AuthService] _onAuthStateChanged: Already authenticated, skipping verification');
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
      // Save user session data using LocalStorageService
      AppLogger.info('Saving user session to LocalStorage: ${userData.uid}');
      debugPrint('[AuthService] Saving login flag: true');
      await _localStorage.saveBool(AppConstants.prefIsLoggedIn, true);
      
      debugPrint('[AuthService] Saving userId: ${userData.uid}');
      await _localStorage.saveString(AppConstants.prefUserId, userData.uid);
      
      debugPrint('[AuthService] Saving userEmail: ${userData.email}');
      await _localStorage.saveString(AppConstants.prefUserEmail, userData.email);
      
      debugPrint('[AuthService] Saving userRole: ${userData.role}');
      await _localStorage.saveString(AppConstants.prefUserRole, userData.role);
      
      // Get Firebase auth token if available
      if (_firebaseUser != null) {
        final token = await _firebaseUser!.getIdToken();
        if (token != null) {
          debugPrint('[AuthService] Saving userToken: ${token.substring(0, 20)}...');
          await _localStorage.saveString(AppConstants.prefUserToken, token);
        }
      }
      
      // Verify the save was successful
      final savedLoginFlag = _localStorage.getBool(AppConstants.prefIsLoggedIn);
      final savedUserId = _localStorage.getString(AppConstants.prefUserId);
      debugPrint('[AuthService] Verification - Login flag saved: $savedLoginFlag');
      debugPrint('[AuthService] Verification - UserId saved: $savedUserId');
      
      AppLogger.info('User session saved successfully');
    } catch (e, stackTrace) {
      AppLogger.warning(
        'Error saving user session for user ${userData.uid}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> _clearSession() async {
    try {
      // Clear all authentication-related data from LocalStorageService
      await _localStorage.remove(AppConstants.prefIsLoggedIn);
      await _localStorage.remove(AppConstants.prefUserToken);
      await _localStorage.remove(AppConstants.prefUserId);
      await _localStorage.remove(AppConstants.prefUserEmail);
      await _localStorage.remove(AppConstants.prefUserRole);
      // Note: Device registration data is kept intentionally
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
      AppLogger.info('AuthService.signIn called for: $email');
      debugPrint('[AuthService] Starting signIn for: $email');
      _status = AuthStatus.loading;
      notifyListeners();

      // Sign in with Firebase Auth first
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        throw Exception('Login failed');
      }

      debugPrint('[AuthService] Firebase signIn successful, user: ${credential.user!.uid}');
      
      // Check approval status in Firestore users collection
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(credential.user!.uid)
            .get();

        if (!userDoc.exists) {
          // User document doesn't exist - allow login for backward compatibility
          debugPrint('[AuthService] User document not found in Firestore, allowing login (backward compatibility)');
        } else {
          final userData = userDoc.data();
          if (userData != null) {
            final isApproved = userData['isApproved'] ?? false;
            
            // For backward compatibility, if isApproved field doesn't exist, check 'active' field
            // Existing users without isApproved field should be treated as approved
            final isActive = userData['active'] ?? true;
            final shouldAllowLogin = isApproved || (userData['isApproved'] == null && isActive);
            
            if (!shouldAllowLogin) {
              // Sign out immediately - user is not approved
              try {
                await FirebaseAuth.instance.signOut();
              } catch (_) {
                // Ignore sign out errors
              }
              _status = AuthStatus.unauthenticated;
              notifyListeners();
              throw Exception('Your account is pending approval by admin. Please try again later.');
            }
            debugPrint('[AuthService] User approved in Firestore, proceeding with session setup');
          }
        }
      } catch (e) {
        // If error contains approval message, rethrow it
        if (e.toString().contains('pending approval')) {
          _status = AuthStatus.unauthenticated;
          notifyListeners();
          rethrow;
        }
        // For other Firestore errors, log but continue (don't block login for network issues)
        debugPrint('[AuthService] Firestore approval check error: $e, continuing with login');
      }
      
      // Ensure user data is verified and saved immediately
      // Don't rely solely on _onAuthStateChanged callback timing
      if (credential.user != null) {
        await _verifyAndSetUserData(credential.user!);
        debugPrint('[AuthService] User data verified and saved after signIn');
      }
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
