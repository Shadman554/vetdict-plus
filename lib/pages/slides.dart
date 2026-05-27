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
import '../models/slide.dart';
import '../widgets/offline_banner.dart';
import '../widgets/offline_error_state.dart';
import 'package:vetstan/utils/page_transition.dart';

class SlidesPage extends StatefulWidget {
  final String initialCategory;
  
  const SlidesPage({
    Key? key,
    required this.initialCategory,
  }) : super(key: key);

  @override
  State<SlidesPage> createState() => _SlidesPageState();
}

class _SlidesPageState extends State<SlidesPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Slide> _filteredSlides = [];
  List<Slide> _allSlides = [];
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

  // Convert Google Drive share/preview links to server-side proxy URLs (avoids CORS on web)
  String _resolveImageUrl(String url) {
    try {
      if (url.isEmpty) return url;
      // Already a proxy URL — ensure it's absolute for CachedNetworkImage
      if (url.contains('/media-proxy?')) return url;
      final uri = Uri.parse(url);
      if (uri.host.contains('drive.google.com')) {
        final fileIdMatch = RegExp(r"/d/([^/]+)").firstMatch(uri.path);
        String? id = fileIdMatch?.group(1);
        id ??= uri.queryParameters['id'];
        if (id != null && id.isNotEmpty) {
          final thumbnailUrl = 'https://drive.google.com/thumbnail?id=$id&sz=w400';
          final proxyPath = '/media-proxy?url=${Uri.encodeComponent(thumbnailUrl)}';
          return kIsWeb ? '${Uri.base.origin}$proxyPath' : proxyPath;
        }
      }
    } catch (_) {}
    return url;
  }

  @override
  void initState() {
    super.initState();
    _loadSlides();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSlides() async {
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
        final apiService = ApiService();
        if (kDebugMode) debugPrint('[SlidesPage] Loading slides for category: $category');
        
        final List<Slide> slides;
        switch (category) {
          case 'urine':
            slides = await apiService.fetchUrineSlides();
            break;
          case 'stool':
            slides = await apiService.fetchStoolSlides();
            break;
          case 'other':
          default:
            slides = await apiService.fetchOtherSlides();
            break;
        }

        // Save to encrypted cache for offline use
        await encCache.saveSlides(category, slides.map((s) => s.toJson()).toList());

        if (!mounted) return;
        setState(() {
          _allSlides = slides;
          _filteredSlides = List.from(slides);
          _isLoading = false;
        });
        if (kDebugMode) debugPrint('[SlidesPage] Loaded ${slides.length} slides from API');
      } else {
        // Offline: load from encrypted cache
        final cached = await encCache.loadSlides(category);
        final slides = cached.map((json) => Slide.fromJson(json)).toList();

        if (!mounted) return;
        if (slides.isNotEmpty) {
          setState(() {
            _allSlides = slides;
            _filteredSlides = List.from(slides);
            _isLoading = false;
          });
          if (kDebugMode) debugPrint('[SlidesPage] Loaded ${slides.length} slides from encrypted cache');
        } else {
          // Offline and no cache — _isOffline is already true, OfflineErrorState will show
          setState(() {
            _hasError = false;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[SlidesPage] API failed, trying cache: $e');
      try {
        final cached = await encCache.loadSlides(category);
        final slides = cached.map((json) => Slide.fromJson(json)).toList();
        if (!mounted) return;
        if (slides.isNotEmpty) {
          setState(() {
            _allSlides = slides;
            _filteredSlides = List.from(slides);
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

  void _filterSlides(String query) {
    if (!mounted) return;
    
    setState(() {
      if (query.isEmpty) {
        _filteredSlides = List.from(_allSlides);
      } else {
        final queryLower = query.toLowerCase().trim();
        _filteredSlides = _allSlides.where((slide) {
          return slide.name.toLowerCase().contains(queryLower) ||
              slide.species.toLowerCase().contains(queryLower);
        }).toList();
      }
    });
  }

  void _showFullScreenImage(BuildContext context, String imageUrl, String name) {
    if (!_isValidHttpUrl(imageUrl)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid image URL')),
      );
      return;
    }

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
            centerTitle: true,
          ),
          body: Center(
            child: PhotoView(
              imageProvider: CachedNetworkImageProvider(_resolveImageUrl(imageUrl)),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 3,
              initialScale: PhotoViewComputedScale.contained,
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              loadingBuilder: (context, event) => Center(
                child: LoadingAnimationWidget.threeArchedCircle(
                  color: Colors.white,
                  size: 40,
                ),
              ),
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_not_supported,
                      color: Colors.white,
                      size: 48,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Failed to load image',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to format text with content inside {} as italic
  Widget _buildFormattedText(String text, TextStyle baseStyle) {
    if (text.isEmpty) {
      return Text(
        'Unnamed Slide',
        style: baseStyle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      );
    }

    final RegExp regex = RegExp(r'\{([^}]*)\}');
    final List<TextSpan> spans = [];
    int lastMatchEnd = 0;

    for (final Match match in regex.allMatches(text)) {
      // Add text before the match
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: baseStyle,
        ));
      }

      // Add the matched text (content inside {}) as italic
      final matchText = match.group(1);
      if (matchText != null) {
        spans.add(TextSpan(
          text: matchText,
          style: baseStyle.copyWith(fontStyle: FontStyle.italic),
        ));
      }

      lastMatchEnd = match.end;
    }

    // Add remaining text after the last match
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: baseStyle,
      ));
    }

    // If no matches found, return the original text
    if (spans.isEmpty) {
      return Text(
        text,
        style: baseStyle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      );
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
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
        textDirection: TextDirection.ltr,
        child: Text(
          () {
            final cat = widget.initialCategory.toLowerCase().trim();
            if (cat == 'urine') return 'Urine Slides';
            if (cat == 'stool') return 'Stool Slides';
            return 'Other Slides';
          }(),
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
          onChanged: _filterSlides,
          style: TextStyle(
            color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
            fontFamily: 'Inter',
          ),
          decoration: InputDecoration(
            hintText: 'گەڕان لە سلایدەکان...',
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

    if (_filteredSlides.isEmpty && _allSlides.isNotEmpty) {
      return _buildNoResultsState(themeProvider, languageProvider);
    }

    if (_filteredSlides.isEmpty) {
      return _buildEmptyState(themeProvider, languageProvider);
    }

    return RefreshIndicator(
      onRefresh: _loadSlides,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        itemCount: _filteredSlides.length,
        itemBuilder: (context, index) {
          final slide = _filteredSlides[index];
          return _buildSlideItem(context, slide, themeProvider, languageProvider);
        },
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
                'هەڵەیەک ڕوویدا لە بارکردنی سلایدەکان',
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
              onPressed: _loadSlides,
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
    if (_isOffline) {
      return OfflineErrorState(onRetry: _loadSlides);
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
              'هیچ سلایدێک نەدۆزرایەوە',
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

  Widget _buildSlideItem(
    BuildContext context,
    Slide slide,
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: themeProvider.isDarkMode
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (_isValidHttpUrl(slide.imageUrl)) {
              _showFullScreenImage(context, slide.imageUrl, slide.name);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Image not available')),
              );
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSlideImage(slide, themeProvider),
              _buildSlideContent(slide, themeProvider, languageProvider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlideImage(Slide slide, ThemeProvider themeProvider) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: Stack(
        children: [
          Hero(
            tag: slide.id,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: _isValidHttpUrl(slide.imageUrl)
                  ? CachedNetworkImage(
                      imageUrl: _resolveImageUrl(slide.imageUrl),
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: themeProvider.isDarkMode
                            ? Colors.grey[800]
                            : Colors.grey[200],
                        child: Center(
                          child: LoadingAnimationWidget.threeArchedCircle(
                            color: themeProvider.theme.colorScheme.primary,
                            size: 30,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => _buildImageError(themeProvider),
                    )
                  : _buildImageError(themeProvider),
            ),
          ),
          if (_isValidHttpUrl(slide.imageUrl))
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: () => _showFullScreenImage(context, slide.imageUrl, slide.name),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.fullscreen,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageError(ThemeProvider themeProvider) {
    return Container(
      color: themeProvider.isDarkMode ? Colors.grey[800] : Colors.grey[200],
      child: Center(
        child: Icon(
          Icons.image_not_supported,
          size: 48,
          color: themeProvider.isDarkMode ? Colors.grey[600] : Colors.grey[400],
        ),
      ),
    );
  }

  Widget _buildSlideContent(
    Slide slide,
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Directionality(
        textDirection: languageProvider.textDirection,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildFormattedText(
              slide.name,
              TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: themeProvider.isDarkMode
                    ? Colors.white
                    : Colors.black87,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'جۆری ئاژەڵ: ${slide.species}',
              style: TextStyle(
                fontSize: 14,
                color: themeProvider.isDarkMode
                    ? Colors.grey[400]
                    : Colors.grey[600],
                fontFamily: 'Inter',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}