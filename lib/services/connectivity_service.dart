import 'dart:io';
import 'dart:developer' as developer;

/// Simple connectivity check service.
/// Checks if the device can reach the internet by attempting a DNS lookup.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  /// Check if the device has internet connectivity
  /// Returns true if online, false if offline
  static Future<bool> isOnline() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      developer.log('[Connectivity] Offline: $e');
      return false;
    }
  }
}
