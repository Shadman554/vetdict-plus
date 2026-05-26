import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import 'package:webview_flutter/webview_flutter.dart'; // Import WebView
import 'package:flutter/gestures.dart'; // Import gestures
import '../utils/constants.dart'; // Import constants
import '../providers/theme_provider.dart';

class LoginPage extends StatefulWidget {
  final bool isEmbedded;
  
  const LoginPage({
    super.key,
    this.isEmbedded = false,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  
  // Form controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoginMode = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // NEW METHOD: Handle navigation after successful login
  void _handleSuccessfulLogin() {
    // If the login page is embedded (e.g., in ProfilePage), we don't want to pop/navigate
    // The parent widget will rebuild automatically when auth state changes
    if (widget.isEmbedded) {
      return;
    }

    // Get the arguments passed to this page
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final returnRoute = args?['returnRoute'];
    
    if (returnRoute != null) {
      // Navigate to the specified return route
      Navigator.pushReplacementNamed(context, returnRoute);
    } else {
      // Default behavior - pop the login page to go back
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Directionality(
      textDirection: languageProvider.textDirection,
      child: Scaffold(
        backgroundColor: themeProvider.theme.scaffoldBackgroundColor,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: themeProvider.isDarkMode
                  ? [
                      themeProvider.theme.scaffoldBackgroundColor,
                      const Color(0xFF1E1E1E),
                    ]
                  : [
                      themeProvider.theme.scaffoldBackgroundColor,
                      const Color(0xFFE2E8F0),
                    ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Column(
                children: [
                  // App Logo and Title
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: themeProvider.isDarkMode
                          ? const Color(0xFF1A3460)
                          : const Color(0xFF556598),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: themeProvider.isDarkMode 
                              ? Colors.black.withValues(alpha: 0.3)
                              : Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/icon/logo1.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.medical_services,
                            size: 25,
                            color: themeProvider.theme.colorScheme.primary,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '+VET DICT',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600, // Changed from bold
                      color: themeProvider.theme.colorScheme.onSurface,
                      fontFamily: 'Inter',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  
                  // Welcome Text
                  Text(
                    _isLoginMode ? 'چوونە ژوورەوە' : 'دروستکردنی هەژمار',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600, // Changed from bold
                      color: themeProvider.theme.colorScheme.onSurface,
                      fontFamily: 'NRT',
                    ),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Login/Register Form
                  Expanded(
                    child: SingleChildScrollView(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Name field (only for registration)
                            if (!_isLoginMode) ...[
                              _buildTextField(
                                controller: _nameController,
                                label: 'ناو',
                                icon: Icons.person,
                                validator: (value) {
                                  if (!_isLoginMode && (value == null || value.isEmpty)) {
                                    return 'تکایە ناوت بنووسە';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                            ],
                            
                            // Email field
                            _buildTextField(
                              controller: _emailController,
                              label: 'ئیمەیڵ',
                              icon: Icons.email,
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'تکایە ئیمەیڵەکەت بنووسە';
                                }
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                  return 'ئیمەیڵەکە دروست نییە';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            
                            // Password field
                            _buildTextField(
                              controller: _passwordController,
                              label: 'وشەی نهێنی',
                              icon: Icons.lock,
                              obscureText: _obscurePassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                  color: themeProvider.theme.colorScheme.primary,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'تکایە وشەی نهێنی بنووسە';
                                }
                                if (value.length < 6) {
                                  return 'وشەی نهێنی دەبێت لانیکەم ٦ پیت بێت';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            
                            // Confirm Password field (only for registration)
                            if (!_isLoginMode) ...[
                              _buildTextField(
                                controller: _confirmPasswordController,
                                label: 'دووبارەکردنەوەی وشەی نهێنی',
                                icon: Icons.lock_outline,
                                obscureText: _obscureConfirmPassword,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                                    color: themeProvider.theme.colorScheme.primary,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirmPassword = !_obscureConfirmPassword;
                                    });
                                  },
                                ),
                                validator: (value) {
                                  if (!_isLoginMode && (value == null || value.isEmpty)) {
                                    return 'تکایە وشەی نهێنی دووبارە بکەرەوە';
                                  }
                                  if (!_isLoginMode && value != _passwordController.text) {
                                    return 'وشەی نهێنی یەکسان نین';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                            ] else
                              const SizedBox(height: 16),
                            
                            // Login/Register Button
                            Container(
                              width: double.infinity,
                              height: 56,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: authProvider.isLoading ? null : _handleSubmit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: themeProvider.isDarkMode
                                      ? const Color(0xFF1A3460)
                                      : themeProvider.theme.colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: authProvider.isLoading
                                    ? SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            themeProvider.theme.colorScheme.onPrimary,
                                          ),
                                        ),
                                      )
                                    : Text(
                                        _isLoginMode ? 'چوونە ژوورەوە' : 'دروستکردنی هەژمار',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Inter',
                                        ),
                                        textDirection: TextDirection.rtl,
                                      ),
                              ),
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // Toggle between login and register
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isLoginMode = !_isLoginMode;
                                  // Clear form when switching modes
                                  _formKey.currentState?.reset();
                                  _emailController.clear();
                                  _passwordController.clear();
                                  _nameController.clear();
                                  _confirmPasswordController.clear();
                                });
                              },
                              child: RichText(
                                textDirection: TextDirection.rtl,
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontFamily: 'Inter',
                                    color: themeProvider.theme.colorScheme.onSurface.withValues(alpha: 0.8),
                                  ),
                                  children: [
                                    TextSpan(
                                      text: _isLoginMode 
                                          ? 'هەژمارت نییە؟ ' 
                                          : 'هەژمارت هەیە؟ ',
                                    ),
                                    TextSpan(
                                      text: _isLoginMode 
                                          ? 'دروستی بکە' 
                                          : 'چوونە ژوورەوە',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // Divider with "یان" (Or)
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: themeProvider.theme.colorScheme.onSurface.withValues(alpha: 0.3),
                                    thickness: 1,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    'یان',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: themeProvider.theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                      fontFamily: 'NRT',
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: themeProvider.theme.colorScheme.onSurface.withValues(alpha: 0.3),
                                    thickness: 1,
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 10),
                            
                            // Google Sign-In Button
                            Container(
                              width: double.infinity,
                              height: 56,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: authProvider.isLoading ? null : _handleGoogleSignIn,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black87,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                      color: Colors.grey.withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: authProvider.isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Image.asset(
                                            'assets/Icons/google.png',
                                            height: 24,
                                            width: 24,
                                            errorBuilder: (context, error, stackTrace) {
                                              return const Icon(
                                                Icons.login,
                                                size: 24,
                                                color: Colors.black87,
                                              );
                                            },
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            _isLoginMode ? 'چوونە ژوورەوە بە گووگڵ' : 'دروستکردنی هەژمار بە گووگڵ',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              fontFamily: 'NRT',
                                              color: Colors.black87,
                                            ),
                                            textDirection: TextDirection.rtl,
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // Bottom section with terms
                            RichText(
                              textAlign: TextAlign.center,
                              textDirection: TextDirection.rtl,
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 12, // Slightly increased for better readability
                                  color: themeProvider.theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  fontFamily: 'NRT',
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'بە چوونە ژوورەوە، تۆ ڕێکەوتننامە و ',
                                  ),
                                  TextSpan(
                                    text: 'سیاسەتی تایبەتمەندی',
                                    style: TextStyle(
                                      color: themeProvider.theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        _showPrivacyPolicyBottomSheet(context);
                                      },
                                  ),
                                  const TextSpan(
                                    text: ' قبوڵ دەکەیت',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Build text field widget
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Directionality(
      textDirection: languageProvider.textDirection,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        textDirection: languageProvider.textDirection,
        style: TextStyle(
          color: themeProvider.theme.colorScheme.onSurface,
          fontFamily: 'Inter',
          fontSize: 16,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: themeProvider.theme.colorScheme.onSurface.withValues(alpha: 0.7),
            fontFamily: 'Inter',
          ),
          prefixIcon: Icon(
            icon,
            color: themeProvider.theme.colorScheme.primary,
          ),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: themeProvider.theme.cardTheme.color,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: themeProvider.theme.colorScheme.primary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: themeProvider.theme.colorScheme.primary,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Colors.red,
              width: 1,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Colors.red,
              width: 2,
            ),
          ),
          errorStyle: const TextStyle(
            color: Colors.red,
            fontFamily: 'Inter',
          ),
        ),
      ),
    );
  }

  // UPDATED: Handle Google Sign-In with navigation
  Future<void> _handleGoogleSignIn() async {
    if (kDebugMode) {
      debugPrint('🔴🔴🔴 GOOGLE SIGN-IN BUTTON PRESSED! 🔴🔴🔴');
      debugPrint('📱 Device Info: Android');
      debugPrint('⏰ Timestamp: ${DateTime.now()}');
    }
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    Map<String, dynamic> result;
    
    try {
      if (_isLoginMode) {
        if (kDebugMode) {
          debugPrint('🔵🔵🔵 CALLING authProvider.signInWithGoogle() for LOGIN... 🔵🔵🔵');
        }
        result = await authProvider.signInWithGoogle();
      } else {
        if (kDebugMode) {
          debugPrint('🔵🔵🔵 CALLING authProvider.signUpWithGoogle() for REGISTRATION... 🔵🔵🔵');
        }
        result = await authProvider.signUpWithGoogle();
      }
      if (kDebugMode) {
        debugPrint('🟡🟡🟡 GOOGLE RESULT: $result 🟡🟡🟡');
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌❌❌ CRITICAL ERROR IN _handleGoogleSignIn: $error');
        debugPrint('📋 Stack trace: $stackTrace');
      }
      
      if (mounted) {
        _showErrorSnackBar('تکایە پشکنینی هێڵی ئینتەرنێت بکە و دووبارە هەوڵ بدەوە');
      }
      return;
    }
    
    if (result['success'] == true) {
      // Success - user logged in successfully
      if (kDebugMode) {
        debugPrint('✅ Google Sign-In successful!');
      }
      
      // Show success message
      final userName = authProvider.userDisplayName;
      _showSuccessMessage(userName);
      
      // Handle navigation after successful login
      if (mounted) {
        _handleSuccessfulLogin();
      }
      
    } else {
      // Handle different error types
      final errorType = result['error_type'] ?? '';
      final message = result['message'] ?? 'Unknown error occurred';
      final email = result['email'] ?? '';
      
      if (kDebugMode) {
        debugPrint('❌ Google Sign-In failed: $errorType - $message');
      }
      
      if (errorType == 'email_exists') {
        // Show dialog explaining the account exists with regular login
        _showAccountExistsDialog(email, message);
      } else if (errorType == 'username_exists') {
        // Show error about username availability
        _showErrorSnackBar(message);
      } else if (errorType == 'authentication_failed') {
        // Show general authentication error
        _showErrorSnackBar('تکایە دووبارە هەوڵ بدەوە یان بە شێوەیەکی ئاسایی بچۆ ژوورەوە.');
      } else {
        // Show the specific error message
        _showErrorSnackBar(message);
      }
    }
  }

  // Show account exists dialog
  void _showAccountExistsDialog(String email, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final languageProvider = Provider.of<LanguageProvider>(context);
        final themeProvider = Provider.of<ThemeProvider>(context);
        
        return Directionality(
          textDirection: languageProvider.textDirection,
          child: AlertDialog(
            backgroundColor: themeProvider.theme.dialogTheme.backgroundColor ?? themeProvider.theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.account_circle_outlined, 
                  color: themeProvider.theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text(
                      'هەژماری ئاسایی هەیە',
                      style: TextStyle(
                        fontFamily: 'NRT',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: themeProvider.theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'NRT',
                      color: themeProvider.theme.colorScheme.onSurface,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: themeProvider.theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: themeProvider.theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.email,
                        color: themeProvider.theme.colorScheme.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            email,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: themeProvider.theme.colorScheme.primary,
                              fontFamily: 'Inter',
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    'تکایە بە وشەی نهێنی خۆت بچۆ ژوورەوە.',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'NRT',
                      color: themeProvider.theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: TextButton.styleFrom(
                  foregroundColor: themeProvider.theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text(
                  'پاشگەزبوونەوە',
                  style: TextStyle(
                    fontFamily: 'NRT',
                    fontSize: 14,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _goToRegularLogin(email);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeProvider.isDarkMode
                      ? const Color(0xFF1A3460)
                      : themeProvider.theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.login, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'چوونە ژوورەوە',
                      style: TextStyle(
                        fontFamily: 'NRT',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPrivacyPolicyBottomSheet(BuildContext context) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..loadRequest(Uri.parse(AppConstants.privacyPolicyUrl));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final themeProvider = Provider.of<ThemeProvider>(context);

        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: themeProvider.theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: themeProvider.isDarkMode
                      ? Colors.grey[700]
                      : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'سیاسەتی تایبەتمەندی',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.theme.colorScheme.onSurface,
                    fontFamily: 'NRT',
                  ),
                ),
              ),
              Expanded(
                child: WebViewWidget(
                  controller: controller,
                  gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                    Factory<VerticalDragGestureRecognizer>(
                      () => VerticalDragGestureRecognizer(),
                    ),
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontFamily: 'NRT',
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          action: SnackBarAction(
            label: 'باشە',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  // Pre-fill email and switch to login mode
  void _goToRegularLogin(String email) {
    setState(() {
      _emailController.text = email;
      _isLoginMode = true;
      _passwordController.clear();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'ئیمەیڵەکەت پڕکراوەتەوە. تکایە وشەی نهێنیت بنووسە.',
                style: TextStyle(
                  fontFamily: 'NRT',
                ),
                textDirection: TextDirection.rtl,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF4A7EB5),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
    
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        FocusScope.of(context).requestFocus(FocusNode());
      }
    });
  }

  // Show success message for successful Google Sign-In
  void _showSuccessMessage(String userName) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'بەخێربێیت $userName!',
                style: const TextStyle(fontFamily: 'NRT'),
                textDirection: TextDirection.rtl,
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  // UPDATED: Handle form submission for regular login/register with navigation
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    Map<String, dynamic> result;

    if (_isLoginMode) {
      // Login
      result = await authProvider.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } else {
      // Register
      result = await authProvider.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        passwordConfirmation: _confirmPasswordController.text,
      );
    }

    if (mounted) {
      if (result['success'] == true) {
        // Success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result['message'] ?? (_isLoginMode ? 'بە سەرکەوتوویی چوویتە ژوورەوە' : 'هەژمار بە سەرکەوتوویی دروست کرا'),
                    style: const TextStyle(
                      fontFamily: 'NRT',
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        
        // ADDED: Handle navigation after successful login
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _handleSuccessfulLogin();
          }
        });
        
      } else {
        // Error
        String errorMessage = result['message'] ?? 'هەڵەیەک ڕوویدا';
        
        // Handle validation errors
        if (result['errors'] != null && result['errors'] is Map) {
          final errors = result['errors'] as Map<String, dynamic>;
          final errorMessages = <String>[];
          
          errors.forEach((key, value) {
            if (value is List) {
              errorMessages.addAll(value.cast<String>());
            } else if (value is String) {
              errorMessages.add(value);
            }
          });
          
          if (errorMessages.isNotEmpty) {
            errorMessage = errorMessages.join('\n');
          }
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    errorMessage,
                    style: const TextStyle(
                      fontFamily: 'NRT',
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }
}