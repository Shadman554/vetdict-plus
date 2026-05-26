import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/language_provider.dart';
import '../providers/theme_provider.dart';
import '../services/onesignal_service.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  String? _playerId;
  bool _isLoading = true;
  final Map<String, bool> _notificationPreferences = {
    'daily_tips': true,
    'new_content': true,
    'quiz_reminders': false,
    'updates': true,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Load saved preferences
      final prefs = await SharedPreferences.getInstance();
      for (final key in _notificationPreferences.keys) {
        final saved = prefs.getBool('notif_pref_$key');
        if (saved != null) {
          _notificationPreferences[key] = saved;
        }
      }

      final playerId = await OneSignalService.getPlayerId();
      if (mounted) {
        setState(() {
          _playerId = playerId;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateNotificationPreference(String key, bool value) async {
    setState(() {
      _notificationPreferences[key] = value;
    });

    // Persist to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_pref_$key', value);

    // Update OneSignal tags based on preferences
    final tags = <String, String>{};
    _notificationPreferences.forEach((prefKey, prefValue) {
      tags['pref_$prefKey'] = prefValue.toString();
    });

    await OneSignalService.setUserTags(tags);
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Directionality(
      textDirection: languageProvider.textDirection,
      child: Scaffold(
        backgroundColor: themeProvider.theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: themeProvider.theme.appBarTheme.backgroundColor,
          elevation: 0,
          title: Text(
            'ڕێکخستنی ئاگادارکردنەوەکان',
            style: TextStyle(
              fontFamily: 'NRT',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: themeProvider.theme.appBarTheme.titleTextStyle?.color,
            ),
          ),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: themeProvider.theme.appBarTheme.iconTheme?.color,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // OneSignal Status Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: themeProvider.theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.notifications_active,
                                color: themeProvider.theme.colorScheme.primary,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'دۆخی ئاگادارکردنەوەکان',
                                style: TextStyle(
                                  fontFamily: 'NRT',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: themeProvider.theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _playerId != null ? 'چالاک - ئامادەی وەرگرتنی ئاگادارکردنەوە' : 'ناچالاک',
                            style: TextStyle(
                              fontFamily: 'NRT',
                              fontSize: 14,
                              color: _playerId != null 
                                  ? Colors.green 
                                  : Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (_playerId != null && _playerId!.length >= 8) ...[
                            const SizedBox(height: 8),
                            Text(
                              'ناسنامەی ئامێر: ${_playerId!.substring(0, 8)}...',
                              style: TextStyle(
                                fontFamily: 'NRT',
                                fontSize: 12,
                                color: themeProvider.theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Notification Preferences
                    Text(
                      'جۆرەکانی ئاگادارکردنەوە',
                      style: TextStyle(
                        fontFamily: 'NRT',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: themeProvider.theme.colorScheme.onSurface,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Daily Tips
                    _buildNotificationTile(
                      context,
                      'daily_tips',
                      'ئامۆژگاریە ڕۆژانەکان',
                      'ئامۆژگاری و زانیاری پزیشکی ڕۆژانە',
                      Icons.lightbulb_outline,
                      themeProvider,
                    ),

                    // New Content
                    _buildNotificationTile(
                      context,
                      'new_content',
                      'ناوەڕۆکی نوێ',
                      'کاتێک دەرمان، نەخۆشی یان زاراوەی نوێ زیاد دەکرێت',
                      Icons.new_releases_outlined,
                      themeProvider,
                    ),

                    // Quiz Reminders
                    _buildNotificationTile(
                      context,
                      'quiz_reminders',
                      'بیرخستنەوەی تاقیکردنەوە',
                      'بیرخستنەوە بۆ بەشداری لە تاقیکردنەوەکان',
                      Icons.quiz_outlined,
                      themeProvider,
                    ),

                    // App Updates
                    _buildNotificationTile(
                      context,
                      'updates',
                      'نوێکردنەوەی ئەپ',
                      'ئاگادارکردنەوە لە نوێکردنەوە و تایبەتمەندی نوێکان',
                      Icons.system_update_outlined,
                      themeProvider,
                    ),

                    const SizedBox(height: 24),

                    // Test Notification Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _sendTestNotification,
                        icon: const Icon(Icons.send),
                        label: const Text(
                          'ناردنی ئاگادارکردنەوەی تاقیکردنەوە',
                          style: TextStyle(
                            fontFamily: 'NRT',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeProvider.theme.colorScheme.primary,
                          foregroundColor: themeProvider.theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildNotificationTile(
    BuildContext context,
    String key,
    String title,
    String subtitle,
    IconData icon,
    ThemeProvider themeProvider,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: themeProvider.theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SwitchListTile(
        value: _notificationPreferences[key] ?? false,
        onChanged: (value) => _updateNotificationPreference(key, value),
        title: Text(
          title,
          style: TextStyle(
            fontFamily: 'NRT',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: themeProvider.theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontFamily: 'NRT',
            fontSize: 14,
            color: themeProvider.theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        secondary: Icon(
          icon,
          color: themeProvider.theme.colorScheme.primary,
        ),
        activeThumbColor: themeProvider.theme.colorScheme.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Future<void> _sendTestNotification() async {
    // This would typically be done from your backend
    // For demonstration, we'll show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'ئاگادارکردنەوەی تاقیکردنەوە لە داشبۆردی OneSignal ناردە',
          style: TextStyle(
            fontFamily: 'NRT',
            fontSize: 14,
          ),
          textDirection: TextDirection.rtl,
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
