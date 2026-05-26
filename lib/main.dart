import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart'; // Import url_launcher
import 'dart:io' show Platform; // Import Platform
import 'dart:async';
import 'utils/constants.dart'; // Import constants

import 'package:shared_preferences/shared_preferences.dart';
import 'providers/notification_provider.dart';

import 'settings.dart';
import 'providers/language_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/font_size_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/auth_provider.dart';
import '../providers/history_provider.dart';
import 'pages/favorites_page.dart';
import 'pages/history_page.dart';
import 'pages/profile_page.dart';
import 'pages/login_page.dart';

import 'pages/drugs.dart';
import 'pages/diseases.dart';
import 'pages/terminology.dart';
import 'pages/drug_details_page.dart';
import 'pages/disease_details_page.dart';
import 'pages/terminology_details_page.dart';
import 'pages/books.dart';
import 'pages/instruments_page.dart';
import 'pages/normal_ranges_page.dart';
import 'widgets/notification_dialog.dart';
import 'pages/notes_page.dart';
import 'pages/note_details_page.dart';
import 'pages/about_page.dart';
import 'pages/introduction_page.dart';
import 'pages/tests_page.dart';
import 'pages/slides.dart';

import 'package:vetstan/utils/page_transition.dart';
import 'services/update_service.dart';
import 'widgets/update_dialog.dart';

import 'package:share_plus/share_plus.dart';

// OneSignal
import 'services/onesignal_service.dart';
import 'services/first_launch_service.dart';
import 'services/notification_permission_service.dart';

import 'models/drug.dart';
import 'models/disease.dart';
import 'models/word.dart';
import 'models/normal_range.dart';
import 'models/note.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'services/sync_service.dart';
import 'services/cache_service.dart';
import 'services/api_service.dart'; // Add ApiService import
import 'pages/quiz_page.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // Preserve the splash screen until initialization is complete
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Lock screen orientation to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Pre-load SharedPreferences instance to avoid multiple async calls later
  await SharedPreferences.getInstance();

  // Initialize OneSignal
  await OneSignalService.initialize();

  // Pre-warm store-based update check (runs in background)
  UpdateService.initialize();

  // Initialize providers
  final notificationProvider = NotificationProvider();
  final bool seenIntro = await FirstLaunchService.hasSeenIntroduction();

  // Remove the splash screen now that initialization is done
  FlutterNativeSplash.remove();

  runApp(
    Phoenix(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<NotificationProvider>.value(value: notificationProvider),
           ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => FontSizeProvider()),
          ChangeNotifierProvider(create: (_) => FavoritesProvider()),
          ChangeNotifierProvider(create: (_) => HistoryProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
        ],
        child: MyApp(seenIntro: seenIntro),
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  final bool seenIntro;
  const MyApp({super.key, required this.seenIntro});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _initializeCache();
    // After first frame, wire OneSignal callbacks to refresh notifications list
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Foreground receipt: rely on local insert (onNotificationModel) to avoid race with backend persistence
      OneSignalService.onForegroundNotification = () {};
      OneSignalService.onNotificationOpened = () {
        final ctx = navigatorKey.currentContext;
        if (ctx != null) {
          Provider.of<NotificationProvider>(ctx, listen: false)
              .fetchRecentNotifications();
        }
      };
      // Insert incoming push immediately to UI
      OneSignalService.onNotificationModel = (notification) {
        final ctx = navigatorKey.currentContext;
        if (ctx != null) {
          Provider.of<NotificationProvider>(ctx, listen: false)
              .addIncomingNotification(notification);
        }
      };
    });
  }

  Future<void> _initializeCache() async {
    try {
      final SyncService syncService = SyncService();
      await syncService.initializeApp();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Cache initialization error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Set system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    // Return the app content directly since providers are already created in main()
    return MyAppContent(seenIntro: widget.seenIntro);
  }
}

class MyAppContent extends StatelessWidget {
  final bool seenIntro;
  const MyAppContent({super.key, required this.seenIntro});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VET DICT+',
      navigatorKey: navigatorKey,
      locale: languageProvider.currentLocale,
      theme: themeProvider.theme.copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
      ),
      supportedLocales: const [
        Locale('ku'), // Kurdish
        Locale('en'), // English
        Locale('ar', 'IQ'), // Arabic for RTL support
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supportedLocales) {
        // Use Arabic as the fallback for RTL support when Kurdish is selected
        if (languageProvider.currentLocale.languageCode == 'ku') {
          return const Locale('ar', 'IQ');
        }
        return languageProvider.currentLocale;
      },
      builder: (context, child) {
        final fontSizeProvider = Provider.of<FontSizeProvider>(context);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(fontSizeProvider.fontSize),
          ),
          child: Directionality(
            textDirection: TextDirection.ltr, // Keep LTR layout for UI elements
            child: child!,
          ),
        );
      },
      home: seenIntro ? const HomePage() : const IntroductionPage(),
      routes: {
        '/home': (context) => const HomePage(),
        '/login': (context) => const LoginPage(),
        '/profile': (context) => const ProfilePage(),
        '/quiz': (context) => const QuizPage(),
      },
    );
  }
}



class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<dynamic> _allItems = [];
  List<dynamic> _filteredItems = [];
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  String _selectedFilter = 'All'; // Add this line for filter state
  bool _isDataLoading = true;
  Timer? _apiSearchTimer; // Add _apiSearchTimer field

  int _selectedIndex = 2;
  final bool _showAllItems = false;

  Widget _currentScreen() {
    switch (_selectedIndex) {
      case 0:
        return const FavoritesPage();
      case 1:
        return const HistoryPage();
      case 2:
        return _buildHomeContent();
      case 3:
        return const BooksPage();
      case 4:
        return const ProfilePage();
      case 5:
      default:
        return _buildHomeContent();
    }
  }

  Widget _buildHomeContent() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final contentPadding = isTablet ? 24.0 : 16.0;
    final heroFontSize = isTablet ? 28.0 : 26.0;
    final heroSubFontSize = isTablet ? 17.0 : 16.0;
    final gridCrossAxisCount = isTablet ? 4 : 3;
    final gridChildAspectRatio = isTablet ? 1.0 : 0.95;
    final heroMinHeight = isTablet ? 160.0 : 180.0;

    return Column(
      children: [
            // App Bar
            Container(
              padding: EdgeInsets.symmetric(horizontal: contentPadding, vertical: isTablet ? 14.0 : 12.0),
              decoration: BoxDecoration(
                color: Provider.of<ThemeProvider>(context).theme.scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Consumer<NotificationProvider>(
                    builder: (context, notificationProvider, _) {
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Provider.of<ThemeProvider>(context).theme.colorScheme.primary
                                  .withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.notifications_outlined),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => const NotificationDialog(),
                                );
                              },
                              color: Provider.of<ThemeProvider>(context).theme.colorScheme.primary,
                              padding: EdgeInsets.all(isTablet ? 10 : 8),
                              constraints: const BoxConstraints(),
                              iconSize: isTablet ? 26 : 24,
                            ),
                          ),
                          if (notificationProvider.unreadCount > 0)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Provider.of<ThemeProvider>(context).theme.colorScheme.error,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  notificationProvider.unreadCount > 9 ? '9+' : '${notificationProvider.unreadCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  // Force LTR direction for app title to ensure '+' stays at the end
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      'VET DICT+',
                      style: TextStyle(
                        fontSize: isTablet ? 22 : 20,
                        fontWeight: FontWeight.bold,
                        color: Provider.of<ThemeProvider>(context).isDarkMode
                            ? Colors.white
                            : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Provider.of<ThemeProvider>(context).theme.colorScheme.primary
                          .withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: () {
                        Navigator.push(
                          context,
                          createRoute(
                            const SettingsPage(),
                          ),
                        );
                      },
                      color: Provider.of<ThemeProvider>(context).theme.colorScheme.primary,
                      padding: EdgeInsets.all(isTablet ? 10 : 8),
                      constraints: const BoxConstraints(),
                      iconSize: isTablet ? 26 : 24,
                    ),
                  ),
                ],
              ),
            ),

            // ── TABLET: scrollable body, grid wraps tightly ──────────────────
            if (isTablet)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Search Bar
                      Padding(
                        padding: EdgeInsets.all(contentPadding),
                        child: _buildSearchBar(),
                      ),
                      // Hero Section
                      _buildHeroSection(
                        contentPadding: contentPadding,
                        heroFontSize: heroFontSize,
                        heroSubFontSize: heroSubFontSize,
                        heroMinHeight: heroMinHeight,
                        isTablet: true,
                      ),
                      // Feature Grid – shrinkWrapped, no Expanded
                      Padding(
                        padding: EdgeInsets.all(contentPadding),
                        child: GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: gridCrossAxisCount,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: gridChildAspectRatio,
                          children: [
                            ..._buildFeatureItems(),
                            if (!_showAllItems) _buildShowMoreItem(),
                          ],
                        ),
                      ),
                      // Action Buttons
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: contentPadding,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildActionItem('share.png', 'هاوبەشکردن', Colors.green, onTap: () {
                              Share.share(
                                'VET DICT+ - یەکێک لە باشترین فەرهەنگەکان بۆ خوێندکارانی پزیشکی ڤێتیرنەری.\n\n'
                                'Android: ${AppConstants.androidStoreUrl}\n'
                                'iOS: ${AppConstants.iosStoreUrl}');
                            }),
                            const SizedBox(width: 48),
                            _buildActionItem('star.png', 'هەڵسەنگاندن', Colors.amber, onTap: () async {
                              final url = Uri.parse(
                                  Platform.isAndroid ? AppConstants.androidStoreUrl : AppConstants.iosStoreUrl);
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url, mode: LaunchMode.externalApplication);
                              }
                            }),
                            const SizedBox(width: 48),
                            _buildActionItem('about.png', 'دەربارە', const Color(0xFF4A7EB5), onTap: () {
                              Navigator.push(context, createRoute(const AboutPage()));
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

            // ── PHONE: original non-scrollable layout with Expanded grid ─────
            if (!isTablet) ...[
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildSearchBar(),
              ),
              // Hero Section
              _buildHeroSection(
                contentPadding: 16,
                heroFontSize: 26,
                heroSubFontSize: 16,
                heroMinHeight: 180,
                isTablet: false,
              ),
              // Feature Grid
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        crossAxisCount: 3,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.95,
                        children: [
                          ..._buildFeatureItems(),
                          if (!_showAllItems) _buildShowMoreItem(),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Action Buttons
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionItem('share.png', 'هاوبەشکردن', Colors.green, onTap: () {
                      Share.share(
                          'VET DICT+ - یەکێک لە باشترین فەرهەنگەکان بۆ خوێندکارانی پزیشکی ڤێتیرنەری.\n\n'
                          'Android: ${AppConstants.androidStoreUrl}\n'
                          'iOS: ${AppConstants.iosStoreUrl}');
                    }),
                    _buildActionItem('star.png', 'هەڵسەنگاندن', Colors.amber, onTap: () async {
                      final url = Uri.parse(
                          Platform.isAndroid ? AppConstants.androidStoreUrl : AppConstants.iosStoreUrl);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    }),
                    _buildActionItem('about.png', 'دەربارە', const Color(0xFF4A7EB5), onTap: () {
                      Navigator.push(context, createRoute(const AboutPage()));
                    }),
                  ],
                ),
              ),
            ],
          ],
    );
  }

  /// Shared hero banner widget used by both tablet and phone layouts.
  Widget _buildHeroSection({
    required double contentPadding,
    required double heroFontSize,
    required double heroSubFontSize,
    required double heroMinHeight,
    required bool isTablet,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: contentPadding, vertical: isTablet ? 0 : 16),
      constraints: BoxConstraints(minHeight: heroMinHeight),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: Provider.of<ThemeProvider>(context).isDarkMode
              ? const [Color(0xFF1A3460), Color(0xFF1E2D4A)]
              : [
                  Provider.of<ThemeProvider>(context).theme.colorScheme.primary,
                  Provider.of<ThemeProvider>(context).theme.colorScheme.primary.withValues(alpha: 0.8),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Provider.of<ThemeProvider>(context).isDarkMode
                ? const Color(0xFF1A3460).withValues(alpha: 0.5)
                : Provider.of<ThemeProvider>(context).theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Container(
              width: isTablet ? 180 : 150,
              height: isTablet ? 180 : 150,
              decoration: BoxDecoration(
                color: Provider.of<ThemeProvider>(context).theme.scaffoldBackgroundColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isTablet ? 28 : 24),
            child: Column(
              crossAxisAlignment: Provider.of<LanguageProvider>(context).isRTL
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Directionality(
                  textDirection: Provider.of<LanguageProvider>(context).textDirection,
                  child: Text(
                    'بەخێربێن بۆ +VET DICT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: heroFontSize,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                    textAlign: Provider.of<LanguageProvider>(context).isRTL ? TextAlign.right : TextAlign.left,
                  ),
                ),
                const SizedBox(height: 8),
                Directionality(
                  textDirection: Provider.of<LanguageProvider>(context).textDirection,
                  child: Text(
                    'یەکێک لە باشترین فەرهەنگەکان بۆ خوێندکارانی پزیشکی ڤێتیرنەری.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: heroSubFontSize,
                      height: 1.3,
                    ),
                    textAlign: Provider.of<LanguageProvider>(context).isRTL ? TextAlign.right : TextAlign.left,
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Provider.of<LanguageProvider>(context).isRTL
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(context, createRoute(const IntroductionPage()));
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 24 : 20,
                        vertical: isTablet ? 12 : 10,
                      ),
                      decoration: BoxDecoration(
                        color: Provider.of<ThemeProvider>(context).isDarkMode
                            ? Colors.white
                            : Provider.of<ThemeProvider>(context).theme.scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Directionality(
                        textDirection: Provider.of<LanguageProvider>(context).textDirection,
                        child: Text(
                          'دەستپێکردن',
                          style: TextStyle(
                            color: Provider.of<ThemeProvider>(context).isDarkMode
                                ? const Color(0xFF1A3460)
                                : Provider.of<ThemeProvider>(context).theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: isTablet ? 15 : 14,
                          ),
                          textAlign: Provider.of<LanguageProvider>(context).isRTL ? TextAlign.right : TextAlign.left,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFeatureItems() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;

    final List<Map<String, dynamic>> allFeatures = [
      {
        'id': 'drugs',
        'icon': 'Drugs.png',
        'title': 'دەرمانەکان',
        'color': const Color(0xFF1A3460)
      },
      {
        'id': 'diseases',
        'icon': 'Diseases.png',
        'title': 'نەخۆشیەکان',
        'color': const Color(0xFF16A34A)
      },
      {
        'id': 'terminology',
        'icon': 'Terminology.png',
        'title': 'زاراوەکان',
        'color': const Color(0xFFEAB308)
      },
      {
        'id': 'tests',
        'icon': 'tests.png',
        'title': 'پشکنینەکان',
        'color': const Color(0xFFDB2777)
      },
      {
        'id': 'slides',
        'icon': 'slide.png',
        'title': 'سڵایدەکان',
        'color': const Color(0xFF475569)
      },
      {
        'id': 'normal_range',
        'icon': 'Normalrange.png',
        'title': 'پێوانە ئاساییەکان',
        'color': const Color(0xFF0891B2)
      },
      {
        'id': 'instruments',
        'icon': 'insturments.png',
        'title': 'کەرەستە پزیشکیەکان',
        'color': const Color(0xFF7C3AED)
      },
      {
        'id': 'notes',
        'icon': 'Note.png',
        'title': 'تێبینیەکان',
        'color': const Color(0xFFDC2626)
      },
      {
        'id': 'haematology',
        'icon': 'Haematology.png',
        'title': 'haematology',
        'color': const Color(0xFFEF4444)
      },
      {
        'id': 'serology',
        'icon': 'Serology.png',
        'title': 'serology',
        'color': const Color(0xFF10B981)
      },
      {
        'id': 'biochemistry',
        'icon': 'Biochemistry.png',
        'title': 'biochemistry',
        'color': const Color(0xFFF59E0B)
      },
      {
        'id': 'bacteriology',
        'icon': 'Bacteriology.png',
        'title': 'bacteriology',
        'color': const Color(0xFF8B5CF6)
      },
      {
        'id': 'quiz',
        'icon': 'quiz.png',
        'title': 'تاقیکردنەوە',
        'color': const Color(0xFF8B5CF6)
      },
    ];

    // On tablet show one extra item before "more" to fill the 4-column row
    final itemsToShow = _showAllItems ? allFeatures.length : (isTablet ? 7 : 5);
    final displayedFeatures = allFeatures.take(itemsToShow).toList();

    return displayedFeatures.map((feature) => _buildFeatureItem(
        feature['icon'] as String,
        feature['title'] as String,
        feature['color'] as Color,
        id: feature['id'] as String,
        inBottomSheet: false)).toList();
  }

  @override
  void initState() {
    super.initState();
    _fetchAllData();
    // Initialize notifications on app start
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      Provider.of<NotificationProvider>(context, listen: false)
          .fetchRecentNotifications();
      
      // Show first-time notification permission prompt after UI settles
      // This is Play Store compliant because we show rationale dialog BEFORE requesting permission
      await Future.delayed(const Duration(milliseconds: 1500));
      
      if (!mounted) return;
      
      final shouldShow = await NotificationPermissionService.shouldShowFirstTimePrompt();
      if (shouldShow && mounted) {
        await NotificationPermissionService.showFirstTimePrompt(context);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _apiSearchTimer?.cancel(); // Add _apiSearchTimer cancel
    _removeOverlay();
    super.dispose();
  }

  Future<void> _fetchAllData() async {
    try {
      // Init SharedPreferences cache (fast, just gets the singleton)
      final cacheService = CacheService();
      await cacheService.init();

      // Read directly from SharedPreferences cache — instant, no API calls
      final drugsData = cacheService.getCachedDrugs();
      final diseasesData = cacheService.getCachedDiseases();
      final termsData = cacheService.getCachedDictionary();
      final normalRangesData = cacheService.getCachedNormalRanges();
      final notesData = cacheService.getCachedNotes();

      final drugs = drugsData.map((drug) => {
        'id': drug.id,
        'name': drug.name,
        'kurdish': drug.kurdish,
        'arabic': '',
        'usage': drug.usage,
        'sideEffect': drug.sideEffect,
        'otherInfo': drug.otherInfo,
        'description': drug.description,
        'drugClass': drug.drugClass,
        'type': 'drug',
      }).toList();

      final diseases = diseasesData.map((disease) => {
        'id': disease.id,
        'name': disease.name,
        'kurdish': disease.kurdish,
        'arabic': '',
        'cause': disease.cause,
        'control': disease.control,
        'symptoms': disease.symptoms,
        'category': disease.category,
        'imageUrl': disease.imageUrl,
        'type': 'disease',
      }).toList();

      final terms = termsData.map((term) => {
        'id': term.id,
        'name': term.name,
        'kurdish': term.kurdish,
        'arabic': term.arabic,
        'description': term.description,
        'type': 'terminology',
      }).toList();

      final normalRanges = normalRangesData.map((range) => {
        'id': range.id,
        'name': range.name,
        'kurdish': '',
        'arabic': '',
        'parameter': range.parameter,
        'category': range.category,
        'species': range.species,
        'unit': range.unit,
        'type': 'normal_range',
      }).toList();

      final notes = notesData.map((note) => {
        'id': note.name,
        'name': note.name,
        'kurdish': '',
        'arabic': '',
        'description': note.description ?? '',
        'type': 'note',
      }).toList();

      if (!mounted) return;

      final combinedItems = [...drugs, ...diseases, ...terms, ...normalRanges, ...notes];

      setState(() {
        _allItems = combinedItems;
        _filteredItems = [];
        _isDataLoading = false;
      });

      // Re-run search if user already typed while loading
      final currentQuery = _searchController.text;
      if (currentQuery.isNotEmpty) {
        _filterItems(currentQuery);
      }

      // If any data type is missing from cache, fetch from API in background
      if (combinedItems.isEmpty || normalRangesData.isEmpty || notesData.isEmpty) {
        _fetchAllDataFromApi();
      }

    } catch (e) {
      if (kDebugMode) debugPrint('Error loading search data from cache: $e');
      if (!mounted) return;
      setState(() => _isDataLoading = false);
      // Try API as fallback
      _fetchAllDataFromApi();
    }
  }

  Future<void> _fetchAllDataFromApi() async {
    try {
      final syncService = SyncService();
      await syncService.initializeApp();

      final drugsData = await syncService.loadCategoryData<Drug>('drugs');
      final diseasesData = await syncService.loadCategoryData<Disease>('diseases');
      final termsData = await syncService.loadCategoryData<Word>('dictionary');

      List<NormalRange> normalRangesData = [];
      List<Note> notesData = [];
      try { normalRangesData = await syncService.loadCategoryData<NormalRange>('normal_ranges'); } catch (_) {}
      try { notesData = await syncService.loadCategoryData<Note>('notes'); } catch (_) {}

      if (!mounted) return;

      final combinedItems = [
        ...drugsData.map((d) => {'id': d.id, 'name': d.name, 'kurdish': d.kurdish, 'arabic': '', 'usage': d.usage, 'sideEffect': d.sideEffect, 'otherInfo': d.otherInfo, 'description': d.description, 'drugClass': d.drugClass, 'type': 'drug'}),
        ...diseasesData.map((d) => {'id': d.id, 'name': d.name, 'kurdish': d.kurdish, 'arabic': '', 'cause': d.cause, 'control': d.control, 'symptoms': d.symptoms, 'category': d.category, 'imageUrl': d.imageUrl, 'type': 'disease'}),
        ...termsData.map((t) => {'id': t.id, 'name': t.name, 'kurdish': t.kurdish, 'arabic': t.arabic, 'description': t.description, 'type': 'terminology'}),
        ...normalRangesData.map((r) => {'id': r.id, 'name': r.name, 'kurdish': '', 'arabic': '', 'parameter': r.parameter, 'category': r.category, 'species': r.species, 'unit': r.unit, 'type': 'normal_range'}),
        ...notesData.map((n) => {'id': n.name, 'name': n.name, 'kurdish': '', 'arabic': '', 'description': n.description ?? '', 'type': 'note'}),
      ];

      setState(() {
        _allItems = combinedItems;
        _filteredItems = [];
        _isDataLoading = false;
      });

      final currentQuery = _searchController.text;
      if (currentQuery.isNotEmpty) {
        _filterItems(currentQuery);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Background API load failed: $e');
      if (mounted) setState(() => _isDataLoading = false);
    }
  }

  void _searchApiDirectly(String query) {
    _apiSearchTimer?.cancel();
    _apiSearchTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      final apiService = ApiService();
      // Search dictionary, drugs, and diseases in parallel
      final results = await Future.wait([
        apiService.searchDictionary(query, limit: 30),
        apiService.fetchAllDrugs().then((drugs) =>
            drugs.where((d) => (d.name).toLowerCase().contains(query.toLowerCase())).toList()),
        apiService.fetchAllDiseases().then((diseases) =>
            diseases.where((d) => (d.name).toLowerCase().contains(query.toLowerCase())).toList()),
      ]);
      if (!mounted || _searchController.text != query) return;
      final words = results[0] as List;
      final drugs = results[1] as List;
      final diseases = results[2] as List;
      final combined = [
        ...words.map((w) => {'id': w.id, 'name': w.name, 'kurdish': w.kurdish, 'arabic': w.arabic, 'description': w.description, 'type': 'terminology'}),
        ...drugs.map((d) => {'id': d.id, 'name': d.name, 'kurdish': d.kurdish, 'arabic': '', 'usage': d.usage, 'sideEffect': d.sideEffect, 'otherInfo': d.otherInfo, 'description': d.description, 'drugClass': d.drugClass, 'type': 'drug'}),
        ...diseases.map((d) => {'id': d.id, 'name': d.name, 'kurdish': d.kurdish, 'arabic': '', 'cause': d.cause, 'control': d.control, 'symptoms': d.symptoms, 'category': d.category, 'imageUrl': d.imageUrl, 'type': 'disease'}),
      ];
      setState(() => _filteredItems = combined);
      if (combined.isNotEmpty) _showSearchResults();
    });
  }

  void _filterItems(String query) {
    if (query.isEmpty) {
      _apiSearchTimer?.cancel();
      setState(() {
        _filteredItems = [];
      });
      _removeOverlay();
      return;
    }

    // If no local cache yet (first install), search API directly
    if (_allItems.isEmpty) {
      _searchApiDirectly(query); // Add _searchApiDirectly call
      return;
    }

    if (kDebugMode) {
      debugPrint('Searching for: "$query" in ${_allItems.length} items');
    }

    setState(() {
      _filteredItems = _allItems.where((item) {
        final name = (item['name'] ?? '').toLowerCase();
        final kurdish = (item['kurdish'] ?? '').toLowerCase();
        final arabic = (item['arabic'] ?? '').toLowerCase();
        final searchQuery = query.toLowerCase();

        // Apply category filter
        if (_selectedFilter != 'All') {
          final itemType = item['type']?.toLowerCase() ?? '';
          final filterType = _selectedFilter.toLowerCase();

          // Check if item matches the selected filter
          bool matchesFilter = false;
          switch (filterType) {
            case 'drugs':
              matchesFilter = itemType == 'drug';
              break;
            case 'diseases':
              matchesFilter = itemType == 'disease';
              break;
            case 'terminology':
              matchesFilter = itemType == 'terminology';
              break;
            case 'instruments':
              matchesFilter = itemType == 'instrument';
              break;
            case 'normal ranges':
              matchesFilter = itemType == 'normal_range';
              break;
            case 'books':
              matchesFilter = itemType == 'book';
              break;
            case 'notes':
              matchesFilter = itemType == 'note';
              break;
            case 'slides':
              matchesFilter = itemType == 'slide';
              break;
            case 'tests':
              matchesFilter = itemType == 'test';
              break;
            default:
              matchesFilter = true;
          }

          if (!matchesFilter) {
            return false;
          }
        }

        final matches = name.contains(searchQuery) || 
               kurdish.contains(searchQuery) || 
               arabic.contains(searchQuery);

        return matches;
      }).toList();
      
      if (kDebugMode) {
        debugPrint('Found ${_filteredItems.length} results for "$query"');
      }
    });

    _showSearchResults();
  }

  void _showSearchResults() {
    _removeOverlay();

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width - 32,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0.0, 48.0),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(
                maxHeight: 200,
              ),
              decoration: BoxDecoration(
                color: Provider.of<ThemeProvider>(context).theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _filteredItems.length,
                itemBuilder: (context, index) {
                  final item = _filteredItems[index];
                  return ListTile(
                    leading: Icon(_getIconForType(item['type'])),
                    title: Text(item['name']),
                    subtitle: Text(_getSubtitleForItem(item)),
                    onTap: () {
                      _removeOverlay();
                      _searchController.clear();
                      _navigateToDetails(item);
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'drug':
        return Icons.medical_services_outlined;
      case 'disease':
        return Icons.healing_outlined;
      case 'terminology':
        return Icons.book_outlined;
      case 'instrument':
        return Icons.medical_services_outlined;
      case 'normal_range': 
        return Icons.list_alt_outlined;
      case 'note':
        return Icons.note;
      case 'book':
        return Icons.book;
      case 'slide':
        return Icons.image;
      case 'test':
        return Icons.science;
      default:
        return Icons.search;
    }
  }

  String _getSubtitleForItem(Map<String, dynamic> item) {
    switch (item['type']) {
      case 'drug':
        return item['category'] ?? 'Drug';
      case 'disease':
        return item['kurdish'] ?? item['category'] ?? 'Disease';
      case 'terminology':
        return item['kurdish'] ?? item['arabic'] ?? 'Term';
      case 'instrument':
        return item['category'] ?? 'Instrument';
      case 'normal_range': 
        return item['species'] ?? item['category'] ?? 'Normal Range';
      case 'note':
        return 'Note';
      case 'book':
        return item['author'] ?? 'Book';
      case 'slide':
        return item['species'] ?? 'Slide';
      case 'test':
        return 'Test';
      default:
        return '';
    }
  }

  void _navigateToDetails(Map<String, dynamic> item) {
  // Unfocus search field before navigation to prevent keyboard from showing when returning
  if (_searchFocusNode.hasFocus) {
    _searchFocusNode.unfocus();
  }

  if (item['type'] == 'drug') {
      if (!context.mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => DrugDetailsPage(
          drug: Drug(
            id: item['id'],
            name: item['name'],
            kurdish: item['kurdish'],
            usage: item['usage'],
            sideEffect: item['sideEffect'],
            otherInfo: item['otherInfo'],
            description: item['description'],
            drugClass: item['drugClass'],
            category: item['category'] ?? '',
            imageUrl: item['imageUrl'] ?? '',
          ),
        ),
      ));
    } else if (item['type'] == 'disease') {
      if (!context.mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => DiseaseDetailsPage(
          disease: Disease(
            id: item['id'],
            name: item['name'],
            cause: item['cause'],
            control: item['control'],
            kurdish: item['kurdish'],
            symptoms: item['symptoms'],
            category: item['category'],
            imageUrl: item['imageUrl'] ?? '',
          ),
        ),
      ));
    } else if (item['type'] == 'terminology') {
      if (!context.mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => TerminologyDetailsPage(
          terminology: Word(
            id: item['id'],
            name: item['name'],
            kurdish: item['kurdish'],
            arabic: item['arabic'],
            description: item['description'],
          ),
        ),
      ));
    } else if (item['type'] == 'normal_range') { 
      if (!context.mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => const NormalRangesPage(),
      ));
    } else if (item['type'] == 'instrument') {
      if (!context.mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => const InstrumentsPage(),
      ));
    } else if (item['type'] == 'note') {
      if (!context.mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => NoteDetailsPage(
          note: Note(
            name: item['name'],
            description: item['description'],
            imageUrl: item['imageUrl'],
            category: item['category'],
          ),
          isEditable: false,
          showHeaderImage: true,
        ),
      ));
    } else if (item['type'] == 'book') {
      if (!context.mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => const BooksPage(),
      ));
    } else if (item['type'] == 'slide') {
      if (!context.mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => const SlidesPage(initialCategory: 'All'),
      ));
    } else if (item['type'] == 'test') {
      if (!context.mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => const TestsPage(initialCategory: 'All'),
      ));
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildSearchBar() {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Provider.of<ThemeProvider>(context).theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Provider.of<ThemeProvider>(context).isDarkMode
                ? Provider.of<ThemeProvider>(context).theme.colorScheme.onSurface
                    .withValues(alpha: 0.12)
                : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Directionality(
          textDirection: Provider.of<LanguageProvider>(context).textDirection,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _isDataLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Provider.of<ThemeProvider>(context).isDarkMode
                                ? Colors.white.withValues(alpha: 0.6)
                                : Colors.grey,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.search,
                        color: Provider.of<ThemeProvider>(context).isDarkMode
                            ? Colors.white.withValues(alpha: 0.6)
                            : Colors.grey,
                      ),
              ),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: _filterItems,
                  autofocus: false,
                  textDirection: Provider.of<LanguageProvider>(context).textDirection,
                  decoration: InputDecoration(
                    hintText: 'گەڕان...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      color: Provider.of<ThemeProvider>(context).isDarkMode
                          ? Colors.white.withValues(alpha: 0.6)
                          : Colors.grey,
                    ),
                  ),
                  style: TextStyle(
                    color: Provider.of<ThemeProvider>(context).isDarkMode
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
              ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  _searchController.clear();
                  _filterItems('');
                },
                color: Provider.of<ThemeProvider>(context).isDarkMode
                    ? Colors.white.withValues(alpha: 0.6)
                    : Colors.grey,
              ),
            Container(
              height: 24,
              width: 1,
              color: Provider.of<ThemeProvider>(context).isDarkMode
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.grey.withValues(alpha: 0.2),
              margin: const EdgeInsets.symmetric(horizontal: 8),
            ),
            Stack(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.filter_list,
                    color: Provider.of<ThemeProvider>(context).isDarkMode
                        ? Colors.white.withValues(alpha: 0.6)
                        : Colors.grey,
                  ),
                  onPressed: () => _showFilterOptions(context),
                ),
                if (_selectedFilter != 'All')
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          ),
        ),
      ),
    );
  }

  void _showFilterOptions(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  Text(
                    'فلتەرکردن',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() => _selectedFilter = 'All');
                          _filterItems(_searchController.text);
                          Navigator.pop(context);
                        },
                        child: _buildFilterOption('هەموو', Icons.apps_rounded, const Color(0xFF4A7EB5), 'All'),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() => _selectedFilter = 'Drugs');
                          _filterItems(_searchController.text);
                          Navigator.pop(context);
                        },
                        child: _buildFilterOption('دەرمانەکان', Icons.medication, Colors.green, 'Drugs'),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() => _selectedFilter = 'Diseases');
                          _filterItems(_searchController.text);
                          Navigator.pop(context);
                        },
                        child: _buildFilterOption('نەخۆشیەکان', Icons.medical_services, Colors.orange, 'Diseases'),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() => _selectedFilter = 'Terminology');
                          _filterItems(_searchController.text);
                          Navigator.pop(context);
                        },
                        child: _buildFilterOption('زاراوەکان', Icons.menu_book, Colors.purple, 'Terminology'),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() => _selectedFilter = 'Normal Ranges');
                          _filterItems(_searchController.text);
                          Navigator.pop(context);
                        },
                        child: _buildFilterOption('پێوانە ئاساییەکان', Icons.list_alt_outlined, Colors.cyan.shade700, 'Normal Ranges'), 
                      ),
                      InkWell(
                        onTap: () {
                          setState(() => _selectedFilter = 'Notes');
                          _filterItems(_searchController.text);
                          Navigator.pop(context);
                        },
                        child: _buildFilterOption('تێبینیەکان', Icons.note, Colors.amber, 'Notes'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(String text, IconData icon, Color color, String filterKey) {
    final isDarkMode = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isSelected = _selectedFilter == filterKey;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected
            ? themeProvider.theme.colorScheme.primary
            : isDarkMode
                ? const Color(0xFF303030)
                : Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? themeProvider.theme.colorScheme.primary
              : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: themeProvider.theme.colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Directionality(
        textDirection: languageProvider.textDirection,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : isDarkMode
                      ? Colors.grey[400]
                      : Colors.grey[700],
            ),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : isDarkMode
                        ? Colors.grey[300]
                        : Colors.grey[800],
              ),
              textAlign: languageProvider.isRTL ? TextAlign.right : TextAlign.left,
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.check_circle,
                size: 14,
                color: Colors.white,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(dynamic icon, String title, Color color,
      {required String id, bool inBottomSheet = false}) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final iconSize = isTablet ? 36.0 : 32.0;
    final labelFontSize = isTablet ? 13.0 : 14.0;

    Widget iconWidget;
    if (icon is IconData) {
      iconWidget = Icon(
        icon,
        size: iconSize,
        color: color,
      );
    } else if (icon is String) {
      iconWidget = Image.asset(
        'assets/Icons/$icon',
        width: iconSize,
        height: iconSize,
        color: color,
      );
    } else {
      iconWidget = const SizedBox(); // Fallback empty widget
    }

    return InkWell(
      onTap: () {
        // Unfocus search field before navigation to prevent keyboard from showing when returning
        if (_searchFocusNode.hasFocus) {
          _searchFocusNode.unfocus();
        }

        if (id == 'drugs') {
          Navigator.push(
            context,
            createRoute(const DrugsPage()),
          );
        } else if (id == 'diseases') {
          Navigator.push(
            context,
            createRoute(const DiseasesPage()),
          );
        } else if (id == 'terminology') {
          Navigator.push(
            context,
            createRoute(const TerminologyPage()),
          );
        } else if (id == 'tests') {
          _showTestsBottomSheet();
        } else if (id == 'slides') {
          _showSlidesBottomSheet();
        } else if (id == 'notes') {
          Navigator.push(
            context,
            createRoute(const NotesPage()),
          );
        } else if (id == 'books') {
          Navigator.push(
            context,
            createRoute(const BooksPage()),
          );
        } else if (id == 'normal_range') { 
          Navigator.push(context, createRoute(const NormalRangesPage())); 
        } else if (id == 'instruments') {
          Navigator.push(
            context,
            createRoute(const InstrumentsPage()),
          );
        } else if (id == 'settings') {
          Navigator.push(
            context,
            createRoute(const SettingsPage()),
          );
        } else if (id == 'quiz') {
          Navigator.push(
            context,
            createRoute(const QuizPage()),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: themeProvider.isDarkMode
              ? (inBottomSheet
                  ? themeProvider.theme.colorScheme.surface
                  : themeProvider.theme.colorScheme.surface)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withValues(alpha: themeProvider.isDarkMode ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: iconWidget,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Directionality(
                    textDirection: languageProvider.textDirection,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: labelFontSize,
                        color: themeProvider.isDarkMode
                            ? Colors.white
                            : const Color(0xFF1E293B),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionItem(dynamic icon, String label, Color color, {VoidCallback? onTap}) {
    Provider.of<LanguageProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
  
    Widget iconWidget;
    if (icon is IconData) {
      iconWidget = Icon(
        icon,
        color: color,
        size: 24,
      );
    } else if (icon is String) {
      iconWidget = Image.asset(
        'assets/Icons/$icon',
        width: 24,
        height: 24,
        color: color,
      );
    } else {
      iconWidget = const SizedBox();
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: themeProvider.isDarkMode
                  ? color.withValues(alpha: 0.2)
                  : color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: iconWidget,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: themeProvider.isDarkMode
                  ? Colors.white.withValues(alpha: 0.87)
                  : const Color(0xFF475569),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShowMoreItem() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    Provider.of<LanguageProvider>(context);
    const Color moreColor = Color(0xFF4A7EB5);
    return Container(
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode
            ? themeProvider.theme.colorScheme.surface
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: themeProvider.isDarkMode ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            _showMoreBottomSheet();
          },
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: moreColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.more_horiz,
                        color: moreColor,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Text(
                      'زیاتر',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: themeProvider.isDarkMode
                            ? Colors.white
                            : const Color(0xFF1E293B),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMoreBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        Provider.of<LanguageProvider>(context);
        final themeProvider = Provider.of<ThemeProvider>(context);
        final screenWidth = MediaQuery.of(context).size.width;
        final isTablet = screenWidth >= 600;
        final sheetHeight = MediaQuery.of(context).size.height * (isTablet ? 0.92 : 0.75);
        final crossAxisCount = isTablet ? 4 : 3;

        return Container(
          height: sheetHeight,
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
                  'هەموو تایبەتمەندییەکان',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.isDarkMode
                        ? Colors.white
                        : const Color(0xFF1E293B),
                  ),
                ),
              ),
              Expanded(
                child: GridView.count(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.9,
                  children: [
                    _buildFeatureItem('Drugs.png', 'دەرمانەکان',
                        const Color(0xFF1A3460),
                        id: 'drugs', inBottomSheet: true),
                    _buildFeatureItem('Diseases.png', 'نەخۆشیەکان',
                        const Color(0xFF16A34A),
                        id: 'diseases', inBottomSheet: true),
                    _buildFeatureItem('Terminology.png', 'زاراوەکان',
                        const Color(0xFFEAB308),
                        id: 'terminology', inBottomSheet: true),
                    _buildFeatureItem('tests.png', 'پشکنینەکان',
                        const Color(0xFFDB2777),
                        id: 'tests', inBottomSheet: true),
                    _buildFeatureItem('slide.png', 'سڵایدەکان',
                        const Color(0xFF475569),
                        id: 'slides', inBottomSheet: true),
                    _buildFeatureItem('Normalrange.png', 'پێوانە ئاساییەکان',
                        const Color(0xFF0891B2),
                        id: 'normal_range', inBottomSheet: true),
                    _buildFeatureItem('insturments.png', 'کەرەستە پزیشکیەکان',
                        const Color(0xFF7C3AED),
                        id: 'instruments', inBottomSheet: true),
                    _buildFeatureItem(
                        'Note.png', 'تێبینیەکان', const Color(0xFFDC2626),
                        id: 'notes', inBottomSheet: true),
                    _buildFeatureItem(
                        'books.png', 'کتێبەکان', const Color.fromARGB(255, 117, 25, 203),
                        id: 'books', inBottomSheet: true),
                    _buildFeatureItem(
                        "quiz.png", 'تاقیکردنەوە', const Color(0xFF8B5CF6),
                        id: 'quiz', inBottomSheet: true),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSlidesBottomSheet() {
    final List<Map<String, dynamic>> slideCategories = [
      {
        'name': 'Urin slide',
        'icon': 'Urinslide.png',
        'type': 'Urine',
      },
      {
        'name': 'Stool slide',
        'icon': 'Stoolslide.png',
        'type': 'Stool',
      },
      {
        'name': 'Others',
        'icon': Icons.more_horiz_outlined,
        'type': 'Other',
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final themeProvider = Provider.of<ThemeProvider>(context);
        Provider.of<LanguageProvider>(context);

        return Container(
          height: MediaQuery.of(context).size.height * 0.3,
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
                  'پۆلەکانی سلاید',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.isDarkMode
                        ? Colors.white
                        : const Color(0xFF1E293B),
                  ),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: slideCategories.length,
                  itemBuilder: (context, index) {
                    final category = slideCategories[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: themeProvider.isDarkMode
                            ? themeProvider.theme.colorScheme.surface
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha:
                                themeProvider.isDarkMode ? 0.3 : 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            final type = (category['type'] as String?) ?? 'Other';
                            // Close the bottom sheet before navigating
                            Navigator.pop(context);
                            Navigator.of(context).push(
                              createRoute(SlidesPage(initialCategory: type)),
                            );
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00B4A2).withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: category['icon'] is IconData
                                    ? Icon(
                                        category['icon'] as IconData,
                                        color: const Color(0xFF00B4A2),
                                        size: 28,
                                      )
                                    : Image.asset(
                                        'assets/Icons/${category['icon']}',
                                        color: const Color(0xFF00B4A2),
                                        width: 28,
                                        height: 28,
                                      ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  category['name'] as String,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: themeProvider.isDarkMode
                                        ? Colors.white
                                        : const Color(0xFF1E293B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTestsBottomSheet() {
    final List<Map<String, dynamic>> testCategories = [
      {
        'name': 'Haematology',
        'icon': 'Haematology.png',
      },
      {
        'name': 'Serology',
        'icon': 'Serology.png',
      },
      {
        'name': 'Biochemistry',
        'icon': 'Biochemistry.png',
      },
      {
        'name': 'Bacteriology',
        'icon': 'Bacteriology.png',
      },
      {
        'name': 'Others',
        'icon': Icons.more_horiz_outlined,
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final themeProvider = Provider.of<ThemeProvider>(context);
        Provider.of<LanguageProvider>(context);

        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
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
                  'پشکنینە تاقیگەییەکان',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.isDarkMode
                        ? Colors.white
                        : const Color(0xFF1E293B),
                  ),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: testCategories.length,
                  itemBuilder: (context, index) {
                    final category = testCategories[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: themeProvider.isDarkMode
                            ? themeProvider.theme.colorScheme.surface
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                                alpha: themeProvider.isDarkMode ? 0.3 : 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.pop(context); // Close the bottom sheet
                            // Navigate to TestsPage with the selected category
                            Navigator.push(
                              context,
                              createRoute(
                                TestsPage(
                                  initialCategory: category['name'] as String,
                                ),
                              ),
                            );
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00B4A2).withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: category['icon'] is IconData
                                    ? Icon(
                                        category['icon'] as IconData,
                                        color: const Color(0xFF00B4A2),
                                        size: 28,
                                      )
                                    : Image.asset(
                                        'assets/Icons/${category['icon']}',
                                        color: const Color(0xFF00B4A2),
                                        width: 28,
                                        height: 28,
                                      ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  category['name'] as String,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: themeProvider.isDarkMode
                                        ? Colors.white
                                        : const Color(0xFF1E293B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _onWillPop() async {
    // If not on home tab (index 2), navigate to home tab
    if (_selectedIndex != 2) {
      setState(() {
        _selectedIndex = 2;
      });
      return false; // Don't exit
    }
    
    // If on home tab, show exit confirmation dialog
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isRTL = languageProvider.isRTL;
    
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Dialog(
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: themeProvider.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: themeProvider.theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.exit_to_app_rounded,
                  size: 32,
                  color: themeProvider.theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              
              // Title
              Text(
                isRTL ? 'دەرچوون' : 'Exit App',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
                  fontFamily: isRTL ? 'NRT' : null,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              // Content
              Text(
                isRTL 
                    ? 'دڵنیای دەتەوێت لە بەرنامەکە دەربچیت؟' 
                    : 'Are you sure you want to exit the application?',
                style: TextStyle(
                  fontSize: 16,
                  color: themeProvider.isDarkMode ? Colors.white70 : Colors.black54,
                  height: 1.5,
                  fontFamily: isRTL ? 'NRT' : null,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Actions
              Row(
                children: [
                   Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        // For TextButton, we typically set foregroundColor for text color
                        foregroundColor: themeProvider.isDarkMode ? Colors.white70 : Colors.grey[700],
                      ),
                      child: Text(
                        isRTL ? 'نەخێر' : 'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: isRTL ? 'NRT' : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: themeProvider.theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        isRTL ? 'بەڵێ' : 'Exit',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: isRTL ? 'NRT' : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ) ?? false;
    
    return shouldExit;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    Provider.of<LanguageProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: VetDictUpgradeAlert(
        child: Scaffold(
          body: SafeArea(
            child: _currentScreen(),
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 20.0 : 15.0,
                    vertical: isTablet ? 10 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: themeProvider.theme.scaffoldBackgroundColor,
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 20,
                        color: Colors.black.withValues(alpha: .1),
                      ),
                    ],
                  ),
                  child: GNav(
                    rippleColor: themeProvider.isDarkMode
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.grey[300]!,
                    hoverColor: themeProvider.isDarkMode
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey[100]!,
                    gap: 8,
                    activeColor: Colors.white,
                    iconSize: isTablet ? 22 : 24,
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 20 : 15,
                      vertical: isTablet ? 12 : 10,
                    ),
                    duration: const Duration(milliseconds: 400),
                    tabBackgroundColor: themeProvider.isDarkMode
                        ? const Color(0xFF1A3460)
                        : themeProvider.theme.colorScheme.primary,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    color: themeProvider.isDarkMode
                        ? Colors.white.withValues(alpha: 0.6)
                        : themeProvider.theme.colorScheme.primary,
                    tabs: const [
                      GButton(
                        icon: Icons.favorite_rounded,
                        text: 'دڵخوازەکان',
                      ),
                      GButton(
                        icon: Icons.history_rounded,
                        text: 'مێژوو',
                      ),
                      GButton(
                        icon: Icons.home_rounded,
                        text: 'سەرەکی',
                      ),
                      GButton(
                        icon: Icons.menu_book_rounded,
                        text: 'کتێبەکان',
                      ),
                      GButton(
                        icon: Icons.person_rounded,
                        text: 'پرۆفایل',
                      ),
                    ],
                    selectedIndex: _selectedIndex,
                    onTabChange: (index) {
                      // Unfocus search field to prevent keyboard from showing
                      if (_searchFocusNode.hasFocus) {
                        _searchFocusNode.unfocus();
                      }
                      setState(() {
                        _selectedIndex = index;
                      });
                    },
                  ),
            ),
          ),
        ), // closes Scaffold
      ), // closes VetDictUpgradeAlert
    );
  }
}