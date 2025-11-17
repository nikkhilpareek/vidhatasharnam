import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/viewmodels/view_state.dart';
import '../../../core/logger/app_logger.dart';

class CommunityViewModel extends BaseViewModel {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isAdmin = false;
  bool _isLoading = true;

  bool get isAdmin => _isAdmin;
  bool get isLoading => _isLoading;

  Future<void> loadRole() async {
    setState(ViewState.loading);
    _isLoading = true;
    notifyListeners();

    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        _isLoading = false;
        setState(ViewState.error);
        return;
      }

      final snap = await _firestore.collection('users').doc(uid).get();
      if (snap.exists) {
        final data = snap.data();
        _isAdmin = (data?['role'] ?? '').toString().toLowerCase() == 'admin';
      }

      _isLoading = false;
      setState(ViewState.success);
    } catch (error, stackTrace) {
      AppLogger.error('Error loading role', error: error, stackTrace: stackTrace);
      _isLoading = false;
      setState(ViewState.error);
    }
  }
}

