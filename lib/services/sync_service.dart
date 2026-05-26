
import 'dart:async';
import 'dart:developer' as developer;

import '../database/database_helper.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../services/encrypted_cache_service.dart';
import '../services/connectivity_service.dart';
import '../models/word.dart';
import '../models/disease.dart';
import '../models/drug.dart';
import '../models/book.dart';
import '../models/note.dart';
import '../models/instrument.dart';
import '../models/normal_range.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final ApiService _apiService = ApiService();
  final DatabaseHelper _database = DatabaseHelper();
  final CacheService _cacheService = CacheService();
  final EncryptedCacheService _encCache = EncryptedCacheService();
  final StreamController<bool> _syncController = StreamController<bool>.broadcast();
  final StreamController<String> _statusController = StreamController<String>.broadcast();

  Stream<bool> get syncStream => _syncController.stream;
  Stream<String> get statusStream => _statusController.stream;

  // Update cached dictionary with new terms
  Future<void> updateCachedDictionary(List<Word> updatedTerminology) async {
    await _cacheService.cacheDictionary(updatedTerminology);
  }

  // Force refresh data from API (for pull-to-refresh)
  Future<List<T>> forceRefreshCategoryData<T>(String dataType) async {
    try {
      // Fetch fresh data from API
      List<T> data = await _fetchDataByType<T>(dataType);
      
      // Cache the fresh data
      await _cacheDataByType(dataType, data);
      
      // Also save to encrypted cache for secure offline access (non-critical)
      try {
        await _saveToEncryptedCache(dataType, data);
      } catch (e) {
        developer.log('[SyncService] Non-critical: encrypted cache save failed for $dataType: $e');
      }
      
      // Store in SQLite for backward compatibility (non-critical)
      try {
        await _storeSQLiteDataByType(dataType, data);
      } catch (e) {
        developer.log('[SyncService] Non-critical: SQLite save failed for $dataType: $e');
      }

      // Update sync timestamp
      await _cacheService.setLastSyncTime(dataType, DateTime.now().toIso8601String());
      
      return data;
    } catch (e) {
      developer.log('Error force refreshing $dataType: $e');
      
      // Try encrypted cache first
      try {
        final encData = await _loadFromEncryptedCache<T>(dataType);
        if (encData.isNotEmpty) return encData;
      } catch (_) {}
      
      // Return regular cached data if available
      if (_cacheService.hasCachedData(dataType)) {
        return _getCachedDataByType<T>(dataType);
      }
      
      rethrow;
    }
  }

  Future<void> initializeApp() async {
    try {
      await _cacheService.init();
      
      if (_cacheService.isFirstInstall()) {
        await _cacheService.setFirstInstall(false);
      }
    } catch (e) {
      // Don't add status updates during silent initialization
      rethrow;
    }
  }

  // Load data for a specific category
  Future<List<T>> loadCategoryData<T>(String dataType) async {
    try {
      // Check if data is already loaded and cached
      if (_cacheService.isDataLoaded(dataType) && _cacheService.hasCachedData(dataType)) {
        return _getCachedDataByType<T>(dataType);
      }

      // Check connectivity before fetching (non-blocking: default to online on failure)
      bool online = true;
      try {
        online = await ConnectivityService.isOnline();
      } catch (_) {
        online = true; // Assume online if check fails
      }

      if (!online) {
        // Offline: try encrypted cache first
        try {
          final encData = await _loadFromEncryptedCache<T>(dataType);
          if (encData.isNotEmpty) {
            developer.log('[SyncService] Loaded $dataType from encrypted cache (offline)');
            return encData;
          }
        } catch (_) {}
        // Fall back to regular cache
        if (_cacheService.hasCachedData(dataType)) {
          return _getCachedDataByType<T>(dataType);
        }
        throw Exception('No internet and no cached data for $dataType');
      }

      // First time loading this category - show loading and fetch from API
      _syncController.add(true);
      _statusController.add('Loading $dataType...');

      List<T> data = await _fetchDataByType<T>(dataType);
      
      // Cache the data in memory (critical - must succeed)
      await _cacheDataByType(dataType, data);
      
      // Save to encrypted cache in background (non-critical)
      try {
        await _saveToEncryptedCache(dataType, data);
      } catch (e) {
        developer.log('[SyncService] Non-critical: encrypted cache save failed for $dataType: $e');
      }
      
      // Store in SQLite for backward compatibility (non-critical)
      try {
        await _storeSQLiteDataByType(dataType, data);
      } catch (e) {
        developer.log('[SyncService] Non-critical: SQLite save failed for $dataType: $e');
      }

      // Update sync timestamp
      await _cacheService.setLastSyncTime(dataType, DateTime.now().toIso8601String());

      _syncController.add(false);
      _statusController.add('$dataType loaded successfully');
      
      return data;
    } catch (e) {
      developer.log('Error loading $dataType: $e');
      _syncController.add(false);
      _statusController.add('Error loading $dataType');
      
      // Try encrypted cache first (more secure)
      try {
        final encData = await _loadFromEncryptedCache<T>(dataType);
        if (encData.isNotEmpty) return encData;
      } catch (_) {}

      // Return regular cached data if available
      if (_cacheService.hasCachedData(dataType)) {
        return _getCachedDataByType<T>(dataType);
      }
      
      rethrow;
    }
  }

  // Check for updates for a specific category
  Future<bool> checkForCategoryUpdates(String dataType) async {
    try {
      final lastSync = _cacheService.getLastSyncTime(dataType);
      if (lastSync == null) {
        // No previous sync, force full load
        await loadCategoryData(dataType);
        return true;
      }

      List<dynamic> updates = await _fetchUpdatesForType(dataType, lastSync);
      
      if (updates.isNotEmpty) {
        _statusController.add('Syncing ${updates.length} new $dataType entries...');
        await _mergeUpdatesForType(dataType, updates);
        await _cacheService.setLastSyncTime(dataType, DateTime.now().toIso8601String());
        await _updateSQLiteFromCacheForType(dataType);
        
        _statusController.add('Found ${updates.length} new $dataType entries');
        return true;
      }
      
      return false;
    } catch (e) {
      developer.log('Error checking updates for $dataType: $e');
      // If checking updates fails, try to force reload all data
      try {
        await forceCategorySync(dataType);
        return true;
      } catch (e2) {
        developer.log('Error in force category sync: $e2');
        return false;
      }
    }
  }

  // Force sync for a specific category
  Future<void> forceCategorySync(String dataType) async {
    try {
      _statusController.add('Force syncing $dataType...');
      
      // Clear cached data for this category
      await _cacheService.clearCategoryCache(dataType);
      
      // Fetch fresh data from API
      List<dynamic> data = await _fetchDataByType(dataType);
      
      // Cache the data
      await _cacheDataByType(dataType, data);
      
      // Also save to encrypted cache for secure offline access (non-critical)
      try {
        await _saveToEncryptedCache(dataType, data);
      } catch (e) {
        developer.log('[SyncService] Non-critical: encrypted cache save failed for $dataType: $e');
      }
      
      // Store in SQLite (non-critical)
      try {
        await _storeSQLiteDataByType(dataType, data);
      } catch (e) {
        developer.log('[SyncService] Non-critical: SQLite save failed for $dataType: $e');
      }

      // Update sync timestamp
      await _cacheService.setLastSyncTime(dataType, DateTime.now().toIso8601String());
      
      _statusController.add('$dataType force sync completed');
    } catch (e) {
      developer.log('Error in force category sync for $dataType: $e');
      _statusController.add('Error syncing $dataType');
      rethrow;
    }
  }

  // Check all categories for updates
  Future<bool> checkAllUpdates() async {
    bool hasUpdates = false;
    
    try {
      _statusController.add('Checking for updates...');
      
      final categories = ['dictionary', 'diseases', 'drugs', 'books', 'notes'];
      
      for (String category in categories) {
        if (_cacheService.isDataLoaded(category)) {
          bool categoryHasUpdates = await checkForCategoryUpdates(category);
          if (categoryHasUpdates) {
            hasUpdates = true;
          }
        }
      }
      
      if (hasUpdates) {
        _statusController.add('Updates synchronized successfully');
      } else {
        _statusController.add('No new updates found');
      }
      
      return hasUpdates;
    } catch (e) {
      developer.log('Error checking all updates: $e');
      _statusController.add('Error checking for updates');
      return false;
    }
  }

  // Auto-sync specific category when loading
  Future<List<T>> loadCategoryDataWithAutoSync<T>(String dataType) async {
    try {
      // First, load existing data if available
      List<T> data = [];
      
      if (_cacheService.isDataLoaded(dataType) && _cacheService.hasCachedData(dataType)) {
        data = _getCachedDataByType<T>(dataType);
        
        // Check for updates in background
        checkForCategoryUpdates(dataType).then((hasUpdates) {
          if (hasUpdates) {
            // Notify that new data is available
            _statusController.add('New $dataType data available');
          }
        }).catchError((e) {
          developer.log('Background update check failed for $dataType: $e');
        });
        
        return data;
      } else {
        // First time loading - fetch all data
        return await loadCategoryData<T>(dataType);
      }
    } catch (e) {
      developer.log('Error loading $dataType with auto-sync: $e');
      rethrow;
    }
  }

  // Generic method to fetch data by type
  Future<List<T>> _fetchDataByType<T>(String dataType) async {
    switch (dataType) {
      case 'dictionary':
        return (await _apiService.fetchAllDictionary()).cast<T>();
      case 'diseases':
        return (await _apiService.fetchAllDiseases()).cast<T>();
      case 'drugs':
        return (await _apiService.fetchAllDrugs()).cast<T>();
      case 'books':
        return (await _apiService.fetchAllBooks()).cast<T>();
      case 'notes':
        return (await _apiService.fetchAllNotes()).cast<T>();
      case 'instruments':
        return (await _apiService.fetchAllInstruments()).cast<T>();
      case 'normal_ranges':
        return (await _apiService.fetchAllNormalRanges()).cast<T>();
      default:
        throw Exception('Unknown data type: $dataType');
    }
  }

  // Generic method to fetch updates by type
  Future<List<dynamic>> _fetchUpdatesForType(String dataType, String since) async {
    switch (dataType) {
      case 'dictionary':
        return await _apiService.fetchDictionaryUpdates(since: since);
      case 'diseases':
        return await _apiService.fetchDiseaseUpdates(since: since);
      case 'drugs':
        return await _apiService.fetchDrugUpdates(since: since);
      case 'books':
        return await _apiService.fetchBookUpdates(since: since);
      case 'notes':
        // Currently API doesn’t expose incremental updates for notes. Return empty list.
        return [];
      case 'instruments':
        // Currently API doesn't expose incremental updates for instruments. Return empty list.
        return [];
      case 'normal_ranges':
        // Currently API doesn't expose incremental updates for normal ranges. Return empty list.
        return [];
      default:
        throw Exception('Unknown data type: $dataType');
    }
  }

  // Generic method to get cached data by type
  List<T> _getCachedDataByType<T>(String dataType) {
    switch (dataType) {
      case 'dictionary':
        return _cacheService.getCachedDictionary().cast<T>();
      case 'diseases':
        return _cacheService.getCachedDiseases().cast<T>();
      case 'drugs':
        return _cacheService.getCachedDrugs().cast<T>();
      case 'books':
        return _cacheService.getCachedBooks().cast<T>();
      case 'notes':
        return _cacheService.getCachedNotes().cast<T>();
      case 'instruments':
        return _cacheService.getCachedInstruments().cast<T>();
      case 'normal_ranges':
        return _cacheService.getCachedNormalRanges().cast<T>();
      default:
        throw Exception('Unknown data type: $dataType');
    }
  }

  // Generic method to cache data by type
  Future<void> _cacheDataByType(String dataType, List<dynamic> data) async {
    switch (dataType) {
      case 'dictionary':
        await _cacheService.cacheDictionary(data.cast());
        break;
      case 'diseases':
        await _cacheService.cacheDiseases(data.cast());
        break;
      case 'drugs':
        await _cacheService.cacheDrugs(data.cast());
        break;
      case 'books':
        await _cacheService.cacheBooks(data.cast());
        break;
      case 'notes':
        await _cacheService.cacheNotes(data.cast());
        break;
      case 'instruments':
        await _cacheService.cacheInstruments(data.cast());
        break;
      case 'normal_ranges':
        await _cacheService.cacheNormalRanges(data.cast());
        break;
    }
  }

  // Generic method to merge updates by type
  Future<void> _mergeUpdatesForType(String dataType, List<dynamic> updates) async {
    switch (dataType) {
      case 'dictionary':
        await _cacheService.mergeDictionaryUpdates(updates.cast());
        break;
      case 'diseases':
        await _cacheService.mergeDiseaseUpdates(updates.cast());
        break;
      case 'drugs':
        await _cacheService.mergeDrugUpdates(updates.cast());
        break;
      case 'books':
        await _cacheService.mergeBookUpdates(updates.cast());
        break;
      case 'notes':
        await _cacheService.mergeNoteUpdates(updates.cast());
        break;
      case 'instruments':
        await _cacheService.mergeInstrumentUpdates(updates.cast());
        break;
      case 'normal_ranges':
        await _cacheService.mergeNormalRangeUpdates(updates.cast());
        break;
    }
  }

  // Save data to encrypted cache by type
  Future<void> _saveToEncryptedCache(String dataType, List<dynamic> data) async {
    try {
      final jsonList = data.map((item) => item.toJson() as Map<String, dynamic>).toList();
      switch (dataType) {
        case 'dictionary':
          await _encCache.saveTerminology(jsonList);
          break;
        case 'diseases':
          await _encCache.saveDiseases(jsonList);
          break;
        case 'drugs':
          await _encCache.saveDrugs(jsonList);
          break;
        case 'books':
          await _encCache.saveBooks(jsonList);
          break;
        case 'notes':
          await _encCache.saveNotes(jsonList);
          break;
        case 'instruments':
          await _encCache.saveInstruments(jsonList);
          break;
        case 'normal_ranges':
          await _encCache.saveNormalRanges(jsonList);
          break;
      }
    } catch (e) {
      developer.log('[SyncService] Error saving to encrypted cache ($dataType): $e');
    }
  }

  // Load data from encrypted cache by type
  Future<List<T>> _loadFromEncryptedCache<T>(String dataType) async {
    try {
      List<Map<String, dynamic>> jsonList;
      switch (dataType) {
        case 'dictionary':
          jsonList = await _encCache.loadTerminology();
          return jsonList.map((json) => Word.fromJson(json) as T).toList();
        case 'diseases':
          jsonList = await _encCache.loadDiseases();
          return jsonList.map((json) => Disease.fromJson(json) as T).toList();
        case 'drugs':
          jsonList = await _encCache.loadDrugs();
          return jsonList.map((json) => Drug.fromJson(json) as T).toList();
        case 'books':
          jsonList = await _encCache.loadBooks();
          return jsonList.map((json) => Book.fromJson(json) as T).toList();
        case 'notes':
          jsonList = await _encCache.loadNotes();
          return jsonList.map((json) => Note.fromJson(json) as T).toList();
        case 'instruments':
          jsonList = await _encCache.loadInstruments();
          return jsonList.map((json) => Instrument.fromJson(json) as T).toList();
        case 'normal_ranges':
          jsonList = await _encCache.loadNormalRanges();
          return jsonList.map((json) => NormalRange.fromJson(json) as T).toList();
        default:
          return [];
      }
    } catch (e) {
      developer.log('[SyncService] Error loading from encrypted cache ($dataType): $e');
      return [];
    }
  }

  Future<void> _storeSQLiteDataByType(String dataType, List<dynamic> data) async {
    final db = await _database.database;
    
    // Insert or replace new data
    for (final item in data) {
      await db.insert(dataType, _itemToSQLiteMap(dataType, item),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> _updateSQLiteFromCacheForType(String dataType) async {
    final data = _getCachedDataByType<dynamic>(dataType);
    await _storeSQLiteDataByType(dataType, data);
  }

  Map<String, dynamic> _itemToSQLiteMap(String dataType, dynamic item) {
    switch (dataType) {
      case 'dictionary':
        return {
          'id': item.id,
          'name': item.name,
          'kurdish': item.kurdish,
          'arabic': item.arabic,
          'description': item.description,
          'image_url': item.imageUrl,
        };
      case 'diseases':
        return {
          'id': item.id,
          'name': item.name,
          'cause': item.cause,
          'control': item.control,
          'kurdish': item.kurdish,
          'symptoms': item.symptoms,
          'category': item.category,
          'image_url': item.imageUrl,
        };
      case 'drugs':
        return {
          'id': item.id,
          'name': item.name,
          'description': item.description,
          'other_info': item.otherInfo,
          'side_effect': item.sideEffect,
          'usage': item.usage,
          'drug_class': item.drugClass,
          'kurdish': item.kurdish,
          'category': item.category,
          'image_url': item.imageUrl,
        };
      case 'books':
        return {
          'id': item.id,
          'title': item.title,
          'author': item.author,
          'description': item.description,
          'category': item.category,
          'image_url': item.imageUrl,
        };
      default:
        throw Exception('Unknown data type: $dataType');
    }
  }

  // Legacy methods for backward compatibility
  Future<void> _performFullSync() async {
    try {
      _syncController.add(true);
      
      // Fetch all data
      final dictionary = await _apiService.fetchAllDictionary();
      final diseases = await _apiService.fetchAllDiseases();
      final drugs = await _apiService.fetchAllDrugs();
      final books = await _apiService.fetchAllBooks();

      // Cache data
      await _cacheService.cacheDictionary(dictionary);
      await _cacheService.cacheDiseases(diseases);
      await _cacheService.cacheDrugs(drugs);
      await _cacheService.cacheBooks(books);

      // Store in SQLite for backward compatibility
      await _storeSQLiteData(dictionary, diseases, drugs, books);

      // Update sync timestamps
      final now = DateTime.now().toIso8601String();
      await _cacheService.setLastSyncTime('dictionary', now);
      await _cacheService.setLastSyncTime('diseases', now);
      await _cacheService.setLastSyncTime('drugs', now);
      await _cacheService.setLastSyncTime('books', now);

      _syncController.add(false);
    } catch (e) {
      developer.log('Full sync failed: $e');
      _syncController.add(false);
      rethrow;
    }
  }

  Future<void> _storeSQLiteData(List<dynamic> dictionary, List<dynamic> diseases, 
                               List<dynamic> drugs, List<dynamic> books) async {
    final db = await _database.database;
    
    // Insert dictionary
    for (final word in dictionary) {
      await db.insert('dictionary', {
        'id': word.id,
        'name': word.name,
        'kurdish': word.kurdish,
        'arabic': word.arabic,
        'description': word.description,
        'image_url': word.imageUrl,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // Insert diseases
    for (final disease in diseases) {
      await db.insert('diseases', {
        'id': disease.id,
        'name': disease.name,
        'cause': disease.cause,
        'control': disease.control,
        'kurdish': disease.kurdish,
        'symptoms': disease.symptoms,
        'category': disease.category,
        'image_url': disease.imageUrl,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // Insert drugs
    for (final drug in drugs) {
      await db.insert('drugs', {
        'id': drug.id,
        'name': drug.name,
        'description': drug.description,
        'other_info': drug.otherInfo,
        'side_effect': drug.sideEffect,
        'usage': drug.usage,
        'drug_class': drug.drugClass,
        'kurdish': drug.kurdish,
        'category': drug.category,
        'image_url': drug.imageUrl,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // Insert books
    for (final book in books) {
      await db.insert('books', {
        'id': book.id,
        'title': book.title,
        'author': book.author,
        'description': book.description,
        'category': book.category,
        'image_url': book.imageUrl,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  void _restartApp() {
    // This will restart the entire app
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigatorKey.currentContext != null) {
        Phoenix.rebirth(navigatorKey.currentContext!);
      }
    });
  }

  Future<void> forceFullSync() async {
    await _cacheService.clearAllCache();
    await _cacheService.setFirstInstall(true);
    await _performFullSync();
    await _cacheService.setFirstInstall(false);
    _restartApp();
  }

  // Legacy method for backward compatibility
  Future<void> syncAll() async {
    await forceFullSync();
  }

  // Get cached data methods
  List<dynamic> getCachedDictionary() => _cacheService.getCachedDictionary();
  List<dynamic> getCachedDiseases() => _cacheService.getCachedDiseases();
  List<dynamic> getCachedDrugs() => _cacheService.getCachedDrugs();
  List<dynamic> getCachedBooks() => _cacheService.getCachedBooks();
}

// Global navigator key for app restart
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
