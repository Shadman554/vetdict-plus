import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../services/sync_service.dart';
import '../services/encrypted_cache_service.dart';
import '../services/connectivity_service.dart';
import '../providers/theme_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/language_provider.dart';
import '../models/disease.dart';
import 'disease_details_page.dart';
import 'package:vetstan/utils/page_transition.dart';
import '../widgets/offline_banner.dart';
import '../widgets/offline_error_state.dart';

// Enum for disease classification
enum DiseaseClass {
  viral,
  bacterial,
  parasitic,
  fungal,
  metabolic,
  other
}

// Extension to provide user-friendly string representation
extension DiseaseClassExtension on DiseaseClass {
  String get displayName {
    switch (this) {
      case DiseaseClass.viral:
        return 'Viral';
      case DiseaseClass.bacterial:
        return 'Bacterial';
      case DiseaseClass.parasitic:
        return 'Parasitic';
      case DiseaseClass.fungal:
        return 'Fungal';
      case DiseaseClass.metabolic:
        return 'Metabolic';
      case DiseaseClass.other:
        return 'Other';
    }
  }

  Color get color {
    switch (this) {
      case DiseaseClass.viral:
        return const Color(0xFF1A3460);
      case DiseaseClass.bacterial:
        return Colors.red.shade700;
      case DiseaseClass.parasitic:
        return Colors.green.shade700;
      case DiseaseClass.fungal:
        return Colors.purple.shade700;
      case DiseaseClass.metabolic:
        return Colors.orange.shade700;
      case DiseaseClass.other:
        return Colors.grey.shade700;
    }
  }
}

class DiseasesPage extends StatefulWidget {
  const DiseasesPage({Key? key}) : super(key: key);

  @override
  State<DiseasesPage> createState() => _DiseasesPageState();
}

class _DiseasesPageState extends State<DiseasesPage> {
  final SyncService _syncService = SyncService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<Disease> _diseases = [];
  List<Disease> _filteredDiseases = [];
  bool _isLoading = true;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _loadDiseasesData();
    _checkForUpdates();
    _startPeriodicSync();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDiseasesData() async {
    if (mounted) setState(() { _isLoading = true; _isOffline = false; });
    final encCache = EncryptedCacheService();

    try {
      final bool online = await ConnectivityService.isOnline();
      if (mounted) setState(() => _isOffline = !online);

      if (online) {
        final diseasesList = await _syncService.loadCategoryData<Disease>('diseases');
        final filtered = diseasesList.where((disease) => disease.name.isNotEmpty).toList();

        // Save to encrypted cache for offline use
        await encCache.saveDiseases(filtered.map((d) => d.toJson()).toList());

        if (mounted) {
          setState(() {
            _diseases = filtered;
            _filteredDiseases = _diseases;
            _isLoading = false;
          });
        }
      } else {
        // Offline: load from encrypted cache
        if (kDebugMode) debugPrint('[Diseases] Offline, loading from encrypted cache...');
        final cached = await encCache.loadDiseases();
        final diseases = cached.map((json) => Disease.fromJson(json)).where((d) => d.name.isNotEmpty).toList();

        if (mounted) {
          setState(() {
            _diseases = diseases;
            _filteredDiseases = _diseases;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading diseases: $e');
      // Try encrypted cache as fallback
      try {
        final cached = await encCache.loadDiseases();
        final diseases = cached.map((json) => Disease.fromJson(json)).where((d) => d.name.isNotEmpty).toList();
        if (mounted && diseases.isNotEmpty) {
          setState(() {
            _diseases = diseases;
            _filteredDiseases = _diseases;
            _isLoading = false;
          });
          return;
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkForUpdates() async {
    // Check for updates in the background (no loading screen)
    final hasUpdates = await _syncService.checkForCategoryUpdates('diseases');
    if (hasUpdates && mounted) {
      // Refresh the data silently
      final updatedData = _syncService.getCachedDiseases().cast<Disease>();
      setState(() {
        _diseases = updatedData.where((disease) => disease.name.isNotEmpty).toList();
        _filteredDiseases = _diseases.where((disease) =>
            disease.name.toLowerCase().contains(_searchController.text.toLowerCase()) ||
            disease.category.toLowerCase().contains(_searchController.text.toLowerCase())).toList();
      });
    }
  }

  void _filterDiseases(String query) {
    setState(() {
      _filteredDiseases = _diseases
          .where((disease) =>
              disease.name.toLowerCase().contains(query.toLowerCase()) ||
              disease.category.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final favoritesProvider = Provider.of<FavoritesProvider>(context);

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
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: themeProvider.isDarkMode
                ? themeProvider.theme.colorScheme.onSurface
                : Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'نەخۆشییەکان',
          style: TextStyle(
            color: themeProvider.isDarkMode
                ? themeProvider.theme.colorScheme.onSurface
                : Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
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
                onChanged: _filterDiseases,
                textDirection: languageProvider.textDirection,
                style: TextStyle(
                  color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'گەڕان بە نەخۆشییەکان...',
                  hintStyle: TextStyle(
                    color: themeProvider.isDarkMode
                        ? Colors.grey[600]
                        : Colors.grey[400],
                  ),
                  prefixIcon: languageProvider.isRTL ? null : Icon(
                    Icons.search,
                    color: themeProvider.isDarkMode
                        ? Colors.grey[600]
                        : Colors.grey[400],
                  ),
                  suffixIcon: languageProvider.isRTL ? Icon(
                    Icons.search,
                    color: themeProvider.isDarkMode
                        ? Colors.grey[600]
                        : Colors.grey[400],
                  ) : null,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
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
            child: _isLoading
                ? Center(
                    child: LoadingAnimationWidget.threeArchedCircle(
                      color: themeProvider.theme.colorScheme.primary,
                      size: 50,
                    ),
                  )
                : _filteredDiseases.isEmpty
                    ? (_isOffline
                        ? OfflineErrorState(onRetry: _loadDiseasesData)
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.sick_outlined,
                                  size: 80,
                                  color: themeProvider.isDarkMode
                                      ? Colors.grey[700]
                                      : Colors.grey[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'هیچ نەخۆشییەک نەدۆزرایەوە',
                                  style: TextStyle(
                                    color: themeProvider.isDarkMode
                                        ? Colors.grey[500]
                                        : Colors.grey[500],
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ))
                    : RefreshIndicator(
                        onRefresh: _loadDiseasesData,
                        child: ListView.builder(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                          itemCount: _filteredDiseases.length,
                          itemBuilder: (context, index) {
                            final disease = _filteredDiseases[index];
                            final isFavorite = favoritesProvider.isFavorite(disease);

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
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    Navigator.of(context).push(createRoute(
                                      DiseaseDetailsPage(disease: disease),
                                    ));
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        if (disease.imageUrl.isNotEmpty)
                                          Container(
                                            width: 60,
                                            height: 60,
                                            margin: const EdgeInsets.only(right: 16),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              image: DecorationImage(
                                                image: NetworkImage(disease.imageUrl),
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                disease.name,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: themeProvider.isDarkMode
                                                      ? Colors.white
                                                      : Colors.black87,
                                                ),
                                              ),
                                              if (disease.category.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  disease.category,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: themeProvider.isDarkMode
                                                        ? Colors.grey[500]
                                                        : Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            isFavorite
                                                ? Icons.bookmark
                                                : Icons.bookmark_border,
                                            color: isFavorite
                                                ? (themeProvider.isDarkMode
                                                        ? const Color(0xFF4A7EB5)
                                                        : const Color(0xFF1A3460))
                                                : (themeProvider.isDarkMode
                                                    ? Colors.grey[600]
                                                    : Colors.grey[400]),
                                          ),
                                          onPressed: () {
                                            if (isFavorite) {
                                              favoritesProvider.removeFavorite(disease);
                                            } else {
                                              favoritesProvider.addFavorite(disease);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _startPeriodicSync() async {
    // Check for updates every 30 seconds in background
    Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (mounted) {
        try {
          final hasUpdates = await _syncService.checkForCategoryUpdates('diseases');
          if (hasUpdates && mounted) {
            // Update data silently without showing loading
            final updatedData = _syncService.getCachedDiseases().cast<Disease>();
            setState(() {
              _diseases = updatedData.where((disease) => disease.name.isNotEmpty).toList();
              _filteredDiseases = _diseases.where((disease) =>
                  disease.name.toLowerCase().contains(_searchController.text.toLowerCase()) ||
                  disease.category.toLowerCase().contains(_searchController.text.toLowerCase())).toList();
            });
          }
        } catch (e) {
          // Silent fail for background sync
          if (kDebugMode) debugPrint('Background sync error: $e');
        }
      }
    });
  }
}