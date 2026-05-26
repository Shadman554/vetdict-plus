import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import '../models/instrument.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../utils/page_transition.dart';
import '../services/api_service.dart';
import '../services/encrypted_cache_service.dart';
import '../services/connectivity_service.dart';
import '../widgets/offline_banner.dart';
import '../widgets/offline_error_state.dart';

class InstrumentsPage extends StatefulWidget {
  const InstrumentsPage({Key? key}) : super(key: key);

  @override
  State<InstrumentsPage> createState() => _InstrumentsPageState();
}

class _InstrumentsPageState extends State<InstrumentsPage> with SingleTickerProviderStateMixin {
  final Map<int, bool> _expandedStates = {};
  late AnimationController _controller;
  final TextEditingController _searchController = TextEditingController();
  List<Instrument> _filteredInstruments = [];
  List<Instrument> _allInstruments = [];
  Set<String> _availableCategories = <String>{};
  String? _selectedCategory;
  bool _isOffline = false;
  bool _isLoading = false;

  // Convert Google Drive share/preview links to direct-view image URLs
  String _resolveImageUrl(String url) {
    try {
      if (url.isEmpty) return url;
      final uri = Uri.parse(url);
      if (uri.host.contains('drive.google.com')) {
        if (uri.path.startsWith('/uc') && uri.queryParameters['id'] != null) {
          final id = uri.queryParameters['id'];
          return 'https://drive.google.com/uc?export=view&id=$id';
        }

        final fileIdMatch = RegExp(r"/d/([^/]+)").firstMatch(uri.path);
        String? id = fileIdMatch?.group(1);
        id ??= uri.queryParameters['id'];

        if (id != null && id.isNotEmpty) {
          return 'https://drive.google.com/uc?export=view&id=$id';
        }
      }
    } catch (_) {
      // If parsing fails, just return original URL
    }
    return url;
  }

  @override
  void initState() {
    super.initState();
    _loadInstruments();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInstruments() async {
    if (mounted) setState(() { _isLoading = true; _isOffline = false; });
    final encCache = EncryptedCacheService();

    try {
      final bool online = await ConnectivityService.isOnline();
      if (mounted) setState(() => _isOffline = !online);

      if (online) {
        final apiService = ApiService();
        final instruments = await apiService.fetchAllInstruments();

        // Save to encrypted cache for offline use
        await encCache.saveInstruments(instruments.map((i) => i.toJson()).toList());

        // Extract unique categories
        final categories = instruments
            .where((instrument) => instrument.category.isNotEmpty)
            .map((instrument) => instrument.category)
            .toSet();

        setState(() {
          _allInstruments = instruments;
          _filteredInstruments = instruments;
          _availableCategories = categories;
          _isLoading = false;
        });
      } else {
        // Offline: load from encrypted cache
        final cached = await encCache.loadInstruments();
        final instruments = cached.map((json) => Instrument.fromJson(json)).toList();

        final categories = instruments
            .where((instrument) => instrument.category.isNotEmpty)
            .map((instrument) => instrument.category)
            .toSet();

        setState(() {
          _allInstruments = instruments;
          _filteredInstruments = instruments;
          _availableCategories = categories;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading instruments: $e');
      // Try encrypted cache as fallback
      try {
        final cached = await encCache.loadInstruments();
        final instruments = cached.map((json) => Instrument.fromJson(json)).toList();
        if (instruments.isNotEmpty) {
          final categories = instruments
              .where((instrument) => instrument.category.isNotEmpty)
              .map((instrument) => instrument.category)
              .toSet();
          setState(() {
            _allInstruments = instruments;
            _filteredInstruments = instruments;
            _availableCategories = categories;
            _isLoading = false;
          });
          return;
        }
      } catch (_) {}

      setState(() {
        _allInstruments = [];
        _filteredInstruments = [];
        _availableCategories = {};
        _isLoading = false;
      });
    }
  }

  void _filterInstruments(String query) {
    const isEnglish = false; // Always use Kurdish
    setState(() {
      _filteredInstruments = _allInstruments.where((instrument) {
        final matchesSearch = instrument.getName(isEnglish).toLowerCase().contains(query.toLowerCase());
        final matchesCategory = _selectedCategory == null || instrument.category == _selectedCategory;
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  void _showFilterOptions(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
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
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text(
                      'فلتەرکردن',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                  
                  const Divider(height: 1),
                  
                  // Scrollable content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category filter section
                          Text(
                            'پۆلەکان',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                            textDirection: TextDirection.ltr,
                          ),
                          const SizedBox(height: 12),
                          
                          // Category chips
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildFilterChip(
                                'هەموو',
                                Icons.apps_rounded,
                                themeProvider.theme.colorScheme.primary,
                                _selectedCategory == null,
                                () {
                                  setModalState(() => _selectedCategory = null);
                                },
                                isDarkMode,
                              ),
                              ..._availableCategories.map((category) => _buildFilterChip(
                                    category,
                                    Icons.medical_services,
                                    themeProvider.theme.colorScheme.primary,
                                    _selectedCategory == category,
                                    () {
                                      setModalState(() => _selectedCategory = category);
                                    },
                                    isDarkMode,
                                  )),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Bottom action buttons
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[100],
                      border: Border(
                        top: BorderSide(
                          color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _selectedCategory = null;
                                _filterInstruments(_searchController.text);
                              });
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('ڕێکخستنەوە'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(
                                color: isDarkMode ? Colors.grey[700]! : Colors.grey[400]!,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _filterInstruments(_searchController.text);
                              });
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: Text(
                              'جێبەجێکردن (${_filteredInstruments.length})',
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: themeProvider.theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                            ),
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
      },
    );
  }

  Widget _buildFilterChip(
    String label,
    IconData icon,
    Color color,
    bool isSelected,
    VoidCallback onTap,
    bool isDarkMode,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? color
              : isDarkMode
                  ? Colors.grey[850]
                  : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? color
                : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
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
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : isDarkMode
                        ? Colors.grey[300]
                        : Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl, String name) {
    Navigator.of(context).push(
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
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              loadingBuilder: (context, event) => Center(
                child: LoadingAnimationWidget.threeArchedCircle(
                  color: Colors.white,
                  size: 50,
                ),
              ),
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Icon(Icons.error_outline, color: Colors.white, size: 50),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    const isEnglish = false; // Always use Kurdish
    
    return Scaffold(
      backgroundColor: themeProvider.isDarkMode
          ? themeProvider.theme.scaffoldBackgroundColor
          : Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 4,
        surfaceTintColor: Colors.transparent,
        backgroundColor: themeProvider.isDarkMode
            ? themeProvider.theme.appBarTheme.backgroundColor
            : themeProvider.theme.colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: const BackButton(),
        title: Directionality(
          textDirection: languageProvider.textDirection,
          child: Text(
            'ئامێرەکان',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
            textAlign: languageProvider.isRTL ? TextAlign.right : TextAlign.left,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Directionality(
            textDirection: languageProvider.textDirection,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                color: themeProvider.isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
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
              child: Row(
                children: [
                  // Filter button
                  Stack(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.filter_list,
                          color: themeProvider.isDarkMode
                              ? Colors.grey[600]
                              : Colors.grey[400],
                        ),
                        onPressed: () => _showFilterOptions(context),
                      ),
                      if (_selectedCategory != null)
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
                  // Divider
                  Container(
                    height: 24,
                    width: 1,
                    color: themeProvider.isDarkMode
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.grey.withValues(alpha: 0.2),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _filterInstruments,
                      textDirection: languageProvider.textDirection,
                      style: TextStyle(
                        color: themeProvider.isDarkMode ? Colors.white : const Color(0xFF1E293B),
                        fontFamily: 'Inter',
                      ),
                      decoration: InputDecoration(
                        hintText: 'گەڕان ...',
                        hintStyle: TextStyle(
                          color: themeProvider.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          fontFamily: 'Inter',
                        ),
                        prefixIcon: languageProvider.isRTL ? null : Icon(
                          Icons.search,
                          color: themeProvider.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                        suffixIcon: languageProvider.isRTL ? Icon(
                          Icons.search,
                          color: themeProvider.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ) : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          if (_isOffline) const OfflineBanner(),
          Expanded(
            child: Directionality(
              textDirection: languageProvider.textDirection,
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: _isLoading
                  ? Center(
                      child: LoadingAnimationWidget.threeArchedCircle(
                        color: themeProvider.theme.colorScheme.primary,
                        size: 50,
                      ),
                    )
                  : _filteredInstruments.isEmpty
                    ? (_isOffline
                        ? OfflineErrorState(onRetry: _loadInstruments)
                        : Center(
                            child: Directionality(
                              textDirection: languageProvider.textDirection,
                              child: Text(
                                'هیچ ئامێرێک نیە',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: themeProvider.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                  fontFamily: 'Inter',
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ))
                    : RefreshIndicator(
                        onRefresh: _loadInstruments,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                          itemCount: _filteredInstruments.length,
                          itemBuilder: (context, index) {
                            final instrument = _filteredInstruments[index];
                            final isExpanded = _expandedStates[index] ?? false;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 20),
                              child: Card(
                                elevation: 3,
                                shadowColor: themeProvider.isDarkMode 
                                    ? Colors.black.withValues(alpha: 0.3)
                                    : Colors.grey.withValues(alpha: 0.2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Image Section with direct tap to fullscreen
                                    Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                          child: Hero(
                                            tag: 'instrument_image_$index',
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () => _showFullScreenImage(context, instrument.imageUrl, instrument.getName(isEnglish)),
                                                child: CachedNetworkImage(
                                                  imageUrl: _resolveImageUrl(instrument.imageUrl),
                                                  height: 220,
                                                  width: double.infinity,
                                                  fit: BoxFit.cover,
                                                  placeholder: (context, url) => Shimmer.fromColors(
                                                    baseColor: themeProvider.isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                                                    highlightColor: themeProvider.isDarkMode ? Colors.grey[700]! : Colors.grey[100]!,
                                                    child: Container(
                                                      height: 220,
                                                      width: double.infinity,
                                                      decoration: const BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                                      ),
                                                    ),
                                                  ),
                                                  errorWidget: (context, url, error) => InkWell(
                                                    onTap: () => _showFullScreenImage(context, instrument.imageUrl, instrument.getName(isEnglish)),
                                                    child: Container(
                                                      height: 220,
                                                      width: double.infinity,
                                                      decoration: BoxDecoration(
                                                        color: themeProvider.isDarkMode ? Colors.grey[800] : Colors.grey[200],
                                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                                      ),
                                                      child: Column(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          Icon(
                                                            Icons.error_outline,
                                                            color: themeProvider.isDarkMode ? Colors.white54 : Colors.grey[600],
                                                            size: 40,
                                                          ),
                                                          const SizedBox(height: 8),
                                                          Text(
                                                            'Failed to load image',
                                                            style: TextStyle(
                                                              color: themeProvider.isDarkMode ? Colors.white54 : Colors.grey[600],
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Gradient overlay for better text visibility
                                        Positioned.fill(
                                          child: IgnorePointer(
                                            ignoring: true,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    Colors.transparent,
                                                    Colors.black.withValues(alpha: 0.1),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Fullscreen icon
                                        Positioned(
                                          top: 12,
                                          right: 12,
                                          child: GestureDetector(
                                            onTap: () => _showFullScreenImage(context, instrument.imageUrl, instrument.getName(isEnglish)),
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
                                    
                                    // Content Section
                                    Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Instrument Name with expand button
                                          Row(
                                            children: [
                                              // Expand/Collapse button - only show if description is not empty
                                              if (instrument
                                                  .getDescription(isEnglish)
                                                  .trim()
                                                  .isNotEmpty)
                                                GestureDetector(
                                                  onTap: () {
                                                    setState(() {
                                                      _expandedStates[index] = !isExpanded;
                                                    });
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context)
                                                          .primaryColor
                                                          .withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: AnimatedRotation(
                                                      turns: isExpanded ? 0.5 : 0,
                                                      duration: const Duration(milliseconds: 300),
                                                      child: Icon(
                                                        Icons.expand_more,
                                                        color: Theme.of(context).primaryColor,
                                                        size: 24,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              else
                                                const SizedBox(width: 40), // Placeholder to maintain centering
                                              // Centered instrument name
                                              Expanded(
                                                child: Text(
                                                  instrument.getName(isEnglish),
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: themeProvider.isDarkMode
                                                        ? Colors.white
                                                        : const Color(0xFF1E293B),
                                                    fontFamily: 'Inter',
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                              const SizedBox(width: 40), // Balance the layout
                                            ],
                                          ),
                                          // Description (RTL for Kurdish) - only show if not empty
                                          if (instrument.getDescription(isEnglish).trim().isNotEmpty) ...[
                                            const SizedBox(height: 12),
                                            
                                            AnimatedContainer(
                                              duration: const Duration(milliseconds: 400),
                                              curve: Curves.easeInOut,
                                              child: Center(
                                                child: Directionality(
                                                  textDirection: TextDirection.rtl, // Force RTL for Kurdish description
                                                  child: AnimatedCrossFade(
                                                    firstChild: Text(
                                                      instrument.getDescription(isEnglish),
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        color: themeProvider.isDarkMode 
                                                            ? Colors.grey[300]
                                                            : Colors.grey[700],
                                                        fontFamily: 'Inter',
                                                        height: 1.4,
                                                      ),
                                                      maxLines: 3,
                                                      overflow: TextOverflow.ellipsis,
                                                      textAlign: TextAlign.center,
                                                    ),
                                                    secondChild: Text(
                                                      instrument.getDescription(isEnglish),
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        color: themeProvider.isDarkMode 
                                                            ? Colors.grey[300]
                                                            : Colors.grey[700],
                                                        height: 1.6,
                                                        fontFamily: 'Inter',
                                                      ),
                                                      textAlign: TextAlign.center,
                                                    ),
                                                    crossFadeState: isExpanded
                                                        ? CrossFadeState.showSecond
                                                        : CrossFadeState.showFirst,
                                                    duration: const Duration(milliseconds: 400),
                                                    firstCurve: Curves.easeOut,
                                                    secondCurve: Curves.easeIn,
                                                    sizeCurve: Curves.easeInOut,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            
                                            // Show more/less text indicator
                                            if (!isExpanded && instrument.getDescription(isEnglish).length > 150)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 8),
                                                child: Center(
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      setState(() {
                                                        _expandedStates[index] = true;
                                                      });
                                                    },
                                                    child: Text(
                                                      'زیاتر بخوێنەوە...',
                                                      style: TextStyle(
                                                        color: Theme.of(context).primaryColor,
                                                        fontWeight: FontWeight.w500,
                                                        fontSize: 14,
                                                        fontFamily: 'Inter',
                                                      ),
                                                      textDirection: TextDirection.rtl,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}