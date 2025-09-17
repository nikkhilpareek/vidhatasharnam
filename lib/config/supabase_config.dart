import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // Replace these with your actual Supabase credentials
  static const String supabaseUrl = 'https://poibpndaxlmzdbaddytc.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBvaWJwbmRheGxtemRiYWRkeXRjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgwNTIwNjgsImV4cCI6MjA3MzYyODA2OH0.V5dcsPb4zjfrZWH6hnS7rcpSOFwaNImSyp34H-RtytI';
  
  // Bucket name for visit photos
  static const String visitPhotosBucket = 'images';
  
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }
  
  static SupabaseClient get client => Supabase.instance.client;
}
