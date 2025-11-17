import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/viewmodels/view_state.dart';

class VisitsTabViewModel extends BaseViewModel {
  String _visitStatusFilter = 'All';
  String _visitSearchQuery = '';
  Map<String, int> _statusChipCounts = {
    'Pending': 0,
    'Approved': 0,
    'Rejected': 0,
  };

  String get visitStatusFilter => _visitStatusFilter;
  String get visitSearchQuery => _visitSearchQuery;
  Map<String, int> get statusChipCounts => _statusChipCounts;

  void setStatusFilter(String filter) {
    _visitStatusFilter = filter;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _visitSearchQuery = query.trim().toLowerCase();
    notifyListeners();
  }

  void updateStatusCounts(Map<String, int> counts) {
    _statusChipCounts = counts;
    notifyListeners();
  }
}

