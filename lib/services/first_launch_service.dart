import 'package:shared_preferences/shared_preferences.dart';

class FirstLaunchService {
  static const String _keyHasSeenIntroduction = 'has_seen_introduction';

  /// Check if the introduction page has been seen
  static Future<bool> hasSeenIntroduction() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHasSeenIntroduction) ?? false;
  }

  /// Mark the introduction page as seen
  static Future<void> markIntroductionAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasSeenIntroduction, true);
  }

  /// Reset the introduction seen status (for testing/debugging)
  static Future<void> resetIntroductionSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHasSeenIntroduction);
  }
}
