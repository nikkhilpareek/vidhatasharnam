class AppConstants {
  // Auth routes
  static const String navigateToSplashScreen = '/';
  static const String navigateToLoginScreen = '/login';
  static const String navigateToRegisterScreen = '/register';
  static const String navigateToHomeScreen = '/home';
  static const String navigateToAdminPanel = '/admin';

  // Visit routes
  static const String navigateToNewVisit = '/newVisit';
  static const String navigateToMyVisits = '/myVisits';
  
  // Profile routes
  static const String navigateToProfile = '/profile';
  
  // Community routes
  static const String navigateToCommunity = '/community';

  // About routes
  static const String navigateToAboutUs = '/about-us';

  // LocalStorage keys
  static const String prefIsLoggedIn = 'pref_is_logged_in';
  static const String prefUserToken = 'pref_user_token';
  static const String prefUserId = 'pref_user_id';
  static const String prefUserEmail = 'pref_user_email';
  static const String prefUserRole = 'pref_user_role';
  static const String prefDeviceRegistered = 'pref_device_registered';
  static const String prefRegisteredDeviceToken = 'pref_registered_device_token';
  static const String prefCommunityLastChecked = 'pref_community_last_checked';
  
  // Admin routes
  static const String navigateToApproveUsers = '/admin/approve-users';
}

