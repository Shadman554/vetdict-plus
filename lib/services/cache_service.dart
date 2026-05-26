import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/word.dart';
import '../models/disease.dart';
import '../models/drug.dart';
import '../models/note.dart';
import '../models/book.dart';
import '../models/instrument.dart';
import '../models/normal_range.dart';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  static const String _dictionaryKey = 'dictionary_cache';
  static const String _diseasesKey = 'diseases_cache';
  static const String _drugsKey = 'drugs_cache';
  static const String _booksKey = 'books_cache';
  static const String _notesKey = 'notes_cache';
  static const String _instrumentsKey = 'instruments_cache';
  static const String _normalRangesKey = 'normal_ranges_cache';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Dictionary methods
  Future<void> cacheDictionary(List<Word> words) async {
    final List<Map<String, dynamic>> wordList = words.map((word) => word.toJson()).toList();
    await _prefs?.setString(_dictionaryKey, jsonEncode(wordList));
    await _setDataLoaded('dictionary', true);
  }

  Future<void> mergeDictionaryUpdates(List<Word> updates) async {
    final existing = getCachedDictionary();
    final Map<String, Word> wordMap = {for (final word in existing) word.id: word};
    
    for (final word in updates) {
      wordMap[word.id] = word;
    }
    
    await cacheDictionary(wordMap.values.toList());
  }

  List<Word> getCachedDictionary() {
    final String? data = _prefs?.getString(_dictionaryKey);
    if (data == null) return [];
    
    final List<dynamic> jsonList = jsonDecode(data);
    return jsonList.map((json) => Word.fromJson(json)).toList();
  }

  // Disease methods
  Future<void> cacheDiseases(List<Disease> diseases) async {
    final List<Map<String, dynamic>> diseaseList = diseases.map((disease) => disease.toJson()).toList();
    await _prefs?.setString(_diseasesKey, jsonEncode(diseaseList));
    await _setDataLoaded('diseases', true);
  }

  Future<void> mergeDiseaseUpdates(List<Disease> updates) async {
    final existing = getCachedDiseases();
    final Map<String, Disease> diseaseMap = {for (final disease in existing) disease.id: disease};
    
    for (final disease in updates) {
      diseaseMap[disease.id] = disease;
    }
    
    await cacheDiseases(diseaseMap.values.toList());
  }

  List<Disease> getCachedDiseases() {
    final String? data = _prefs?.getString(_diseasesKey);
    if (data == null) return [];
    
    final List<dynamic> jsonList = jsonDecode(data);
    return jsonList.map((json) => Disease.fromJson(json)).toList();
  }

  // Drug methods
  Future<void> cacheDrugs(List<Drug> drugs) async {
    final List<Map<String, dynamic>> drugList = drugs.map((drug) => drug.toJson()).toList();
    await _prefs?.setString(_drugsKey, jsonEncode(drugList));
    await _setDataLoaded('drugs', true);
  }

  Future<void> mergeDrugUpdates(List<Drug> updates) async {
    final existing = getCachedDrugs();
    final Map<String, Drug> drugMap = {for (final drug in existing) drug.id: drug};
    
    for (final drug in updates) {
      drugMap[drug.id] = drug;
    }
    
    await cacheDrugs(drugMap.values.toList());
  }

  List<Drug> getCachedDrugs() {
    final String? data = _prefs?.getString(_drugsKey);
    if (data == null) return [];
    
    final List<dynamic> jsonList = jsonDecode(data);
    return jsonList.map((json) => Drug.fromJson(json)).toList();
  }

  // Note methods
  Future<void> cacheNotes(List<Note> notes) async {
    final List<Map<String, dynamic>> noteList = notes.map((note) => note.toJson()).toList();
    await _prefs?.setString(_notesKey, jsonEncode(noteList));
    await _setDataLoaded('notes', true);
  }

  Future<void> mergeNoteUpdates(List<Note> updates) async {
    final existing = getCachedNotes();
    final Map<String, Note> noteMap = {for (final note in existing) note.name: note};
    
    for (final note in updates) {
      noteMap[note.name] = note;
    }
    
    await cacheNotes(noteMap.values.toList());
  }

  List<Note> getCachedNotes() {
    final String? data = _prefs?.getString(_notesKey);
    if (data == null) return [];
    
    final List<dynamic> jsonList = jsonDecode(data);
    return jsonList.map((json) => Note.fromJson(json)).toList();
  }

  // Book methods
  Future<void> cacheBooks(List<Book> books) async {
    final List<Map<String, dynamic>> bookList = books.map((book) => book.toJson()).toList();
    await _prefs?.setString(_booksKey, jsonEncode(bookList));
    await _setDataLoaded('books', true);
  }

  Future<void> mergeBookUpdates(List<Book> updates) async {
    final existing = getCachedBooks();
    final Map<String, Book> bookMap = {for (final book in existing) book.id: book};
    
    for (final book in updates) {
      bookMap[book.id] = book;
    }
    
    await cacheBooks(bookMap.values.toList());
  }

  List<Book> getCachedBooks() {
    final String? data = _prefs?.getString(_booksKey);
    if (data == null) return [];
    
    final List<dynamic> jsonList = jsonDecode(data);
    return jsonList.map((json) => Book.fromJson(json)).toList();
  }

  // Instrument methods
  Future<void> cacheInstruments(List<Instrument> instruments) async {
    final List<Map<String, dynamic>> instrumentList = instruments.map((instrument) => instrument.toJson()).toList();
    await _prefs?.setString(_instrumentsKey, jsonEncode(instrumentList));
    await _setDataLoaded('instruments', true);
  }

  Future<void> mergeInstrumentUpdates(List<Instrument> updates) async {
    final existing = getCachedInstruments();
    final Map<String, Instrument> instrumentMap = {for (final instrument in existing) instrument.id: instrument};
    
    for (final instrument in updates) {
      instrumentMap[instrument.id] = instrument;
    }
    await cacheInstruments(instrumentMap.values.toList());
  }

  List<Instrument> getCachedInstruments() {
    final String? data = _prefs?.getString(_instrumentsKey);
    if (data == null) return [];
    
    final List<dynamic> jsonList = jsonDecode(data);
    return jsonList.map((json) => Instrument.fromJson(json)).toList();
  }

  // Normal Range methods
  Future<void> cacheNormalRanges(List<NormalRange> ranges) async {
    final List<Map<String, dynamic>> rangeList = ranges.map((range) => range.toJson()).toList();
    await _prefs?.setString(_normalRangesKey, jsonEncode(rangeList));
    await _setDataLoaded('normal_ranges', true);
  }

  Future<void> mergeNormalRangeUpdates(List<NormalRange> updates) async {
    final existing = getCachedNormalRanges();
    final Map<String, NormalRange> rangeMap = {for (final range in existing) range.id: range};
    
    for (final range in updates) {
      rangeMap[range.id] = range;
    }
    await cacheNormalRanges(rangeMap.values.toList());
  }

  List<NormalRange> getCachedNormalRanges() {
    final String? data = _prefs?.getString(_normalRangesKey);
    if (data == null) return [];
    
    final List<dynamic> jsonList = jsonDecode(data);
    return jsonList.map((json) => NormalRange.fromJson(json)).toList();
  }

  // Data loading state methods
  Future<void> _setDataLoaded(String dataType, bool loaded) async {
    await _prefs?.setBool('${dataType}_loaded', loaded);
  }

  bool isDataLoaded(String dataType) {
    return _prefs?.getBool('${dataType}_loaded') ?? false;
  }

  bool hasCachedData(String dataType) {
    switch (dataType) {
      case 'dictionary':
        return getCachedDictionary().isNotEmpty;
      case 'diseases':
        return getCachedDiseases().isNotEmpty;
      case 'drugs':
        return getCachedDrugs().isNotEmpty;
      case 'books':
        return getCachedBooks().isNotEmpty;
      case 'notes':
        return getCachedNotes().isNotEmpty;
      case 'instruments':
        return getCachedInstruments().isNotEmpty;
      case 'normal_ranges':
        return getCachedNormalRanges().isNotEmpty;
      default:
        return false;
    }
  }

  // Metadata methods
  Future<void> setLastSyncTime(String dataType, String timestamp) async {
    await _prefs?.setString('last_sync_$dataType', timestamp);
  }

  String? getLastSyncTime(String dataType) {
    return _prefs?.getString('last_sync_$dataType');
  }

  Future<void> setFirstInstall(bool isFirst) async {
    await _prefs?.setBool('first_install', isFirst);
  }

  bool isFirstInstall() {
    return _prefs?.getBool('first_install') ?? true;
  }

  // Clear methods
  Future<void> clearAllCache() async {
    await _prefs?.remove(_dictionaryKey);
    await _prefs?.remove(_diseasesKey);
    await _prefs?.remove(_drugsKey);
    await _prefs?.remove(_booksKey);
    await _prefs?.remove(_notesKey);
    
    // Clear metadata
    await _prefs?.remove('dictionary_loaded');
    await _prefs?.remove('diseases_loaded');
    await _prefs?.remove('drugs_loaded');
    await _prefs?.remove('books_loaded');
    await _prefs?.remove('notes_loaded');
  }

  Future<void> clearCategoryCache(String dataType) async {
    switch (dataType) {
      case 'dictionary':
        await _prefs?.remove(_dictionaryKey);
        break;
      case 'diseases':
        await _prefs?.remove(_diseasesKey);
        break;
      case 'drugs':
        await _prefs?.remove(_drugsKey);
        break;
      case 'books':
        await _prefs?.remove(_booksKey);
        break;
      case 'notes':
        await _prefs?.remove(_notesKey);
        break;
    }
    await _setDataLoaded(dataType, false);
  }

  bool hasData() {
    return getCachedDictionary().isNotEmpty || 
           getCachedDiseases().isNotEmpty || 
           getCachedDrugs().isNotEmpty || 
           getCachedBooks().isNotEmpty;
  }
}