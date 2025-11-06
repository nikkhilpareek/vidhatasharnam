import 'package:flutter/foundation.dart';

import '../logger/app_logger.dart';
import 'view_state.dart';

class BaseViewModel extends ChangeNotifier {
  ViewState _state = ViewState.idle;
  Object? _error;
  StackTrace? _stackTrace;

  ViewState get state => _state;
  bool get isLoading => _state == ViewState.loading;
  bool get hasError => _state == ViewState.error;
  Object? get error => _error;
  StackTrace? get stackTrace => _stackTrace;

  @protected
  void setState(ViewState newState) {
    if (_state == newState) return;
    _state = newState;
    notifyListeners();
  }

  @protected
  Future<T> execute<T>(Future<T> Function() action) async {
    setState(ViewState.loading);
    try {
      final result = await action();
      _error = null;
      _stackTrace = null;
      setState(ViewState.success);
      return result;
    } catch (error, stackTrace) {
      AppLogger.error('ViewModel execution error', error: error, stackTrace: stackTrace);
      _error = error;
      _stackTrace = stackTrace;
      setState(ViewState.error);
      rethrow;
    }
  }

  void reset() {
    _error = null;
    _stackTrace = null;
    setState(ViewState.idle);
  }
}

