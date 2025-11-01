import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminPanelViewModel extends ChangeNotifier {
  bool _isCreatingUser = false;
  bool get isCreatingUser => _isCreatingUser;

  void _setCreating(bool creating) {
    if (_isCreatingUser == creating) return;
    _isCreatingUser = creating;
    notifyListeners();
  }

  Future<void> createUser({
    required String username,
    required String email,
    required String password,
    String? phoneNumber,
  }) async {
    if (_isCreatingUser) return;
    _setCreating(true);
    try {
      FirebaseApp secondaryApp;
      try {
        secondaryApp = Firebase.app('Secondary');
      } catch (_) {
        secondaryApp = await Firebase.initializeApp(
          name: 'Secondary',
          options: Firebase.app().options,
        );
      }

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final UserCredential newUserCred = await secondaryAuth
          .createUserWithEmailAndPassword(email: email, password: password);

      final newUid = newUserCred.user!.uid;

      await FirebaseFirestore.instance.collection('users').doc(newUid).set({
        'username': username,
        'email': email,
        'phone': phoneNumber,
        'role': 'User',
        'active': true,
        'status': 'Active',
        'createdAt': FieldValue.serverTimestamp(),
      });

      try {
        await secondaryAuth.signOut();
        await secondaryApp.delete();
      } catch (_) {}
    } finally {
      _setCreating(false);
    }
  }
}


