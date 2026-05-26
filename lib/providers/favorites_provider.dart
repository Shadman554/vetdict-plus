import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/drug.dart';
import '../models/disease.dart';
import '../models/word.dart';

class FavoritesProvider with ChangeNotifier {
  List<dynamic> _favorites = [];
  static const String _favoritesKey = 'favorites_data';
  late SharedPreferences _prefs;

  // Constructor now loads favorites in the background
  FavoritesProvider() {
    // Initialize with empty list and load in background
    _loadFavoritesAsync();
  }

  // Load favorites asynchronously without blocking app startup
  void _loadFavoritesAsync() {
    SharedPreferences.getInstance().then((prefs) {
      _prefs = prefs;
      final String? favoritesString = _prefs.getString(_favoritesKey);
      if (favoritesString != null) {
        try {
          final List<dynamic> favoritesJson = json.decode(favoritesString);
          _favorites = favoritesJson.map((item) {
            final type = item['type'];
            final data = item['data'];
            if (type == 'drug') {
              return Drug.fromJson(data);
            } else if (type == 'disease') {
              return Disease.fromJson(data);
            } else {
              return Word.fromJson(data);
            }
          }).toList();
          notifyListeners();
        } catch (e) {
          // Handle parsing errors gracefully
        }
      }
    });
  }

  Future<void> _saveFavorites() async {
    final List<Map<String, dynamic>> favoritesJson = _favorites.map((item) {
      String type;
      if (item is Drug) {
        type = 'drug';
      } else if (item is Disease) {
        type = 'disease';
      } else {
        type = 'word';
      }
      return {
        'type': type,
        'data': item.toJson(),
      };
    }).toList();
    await _prefs.setString(_favoritesKey, json.encode(favoritesJson));
  }

  List<dynamic> get favorites => List.unmodifiable(_favorites);

  bool isFavorite(dynamic item) {
    return _favorites.any((fav) => fav.id == item.id);
  }

  void addFavorite(dynamic item) {
    if (!isFavorite(item)) {
      _favorites.add(item);
      _saveFavorites();
      notifyListeners();
    }
  }

  void removeFavorite(dynamic item) {
    _favorites.removeWhere((fav) => fav.id == item.id);
    _saveFavorites();
    notifyListeners();
  }

  List<Drug> getDrugFavorites() {
    return _favorites.whereType<Drug>().toList();
  }

  List<Disease> getDiseaseFavorites() {
    return _favorites.whereType<Disease>().toList();
  }

  List<Word> getWordFavorites() {
    return _favorites.whereType<Word>().toList();
  }
}