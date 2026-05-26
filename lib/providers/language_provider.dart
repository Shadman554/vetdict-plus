import 'package:flutter/material.dart';

class LanguageProvider extends ChangeNotifier {
  // Fixed Kurdish locale for RTL support
  final Locale _currentLocale = const Locale('ku');

  Locale get currentLocale => _currentLocale;
  
  // Get text direction - always RTL for Kurdish
  TextDirection get textDirection => TextDirection.rtl;
  
  // Check if current language is RTL - always true for Kurdish
  bool get isRTL => true;
  
  // Simple constructor - no translation loading needed
  LanguageProvider();
}
