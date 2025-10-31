import 'package:cloud_firestore/cloud_firestore.dart';

/// One-time script to clean up existing users with adminRequestedPasswordChange flag
/// Run this once to fix users who are currently locked out
/// 
/// To run: Add this to your main.dart temporarily or create a button in admin panel
Future<void> cleanupPasswordResetFlags() async {
  print('🔧 Starting cleanup of password reset flags...');
  
  try {
    final firestore = FirebaseFirestore.instance;
    
    // Find all users with the blocking flag set
    final querySnapshot = await firestore
        .collection('users')
        .where('adminRequestedPasswordChange', isEqualTo: true)
        .get();
    
    print('📊 Found ${querySnapshot.docs.length} users with blocking flag');
    
    if (querySnapshot.docs.isEmpty) {
      print('✅ No users need cleanup!');
      return;
    }
    
    // Use batch for efficient updates
    final batch = firestore.batch();
    int count = 0;
    
    for (final doc in querySnapshot.docs) {
      final userData = doc.data();
      final email = userData['email'] ?? 'unknown';
      
      print('  → Cleaning up user: $email (${doc.id})');
      
      // Remove the blocking flag and add audit trail
      batch.update(doc.reference, {
        'adminRequestedPasswordChange': FieldValue.delete(), // Remove the field
        'passwordResetFlagClearedAt': FieldValue.serverTimestamp(),
        'passwordResetFlagCleanupNote': 'Automatically cleaned up - flag was blocking login',
      });
      
      count++;
      
      // Firestore batch limit is 500 operations
      if (count >= 500) {
        await batch.commit();
        print('  ✅ Committed batch of $count updates');
        count = 0;
      }
    }
    
    // Commit remaining updates
    if (count > 0) {
      await batch.commit();
      print('  ✅ Committed final batch of $count updates');
    }
    
    print('✅ Cleanup complete! ${querySnapshot.docs.length} users fixed.');
    print('ℹ️  Users should now be able to login with their new passwords.');
    
  } catch (e) {
    print('❌ Error during cleanup: $e');
    rethrow;
  }
}

/// Alternative: Clean up a specific user by email
Future<void> cleanupUserPasswordResetFlag(String email) async {
  try {
    final firestore = FirebaseFirestore.instance;
    
    // Find user by email
    final querySnapshot = await firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    
    if (querySnapshot.docs.isEmpty) {
      print('❌ User not found: $email');
      return;
    }
    
    final doc = querySnapshot.docs.first;
    final userData = doc.data();
    
    if (userData['adminRequestedPasswordChange'] == true) {
      await doc.reference.update({
        'adminRequestedPasswordChange': FieldValue.delete(),
        'passwordResetFlagClearedAt': FieldValue.serverTimestamp(),
        'passwordResetFlagCleanupNote': 'Manually cleaned up by admin',
      });
      
      print('✅ Cleaned up password reset flag for: $email');
    } else {
      print('ℹ️  User $email does not have blocking flag set');
    }
    
  } catch (e) {
    print('❌ Error cleaning up user: $e');
    rethrow;
  }
}

/// Check if any users are currently blocked
Future<void> checkBlockedUsers() async {
  try {
    final firestore = FirebaseFirestore.instance;
    
    final snapshot = await firestore
        .collection('users')
        .where('adminRequestedPasswordChange', isEqualTo: true)
        .get();
    
    print('📊 Users currently blocked by password reset flag: ${snapshot.docs.length}');
    
    for (final doc in snapshot.docs) {
      final data = doc.data();
      print('  - ${data['email']} (UID: ${doc.id})');
      print('    Reset requested at: ${data['passwordResetSentAt']}');
      print('    Requested by: ${data['passwordResetSentBy']}');
    }
    
  } catch (e) {
    print('❌ Error checking blocked users: $e');
  }
}
