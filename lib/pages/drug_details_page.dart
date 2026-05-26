import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import '../providers/history_provider.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_tts/flutter_tts.dart';

class DrugDetailsPage extends StatefulWidget {
  final dynamic drug;

  const DrugDetailsPage({Key? key, required this.drug}) : super(key: key);

  @override
  State<DrugDetailsPage> createState() => _DrugDetailsPageState();
}

class _DrugDetailsPageState extends State<DrugDetailsPage> {
  final FlutterTts flutterTts = FlutterTts();
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initTts();
    
    // Add to history after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<HistoryProvider>(context, listen: false)
          .addToHistory(widget.drug.name, 'drug', 'Viewed drug details', data: widget.drug);
    });
  }

  Future<void> _initTts() async {
    try {
      await flutterTts.setLanguage("en-US");
      await flutterTts.setSpeechRate(0.5);
      await flutterTts.setVolume(1.0);
      await flutterTts.setPitch(1.0);
    } catch (e) {
      if (kDebugMode) {
        debugPrint("TTS initialization error: $e");
      }
    }
  }

  Future<void> _speak(String text) async {
    try {
      if (isPlaying) {
        await flutterTts.stop();
        setState(() => isPlaying = false);
      } else {
        setState(() => isPlaying = true);
        await flutterTts.speak(text);
        setState(() => isPlaying = false);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("TTS speak error: $e");
      }
      setState(() => isPlaying = false);
    }
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final favoritesProvider = Provider.of<FavoritesProvider>(context);
    Provider.of<LanguageProvider>(context);
    final isFavorite = favoritesProvider.isFavorite(widget.drug);

    return Scaffold(
      backgroundColor: themeProvider.theme.scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: themeProvider.isDarkMode 
                  ? const Color(0xFF1E1E1E)
                  : themeProvider.theme.colorScheme.primary.withValues(alpha: 0.8),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 40, left: 16, right: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  // Drug Image
                  if (widget.drug.imageUrl.isNotEmpty)
                    Container(
                      width: 140,
                      height: 140,
                      margin: const EdgeInsets.only(top: 20, bottom: 16),
                      decoration: BoxDecoration(
                        color: themeProvider.isDarkMode 
                          ? Colors.grey[800] 
                          : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: themeProvider.isDarkMode 
                          ? null 
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.network(
                          widget.drug.imageUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                  // Drug Name
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Text(
                      widget.drug.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  // Category (if available) - placed under name
                  if (widget.drug.drugClass.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: themeProvider.isDarkMode 
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        widget.drug.drugClass,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  
                  // Action buttons
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: themeProvider.isDarkMode 
                        ? const Color(0xFF2C2C2C)
                        : Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildActionButton(
                          icon: Icons.copy_rounded,
                          onTap: () {
                            String content = '''${widget.drug.name}
${widget.drug.usage}
${widget.drug.sideEffect}
${widget.drug.otherInfo}
${widget.drug.withdrawalTimes.isNotEmpty ? 'Withdrawal Times: ${widget.drug.withdrawalTimes}' : ''}
${widget.drug.drugInteractions.isNotEmpty ? 'Drug Interactions: ${widget.drug.drugInteractions}' : ''}
${widget.drug.contraindications.isNotEmpty ? 'Contraindications: ${widget.drug.contraindications}' : ''}
${widget.drug.speciesDosages.isNotEmpty ? 'Species Dosages: ${widget.drug.speciesDosages}' : ''}
${widget.drug.tradeNames.isNotEmpty ? 'Trade Names: ${widget.drug.tradeNames}' : ''}''';
                            Clipboard.setData(ClipboardData(text: content.trim()));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Copied to clipboard')),
                            );
                          },
                          label: 'کۆپی',
                          themeProvider: themeProvider,
                        ),
                        _buildActionButton(
                          icon: isFavorite ? Icons.bookmark : Icons.bookmark_border,
                          onTap: () {
                            if (isFavorite) {
                              favoritesProvider.removeFavorite(widget.drug);
                            } else {
                              favoritesProvider.addFavorite(widget.drug);
                            }
                          },
                          label: isFavorite 
                            ? 'پاشەکەوتکراوە'
                            : 'پاشەکەوتکردن',
                          themeProvider: themeProvider,
                        ),
                        _buildActionButton(
                          icon: Icons.share_rounded,
                          onTap: () {
                            String content = '''${widget.drug.name}
${widget.drug.usage}
${widget.drug.sideEffect}
${widget.drug.otherInfo}
${widget.drug.withdrawalTimes.isNotEmpty ? 'Withdrawal Times: ${widget.drug.withdrawalTimes}' : ''}
${widget.drug.drugInteractions.isNotEmpty ? 'Drug Interactions: ${widget.drug.drugInteractions}' : ''}
${widget.drug.contraindications.isNotEmpty ? 'Contraindications: ${widget.drug.contraindications}' : ''}
${widget.drug.speciesDosages.isNotEmpty ? 'Species Dosages: ${widget.drug.speciesDosages}' : ''}
${widget.drug.tradeNames.isNotEmpty ? 'Trade Names: ${widget.drug.tradeNames}' : ''}''';
                            Share.share(content);
                          },
                          label: 'هاوبەشکردن',
                          themeProvider: themeProvider,
                        ),
                        _buildActionButton(
                          icon: isPlaying ? Icons.stop_rounded : Icons.volume_up_rounded,
                          onTap: () {
                            String content = '''${widget.drug.name}
${widget.drug.usage}
${widget.drug.sideEffect}
${widget.drug.otherInfo}
${widget.drug.withdrawalTimes.isNotEmpty ? 'Withdrawal Times: ${widget.drug.withdrawalTimes}' : ''}
${widget.drug.drugInteractions.isNotEmpty ? 'Drug Interactions: ${widget.drug.drugInteractions}' : ''}
${widget.drug.contraindications.isNotEmpty ? 'Contraindications: ${widget.drug.contraindications}' : ''}
${widget.drug.speciesDosages.isNotEmpty ? 'Species Dosages: ${widget.drug.speciesDosages}' : ''}
${widget.drug.tradeNames.isNotEmpty ? 'Trade Names: ${widget.drug.tradeNames}' : ''}''';
                            _speak(content.trim());
                          },
                          label: isPlaying 
                            ? 'وەستان'
                            : 'دەنگ',
                          themeProvider: themeProvider,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            
            // Content sections - ordered to match toJson() structure
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 1. Category (if available)
                  if (widget.drug.category.isNotEmpty) ...[
                    _buildInfoSection(
                      'جۆر',
                      widget.drug.category,
                      Icons.category,
                      themeProvider.isDarkMode 
                        ? Colors.cyan.shade300 
                        : Colors.cyan.shade700,
                      themeProvider,
                    ),
                    const SizedBox(height: 16),
                  ],
                  // 2. Trade Names
                  if (widget.drug.tradeNames.isNotEmpty) ...[  
                    _buildInfoSection(
                      'ناوی بازرگانی',
                      widget.drug.tradeNames,
                      Icons.business,
                      themeProvider.isDarkMode 
                        ? Colors.amber.shade300 
                        : Colors.amber.shade700,
                      themeProvider,
                    ),
                    const SizedBox(height: 16),
                  ],
                  // 4. Description
                  if (widget.drug.description.isNotEmpty) ...[
                    _buildInfoSection(
                      'وەسف',
                      widget.drug.description,
                      Icons.description,
                      themeProvider.isDarkMode 
                        ? const Color(0xFF4A7EB5) 
                        : const Color(0xFF1A3460),
                      themeProvider,
                    ),
                    const SizedBox(height: 16),
                  ],
                  // 5. Usage
                  if (widget.drug.usage.isNotEmpty) ...[
                    _buildInfoSection(
                      'بەکارهێنان',
                      widget.drug.usage,
                      Icons.medical_services,
                      themeProvider.isDarkMode 
                        ? Colors.green.shade300 
                        : Colors.green.shade700,
                      themeProvider,
                    ),
                    const SizedBox(height: 16),
                  ],
                  // 6. Side Effect
                  if (widget.drug.sideEffect.isNotEmpty) ...[
                    _buildInfoSection(
                      'کاریگەری لاوەکی',
                      widget.drug.sideEffect,
                      Icons.warning_amber,
                      themeProvider.isDarkMode 
                        ? Colors.orange.shade300 
                        : Colors.orange.shade700,
                      themeProvider,
                    ),
                    const SizedBox(height: 16),
                  ],
                  // 7. Contraindications
                  if (widget.drug.contraindications.isNotEmpty) ...[
                    _buildInfoSection(
                      'ئەو حاڵەتانەی کە نابێت بەکاربهێنرێت',
                      widget.drug.contraindications,
                      Icons.block,
                      themeProvider.isDarkMode 
                        ? Colors.pink.shade300 
                        : Colors.pink.shade700,
                      themeProvider,
                    ),
                    const SizedBox(height: 16),
                  ],
                  // 8. Drug Interactions
                  if (widget.drug.drugInteractions.isNotEmpty) ...[  
                    _buildInfoSection(
                      'ئەو دەرمانانەی نابێت لەگەڵی بەکاربهێنرێت',
                      widget.drug.drugInteractions,
                      Icons.warning_rounded,
                      themeProvider.isDarkMode 
                        ? Colors.red.shade300 
                        : Colors.red.shade700,
                      themeProvider,
                    ),
                    const SizedBox(height: 16),
                  ],
                  // 9. Withdrawal Times
                  if (widget.drug.withdrawalTimes.isNotEmpty) ...[  
                    _buildInfoSection(
                      'کاتی پێویست بۆ نەمانی کاریگەری ',
                      widget.drug.withdrawalTimes,
                      Icons.schedule,
                      themeProvider.isDarkMode 
                        ? Colors.indigo.shade300 
                        : Colors.indigo.shade700,
                      themeProvider,
                    ),
                    const SizedBox(height: 16),
                  ],
                  // 10. Species Dosages
                  if (widget.drug.speciesDosages.isNotEmpty) ...[  
                    _buildInfoSection(
                      'دۆزی دەرمان بەپێی ئاژەڵەکان',
                      widget.drug.speciesDosages,
                      Icons.pets,
                      themeProvider.isDarkMode 
                        ? Colors.teal.shade300 
                        : Colors.teal.shade700,
                      themeProvider,
                    ),
                    const SizedBox(height: 16),
                  ],
                  // 11. Other Info
                  if (widget.drug.otherInfo.isNotEmpty) ...[  
                    _buildInfoSection(
                      'زانیاری زیاتر',
                      widget.drug.otherInfo,
                      Icons.info,
                      themeProvider.isDarkMode 
                        ? Colors.lightBlue.shade300 
                        : Colors.lightBlue.shade700,
                      themeProvider,
                    ),
                    const SizedBox(height: 16),
                  ],
                  // 12. Kurdish (if available)
                  if (widget.drug.kurdish.isNotEmpty)
                    _buildInfoSection(
                      'کوردی',
                      widget.drug.kurdish,
                      Icons.language,
                      themeProvider.isDarkMode 
                        ? Colors.deepPurple.shade300 
                        : Colors.deepPurple.shade700,
                      themeProvider,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required String label,
    required ThemeProvider themeProvider,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon, 
              color: Colors.white, 
              size: 24
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(
    String title, 
    String content, 
    IconData icon, 
    Color color,
    ThemeProvider themeProvider,
  ) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode 
          ? const Color(0xFF1E1E1E) 
          : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: themeProvider.isDarkMode 
          ? null 
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
      ),
      child: Column(
        crossAxisAlignment: languageProvider.isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Section title
          SizedBox(
            width: double.infinity,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: themeProvider.isDarkMode 
                    ? Colors.white 
                    : Colors.black87,
                  height: 1.4,
                  fontFamily: 'Inter',
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Separator line under title
          Container(
            width: double.infinity,
            height: 1,
            color: themeProvider.isDarkMode 
              ? Colors.grey[600] 
              : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          // Section content
          SizedBox(
            width: double.infinity,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                content,
                style: TextStyle(
                  fontSize: 16,
                  color: themeProvider.isDarkMode 
                    ? Colors.grey[300] 
                    : Colors.black87,
                  height: 1.6,
                  fontFamily: 'Inter',
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
