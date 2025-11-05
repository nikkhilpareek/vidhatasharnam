import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class SupabaseConfig {
  // Replace these with your actual Supabase credentials
  static const String supabaseUrl = 'https://poibpndaxlmzdbaddytc.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBvaWJwbmRheGxtemRiYWRkeXRjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgwNTIwNjgsImV4cCI6MjA3MzYyODA2OH0.V5dcsPb4zjfrZWH6hnS7rcpSOFwaNImSyp34H-RtytI';
  
  // Bucket name for visit photos
  static const String visitPhotosBucket = 'images';
  
  static bool _isInitialized = false;
  
  static Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('⚠️ Supabase already initialized, skipping');
      return;
    }
    
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      _isInitialized = true;
      debugPrint('✅ Supabase initialized successfully');
    } catch (e) {
      debugPrint('❌ Supabase initialization failed: $e');
      rethrow;
    }
  }
  
  /// Get Supabase client with defensive guard
  /// Throws exception if Supabase is not initialized
  static SupabaseClient get client {
    if (!_isInitialized) {
      try {
        // Try to access instance - may throw if not initialized
        final _ = Supabase.instance;
        // If we can access instance, mark as initialized
        _isInitialized = true;
      } catch (e) {
        throw Exception('Supabase not initialized. Call SupabaseConfig.initialize() first. Error: $e');
      }
    }
    
    try {
      return Supabase.instance.client;
    } catch (e) {
      throw Exception('Failed to access Supabase client. Ensure Supabase.initialize() was called. Error: $e');
    }
  }
  
  /// Check if Supabase is initialized
  static bool get isInitialized {
    try {
      if (_isInitialized) return true;
      // Try to access instance to verify initialization
      final _ = Supabase.instance;
      _isInitialized = true;
      return true;
    } catch (e) {
      return false;
    }
  }
}
