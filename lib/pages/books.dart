import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shimmer/shimmer.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../services/connectivity_service.dart';
import '../widgets/offline_banner.dart';
import '../widgets/offline_error_state.dart';

class BooksPage extends StatefulWidget {
  const BooksPage({super.key});

  @override
  State<BooksPage> createState() => _BooksPageState();
}

class _BooksPageState extends State<BooksPage> with SingleTickerProviderStateMixin {
  final List<Map<String, dynamic>> _books = [];
  final List<Map<String, dynamic>> _recentBooks = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _isOffline = false;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<Map<String, dynamic>> _filteredBooks = [];
  String _selectedCategory = 'هەموو کتێبەکان';

  String _getDatabaseCategory(String displayCategory) {
    switch (displayCategory) {
      case 'هەموو کتێبەکان':
        return 'All';
      case 'کتێبە کوردیەکان':
        return 'Kurdish';
      case 'کتێبە عەرەبیەکان':
        return 'Arabic';
      case 'کتێبە ئینگلیزیەکان':
        return 'English';
      default:
        return displayCategory;
    }
  }

  /// Convert any Google Drive viewer/share URL to a direct image URL.
  String _processCoverUrl(String url) {
    if (url.isEmpty) return url;
    // Handle: https://drive.google.com/file/d/ID/view?...
    final match = RegExp(r'drive\.google\.com/file/d/([a-zA-Z0-9_-]+)').firstMatch(url);
    if (match != null) {
      final fileId = match.group(1)!;
      return 'https://drive.google.com/uc?export=view&id=$fileId';
    }
    return url;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _clearStaleCache();
    _loadBooks();
    _loadRecentBooks();
  }

  /// Clear cached books if they contain old-format cover URLs (Google Drive /view links).
  /// This forces a fresh fetch with properly converted URLs.
  Future<void> _clearStaleCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedBooks = prefs.getStringList('books');
      if (cachedBooks != null && cachedBooks.isNotEmpty) {
        final firstBook = Map<String, dynamic>.from(jsonDecode(cachedBooks.first));
        final coverUrl = (firstBook['cover_url'] ?? firstBook['image_url'] ?? firstBook['coverUrl'] ?? '').toString();
        // If the stored cover URL is a Google Drive viewer URL (not already converted), clear cache
        if (coverUrl.contains('drive.google.com/file/d/') || coverUrl.contains('drive.google.com/open')) {
          await prefs.remove('books');
          // Also clear the image cache so old broken image data is re-fetched
          await DefaultCacheManager().emptyCache();
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _removeOverlay();
    super.dispose();
  }

  Future<void> _loadRecentBooks() async {
    final prefs = await SharedPreferences.getInstance();
    final recentBooks = prefs.getStringList('recentBooks') ?? [];
    setState(() {
      _recentBooks.clear();
      _recentBooks.addAll(
        recentBooks.map((book) => Map<String, dynamic>.from(jsonDecode(book))),
      );
    });
  }

  Future<void> _addToRecentBooks(Map<String, dynamic> book) async {
    final prefs = await SharedPreferences.getInstance();
    final recentBooks = prefs.getStringList('recentBooks') ?? [];

    recentBooks.removeWhere((b) {
      final Map<String, dynamic> bookMap = jsonDecode(b);
      return bookMap['id'] == book['id'];
    });

    recentBooks.insert(0, jsonEncode(book));

    if (recentBooks.length > 10) {
      recentBooks.removeLast();
    }

    await prefs.setStringList('recentBooks', recentBooks);
    await _loadRecentBooks();
  }

  void _filterBooks(String query) {
    final dbCategory = _getDatabaseCategory(_selectedCategory);

    setState(() {
      if (query.isEmpty) {
        _filteredBooks = dbCategory == 'All'
            ? List.from(_books)
            : _books.where((book) => book['category'] == dbCategory).toList();
        _removeOverlay();
      } else {
        _filteredBooks = _books.where((book) {
          final title = book['title'].toString().toLowerCase();
          final author = book['author'].toString().toLowerCase();
          final description = book['description'].toString().toLowerCase();
          final searchLower = query.toLowerCase();

          final matchesSearch = title.contains(searchLower) ||
              author.contains(searchLower) ||
              description.contains(searchLower);

          return dbCategory == 'All'
              ? matchesSearch
              : matchesSearch && book['category'] == dbCategory;
        }).toList();
        _showSearchResults();
      }
    });
  }

  void _showSearchResults() {
    _removeOverlay();

    if (_searchController.text.isEmpty || _filteredBooks.isEmpty) {
      return;
    }

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
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _filteredBooks.length,
                itemBuilder: (context, index) {
                  final book = _filteredBooks[index];
                  return ListTile(
                    leading: const Icon(Icons.book_outlined),
                    title: Text(book['title'] ?? ''),
                    subtitle: Text(book['author'] ?? ''),
                    onTap: () {
                      _removeOverlay();
                      _searchController.clear();
                      _addToRecentBooks(book);
                      _openPDF(book['downloadUrl'], book['title']);
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

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildSearchBar() {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          CompositedTransformTarget(
            link: _layerLink,
            child: Directionality(
              textDirection: Provider.of<LanguageProvider>(context).textDirection,
              child: TextField(
                controller: _searchController,
                onChanged: _filterBooks,
                textDirection: Provider.of<LanguageProvider>(context).textDirection,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontFamily: 'Inter',
                ),
                decoration: InputDecoration(
                  hintText: 'گەڕان بۆ کتێب...',
                  hintStyle: TextStyle(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.6)
                        : Colors.grey,
                    fontFamily: 'Inter',
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.6)
                        : Colors.grey,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            _filterBooks('');
                          },
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.6)
                              : Colors.grey,
                        )
                      : null,
                  filled: true,
                  fillColor: isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDarkMode ? Colors.white12 : Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDarkMode ? Colors.white12 : Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDarkMode ? Colors.white24 : Colors.grey.shade400,
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildCategoryChip('هەموو کتێبەکان'),
                _buildCategoryChip('کتێبە کوردیەکان'),
                _buildCategoryChip('کتێبە عەرەبیەکان'),
                _buildCategoryChip('کتێبە ئینگلیزیەکان'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String category) {
    final isSelected = _selectedCategory == category;
    final languageProvider = Provider.of<LanguageProvider>(context);
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Directionality(
          textDirection: languageProvider.textDirection,
          child: Text(
            category,
            style: const TextStyle(
              fontFamily: 'Inter',
            ),
          ),
        ),
        onSelected: (selected) {
          setState(() {
            _selectedCategory = category;
            _filterBooks(_searchController.text);
          });
        },
        backgroundColor: Provider.of<ThemeProvider>(context).isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
        selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
        checkmarkColor: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildBookGrid(List<Map<String, dynamic>> books) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) => _buildBookGridItem(books[index]),
    );
  }

  Widget _buildBookGridItem(Map<String, dynamic> book) {
    return GestureDetector(
      onTap: () {
        _addToRecentBooks(book);
        _openPDF(book['downloadUrl'], book['title']);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Provider.of<ThemeProvider>(context).isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Provider.of<ThemeProvider>(context).isDarkMode
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Builder(builder: (context) {
                  final rawUrl = (book['coverUrl'] ?? '').toString();
                  final coverUrl = _processCoverUrl(rawUrl);
                  final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
                  final placeholderColor = isDark ? const Color(0xFF3A3A3A) : Colors.grey[200]!;

                  if (coverUrl.isEmpty) {
                    return Container(
                      color: placeholderColor,
                      child: Icon(Icons.menu_book_rounded,
                          size: 48, color: isDark ? Colors.white30 : Colors.grey[400]),
                    );
                  }
                  return CachedNetworkImage(
                    imageUrl: coverUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (context, url) => _buildShimmerEffect(),
                    errorWidget: (context, url, error) => Container(
                      color: placeholderColor,
                      child: Icon(Icons.menu_book_rounded,
                          size: 48, color: isDark ? Colors.white30 : Colors.grey[400]),
                    ),
                  );
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Directionality(
                    textDirection: Provider.of<LanguageProvider>(context).textDirection,
                    child: Text(
                      book['title'],
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Inter',
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: Provider.of<LanguageProvider>(context).isRTL 
                          ? TextAlign.right 
                          : TextAlign.left,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Directionality(
                    textDirection: Provider.of<LanguageProvider>(context).textDirection,
                    child: Text(
                      book['author'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                        fontFamily: 'Inter',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: Provider.of<LanguageProvider>(context).isRTL 
                          ? TextAlign.right 
                          : TextAlign.left,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    
    return Scaffold(
      backgroundColor: isDark ? themeProvider.theme.scaffoldBackgroundColor : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : themeProvider.theme.colorScheme.primary,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.white,
        ),
        title: Directionality(
          textDirection: languageProvider.textDirection,
          child: Text(
            'کتێبەکان',
            style: TextStyle(fontFamily: 'Inter', color: isDark ? Colors.white : Colors.white),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        bottom: TabBar(
          labelColor: isDark ? themeProvider.theme.colorScheme.primary : Colors.white,
          unselectedLabelColor: isDark ? Colors.white70 : Colors.white70,
          indicatorColor: isDark ? themeProvider.theme.colorScheme.primary : Colors.white,
          controller: _tabController,
          tabs: [
            Tab(
              child: Directionality(
                textDirection: languageProvider.textDirection,
                child: const Text(
                  'هەموو کتێبەکان',
                  style: TextStyle(fontFamily: 'Inter'),
                ),
              ),
            ),
            Tab(
              child: Directionality(
                textDirection: languageProvider.textDirection,
                child: const Text(
                  'خوێندراوەکان',
                  style: TextStyle(fontFamily: 'Inter'),
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          if (_isOffline && !_isLoading) const OfflineBanner(),
          Expanded(child: _isLoading
          ? Center(
              child: LoadingAnimationWidget.threeArchedCircle(
                color: themeProvider.theme.colorScheme.primary,
                size: 50,
              ),
            )
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 60),
                      const SizedBox(height: 16),
                      Directionality(
                        textDirection: languageProvider.textDirection,
                        child: const Text(
                          'ببورە کێشەیەک ڕوویدا!',
                          style: TextStyle(
                            fontSize: 18, 
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loadBooks,
                        child: Directionality(
                          textDirection: languageProvider.textDirection,
                          child: const Text(
                            'دووبارەی بکەوە',
                            style: TextStyle(fontFamily: 'Inter'),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    Column(
                      children: [
                        _buildSearchBar(),
                        Expanded(
                          child: _filteredBooks.isEmpty && _searchController.text.isNotEmpty
                              ? Center(
                                  child: Directionality(
                                    textDirection: languageProvider.textDirection,
                                    child: const Text(
                                      'هیچ کتێبێک نەدۆزرایەوە',
                                      style: TextStyle(fontFamily: 'Inter'),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                )
                              : _filteredBooks.isEmpty
                                  ? (_isOffline
                                      ? OfflineErrorState(onRetry: _loadBooks)
                                      : Center(
                                          child: CircularProgressIndicator(
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                        ))
                              : _buildBookGrid(_filteredBooks),
                        ),
                      ],
                    ),
                    _recentBooks.isEmpty
                        ? Center(
                            child: Directionality(
                              textDirection: languageProvider.textDirection,
                              child: const Text(
                                'هیچ کتێبێکت نەخوێندوەتەوە',
                                style: TextStyle(fontFamily: 'Inter'),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : _buildBookGrid(_recentBooks),
                  ],
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadBooks() async {
    // Show loading immediately so retry button gives visual feedback
    if (mounted) setState(() { _isLoading = true; _hasError = false; });

    final bool online = await ConnectivityService.isOnline();
    if (mounted) setState(() => _isOffline = !online);

    // Always load cache first so offline users see cached data instantly
    await _loadCachedBooks();

    if (!online) {
      // Offline: show cached data if available, otherwise show OfflineErrorState
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = false;
        });
        _filterBooks(_searchController.text);
      }
      return;
    }

    try {
      final apiService = ApiService();
      final books = await apiService.fetchAllBooks();

      final List<Map<String, dynamic>> bookMaps = books.map((book) => {
        'id': book.id,
        'title': book.title,
        'author': book.author,
        'downloadUrl': book.downloadUrl,
        'description': book.description,
        'coverUrl': _processCoverUrl(book.imageUrl),
        'category': book.category,
      }).toList();

      if (mounted) {
        setState(() {
          _books.clear();
          _books.addAll(bookMaps);
          _isLoading = false;
        });
        _filterBooks(_searchController.text);
      }

      await _cacheBooks(bookMaps);
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = _books.isEmpty;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadCachedBooks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedBooks = prefs.getStringList('books');
      if (cachedBooks != null && mounted) {
        final loaded = cachedBooks.map((book) {
          final map = Map<String, dynamic>.from(jsonDecode(book));
          // Normalize keys: toJson() saves image_url / download_url,
          // but the UI reads coverUrl / downloadUrl.
          if (!map.containsKey('coverUrl')) {
            map['coverUrl'] = map['cover_url'] ?? map['image_url'] ?? '';
          }
          if (!map.containsKey('downloadUrl')) {
            map['downloadUrl'] = map['download_url'] ?? '';
          }
          return map;
        }).toList();

        setState(() {
          _books.clear();
          _books.addAll(loaded);
          // Also immediately set filteredBooks so covers show from cache
          _filteredBooks = List.from(loaded);
        });
      }
    } catch (e) {
      // Handle cache loading error
    }
  }

  Future<void> _cacheBooks(List<Map<String, dynamic>> books) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          'books', books.map((book) => jsonEncode(book)).toList());
    } catch (e) {
      // Handle cache saving error
      // print('Error caching books: $e');
    }
  }

  void _openPDF(String url, String title) {
    String pdfUrl = url;
    if (url.contains('drive.google.com/file/d/')) {
      final match = RegExp(r'drive\.google\.com/file/d/([a-zA-Z0-9_-]+)').firstMatch(url);
      if (match != null) {
        final fileId = match.group(1);
        pdfUrl = 'https://drive.google.com/uc?export=view&id=$fileId';
      }
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (context, animation, secondaryAnimation) => PDFViewerPage(
          url: pdfUrl,
          title: title,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  Widget _buildShimmerEffect() {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: Container(
        width: 100,
        height: 140,
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      ),
    );
  }
}

class PDFViewerPage extends StatefulWidget {
  final String url;
  final String title;

  const PDFViewerPage({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<PDFViewerPage> createState() => _PDFViewerPageState();
}

class _PDFViewerPageState extends State<PDFViewerPage> {
  bool _isDarkMode = false;
  int _currentPage = 0;
  int _totalPages = 0;
  bool _isSearching = false;
  double _loadingProgress = 0;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  final PdfViewerController _pdfViewerController = PdfViewerController();
  final ValueNotifier<bool> _isToolbarVisible = ValueNotifier<bool>(true);
  CancelToken? _cancelToken;
  Uint8List? _cachedPdfData;
  PdfTextSearchResult _searchResult = PdfTextSearchResult();
  int _currentSearchIndex = 0;
  bool _isDisposed = false;
  bool _isPdfLoadedFromFile = false; // New state to track if PDF is loaded from file cache

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _searchController.dispose();
    _pdfViewerController.dispose();
    _isToolbarVisible.dispose();
    _searchResult.clear();
    _cancelToken?.cancel(); // Cancel any ongoing download
    _cachedPdfData = null; // Clear cached data
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (!_isDisposed && mounted) {
      setState(fn);
    }
  }

  Future<void> _loadPdf() async {
    if (_isDisposed) return;

    _safeSetState(() {
      _isLoading = true;
      _loadingProgress = 0;
      _cachedPdfData = null; // Reset cached data
      _isPdfLoadedFromFile = false; // Reset file loaded status
    });

    _cancelToken = CancelToken();
    try {
      final cacheDir = await getTemporaryDirectory();
      final cachedPdfFile = File('${cacheDir.path}/${widget.url.hashCode}.pdf');

      // Check if PDF is cached and valid
      if (await cachedPdfFile.exists()) {
        try {
          final fileSize = await cachedPdfFile.length();
          const maxMemoryLoadSize = 100 * 1024 * 1024; // 100 MB

          if (fileSize > maxMemoryLoadSize) {
            // For very large files, avoid loading into memory. Rely on network streaming from local file.
            if (!_isDisposed && mounted) {
              _safeSetState(() {
                _isLoading = false;
                _isPdfLoadedFromFile = true; // Indicate it's from local cache (streaming)
                _loadingProgress = 100;
              });
              _showSnackBar('Large PDF found in cache. Streaming from local storage.');
              return;
            }
          } else {
            // For smaller files, load into memory
            final allBytes = await cachedPdfFile.readAsBytes();
            if (!_isDisposed && mounted) {
              _safeSetState(() {
                _cachedPdfData = allBytes;
                _isLoading = false;
                _isPdfLoadedFromFile = true; // Indicate it's from local cache (in-memory)
                _loadingProgress = 100;
              });
              _showSnackBar('PDF loaded from cache.');
              return;
            }
          }
        } catch (e) {
          // If cached file is corrupted or causes error, delete it and re-download
          // print('Error reading cached PDF: $e. Deleting and re-downloading.');
          if (!_isDisposed) {
            await cachedPdfFile.delete();
          }
        }
      }

      // If not cached or cache is invalid, download from network
      _showSnackBar('کتێبەکە دادەبەزێت...');
      final dio = Dio();
      final response = await dio.get(
        widget.url,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
        ),
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1 && !_isDisposed && mounted) {
            final double currentProgress = (received / total * 100).toDouble();
            // Throttle progress updates to avoid UI lag
            if (currentProgress - _loadingProgress > 2.0 || currentProgress >= 100) {
              _safeSetState(() {
                _loadingProgress = currentProgress;
              });
            }
          }
        },
      );

      final List<int> bytes = response.data as List<int>;
      if (!_isDisposed && mounted) {
        _safeSetState(() {
          _cachedPdfData = Uint8List.fromList(bytes);
          _isLoading = false;
          _isPdfLoadedFromFile = true;
          _loadingProgress = 100;
        });
      }
      
      // Write to cache in the background to not block the UI
      cachedPdfFile.writeAsBytes(bytes).catchError((_) => cachedPdfFile);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        // print('PDF download cancelled.');
      } else {
        if (!_isDisposed && mounted) {
          _safeSetState(() {
            _isLoading = false;
            _loadingProgress = 0;
          });
          String errorMessage = 'Error loading PDF. Please check your internet connection and try again.';
          if (e.type == DioExceptionType.receiveTimeout) {
            errorMessage = 'PDF download timed out. Please try again.';
          } else if (e.response != null) {
            errorMessage = 'Error: ${e.response?.statusCode} - Failed to download PDF.';
          }
          _showSnackBar(errorMessage);
        }
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        _safeSetState(() {
          _isLoading = false;
          _loadingProgress = 0;
        });
        _showSnackBar('An unexpected error occurred: $e');
      }
    }
  }

  void _showSnackBar(String message) {
    // SnackBar disabled as per request
  }

  void _handleSearch(String searchText) {
    if (searchText.isEmpty) {
      setState(() {
        _searchResult = PdfTextSearchResult();
        _currentSearchIndex = 0;
      });
      return;
    }

    _searchResult = _pdfViewerController.searchText(
      searchText,
    );

    _searchResult.addListener(() {
      if (mounted) {
        _safeSetState(() {
          if (_searchResult.hasResult) {
            _currentSearchIndex = _searchResult.currentInstanceIndex;
          } else {
            _currentSearchIndex = 0;
          }
        });
      }
    });
  }

  void _jumpToNextSearchResult() {
    if (_searchResult.hasResult) {
      _searchResult.nextInstance();
    }
  }

  void _jumpToPreviousSearchResult() {
    if (_searchResult.hasResult) {
      _searchResult.previousInstance();
    }
  }

  Future<void> _jumpToPage(int page) async {
    _pdfViewerController.jumpToPage(page);
  }

  Widget _buildPdfContent({
    required Color scaffoldBg,
    required Color primaryColor,
    required Color onSurfaceColor,
    required Color onSurfaceColorMuted,
    required bool isDark,
    required ThemeData theme,
  }) {
    if (_isLoading) {
      return Container(
        key: const ValueKey('loading'),
        color: scaffoldBg,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  value: _loadingProgress > 0 && _loadingProgress < 100
                      ? _loadingProgress / 100
                      : null,
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  backgroundColor: primaryColor.withValues(alpha: 0.15),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _loadingProgress > 0
                    ? 'دادەبەزێت ${_loadingProgress.toStringAsFixed(0)}%'
                    : 'چاوەڕوان بە...',
                style: TextStyle(
                  color: onSurfaceColor,
                  fontSize: 16,
                  fontFamily: 'Inter',
                ),
              ),
              if (_loadingProgress > 0) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: 200,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _loadingProgress / 100,
                      backgroundColor: primaryColor.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      minHeight: 6,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (_cachedPdfData != null || _isPdfLoadedFromFile) {
      // PDF background is always white; dark mode uses a color-invert matrix.
      return ColorFiltered(
        key: const ValueKey('pdf'),
        colorFilter: isDark
            ? const ColorFilter.matrix([
                -1, 0, 0, 0, 255,
                 0,-1, 0, 0, 255,
                 0, 0,-1, 0, 255,
                 0, 0, 0, 1,   0,
              ])
            : const ColorFilter.matrix([
                1, 0, 0, 0, 0,
                0, 1, 0, 0, 0,
                0, 0, 1, 0, 0,
                0, 0, 0, 1, 0,
              ]),
        child: _cachedPdfData != null
            ? SfPdfViewer.memory(
                _cachedPdfData!,
                controller: _pdfViewerController,
                pageLayoutMode: PdfPageLayoutMode.single,
                scrollDirection: PdfScrollDirection.vertical,
                canShowScrollHead: false,
                canShowScrollStatus: false,
                enableDoubleTapZooming: true,
                enableTextSelection: true,
                initialZoomLevel: 1.0,
                onPageChanged: (details) {
                  _safeSetState(() => _currentPage = details.newPageNumber - 1);
                },
                onDocumentLoaded: (details) {
                  _safeSetState(() {
                    _totalPages = details.document.pages.count;
                    _isLoading = false;
                  });
                },
                onDocumentLoadFailed: (_) {
                  if (!_isDisposed && mounted) {
                    _safeSetState(() => _isLoading = false);
                  }
                },
              )
            : SfPdfViewer.network(
                widget.url,
                controller: _pdfViewerController,
                pageLayoutMode: PdfPageLayoutMode.single,
                scrollDirection: PdfScrollDirection.vertical,
                canShowScrollHead: false,
                canShowScrollStatus: false,
                enableDoubleTapZooming: true,
                enableTextSelection: true,
                initialZoomLevel: 1.0,
                onPageChanged: (details) {
                  _safeSetState(() => _currentPage = details.newPageNumber - 1);
                },
                onDocumentLoaded: (details) {
                  _safeSetState(() {
                    _totalPages = details.document.pages.count;
                    _isLoading = false;
                  });
                },
                onDocumentLoadFailed: (_) {
                  if (!_isDisposed && mounted) {
                    _safeSetState(() => _isLoading = false);
                  }
                },
              ),
      );
    }

    // Error state
    return Center(
      key: const ValueKey('error'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.broken_image_outlined,
                  color: theme.colorScheme.error, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              'کتێبەکە نەکرایەوە',
              style: TextStyle(
                color: onSurfaceColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'تکایە هەوڵی دووبارە بدەوە',
              style: TextStyle(color: onSurfaceColorMuted, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadPdf,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('دووبارە'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final appIsDark = themeProvider.isDarkMode;
    final isDark = _isDarkMode;

    final scaffoldBg = appIsDark ? const Color(0xFF121212) : Colors.grey[50]!;
    final surfaceColor = appIsDark ? const Color(0xFF1E1E1E) : Colors.white;
    final primaryColor = theme.colorScheme.primary;
    final onSurfaceColor = appIsDark ? const Color(0xFFE1E1E1) : Colors.black87;
    final onSurfaceColorMuted = appIsDark ? Colors.grey[400]! : Colors.grey[600]!;
    final appBarBg = appIsDark ? const Color(0xFF1E1E1E) : theme.colorScheme.primary;
    const appBarFg = Colors.white;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: appBarBg,
        iconTheme: const IconThemeData(color: appBarFg),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: appBarFg),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: appBarFg,
            fontWeight: FontWeight.w600,
            fontSize: 18,
            fontFamily: 'Inter',
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close : Icons.search,
              color: appBarFg,
            ),
            onPressed: () {
              _safeSetState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _pdfViewerController.clearSelection();
                  _searchResult.clear();
                }
              });
            },
          ),
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: appBarFg,
            ),
            tooltip: isDark ? 'ڕووناک' : 'تاریک',
            onPressed: () {
              _safeSetState(() {
                _isDarkMode = !_isDarkMode;
                SystemChrome.setSystemUIOverlayStyle(
                  _isDarkMode ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
                );
              });
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          // ── PDF Content ───────────────────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: child,
            ),
            child: _buildPdfContent(
              scaffoldBg: scaffoldBg,
              primaryColor: primaryColor,
              onSurfaceColor: onSurfaceColor,
              onSurfaceColorMuted: onSurfaceColorMuted,
              isDark: isDark,
              theme: theme,
            ),
          ),

          // ── Floating search bar ───────────────────────────────────────
          if (_isSearching)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: appIsDark ? 0.3 : 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: TextStyle(color: onSurfaceColor, fontFamily: 'Inter'),
                        decoration: InputDecoration(
                          hintText: 'گەڕان بۆ دەق...',
                          hintStyle: TextStyle(color: onSurfaceColorMuted),
                          filled: true,
                          fillColor: appIsDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: Icon(Icons.search, color: onSurfaceColorMuted, size: 20),
                        ),
                        onChanged: _handleSearch,
                      ),
                    ),
                    if (_searchResult.hasResult && _searchResult.totalInstanceCount > 0) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.keyboard_arrow_up_rounded, color: primaryColor),
                        style: IconButton.styleFrom(
                          backgroundColor: primaryColor.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _jumpToPreviousSearchResult,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_currentSearchIndex + 1}/${_searchResult.totalInstanceCount}',
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(Icons.keyboard_arrow_down_rounded, color: primaryColor),
                        style: IconButton.styleFrom(
                          backgroundColor: primaryColor.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _jumpToNextSearchResult,
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // ── Bottom page navigation bar ────────────────────────────────
          if (!_isLoading && _totalPages > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: appIsDark ? 0.3 : 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      // Prev button
                      IconButton(
                        icon: Icon(Icons.chevron_left_rounded,
                            color: _currentPage > 0 ? primaryColor : onSurfaceColorMuted),
                        style: IconButton.styleFrom(
                          backgroundColor: _currentPage > 0
                              ? primaryColor.withValues(alpha: 0.1)
                              : Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _currentPage > 0
                            ? () => _pdfViewerController.previousPage()
                            : null,
                      ),
                      // Page counter pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_currentPage + 1} / $_totalPages',
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                      // Slider
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: primaryColor,
                            inactiveTrackColor: primaryColor.withValues(alpha: 0.2),
                            thumbColor: primaryColor,
                            overlayColor: primaryColor.withValues(alpha: 0.1),
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          ),
                          child: Slider(
                            value: (_currentPage + 1).toDouble().clamp(1, _totalPages.toDouble()),
                            min: 1,
                            max: _totalPages.toDouble(),
                            onChanged: (value) => _jumpToPage(value.toInt()),
                          ),
                        ),
                      ),
                      // Next button
                      IconButton(
                        icon: Icon(Icons.chevron_right_rounded,
                            color: _currentPage < _totalPages - 1
                                ? primaryColor
                                : onSurfaceColorMuted),
                        style: IconButton.styleFrom(
                          backgroundColor: _currentPage < _totalPages - 1
                              ? primaryColor.withValues(alpha: 0.1)
                              : Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _currentPage < _totalPages - 1
                            ? () => _pdfViewerController.nextPage()
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
