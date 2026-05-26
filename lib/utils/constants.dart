import '../config/app_config.dart';

class AppConstants {
  static const String iosAppId = 'id6680200091'; 
  
  static const String androidAppId = 'com.shaduman.vetdictplus';

  static String get androidStoreUrl => AppConfig.androidStoreUrl;
  static String get iosStoreUrl => AppConfig.iosStoreUrl;
  
  // Privacy Policy URL
  static String get privacyPolicyUrl => AppConfig.privacyPolicyUrl;
  static String get contactEmail => AppConfig.contactEmail;
}
