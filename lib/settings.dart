import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'providers/language_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/font_size_provider.dart';
import 'services/onesignal_service.dart';
import 'utils/constants.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _appVersion = '';
  bool _notificationsEnabled = false;
  bool _checkingPermission = true;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _checkNotificationPermission();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = info.version;
      });
    }
  }

  Future<void> _checkNotificationPermission() async {
    final hasPermission = await OneSignalService.hasNotificationPermission();
    if (mounted) {
      setState(() {
        _notificationsEnabled = hasPermission;
        _checkingPermission = false;
      });
    }
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
          title: Directionality(
            textDirection: languageProvider.textDirection,
            child: Text(
              'ڕێکخستنەکان',
              style: TextStyle(
                color: themeProvider.isDarkMode ? Colors.white : const Color(0xFF1E293B),
                fontSize: 20,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
              textAlign: languageProvider.isRTL ? TextAlign.right : TextAlign.left,
            ),
          ),
          backgroundColor: themeProvider.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          centerTitle: true,
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            Directionality(
              textDirection: TextDirection.ltr,
              child: IconButton(
                icon: Icon(Icons.arrow_back, 
                  color: themeProvider.isDarkMode ? Colors.white : const Color(0xFF1E293B)
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSettingsSection(
              title: 'ڕووکار',
              children: [
                _buildThemeToggle(),
                _buildFontSizeSlider(),
              ],
            ),

            const SizedBox(height: 24),
            _buildSettingsSection(
              title: 'ئاگادارییەکان',
              children: [
                _buildNotificationToggle(),
              ],
            ),

            const SizedBox(height: 24),
            _buildSettingsSection(
              title:'دەربارە',
              children: [
                _buildAboutTile(),
                _buildDivider(),
                _buildPrivacyPolicyTile(),
              ],
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection({required String title, required List<Widget> children}) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: themeProvider.isDarkMode
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text(
              title,
              style: TextStyle(
                color: themeProvider.isDarkMode ? Colors.white : const Color(0xFF1E293B),
                fontSize: 19,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter',
                letterSpacing: 0.2,
              ),
              textAlign: languageProvider.isRTL ? TextAlign.right : TextAlign.left,
              textDirection: languageProvider.textDirection,
            ),
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: themeProvider.isDarkMode ? Colors.grey[600] : Colors.grey[300],
            indent: 20,
            endIndent: 20,
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildThemeToggle() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Directionality(
        textDirection: languageProvider.textDirection,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'دۆخی تاریک',
                style: TextStyle(
                  color: themeProvider.isDarkMode ? Colors.white : const Color(0xFF475569),
                  fontSize: 16,
                  fontFamily: 'Inter',
                ),
                textAlign: languageProvider.isRTL ? TextAlign.right : TextAlign.left,
              ),
            ),
            Switch(
              value: themeProvider.isDarkMode,
              onChanged: (value) {
                themeProvider.toggleTheme();
              },
              activeThumbColor: const Color(0xFF4A7EB5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFontSizeSlider() {
    final fontSizeProvider = Provider.of<FontSizeProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: languageProvider.isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Directionality(
            textDirection: languageProvider.textDirection,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'قەبارەی فۆنت',
                    style: TextStyle(
                      color: themeProvider.isDarkMode ? Colors.white : const Color(0xFF1E293B),
                      fontSize: 16,
                      fontFamily: 'Inter',
                    ),
                    textAlign: languageProvider.isRTL ? TextAlign.right : TextAlign.left,
                  ),
                ),
                Text(
                  '${(fontSizeProvider.fontSize * 100).round()}%',
                  style: TextStyle(
                    color: themeProvider.isDarkMode ? Colors.white70 : Colors.grey[600],
                    fontSize: 14,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
          Slider(
            value: fontSizeProvider.fontSize,
            min: 0.8,
            max: 1.4,
            divisions: 6,
            onChanged: (value) {
              fontSizeProvider.setFontSize(value);
            },
            activeColor: const Color(0xFF6366F1),
            inactiveColor: themeProvider.isDarkMode ? Colors.white24 : Colors.grey[300],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationToggle() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Directionality(
        textDirection: languageProvider.textDirection,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: languageProvider.isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    'ئاگادارییەکان',
                    style: TextStyle(
                      color: themeProvider.isDarkMode ? Colors.white : const Color(0xFF475569),
                      fontSize: 16,
                      fontFamily: 'NRT',
                    ),
                    textAlign: languageProvider.isRTL ? TextAlign.right : TextAlign.left,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'وەرگرتنی ئاگادارییەکان بۆ ناوەڕۆکی نوێ',
                    style: TextStyle(
                      color: themeProvider.isDarkMode ? Colors.white60 : Colors.grey[600],
                      fontSize: 12,
                      fontFamily: 'NRT',
                    ),
                    textAlign: languageProvider.isRTL ? TextAlign.right : TextAlign.left,
                  ),
                ],
              ),
            ),
            if (_checkingPermission)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Switch(
                value: _notificationsEnabled,
                onChanged: (value) => _handleNotificationToggle(value),
                activeThumbColor: const Color(0xFF4A7EB5),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleNotificationToggle(bool enable) async {
    if (!enable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'بۆ ناچالاککردنی ئاگادارییەکان، سەردانی ڕێکخستنەکانی سیستەم بکە',
            style: TextStyle(fontFamily: 'NRT'),
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final shouldRequest = await _showNotificationRationaleDialog();
    if (!shouldRequest) {
      // User cancelled - refresh to ensure toggle shows correct state
      await _checkNotificationPermission();
      return;
    }

    final granted = await OneSignalService.requestNotificationPermission();
    
    // Wait a moment for permission to be processed
    await Future.delayed(const Duration(milliseconds: 300));
    
    // Refresh permission status from OneSignal
    await _checkNotificationPermission();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            granted 
                ? 'ئاگادارییەکان چالاککرا' 
                : 'مۆڵەت نەدرا',
            style: const TextStyle(fontFamily: 'NRT'),
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: granted ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<bool> _showNotificationRationaleDialog() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: languageProvider.textDirection,
        child: AlertDialog(
          backgroundColor: themeProvider.isDarkMode 
              ? themeProvider.theme.colorScheme.surface 
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.notifications_active, color: Color(0xFF4A7EB5)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'چالاککردنی ئاگادارییەکان',
                  style: TextStyle(
                    fontFamily: 'NRT',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.isDarkMode 
                        ? Colors.white 
                        : Colors.black,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ئەگەر دەتەوێت لەکاتی بوونی هەر چالاکیەکی نوێ وەک زیادکردنی زانیاری ، وەشانی نوێی ئەپ یاخود هەر ئاگادارکردنەوەیەک سەبارەت بە ئەپڵیکەیشنەکەمان ئاگاداربیت تکایە نۆتیفیکەیشن چالاک بکە',
                style: TextStyle(
                  fontFamily: 'NRT',
                  fontSize: 15,
                  height: 1.6,
                  color: themeProvider.isDarkMode 
                      ? Colors.white 
                      : Colors.black87,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF0EA5E9)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF0369A1), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'دەتوانیت هەر کاتێک ویستت لە سیتینگی موبایلەکەتەوە ناچالاکی بکەیتەوە',
                        style: TextStyle(
                          fontFamily: 'NRT',
                          fontSize: 12,
                          color: themeProvider.isDarkMode 
                              ? const Color(0xFF0369A1) 
                              : const Color(0xFF075985),
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'پاشگەزبوونەوە',
                style: TextStyle(
                  fontFamily: 'NRT',
                  color: themeProvider.isDarkMode 
                      ? Colors.white60 
                      : Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A7EB5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'چالاککردن',
                style: TextStyle(
                  fontFamily: 'NRT',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return result ?? false;
  }

  Widget _buildDivider() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Divider(
      height: 1,
      thickness: 0.5,
      color: themeProvider.isDarkMode ? Colors.grey[700] : Colors.grey[200],
      indent: 16,
      endIndent: 16,
    );
  }

  Widget _buildPrivacyPolicyTile() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    return Directionality(
      textDirection: languageProvider.textDirection,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF4A7EB5).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.privacy_tip_outlined,
            color: Color(0xFF4A7EB5),
            size: 20,
          ),
        ),
        title: Text(
          'سیاسەتی تایبەتمەندی',
          style: TextStyle(
            color: themeProvider.isDarkMode ? Colors.white : const Color(0xFF475569),
            fontSize: 15,
            fontFamily: 'NRT',
          ),
          textAlign: languageProvider.isRTL ? TextAlign.right : TextAlign.left,
        ),
        trailing: Icon(
          languageProvider.isRTL ? Icons.arrow_back_ios_rounded : Icons.arrow_forward_ios_rounded,
          size: 14,
          color: themeProvider.isDarkMode ? Colors.grey[500] : Colors.grey[400],
        ),
        onTap: () => _showPrivacyPolicyBottomSheet(context),
      ),
    );
  }

  void _showPrivacyPolicyBottomSheet(BuildContext context) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..loadRequest(Uri.parse(AppConstants.privacyPolicyUrl));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final themeProvider = Provider.of<ThemeProvider>(context);
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: themeProvider.theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: themeProvider.isDarkMode ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'سیاسەتی تایبەتمەندی',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.theme.colorScheme.onSurface,
                    fontFamily: 'NRT',
                  ),
                ),
              ),
              Expanded(
                child: WebViewWidget(
                  controller: controller,
                  gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                    Factory<VerticalDragGestureRecognizer>(
                      () => VerticalDragGestureRecognizer(),
                    ),
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAboutTile() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    return Directionality(
      textDirection: languageProvider.textDirection,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          'وەشانی ئەپ',
          style: TextStyle(
            color: themeProvider.isDarkMode ? Colors.white : const Color(0xFF475569),
            fontSize: 16,
            fontFamily: 'Inter',
          ),
          textAlign: languageProvider.isRTL ? TextAlign.right : TextAlign.left,
        ),
        trailing: Text(
          _appVersion.isEmpty ? '...' : _appVersion,
          style: TextStyle(
            color: themeProvider.isDarkMode ? Colors.grey[400] : const Color(0xFF64748B),
            fontSize: 16,
            fontFamily: 'Inter',
          ),
        ),
      ),
    );
  }

}