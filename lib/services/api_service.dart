import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;

import '../models/word.dart';
import '../models/disease.dart';
import '../models/drug.dart';
import '../models/book.dart';
import '../models/normal_range.dart';
import '../models/note.dart';
import '../models/instrument.dart';
import '../models/slide.dart';
import '../models/test.dart';
import '../models/notification.dart';
import '../models/ceo.dart';
import '../models/supporter.dart';
import 'secure_storage_service.dart';

class ApiService {
  ApiService();

  static const String _baseUrl = 'https://vetdict.space';

  // Secure storage instance
  final _secureStorage = SecureStorageService();

  // Rate limiting: Track last request time per endpoint and enforce minimum delay
  static const Duration _minRequestDelay = Duration(milliseconds: 500);
  static final Map<String, DateTime> _endpointLastCall = {};

  // Wait if necessary to respect rate limits
  Future<void> _respectRateLimit(String endpoint) async {
    final now = DateTime.now();
    final lastCall = _endpointLastCall[endpoint];
    
    if (lastCall != null) {
      final timeSinceLastCall = now.difference(lastCall);
      if (timeSinceLastCall < _minRequestDelay) {
        final waitTime = _minRequestDelay - timeSinceLastCall;
        await Future.delayed(waitTime);
      }
    }
    
    _endpointLastCall[endpoint] = DateTime.now();
  }

  // Load bearer token from secure storage and return common auth headers
  Future<Map<String, String>> _authHeaders({Map<String, String>? extra}) async {
    final token = await _secureStorage.getToken();
    final headers = <String, String>{
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (extra != null) ...extra,
    };
    return headers;
  }

  Future<List<Book>> fetchAllBooks() async {
    const int limit = 100;
    int skip = 0;
    List<Book> all = [];
    while (true) {
      final page = await _fetchBooksPage(skip: skip, limit: limit);
      if (page.isEmpty) break;
      all.addAll(page);
      if (page.length < limit) break;
      skip += limit;
    }
    return all;
  }

  Future<List<Book>> _fetchBooksPage({int skip = 0, int limit = 100}) async {
    final uri = Uri.parse('$_baseUrl/api/books/?skip=$skip&limit=$limit');
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load books – status ${response.statusCode}');
    }

    final decoded = json.decode(response.body);
    final List<dynamic> jsonData = decoded is List ? decoded : (decoded['items'] as List<dynamic>);
    return jsonData.map((e) => Book.fromJson(e as Map<String, dynamic>)).toList();
  }

  // Get total dictionary count from API (lightweight - fetches 1 item just to read total)
  Future<int> fetchDictionaryTotalCount() async {
    await _respectRateLimit('dictionary');
    final uri = Uri.parse('$_baseUrl/api/dictionary?skip=0&limit=1');
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to get dictionary count');
    }
    final decoded = json.decode(response.body);
    if (decoded is Map && decoded.containsKey('total')) {
      return decoded['total'] as int;
    }
    return -1;
  }

  // Fetch only a limited number of dictionary words (for pagination)
  Future<List<Word>> fetchDictionaryPage({int skip = 0, int limit = 200}) async {
    await _respectRateLimit('dictionary');
    
    final uri = Uri.parse('$_baseUrl/api/dictionary?skip=$skip&limit=$limit');
    final response = await http.get(uri);

    if (response.statusCode == 429) {
      developer.log('Rate limited on dictionary endpoint, waiting 3 seconds...');
      await Future.delayed(const Duration(seconds: 3));
      final retryResponse = await http.get(uri);
      if (retryResponse.statusCode != 200) {
        throw Exception('Failed to load dictionary – status ${retryResponse.statusCode}');
      }
      final decoded = json.decode(retryResponse.body);
      final List<dynamic> jsonData = decoded is List ? decoded : (decoded['items'] as List<dynamic>);
      return jsonData.map((e) => Word.fromJson(e as Map<String, dynamic>)).toList();
    }

    if (response.statusCode != 200) {
      throw Exception('Failed to load dictionary – status ${response.statusCode}');
    }

    final decoded = json.decode(response.body);
    final List<dynamic> jsonData = decoded is List ? decoded : (decoded['items'] as List<dynamic>);
    return jsonData.map((e) => Word.fromJson(e as Map<String, dynamic>)).toList();
  }

  // Fetch ALL dictionary words (WARNING: Use only for small datasets or background sync)
  Future<List<Word>> fetchAllDictionary() async {
    const int limit = 100;
    int skip = 0;
    List<Word> all = [];
    while (true) {
      final page = await _fetchDictionaryPage(skip: skip, limit: limit);
      if (page.isEmpty) break;
      all.addAll(page);
      if (page.length < limit) break;
      skip += limit;
    }
    return all;
  }

  Future<List<Word>> _fetchDictionaryPage({int skip = 0, int limit = 100}) async {
    // Respect rate limits before making request
    await _respectRateLimit('dictionary');
    
    final uri = Uri.parse('$_baseUrl/api/dictionary?skip=$skip&limit=$limit');
    final response = await http.get(uri);

    if (response.statusCode == 429) {
      // Rate limited - wait longer and retry once
      developer.log('Rate limited on dictionary endpoint, waiting 3 seconds...');
      await Future.delayed(const Duration(seconds: 3));
      final retryResponse = await http.get(uri);
      if (retryResponse.statusCode != 200) {
        throw Exception('Failed to load dictionary – status ${retryResponse.statusCode}');
      }
      final decoded = json.decode(retryResponse.body);
      final List<dynamic> jsonData = decoded is List ? decoded : (decoded['items'] as List<dynamic>);
      return jsonData.map((e) => Word.fromJson(e as Map<String, dynamic>)).toList();
    }

    if (response.statusCode != 200) {
      throw Exception('Failed to load dictionary – status ${response.statusCode}');
    }

    final decoded = json.decode(response.body);
    final List<dynamic> jsonData = decoded is List ? decoded : (decoded['items'] as List<dynamic>);
    return jsonData.map((e) => Word.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Disease>> fetchAllDiseases() async {
    final uri = Uri.parse('$_baseUrl/api/diseases');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to load diseases – status ${response.statusCode}');
    }

    final decoded = json.decode(response.body);
    final List<dynamic> jsonData = decoded is List ? decoded : (decoded['items'] as List<dynamic>);
    return jsonData.map((e) => Disease.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Drug>> fetchAllDrugs() async {
    final uri = Uri.parse('$_baseUrl/api/drugs');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to load drugs – status ${response.statusCode}');
    }

    final decoded = json.decode(response.body);
    final List<dynamic> jsonData = decoded is List ? decoded : (decoded['items'] as List<dynamic>);
    return jsonData.map((e) => Drug.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<NormalRange>> fetchAllNormalRanges() async {
    final uri = Uri.parse('$_baseUrl/api/normal-ranges/');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to load normal ranges – status ${response.statusCode}');
    }

    final decoded = json.decode(response.body);
    final List<dynamic> jsonData = decoded is List ? decoded : (decoded['items'] as List<dynamic>);
    return jsonData.map((e) => NormalRange.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Note>> fetchAllNotes() async {
    final uri = Uri.parse('$_baseUrl/api/notes/');
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load notes – status \${response.statusCode}');
    }

    final decoded = json.decode(response.body);
    final List<dynamic> jsonData = decoded is List ? decoded : (decoded['items'] as List<dynamic>);
    return jsonData.map((e) => Note.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Instrument>> fetchAllInstruments() async {
    final uri = Uri.parse('$_baseUrl/api/instruments/');
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load instruments – status ${response.statusCode}');
    }

    final decoded = json.decode(response.body);
    final List<dynamic> jsonData = decoded is List ? decoded : (decoded['items'] as List<dynamic>);
    return jsonData.map((e) => Instrument.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Slide>> fetchUrineSlides() async {
    final uri = Uri.parse('$_baseUrl/api/urine-slides/');
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load urine slides – status ${response.statusCode}');
    }

    final decoded = json.decode(response.body);
    final List<dynamic> jsonData = decoded is List ? decoded : (decoded['items'] as List<dynamic>);
    return jsonData.map((e) => Slide.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Slide>> fetchStoolSlides() async {
    final uri = Uri.parse('$_baseUrl/api/stool-slides/');
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load stool slides – status ${response.statusCode}');
    }

    final decoded = json.decode(response.body);
    final List<dynamic> jsonData = decoded is List ? decoded : (decoded['items'] as List<dynamic>);
    return jsonData.map((e) => Slide.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Slide>> fetchOtherSlides() async {
    final uri = Uri.parse('$_baseUrl/api/other-slides/');
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load other slides – status ${response.statusCode}');
    }

    final decoded = json.decode(response.body);
    final List<dynamic> jsonData = decoded is List ? decoded : (decoded['items'] as List<dynamic>);
    return jsonData.map((e) => Slide.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Slide> fetchSlideByName(String category, String slideName) async {
    final uri = Uri.parse('$_baseUrl/api/${category.toLowerCase()}-slides/$slideName');
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load slide – status ${response.statusCode}');
    }

    final decoded = json.decode(response.body);
    return Slide.fromJson(decoded as Map<String, dynamic>);
  }

  // Test methods
  Future<List<Test>> fetchHaematologyTests() async {
    final uri = Uri.parse('$_baseUrl/api/haematology-tests/');
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      // Debug logging to diagnose backend mismatch
      developer.log('[Tests] GET $uri -> ${response.statusCode}: ${response.body}');
      throw Exception('Failed to load haematology tests – status ${response.statusCode}');
    }

    final decoded = json.decode(response.body);
    List<dynamic> jsonData;
    if (decoded is List) {
      jsonData = decoded;
    } else if (decoded is Map && decoded['items'] is List) {
      jsonData = decoded['items'] as List<dynamic>;
    } else if (decoded is Map && decoded['results'] is List) {
      jsonData = decoded['results'] as List<dynamic>;
    } else if (decoded is Map && decoded['data'] is List) {
      jsonData = decoded['data'] as List<dynamic>;
    } else {
      developer.log('[Tests] Unexpected response shape for $uri: $decoded');
      jsonData = [];
    }
    return jsonData.map((e) => Test.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Test>> fetchSerologyTests() async {
    final uri = Uri.parse('$_baseUrl/api/serology-tests/');
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      developer.log('[Tests] GET $uri -> ${response.statusCode}: ${response.body}');
      throw Exception('Failed to load serology tests – status ${response.statusCode}');
    }

    final decoded = json.decode(response.body);
    List<dynamic> jsonData;
    if (decoded is List) {
      jsonData = decoded;
    } else if (decoded is Map && decoded['items'] is List) {
      jsonData = decoded['items'] as List<dynamic>;
    } else if (decoded is Map && decoded['results'] is List) {
      jsonData = decoded['results'] as List<dynamic>;
    } else if (decoded is Map && decoded['data'] is List) {
      jsonData = decoded['data'] as List<dynamic>;
    } else {
      developer.log('[Tests] Unexpected response shape for $uri: $decoded');
      jsonData = [];
    }
    return jsonData.map((e) => Test.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Test>> fetchBiochemistryTests() async {
    final uri = Uri.parse('$_baseUrl/api/biochemistry-tests/');
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      developer.log('[Tests] GET $uri -> ${response.statusCode}: ${response.body}');
      throw Exception('Failed to load biochemistry tests – status ${response.statusCode}');
    }

    final decoded = json.decode(response.body);
    List<dynamic> jsonData;
    if (decoded is List) {
      jsonData = decoded;
    } else if (decoded is Map && decoded['items'] is List) {
      jsonData = decoded['items'] as List<dynamic>;
    } else if (decoded is Map && decoded['results'] is List) {
      jsonData = decoded['results'] as List<dynamic>;
    } else if (decoded is Map && decoded['data'] is List) {
      jsonData = decoded['data'] as List<dynamic>;
    } else {
      developer.log('[Tests] Unexpected response shape for $uri: $decoded');
      jsonData = [];
    }
    return jsonData.map((e) => Test.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Test>> fetchBacteriologyTests() async {
    final uri = Uri.parse('$_baseUrl/api/bacteriology-tests/');
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      developer.log('[Tests] GET $uri -> ${response.statusCode}: ${response.body}');
      throw Exception('Failed to load bacteriology tests – status ${response.statusCode}');
    }

    final decoded = json.decode(response.body);
    List<dynamic> jsonData;
    if (decoded is List) {
      jsonData = decoded;
    } else if (decoded is Map && decoded['items'] is List) {
      jsonData = decoded['items'] as List<dynamic>;
    } else if (decoded is Map && decoded['results'] is List) {
      jsonData = decoded['results'] as List<dynamic>;
    } else if (decoded is Map && decoded['data'] is List) {
      jsonData = decoded['data'] as List<dynamic>;
    } else {
      developer.log('[Tests] Unexpected response shape for $uri: $decoded');
      jsonData = [];
    }
    return jsonData.map((e) => Test.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Test>> fetchOtherTests() async {
    final uri = Uri.parse('$_baseUrl/api/other-tests/');
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      developer.log('[Tests] GET $uri -> ${response.statusCode}: ${response.body}');
      throw Exception('Failed to load other tests – status ${response.statusCode}');
    }

    final decoded = json.decode(response.body);
    List<dynamic> jsonData;
    if (decoded is List) {
      jsonData = decoded;
    } else if (decoded is Map && decoded['items'] is List) {
      jsonData = decoded['items'] as List<dynamic>;
    } else if (decoded is Map && decoded['results'] is List) {
      jsonData = decoded['results'] as List<dynamic>;
    } else if (decoded is Map && decoded['data'] is List) {
      jsonData = decoded['data'] as List<dynamic>;
    } else {
      developer.log('[Tests] Unexpected response shape for $uri: $decoded');
      jsonData = [];
    }
    return jsonData.map((e) => Test.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Test> fetchTestByName(String category, String testName) async {
    final encoded = Uri.encodeComponent(testName);
    final uri = Uri.parse('$_baseUrl/api/${category.toLowerCase()}-tests/by-name/$encoded');
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      developer.log('[Tests] GET $uri -> ${response.statusCode}: ${response.body}');
      throw Exception('Failed to load test – status ${response.statusCode}');
    }

    final decoded = json.decode(response.body);
    return Test.fromJson(decoded as Map<String, dynamic>);
  }

  // Search dictionary by query string (searches name, kurdish, arabic, description)
  Future<List<Word>> searchDictionary(String query, {int limit = 50}) async {
    try {
      await _respectRateLimit('dictionary_search');
      
      final encoded = Uri.encodeComponent(query);
      final uri = Uri.parse('$_baseUrl/api/dictionary?search=$encoded&limit=$limit');
      final response = await http.get(uri);
      
      if (response.statusCode == 429) {
        developer.log('Rate limited on dictionary search, waiting 2 seconds...');
        await Future.delayed(const Duration(seconds: 2));
        final retryResponse = await http.get(uri);
        if (retryResponse.statusCode != 200) {
          return [];
        }
        final decoded = json.decode(retryResponse.body);
        final List<dynamic> jsonData = decoded is List ? decoded : (decoded['items'] as List<dynamic>);
        return jsonData.map((e) => Word.fromJson(e as Map<String, dynamic>)).toList();
      }
      
      if (response.statusCode != 200) {
        developer.log('[Dictionary] Search failed with status ${response.statusCode}');
        return [];
      }

      final decoded = json.decode(response.body);
      final List<dynamic> jsonData = decoded is List ? decoded : (decoded['items'] as List<dynamic>);
      return jsonData.map((e) => Word.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      developer.log('[Dictionary] Error searching for "$query": $e');
      return [];
    }
  }

  // Dictionary search method for hybrid search (exact match by name)
  Future<Word?> searchDictionaryInDatabase(String wordName) async {
    try {
      final encoded = Uri.encodeComponent(wordName);
      final uri = Uri.parse('$_baseUrl/api/dictionary/$encoded');
      final response = await http.get(uri);
      
      if (response.statusCode == 404) {
        // Word not found in database
        return null;
      }
      
      if (response.statusCode != 200) {
        developer.log('[Dictionary] GET $uri -> ${response.statusCode}: ${response.body}');
        throw Exception('Failed to search dictionary – status ${response.statusCode}');
      }

      final decoded = json.decode(response.body);
      return Word.fromJson(decoded as Map<String, dynamic>);
    } catch (e) {
      developer.log('[Dictionary] Error searching for word "$wordName": $e');
      return null;
    }
  }

  // Incremental sync methods
  Future<List<Word>> fetchDictionaryUpdates({String? since}) async {
    String url = '$_baseUrl/api/dictionary';
    if (since != null) {
      url += '?since=$since';
    }
    
    final uri = Uri.parse(url);
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to load dictionary updates – status ${response.statusCode}');
    }

    final decoded = json.decode(response.body);
    final List<dynamic> jsonData = decoded is List ? decoded : (decoded['items'] as List<dynamic>);
    return jsonData.map((e) => Word.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Disease>> fetchDiseaseUpdates({String? since}) async {
    String url = '$_baseUrl/api/diseases';
    if (since != null) {
      url += '?since=$since';
    }
    
    final uri = Uri.parse(url);
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to load disease updates – status ${response.statusCode}');
    }

    final decoded = json.decode(response.body);
    final List<dynamic> jsonData = decoded is List ? decoded : (decoded['items'] as List<dynamic>);
    return jsonData.map((e) => Disease.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Drug>> fetchDrugUpdates({String? since}) async {
    String url = '$_baseUrl/api/drugs';
    if (since != null) {
      url += '?since=$since';
    }
    
    final uri = Uri.parse(url);
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to load drug updates – status ${response.statusCode}');
    }

    final decoded = json.decode(response.body);
    final List<dynamic> jsonData = decoded is List ? decoded : (decoded['items'] as List<dynamic>);
    return jsonData.map((e) => Drug.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Book>> fetchBookUpdates({String? since}) async {
    String url = '$_baseUrl/api/books/';
    if (since != null) {
      url += '?since=$since';
    }
    
    final uri = Uri.parse(url);
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to load book updates – status ${response.statusCode}');
    }

    final decoded = json.decode(response.body);
    final List<dynamic> jsonData = decoded is List ? decoded : (decoded['items'] as List<dynamic>);
    return jsonData.map((e) => Book.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> checkForUpdates() async {
    final uri = Uri.parse('$_baseUrl/api/updates/check');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to check for updates – status ${response.statusCode}');
    }

    return json.decode(response.body) as Map<String, dynamic>;
  }

  // Notification methods
  Future<List<NotificationModel>> fetchRecentNotifications() async {
    try {
      final uri = Uri.parse('$_baseUrl/api/notifications/recent/latest');

      final response = await http.get(
        uri,
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 15));




      if (response.statusCode != 200) {
        throw Exception('Failed to load recent notifications – status ${response.statusCode}');
      }

      final decoded = json.decode(response.body);


      
      // Handle null or empty response
      if (decoded == null) {

        return [];
      }
      
      List<dynamic> jsonData;
      if (decoded is List) {
        jsonData = decoded;

      } else if (decoded is Map && decoded['items'] != null) {
        jsonData = decoded['items'] as List<dynamic>;

      } else if (decoded is Map && decoded['notifications'] != null) {
        jsonData = decoded['notifications'] as List<dynamic>;

      } else {


        return []; // Return empty list if no valid data
      }
      
      final notifications = jsonData.map((e) {

        return NotificationModel.fromJson(e as Map<String, dynamic>);
      }).toList();
      

      return notifications;
    } catch (e) {

      throw Exception('خەتا لە بارکردنی ئاگادارکردنەوەکان');
    }
  }

  Future<List<NotificationModel>> fetchAllNotifications() async {
    try {
      final uri = Uri.parse('$_baseUrl/api/notifications/');
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('Failed to load notifications – status ${response.statusCode}');
      }

      final decoded = json.decode(response.body);
      
      // Handle null or empty response
      if (decoded == null) {
        return [];
      }
      
      List<dynamic> jsonData;
      if (decoded is List) {
        jsonData = decoded;
      } else if (decoded is Map && decoded['items'] != null) {
        jsonData = decoded['items'] as List<dynamic>;
      } else {
        return []; // Return empty list if no valid data
      }
      
      return jsonData.map((e) => NotificationModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      developer.log('Error in fetchAllNotifications: $e');
      return []; // Return empty list on error
    }
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    final uri = Uri.parse('$_baseUrl/api/notifications/$notificationId/read');
    final response = await http.put(
      uri,
      headers: await _authHeaders(),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('نیشانکردن وەک خوێندراوە سەرکەوتوو نەبوو');
    }
  }

  Future<void> markAllNotificationsAsRead() async {
    final uri = Uri.parse('$_baseUrl/api/notifications/mark-all-read');
    final response = await http.put(
      uri,
      headers: await _authHeaders(),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('نیشانکردنی هەموو وەک خوێندراوە سەرکەوتوو نەبوو');
    }
  }

  // ─── About Page API Methods ────────────────────────────────────────────────

  Future<String?> fetchAboutText() async {
    try {
      final uri = Uri.parse('$_baseUrl/api/about/');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        return decoded['text'] as String?;
      }
      return null;
    } catch (e) {
      developer.log('Error fetching about text: $e');
      return null;
    }
  }

  Future<List<CEO>> fetchCEOs() async {
    try {
      final uri = Uri.parse('$_baseUrl/api/about/ceos');
      developer.log('Fetching CEOs from: $uri');
      
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      
      if (response.statusCode != 200) {
        developer.log('Failed to fetch CEOs - Status: ${response.statusCode}');
        throw Exception('Failed to load CEOs');
      }

      final decoded = json.decode(response.body);
      final List<dynamic> jsonData = decoded is List ? decoded : (decoded['items'] as List<dynamic>? ?? []);
      
      developer.log('Successfully fetched ${jsonData.length} CEOs');
      return jsonData.map((e) => CEO.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      developer.log('Error fetching CEOs: $e');
      rethrow;
    }
  }

  Future<List<Supporter>> fetchSupporters() async {
    try {
      final uri = Uri.parse('$_baseUrl/api/about/supporters');
      developer.log('Fetching Supporters from: $uri');
      
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      
      if (response.statusCode != 200) {
        developer.log('Failed to fetch Supporters - Status: ${response.statusCode}');
        throw Exception('Failed to load Supporters');
      }

      final decoded = json.decode(response.body);
      final List<dynamic> jsonData = decoded is List ? decoded : (decoded['items'] as List<dynamic>? ?? []);
      
      developer.log('Successfully fetched ${jsonData.length} Supporters');
      return jsonData.map((e) => Supporter.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      developer.log('Error fetching Supporters: $e');
      rethrow;
    }
  }
}
