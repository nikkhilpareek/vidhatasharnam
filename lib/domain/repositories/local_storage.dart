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
    await _preferences?.setString(key, value);
  }
  // Save Data
  Future<void> saveInt(String key, int value) async {
    await _preferences?.setInt(key, value);
  }

  Future<void> saveBool(String key, bool value) async {
    await _preferences?.setBool(key, value);
  }

  // Retrieve Data
  String? getString(String key) {
    return _preferences?.getString(key);
  }
  int? getInt(String key) {
    return _preferences?.getInt(key);
  }

  bool? getBool(String key) {
    return _preferences?.getBool(key);
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
