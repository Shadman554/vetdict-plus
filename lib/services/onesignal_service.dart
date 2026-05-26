import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../config/app_config.dart';
import '../models/notification.dart';

class OneSignalService {
  static String get _appId => AppConfig.oneSignalAppId;
  // App-level callbacks (set from main.dart) to react to notification events
  static VoidCallback? onForegroundNotification;
  static VoidCallback? onNotificationOpened;
  static void Function(NotificationModel notification)? onNotificationModel;

  static Future<void> initialize() async {
    if (kIsWeb) return; // OneSignal has no web implementation
    try {
      // Initialize OneSignal with your App ID (no debug logging)
      OneSignal.initialize(_appId);

      // DO NOT auto-request permission here - violates Play Store policy
      // Permission must be requested in context with user understanding
      // Use requestNotificationPermission() method when user opts in

      // Configure notification settings
      _configureNotificationSettings();

      // Set up notification handlers
      _setupNotificationHandlers();

      // Enable vibration and configure defaults
      await enableVibration();
      await configureNotificationDefaults();
      // Debug-only: log current subscription state
      await _debugLogPushSubscription('init');
      // get current player id for debugging
      if (kDebugMode) {
        final playerId = await getPlayerId();
        print('OneSignal Player ID: $playerId');
      }
    } catch (e) {
      print('OneSignal initialization failed: $e');
      // Silent error handling for production
    }
  }

  /// Request notification permission with user context
  /// Call this ONLY after showing rationale dialog explaining why notifications are needed
  /// Returns true if permission granted, false otherwise
  static Future<bool> requestNotificationPermission() async {
    if (kIsWeb) return false;
    try {
      final granted = await OneSignal.Notifications.requestPermission(true);
      await _debugLogPushSubscription('permission granted=$granted');
      return granted;
    } catch (e) {
      return false;
    }
  }

  /// Check if notification permission is already granted
  static Future<bool> hasNotificationPermission() async {
    if (kIsWeb) return false;
    try {
      return OneSignal.Notifications.permission;
    } catch (e) {
      return false;
    }
  }

  static Future<void> _debugLogPushSubscription(String reason) async {
    if (kIsWeb) return;
    final delays = <int>[0, 2, 5];
    for (final seconds in delays) {
      if (seconds > 0) {
        await Future.delayed(Duration(seconds: seconds));
      }
      final permission = OneSignal.Notifications.permission;
      final push = OneSignal.User.pushSubscription;
      final onesignalId = await OneSignal.User.getOnesignalId();
      debugPrint(
        'OneSignal push subscription ($reason, +${seconds}s): '
        'permission=$permission onesignalId=$onesignalId '
        'id=${push.id} token=${push.token} optedIn=${push.optedIn}',
      );
    }
  }

  // Local helper to infer a type from title/body (mirrors model logic without private access)
  static String _inferTypeFromContent(String title, String body) {
    final content = '$title $body'.toLowerCase();
    if (content.contains('drug') ||
        content.contains('medicine') ||
        content.contains('دەرمان') ||
        content.contains('دەوا')) {
      return 'drug';
    } else if (content.contains('disease') ||
        content.contains('illness') ||
        content.contains('نەخۆشی') ||
        content.contains('دەرد')) {
      return 'diseases';
    } else if (content.contains('book') ||
        content.contains('کتێب') ||
        content.contains('پەرتووک')) {
      return 'books';
    } else if (content.contains('terminology') ||
        content.contains('term') ||
        content.contains('زاراوە') ||
        content.contains('تێرم')) {
      return 'terminology';
    } else if (content.contains('slide') ||
        content.contains('presentation') ||
        content.contains('سلاید') ||
        content.contains('پێشکەش')) {
      return 'slides';
    } else if (content.contains('test') ||
        content.contains('exam') ||
        content.contains('تاقیکردنەوە') ||
        content.contains('پشکنین')) {
      return 'tests';
    } else if (content.contains('note') ||
        content.contains('تێبینی') ||
        content.contains('نۆت')) {
      return 'notes';
    } else if (content.contains('instrument') ||
        content.contains('tool') ||
        content.contains('ئامێر') ||
        content.contains('کەرەستە')) {
      return 'instruments';
    } else if (content.contains('normal range') ||
        content.contains('reference') ||
        content.contains('نۆرماڵ رێنج') ||
        content.contains('ئاسایی')) {
      return 'normal ranges';
    } else {
      return 'general';
    }
  }

  static void _configureNotificationSettings() {
    try {
      // Enable sound for notifications
      OneSignal.Notifications.addPermissionObserver((state) {
        // Silent permission observer
      });
    } catch (e) {
      // Silent in production
    }
  }

  static void _setupNotificationHandlers() {
    // Handle notification opened
    OneSignal.Notifications.addClickListener((OSNotificationClickEvent event) {
      _handleNotificationOpened(event);
      // Notify app to refresh notifications
      try {
        onNotificationOpened?.call();
      } catch (_) {}
      // Also emit a model for immediate local insert
      try {
        final model = _toModel(event.notification);
        if (model != null) {
          onNotificationModel?.call(model);
        }
      } catch (_) {}
    });

    // Configure notification display settings for heads-up notifications
    OneSignal.Notifications.addForegroundWillDisplayListener(
        (OSNotificationWillDisplayEvent event) {
      // Force display the notification even when app is in foreground
      // This ensures heads-up display
      event.notification.display();

      // Notify app to refresh notifications and badge
      try {
        onForegroundNotification?.call();
      } catch (_) {}

      // Emit a model for immediate local insert
      try {
        final model = _toModel(event.notification);
        if (model != null) {
          onNotificationModel?.call(model);
        }
      } catch (_) {}
    });
  }

  // Convert OneSignal notification to our NotificationModel
  static NotificationModel? _toModel(OSNotification notification) {
    try {
      final additional = notification.additionalData ?? {};
      // Prefer backend id if provided, else generate a local unique id
      final id = additional['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString();
      final title = notification.title ?? '';
      final body = notification.body ?? '';
      final type =
          additional['type']?.toString() ?? _inferTypeFromContent(title, body);
      final createdStr = additional['timestamp']?.toString();
      final createdAt = createdStr != null
          ? DateTime.tryParse(createdStr) ?? DateTime.now()
          : DateTime.now();

      return NotificationModel(
        id: id,
        title: title,
        content: body,
        type: type,
        isRead: false,
        createdAt: createdAt,
      );
    } catch (e) {
      // Silent in production
      return null;
    }
  }

  static void _handleNotificationOpened(OSNotificationClickEvent event) {
    // Handle notification tap - navigate to specific page based on notification data
    final additionalData = event.notification.additionalData;

    if (additionalData != null) {
      // Example: Navigate to specific page based on notification data
      // Silent in production

      // You can add navigation logic here based on your app's needs
      // Example:
      // if (pageType == 'drug' && itemId != null) {
      //   // Navigate to drug details page
      // } else if (pageType == 'disease' && itemId != null) {
      //   // Navigate to disease details page
      // }
    }
  }

  // Get the player ID (user's unique identifier)
  static Future<String?> getPlayerId() async {
    if (kIsWeb) return null;
    try {
      final user = OneSignal.User;
      return user.pushSubscription.id;
    } catch (e) {
      return null;
    }
  }

  // Set user tags for targeting
  static Future<void> setUserTags(Map<String, String> tags) async {
    if (kIsWeb) return;
    try {
      OneSignal.User.addTags(tags);
    } catch (e) {
      // Failed to set user tags
    }
  }

  // Set external user ID (for linking with your backend)
  static Future<void> setExternalUserId(String userId) async {
    if (kIsWeb) return;
    try {
      OneSignal.User.addAlias("external_id", userId);
    } catch (e) {
      // Failed to set external user id
    }
  }

  // Remove external user ID
  static Future<void> removeExternalUserId() async {
    if (kIsWeb) return;
    try {
      OneSignal.User.removeAlias("external_id");
    } catch (e) {
      // Failed to remove external user id
    }
  }

  // Send a tag when user performs specific actions
  static Future<void> trackUserAction(String action, String value) async {
    await setUserTags({action: value});
  }

  // Enable vibration for notifications
  static Future<void> enableVibration() async {
    try {
      await setUserTags({
        'vibration_enabled': 'true',
        'notification_preferences': 'sound_and_vibration'
      });
    } catch (e) {
      // Failed to enable vibration
    }
  }

  // Configure notification with sound and vibration
  static Future<void> configureNotificationDefaults() async {
    try {
      // Only set essential tags to avoid OneSignal tag limit
      await setUserTags({
        'notification_channel':
            'onesignal_default', // Use OneSignal default channel
        'sound_enabled': 'true'
      });
    } catch (e) {
      // Failed to configure notification defaults
    }
  }

  // Send a test notification to verify heads-up display
  static Future<void> sendTestNotification() async {
    try {
      await setUserTags({
        'test_notification': 'requested',
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString()
      });
    } catch (e) {
      // Failed to send test notification
    }
  }
}
