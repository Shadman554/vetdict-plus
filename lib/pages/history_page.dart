import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/history_item.dart';
import '../providers/history_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import 'package:intl/intl.dart';
import '../models/drug.dart';
import '../models/disease.dart';
import '../models/word.dart';
import 'package:vetstan/utils/page_transition.dart';
import 'drug_details_page.dart';
import 'disease_details_page.dart';
import 'terminology_details_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> with SingleTickerProviderStateMixin {
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

  List<HistoryItem> _getFilteredItems(String type) {
    final historyProvider = Provider.of<HistoryProvider>(context);
    return historyProvider.historyItems.where((item) => item.type == type).toList();
  }

  void _navigateToDetails(BuildContext context, HistoryItem item) {
    // If we have the complete data object, use it directly like favorites page
    if (item.data != null) {
      Widget? detailsPage;
      switch (item.type) {
        case 'drug':
          detailsPage = DrugDetailsPage(drug: item.data);
          break;
        case 'disease':
          detailsPage = DiseaseDetailsPage(disease: item.data);
          break;
        case 'terminology':
          detailsPage = TerminologyDetailsPage(terminology: item.data);
          break;
      }
      
      if (detailsPage != null) {
        Navigator.push(
          context,
          createRoute(detailsPage),
        );
      }
      return;
    }

    // Fallback for old history items without complete data
    if (item.type == 'drug') {
      if (!context.mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => DrugDetailsPage(
          drug: Drug(
            id: item.title,
            name: item.title,
            description: item.description.isNotEmpty ? item.description : 'No additional information available from history.',
            kurdish: '',
            category: '',
            otherInfo: item.description.isNotEmpty ? 'Viewed from history on ${DateFormat('MMM dd, yyyy').format(item.timestamp)}' : '',
            sideEffect: '',
            usage: '',
            drugClass: '',
            imageUrl: '',
          ),
        ),
      ));
    } else if (item.type == 'disease') {
      if (!context.mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => DiseaseDetailsPage(
          disease: Disease(
            id: item.title,
            name: item.title,
            cause: '',
            control: '',
            kurdish: '',
            symptoms: item.description.isNotEmpty ? item.description : 'No additional information available from history.',
            category: '',
            imageUrl: '',
          ),
        ),
      ));
    } else if (item.type == 'terminology') {
      if (!context.mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => TerminologyDetailsPage(
          terminology: Word(
            id: item.title,
            name: item.title,
            kurdish: '',
            arabic: '',
            description: item.description.isNotEmpty ? item.description : 'No additional information available from history.',
          ),
        ),
      ));
    }
  }

  Future<void> _showClearHistoryDialog() async {
    final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: languageProvider.textDirection,
          child: AlertDialog(
            backgroundColor: themeProvider.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            title: Text(
              'پاککردنەوەی مێژوو',
              style: TextStyle(
                color: themeProvider.theme.colorScheme.onSurface,
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: languageProvider.isRTL ? TextAlign.right : TextAlign.left,
            ),
            content: Text(
              'دڵنیایت لە پاککردنەوەی هەموو مێژووەکە؟',
              style: TextStyle(
                color: themeProvider.theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontFamily: 'Inter',
                fontSize: 16,
              ),
              textAlign: languageProvider.isRTL ? TextAlign.right : TextAlign.left,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'نەخێر',
                  style: TextStyle(
                    color: themeProvider.theme.colorScheme.primary,
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  historyProvider.clearHistory();
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Directionality(
                        textDirection: languageProvider.textDirection,
                        child: Text(
                          'مێژوو پاک کرایەوە',
                          style: TextStyle(
                            color: themeProvider.theme.colorScheme.onSurface,
                            fontFamily: 'Inter',
                            fontSize: 16,
                          ),
                          textAlign: languageProvider.isRTL ? TextAlign.right : TextAlign.left,
                        ),
                      ),
                      backgroundColor: themeProvider.theme.colorScheme.primary,
                    ),
                  );
                },
                child: Text(
                  'بەڵێ',
                  style: TextStyle(
                    color: themeProvider.theme.colorScheme.primary,
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryList(String type) {
    final items = _getFilteredItems(type);
    final themeProvider = Provider.of<ThemeProvider>(context);
    Provider.of<LanguageProvider>(context);

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 80,
              color: themeProvider.isDarkMode ? Colors.grey[700] : Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'هیچ مێژووی ${type.toLowerCase() == 'drug' ? 'دەرمان' : type.toLowerCase() == 'disease' ? 'نەخۆشی' : 'زاراوە'} نییە',
              style: TextStyle(
                color: themeProvider.theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 18,
              ),
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
        final formattedTime = DateFormat('HH:mm').format(item.timestamp);
        final formattedDate = DateFormat('MMM d, yyyy').format(item.timestamp);

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
                onTap: () => _navigateToDetails(context, item),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: themeProvider.isDarkMode
                                  ? themeProvider.theme.colorScheme.primary.withValues(alpha: 0.2)
                                  : themeProvider.theme.colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              type == 'drug'
                                  ? Icons.medication_rounded
                                  : type == 'disease'
                                      ? Icons.sick_rounded
                                      : Icons.book_rounded,
                              color: themeProvider.theme.colorScheme.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: themeProvider.theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.description,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: themeProvider.theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 13,
                              color: themeProvider.theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: themeProvider.isDarkMode
                                  ? Colors.grey[800]
                                  : themeProvider.theme.colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              formattedTime,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: themeProvider.theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ],
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: themeProvider.theme.appBarTheme.backgroundColor,
        title: Text(
          'مێژوو',
          style: themeProvider.theme.appBarTheme.titleTextStyle?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              decoration: BoxDecoration(
                color: themeProvider.theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: _showClearHistoryDialog,
                color: themeProvider.theme.colorScheme.primary,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
                iconSize: 24,
              ),
            ),
          ),
        ],
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
                textDirection: Provider.of<LanguageProvider>(context).textDirection,
                child: const Text(
                  'دەرمانەکان',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
            Tab(
              child: Directionality(
                textDirection: Provider.of<LanguageProvider>(context).textDirection,
                child: const Text(
                  'نەخۆشییەکان',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
            Tab(
              child: Directionality(
                textDirection: Provider.of<LanguageProvider>(context).textDirection,
                child: const Text(
                  'زاراوەکان',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHistoryList('drug'),
          _buildHistoryList('disease'),
          _buildHistoryList('terminology'),
        ],
      ),
    );
  }
}
