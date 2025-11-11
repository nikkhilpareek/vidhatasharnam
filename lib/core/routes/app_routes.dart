import 'package:flutter/material.dart';

import 'package:vidhatasharnam/admin/admin_panel.dart';
import 'package:vidhatasharnam/presentation/auth/login/login_screen.dart';
import 'package:vidhatasharnam/presentation/auth/register/register_screen.dart';
import 'package:vidhatasharnam/presentation/home/my_home_page.dart';
import 'package:vidhatasharnam/presentation/splash/splash_screen.dart';
import 'package:vidhatasharnam/presentation/visits/new_visit.dart';
import 'package:vidhatasharnam/presentation/visits/my_visits_screen.dart';
import 'package:vidhatasharnam/presentation/profile/profile_page.dart';
import 'package:vidhatasharnam/presentation/community/community_screen.dart';
import 'package:vidhatasharnam/presentation/admin/approve_users_screen.dart';
import 'package:vidhatasharnam/presentation/about/about_us_screen.dart';
import 'package:vidhatasharnam/core/config/app_constants.dart';

class AppRoutes {
  static Map<String, WidgetBuilder> getRoutes() {
    return {
      // Auth routes
      AppConstants.navigateToSplashScreen: (context) => const SplashScreen(),
      AppConstants.navigateToLoginScreen: (context) => const LoginScreen(),
      AppConstants.navigateToRegisterScreen: (context) => const RegisterScreen(),
      AppConstants.navigateToHomeScreen: (context) => const MyHomePage(title: "Vidhatasharanam"),
      AppConstants.navigateToAdminPanel: (context) {
        // Get username from AuthService - this will be handled by SplashScreen navigation
        return const AdminPanel(username: 'Admin');
      },

      // Visit routes
      AppConstants.navigateToNewVisit: (context) => const NewVisitScreen(),
      AppConstants.navigateToMyVisits: (context) => const MyVisitsScreen(),

      // Profile routes
      AppConstants.navigateToProfile: (context) => const ProfilePage(),

      // Community routes
      AppConstants.navigateToCommunity: (context) => const CommunityScreen(),

      // About routes
      AppConstants.navigateToAboutUs: (context) => const AboutUsScreen(),

      // Admin routes
      AppConstants.navigateToApproveUsers: (context) => const ApproveUsersScreen(),
    };
  }
}

