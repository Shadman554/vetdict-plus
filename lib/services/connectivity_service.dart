import 'dart:developer' as developer;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

/// Simple connectivity check service.
/// On web, uses an HTTP request; on native, uses dart:io InternetAddress.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  /// Check if the device has internet connectivity.
  /// Returns true if online, false if offline.
  static Future<bool> isOnline() async {
    if (kIsWeb) {
      // On web, cross-origin pings (e.g. google.com) are blocked by CORS and
      // always fail, giving a false "offline" result on every page.
      // Instead we optimistically return true and let the real API calls
      // report connectivity errors if the network is actually down.
      return true;
    } else {
      return _nativeIsOnline();
    }
  }

  static Future<bool> _nativeIsOnline() async {
    try {
      // Use conditional import pattern via dynamic to avoid dart:io on web
      // This method is only called on non-web platforms
      final result = await _lookupAddress();
      return result;
    } catch (e) {
      developer.log('[Connectivity] Offline: $e');
      return false;
    }
  }

  static Future<bool> _lookupAddress() async {
    // ignore: undefined_prefixed_name
    final addresses = await _InternetAddressLookup.lookup('google.com');
    return addresses;
  }
}

class _InternetAddressLookup {
  static Future<bool> lookup(String host) async {
    try {
      // dart:io is available on non-web platforms
      // We use http instead to avoid dart:io entirely
      final response = await http
          .get(Uri.parse('https://$host'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }
}
