import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static LocalStorageService? _instance;
  static SharedPreferences? _preferences;

  // Singleton Pattern
  LocalStorageService._internal();

  factory LocalStorageService() {
    return _instance ??= LocalStorageService._internal();
  }

  // Initialize SharedPreferences
  static Future<void> init() async {
    _preferences = await SharedPreferences.getInstance();
  }

  // Save Data
  Future<void> saveString(String key, String value) async {
    debugPrint('[LocalStorage] Saving string - Key: $key, Value: ${value.length > 50 ? value.substring(0, 50) + "..." : value}');
    await _preferences?.setString(key, value);
    final saved = _preferences?.getString(key);
    debugPrint('[LocalStorage] Verified save - Key: $key, Saved: ${saved != null ? "SUCCESS" : "FAILED"}');
  }
  
  // Save Data
  Future<void> saveInt(String key, int value) async {
    debugPrint('[LocalStorage] Saving int - Key: $key, Value: $value');
    await _preferences?.setInt(key, value);
  }

  Future<void> saveBool(String key, bool value) async {
    debugPrint('[LocalStorage] Saving bool - Key: $key, Value: $value');
    await _preferences?.setBool(key, value);
    final saved = _preferences?.getBool(key);
    debugPrint('[LocalStorage] Verified save - Key: $key, Saved: $saved');
  }

  // Retrieve Data
  String? getString(String key) {
    final value = _preferences?.getString(key);
    debugPrint('[LocalStorage] Getting string - Key: $key, Value: ${value != null ? (value.length > 50 ? value.substring(0, 50) + "..." : value) : "NULL"}');
    return value;
  }
  
  int? getInt(String key) {
    final value = _preferences?.getInt(key);
    debugPrint('[LocalStorage] Getting int - Key: $key, Value: $value');
    return value;
  }

  bool? getBool(String key) {
    final value = _preferences?.getBool(key);
    debugPrint('[LocalStorage] Getting bool - Key: $key, Value: $value');
    return value;
  }

  // Remove Data
  Future<void> remove(String key) async {
    await _preferences?.remove(key);
  }

  // Clear All Data
  Future<void> clearAll() async {
    await _preferences?.clear();
  }
}
