import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../providers/theme_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/language_provider.dart';
import '../providers/history_provider.dart';
import '../models/drug.dart';
import '../services/sync_service.dart';
import '../services/encrypted_cache_service.dart';
import '../services/connectivity_service.dart';
import 'drug_details_page.dart';
import 'package:vetstan/utils/page_transition.dart';
import '../widgets/offline_banner.dart';
import '../widgets/offline_error_state.dart';

// Enum for drug classification
enum DrugClass {
  antibiotic,
  painkiller,
  antiviral,
  antiparasitic,
  hormone,
  other
}

// Extension to provide user-friendly string representation
extension DrugClassExtension on DrugClass {
  String get displayName {
    switch (this) {
      case DrugClass.antibiotic:
        return 'Antibiotics';
      case DrugClass.painkiller:
        return 'Painkillers';
      case DrugClass.antiviral:
        return 'Antivirals';
      case DrugClass.antiparasitic:
        return 'Antiparasitics';
      case DrugClass.hormone:
        return 'Hormones';
      case DrugClass.other:
        return 'Other';
    }
  }

  Color get color {
    switch (this) {
      case DrugClass.antibiotic:
        return const Color(0xFF1A3460);
      case DrugClass.painkiller:
        return Colors.red.shade700;
      case DrugClass.antiviral:
        return Colors.green.shade700;
      case DrugClass.antiparasitic:
        return Colors.purple.shade700;
      case DrugClass.hormone:
        return Colors.orange.shade700;
      case DrugClass.other:
        return Colors.grey.shade700;
    }
  }
}

class DrugsPage extends StatefulWidget {
  const DrugsPage({Key? key}) : super(key: key);

  @override
  State<DrugsPage> createState() => _DrugsPageState();
}

class _DrugsPageState extends State<DrugsPage> with SingleTickerProviderStateMixin {
  final SyncService _syncService = SyncService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<Drug> _drugs = [];
  List<Drug> _filteredDrugs = [];
  bool _isLoading = true;
  bool _isOffline = false;
  Set<String> _availableClasses = <String>{};
  String? _selectedClass;

  void _onDrugTap(BuildContext context, Drug drug) {
    // Add to history
    Provider.of<HistoryProvider>(context, listen: false).addToHistory(
      drug.name,
      'drug',
      'Viewed drug details'
    );

    // Navigate to drug details with custom transition
    Navigator.push(
      context,
      createRoute(DrugDetailsPage(drug: drug)),
    );
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
                          // Class filter section
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
                          
                          // Class chips
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildFilterChip(
                                'هەموو',
                                Icons.apps_rounded,
                                themeProvider.theme.colorScheme.primary,
                                _selectedClass == null,
                                () {
                                  setModalState(() => _selectedClass = null);
                                },
                                isDarkMode,
                              ),
                              ..._availableClasses.map((classValue) => _buildFilterChip(
                                    classValue,
                                    Icons.medical_services,
                                    themeProvider.theme.colorScheme.primary,
                                    _selectedClass == classValue,
                                    () {
                                      setModalState(() => _selectedClass = classValue);
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
                                _selectedClass = null;
                                _filterDrugs(_searchController.text);
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
                                _filterDrugs(_searchController.text);
                              });
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: Text(
                              'جێبەجێکردن (${_filteredDrugs.length})',
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
              textDirection: TextDirection.ltr,
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

  @override
  void initState() {
    super.initState();
    _loadDrugsData();
    _checkForUpdates();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDrugsData() async {
    if (mounted) setState(() { _isLoading = true; _isOffline = false; });
    final encCache = EncryptedCacheService();

    try {
      final bool online = await ConnectivityService.isOnline();
      if (mounted) setState(() => _isOffline = !online);

      if (online) {
        final drugsList = await _syncService.loadCategoryData<Drug>('drugs');
        final filtered = drugsList.where((drug) => drug.name.isNotEmpty).toList();

        // Save to encrypted cache for offline use
        await encCache.saveDrugs(filtered.map((d) => d.toJson()).toList());

        if (mounted) {
          setState(() {
            _drugs = filtered;
            _filteredDrugs = _drugs;
            _availableClasses = _drugs.map((d) => d.drugClass).where((c) => c.isNotEmpty).toSet();
            _isLoading = false;
          });
        }
      } else {
        // Offline: load from encrypted cache
        final cached = await encCache.loadDrugs();
        final drugs = cached.map((json) => Drug.fromJson(json)).where((d) => d.name.isNotEmpty).toList();

        if (mounted) {
          setState(() {
            _drugs = drugs;
            _filteredDrugs = _drugs;
            _availableClasses = _drugs.map((d) => d.drugClass).where((c) => c.isNotEmpty).toSet();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading drugs: $e');
      try {
        final cached = await encCache.loadDrugs();
        final drugs = cached.map((json) => Drug.fromJson(json)).where((d) => d.name.isNotEmpty).toList();
        if (mounted && drugs.isNotEmpty) {
          setState(() {
            _drugs = drugs;
            _filteredDrugs = _drugs;
            _availableClasses = _drugs.map((d) => d.drugClass).where((c) => c.isNotEmpty).toSet();
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
    final hasUpdates = await _syncService.checkForCategoryUpdates('drugs');
    if (hasUpdates && mounted) {
      // Refresh the data silently
      final updatedData = _syncService.getCachedDrugs().cast<Drug>();
      setState(() {
        _drugs = updatedData.where((drug) => drug.name.isNotEmpty).toList();
        _availableClasses = _drugs.map((d) => d.drugClass).where((c) => c.isNotEmpty).toSet();
        _filterDrugs(_searchController.text);
      });
    }
  }

  void _filterDrugs(String query) {
    setState(() {
      _filteredDrugs = _drugs.where((drug) {
        final nameMatch = drug.name.toLowerCase().contains(query.toLowerCase());
        final classMatch = _selectedClass == null || drug.drugClass == _selectedClass;
        return nameMatch && classMatch;
      }).toList();
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
          'دەرمانەکان',
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
            child: Row(
              children: [
                Expanded(
                  child: Directionality(
                    textDirection: languageProvider.textDirection,
                    child: TextField(
                      controller: _searchController,
                      onChanged: _filterDrugs,
                      textDirection: languageProvider.textDirection,
                      style: TextStyle(
                        color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'گەڕان لە دەرمانەکان...',
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ),
                Container(
                  height: 24,
                  width: 1,
                  color: themeProvider.isDarkMode
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.grey.withValues(alpha: 0.2),
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),
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
                    if (_selectedClass != null)
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
                : _filteredDrugs.isEmpty
              ? (_isOffline
                  ? OfflineErrorState(onRetry: _loadDrugsData)
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.medical_services_outlined,
                            size: 80,
                            color: themeProvider.isDarkMode
                                ? Colors.grey[700]
                                : Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'هیچ دەرمانێک نەدۆزرایەوە',
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
                  onRefresh: _loadDrugsData,
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      physics: const BouncingScrollPhysics(),
                    ),
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                      itemCount: _filteredDrugs.length,
                      itemBuilder: (context, index) {
                        final drug = _filteredDrugs[index];
                        final isFavorite = favoritesProvider.isFavorite(drug);

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
                              onTap: () => _onDrugTap(context, drug),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            drug.name,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: themeProvider.isDarkMode
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                          if (drug.drugClass.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              drug.drugClass,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: themeProvider.isDarkMode
                                                    ? Colors.grey[400]
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
                                          favoritesProvider.removeFavorite(drug);
                                        } else {
                                          favoritesProvider.addFavorite(drug);
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
          ),
        ],
      ),
    );
  }
}