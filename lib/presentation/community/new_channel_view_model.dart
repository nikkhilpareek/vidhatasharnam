import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/viewmodels/view_state.dart';
import '../../../core/logger/app_logger.dart';

class NewChannelViewModel extends BaseViewModel {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Set<String> _selectedMembers = {};
  String _searchQuery = '';
  bool _isCreating = false;

  Set<String> get selectedMembers => _selectedMembers;
  String get searchQuery => _searchQuery;
  bool get isCreating => _isCreating;

  void setSearchQuery(String query) {
    _searchQuery = query.trim().toLowerCase();
    notifyListeners();
  }

  void toggleMember(String userId) {
    if (_selectedMembers.contains(userId)) {
      _selectedMembers.remove(userId);
    } else {
      _selectedMembers.add(userId);
    }
    notifyListeners();
  }

  Future<bool> createChannel(String channelName, String adminUid) async {
    if (channelName.isEmpty || _selectedMembers.isEmpty) {
      return false;
    }

    setState(ViewState.loading);
    _isCreating = true;
    notifyListeners();

    try {
      final members = _selectedMembers.toSet();
      members.add(adminUid);

      await _firestore.collection('channels').add({
        'name': channelName,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': adminUid,
        'members': members.toList(),
        'admins': [adminUid],
        'lastMessagePreview': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'broadcast': true,
      });

      _isCreating = false;
      setState(ViewState.success);
      return true;
    } catch (error, stackTrace) {
      AppLogger.error('Error creating channel', error: error, stackTrace: stackTrace);
      _isCreating = false;
      setState(ViewState.error);
      return false;
    }
  }

  void clearSelection() {
    _selectedMembers.clear();
    _searchQuery = '';
    notifyListeners();
  }
}

