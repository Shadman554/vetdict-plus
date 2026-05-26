import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'onesignal_service.dart';

/// Service to handle first-time notification permission prompt
/// This is Play Store compliant because it shows a rationale dialog BEFORE requesting permission
class NotificationPermissionService {
  static const String _keyNotificationPromptShown = 'notification_prompt_shown';
  
  /// Check if we should show the first-time notification prompt
  static Future<bool> shouldShowFirstTimePrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final hasShown = prefs.getBool(_keyNotificationPromptShown) ?? false;
    
    // Only show if we haven't shown before AND permission not already granted
    if (hasShown) return false;
    
    final hasPermission = await OneSignalService.hasNotificationPermission();
    return !hasPermission;
  }
  
  /// Mark that we've shown the first-time prompt
  static Future<void> markPromptAsShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotificationPromptShown, true);
  }
  
  /// Show the first-time notification rationale dialog
  /// Returns true if user granted permission, false otherwise
  static Future<bool> showFirstTimePrompt(BuildContext context) async {
    // Mark as shown immediately to prevent showing again
    await markPromptAsShown();
    
    if (!context.mounted) return false;
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _FirstTimeNotificationDialog(),
    );
    
    if (result == true) {
      // User agreed - request permission
      final granted = await OneSignalService.requestNotificationPermission();
      return granted;
    }
    
    return false;
  }
}

class _FirstTimeNotificationDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF4A7EB5).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.notifications_active,
                color: Color(0xFF4A7EB5),
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'بەخێربێیت بۆ VET DICT+',
                style: TextStyle(
                  fontFamily: 'NRT',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textDirection: TextDirection.rtl,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ئەگەر دەتەوێت لەکاتی بوونی هەر چالاکیەکی نوێ وەک زیادکردنی زانیاری ، وەشانی نوێی ئەپ یاخود هەر ئاگادارکردنەوەیەک سەبارەت بە ئەپڵیکەیشنەکەمان ئاگاداربیت تکایە نۆتیفیکەیشن چالاک بکە',
                style: TextStyle(
                  fontFamily: 'NRT',
                  fontSize: 15,
                  height: 1.6,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFF59E0B),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Color(0xFFD97706),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'دەتوانیت هەر کاتێک ویستت لە سیتینگی موبایلەکەتەوە ناچالاکی بکەیتەوە',
                        style: TextStyle(
                          fontFamily: 'NRT',
                          fontSize: 12,
                          color: Colors.brown[800],
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'نەخێر، سوپاس',
              style: TextStyle(
                fontFamily: 'NRT',
                color: Colors.grey[600],
                fontSize: 15,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A7EB5),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'چالاککردن',
              style: TextStyle(
                fontFamily: 'NRT',
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
