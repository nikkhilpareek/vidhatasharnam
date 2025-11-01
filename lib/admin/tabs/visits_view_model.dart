import 'package:flutter/foundation.dart';

class VisitsViewModel extends ChangeNotifier {
  String _statusFilter = 'All';
  String _searchQuery = '';

  String get statusFilter => _statusFilter;
  String get searchQuery => _searchQuery;

  void setStatusFilter(String filter) {
    if (_statusFilter == filter) return;
    _statusFilter = filter;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    final normalized = query.trim().toLowerCase();
    if (_searchQuery == normalized) return;
    _searchQuery = normalized;
    notifyListeners();
  }
}


