import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';
import '../services/encrypted_cache_service.dart';
import '../services/connectivity_service.dart';
import '../models/test.dart';
import '../widgets/offline_banner.dart';
import '../widgets/offline_error_state.dart';
import '../models/note.dart';
import '../providers/history_provider.dart';
import 'note_details_page.dart';
import 'package:vetstan/utils/page_transition.dart';

class TestsPage extends StatefulWidget {
  final String initialCategory;

  const TestsPage({
    Key? key,
    required this.initialCategory,
  }) : super(key: key);

  @override
  State<TestsPage> createState() => _TestsPageState();
}

class _TestsPageState extends State<TestsPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Test> _filteredTests = [];
  List<Test> _allTests = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _isOffline = false;

  bool _isValidHttpUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    try {
      final uri = Uri.parse(url.trim());
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTests();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTests() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final category = widget.initialCategory.toLowerCase();
    final encCache = EncryptedCacheService();

    try {
      final bool online = await ConnectivityService.isOnline();
      if (mounted) setState(() => _isOffline = !online);

      if (online) {
        // Online: fetch from API and cache encrypted
        final apiService = ApiService();
        if (kDebugMode) debugPrint('[TestsPage] Loading tests for category: $category');
        
        final List<Test> tests;
        switch (category) {
          case 'haematology':
            tests = await apiService.fetchHaematologyTests();
            break;
          case 'serology':
            tests = await apiService.fetchSerologyTests();
            break;
          case 'biochemistry':
            tests = await apiService.fetchBiochemistryTests();
            break;
          case 'bacteriology':
            tests = await apiService.fetchBacteriologyTests();
            break;
          default:
            tests = await apiService.fetchOtherTests();
            break;
        }

        // Save to encrypted cache for offline use
        await encCache.saveTests(category, tests.map((t) => t.toJson()).toList());

        if (!mounted) return;
        setState(() {
          _allTests = tests;
          _filteredTests = List.from(tests);
          _isLoading = false;
        });
        if (kDebugMode) debugPrint('[TestsPage] Loaded ${tests.length} tests from API');
      } else {
        // Offline: load from encrypted cache
        final cached = await encCache.loadTests(category);
        final tests = cached.map((json) => Test.fromJson(json)).toList();

        if (!mounted) return;
        if (tests.isNotEmpty) {
          setState(() {
            _allTests = tests;
            _filteredTests = List.from(tests);
            _isLoading = false;
          });
          if (kDebugMode) debugPrint('[TestsPage] Loaded ${tests.length} tests from encrypted cache');
        } else {
          // Offline and no cache — _isOffline is already true, OfflineErrorState will show
          setState(() {
            _hasError = false;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      // API failed — try encrypted cache as fallback
      if (kDebugMode) debugPrint('[TestsPage] API failed, trying cache: $e');
      try {
        final cached = await encCache.loadTests(category);
        final tests = cached.map((json) => Test.fromJson(json)).toList();
        if (!mounted) return;
        if (tests.isNotEmpty) {
          setState(() {
            _allTests = tests;
            _filteredTests = List.from(tests);
            _isLoading = false;
          });
          return;
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _hasError = !_isOffline;
        _isLoading = false;
      });
    }
  }

  void _filterTests(String query) {
    if (!mounted) return;
    
    setState(() {
      if (query.isEmpty) {
        _filteredTests = List.from(_allTests);
      } else {
        final queryLower = query.toLowerCase().trim();
        _filteredTests = _allTests.where((test) {
          return test.name.toLowerCase().contains(queryLower) ||
              (test.description?.toLowerCase().contains(queryLower) ?? false);
        }).toList();
      }
    });
  }

  void _onTestTap(BuildContext context, Test test) {
    try {
      // Convert Test to Note for details page reuse
      final note = Note(
        name: test.name,
        description: test.description,
        imageUrl: _isValidHttpUrl(test.imageUrl) ? test.imageUrl : null,
        category: null,
      );

      // Add to history
      context.read<HistoryProvider>().addToHistory(
        test.name,
        'test',
        'Viewed test details',
      );

      // Navigate to note details page with custom transition
      Navigator.push(
        context,
        createRoute(NoteDetailsPage(note: note, showHeaderImage: false)),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[TestsPage] Error navigating to test details: $e');
      // Show error snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening test details: $e')),
        );
      }
    }
  }

  void _showFullScreenImage(BuildContext context, String imageUrl, String name) {
    Navigator.push(
      context,
      createRoute(
        Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Inter',
              ),
            ),
          ),
          body: Center(
            child: PhotoView(
              imageProvider: CachedNetworkImageProvider(imageUrl),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              loadingBuilder: (_, __) => Center(
                child: LoadingAnimationWidget.threeArchedCircle(
                  color: Colors.white,
                  size: 40,
                ),
              ),
              errorBuilder: (_, __, ___) => const Icon(
                Icons.image_not_supported,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LanguageProvider>(
      builder: (context, themeProvider, languageProvider, _) {
        return Scaffold(
          backgroundColor: themeProvider.isDarkMode
              ? themeProvider.theme.scaffoldBackgroundColor
              : Colors.grey[50],
          appBar: _buildAppBar(themeProvider, languageProvider),
          body: _buildBody(themeProvider, languageProvider),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
  ) {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 4,
      surfaceTintColor: Colors.transparent,
      backgroundColor: themeProvider.isDarkMode
          ? themeProvider.theme.appBarTheme.backgroundColor
          : themeProvider.theme.colorScheme.primary,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: themeProvider.isDarkMode
              ? themeProvider.theme.colorScheme.onSurface
              : Colors.white,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Directionality(
        textDirection: languageProvider.textDirection,
        child: Text(
          widget.initialCategory,
          style: TextStyle(
            color: themeProvider.isDarkMode
                ? themeProvider.theme.colorScheme.onSurface
                : Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
      ),
      centerTitle: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: _buildSearchBar(themeProvider, languageProvider),
      ),
    );
  }

  Widget _buildSearchBar(
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode
            ? const Color(0xFF2C2C2C)
            : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: themeProvider.isDarkMode
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Directionality(
        textDirection: languageProvider.textDirection,
        child: TextField(
          controller: _searchController,
          onChanged: _filterTests,
          style: TextStyle(
            color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
            fontFamily: 'Inter',
          ),
          decoration: InputDecoration(
            hintText: 'گەڕان لە تاقیکردنەوەکان...',
            hintStyle: TextStyle(
              color: themeProvider.isDarkMode
                  ? Colors.grey[600]
                  : Colors.grey[400],
              fontFamily: 'Inter',
            ),
            suffixIcon: languageProvider.isRTL
                ? Icon(
                    Icons.search,
                    color: themeProvider.isDarkMode
                        ? Colors.grey[600]
                        : Colors.grey[400],
                  )
                : null,
            prefixIcon: !languageProvider.isRTL
                ? Icon(
                    Icons.search,
                    color: themeProvider.isDarkMode
                        ? Colors.grey[600]
                        : Colors.grey[400],
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
  ) {
    if (_isOffline && !_isLoading) {
      return Column(
        children: [
          const OfflineBanner(),
          Expanded(child: _buildBodyContent(themeProvider, languageProvider)),
        ],
      );
    }
    return _buildBodyContent(themeProvider, languageProvider);
  }

  Widget _buildBodyContent(
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
  ) {
    if (_isLoading) {
      return Center(
        child: LoadingAnimationWidget.threeArchedCircle(
          color: themeProvider.theme.colorScheme.primary,
          size: 50,
        ),
      );
    }

    if (_hasError) {
      return _buildErrorState(themeProvider, languageProvider);
    }

    if (_filteredTests.isEmpty && _allTests.isNotEmpty) {
      return _buildNoResultsState(themeProvider, languageProvider);
    }

    if (_filteredTests.isEmpty) {
      return _buildEmptyState(themeProvider, languageProvider);
    }

    return RefreshIndicator(
      onRefresh: _loadTests,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        itemCount: _filteredTests.length,
        itemBuilder: (context, index) {
          final test = _filteredTests[index];
          return _buildTestItem(context, test, index + 1, themeProvider, languageProvider);
        },
      ),
    );
  }

  Widget _buildTestItem(
    BuildContext context,
    Test test,
    int itemNumber,
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: themeProvider.isDarkMode
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _onTestTap(context, test),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Directionality(
            textDirection: languageProvider.textDirection,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Numbered badge
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: themeProvider.isDarkMode
                        ? const Color(0xFF1A3460).withValues(alpha: 0.35)
                        : const Color(0xFF1A3460).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: themeProvider.isDarkMode
                          ? const Color(0xFF4A7EB5)
                          : const Color(0xFF1A3460),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      itemNumber.toString(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: themeProvider.isDarkMode
                            ? const Color(0xFF4A7EB5)
                            : const Color(0xFF1A3460),
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ),
                // Title only
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: languageProvider.isRTL ? 8 : 0,
                      left: languageProvider.isRTL ? 0 : 8,
                    ),
                    child: Align(
                      alignment: languageProvider.isRTL
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Text(
                        test.name.isNotEmpty ? test.name : 'Unnamed Test',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.black87,
                          fontFamily: 'Inter',
                        ),
                        textAlign: languageProvider.isRTL
                            ? TextAlign.right
                            : TextAlign.left,
                      ),
                    ),
                  ),
                ),
                // Optional image thumbnail
                if (_isValidHttpUrl(test.imageUrl)) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showFullScreenImage(context, test.imageUrl!, test.name),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: themeProvider.isDarkMode
                            ? Colors.grey[800]
                            : Colors.grey[200],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: test.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Center(
                            child: LoadingAnimationWidget.threeArchedCircle(
                              color: themeProvider.theme.colorScheme.primary,
                              size: 20,
                            ),
                          ),
                          errorWidget: (context, url, error) => Icon(
                            Icons.image_not_supported,
                            color: themeProvider.isDarkMode
                                ? Colors.grey[600]
                                : Colors.grey[400],
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: Colors.red[400]),
            const SizedBox(height: 16),
            Directionality(
              textDirection: languageProvider.textDirection,
              child: Text(
                'هەڵەیەک ڕوویدا لە بارکردنی تاقیکردنەوەکان',
                style: TextStyle(
                  color: themeProvider.isDarkMode
                      ? Colors.grey[400]
                      : Colors.grey[600],
                  fontSize: 16,
                  fontFamily: 'Inter',
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Directionality(
              textDirection: languageProvider.textDirection,
              child: Text(
                'تکایە پشکنینی هێڵی ئینتەرنێت بکە',
                style: TextStyle(
                  color: themeProvider.isDarkMode
                      ? Colors.grey[500]
                      : Colors.grey[500],
                  fontSize: 12,
                  fontFamily: 'Inter',
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTests,
              child: Directionality(
                textDirection: languageProvider.textDirection,
                child: const Text(
                  'هەوڵدانەوە',
                  style: TextStyle(fontFamily: 'Inter'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isOffline)
            OfflineErrorState(onRetry: _loadTests)
          else ...[  
            Icon(
              Icons.science_outlined,
              size: 80,
              color: themeProvider.isDarkMode
                  ? Colors.grey[700]
                  : Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Directionality(
              textDirection: languageProvider.textDirection,
              child: Text(
                'هیچ نەدۆزرایەوە',
                style: TextStyle(
                  color: themeProvider.isDarkMode
                      ? Colors.grey[500]
                      : Colors.grey[500],
                  fontSize: 18,
                  fontFamily: 'Inter',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoResultsState(
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: themeProvider.isDarkMode
                ? Colors.grey[700]
                : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Directionality(
            textDirection: languageProvider.textDirection,
            child: Text(
              'هیچ ئەنجامێک نەدۆزرایەوە بۆ گەڕانەکەت',
              style: TextStyle(
                color: themeProvider.isDarkMode
                    ? Colors.grey[500]
                    : Colors.grey[500],
                fontSize: 18,
                fontFamily: 'Inter',
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Directionality(
            textDirection: languageProvider.textDirection,
            child: Text(
              'تکایە وشەی گەڕان بگۆڕە',
              style: TextStyle(
                color: themeProvider.isDarkMode
                    ? Colors.grey[600]
                    : Colors.grey[400],
                fontSize: 14,
                fontFamily: 'Inter',
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}