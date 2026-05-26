import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted cache service for secure offline data storage.
/// Uses platform-specific secure storage (Android Keystore, iOS Keychain)
/// so data cannot be read even on rooted/jailbroken devices.
class EncryptedCacheService {
  static final EncryptedCacheService _instance = EncryptedCacheService._internal();
  factory EncryptedCacheService() => _instance;
  EncryptedCacheService._internal();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // Cache keys for each data type
  static const String _testsPrefix = 'enc_tests_';
  static const String _slidesPrefix = 'enc_slides_';
  static const String _notesKey = 'enc_notes';
  static const String _terminologyKey = 'enc_terminology';
  static const String _normalRangesKey = 'enc_normal_ranges';
  static const String _diseasesKey = 'enc_diseases';
  static const String _drugsKey = 'enc_drugs';
  static const String _booksKey = 'enc_books';
  static const String _instrumentsKey = 'enc_instruments';
  static const String _aboutCeosKey = 'enc_about_ceos';
  static const String _aboutSupportersKey = 'enc_about_supporters';

  // Timestamp keys to track freshness
  static const String _timestampSuffix = '_ts';

  // ─── Generic save / load ───────────────────────────────────────────

  /// Save a list of JSON-serializable objects encrypted
  Future<void> saveList(String key, List<Map<String, dynamic>> data) async {
    try {
      final jsonStr = jsonEncode(data);
      await _storage.write(key: key, value: jsonStr);
      await _storage.write(
        key: '$key$_timestampSuffix',
        value: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      developer.log('[EncryptedCache] Error saving $key: $e');
    }
  }

  /// Load a list of JSON maps from encrypted storage
  Future<List<Map<String, dynamic>>> loadList(String key) async {
    try {
      final jsonStr = await _storage.read(key: key);
      if (jsonStr == null || jsonStr.isEmpty) return [];

      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      developer.log('[EncryptedCache] Error loading $key: $e');
      return [];
    }
  }

  /// Check if cached data exists for a key
  Future<bool> hasData(String key) async {
    try {
      final data = await _storage.read(key: key);
      return data != null && data.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get the timestamp of when data was last cached
  Future<DateTime?> getLastCacheTime(String key) async {
    try {
      final ts = await _storage.read(key: '$key$_timestampSuffix');
      if (ts == null) return null;
      return DateTime.parse(ts);
    } catch (e) {
      return null;
    }
  }

  /// Clear cached data for a specific key
  Future<void> clearKey(String key) async {
    try {
      await _storage.delete(key: key);
      await _storage.delete(key: '$key$_timestampSuffix');
    } catch (e) {
      developer.log('[EncryptedCache] Error clearing $key: $e');
    }
  }

  // ─── Tests (per category) ─────────────────────────────────────────

  String testsKey(String category) => '$_testsPrefix$category';

  Future<void> saveTests(String category, List<Map<String, dynamic>> data) async {
    await saveList(testsKey(category), data);
  }

  Future<List<Map<String, dynamic>>> loadTests(String category) async {
    return await loadList(testsKey(category));
  }

  // ─── Slides (per category) ────────────────────────────────────────

  String slidesKey(String category) => '$_slidesPrefix$category';

  Future<void> saveSlides(String category, List<Map<String, dynamic>> data) async {
    await saveList(slidesKey(category), data);
  }

  Future<List<Map<String, dynamic>>> loadSlides(String category) async {
    return await loadList(slidesKey(category));
  }

  // ─── Notes ────────────────────────────────────────────────────────

  Future<void> saveNotes(List<Map<String, dynamic>> data) async {
    await saveList(_notesKey, data);
  }

  Future<List<Map<String, dynamic>>> loadNotes() async {
    return await loadList(_notesKey);
  }

  // ─── Terminology ──────────────────────────────────────────────────

  Future<void> saveTerminology(List<Map<String, dynamic>> data) async {
    await saveList(_terminologyKey, data);
  }

  Future<List<Map<String, dynamic>>> loadTerminology() async {
    return await loadList(_terminologyKey);
  }

  // ─── Terminology Chunked Storage (for large datasets ~26k+) ──────

  static const String _termChunkPrefix = 'enc_term_chunk_';
  static const String _termChunkCountKey = 'enc_term_chunk_count';
  static const String _termSyncProgressKey = 'enc_term_sync_progress';
  static const int termChunkSize = 1000;

  /// Save a single chunk of terminology data by chunk index
  Future<void> saveTerminologyChunk(int chunkIndex, List<Map<String, dynamic>> data) async {
    try {
      final jsonStr = jsonEncode(data);
      await _storage.write(key: '$_termChunkPrefix$chunkIndex', value: jsonStr);
      if (kDebugMode) {
        developer.log('[EncCache] Saved terminology chunk $chunkIndex (${data.length} items)');
      }
    } catch (e) {
      developer.log('[EncCache] Error saving terminology chunk $chunkIndex: $e');
    }
  }

  /// Save the total number of chunks
  Future<void> saveTerminologyChunkCount(int count) async {
    await _storage.write(key: _termChunkCountKey, value: count.toString());
  }

  /// Get the total number of saved chunks
  Future<int> getTerminologyChunkCount() async {
    final val = await _storage.read(key: _termChunkCountKey);
    return val != null ? int.tryParse(val) ?? 0 : 0;
  }

  /// Save background sync progress (how many terms downloaded so far)
  Future<void> saveTermSyncProgress(int totalDownloaded) async {
    await _storage.write(key: _termSyncProgressKey, value: totalDownloaded.toString());
  }

  /// Get background sync progress
  Future<int> getTermSyncProgress() async {
    final val = await _storage.read(key: _termSyncProgressKey);
    return val != null ? int.tryParse(val) ?? 0 : 0;
  }

  /// Load ALL terminology from chunked storage
  Future<List<Map<String, dynamic>>> loadAllTerminologyChunks() async {
    try {
      final chunkCount = await getTerminologyChunkCount();
      if (chunkCount == 0) {
        // Fall back to legacy single-key storage
        return await loadTerminology();
      }

      final List<Map<String, dynamic>> allData = [];
      for (int i = 0; i < chunkCount; i++) {
        final jsonStr = await _storage.read(key: '$_termChunkPrefix$i');
        if (jsonStr != null && jsonStr.isNotEmpty) {
          final List<dynamic> decoded = jsonDecode(jsonStr);
          allData.addAll(decoded.cast<Map<String, dynamic>>());
        }
      }

      if (kDebugMode) {
        developer.log('[EncCache] Loaded $chunkCount chunks = ${allData.length} total terms');
      }
      return allData;
    } catch (e) {
      developer.log('[EncCache] Error loading terminology chunks: $e');
      // Fall back to legacy single-key storage
      return await loadTerminology();
    }
  }

  // ─── Terminology Total Count (for incremental sync) ────────────────

  static const String _termTotalCountKey = 'enc_term_total_count';

  /// Save the total number of terms that were synced
  Future<void> saveTermTotalCount(int count) async {
    await _storage.write(key: _termTotalCountKey, value: count.toString());
  }

  /// Get the total number of terms that were synced
  Future<int> getTermTotalCount() async {
    final val = await _storage.read(key: _termTotalCountKey);
    return val != null ? int.tryParse(val) ?? 0 : 0;
  }

  /// Replace a specific chunk with updated data
  Future<void> replaceTerminologyChunk(int chunkIndex, List<Map<String, dynamic>> data) async {
    await saveTerminologyChunk(chunkIndex, data);
  }

  /// Load a single chunk by index
  Future<List<Map<String, dynamic>>> loadTerminologyChunk(int chunkIndex) async {
    try {
      final jsonStr = await _storage.read(key: '$_termChunkPrefix$chunkIndex');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        return decoded.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      developer.log('[EncCache] Error loading terminology chunk $chunkIndex: $e');
    }
    return [];
  }

  /// Clear all terminology chunks
  Future<void> clearTerminologyChunks() async {
    try {
      final chunkCount = await getTerminologyChunkCount();
      for (int i = 0; i < chunkCount; i++) {
        await _storage.delete(key: '$_termChunkPrefix$i');
      }
      await _storage.delete(key: _termChunkCountKey);
      await _storage.delete(key: _termSyncProgressKey);
      await _storage.delete(key: _termTotalCountKey);
    } catch (e) {
      developer.log('[EncCache] Error clearing terminology chunks: $e');
    }
  }

  // ─── Normal Ranges ────────────────────────────────────────────────

  Future<void> saveNormalRanges(List<Map<String, dynamic>> data) async {
    await saveList(_normalRangesKey, data);
  }

  Future<List<Map<String, dynamic>>> loadNormalRanges() async {
    return await loadList(_normalRangesKey);
  }

  // ─── Diseases ─────────────────────────────────────────────────────

  Future<void> saveDiseases(List<Map<String, dynamic>> data) async {
    await saveList(_diseasesKey, data);
  }

  Future<List<Map<String, dynamic>>> loadDiseases() async {
    return await loadList(_diseasesKey);
  }

  // ─── Drugs ────────────────────────────────────────────────────────

  Future<void> saveDrugs(List<Map<String, dynamic>> data) async {
    await saveList(_drugsKey, data);
  }

  Future<List<Map<String, dynamic>>> loadDrugs() async {
    return await loadList(_drugsKey);
  }

  // ─── Books ────────────────────────────────────────────────────────

  Future<void> saveBooks(List<Map<String, dynamic>> data) async {
    await saveList(_booksKey, data);
  }

  Future<List<Map<String, dynamic>>> loadBooks() async {
    return await loadList(_booksKey);
  }

  // ─── Instruments ──────────────────────────────────────────────────

  Future<void> saveInstruments(List<Map<String, dynamic>> data) async {
    await saveList(_instrumentsKey, data);
  }

  Future<List<Map<String, dynamic>>> loadInstruments() async {
    return await loadList(_instrumentsKey);
  }

  // ─── About (CEOs & Supporters) ────────────────────────────────────

  Future<void> saveCeos(List<Map<String, dynamic>> data) async {
    await saveList(_aboutCeosKey, data);
  }

  Future<List<Map<String, dynamic>>> loadCeos() async {
    return await loadList(_aboutCeosKey);
  }

  Future<void> saveSupporters(List<Map<String, dynamic>> data) async {
    await saveList(_aboutSupportersKey, data);
  }

  Future<List<Map<String, dynamic>>> loadSupporters() async {
    return await loadList(_aboutSupportersKey);
  }

  // ─── Clear all encrypted cache ────────────────────────────────────

  Future<void> clearAll() async {
    try {
      // We only delete our cache keys, not auth tokens
      final allKeys = [
        _notesKey, _terminologyKey, _normalRangesKey,
        _diseasesKey, _drugsKey, _booksKey, _instrumentsKey,
        _aboutCeosKey, _aboutSupportersKey,
      ];

      for (final key in allKeys) {
        await _storage.delete(key: key);
        await _storage.delete(key: '$key$_timestampSuffix');
      }

      // Clear category-based keys (tests and slides)
      final testCategories = ['haematology', 'serology', 'biochemistry', 'bacteriology', 'other'];
      for (final cat in testCategories) {
        final tk = testsKey(cat);
        await _storage.delete(key: tk);
        await _storage.delete(key: '$tk$_timestampSuffix');
      }

      final slideCategories = ['urine', 'stool', 'other'];
      for (final cat in slideCategories) {
        final sk = slidesKey(cat);
        await _storage.delete(key: sk);
        await _storage.delete(key: '$sk$_timestampSuffix');
      }
    } catch (e) {
      developer.log('[EncryptedCache] Error clearing all: $e');
    }
  }
}
