import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FontSizeProvider with ChangeNotifier {
  static const String _fontSizeKey = 'font_size';
  double _fontSize = 1.0; // Default scale factor

  FontSizeProvider() {
    _loadFontSize();
  }

  double get fontSize => _fontSize;

  Future<void> _loadFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    _fontSize = prefs.getDouble(_fontSizeKey) ?? 1.0;
    notifyListeners();
  }

  Future<void> setFontSize(double size) async {
    if (size >= 0.8 && size <= 1.4) {
      _fontSize = size;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_fontSizeKey, size);
      notifyListeners();
    }
  }
}
