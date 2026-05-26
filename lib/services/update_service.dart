import 'dart:developer' as developer;
import 'package:upgrader/upgrader.dart';

/// Thin wrapper around [Upgrader] that provides store-based update checking.
///
/// The shared [upgrader] instance is passed to [VetDictUpgradeAlert], which
/// wraps the home page scaffold and automatically shows the update dialog
/// when a new version is available on the Play Store or App Store.
class UpdateService {
  UpdateService._();

  /// Shared Upgrader instance used throughout the app.
  static final Upgrader upgrader = Upgrader(
    debugLogging: false,
    // Show the dialog again after 1 day if the user tapped "Later"
    durationUntilAlertAgain: const Duration(days: 1),
    // Force Kurdish (ku) strings — upgrader has built-in Kurdish support
    messages: UpgraderMessages(code: 'ku'),
  );

  /// Call once during app startup to pre-warm the store version lookup.
  /// This runs in the background and does NOT delay the app launch.
  static Future<void> initialize() async {
    try {
      await upgrader.initialize();
      developer.log(
        '[UpdateService] Ready. Update available: ${upgrader.isUpdateAvailable()}',
      );
    } catch (e) {
      developer.log('[UpdateService] Error initializing: $e');
      // Never crash the app because of an update check failure
    }
  }
}
