import '../../../core/viewmodels/base_view_model.dart';
import '../../../core/viewmodels/view_state.dart';

class TotalVisitsViewModel extends BaseViewModel {
  String _selectedFilter = 'All';

  String get selectedFilter => _selectedFilter;

  void setFilter(String filter) {
    _selectedFilter = filter;
    notifyListeners();
  }
}

