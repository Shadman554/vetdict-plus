import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../providers/theme_provider.dart';
import '../services/first_launch_service.dart';

class IntroductionPage extends StatefulWidget {
  const IntroductionPage({Key? key}) : super(key: key);

  @override
  State<IntroductionPage> createState() => _IntroductionPageState();
}

class _IntroductionPageState extends State<IntroductionPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<IntroductionItem> _introItems = [
    IntroductionItem(
      icon: Icons.medical_services,
      imagePath: 'assets/images/swibe/first image.png',
      title: 'بەخێربێن بۆ +VET DICT',
      // Fixed spacing, punctuation, and streamlined the list of sections.
      description: 'ئەم فەرهەنگە تایبەتە بە فێرخوازان و پزیشکانی ڤێتێرنەری. لە چەند بەشێکی سەرەکی پێکهاتووە وەک: زاراوەزانی، دەرمانزانی، نەخۆشیزانی، پشکنینی تاقیگەیی و کتێبخانە. لێرە دەتوانیت زانیاری تەواوت دەستبکەوێت لەسەر هەر بابەتێک کە بتەوێت.',
      color: const Color(0xFF1A3460),
    ),
    IntroductionItem(
      icon: Icons.book,
      imagePath: 'assets/images/swibe/second image.png',
      title: 'زاراوەزانی',
      // Removed redundant "thousand" after the number and improved flow.
      description: 'ئەم بەشە پێکهاتووە لە هەزاران وشەی زانستی لەگەڵ واتاکانیان بە هەرسێ زمانی: ئینگلیزی، کوردی و عەرەبی. جگە لە زاراوە پزیشکییەکان، ئەم فەرهەنگە ٢٠,٠٠٠ زاراوەی گشتی لەخۆدەگرێت.',
      color: const Color(0xFF059669),
    ),
    IntroductionItem(
      icon: Icons.healing,
      imagePath: 'assets/images/swibe/third image.png',
      title: 'نەخۆشیزانی و دەرمانزانی',
      // Corrected "ba wrdi" spacing and sentence structure.
      description: 'لەم بەشەدا بە وردی باسی هۆکار و نیشانەکانی نەخۆشی کراوە، لەگەڵ جۆر و شێوازی کارکردن و بەکارهێنانی دەرمانەکان بە تەواوی.',
      color: const Color(0xFFDC2626),
    ),
    IntroductionItem(
      icon: Icons.library_books,
      imagePath: 'assets/images/swibe/fourth image.png',
      title: 'کتێبخانە',
      // Fixed punctuation placement.
      description: 'یەکێکی دیکەیە لە بەشە گرنگەکانی فەرهەنگەکە، تێیدا پەرتووک بە هەرسێ زمانی ئینگلیزی، کوردی و عەرەبی بەردەستە.',
      color: const Color(0xFF7C3AED),
    ),
    IntroductionItem(
      icon: Icons.science,
      imagePath: 'assets/images/swibe/fifth image.png',
      title: 'ئامێری پزیشکی و تێستەکان',
      // Fixed "ka la kati" spacing and rephrased for clarity.
      description: 'بە وردی باسی ئەو ئامێرە باوانە کراوە کە لە کاتی نەشتەرگەریدا بەکاردێن، هەروەها ئەو پشکنینانەی کە ڕۆژانە ئەنجام دەدرێن بە تەواوی شیکراونەتەوە.',
      color: const Color(0xFFEA580C),
    ),
    IntroductionItem(
      icon: Icons.favorite,
      imagePath: 'assets/images/swibe/sixth image.png',
      title: 'دڵخوازەکان و مێژوو',
      // Clarified the action of saving/bookmarking.
      description: 'لەم بەشەدا هەموو ئەو زانیاریانە دەبینیتەوە کە پاشەکەوتت کردوون یان پێشتر بەکارت هێناون.',
      color: const Color(0xFFDB2777),
    ),
    IntroductionItem(
      icon: Icons.favorite,
      imagePath: 'assets/images/swibe/seventh image.png',
      title: 'تاقیکردنەوە',
      // Fixed spelling of "taqikrdnawa" and changed "intelligence" to "scientific level".
      description: 'یەکێکی تر لە تایبەتمەندییە بەهێزەکانی ئەم فەرهەنگە ئەوەیە دەتوانیت تاقیکردنەوە لەسەر ئامێر و تێستەکان بکەیت. دەتوانیت خاڵ بەدەست بهێنیت و ئاستی زانستی خۆت لە بوارەکەدا بسەلمێنیت.',
      color: const Color(0xFFDB2777),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.isDarkMode
          ? themeProvider.theme.scaffoldBackgroundColor
          : Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: themeProvider.isDarkMode
            ? themeProvider.theme.scaffoldBackgroundColor
            : Colors.white,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text(
          'VET DICT+',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: themeProvider.isDarkMode ? Colors.white : const Color(0xFF1E293B),
        ),
        iconTheme: IconThemeData(color: themeProvider.theme.colorScheme.primary),
        actions: [
          // Use same transition as back button
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              await FirstLaunchService.markIntroductionAsSeen();
              if (!mounted) return;
              
              if (navigator.canPop()) {
                navigator.pop();
              } else {
                navigator.pushReplacementNamed('/home');
              }
            },
            child: Directionality(
              textDirection: languageProvider.textDirection,
              child: Text(
                'تەواوکردن',
                style: TextStyle(
                  color: themeProvider.theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'NRT',
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header moved to AppBar

            // Page indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _introItems.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? themeProvider.theme.colorScheme.primary
                          : themeProvider.theme.colorScheme.primary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _introItems.length,
                itemBuilder: (context, index) {
                  final item = _introItems[index];
                  final screenHeight = MediaQuery.of(context).size.height;
                  final imageHeight = (screenHeight * 0.3).clamp(150.0, 300.0);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),

                        // Image or Icon
                        item.imagePath != null
                            ? Container(
                                height: imageHeight,
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 12),
                                child: item.imagePath!.endsWith('.svg')
                                    ? SvgPicture.asset(
                                        item.imagePath!,
                                        fit: BoxFit.contain,
                                      )
                                    : Image.asset(
                                        item.imagePath!,
                                        fit: BoxFit.contain,
                                      ),
                              )
                            : Container(
                                width: 100,
                                height: 100,
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      item.color,
                                      item.color.withValues(alpha: 0.7),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: item.color.withValues(alpha: 0.3),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  item.icon,
                                  size: 50,
                                  color: Colors.white,
                                ),
                              ),

                        // Scrollable text content
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              children: [
                                const SizedBox(height: 16),

                                // Title
                                Directionality(
                                  textDirection: languageProvider.textDirection,
                                  child: Text(
                                    item.title,
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: themeProvider.isDarkMode
                                          ? Colors.white
                                          : const Color(0xFF1E293B),
                                      fontFamily: 'NRT',
                                    ),
                                    textAlign: languageProvider.isRTL
                                        ? TextAlign.right
                                        : TextAlign.left,
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Description
                                Directionality(
                                  textDirection: languageProvider.textDirection,
                                  child: Text(
                                    item.description,
                                    style: TextStyle(
                                      fontSize: 16,
                                      height: 1.6,
                                      color: themeProvider.isDarkMode
                                          ? Colors.white.withValues(alpha: 0.8)
                                          : const Color(0xFF64748B),
                                      fontFamily: 'NRT',
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Medical disclaimer on Diseases & Drugs slide (index 2)
                                if (index == 2)
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
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.info_outline,
                                          color: Color(0xFFD97706),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Directionality(
                                            textDirection: languageProvider.textDirection,
                                            child: Text(
                                              'ئاگاداری: زانیارییەکانی نەخۆشی و دەرمان تەنها بۆ مەبەستی فێربوون و پەروەردەیین. پێویستە پێش بەکارهێنانی هەر دەرمانێک ڕاوێژ بە پزیشکی پسپۆڕ بکرێت.',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                height: 1.5,
                                                color: Color(0xFF78350F),
                                                fontFamily: 'NRT',
                                              ),
                                              textAlign: languageProvider.isRTL ? TextAlign.right : TextAlign.left,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Previous button
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      style: TextButton.styleFrom(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      child: Directionality(
                        textDirection: languageProvider.textDirection,
                        child: Text(
                          'پێشوو',
                          style: TextStyle(
                            color: themeProvider.theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'NRT',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 80),

                  // Next/Finish button
                  ElevatedButton(
                    onPressed: () async {
                      if (_currentPage < _introItems.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        final navigator = Navigator.of(context);
                        await FirstLaunchService.markIntroductionAsSeen();
                        if (!mounted) return;
                        
                        if (navigator.canPop()) {
                          navigator.pop();
                        } else {
                          navigator.pushReplacementNamed('/home');
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeProvider.theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 4,
                      alignment: Alignment.center,
                    ),
                    child: Directionality(
                      textDirection: languageProvider.textDirection,
                      child: Text(
                        _currentPage < _introItems.length - 1 ? 'دواتر' : 'تەواوکردن',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontFamily: 'NRT',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class IntroductionItem {
  final IconData icon;
  final String? imagePath;
  final String title;
  final String description;
  final Color color;

  IntroductionItem({
    required this.icon,
    this.imagePath,
    required this.title,
    required this.description,
    required this.color,
  });
}
