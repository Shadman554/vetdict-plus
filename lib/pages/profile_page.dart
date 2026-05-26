import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import '../providers/auth_provider.dart';
import 'login_page.dart';
import '../widgets/notification_bottom_sheet.dart';
import '../utils/constants.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  // Quiz data
  int currentRank = 0;
  int totalPlayers = 0;
  
  // Leaderboard data
  List<Map<String, dynamic>> leaderboardData = [];
  
  // My rank data from /my-rank endpoint (accurate, not limited to top 50)
  int _myPoints = 0;
  int _myTodayPoints = 0;

  // UI States
  bool _isLoadingLeaderboard = false;
  bool _isDeletingAccount = false;

  // Track which user the leaderboard was fetched for
  String? _leaderboardFetchedForUser;

  // Animation controller
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Reset leaderboard data on init to prevent showing old user's data
    currentRank = 0;
    totalPlayers = 0;
    leaderboardData = [];
    _myPoints = 0;
    _myTodayPoints = 0;
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
    
    // Load data after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchLeaderboard();
      }
    });
  }

  String? _getUserIdentifier(AuthProvider authProvider) {
    return authProvider.user?['id']?.toString() ??
        authProvider.user?['email']?.toString() ??
        authProvider.user?['username']?.toString();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchLeaderboard() async {
    if (_isLoadingLeaderboard) return;
    
    setState(() => _isLoadingLeaderboard = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      // Fetch current user's rank from dedicated endpoint (accurate, not limited to top 50)
      if (authProvider.token != null) {
        final myRankResponse = await http.get(
          Uri.parse('${AuthProvider.baseUrl}/api/leaderboard/my-rank'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer ${authProvider.token}',
          },
        ).timeout(const Duration(seconds: 10));

        if (myRankResponse.statusCode == 200) {
          final myData = jsonDecode(myRankResponse.body);
          if (mounted) {
            setState(() {
              currentRank = myData['rank'] ?? 0;
              totalPlayers = myData['total_players'] ?? 0;
              _myPoints = myData['total_points'] ?? 0;
              _myTodayPoints = myData['today_points'] ?? 0;
            });
          }
        }
      }

      // Fetch full leaderboard for the leaderboard sheet display
      final response = await http.get(
        Uri.parse('${AuthProvider.baseUrl}/api/leaderboard'),
        headers: {
          'Accept': 'application/json',
          if (authProvider.token != null)
            'Authorization': 'Bearer ${authProvider.token}',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> list = _extractLeaderboardList(decoded);

        final String? currentUsername = authProvider.user?['username'] ??
            authProvider.user?['name'] ??
            authProvider.user?['email'];
        final String? currentUserId = authProvider.user?['id']?.toString() ??
            authProvider.user?['user_id']?.toString();

        final normalized = _normalizeLeaderboardData(list, currentUsername, currentUserId);

        // Override isCurrentUser using rank from /my-rank — avoids false positives
        // when multiple accounts share the same display name.
        final int rankToMark = currentRank;
        if (rankToMark > 0) {
          for (final entry in normalized) {
            entry['isCurrentUser'] = (entry['rank'] == rankToMark);
          }
        }

        if (mounted) {
          setState(() {
            leaderboardData = normalized;

            // Fallback: if /my-rank didn't return data, derive rank from leaderboard list
            if (currentRank == 0 && normalized.isNotEmpty) {
              final currentEntry = normalized.firstWhere(
                (e) => e['isCurrentUser'] == true,
                orElse: () => {},
              );
              if (currentEntry.isNotEmpty) {
                currentRank = currentEntry['rank'] as int;
                _myPoints = currentEntry['points'] as int;
              }
              totalPlayers = normalized.length;
            }
          });
        }
      }
    } catch (e) {
      // Silently ignore — leaderboard is non-critical and may fail when offline or not logged in
    } finally {
      if (mounted) {
        setState(() => _isLoadingLeaderboard = false);
      }
    }
  }

  List<dynamic> _extractLeaderboardList(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map) {
      if (decoded.containsKey('data')) return decoded['data'];
      if (decoded.containsKey('leaderboard')) return decoded['leaderboard'];
    }
    return [];
  }

  List<Map<String, dynamic>> _normalizeLeaderboardData(
    List<dynamic> list,
    String? currentUsername,
    String? currentUserId,
  ) {
    final normalized = <Map<String, dynamic>>[];
    
    for (var i = 0; i < list.length; i++) {
      final raw = list[i] as Map<String, dynamic>;
      final username = raw['username'] ?? raw['name'] ?? raw['user'] ?? 'User';
      final points = raw['total_points'] ?? raw['points'] ?? 0;
      final photoUrl = raw['photo_url'] ?? raw['avatar'] ?? raw['profile_image'];
      
      // Skip admin accounts for security/privacy
      final role = (raw['role'] ?? raw['user_role'] ?? '').toString().toLowerCase();
      
      // Check is_admin field (handle both boolean and string values)
      final isAdminValue = raw['is_admin'];
      final isAdminFlag = (isAdminValue == true) || 
                          (isAdminValue == 1) || 
                          (isAdminValue.toString().toLowerCase() == 'true') ||
                          (isAdminValue.toString() == '1') ||
                          role.contains('admin') || 
                          role.contains('superuser');
      
      // Check username for admin-like names
      final isAdminName = username.toString().toLowerCase() == 'admin' ||
          username.toString().toLowerCase() == 'administrator' ||
          username.toString().toLowerCase().contains('admin');
      
      if (isAdminFlag || isAdminName) {
        continue;
      }
      
      final userId = raw['id']?.toString() ?? raw['user_id']?.toString();
      final bool isCurrentUser = (currentUserId != null && userId != null)
          ? userId == currentUserId
          : (currentUsername != null &&
             username.toString().toLowerCase() == currentUsername.toLowerCase());

      normalized.add({
        'name': username,
        'points': points,
        'photo_url': photoUrl,
        'isCurrentUser': isCurrentUser,
      });
    }

    // Sort by points descending
    normalized.sort((a, b) => (b['points'] as int).compareTo(a['points'] as int));
    
    // Assign ranks
    for (int i = 0; i < normalized.length; i++) {
      normalized[i]['rank'] = i + 1;
    }
    
    return normalized;
  }

  void _showLeaderboard() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: themeProvider.isDarkMode ? themeProvider.theme.colorScheme.surface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: themeProvider.isDarkMode ? themeProvider.theme.colorScheme.outlineVariant : Colors.grey[400],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            
            // Title with refresh button
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 40),
                  Expanded(
                    child: Directionality(
                      textDirection: languageProvider.textDirection,
                      child: Text(
                        'پلەبەندی',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'NRT',
                          color: themeProvider.isDarkMode ? themeProvider.theme.colorScheme.onSurface : Colors.black,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _isLoadingLeaderboard ? null : _fetchLeaderboard,
                    icon: _isLoadingLeaderboard
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: themeProvider.theme.colorScheme.primary,
                            ),
                          )
                        : Icon(
                            Icons.refresh,
                            color: themeProvider.theme.colorScheme.primary,
                          ),
                  ),
                ],
              ),
            ),
            
            // Leaderboard list
            Expanded(
              child: _isLoadingLeaderboard && leaderboardData.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : leaderboardData.isEmpty
                      ? Center(
                          child: Directionality(
                            textDirection: languageProvider.textDirection,
                            child: Text(
                              'هیچ داتایەک نەدۆزرایەوە',
                              style: TextStyle(
                                fontFamily: 'NRT',
                                fontSize: 16,
                                color: themeProvider.isDarkMode ? themeProvider.theme.colorScheme.onSurfaceVariant : Colors.grey[600],
                              ),
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchLeaderboard,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: leaderboardData.length,
                            itemBuilder: (context, index) => 
                                _buildLeaderboardItem(context, index),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardItem(BuildContext context, int index) {
    final user = leaderboardData[index];
    final isCurrentUser = user['isCurrentUser'] ?? false;
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return AnimatedContainer(
      duration: Duration(milliseconds: 300 + (index * 50)),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isCurrentUser 
            ? themeProvider.theme.colorScheme.primary.withValues(alpha: 0.15)
            : (themeProvider.isDarkMode ? themeProvider.theme.colorScheme.surface : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: _getRankColor(user['rank']),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _getRankColor(user['rank']).withValues(alpha: 0.4),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '${user['rank']}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Avatar
          Hero(
            tag: 'avatar_${user['name']}',
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCurrentUser 
                      ? themeProvider.theme.colorScheme.primary 
                      : (themeProvider.isDarkMode ? themeProvider.theme.colorScheme.outlineVariant : Colors.grey.shade300),
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: themeProvider.isDarkMode ? themeProvider.theme.colorScheme.surfaceContainerHighest : Colors.grey.shade300,
                backgroundImage: user['photo_url'] != null && 
                                user['photo_url'].toString().isNotEmpty
                    ? NetworkImage(user['photo_url'])
                    : null,
                child: (user['photo_url'] == null || user['photo_url'].toString().isEmpty)
                    ? Text(
                        (user['name'] ?? 'U').toString().substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: themeProvider.isDarkMode ? themeProvider.theme.colorScheme.onSurfaceVariant : Colors.black54,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (user['name'] as String? ?? '')
                    .split(RegExp(r'[.\s]'))
                    .where((w) => w.isNotEmpty)
                    .map((w) => w[0].toUpperCase() + w.substring(1))
                    .join(' '),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'NRT',
                    fontWeight: isCurrentUser 
                        ? FontWeight.w700 
                        : FontWeight.w500,
                    color: isCurrentUser 
                        ? themeProvider.theme.colorScheme.primary
                        : (themeProvider.isDarkMode ? themeProvider.theme.colorScheme.onSurface : Colors.black87),
                  ),
                ),
                if (isCurrentUser)
                  Text(
                    'تۆ',
                    style: TextStyle(
                      fontSize: 12,
                      color: themeProvider.theme.colorScheme.primary,
                      fontFamily: 'NRT',
                    ),
                  ),
              ],
            ),
          ),
          
          // Points badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFFD700),
                  Color(0xFFFFA000),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.stars_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  '${user['points']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return const Color(0xFF4CAF50); // Green
    }
  }

  void _showLogoutDialog() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: languageProvider.textDirection,
          child: AlertDialog(
            backgroundColor: themeProvider.isDarkMode ? themeProvider.theme.colorScheme.surface : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'چوونەدەرەوە',
              style: TextStyle(
                fontFamily: 'NRT',
                fontWeight: FontWeight.bold,
                color: themeProvider.isDarkMode ? themeProvider.theme.colorScheme.onSurface : Colors.black,
              ),
            ),
            content: Directionality(
              textDirection: languageProvider.textDirection,
              child: Text(
                'دڵنیایت لە چوونەدەرەوە؟',
                style: TextStyle(
                  fontFamily: 'NRT',
                  color: themeProvider.isDarkMode ? themeProvider.theme.colorScheme.onSurfaceVariant : Colors.black87,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Directionality(
                  textDirection: languageProvider.textDirection,
                  child: Text(
                    'پاشگەزبوونەوە',
                    style: TextStyle(
                      fontFamily: 'NRT',
                      color: themeProvider.isDarkMode ? themeProvider.theme.colorScheme.outlineVariant : Colors.grey[600],
                    ),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _performLogout();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Directionality(
                  textDirection: languageProvider.textDirection,
                  child: const Text(
                    'چوونەدەرەوە',
                    style: TextStyle(
                      fontFamily: 'NRT',
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteAccountDialog() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: languageProvider.textDirection,
          child: AlertDialog(
            backgroundColor: themeProvider.isDarkMode ? themeProvider.theme.colorScheme.surface : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'سڕینەوەی هەژمار',
              style: TextStyle(
                fontFamily: 'NRT',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
              textAlign: TextAlign.right,
            ),
            content: Text(
              'دڵنیایت لە سڕینەوەی هەژمارەکەت؟ ئامادە بیت بۆ لەدەستدانی هەموو داتاکانت',
              style: TextStyle(
                fontFamily: 'NRT',
                fontSize: 16,
                color: themeProvider.isDarkMode ? themeProvider.theme.colorScheme.onSurfaceVariant : Colors.black87,
              ),
              textAlign: TextAlign.right,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'هەڵوەشاندنەوە',
                  style: TextStyle(
                    fontFamily: 'NRT',
                    color: themeProvider.isDarkMode ? themeProvider.theme.colorScheme.outlineVariant : Colors.grey[600],
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _isDeletingAccount 
                    ? null 
                    : () {
                        Navigator.of(context).pop();
                        _performDeleteAccount();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'سڕینەوە',
                  style: TextStyle(
                    fontFamily: 'NRT',
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _performLogout() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.signOut();
      
      if (mounted) {
        _showSuccessSnackBar('بە سەرکەوتوویی چوویتە دەرەوە');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('هەڵەیەک ڕووی دا لە چوونەدەرەوە');
      }
    }
  }

  Future<void> _performDeleteAccount() async {
    setState(() {
      _isDeletingAccount = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      final result = await authProvider.deleteAccount();
      
      if (mounted) {
        if (result['success'] == true) {
          _showSuccessSnackBar(result['message'] ?? 'هەژمارەکەت سڕایەوە');
        } else {
          _showErrorSnackBar(result['message'] ?? 'هەڵەیەک ڕووی دا');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('هەڵەیەک ڕووی دا لە سڕینەوەی هەژمار');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingAccount = false;
        });
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Directionality(
          textDirection: languageProvider.textDirection,
          child: Text(
            message,
            style: const TextStyle(fontFamily: 'NRT'),
          ),
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Directionality(
          textDirection: languageProvider.textDirection,
          child: Text(
            message,
            style: const TextStyle(fontFamily: 'NRT'),
          ),
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    final currentUserId = _getUserIdentifier(authProvider);
    if (currentUserId != _leaderboardFetchedForUser && authProvider.isSignedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            currentRank = 0;
            totalPlayers = 0;
            leaderboardData = [];
            _leaderboardFetchedForUser = currentUserId;
          });
          _fetchLeaderboard();
        }
      });
    }

    final int userPoints = _myPoints > 0 ? _myPoints : (authProvider.user?['total_points'] ?? 0);

    if (!authProvider.isSignedIn) {
      return const LoginPage(isEmbedded: true);
    }

    final primaryColor = themeProvider.theme.colorScheme.primary;
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: themeProvider.theme.scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _fetchLeaderboard,
        color: primaryColor,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              backgroundColor: themeProvider.theme.scaffoldBackgroundColor,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  color: themeProvider.theme.scaffoldBackgroundColor,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 56),
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: primaryColor, width: 2.5),
                              ),
                              child: CircleAvatar(
                                radius: 44,
                                backgroundColor: themeProvider.theme.scaffoldBackgroundColor,
                                backgroundImage: authProvider.userPhotoUrl != null
                                    ? NetworkImage(authProvider.userPhotoUrl!)
                                    : null,
                                child: authProvider.userPhotoUrl == null
                                    ? Text(
                                        authProvider.userDisplayName.isNotEmpty
                                            ? authProvider.userDisplayName[0].toUpperCase()
                                            : 'U',
                                        style: TextStyle(
                                          fontSize: 34,
                                          fontWeight: FontWeight.bold,
                                          color: primaryColor,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            if (currentRank > 0 && currentRank <= 3)
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: currentRank == 1
                                      ? const Color(0xFFFFD700)
                                      : currentRank == 2
                                          ? const Color(0xFFC0C0C0)
                                          : const Color(0xFFCD7F32),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark ? themeProvider.theme.colorScheme.surface : Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: Text(
                                  currentRank == 1 ? '🥇' : currentRank == 2 ? '🥈' : '🥉',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          authProvider.userDisplayName,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (authProvider.user?['email'] != null)
                          Text(
                            authProvider.user!['email'],
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              title: Text(
                'پرۆفایل',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  fontFamily: 'NRT',
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              centerTitle: true,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
                child: Directionality(
                  textDirection: languageProvider.textDirection,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Stats Card ──
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
                        decoration: BoxDecoration(
                          color: isDark ? themeProvider.theme.colorScheme.surface : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: isDark
                              ? Border.all(color: Colors.white.withValues(alpha: 0.07), width: 1)
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.07),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _isLoadingLeaderboard && currentRank == 0
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                                ),
                              )
                            : Row(
                                children: [
                                  _buildStatItem(value: userPoints.toString(), label: 'خاڵی گشتی', icon: Icons.stars_rounded, color: const Color(0xFFFFB300), isDark: isDark),
                                  _buildStatDivider(isDark),
                                  _buildStatItem(value: _myTodayPoints.toString(), label: 'خاڵی ئەمڕۆ', icon: Icons.wb_sunny_rounded, color: const Color(0xFF4CAF50), isDark: isDark),
                                  _buildStatDivider(isDark),
                                  _buildStatItem(value: currentRank > 0 ? '#$currentRank' : '--', label: 'پلەبەندی', icon: Icons.emoji_events_rounded, color: primaryColor, isDark: isDark),
                                ],
                              ),
                      ),
                      const SizedBox(height: 20),
                      // ── Actions Section ──
                      _buildSectionGroup(
                        label: 'کارەکان',
                        isDark: isDark,
                        themeProvider: themeProvider,
                        languageProvider: languageProvider,
                        items: [
                          _buildMenuItem(icon: Icons.leaderboard_rounded, title: 'پلەبەندی', color: primaryColor, languageProvider: languageProvider, themeProvider: themeProvider, onTap: _showLeaderboard),
                          Divider(height: 1, indent: 60, color: isDark ? Colors.white10 : Colors.grey.shade100),
                          _buildMenuItem(
                            icon: Icons.notifications_rounded,
                            title: 'ئاگادارکردنەوە',
                            color: const Color(0xFF8B5CF6),
                            languageProvider: languageProvider,
                            themeProvider: themeProvider,
                            onTap: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => const NotificationBottomSheet(),
                            ),
                          ),
                          Divider(height: 1, indent: 60, color: isDark ? Colors.white10 : Colors.grey.shade100),
                          _buildMenuItem(
                            icon: Icons.privacy_tip_outlined,
                            title: 'سیاسەتی تایبەتمەندی',
                            color: const Color(0xFF4A7EB5),
                            languageProvider: languageProvider,
                            themeProvider: themeProvider,
                            onTap: () => _showPrivacyPolicyBottomSheet(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // ── Account Section ──
                      _buildSectionGroup(
                        label: 'هەژمار',
                        isDark: isDark,
                        themeProvider: themeProvider,
                        languageProvider: languageProvider,
                        items: [
                          _buildMenuItem(icon: Icons.logout_rounded, title: 'چوونەدەرەوە', color: Colors.orange, languageProvider: languageProvider, themeProvider: themeProvider, onTap: _showLogoutDialog),
                          Divider(height: 1, indent: 60, color: isDark ? Colors.white10 : Colors.grey.shade100),
                          _buildMenuItem(icon: Icons.delete_outline_rounded, title: 'سڕینەوەی هەژمار', color: Colors.red, languageProvider: languageProvider, themeProvider: themeProvider, onTap: _showDeleteAccountDialog),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacyPolicyBottomSheet(BuildContext context) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..loadRequest(Uri.parse(AppConstants.privacyPolicyUrl));

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
                  color: themeProvider.isDarkMode ? Colors.grey[700] : Colors.grey[300],
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

  Widget _buildStatItem({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'NRT',
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider(bool isDark) {
    return Container(
      width: 1,
      height: 50,
      color: isDark ? Colors.white10 : Colors.grey.shade200,
    );
  }

  Widget _buildSectionGroup({
    required String label,
    required bool isDark,
    required ThemeProvider themeProvider,
    required LanguageProvider languageProvider,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, right: 4, left: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'NRT',
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.grey[500] : Colors.grey[500],
              letterSpacing: 0.4,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? themeProvider.theme.colorScheme.surface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isDark
                ? Border.all(color: Colors.white.withValues(alpha: 0.07), width: 1)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(children: items),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required LanguageProvider languageProvider,
    required ThemeProvider themeProvider,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (color ?? themeProvider.theme.colorScheme.primary).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color ?? themeProvider.theme.colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Directionality(
                  textDirection: languageProvider.textDirection,
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontFamily: 'NRT',
                      color: color ??
                          (themeProvider.isDarkMode
                              ? Colors.white
                              : const Color(0xFF1A1A2E)),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              Icon(
                languageProvider.isRTL
                    ? Icons.arrow_back_ios_rounded
                    : Icons.arrow_forward_ios_rounded,
                color: themeProvider.isDarkMode ? Colors.grey[600] : Colors.grey.shade400,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

