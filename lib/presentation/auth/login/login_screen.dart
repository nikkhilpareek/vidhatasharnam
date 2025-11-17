import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:vidhatasharnam/core/theme/app_theme.dart';
import 'package:vidhatasharnam/core/config/app_constants.dart';
import 'package:vidhatasharnam/data/datasources/auth/auth_service.dart';
import 'package:vidhatasharnam/domain/repositories/local_storage.dart';
import 'package:vidhatasharnam/presentation/auth/login/login_view_model.dart';
import 'package:vidhatasharnam/presentation/user/user_view_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isPasswordVisible = false;
  bool _isLoggingIn = false; // Local loading state that persists until navigation

  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    // Set local loading state to true - this will persist until navigation
    setState(() {
      _isLoggingIn = true;
    });

    try {
      final loginViewModel = context.read<LoginViewModel>();
      final success = await loginViewModel.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (success) {
        // Wait for AuthService to update and save login state
        final authService = AuthService.instance;
        debugPrint('[LoginScreen] Waiting for AuthService to be authenticated...');
        
        // Wait for authentication with timeout
        int attempts = 0;
        const maxAttempts = 100; // 5 seconds max wait
        while ((!authService.isInitialized || !authService.isAuthenticated) && attempts < maxAttempts) {
          await Future.delayed(const Duration(milliseconds: 50));
          attempts++;
        }

        if (!authService.isAuthenticated) {
          debugPrint('[LoginScreen] WARNING: AuthService not authenticated after wait');
          if (mounted) {
            setState(() {
              _isLoggingIn = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Login successful but authentication state not ready. Please try again.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        // Verify session was saved to LocalStorage
        final localStorage = LocalStorageService();
        final isLoggedInSaved = localStorage.getBool(AppConstants.prefIsLoggedIn) ?? false;
        debugPrint('[LoginScreen] Login flag saved to LocalStorage: $isLoggedInSaved');
        
        if (!isLoggedInSaved) {
          debugPrint('[LoginScreen] ERROR: Login flag not saved! Waiting a bit more...');
          await Future.delayed(const Duration(milliseconds: 200));
          final retryCheck = localStorage.getBool(AppConstants.prefIsLoggedIn) ?? false;
          debugPrint('[LoginScreen] Retry check result: $retryCheck');
          
          if (!retryCheck) {
            debugPrint('[LoginScreen] CRITICAL: Login flag still not saved after retry!');
          }
        }

        // AuthService has already saved login state via LocalStorageService
        // Start UserViewModel listener for real-time status updates
        try {
          final userViewModel = context.read<UserViewModel>();
          await userViewModel.startUserListener();
          debugPrint('[LoginScreen] UserViewModel started for real-time status monitoring');
        } catch (e) {
          debugPrint('[LoginScreen] Warning: Failed to start UserViewModel: $e');
          // Continue with navigation even if UserViewModel fails
        }

        // Now navigate based on user role
        final userData = authService.userData!;
        debugPrint('[LoginScreen] Navigating to dashboard for role: ${userData.role}');
        
        // Keep loading state active during navigation
        // Navigation will replace this screen, so we don't need to reset _isLoggingIn
        if (userData.role == "admin") {
          Navigator.of(context).pushReplacementNamed(
            AppConstants.navigateToAdminPanel,
            arguments: userData.displayName,
          );
        } else {
          Navigator.of(context).pushReplacementNamed(
            AppConstants.navigateToHomeScreen,
          );
        }
      } else {
        // Login failed, reset loading state
        if (mounted) {
          setState(() {
            _isLoggingIn = false;
          });
          final errorMessage =
              loginViewModel.errorMessage ?? 'Unable to sign in. Please try again.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Handle any unexpected errors
      if (mounted) {
        setState(() {
          _isLoggingIn = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModelLoading = context.select<LoginViewModel, bool>((vm) => vm.isLoading);
    // Use local loading state OR viewModel loading state - show loading if either is true
    final isLoading = _isLoggingIn || viewModelLoading;

    return PopScope(
      canPop: false, // Prevent back button navigation
      child: Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),

              // Logo + App Name
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.business,
                              size: 60,
                              color: AppTheme.iconColor,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'VIDHATASHARANAM',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Turning land into legacy',
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.8),
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),    Text(
                      'New users can register directly to get started — open for everyone.',
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.8),
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Welcome back! Please sign in to continue.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // Login Form
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Email
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Password
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: _togglePasswordVisibility,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty
                              ? 'Please enter your password'
                              : null,
                    ),
                    const SizedBox(height: 32),

                    // Login button
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: isLoading
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Signing In...',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              )
                            : const Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Register link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        TextButton(
                          onPressed: isLoading
                              ? null
                              : () {
                                  Navigator.of(context).pushNamed(
                                    AppConstants.navigateToRegisterScreen,
                                  );
                                },
                          child: const Text(
                            'Register',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

