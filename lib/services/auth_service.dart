import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

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

  AuthService._() {
    _init();
  }

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

  Future<void> _init() async {
    _status = AuthStatus.loading;
    notifyListeners();

    // Listen to Firebase auth state changes
    FirebaseAuth.instance.authStateChanges().listen(_onAuthStateChanged);

    // Check for existing session
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
    } catch (e) {
      print('Error checking existing session: $e');
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

    } catch (e) {
      print('Error verifying user data: $e');
      await _clearSession();
      throw e;
    }
  }

  Future<void> _saveUserSession(UserData userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastLoginKey, DateTime.now().toIso8601String());
      await prefs.setString(_userDataKey, userData.uid); // Just store reference
    } catch (e) {
      print('Error saving user session: $e');
    }
  }

  Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastLoginKey);
      await prefs.remove(_userDataKey);
    } catch (e) {
      print('Error clearing session: $e');
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
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      await _clearSession();
    } catch (e) {
      print('Error signing out: $e');
      // Force clear session even if Firebase signOut fails
      await _clearSession();
    }
  }

  Future<void> refreshUserData() async {
    if (_firebaseUser == null) return;
    
    try {
      await _verifyAndSetUserData(_firebaseUser!);
    } catch (e) {
      print('Error refreshing user data: $e');
      // If refresh fails, sign out user
      await signOut();
    }
  }
}
