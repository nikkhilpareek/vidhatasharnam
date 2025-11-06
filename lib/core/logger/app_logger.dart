import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

enum _LogLevel { debug, info, warning, error, critical }

class AppLogger {
  AppLogger._();

  static const String _logName = 'Vidhatasharnam';

  static void debug(String message, {Object? error, StackTrace? stackTrace}) {
    _log(_LogLevel.debug, message, error: error, stackTrace: stackTrace);
  }

  static void info(String message, {Object? error, StackTrace? stackTrace}) {
    _log(_LogLevel.info, message, error: error, stackTrace: stackTrace);
  }

  static void warning(String message, {Object? error, StackTrace? stackTrace}) {
    _log(_LogLevel.warning, message, error: error, stackTrace: stackTrace);
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    _log(_LogLevel.error, message, error: error, stackTrace: stackTrace);
  }

  static void critical(String message, {Object? error, StackTrace? stackTrace}) {
    _log(_LogLevel.critical, message, error: error, stackTrace: stackTrace);
  }

  static void _log(
    _LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final formattedMessage = '[${level.name.toUpperCase()}] $message';

    developer.log(
      formattedMessage,
      name: _logName,
      error: error,
      stackTrace: stackTrace,
      level: _mapLevel(level),
    );

    if (!kReleaseMode) {
      final buffer = StringBuffer(formattedMessage);
      if (error != null) {
        buffer.write('\nERROR: $error');
      }
      if (stackTrace != null) {
        buffer.write('\nSTACKTRACE: $stackTrace');
      }
      debugPrint(buffer.toString());
    }
  }

  static int _mapLevel(_LogLevel level) {
    switch (level) {
      case _LogLevel.debug:
        return 500;
      case _LogLevel.info:
        return 800;
      case _LogLevel.warning:
        return 900;
      case _LogLevel.error:
        return 1000;
      case _LogLevel.critical:
        return 1200;
    }
  }
}

