import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../providers/theme_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/language_provider.dart';
import '../models/word.dart';
import '../services/api_service.dart';
import '../services/encrypted_cache_service.dart';
import '../services/connectivity_service.dart';
import 'terminology_details_page.dart';
import 'package:vetstan/utils/page_transition.dart';
import '../widgets/offline_banner.dart';
import '../widgets/offline_error_state.dart';

// Enum for terminology classification
enum TerminologyClass {
  antibiotic,
  painkiller,
  antiviral,
  antiparasitic,
  hormone,
  other
}

// Extension to provide user-friendly string representation
extension TerminologyClassExtension on TerminologyClass {
  String get displayName {
    switch (this) {
      case TerminologyClass.antibiotic:
        return 'Antibiotics';
      case TerminologyClass.painkiller:
        return 'Painkillers';
      case TerminologyClass.antiviral:
        return 'Antivirals';
      case TerminologyClass.antiparasitic:
        return 'Antiparasitics';
      case TerminologyClass.hormone:
        return 'Hormones';
      case TerminologyClass.other:
        return 'Other';
    }
  }

  Color get color {
    switch (this) {
      case TerminologyClass.antibiotic:
        return const Color(0xFF1A3460);
      case TerminologyClass.painkiller:
        return Colors.red.shade700;
      case TerminologyClass.antiviral:
        return Colors.green.shade700;
      case TerminologyClass.antiparasitic:
        return Colors.purple.shade700;
      case TerminologyClass.hormone:
        return Colors.orange.shade700;
      case TerminologyClass.other:
        return Colors.grey.shade700;
    }
  }
}

class TerminologyPage extends StatefulWidget {
  const TerminologyPage({Key? key}) : super(key: key);

  @override
  State<TerminologyPage> createState() => _TerminologyPageState();
}

class _TerminologyPageState extends State<TerminologyPage> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  static final ApiService _apiService = ApiService();
  final EncryptedCacheService _encCache = EncryptedCacheService();

  List<Word> _terminology = [];
  List<Word> _filteredTerminology = [];
  bool _isLoading = true;
  bool _isOffline = false;
  bool _isSearchingDatabase = false;
  bool _isLoadingMore = false;
  // ignore: unused_field
  String _statusMessage = 'Loading terminology...';
  Timer? _searchTimer;
  
  // Pagination variables
  int _currentPage = 0;
  static const int _pageSize = 100; // Load 100 words per page for UI
  bool _hasMoreData = true;
  List<Word> _allTerminology = []; // Full dataset for search

  // Background sync state
  bool _isBackgroundSyncing = false;
  int _bgSyncDownloaded = 0;
  bool _bgSyncComplete = false;
  static const int _bgBatchSize = 500; // Download 500 terms per batch in background

  @override
  void initState() {
    super.initState();
    _loadTerminologyData();
    _scrollController.addListener(_onScroll);
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 500) {
      // Load more when user is 500px from bottom
      if (!_isLoadingMore && _hasMoreData && _searchController.text.isEmpty) {
        _loadMoreTerminology();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTerminologyData() async {
    try {
      setState(() {
        _statusMessage = 'Loading terminology...';
        _isLoading = true;
      });

      bool online = true;
      try {
        online = await ConnectivityService.isOnline();
      } catch (_) {
        online = true;
      }
      if (mounted) setState(() => _isOffline = !online);

      if (online) {
        // Load first page from API for instant display
        final terminologyList = await _apiService.fetchDictionaryPage(skip: 0, limit: _pageSize);
        
        if (mounted) {
          setState(() {
            _terminology = terminologyList;
            _filteredTerminology = terminologyList;
            _allTerminology = List.from(terminologyList);
            _currentPage = 0;
            _hasMoreData = terminologyList.length >= _pageSize;
            _isLoading = false;
            _statusMessage = 'Loaded ${_terminology.length} terms';
          });
        }

        // Start background sync to download ALL terms for offline use
        _startBackgroundSync();
      } else {
        // Offline: load ALL data from chunked encrypted cache
        await _loadFromOfflineCache();
      }
    } catch (e) {
      // Try offline cache as fallback
      await _loadFromOfflineCache();
    }
  }

  /// Load all terminology from encrypted cache (chunked or legacy)
  Future<void> _loadFromOfflineCache() async {
    try {
      // Try chunked storage first (has all 26k+ terms)
      final cached = await _encCache.loadAllTerminologyChunks();
      
      final terminologyList = cached.map((json) => Word.fromJson(json)).toList();

      if (mounted && terminologyList.isNotEmpty) {
        setState(() {
          _terminology = terminologyList.take(_pageSize).toList();
          _filteredTerminology = _terminology;
          _allTerminology = terminologyList;
          _currentPage = 0;
          _hasMoreData = terminologyList.length > _pageSize;
          _isLoading = false;
          _bgSyncComplete = true;
          _statusMessage = 'Loaded ${terminologyList.length} terms (offline)';
        });
        return;
      }
    } catch (e) {
      // Error loading chunks
    }

    // Nothing cached at all
    if (mounted) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'No cached data available';
      });
    }
  }

  /// Background progressive sync: downloads all terms in batches without blocking UI
  Future<void> _startBackgroundSync() async {
    if (_isBackgroundSyncing) return;

    // Check if sync already completed previously
    final prefs = await SharedPreferences.getInstance();
    final syncComplete = prefs.getBool('term_sync_complete') ?? false;
    if (syncComplete) {
      // Already synced — load all from cache into _allTerminology for search
      await _loadAllCachedIntoMemory();
      // Then check for new/updated words in background
      _checkForNewAndUpdatedWords();
      return;
    }

    // Check where we left off last time
    final previousProgress = await _encCache.getTermSyncProgress();
    
    if (mounted) {
      setState(() {
        _isBackgroundSyncing = true;
        _bgSyncDownloaded = previousProgress;
      });
    }

    int skip = previousProgress;
    int chunkIndex = skip ~/ EncryptedCacheService.termChunkSize;
    List<Map<String, dynamic>> currentChunk = [];
    final Set<String> seenIds = {};

    // Add already-loaded terms to seen set to avoid duplicates
    for (final term in _allTerminology) {
      seenIds.add(term.id);
    }

    try {
      while (true) {
        if (!mounted) return;

        // Check connectivity periodically
        bool stillOnline = true;
        try {
          stillOnline = await ConnectivityService.isOnline();
        } catch (_) {}
        if (!stillOnline) {
          break;
        }

        // Fetch a batch from API
        final batch = await _apiService.fetchDictionaryPage(skip: skip, limit: _bgBatchSize);
        if (batch.isEmpty) {
          break;
        }

        // Deduplicate
        final newTerms = <Word>[];
        for (final term in batch) {
          final id = term.id;
          if (!seenIds.contains(id)) {
            seenIds.add(id);
            newTerms.add(term);
          }
        }

        // Add to in-memory search index
        if (newTerms.isNotEmpty && mounted) {
          _allTerminology.addAll(newTerms);
        }

        // Accumulate into chunk for encrypted cache
        currentChunk.addAll(newTerms.map((w) => w.toJson()).toList());

        // Save chunk when it reaches chunk size
        while (currentChunk.length >= EncryptedCacheService.termChunkSize) {
          final toSave = currentChunk.sublist(0, EncryptedCacheService.termChunkSize);
          await _encCache.saveTerminologyChunk(chunkIndex, toSave);
          chunkIndex++;
          await _encCache.saveTerminologyChunkCount(chunkIndex);
          currentChunk = currentChunk.sublist(EncryptedCacheService.termChunkSize);
        }

        skip += batch.length;

        // Save progress
        await _encCache.saveTermSyncProgress(skip);

        // Update UI progress (throttled)
        if (mounted) {
          setState(() {
            _bgSyncDownloaded = skip;
          });
        }

        // Small delay to avoid overwhelming the API and keep UI responsive
        await Future.delayed(const Duration(milliseconds: 200));

        // If batch was smaller than requested, we've reached the end
        if (batch.length < _bgBatchSize) {
          break;
        }
      }

      // Save any remaining partial chunk
      if (currentChunk.isNotEmpty) {
        await _encCache.saveTerminologyChunk(chunkIndex, currentChunk);
        chunkIndex++;
        await _encCache.saveTerminologyChunkCount(chunkIndex);
      }

      // Mark sync as complete and save total count for incremental sync
      await prefs.setBool('term_sync_complete', true);
      await _encCache.saveTermSyncProgress(skip);
      await _encCache.saveTermTotalCount(_allTerminology.length);

      if (mounted) {
        setState(() {
          _isBackgroundSyncing = false;
          _bgSyncComplete = true;
          _bgSyncDownloaded = _allTerminology.length;
        });
      }
    } catch (e) {
      // Save progress so we can resume later
      await _encCache.saveTermSyncProgress(skip);
      if (currentChunk.isNotEmpty) {
        await _encCache.saveTerminologyChunk(chunkIndex, currentChunk);
        chunkIndex++;
        await _encCache.saveTerminologyChunkCount(chunkIndex);
      }

      if (mounted) {
        setState(() {
          _isBackgroundSyncing = false;
        });
      }
    }
  }

  /// Incremental sync: check for NEW words and UPDATED existing words
  Future<void> _checkForNewAndUpdatedWords() async {
    if (!mounted) return;

    try {
      bool online = true;
      try { online = await ConnectivityService.isOnline(); } catch (_) {}
      if (!online) return;

      // ── Step 1: Check for NEW words ──────────────────────────────
      final dbTotal = await _apiService.fetchDictionaryTotalCount();
      if (dbTotal <= 0) return; // API doesn't support total count

      final cachedTotal = await _encCache.getTermTotalCount();

      if (dbTotal > cachedTotal && cachedTotal > 0) {
        if (mounted) {
          setState(() { _isBackgroundSyncing = true; });
        }

        // Download only the new words starting from where we left off
        int skip = cachedTotal;
        int chunkIndex = await _encCache.getTerminologyChunkCount();
        List<Map<String, dynamic>> currentChunk = [];
        final existingIds = _allTerminology.map((w) => w.id).toSet();

        while (skip < dbTotal) {
          if (!mounted) return;
          final batch = await _apiService.fetchDictionaryPage(skip: skip, limit: _bgBatchSize);
          if (batch.isEmpty) break;

          final newTerms = <Word>[];
          for (final term in batch) {
            if (!existingIds.contains(term.id)) {
              existingIds.add(term.id);
              newTerms.add(term);
            }
          }

          if (newTerms.isNotEmpty) {
            _allTerminology.addAll(newTerms);
            currentChunk.addAll(newTerms.map((w) => w.toJson()).toList());

            while (currentChunk.length >= EncryptedCacheService.termChunkSize) {
              final toSave = currentChunk.sublist(0, EncryptedCacheService.termChunkSize);
              await _encCache.saveTerminologyChunk(chunkIndex, toSave);
              chunkIndex++;
              await _encCache.saveTerminologyChunkCount(chunkIndex);
              currentChunk = currentChunk.sublist(EncryptedCacheService.termChunkSize);
            }
          }

          skip += batch.length;
          if (batch.length < _bgBatchSize) break;
          await Future.delayed(const Duration(milliseconds: 200));
        }

        // Save remaining partial chunk
        if (currentChunk.isNotEmpty) {
          await _encCache.saveTerminologyChunk(chunkIndex, currentChunk);
          chunkIndex++;
          await _encCache.saveTerminologyChunkCount(chunkIndex);
        }

        // Update total count
        await _encCache.saveTermTotalCount(_allTerminology.length);
        await _encCache.saveTermSyncProgress(_allTerminology.length);
      }

      // ── Step 2: Check for UPDATED existing words ─────────────────
      // Re-fetch the most recent 2000 words and compare with cached versions.
      // Words are typically added/updated at the end, so checking the tail
      // catches most edits without re-downloading the entire dataset.
      int updatedCount = 0;
      const int refreshWindow = 2000; // Check last 2000 words for updates
      final int refreshStart = (dbTotal - refreshWindow).clamp(0, dbTotal);

      if (refreshStart >= 0 && dbTotal > 0) {
        // Build a map of existing terms by ID for fast lookup
        final Map<String, Word> existingById = {};
        for (final term in _allTerminology) {
          existingById[term.id] = term;
        }

        int checkSkip = refreshStart;
        while (checkSkip < dbTotal) {
          if (!mounted) return;
          final batch = await _apiService.fetchDictionaryPage(skip: checkSkip, limit: _bgBatchSize);
          if (batch.isEmpty) break;

          for (final term in batch) {
            final existing = existingById[term.id];
            if (existing != null) {
              // Compare fields to detect updates
              if (existing.name != term.name ||
                  existing.kurdish != term.kurdish ||
                  existing.arabic != term.arabic ||
                  existing.description != term.description ||
                  existing.imageUrl != term.imageUrl) {
                // Replace in memory
                final idx = _allTerminology.indexWhere((w) => w.id == term.id);
                if (idx != -1) {
                  _allTerminology[idx] = term;
                  updatedCount++;
                }
              }
            }
          }

          checkSkip += batch.length;
          if (batch.length < _bgBatchSize) break;
          await Future.delayed(const Duration(milliseconds: 200));
        }

        // If any words were updated, rebuild and save the affected chunks
        if (updatedCount > 0) {
          await _rebuildCacheFromMemory();
        }
      }

      if (mounted) {
        setState(() {
          _isBackgroundSyncing = false;
          _bgSyncDownloaded = _allTerminology.length;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isBackgroundSyncing = false; });
      }
    }
  }

  /// Rebuild all cache chunks from the current in-memory _allTerminology list
  Future<void> _rebuildCacheFromMemory() async {
    try {
      final allJson = _allTerminology.map((w) => w.toJson()).toList();
      int chunkIndex = 0;
      for (int i = 0; i < allJson.length; i += EncryptedCacheService.termChunkSize) {
        final end = (i + EncryptedCacheService.termChunkSize).clamp(0, allJson.length);
        await _encCache.saveTerminologyChunk(chunkIndex, allJson.sublist(i, end));
        chunkIndex++;
      }
      await _encCache.saveTerminologyChunkCount(chunkIndex);
      await _encCache.saveTermTotalCount(_allTerminology.length);
      await _encCache.saveTermSyncProgress(_allTerminology.length);
    } catch (e) {
      // Error rebuilding cache
    }
  }

  /// Load all cached terms into memory for search (when sync was already complete)
  Future<void> _loadAllCachedIntoMemory() async {
    try {
      final cached = await _encCache.loadAllTerminologyChunks();
      if (cached.isNotEmpty && mounted) {
        final allTerms = cached.map((json) => Word.fromJson(json)).toList();
        setState(() {
          _allTerminology = allTerms;
          _bgSyncComplete = true;
          _bgSyncDownloaded = allTerms.length;
        });
      }
    } catch (e) {
      // Error loading cached terms
    }
  }
  
  Future<void> _loadMoreTerminology() async {
    if (_isLoadingMore || !_hasMoreData) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    try {
      final nextPage = _currentPage + 1;
      final skip = nextPage * _pageSize;

      // If background sync has loaded more data, use it from memory
      if (_allTerminology.length > skip) {
        final end = (skip + _pageSize).clamp(0, _allTerminology.length);
        final nextBatch = _allTerminology.sublist(skip, end);
        if (mounted) {
          setState(() {
            _terminology.addAll(nextBatch);
            _filteredTerminology = _terminology;
            _currentPage = nextPage;
            _hasMoreData = _allTerminology.length > end;
            _statusMessage = 'Loaded ${_terminology.length} terms';
            _isLoadingMore = false;
          });
        }
        return;
      }

      // Otherwise fetch from API
      final newTerms = await _apiService.fetchDictionaryPage(skip: skip, limit: _pageSize);
      
      if (mounted) {
        setState(() {
          if (newTerms.isNotEmpty) {
            _terminology.addAll(newTerms);
            _filteredTerminology = _terminology;
            _currentPage = nextPage;
            _hasMoreData = newTerms.length >= _pageSize;
            _statusMessage = 'Loaded ${_terminology.length} terms';
          } else {
            _hasMoreData = false;
          }
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _hasMoreData = false;
        });
      }
    }
  }

  Future<void> _refreshTerminologyData() async {
    try {
      // Clear sync state and re-sync
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('term_sync_complete', false);
      await _encCache.clearTerminologyChunks();

      setState(() {
        _bgSyncComplete = false;
        _bgSyncDownloaded = 0;
      });

      await _loadTerminologyData();
    } catch (e) {
      // Error refreshing terminology
    }
  }

  void _filterTerminology(String query) {
    // Cancel any existing search timer
    _searchTimer?.cancel();
    
    if (query.isEmpty) {
      setState(() {
        _filteredTerminology = _terminology;
        _isSearchingDatabase = false;
        _statusMessage = 'Loaded ${_terminology.length} terms';
      });
      return;
    }

    final lowerQuery = query.toLowerCase();

    // Search in ALL loaded data (includes background-synced terms)
    final cachedResults = _allTerminology
        .where((terminology) =>
            terminology.name.toLowerCase().contains(lowerQuery) ||
            terminology.kurdish.toLowerCase().contains(lowerQuery) ||
            terminology.arabic.toLowerCase().contains(lowerQuery) ||
            terminology.description.toLowerCase().contains(lowerQuery))
        .toList();

    setState(() {
      _filteredTerminology = cachedResults;
      _statusMessage = 'Found ${cachedResults.length} results';
    });

    // If sync is complete, local search is sufficient — no need for API
    if (_bgSyncComplete) {
      setState(() {
        _isSearchingDatabase = false;
      });
      return;
    }

    // If sync is NOT complete, also search API as fallback (debounced)
    setState(() {
      _isSearchingDatabase = true;
    });
    _searchTimer = Timer(const Duration(milliseconds: 500), () {
      _searchDatabase(query);
    });
  }
  
  Future<void> _searchDatabase(String query) async {
    if (!mounted) return;
    
    try {
      final results = await _apiService.searchDictionary(query, limit: 100);
      
      if (mounted && _searchController.text == query) {
        // Merge API results with local results (deduplicated)
        final existingIds = _filteredTerminology.map((w) => w.id).toSet();
        final newResults = results.where((w) => !existingIds.contains(w.id)).toList();

        setState(() {
          // Add new results to filtered list (no separate database results)
          if (newResults.isNotEmpty) {
            _filteredTerminology.addAll(newResults);
          }
          _isSearchingDatabase = false;
          _statusMessage = 'Found ${_filteredTerminology.length} results';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearchingDatabase = false;
        });
      }
    }
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
          'زاراوەکان',
          style: TextStyle(
            color: themeProvider.isDarkMode
                ? themeProvider.theme.colorScheme.onSurface
                : Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_isBackgroundSyncing)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Tooltip(
                message: 'دادەبەزێت بۆ ئۆفلاین: $_bgSyncDownloaded',
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: themeProvider.isDarkMode
                        ? themeProvider.theme.colorScheme.primary
                        : Colors.white70,
                  ),
                ),
              ),
            )
          else if (_bgSyncComplete)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Tooltip(
                message: '${_allTerminology.length} زاراوە ئامادەیە بۆ ئۆفلاین',
                child: Icon(
                  Icons.cloud_done_outlined,
                  color: themeProvider.isDarkMode
                      ? Colors.green.shade300
                      : Colors.white70,
                  size: 20,
                ),
              ),
            ),
        ],
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
                onChanged: _filterTerminology,
                textDirection: languageProvider.textDirection,
                style: TextStyle(
                  color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'گەڕان بە زاراوەکان...',
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
                  suffixIcon: languageProvider.isRTL ? (_isSearchingDatabase
                    ? Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: themeProvider.theme.colorScheme.primary,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.search,
                        color: themeProvider.isDarkMode
                            ? Colors.grey[600]
                            : Colors.grey[400],
                      )) : (_searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: themeProvider.isDarkMode
                              ? Colors.grey[600]
                              : Colors.grey[400],
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _filterTerminology('');
                        },
                      )
                    : null),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                : (_filteredTerminology.isEmpty && !_isSearchingDatabase && !_isLoading)
              ? (_isOffline && _searchController.text.isEmpty
                  ? OfflineErrorState(onRetry: _loadTerminologyData)
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 80,
                            color: themeProvider.isDarkMode
                                ? Colors.grey[700]
                                : Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchController.text.isNotEmpty
                                ? 'هیچ زاراوەیەک نەدۆزرایەوە'
                                : 'زاراوەکان بارناکرێن',
                            style: TextStyle(
                              color: themeProvider.isDarkMode
                                  ? Colors.grey[500]
                                  : Colors.grey[500],
                              fontSize: 18,
                            ),
                          ),
                          if (_searchController.text.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: TextButton.icon(
                                onPressed: _loadTerminologyData,
                                icon: const Icon(Icons.refresh),
                                label: const Text('هەوڵبدەرەوە'),
                              ),
                            ),
                        ],
                      ),
                    ))
              : RefreshIndicator(
                  onRefresh: _refreshTerminologyData,
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredTerminology.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Show loading indicator at bottom
                      if (index == _filteredTerminology.length) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          alignment: Alignment.center,
                          child: LoadingAnimationWidget.staggeredDotsWave(
                            color: themeProvider.theme.colorScheme.primary,
                            size: 40,
                          ),
                        );
                      }
                      final terminology = _filteredTerminology[index];
                      final isFavorite = favoritesProvider.isFavorite(terminology);

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
                                TerminologyDetailsPage(terminology: terminology),
                              ));
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                terminology.name,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: themeProvider.isDarkMode
                                                      ? Colors.white
                                                      : Colors.black87,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
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
                                        favoritesProvider.removeFavorite(terminology);
                                      } else {
                                        favoritesProvider.addFavorite(terminology);
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
}