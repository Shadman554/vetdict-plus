import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/language_provider.dart';
import 'package:vetstan/utils/page_transition.dart';
import 'drug_details_page.dart';
import 'disease_details_page.dart';
import 'terminology_details_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({Key? key}) : super(key: key);

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildFavoritesList(List<dynamic> items, String type) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final favoritesProvider = Provider.of<FavoritesProvider>(context);

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_outline,
              size: 80,
              color: themeProvider.isDarkMode ? Colors.grey[700] : Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'هیچ ${type.toLowerCase() == 'drug' ? 'دەرمانی' : type.toLowerCase() == 'disease' ? 'نەخۆشیی' : 'زاراوەی'} دڵخواز نییە',
              style: TextStyle(
                color: themeProvider.theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 18,
              ),
              textDirection: languageProvider.textDirection,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isFavorite = favoritesProvider.isFavorite(item);
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            decoration: BoxDecoration(
              color: themeProvider.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
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
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Widget? detailsPage;
                  switch (type) {
                    case 'drug':
                      detailsPage = DrugDetailsPage(drug: item);
                      break;
                    case 'disease':
                      detailsPage = DiseaseDetailsPage(disease: item);
                      break;
                    case 'terminology':
                      detailsPage = TerminologyDetailsPage(terminology: item);
                      break;
                  }
                  
                  if (detailsPage != null) {
                    Navigator.push(
                      context,
                      createRoute(detailsPage),
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: themeProvider.theme.colorScheme.primary.withValues(
                            alpha: themeProvider.isDarkMode ? 0.2 : 0.1
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getIconForType(type),
                          color: themeProvider.theme.colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          item.name ?? '',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: themeProvider.theme.colorScheme.onSurface,
                          ),
                          textDirection: languageProvider.textDirection,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isFavorite ? Icons.bookmark : Icons.bookmark_border,
                          color: isFavorite
                              ? (themeProvider.isDarkMode
                                  ? const Color(0xFF4A7EB5)
                                  : const Color(0xFF1A3460))
                              : (themeProvider.isDarkMode
                                  ? Colors.grey[600]
                                  : Colors.grey[400]),
                        ),
                        onPressed: () {
                          if (isFavorite) {
                            favoritesProvider.removeFavorite(item);
                          } else {
                            favoritesProvider.addFavorite(item);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'drug':
        return Icons.medication_rounded;
      case 'disease':
        return Icons.sick_rounded;
      case 'terminology':
        return Icons.book_rounded;
      default:
        return Icons.favorite;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final favoritesProvider = Provider.of<FavoritesProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);

    final drugFavorites = favoritesProvider.getDrugFavorites();
    final diseaseFavorites = favoritesProvider.getDiseaseFavorites();
    final wordFavorites = favoritesProvider.getWordFavorites();

    return Scaffold(
      backgroundColor: themeProvider.isDarkMode 
          ? themeProvider.theme.scaffoldBackgroundColor 
          : Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: themeProvider.theme.appBarTheme.backgroundColor,
        title: Text(
          'دڵخوازەکان',
          style: themeProvider.theme.appBarTheme.titleTextStyle?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: themeProvider.theme.colorScheme.onSurface,
          unselectedLabelColor: themeProvider.theme.colorScheme.onSurface.withValues(alpha: 0.7),
          indicatorColor: themeProvider.theme.colorScheme.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
          tabs: [
            Tab(
              child: Directionality(
                textDirection: languageProvider.textDirection,
                child: const Text('دەرمانەکان'),
              ),
            ),
            Tab(
              child: Directionality(
                textDirection: languageProvider.textDirection,
                child: const Text('نەخۆشییەکان'),
              ),
            ),
            Tab(
              child: Directionality(
                textDirection: languageProvider.textDirection,
                child: const Text('زاراوەکان'),
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFavoritesList(drugFavorites, 'drug'),
          _buildFavoritesList(diseaseFavorites, 'disease'),
          _buildFavoritesList(wordFavorites, 'terminology'),
        ],
      ),
    );
  }
}