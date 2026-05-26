import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/history_item.dart';
import '../models/drug.dart';
import '../models/disease.dart';
import '../models/word.dart';

class HistoryProvider with ChangeNotifier {
  List<HistoryItem> _historyItems = [];
  static const String _historyKey = 'history_items';
  SharedPreferences? _prefs;
  static const int _maxHistoryItems = 50;

  // Constructor now loads history in the background
  HistoryProvider() {
    // Initialize with empty list and load in background
    _loadHistoryAsync();
  }

  // Load history asynchronously without blocking app startup
  void _loadHistoryAsync() {
    SharedPreferences.getInstance().then((prefs) {
      _prefs = prefs;
      final String? historyString = _prefs?.getString(_historyKey);
      if (historyString != null) {
        try {
          final List<dynamic> historyJson = json.decode(historyString);
          // Limit the number of items to parse during startup for better performance
          final itemsToLoad = historyJson.length > 10 ? historyJson.sublist(0, 10) : historyJson;
          
          _historyItems = itemsToLoad.map((item) {
            dynamic data;
            if (item['data'] != null) {
              // Parse the complete object based on type
              switch (item['type']) {
                case 'drug':
                  data = Drug.fromJson(item['data']);
                  break;
                case 'disease':
                  data = Disease.fromJson(item['data']);
                  break;
                case 'terminology':
                  data = Word.fromJson(item['data']);
                  break;
              }
            }
            
            return HistoryItem(
              title: item['title'],
              type: item['type'],
              timestamp: DateTime.parse(item['timestamp']),
              description: item['description'],
              data: data,
            );
          }).toList();
          
          notifyListeners();
          
          // If there are more items, load them after a delay
          if (historyJson.length > 10) {
            Future.delayed(const Duration(milliseconds: 1000), () {
              final remainingItems = historyJson.sublist(10).map((item) {
                dynamic data;
                if (item['data'] != null) {
                  // Parse the complete object based on type
                  switch (item['type']) {
                    case 'drug':
                      data = Drug.fromJson(item['data']);
                      break;
                    case 'disease':
                      data = Disease.fromJson(item['data']);
                      break;
                    case 'terminology':
                      data = Word.fromJson(item['data']);
                      break;
                  }
                }
                
                return HistoryItem(
                  title: item['title'],
                  type: item['type'],
                  timestamp: DateTime.parse(item['timestamp']),
                  description: item['description'],
                  data: data,
                );
              }).toList();
              
              _historyItems.addAll(remainingItems);
              notifyListeners();
            });
          }
        } catch (e) {
          // Handle parsing errors gracefully
        }
      }
    });
  }

  Future<void> _saveHistory() async {
    _prefs ??= await SharedPreferences.getInstance();
    final String historyString = json.encode(
      _historyItems.map((item) => item.toJson()).toList(),
    );
    await _prefs?.setString(_historyKey, historyString);
  }

  List<HistoryItem> get historyItems => List.unmodifiable(_historyItems);

  void addToHistory(String title, String type, String description, {dynamic data}) {
    // Remove existing item if it exists
    _historyItems.removeWhere((item) => 
      item.title == title && item.type == type
    );

    // Add new item at the beginning
    _historyItems.insert(0, HistoryItem(
      title: title,
      type: type,
      timestamp: DateTime.now(),
      description: description,
      data: data,
    ));

    // Keep only the most recent items
    if (_historyItems.length > _maxHistoryItems) {
      _historyItems = _historyItems.sublist(0, _maxHistoryItems);
    }

    _saveHistory();
    notifyListeners();
  }

  void addDiseaseToHistory(String title, String description) {
    addToHistory(title, 'disease', description);
  }

  void addTerminologyToHistory(String title, String description) {
    addToHistory(title, 'terminology', description);
  }

  void clearHistory() {
    _historyItems.clear();
    _saveHistory();
    notifyListeners();
  }

  void removeFromHistory(String title, String type) {
    _historyItems.removeWhere((item) => 
      item.title == title && item.type == type
    );
    _saveHistory();
    notifyListeners();
  }

  List<HistoryItem> getFilteredHistory(String type) {
    return _historyItems.where((item) => item.type == type).toList();
  }
}
