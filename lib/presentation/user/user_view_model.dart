import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/logger/app_logger.dart';
import '../../core/viewmodels/base_view_model.dart';
import '../../core/viewmodels/view_state.dart';

/// ViewModel for managing user status and data with real-time Firestore listener
/// Follows MVVM pattern by extending BaseViewModel and using ChangeNotifier
class UserViewModel extends BaseViewModel with WidgetsBindingObserver {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;

  Map<String, dynamic>? _userData;
  bool _isActive = true; // Default true to avoid accidental block during initialization
  bool _isListening = false;
  String? _userName;

  Map<String, dynamic>? get userData => _userData;
  bool get isActive => _isActive;
  bool get isListening => _isListening;
  String? get userName => _userName;

  UserViewModel() {
    // Add lifecycle observer to handle app resume
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Reconnect listener when app resumes
      final user = _auth.currentUser;
      if (user != null && !_isListening) {
        AppLogger.info('[UserViewModel] App resumed, restarting listener');
        startUserListener();
      }
    }
  }

  /// Start listening to user document changes in Firestore
  /// Call this when user logs in or when app resumes
  Future<void> startUserListener() async {
    final user = _auth.currentUser;
    if (user == null) {
      AppLogger.warning('[UserViewModel] Cannot start: No authenticated user');
      return;
    }

    // Cancel existing subscription if any
    await _subscription?.cancel();
    _isListening = false;

    try {
      final docRef = _firestore.collection('users').doc(user.uid);
      
      AppLogger.info('[UserViewModel] Starting listener for user: ${user.uid}');

      _subscription = docRef.snapshots().listen(
        (snapshot) {
          _handleSnapshot(snapshot);
        },
        onError: (error) {
          AppLogger.error(
            '[UserViewModel] Snapshot listener error',
            error: error,
          );
          debugPrint('[UserViewModel] snapshot error: $error');
          // Don't crash app on error, but log it
        },
      );

      _isListening = true;

      // Also fetch initial data immediately
      final initialSnapshot = await docRef.get();
      if (initialSnapshot.exists) {
        _handleSnapshot(initialSnapshot);
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        '[UserViewModel] Error starting listener',
        error: e,
        stackTrace: stackTrace,
      );
      _isListening = false;
      setState(ViewState.error);
    }
  }

  void _handleSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    if (!snapshot.exists) {
      // Defensive: if no doc, treat user as deactivated for safety
      AppLogger.warning('[UserViewModel] User document does not exist');
      _userData = null;
      _isActive = false;
      _userName = null;
      notifyListeners();
      return;
    }

    final data = snapshot.data();
    if (data == null) {
      AppLogger.warning('[UserViewModel] User document data is null');
      _userData = null;
      _isActive = false;
      _userName = null;
      notifyListeners();
      return;
    }

    // Update user data with null-safe defaults
    _userData = data;
    
    // Extract username with null-safe defaults
    _userName = data['username'] as String? ?? 
               data['name'] as String? ?? 
               data['email']?.split('@')[0] as String? ?? 
               'User';
    
    // Check active status - support both 'active' field and 'status' field
    final activeField = data['active'] as bool?;
    final statusField = data['status'] as String?;
    
    // If 'active' field exists, use it; otherwise check 'status' field
    bool previousIsActive = _isActive;
    if (activeField != null) {
      _isActive = activeField;
    } else if (statusField != null) {
      _isActive = statusField.toLowerCase() == 'Active';
    } else {
      // Default to false if neither field is present (defensive)
      _isActive = false;
      AppLogger.warning('[UserViewModel] Neither active nor status field found, defaulting to inactive');
    }

    // Log status change
    if (previousIsActive != _isActive) {
      AppLogger.info('[UserViewModel] User status changed: active=$_isActive');
    }

    // Notify listeners for reactive UI updates
    notifyListeners();
  }

  /// Stop listening to user document changes
  /// Call this when user logs out or ViewModel is disposed
  Future<void> stopUserListener() async {
    AppLogger.info('[UserViewModel] Stopping listener');
    await _subscription?.cancel();
    _subscription = null;
    _isListening = false;
    _userData = null;
    _isActive = true; // Reset to default
    _userName = null;
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }
}

