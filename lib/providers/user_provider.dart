import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/logger/app_logger.dart';

/// Provider that monitors user active status in real-time via Firestore listener
/// Updates when admin toggles user active/deactivated status
class UserProvider extends ChangeNotifier with WidgetsBindingObserver {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  Map<String, dynamic>? _userData;
  bool _isActive = true; // Default true to avoid accidental block during initialization
  bool _isListening = false;

  Map<String, dynamic>? get userData => _userData;
  bool get isActive => _isActive;
  bool get isListening => _isListening;

  UserProvider() {
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
        AppLogger.info('[UserProvider] App resumed, restarting listener');
        start();
      }
    }
  }

  /// Start listening to user document changes in Firestore
  /// Call this when user logs in
  Future<void> start() async {
    final user = _auth.currentUser;
    if (user == null) {
      AppLogger.warning('[UserProvider] Cannot start: No authenticated user');
      return;
    }

    // Cancel existing subscription if any
    await _subscription?.cancel();
    _isListening = false;

    try {
      final docRef = _db.collection('users').doc(user.uid);
      
      AppLogger.info('[UserProvider] Starting listener for user: ${user.uid}');

      _subscription = docRef.snapshots().listen(
        (snapshot) {
          _handleSnapshot(snapshot);
        },
        onError: (error) {
          AppLogger.error(
            '[UserProvider] Snapshot listener error',
            error: error,
          );
          // Don't crash app on error, but log it
          debugPrint('[UserProvider] snapshot error: $error');
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
        '[UserProvider] Error starting listener',
        error: e,
        stackTrace: stackTrace,
      );
      _isListening = false;
    }
  }

  void _handleSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    if (!snapshot.exists) {
      // Defensive: if no doc, treat user as deactivated for safety
      AppLogger.warning('[UserProvider] User document does not exist');
      _userData = null;
      _isActive = false;
      notifyListeners();
      return;
    }

    final data = snapshot.data();
    if (data == null) {
      AppLogger.warning('[UserProvider] User document data is null');
      _userData = null;
      _isActive = false;
      notifyListeners();
      return;
    }

    // Update user data with null-safe defaults
    _userData = data;
    
    // Check active status - support both 'active' field and 'status' field
    final activeField = data['active'] as bool?;
    final statusField = data['status'] as String?;
    
    // If 'active' field exists, use it; otherwise check 'status' field
    if (activeField != null) {
      _isActive = activeField;
    } else if (statusField != null) {
      _isActive = statusField.toLowerCase() == 'active';
    } else {
      // Default to false if neither field is present (defensive)
      _isActive = false;
      AppLogger.warning('[UserProvider] Neither active nor status field found, defaulting to inactive');
    }

    AppLogger.info('[UserProvider] User status updated - active: $_isActive');
    notifyListeners();
  }

  /// Stop listening to user document changes
  /// Call this when user logs out or provider is disposed
  Future<void> stop() async {
    AppLogger.info('[UserProvider] Stopping listener');
    await _subscription?.cancel();
    _subscription = null;
    _isListening = false;
    _userData = null;
    _isActive = true; // Reset to default
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }
}

