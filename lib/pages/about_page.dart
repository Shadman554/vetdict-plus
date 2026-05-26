import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';
import '../models/ceo.dart';
import '../models/supporter.dart';

// ─── Single accent used across the entire page ───────────────────────────────
const Color _kAccent = Color(0xFF4A6FA5);

class AboutPage extends StatefulWidget {
  const AboutPage({Key? key}) : super(key: key);

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final ApiService _apiService = ApiService();
  
  List<CEO> _ceos = [];
  List<Supporter> _supporters = [];
  String? _aboutText;
  bool _isLoadingAbout = true;

  bool _isLoadingCEOs = true;
  bool _isLoadingSupporters = true;
  
  String? _ceoError;
  String? _supporterError;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Try loading from cache first
    final hasCache = await _loadFromCache();
    
    // If we have cache, check for updates in background
    // If no cache, wait for API data
    if (hasCache) {
      _checkForUpdates();
    } else {
      await _checkForUpdates();
      setState(() {
        _isLoadingAbout = false;
        _isLoadingCEOs = false;
        _isLoadingSupporters = false;
      });
    }
  }

  Future<bool> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool hasAnyCache = false;
      
      // Load cached about text
      final cachedAboutText = prefs.getString('about_text');
      if (cachedAboutText != null) {
        setState(() {
          _aboutText = cachedAboutText;
          _isLoadingAbout = false;
        });
        hasAnyCache = true;
      }
      
      // Load cached CEOs
      final cachedCEOsJson = prefs.getString('about_ceos');
      if (cachedCEOsJson != null) {
        final List<dynamic> ceosData = json.decode(cachedCEOsJson);
        setState(() {
          _ceos = ceosData.map((e) => CEO.fromJson(e)).toList();
          _isLoadingCEOs = false;
        });
        hasAnyCache = true;
      }
      
      // Load cached Supporters
      final cachedSupportersJson = prefs.getString('about_supporters');
      if (cachedSupportersJson != null) {
        final List<dynamic> supportersData = json.decode(cachedSupportersJson);
        setState(() {
          _supporters = supportersData.map((e) => Supporter.fromJson(e)).toList();
          _isLoadingSupporters = false;
        });
        hasAnyCache = true;
      }
      
      return hasAnyCache;
    } catch (e) {
      developer.log('Error loading from cache: $e');
      return false;
    }
  }

  Future<void> _checkForUpdates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Fetch fresh data from API
      final newAboutText = await _apiService.fetchAboutText();
      final newCEOs = await _apiService.fetchCEOs();
      final newSupporters = await _apiService.fetchSupporters();
      
      // Calculate hashes of new data
      final newAboutHash = newAboutText?.hashCode.toString() ?? '';
      final newCEOsHash = json.encode(newCEOs.map((e) => e.toJson()).toList()).hashCode.toString();
      final newSupportersHash = json.encode(newSupporters.map((e) => e.toJson()).toList()).hashCode.toString();
      
      // Get cached hashes
      final cachedAboutHash = prefs.getString('about_text_hash') ?? '';
      final cachedCEOsHash = prefs.getString('about_ceos_hash') ?? '';
      final cachedSupportersHash = prefs.getString('about_supporters_hash') ?? '';
      
      // Update only if data changed
      bool hasChanges = false;
      
      if (newAboutHash != cachedAboutHash && newAboutText != null) {
        await prefs.setString('about_text', newAboutText);
        await prefs.setString('about_text_hash', newAboutHash);
        if (mounted) {
          setState(() => _aboutText = newAboutText);
        }
        hasChanges = true;
      }
      
      if (newCEOsHash != cachedCEOsHash) {
        final ceosJson = json.encode(newCEOs.map((e) => e.toJson()).toList());
        await prefs.setString('about_ceos', ceosJson);
        await prefs.setString('about_ceos_hash', newCEOsHash);
        if (mounted) {
          setState(() => _ceos = newCEOs);
        }
        hasChanges = true;
      }
      
      if (newSupportersHash != cachedSupportersHash) {
        final supportersJson = json.encode(newSupporters.map((e) => e.toJson()).toList());
        await prefs.setString('about_supporters', supportersJson);
        await prefs.setString('about_supporters_hash', newSupportersHash);
        if (mounted) {
          setState(() => _supporters = newSupporters);
        }
        hasChanges = true;
      }
      
      if (hasChanges && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('زانیاری نوێکراوە'),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFF4A6FA5),
          ),
        );
      }
    } catch (e) {
      developer.log('Error checking for updates: $e');
      // Silently fail - user already has cached data
    }
  }

  Future<void> _forceRefresh() async {
    setState(() {
      _isLoadingAbout = true;
      _isLoadingCEOs = true;
      _isLoadingSupporters = true;
      _ceoError = null;
      _supporterError = null;
    });
    
    await _checkForUpdates();
    
    setState(() {
      _isLoadingAbout = false;
      _isLoadingCEOs = false;
      _isLoadingSupporters = false;
    });
  }

  IconData _getIconFromString(String? iconName) {
    if (iconName == null) return Icons.person;
    switch (iconName.toLowerCase()) {
      case 'school':
        return Icons.school;
      case 'medical_services':
        return Icons.medical_services;
      case 'person':
        return Icons.person;
      default:
        return Icons.person;
    }
  }

  // ─── Shared card decoration ─────────────────────────────────────────────────
  BoxDecoration _cardDecoration(ThemeProvider tp) => BoxDecoration(
        color: tp.isDarkMode ? const Color(0xFF232323) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: tp.isDarkMode
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.grey.withValues(alpha: 0.18),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: tp.isDarkMode ? 0.22 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      );

  // ─── Shared section title ───────────────────────────────────────────────────
  Widget _sectionTitle(
      String text, ThemeProvider tp, LanguageProvider lp) {
    return SizedBox(
      width: double.infinity,
      child: Directionality(
        textDirection: lp.textDirection,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: tp.isDarkMode ? Colors.white : Colors.black87,
            fontFamily: 'Inter',
            letterSpacing: 0.2,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // ─── Shared avatar ──────────────────────────────────────────────────────────
  Widget _avatar(
      {required String? imagePath,
      required IconData fallbackIcon,
      required ThemeProvider tp,
      double size = 58}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tp.isDarkMode ? const Color(0xFF3A3A3A) : const Color(0xFFECEFF4),
        shape: BoxShape.circle,
        border: Border.all(
          color: tp.isDarkMode
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.grey.withValues(alpha: 0.22),
          width: 1.5,
        ),
      ),
      child: imagePath != null
          ? ClipOval(
              child: Image.asset(
                imagePath,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  fallbackIcon,
                  size: size * 0.44,
                  color: tp.isDarkMode ? Colors.white54 : Colors.grey[500],
                ),
              ),
            )
          : Icon(
              fallbackIcon,
              size: size * 0.44,
              color: tp.isDarkMode ? Colors.white54 : Colors.grey[500],
            ),
    );
  }

  // ─── Shared name + subtitle row ─────────────────────────────────────────────
  Widget _nameBlock({
    required String name,
    required String subtitle,
    String? extra,
    required ThemeProvider tp,
    required LanguageProvider lp,
  }) {
    return Column(
      crossAxisAlignment:
          lp.isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Directionality(
          textDirection: lp.textDirection,
          child: Text(
            name,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: tp.isDarkMode ? Colors.white : Colors.black87,
              fontFamily: 'Inter',
            ),
            textAlign: lp.isRTL ? TextAlign.right : TextAlign.left,
          ),
        ),
        const SizedBox(height: 4),
        Directionality(
          textDirection: lp.textDirection,
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.5,
              color: tp.isDarkMode
                  ? Colors.white.withValues(alpha: 0.50)
                  : Colors.grey[600],
              fontFamily: 'Inter',
            ),
            textAlign: lp.isRTL ? TextAlign.right : TextAlign.left,
          ),
        ),
        if (extra != null && extra.isNotEmpty) ...[
          const SizedBox(height: 3),
          Directionality(
            textDirection: lp.textDirection,
            child: Text(
              extra,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: tp.isDarkMode
                    ? Colors.white.withValues(alpha: 0.38)
                    : Colors.grey[400],
                fontFamily: 'Inter',
              ),
              textAlign: lp.isRTL ? TextAlign.right : TextAlign.left,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tp = Provider.of<ThemeProvider>(context);
    final lp = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: tp.theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: tp.theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: tp.isDarkMode ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Directionality(
          textDirection: lp.textDirection,
          child: Text(
            'دەربارەی',
            style: TextStyle(
              color: tp.isDarkMode ? Colors.white : Colors.black,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDescriptionSection(tp, lp),
              const SizedBox(height: 20),
              _buildCEOSection(tp, lp),
              const SizedBox(height: 20),
              _buildSupportTeamSection(tp, lp),
              const SizedBox(height: 32),
              _buildFooter(tp),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Footer
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildFooter(ThemeProvider tp) {
    return Column(
      children: [
        const Text(
          'VET DICT +',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _kAccent,
            fontFamily: 'Inter',
            letterSpacing: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          '© 2026  All rights reserved',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: tp.isDarkMode
                ? Colors.white.withValues(alpha: 0.35)
                : Colors.grey[400],
            fontFamily: 'Inter',
            letterSpacing: 0.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SECTION 1 – App description (dynamic Markdown from API)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildDescriptionSection(ThemeProvider tp, LanguageProvider lp) {
    final textColor = tp.isDarkMode
        ? Colors.white.withValues(alpha: 0.80)
        : Colors.grey[800]!;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(tp),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('دەربارەی ئەپڵیکەیشن', tp, lp),
          const SizedBox(height: 14),
          
          // Medical/Health Disclaimer - Required by Play Store policy
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFF59E0B),
                width: 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Color(0xFFD97706),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Directionality(
                    textDirection: lp.textDirection,
                    child: Text(
                      'ئاگاداری: VET DICT+ تەنها بۆ مەبەستی پەروەردەیی و زانیاری پێدانە. بەهیچ شێوەیەک ناکرێت بۆ مەبەستی چارەسەرکردن پشتی پێ ببەسترێت.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: tp.isDarkMode ? const Color(0xFF92400E) : const Color(0xFF78350F),
                        fontFamily: 'NRT',
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: lp.isRTL ? TextAlign.right : TextAlign.left,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 4),
          if (_isLoadingAbout)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_kAccent),
                ),
              ),
            )
          else if (_aboutText != null && _aboutText!.isNotEmpty)
            Directionality(
              textDirection: lp.textDirection,
              child: Builder(
                builder: (context) {
                  final rawText = _aboutText!;
                  // Handle Delta JSON format (from flutter_quill)
                  if (rawText.trimLeft().startsWith('[') && rawText.contains('"insert"')) {
                    try {
                      final deltaOps = (json.decode(rawText) as List).cast<Map<String, dynamic>>();
                      return _buildDeltaContent(deltaOps, textColor, tp, lp);
                    } catch (e) {
                      developer.log('Error parsing Delta JSON: $e');
                    }
                  }
                  // If looks like markdown, render as markdown
                  if (rawText.contains('**') || rawText.contains('# ') || rawText.contains('- ') || rawText.contains('> ')) {
                    return MarkdownBody(
                      data: rawText,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          fontSize: 14,
                          height: 1.8,
                          color: textColor,
                          fontFamily: 'Inter',
                        ),
                        strong: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _kAccent,
                          fontFamily: 'Inter',
                        ),
                        em: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: textColor,
                          fontFamily: 'Inter',
                        ),
                        h1: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: tp.isDarkMode ? Colors.white : Colors.black87,
                          fontFamily: 'Inter',
                        ),
                        h2: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: tp.isDarkMode ? Colors.white : Colors.black87,
                          fontFamily: 'Inter',
                        ),
                        h3: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _kAccent,
                          fontFamily: 'Inter',
                        ),
                        listBullet: const TextStyle(
                          fontSize: 14,
                          color: _kAccent,
                          fontFamily: 'Inter',
                        ),
                        blockquoteDecoration: BoxDecoration(
                          color: _kAccent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: const Border(
                            right: BorderSide(color: _kAccent, width: 3),
                          ),
                        ),
                        code: TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                          color: _kAccent,
                          backgroundColor: _kAccent.withValues(alpha: 0.08),
                        ),
                        textAlign: WrapAlignment.start,
                      ),
                      onTapLink: (text, href, title) {
                        if (href != null) _launchURL(href);
                      },
                    );
                  }
                  // Plain text rendering
                  return Text(
                    rawText,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.8,
                      color: textColor,
                      fontFamily: 'Inter',
                    ),
                    textAlign: lp.isRTL ? TextAlign.right : TextAlign.left,
                  );
                },
              ),
            )
          else
            // Fallback: show default hardcoded text if no API data
            Directionality(
              textDirection: lp.textDirection,
              child: Text(
                'VET DICT + یەکەم فەرهەنگی پزیشکی پیشەی بۆ پزیشکانی ڤێترنەری لە کوردستان.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.8,
                  color: textColor,
                  fontFamily: 'Inter',
                ),
                textAlign: lp.isRTL ? TextAlign.right : TextAlign.left,
              ),
            ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SECTION 2 – Project managers
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildCEOSection(ThemeProvider tp, LanguageProvider lp) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(tp),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('بەڕێوەبەرانی پڕۆژە', tp, lp),
          const SizedBox(height: 16),
          if (_isLoadingCEOs)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_kAccent),
                ),
              ),
            )
          else if (_ceoError != null)
            Center(
              child: Column(
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                  const SizedBox(height: 12),
                  Text(
                    'هەڵەیەک ڕوویدا لە بارکردنی زانیاری',
                    style: TextStyle(
                      color: tp.isDarkMode ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _forceRefresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('هەوڵدانەوە'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kAccent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          else if (_ceos.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'هیچ زانیارییەک نەدۆزرایەوە',
                  style: TextStyle(
                    color: tp.isDarkMode ? Colors.white70 : Colors.grey[600],
                  ),
                ),
              ),
            )
          else
            ...List.generate(_ceos.length, (i) {
              final ceo = _ceos[i];
              final socialMedia = <String, String>{};
              if (ceo.facebookUrl != null && ceo.facebookUrl!.isNotEmpty) {
                socialMedia['facebook'] = ceo.facebookUrl!;
              }
              if (ceo.instagramUrl != null && ceo.instagramUrl!.isNotEmpty) {
                socialMedia['instagram'] = ceo.instagramUrl!;
              }
              if (ceo.viberUrl != null && ceo.viberUrl!.isNotEmpty) {
                socialMedia['viber'] = ceo.viberUrl!;
              }
              
              return Column(
                children: [
                  _buildPersonRow(
                    name: ceo.name,
                    subtitle: ceo.role,
                    extra: ceo.description,
                    imagePath: ceo.imageUrl,
                    fallbackIcon: Icons.person,
                    tp: tp,
                    lp: lp,
                    socialMedia: socialMedia.isNotEmpty ? socialMedia : null,
                  ),
                  if (i < _ceos.length - 1) _divider(tp),
                ],
              );
            }),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SECTION 3 – Support / collaborators
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildSupportTeamSection(ThemeProvider tp, LanguageProvider lp) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(tp),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('هاوکاران', tp, lp),
          const SizedBox(height: 4),
          Directionality(
            textDirection: lp.textDirection,
            child: Text(
              'سوپاسی بێ پایانمان بۆ هەر یەکە لەم بەڕێزانە کە بە شێوازی جۆراو جۆر هاوکارمان بوون',
              style: TextStyle(
                fontSize: 12,
                color: tp.isDarkMode
                    ? Colors.white.withValues(alpha: 0.45)
                    : Colors.grey[500],
                fontFamily: 'Inter',
              ),
              textAlign: lp.isRTL ? TextAlign.right : TextAlign.left,
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoadingSupporters)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_kAccent),
                ),
              ),
            )
          else if (_supporterError != null)
            Center(
              child: Column(
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                  const SizedBox(height: 12),
                  Text(
                    'هەڵەیەک ڕوویدا لە بارکردنی زانیاری',
                    style: TextStyle(
                      color: tp.isDarkMode ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _forceRefresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('هەوڵدانەوە'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kAccent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          else if (_supporters.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'هیچ زانیارییەک نەدۆزرایەوە',
                  style: TextStyle(
                    color: tp.isDarkMode ? Colors.white70 : Colors.grey[600],
                  ),
                ),
              ),
            )
          else
            ...List.generate(_supporters.length, (i) {
              final supporter = _supporters[i];
              return Column(
                children: [
                  _buildPersonRow(
                    name: supporter.name,
                    subtitle: supporter.title,
                    extra: supporter.description,
                    imagePath: supporter.imageUrl,
                    fallbackIcon: _getIconFromString(supporter.icon),
                    tp: tp,
                    lp: lp,
                  ),
                  if (i < _supporters.length - 1) _divider(tp),
                ],
              );
            }),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Shared person row (avatar + name block + optional social buttons)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildPersonRow({
    required String name,
    required String subtitle,
    String? extra,
    String? imagePath,
    required IconData fallbackIcon,
    required ThemeProvider tp,
    required LanguageProvider lp,
    Map<String, String>? socialMedia,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _avatar(imagePath: imagePath, fallbackIcon: fallbackIcon, tp: tp),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: lp.isRTL
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                _nameBlock(
                    name: name, subtitle: subtitle, extra: extra, tp: tp, lp: lp),
                if (socialMedia != null && socialMedia.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: lp.isRTL
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    children: socialMedia.entries
                        .map((e) => _socialButton(e.key, e.value, tp))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Divider between rows inside a card
  // ───────────────────────────────────────────────────────────────────────────
  Widget _divider(ThemeProvider tp) => Divider(
        height: 1,
        thickness: 1,
        color: tp.isDarkMode
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.grey.withValues(alpha: 0.13),
      );

  // ───────────────────────────────────────────────────────────────────────────
  // Social media icon button (neutral style)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _socialButton(String platform, String url, ThemeProvider tp) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => _launchURL(url),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: tp.isDarkMode
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.grey.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: tp.isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey.withValues(alpha: 0.20),
              width: 1,
            ),
          ),
          child: _socialIcon(platform, tp),
        ),
      ),
    );
  }

  Widget _socialIcon(String platform, ThemeProvider tp) {
    final Color iconColor =
        tp.isDarkMode ? Colors.white60 : Colors.grey[600]!;
    switch (platform.toLowerCase()) {
      case 'facebook':
        return Icon(Icons.facebook, size: 18, color: iconColor);
      case 'instagram':
        return FaIcon(FontAwesomeIcons.instagram, size: 18, color: iconColor);
      case 'viber':
        return Image.asset(
          'assets/icon/viber.png',
          width: 18,
          height: 18,
          color: iconColor,
          errorBuilder: (_, __, ___) =>
              Icon(Icons.chat_bubble_outline, size: 18, color: iconColor),
        );
      default:
        return Icon(Icons.link, size: 18, color: iconColor);
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Delta JSON renderer — converts Quill Delta ops into Flutter widgets
  // Supports: bold, italic, underline, strikethrough, color, background,
  //           headers (h1–h3), ordered/unordered lists, alignment, blockquote
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildDeltaContent(
    List<Map<String, dynamic>> ops,
    Color textColor,
    ThemeProvider tp,
    LanguageProvider lp,
  ) {
    // Split ops into lines, each line = list of (text, attributes) + line attrs
    final lines = <_DeltaLine>[];
    var currentSpans = <_DeltaSpan>[];
    Map<String, dynamic> lineAttrs = {};

    for (final op in ops) {
      final insert = op['insert'];
      final attrs = op['attributes'] as Map<String, dynamic>? ?? {};

      if (insert is String) {
        final parts = insert.split('\n');
        for (int i = 0; i < parts.length; i++) {
          if (parts[i].isNotEmpty) {
            currentSpans.add(_DeltaSpan(parts[i], Map<String, dynamic>.from(attrs)));
          }
          if (i < parts.length - 1) {
            // Newline found — flush current line
            // Line-level attributes (header, list, align) come from attrs on the '\n' insert
            if (parts[i].isEmpty && currentSpans.isEmpty && i == 0) {
              lineAttrs = Map<String, dynamic>.from(attrs);
            } else {
              lineAttrs = i == 0 ? Map<String, dynamic>.from(attrs) : {};
            }
            lines.add(_DeltaLine(List.from(currentSpans), Map<String, dynamic>.from(lineAttrs)));
            currentSpans = [];
            lineAttrs = {};
          }
        }
        // If the very last op is just '\n' with attrs, apply attrs to the last pending line
        if (insert == '\n' && attrs.isNotEmpty && lines.isNotEmpty) {
          lines.last.lineAttributes.addAll(attrs);
        }
      }
    }
    // Flush remaining spans
    if (currentSpans.isNotEmpty) {
      lines.add(_DeltaLine(currentSpans, lineAttrs));
    }

    // Build widgets for each line
    final widgets = <Widget>[];
    int orderedIndex = 0;
    
    for (final line in lines) {
      final la = line.lineAttributes;
      final header = la['header'] as int?;
      final listType = la['list'] as String?;
      final alignStr = la['align'] as String?;
      final isBlockquote = la['blockquote'] == true;

      // Determine base font size
      double fontSize = 14;
      FontWeight fontWeight = FontWeight.w400;
      if (header != null) {
        switch (header) {
          case 1:
            fontSize = 22;
            fontWeight = FontWeight.w800;
            break;
          case 2:
            fontSize = 18;
            fontWeight = FontWeight.w700;
            break;
          case 3:
            fontSize = 16;
            fontWeight = FontWeight.w600;
            break;
        }
      }

      // Build text spans
      final spans = <InlineSpan>[];
      for (final s in line.spans) {
        final a = s.attributes;
        final isBold = a['bold'] == true;
        final isItalic = a['italic'] == true;
        final isUnderline = a['underline'] == true;
        final isStrike = a['strike'] == true;
        
        Color? spanColor;
        if (a['color'] is String) {
          spanColor = _parseHexColor(a['color'] as String);
        }
        Color? bgColor;
        if (a['background'] is String) {
          bgColor = _parseHexColor(a['background'] as String);
        }

        final decorations = <TextDecoration>[];
        if (isUnderline) decorations.add(TextDecoration.underline);
        if (isStrike) decorations.add(TextDecoration.lineThrough);

        spans.add(TextSpan(
          text: s.text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold || header != null ? (isBold ? FontWeight.w700 : fontWeight) : FontWeight.w400,
            fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
            decoration: decorations.isEmpty ? TextDecoration.none : TextDecoration.combine(decorations),
            color: spanColor ?? (header != null && header <= 2
                ? (tp.isDarkMode ? Colors.white : Colors.black87)
                : (header == 3 ? _kAccent : textColor)),
            backgroundColor: bgColor,
            fontFamily: 'Inter',
            height: 1.6,
          ),
        ));
      }

      // If no spans, add empty span to preserve the empty line
      if (spans.isEmpty) {
        spans.add(TextSpan(
          text: '',
          style: TextStyle(fontSize: fontSize, height: 1.6, fontFamily: 'Inter'),
        ));
      }

      // Determine alignment
      TextAlign textAlign = lp.isRTL ? TextAlign.right : TextAlign.left;
      if (alignStr != null) {
        switch (alignStr) {
          case 'center':
            textAlign = TextAlign.center;
            break;
          case 'right':
            textAlign = TextAlign.right;
            break;
          case 'justify':
            textAlign = TextAlign.justify;
            break;
          default:
            break;
        }
      }

      Widget lineWidget = RichText(
        textAlign: textAlign,
        textDirection: lp.textDirection,
        text: TextSpan(children: spans),
      );

      // Handle list items
      if (listType != null) {
        if (listType == 'ordered') {
          orderedIndex++;
        } else {
          orderedIndex = 0;
        }
        final bullet = listType == 'ordered' ? '$orderedIndex. ' : '• ';
        lineWidget = Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bullet,
                style: TextStyle(
                  fontSize: fontSize,
                  color: _kAccent,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                  height: 1.6,
                ),
              ),
              Expanded(child: lineWidget),
            ],
          ),
        );
      } else {
        orderedIndex = 0;
      }

      // Handle blockquote
      if (isBlockquote) {
        lineWidget = Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: _kAccent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border(
              right: lp.isRTL ? const BorderSide(color: _kAccent, width: 3) : BorderSide.none,
              left: lp.isRTL ? BorderSide.none : const BorderSide(color: _kAccent, width: 3),
            ),
          ),
          child: lineWidget,
        );
      }

      widgets.add(Padding(
        padding: EdgeInsets.only(bottom: header != null ? 8 : 2),
        child: lineWidget,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widgets,
    );
  }

  Color? _parseHexColor(String hex) {
    try {
      hex = hex.replaceFirst('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      if (hex.length == 8) return Color(int.parse(hex, radix: 16));
    } catch (_) {}
    return null;
  }

  Future<void> _launchURL(String url) async {

    try {
      // For Instagram: try native app deep link first, then HTTPS fallback
      if (url.contains('instagram.com')) {
        final path = Uri.parse(url).path; // e.g. /shadman_osman1/
        final nativeUri = Uri.parse('instagram://user?username=${path.replaceAll('/', '')}');
        try {
          await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
          return;
        } catch (_) {
          // native app not installed, fall through to browser
        }
      }
      final Uri uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (kDebugMode) debugPrint('Could not launch $url: $e');
    }
  }
}

// Helper classes for Delta JSON rendering
class _DeltaSpan {
  final String text;
  final Map<String, dynamic> attributes;
  _DeltaSpan(this.text, this.attributes);
}

class _DeltaLine {
  final List<_DeltaSpan> spans;
  final Map<String, dynamic> lineAttributes;
  _DeltaLine(this.spans, this.lineAttributes);
}
