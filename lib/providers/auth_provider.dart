import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';
import '../services/onesignal_service.dart';
import '../services/secure_storage_service.dart';
import '../config/app_config.dart';

class AuthProvider with ChangeNotifier {
  Map<String, dynamic>? _user;
  bool _isSignedIn = false;
  bool _isLoading = false;
  String? _token;
  String? _refreshToken;

  // Secure storage instance
  final _secureStorage = SecureStorageService();

  // Google Sign-In instance — only initialized on native platforms or when
  // a web client ID is configured. The web GSI library throws immediately
  // if clientId is empty, so we skip construction on web without a key.
  final GoogleSignIn? _googleSignIn = (kIsWeb && AppConfig.googleClientIdIOS.isEmpty)
      ? null
      : GoogleSignIn(
          clientId: AppConfig.googleClientIdIOS,
          serverClientId: AppConfig.googleServerClientId,
          scopes: ['email', 'profile'],
        );

  Map<String, dynamic>? get user => _user;
  bool get isSignedIn => _isSignedIn;
  bool get isLoading => _isLoading;
  String? get token => _token;
  GoogleSignIn? get googleSignIn => _googleSignIn;

  // API Base URL from config — use relative path on web so calls go through the local proxy
  static String get baseUrl => kIsWeb ? '' : AppConfig.apiBaseUrl;

  AuthProvider() {
    _checkSignInStatus();
  }

  // Check if user is already signed in
  Future<void> _checkSignInStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Get tokens from secure storage
      final token = await _secureStorage.getToken();
      final refreshToken = await _secureStorage.getRefreshToken();
      
      // Load cached user data from SharedPreferences (non-sensitive data)
      final prefs = await SharedPreferences.getInstance();
      final cachedUserJson = prefs.getString('userData');
      if (cachedUserJson != null) {
        try {
          _user = jsonDecode(cachedUserJson);
        } catch (e) {
          // If decoding fails, clear corrupted data
          await prefs.remove('userData');
        }
      }
      
      if (token != null) {
        _token = token;
        _refreshToken = refreshToken; // Can be null
        
        // If we have cached user data, trust the token and stay signed in
        if (_user != null) {
          _isSignedIn = true;
          
          // Try to get current user info in background
          // Note: _getCurrentUser() now handles 401 errors by auto-logging out
          _getCurrentUser().then((success) {
            if (!success && _isSignedIn) {
              // Only try refresh if still signed in (not logged out by 401)

              // Try to refresh token in background if available
              if (_refreshToken != null) {
                _refreshAccessToken().then((refreshSuccess) {
                  if (refreshSuccess && _isSignedIn) {
                    _getCurrentUser();
                  }
                  // Don't logout on refresh failure - keep cached session
                });
              }
            }
          });
        } else {
          // No cached user data, must validate token
          final success = await _getCurrentUser();
          if (success) {
            _isSignedIn = true;
          } else {
            // Try to refresh token only if refresh token exists
            if (_refreshToken != null) {
              final refreshSuccess = await _refreshAccessToken();
              if (refreshSuccess) {
                _isSignedIn = true;
                await _getCurrentUser();
              } else {
                // Clear invalid tokens
                await _clearTokens();
              }
            } else {
              // No refresh token, clear tokens
              await _clearTokens();
            }
          }
        }
      }
    } catch (e) {
      _isSignedIn = false;
      await _clearTokens();
    }

    // Set OneSignal user identification if user is signed in
    if (_isSignedIn && _user != null) {
      _setOneSignalUserData(); // Don't await here to speed up app launch
    }

    _isLoading = false;
    notifyListeners();
  }

  // Register new user
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? photoUrl,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {

      
      // Prepare request body
      // Use the actually entered name as username instead of deriving from email
      final requestBody = {
        'name': name,
        'username': email.split('@')[0],
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
        if (photoUrl != null) 'photo_url': photoUrl,
        if (photoUrl != null) 'avatar': photoUrl,
      };
      


      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/register'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 15));



      // Try to parse response
      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {

        throw Exception('Invalid server response format');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {

        // Registration successful, now login using the username the API returned (or fallback)
        String usernameFromApi = '';
        try {
          usernameFromApi = (data['username'] ?? '') as String;
        } catch (_) {}

        final username = usernameFromApi.isNotEmpty
            ? usernameFromApi
            : (name.isNotEmpty
                ? name
                : (email.contains('@') ? email.split('@')[0] : email));

        _isLoading = false;
        notifyListeners();
        return await _loginWithUsername(username: username, password: password);
      } else {
        String errorMessage = 'Registration failed';
        if (data['message'] != null) {
          errorMessage = data['message'].toString();
        } else if (data['error'] != null) {
          errorMessage = data['error'].toString();
        }
        

        _isLoading = false;
        notifyListeners();
        return {
          'success': false,
          'message': errorMessage,
          'errors': (data['errors'] is Map)
              ? Map<String, dynamic>.from(data['errors'])
              : <String, dynamic>{},
        };
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('Error during registration: $e');
        debugPrint(stackTrace.toString());
      }
      _isLoading = false;
      notifyListeners();
      return {
        'success': false,
        'message': 'تکایە پشکنینی هێڵی ئینتەرنێت بکە و دووبارە هەوڵ بدەوە',
      };
    }
  }

  // Login user
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {

      
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 15));



      Map<String, dynamic> data = {};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) data = Map<String, dynamic>.from(decoded);
      } catch (_) {}

      if (response.statusCode == 200) {
        _token = data['access'] ?? data['access_token'];  // Support both formats
        _refreshToken = data['refresh'] ?? data['refresh_token'];  // Support both formats
        _isSignedIn = true;


        // Get user information using the token


        // OPTIMIZATION: Check if user data is already in the response to avoid extra API call
        if (data.containsKey('user') && data['user'] != null) {
          _user = data['user'];
          // Ensure we have minimal required fields
          if (_user!['email'] == null) _user!['email'] = email;
        } else {
          // Only fetch if not provided in login response
          final userInfoSuccess = await _getCurrentUser();
          
          if (!userInfoSuccess) {
            // If we can't get user info, create a basic user object with email
            _user = {
              'email': email,
              'name': email.split('@')[0], // Use part before @ as name
              'username': email.split('@')[0],
            };
          }
        }
        

        
        // Save tokens securely
        await _saveTokens();
        
        // Save user data to SharedPreferences (non-sensitive)
        if (_user != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userData', jsonEncode(_user));
          _setOneSignalUserData(); // Sync OneSignal in background
        }

        _isLoading = false;
        notifyListeners();
        return {
          'success': true,
          'message': 'Login successful',
          'user': _user,
        };
      } else {
        // Handle inactive user account (403 Forbidden)
        if (response.statusCode == 403) {
          _isLoading = false;
          notifyListeners();
          return {
            'success': false,
            'message': data['detail'] ?? 'هەژمارەکەت راگیراوە',
          };
        }
        
        // If backend requires username (422 with detail missing username), retry with username
        final needsUsername = response.statusCode == 422 &&
            ((data['detail'] is List &&
                (data['detail'] as List).any((e) =>
                    (e is Map) &&
                    (e['loc'] is List) &&
                    (e['loc'] as List).contains('username'))));

        if (needsUsername) {
          // Try username as email local-part first, then as full email
          final usernameCandidates = <String>[
            if (email.contains('@')) email.split('@')[0],
            email,
          ];

          for (final u in usernameCandidates) {
            try {
              final r2 = await http.post(
                Uri.parse('$baseUrl/api/auth/login'),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
                body: jsonEncode({
                  'username': u,
                  'password': password,
                }),
              );

              Map<String, dynamic> d2 = {};
              try {
                final dec2 = jsonDecode(r2.body);
                if (dec2 is Map) d2 = Map<String, dynamic>.from(dec2);
              } catch (_) {}



              if (r2.statusCode == 200) {
                _token = d2['access'] ?? d2['access_token'];
                _refreshToken = d2['refresh'] ?? d2['refresh_token'];
                _isSignedIn = true;

                // Fetch user info (ignore failure)
                await _getCurrentUser();

                // Save tokens securely
                await _saveTokens();
                
                // Save user data to SharedPreferences (non-sensitive)
                if (_user != null) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('userData', jsonEncode(_user));
                }

                _isLoading = false;
                notifyListeners();
                return {
                  'success': true,
                  'message': 'Login successful',
                  'user': _user,
                };
              }
            } catch (_) {
              // continue to next candidate
            }
          }
        }

        _isLoading = false;
        notifyListeners();
        return {
          'success': false,
          'message': data['message'] ?? 'Login failed',
          'errors': (data['errors'] is Map)
              ? Map<String, dynamic>.from(data['errors'])
              : <String, dynamic>{},
        };
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {
        'success': false,
        'message': 'تکایە پشکنینی هێڵی ئینتەرنێت بکە و دووبارە هەوڵ بدەوە',
      };
    }
  }

  // Login with username instead of email (used after registration)
  Future<Map<String, dynamic>> _loginWithUsername({
    required String username,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {

      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 15));



      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _token = data['access'] ?? data['access_token'];  // Support both formats
        _refreshToken = data['refresh'] ?? data['refresh_token'];  // Support both formats
        _isSignedIn = true;


        // Get user information using the token


        // OPTIMIZATION: Check if user data is already in the response to avoid extra API call
        if (data.containsKey('user') && data['user'] != null) {
          _user = data['user'];
          if (_user!['username'] == null) _user!['username'] = username;
        } else {
          // Only fetch if not provided in login response
          final userInfoSuccess = await _getCurrentUser();
          
          if (!userInfoSuccess) {
            // If we can't get user info, create a basic user object with username
            _user = {
              'username': username,
              'name': username,
            };
          }
        }

        
        // Save tokens securely
        await _saveTokens();
        
        // Save user data to SharedPreferences (non-sensitive)
        if (_user != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userData', jsonEncode(_user));
          _setOneSignalUserData(); // Sync OneSignal in background
        }

        _isLoading = false;
        notifyListeners();
        return {
          'success': true,
          'message': 'Login successful',
          'user': _user,
        };
      } else {
        // Handle inactive user account (403 Forbidden)
        if (response.statusCode == 403) {
          _isLoading = false;
          notifyListeners();
          return {
            'success': false,
            'message': data['detail'] ?? 'هەژمارەکەت راگیراوە',
          };
        }
        
        _isLoading = false;
        notifyListeners();
        return {
          'success': false,
          'message': data['message'] ?? 'Login failed',
          'errors': data['errors'] ?? {},
        };
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {
        'success': false,
        'message': 'تکایە پشکنینی هێڵی ئینتەرنێت بکە و دووبارە هەوڵ بدەوە',
      };
    }
  }

  // Get current user info (public method)
  Future<bool> getCurrentUser() async {
    return await _getCurrentUser();
  }

  // Get current user info
  Future<bool> _getCurrentUser() async {
    if (_token == null) return false;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Preserve existing avatar/photo_url if the server response lacks them
        final newUser = Map<String, dynamic>.from(data['user'] ?? data);
        if ((newUser['avatar'] == null && newUser['photo_url'] == null) && _user != null) {
          newUser['avatar'] = _user!['avatar'] ?? _user!['photo_url'];
          newUser['photo_url'] = newUser['photo_url'] ?? _user!['photo_url'];
        }
        _user = newUser;
        
        // Save user data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userData', jsonEncode(_user));
        _setOneSignalUserData(); // Sync OneSignal in background
        
        return true;
      } else if (response.statusCode == 401) {
        // 401 means invalid credentials - account deleted or token revoked
        // Clear all data and logout
        await _clearTokens();
        _user = null;
        _isSignedIn = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      // Silent error handling
    }
    return false;
  }

  // Refresh access token
  Future<bool> _refreshAccessToken() async {
    if (_refreshToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/refresh'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'refresh_token': _refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['access_token'];
        if (data['refresh_token'] != null) {
          _refreshToken = data['refresh_token'];
        }

        // Save new tokens securely
        await _saveTokens();

        return true;
      } else if (response.statusCode == 403) {
        // Account has been deactivated - force logout
        await _clearTokens();
        _user = null;
        _isSignedIn = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error refreshing token: $e');
      }
    }
    return false;
  }

  // Sign out
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_token != null && _refreshToken != null) {
        // Call logout API - must send refresh_token in body for backend to revoke it
        await http.post(
          Uri.parse('$baseUrl/api/auth/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $_token',
          },
          body: jsonEncode({'refresh_token': _refreshToken}),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error during sign out: $e');
      }
    }

    // Sign out from Google as well
    try {
      await _googleSignIn?.signOut();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error signing out from Google: $e');
      }
    }
    
    // Clear local data regardless of API call result
    await _clearTokens();
    _user = null;
    _isSignedIn = false;

    _isLoading = false;
    notifyListeners();
  }

  // Save tokens securely
  Future<void> _saveTokens() async {
    if (_token != null) {
      await _secureStorage.saveToken(_token!);
    }
    if (_refreshToken != null) {
      await _secureStorage.saveRefreshToken(_refreshToken!);
    }
  }

  // Clear tokens and user data
  Future<void> _clearTokens() async {
    _token = null;
    _refreshToken = null;
    
    // Clear secure storage
    await _secureStorage.clearAll();
    
    // Clear non-sensitive data from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userData');
    
    // Clear all cached data that might be user-specific
    // This prevents showing old user's data to new users
    final keysToRemove = [
      'about_text',
      'about_text_hash',
      'about_ceos',
      'about_ceos_hash',
      'about_supporters',
      'about_supporters_hash',
    ];
    
    for (final key in keysToRemove) {
      await prefs.remove(key);
    }
  }

  // Get user display name
  String get userDisplayName {
    if (_user != null) {
      return _user!['username'] ?? _user!['name'] ?? _user!['email'] ?? 'User';
    }
    return 'User';
  }

  // Get user email
  String get userEmail {
    if (_user != null) {
      return _user!['email'] ?? '';
    }
    return '';
  }

  // Get user photo URL
  String? get userPhotoUrl {
    if (_user != null) {
      return _user!['avatar'] ?? _user!['photo_url'];
    }
    return null;
  }

  // UPDATED: Fixed Google Sign-In Flow - Login First, Then Register
  Future<Map<String, dynamic>> _registerOrLoginWithGoogle({
    required String email,
    required String name,
    required String googleId,
    required String googleToken,
    String? photoUrl,
  }) async {


    // STEP 1: Try Google-specific login endpoint first (for existing Google users)


  final googleLoginResult = await _loginWithGoogleEndpoint(
    email: email,
    name: name,
    googleId: googleId,
    googleToken: googleToken,
    photoUrl: photoUrl,
  );

  if (googleLoginResult['success'] == true) {

    return googleLoginResult;
  }
  
  // Check if account is deactivated
  if (googleLoginResult['message'] != null && 
      googleLoginResult['message'].toString().contains('هەژمارەکەت راگیراوە')) {
    return googleLoginResult;
  }

  // STEP 2: If Google login failed, try Google registration endpoint (for first-time Google users)

  final googleRegisterResult = await _registerWithGoogleEndpoint(
    email: email,
    name: name,
    googleId: googleId,
    googleToken: googleToken,
    photoUrl: photoUrl,
  );

  if (googleRegisterResult['success'] == true) {
    return googleRegisterResult;
  }

  // STEP 3: Legacy Fallback - Try login with email and googleId as password
  final regularLoginResult = await login(
    email: email,
    password: googleId,
  );

  if (regularLoginResult['success'] == true) {
    if (photoUrl != null && _user != null) {
      _user!['photo_url'] = photoUrl;
      _user!['avatar'] = photoUrl;
      SharedPreferences.getInstance().then((prefs) => prefs.setString('userData', jsonEncode(_user)));
    }
    return {
      'success': true,
      'message': 'بەخێربێیت $name!',
      'user': _user,
    };
  }
  
  // Check if account is deactivated
  if (regularLoginResult['message'] != null && 
      regularLoginResult['message'].toString().contains('هەژمارەکەت راگیراوە')) {
    return regularLoginResult;
  }

  // STEP 4: Username Variations loop (Crucial for legacy users with custom usernames)
  final normalizedFullName = name.trim().replaceAll(RegExp(r'\s+'), ' ');
  final firstName = normalizedFullName.contains(' ') ? normalizedFullName.split(' ')[0] : normalizedFullName;
  final emailLocal = email.split('@')[0];
  
  final usernameVariations = [
    emailLocal,
    emailLocal.toLowerCase(),
    firstName,
    firstName.toLowerCase(),
    normalizedFullName,
    normalizedFullName.toLowerCase(),
    normalizedFullName.replaceAll(' ', '.'),
    '${firstName}_google',
    '${emailLocal}_google',
  ];

  for (String username in usernameVariations) {
    try {
      final usernameLoginResult = await _loginWithUsername(
        username: username,
        password: googleId,
      );

      if (usernameLoginResult['success'] == true) {
        if (photoUrl != null && _user != null) {
          _user!['photo_url'] = photoUrl;
          _user!['avatar'] = photoUrl;
          SharedPreferences.getInstance().then((prefs) => prefs.setString('userData', jsonEncode(_user)));
        }
        return {
          'success': true,
          'message': 'بەخێربێیت $name!',
          'user': _user,
        };
      }
      
      // Check if account is deactivated
      if (usernameLoginResult['message'] != null && 
          usernameLoginResult['message'].toString().contains('هەژمارەکەت راگیراوە')) {
        return usernameLoginResult;
      }
    } catch (_) {}
  }

  // STEP 5: Final Failure
  return {
    'success': false,
    'message': 'ئەکاونت نەدۆزرایەوە یان زانیارییەکان هەڵەن. تکایە هەژماری نوێ دروست بکە.',
    'account_not_found': true,
    'email': email,
    'error_type': 'account_not_found',
  };
}

  // Updated signInWithGoogle method to handle the response better
  Future<Map<String, dynamic>> signInWithGoogle() async {

    
    _isLoading = true;
    notifyListeners();

    
    try {

      if (_googleSignIn == null) {
        _isLoading = false;
        notifyListeners();
        return {
          'success': false,
          'message': 'چوونە ژوورەوە بە گووگڵ لەسەر وێب بەردەست نییە. تکایە ئیمەیڵ و وشەی نهێنیت بەکاربهێنە.',
        };
      }

      // Sign out first to ensure fresh login
      await _googleSignIn?.signOut();
      
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn?.signIn();
      
      if (googleUser == null) {

        _isLoading = false;
        notifyListeners();
        return {
          'success': false,
          'message': 'تۆ داخڵبوونت هەڵوەشاندەوە', // You cancelled the login
        };
      }


      
      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      if (googleAuth.accessToken == null && googleAuth.idToken == null) {

        _isLoading = false;
        notifyListeners();
        return {
          'success': false,
          'message': 'هەڵەیەک ڕووی دا لە گووگڵ داخڵبوون', // An error occurred with Google login
        };
      }


      
      // Try to register/login with your backend using Google data
      final result = await _registerOrLoginWithGoogle(
        email: googleUser.email,
        name: googleUser.displayName ?? googleUser.email.split('@')[0],
        googleId: googleUser.id,
        googleToken: googleAuth.idToken ?? googleAuth.accessToken ?? '',
        photoUrl: googleUser.photoUrl,
      );
      
      _isLoading = false;
      notifyListeners();
      
      return result;
      
    } catch (error) {
      if (kDebugMode) debugPrint('Error in signInWithGoogle: $error');
      _isLoading = false;
      notifyListeners();
      final errorStr = error.toString();
      String message;
      if (errorStr.contains('network_error') || errorStr.contains('NetworkError') || errorStr.contains('SocketException')) {
        message = 'تکایە پشکنینی هێڵی ئینتەرنێت بکە و دووبارە هەوڵ بدەوە';
      } else {
        message = 'هەڵەی گووگڵ: $errorStr';
      }
      return {
        'success': false,
        'message': message,
      };
    }
  }

  // Updated _registerWithRegularEndpoint to be more robust
  Future<Map<String, dynamic>> _registerWithRegularEndpoint({
    required String email,
    required String name,
    required String googleId,
    String? photoUrl,
  }) async {
    try {
      // Try different username variations if the first one fails
      final normalizedName = name.trim().replaceAll(RegExp(r'\s+'), ' ');
      final baseUsername = normalizedName; // Preserve spaces and case
      final emailUsername = email.split('@')[0];
      
      final usernameVariations = [
        baseUsername,
        emailUsername,
        baseUsername.replaceAll(' ', ''),
        baseUsername.toLowerCase(),
        emailUsername.toLowerCase(),
        baseUsername.replaceAll(' ', '.'), // legacy fallback
        '${emailUsername}_google',
        '${baseUsername}_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
      ];
      
      for (int i = 0; i < usernameVariations.length; i++) {
        final username = usernameVariations[i];
        final requestBody = {
          'email': email,
          'name': name,
          'username': username,
          'password': googleId,
          'password_confirmation': googleId,
          if (photoUrl != null) 'photo_url': photoUrl,
          if (photoUrl != null) 'avatar': photoUrl,
        };
        

        
        final registerResponse = await http.post(
          Uri.parse('$baseUrl/api/auth/register'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(requestBody),
        );
        

        
        if (registerResponse.statusCode == 200 || registerResponse.statusCode == 201) {

          
          // Parse the registration response
          final regData = jsonDecode(registerResponse.body);
          
          // Check if registration response contains tokens (direct login)
          if (regData['access_token'] != null) {

            _token = regData['access_token'];
            _refreshToken = regData['refresh_token'];
            _user = regData['user'] ?? {
              'email': email,
              'username': username,
              'name': name,
              'photo_url': photoUrl,
            };
            _isSignedIn = true;

            // Save tokens securely
            await _saveTokens();
            
            // Save user data to SharedPreferences (non-sensitive)
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('userData', jsonEncode(_user));
            
            return {
              'success': true,
              'message': 'بەخێربێیت $name! هەژمارەکەت بە سەرکەوتوویی دروستکرا.',
              'user': _user,
            };
          }
          
          // If no tokens in registration response, login separately

          final loginResult = await login(
            email: email,
            password: googleId,
          );
          
          if (loginResult['success'] == true) {

            return {
              'success': true,
              'message': 'بەخێربێیت $name! هەژمارەکەت بە سەرکەوتوویی دروستکرا.',
              'user': _user,
            };
          } else {
            // Registration successful but login failed - try username login
            final usernameLoginResult = await _loginWithUsername(
              username: username,
              password: googleId,
            );
            
            if (usernameLoginResult['success'] == true) {
              return {
                'success': true,
                'message': 'بەخێربێیت $name! هەژمارەکەت بە سەرکەوتوویی دروستکرا.',
                'user': _user,
              };
            }
          }
          
          // If both login attempts failed after successful registration
          return {
            'success': false,
            'message': 'هەژمار دروست کرا بەڵام نەتوانرا بچیتە ژوورەوە. تکایە دووبارە هەوڵ بدەوە.',
          };
        } else {
          final data = jsonDecode(registerResponse.body);
          
          // If it's an email already registered error, return immediately
          if (data['detail']?.toString().contains('Email already registered') == true) {

            return {
              'success': false,
              'message': 'Registration failed',
              'detail': data['detail'],
              'errors': data['errors'] ?? {},
              'status_code': registerResponse.statusCode,
            };
          }
          
          // If username is already taken and we have more variations, try next
          if (data['detail']?.toString().contains('Username already registered') == true && 
              i < usernameVariations.length - 1) {

            continue;
          }
          
          // If it's the last attempt or a different error, return the error

          return {
            'success': false,
            'message': data['message'] ?? data['detail'] ?? 'Registration failed',
            'detail': data['detail'],
            'errors': data['errors'] ?? {},
            'status_code': registerResponse.statusCode,
          };
        }
      }
      
      // If all username variations failed
      return {
        'success': false,
        'message': 'Unable to create account with available usernames',
        'status_code': 400,
      };
      
    } catch (e) {
      if (kDebugMode) debugPrint('Error in _registerWithRegularEndpoint: $e');
      final errorStr = e.toString();
      String message;
      if (errorStr.contains('network_error') || errorStr.contains('NetworkError') || errorStr.contains('SocketException')) {
        message = 'تکایە پشکنینی هێڵی ئینتەرنێت بکە و دووبارە هەوڵ بدەوە';
      } else {
        message = 'هەڵەیەک ڕوویدا: $errorStr';
      }
      return {
        'success': false,
        'message': message,
      };
    }
  }

  // Google-specific login endpoint method
  Future<Map<String, dynamic>> _loginWithGoogleEndpoint({
    required String email,
    required String name,
    required String googleId,
    required String googleToken,
    String? photoUrl,
  }) async {
    try {

      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/google-login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'name': name,
          'google_id': googleId,
          'google_token': googleToken,
          'photo_url': photoUrl,
        }),
      ).timeout(const Duration(seconds: 15));



      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        // Store tokens and user data
        _token = data['access_token'];
        _refreshToken = data['refresh_token'];
        _user = data['user'];
        _isSignedIn = true;

        // Save tokens securely
        await _saveTokens();
        
        // Save user data to SharedPreferences (non-sensitive)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userData', jsonEncode(_user));
        _setOneSignalUserData(); // Sync OneSignal in background


        return {
          'success': true,
          'message': 'بەخێربێیت ${_user!['name']}!',
          'user': _user,
        };
      } else if (response.statusCode == 403) {
        // Handle inactive user account
        return {
          'success': false,
          'message': data['detail'] ?? 'هەژمارەکەت راگیراوە',
        };
      } else {

        return {
          'success': false,
          'message': data['message'] ?? 'Google login failed',
        };
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error in _loginWithGoogleEndpoint: $e');
      final errorStr = e.toString();
      String message;
      if (errorStr.contains('network_error') || errorStr.contains('NetworkError') || errorStr.contains('SocketException')) {
        message = 'تکایە پشکنینی هێڵی ئینتەرنێت بکە و دووبارە هەوڵ بدەوە';
      } else {
        message = 'هەڵەیەک ڕوویدا: $errorStr';
      }
      return {
        'success': false,
        'message': message,
      };
    }
  }

  // Google-specific registration endpoint method
  Future<Map<String, dynamic>> _registerWithGoogleEndpoint({
    required String email,
    required String name,
    required String googleId,
    required String googleToken,
    String? photoUrl,
  }) async {
    try {

      
      // Try to register with the full name as the username (preserve spaces and case)
      final normalizedName = name.trim().replaceAll(RegExp(r'\s+'), ' ');
      String username = normalizedName;
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/google-register'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'name': name,
          'username': username,
          'google_id': googleId,
          'google_token': googleToken,
          'photo_url': photoUrl,
        }),
      ).timeout(const Duration(seconds: 15));



      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data['success'] == true) {
          // Store tokens and user data if provided
          if (data['access_token'] != null) {
            _token = data['access_token'];
            _refreshToken = data['refresh_token'];
            _user = data['user'];
            _isSignedIn = true;

            // Save tokens securely
            await _saveTokens();
            
            // Save user data to SharedPreferences (non-sensitive)
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('userData', jsonEncode(_user));
            _setOneSignalUserData(); // Sync OneSignal in background


            return {
              'success': true,
              'message': 'بەخێربێیت ${_user!['name']}!',
              'user': _user,
            };
          } else {
            // Registration successful but need to login

            return await _loginWithGoogleEndpoint(
              email: email,
              name: name,
              googleId: googleId,
              googleToken: googleToken,
              photoUrl: photoUrl,
            );
          }
        }
      }
      

      return {
        'success': false,
        'message': data['message'] ?? 'Google registration failed',
      };
    } catch (e) {
      if (kDebugMode) debugPrint('Error in _registerWithGoogleEndpoint: $e');
      final errorStr = e.toString();
      String message;
      if (errorStr.contains('network_error') || errorStr.contains('NetworkError') || errorStr.contains('SocketException')) {
        message = 'تکایە پشکنینی هێڵی ئینتەرنێت بکە و دووبارە هەوڵ بدەوە';
      } else {
        message = 'هەڵەیەک ڕوویدا: $errorStr';
      }
      return {
        'success': false,
        'message': message,
      };
    }
  }

  // Google Sign-Up method - Forces registration first (for registration mode)
  Future<Map<String, dynamic>> signUpWithGoogle() async {

    
    _isLoading = true;
    notifyListeners();

    
    try {

      if (_googleSignIn == null) {
        _isLoading = false;
        notifyListeners();
        return {
          'success': false,
          'message': 'چوونە ژوورەوە بە گووگڵ لەسەر وێب بەردەست نییە. تکایە ئیمەیڵ و وشەی نهێنیت بەکاربهێنە.',
        };
      }

      // Sign out first to ensure fresh login
      await _googleSignIn?.signOut();
      
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn?.signIn();
      
      if (googleUser == null) {

        _isLoading = false;
        notifyListeners();
        return {
          'success': false,
          'message': 'تۆ داخڵبوونت هەڵوەشاندەوە', // You cancelled the login
        };
      }


      
      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      if (googleAuth.accessToken == null && googleAuth.idToken == null) {

        _isLoading = false;
        notifyListeners();
        return {
          'success': false,
          'message': 'هەڵەیەک ڕووی دا لە گووگڵ داخڵبوون', // An error occurred with Google login
        };
      }


      
      // Try to register first (this is the key difference from signInWithGoogle)
      final result = await _registerWithRegularEndpoint(
        email: googleUser.email,
        name: googleUser.displayName ?? googleUser.email.split('@')[0],
        googleId: googleUser.id,
        photoUrl: googleUser.photoUrl,
      );
      
      _isLoading = false;
      notifyListeners();
      
      // If registration succeeded, return success
      if (result['success'] == true) {
        return result;
      }
      
      // If registration failed due to existing email, show appropriate message
      final errorMessage = result['message']?.toString() ?? '';
      final errorDetail = result['detail']?.toString() ?? '';
      
      if (errorDetail.contains('Email already registered') || 
          errorMessage.contains('already registered') ||
          errorDetail.contains('تۆمارکراوە') ||
          errorMessage.contains('تۆمارکراوە')) {
        

        return {
          'success': false,
          'message': 'ئەم ئیمەیڵە پێشتر بە شێوەیەکی ئاسایی تۆمارکراوە. تکایە بە وشەی نهێنی خۆت بچۆ ژوورەوە.',
          'account_exists': true,
          'email': googleUser.email,
          'error_type': 'email_exists',
        };
      }
      
      // For other registration errors
      return {
        'success': false,
        'message': result['message'] ?? 'هەڵەیەک ڕوویدا لە هەژمار دروستکردن',
        'error_type': 'registration_failed'
      };
      
    } catch (error) {
      if (kDebugMode) debugPrint('Error in signUpWithGoogle: $error');
      _isLoading = false;
      notifyListeners();
      final errorStr = error.toString();
      String message;
      if (errorStr.contains('network_error') || errorStr.contains('NetworkError') || errorStr.contains('SocketException')) {
        message = 'تکایە پشکنینی هێڵی ئینتەرنێت بکە و دووبارە هەوڵ بدەوە';
      } else {
        message = 'هەڵەی گووگڵ: $errorStr';
      }
      return {
        'success': false,
        'message': message,
      };
    }
  }

  // Sign out from Google
  Future<void> signOutFromGoogle() async {
    try {
      await _googleSignIn?.signOut();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error signing out from Google: $e');
      }
    }
  }

  // Delete account method
  Future<Map<String, dynamic>> deleteAccount() async {
    if (!_isSignedIn || _token == null) {
      return {
        'success': false,
        'message': 'تۆ داخڵ نەبوویت',
      };
    }

    _isLoading = true;
    notifyListeners();

    try {

      
      final response = await http.delete(
        Uri.parse('$baseUrl/api/auth/delete-account'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );



      if (response.statusCode == 200 || response.statusCode == 204) {
        // Account successfully deleted

        
        // Sign out from Google if applicable
        try {
          await _googleSignIn?.signOut();
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error signing out from Google after account delete: $e');
          }
        }
        
        // Clear all local data
        await _clearTokens();
        _user = null;
        _isSignedIn = false;
        
        _isLoading = false;
        notifyListeners();
        
        return {
          'success': true,
          'message': 'هەژمارەکەت بە سەرکەوتوویی سڕایەوە',
        };
      } else {
        final data = jsonDecode(response.body);
        final errorMessage = data['message'] ?? data['detail'] ?? 'هەڵەیەک ڕووی دا لە سڕینەوەی هەژمار';
        
        _isLoading = false;
        notifyListeners();
        
        return {
          'success': false,
          'message': errorMessage,
        };
      }
    } catch (e) {

      _isLoading = false;
      notifyListeners();
      
      return {
        'success': false,
        'message': 'تکایە پشکنینی هێڵی ئینتەرنێت بکە و دووبارە هەوڵ بدەوە',
      };
    }
  }

  // Set OneSignal user data for push notifications
  Future<void> _setOneSignalUserData() async {
    if (_user != null) {
      try {
        // Set external user ID for targeting
        final userId = _user!['id']?.toString() ?? _user!['email']?.toString();
        if (userId != null) {
          await OneSignalService.setExternalUserId(userId);
        }

        // Set minimal OneSignal user tags to avoid tag limit
        await OneSignalService.setUserTags({
          'user_type': 'registered',
        });
        

      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error setting OneSignal user data: $e');
        }
      }
    }
  }
}