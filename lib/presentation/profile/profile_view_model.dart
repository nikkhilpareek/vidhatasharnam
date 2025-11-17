import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/viewmodels/view_state.dart';
import '../../../core/logger/app_logger.dart';

class ProfileViewModel extends BaseViewModel {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _email = '';
  String _username = '';
  bool _isLoading = true;

  String get email => _email;
  String get username => _username;
  bool get isLoading => _isLoading;

  Future<void> loadProfile() async {
    setState(ViewState.loading);
    _isLoading = true;
    notifyListeners();

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      _email = user.email ?? '';

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data();
        _username = data?['username'] ?? '';
      }

      _isLoading = false;
      setState(ViewState.success);
    } catch (error, stackTrace) {
      AppLogger.error('Error loading profile', error: error, stackTrace: stackTrace);
      _isLoading = false;
      setState(ViewState.error);
      rethrow;
    }
  }

  Future<void> updateProfile(String newUsername) async {
    setState(ViewState.loading);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await _firestore.collection('users').doc(user.uid).update({
        'username': newUsername.trim(),
      });

      _username = newUsername.trim();
      setState(ViewState.success);
    } catch (error, stackTrace) {
      AppLogger.error('Error updating profile', error: error, stackTrace: stackTrace);
      setState(ViewState.error);
      rethrow;
    }
  }

  Future<void> changePassword(String newPassword) async {
    setState(ViewState.loading);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      if (newPassword.isEmpty) {
        throw Exception('Password cannot be empty');
      }

      await user.updatePassword(newPassword);
      setState(ViewState.success);
    } catch (error, stackTrace) {
      AppLogger.error('Error changing password', error: error, stackTrace: stackTrace);
      setState(ViewState.error);
      rethrow;
    }
  }
}

