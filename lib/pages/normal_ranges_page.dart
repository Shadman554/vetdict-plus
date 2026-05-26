import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../models/normal_range.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import '../services/api_service.dart';
import '../services/encrypted_cache_service.dart';
import '../services/connectivity_service.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../widgets/offline_banner.dart';
import '../widgets/offline_error_state.dart';

class NormalRangesPage extends StatefulWidget {
  const NormalRangesPage({Key? key}) : super(key: key);

  @override
  State<NormalRangesPage> createState() => _NormalRangesPageState();
}

class _NormalRangesPageState extends State<NormalRangesPage> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCategory;
  String? _selectedSpecies;
  String _searchQuery = '';
  List<NormalRange> _normalRanges = [];
  bool _isLoading = true;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _fetchNormalRanges();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchNormalRanges() async {
    final encCache = EncryptedCacheService();

    try {
      setState(() {
        _isLoading = true;
      });

      final bool online = await ConnectivityService.isOnline();
      if (mounted) setState(() => _isOffline = !online);

      if (online) {
        final apiService = ApiService();
        final ranges = await apiService.fetchAllNormalRanges();

        // Save to encrypted cache for offline use
        await encCache.saveNormalRanges(ranges.map((r) => r.toJson()).toList());

        setState(() {
          _normalRanges = ranges;
          _isLoading = false;
        });
      } else {
        // Offline: load from encrypted cache
        final cached = await encCache.loadNormalRanges();
        final ranges = cached.map((json) => NormalRange.fromJson(json)).toList();

        setState(() {
          _normalRanges = ranges;
          _isLoading = false;
        });
      }
    } catch (e) {
      // API failed — try encrypted cache as fallback
      if (kDebugMode) debugPrint('[NormalRanges] API failed, trying cache: $e');
      try {
        final cached = await encCache.loadNormalRanges();
        final ranges = cached.map((json) => NormalRange.fromJson(json)).toList();
        if (ranges.isNotEmpty) {
          setState(() {
            _normalRanges = ranges;
            _isLoading = false;
          });
          return;
        }
      } catch (_) {}

      setState(() {
        _isLoading = false;
      });
    }
  }

  // Group ranges by name and category
  Map<String, Map<String, List<NormalRange>>> get _groupedRanges {
    final Map<String, Map<String, List<NormalRange>>> grouped = {};
    
    for (final range in _normalRanges) {
      final key = '${range.name}::${range.category ?? ''}';
      if (!grouped.containsKey(key)) {
        grouped[key] = {};
      }
      final species = range.species ?? 'Unknown';
      if (!grouped[key]!.containsKey(species)) {
        grouped[key]![species] = [];
      }
      grouped[key]![species]!.add(range);
    }
    
    return grouped;
  }
  
  List<MapEntry<String, Map<String, List<NormalRange>>>> get _filteredRanges {
    return _groupedRanges.entries.where((entry) {
      if (entry.value.isEmpty || entry.value.values.first.isEmpty) return false;
      
      final firstRange = entry.value.values.first.first;
      final matchesSearch = _searchQuery.isEmpty ||
          firstRange.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (firstRange.notes?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      final matchesCategory = _selectedCategory == null ||
          firstRange.category?.toLowerCase() == _selectedCategory?.toLowerCase();
      final matchesSpecies = _selectedSpecies == null ||
          entry.value.keys.any((species) => 
              species.toLowerCase() == _selectedSpecies!.toLowerCase());
              
      return matchesSearch && matchesCategory && matchesSpecies;
    }).toList();
  }

  List<String> get _categories {
    final categories = _normalRanges
        .map((range) => range.category)
        .whereType<String>()
        .toSet()
        .toList();
    categories.sort();
    return categories;
  }

  List<String> get _speciesList {
    final species = _normalRanges
        .map((range) => range.species)
        .whereType<String>()
        .toSet()
        .toList();
    species.sort();
    return species;
  }
  

  // Helper method to build table header cells
  Widget _buildTableHeaderCell(String text, ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
          fontSize: 14,
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      ),
    );
  }
  
  // Helper method to build table cells
  Widget _buildTableCell(String text, ThemeProvider themeProvider, {bool isFirstColumn = false, bool isSingleValue = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
      alignment: isFirstColumn ? Alignment.centerLeft : Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
          fontSize: 14,
          fontWeight: isSingleValue ? FontWeight.bold : null,
        ),
        textAlign: isFirstColumn ? TextAlign.left : TextAlign.center,
        textDirection: TextDirection.ltr,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: isDarkMode
            ? themeProvider.theme.scaffoldBackgroundColor
            : Colors.grey[50],
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 4,
          surfaceTintColor: Colors.transparent,
          backgroundColor: isDarkMode
              ? themeProvider.theme.appBarTheme.backgroundColor
              : themeProvider.theme.colorScheme.primary,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: isDarkMode
                  ? themeProvider.theme.colorScheme.onSurface
                  : Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'پێوانە ئاساییەکان',
            style: TextStyle(
              color: isDarkMode
                  ? themeProvider.theme.colorScheme.onSurface
                  : Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            textDirection: TextDirection.ltr,
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                color: themeProvider.isDarkMode
                    ? const Color(0xFF2C2C2C)
                    : Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: themeProvider.isDarkMode
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Directionality(
                      textDirection: languageProvider.textDirection,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _searchQuery = value),
                        textDirection: languageProvider.textDirection,
                        style: TextStyle(
                          color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: 'گەڕان لە پێوانە ئاساییەکان...',
                          hintStyle: TextStyle(
                            color: themeProvider.isDarkMode
                                ? Colors.grey[600]
                                : Colors.grey[400],
                          ),
                          prefixIcon: languageProvider.isRTL ? null : Icon(
                            Icons.search,
                            color: themeProvider.isDarkMode
                                ? Colors.grey[600]
                                : Colors.grey[400],
                          ),
                          suffixIcon: languageProvider.isRTL ? Icon(
                            Icons.search,
                            color: themeProvider.isDarkMode
                                ? Colors.grey[600]
                                : Colors.grey[400],
                          ) : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    height: 24,
                    width: 1,
                    color: themeProvider.isDarkMode
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.grey.withValues(alpha: 0.2),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  Stack(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.filter_list,
                          color: themeProvider.isDarkMode
                              ? Colors.grey[600]
                              : Colors.grey[400],
                        ),
                        onPressed: () => _showFilterOptions(context),
                      ),
                      if (_selectedCategory != null || _selectedSpecies != null)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
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
        body: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            if (_isOffline) const OfflineBanner(),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: LoadingAnimationWidget.threeArchedCircle(
                        color: themeProvider.theme.colorScheme.primary,
                        size: 50,
                      ),
                    )
                  : _filteredRanges.isEmpty
                ? (_isOffline
                    ? OfflineErrorState(onRetry: _fetchNormalRanges)
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.balance,
                              size: 80,
                              color: themeProvider.isDarkMode
                                  ? Colors.grey[700]
                                  : Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'هیچ پێوانەیەکی ئاسایی نەدۆزرایەوە',
                              style: TextStyle(
                                color: themeProvider.isDarkMode
                                    ? Colors.grey[500]
                                    : Colors.grey[500],
                                fontSize: 18,
                              ),
                              textDirection: TextDirection.ltr,
                            ),
                          ],
                        ),
                      ))
                : RefreshIndicator(
                    onRefresh: _fetchNormalRanges,
                    child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredRanges.length,
                              itemBuilder: (context, index) {
                                final entry = _filteredRanges[index];
                                final firstRange = entry.value.values.first.first;
                                // Filter species entries based on selected species
                                final speciesEntries = _selectedSpecies == null
                                    ? entry.value.entries.toList()
                                    : entry.value.entries
                                        .where((e) => e.key.toLowerCase() == _selectedSpecies!.toLowerCase())
                                        .toList();
                                
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: themeProvider.isDarkMode
                                        ? const Color(0xFF1E1E1E)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: themeProvider.isDarkMode
                                        ? null
                                        : [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.05),
                                              blurRadius: 10,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                        child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Test name
                                          Text(
                                            firstRange.name,
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: themeProvider.isDarkMode
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                            textDirection: TextDirection.ltr,
                                          ),
                                          
                                          // Parameter and Category in one line
                                          if ((firstRange.parameter != null && firstRange.parameter!.isNotEmpty) ||
                                              (firstRange.category != null && firstRange.category!.isNotEmpty))
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                                              child: Text(
                                                [
                                                  if (firstRange.parameter != null && firstRange.parameter!.isNotEmpty)
                                                    firstRange.parameter!,
                                                  if (firstRange.category != null && firstRange.category!.isNotEmpty)
                                                    firstRange.category!,
                                                ].join(' • '),
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: themeProvider.isDarkMode
                                                      ? Colors.grey[500]
                                                      : Colors.grey[600],
                                                ),
                                                textDirection: TextDirection.ltr,
                                              ),
                                            ),
                                          
                                          // Species and ranges table
                                          Directionality(
                                            textDirection: TextDirection.ltr,
                                            child: Container(
                                              width: double.infinity,
                                              margin: const EdgeInsets.only(top: 8),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: themeProvider.isDarkMode
                                                      ? Colors.grey[800]!
                                                      : Colors.grey[300]!,
                                                  width: 1,
                                                ),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Table(
                                                columnWidths: const {
                                                  0: FlexColumnWidth(1.5),
                                                  1: FlexColumnWidth(1),
                                                  2: FlexColumnWidth(1),
                                                  3: FlexColumnWidth(1.2),
                                                },
                                                border: TableBorder(
                                                  horizontalInside: BorderSide(
                                                    color: themeProvider.isDarkMode
                                                        ? Colors.grey[800]!
                                                        : Colors.grey[200]!,
                                                    width: 1,
                                                  ),
                                                ),
                                                children: [
                                                  // Table header with unit
                                                  TableRow(
                                                    decoration: BoxDecoration(
                                                      color: themeProvider.isDarkMode
                                                          ? Colors.grey[900]!
                                                          : Colors.grey[100]!,
                                                      borderRadius: const BorderRadius.only(
                                                        topLeft: Radius.circular(7),
                                                        topRight: Radius.circular(7),
                                                      ),
                                                    ),
                                                    children: [
                                                      _buildTableHeaderCell(
                                                        'جۆر', 
                                                        themeProvider,
                                                      ),
                                                      _buildTableHeaderCell(
                                                        firstRange.minValue.isNotEmpty && !firstRange.minValue.startsWith('<') && !firstRange.minValue.startsWith('>')
                                                            ? 'کەمترین${firstRange.unit.isNotEmpty ? '\n(${firstRange.unit})' : ''}'
                                                            : 'نرخ',
                                                        themeProvider,
                                                      ),
                                                      if (firstRange.minValue.isNotEmpty && firstRange.maxValue.isNotEmpty && 
                                                          !firstRange.minValue.startsWith('<') && !firstRange.minValue.startsWith('>') &&
                                                          !firstRange.maxValue.startsWith('<') && !firstRange.maxValue.startsWith('>'))
                                                        _buildTableHeaderCell(
                                                          'زۆرترین${firstRange.unit.isNotEmpty ? '\n(${firstRange.unit})' : ''}',
                                                          themeProvider,
                                                        )
                                                      else
                                                        _buildTableHeaderCell('', themeProvider),
                                                      _buildTableHeaderCell(
                                                        'Panic Range',
                                                        themeProvider,
                                                      ),
                                                    ],
                                                  ),
                                                  // Table rows for each species
                                                  ...speciesEntries.expand((speciesEntry) {
                                                    final species = speciesEntry.key;
                                                    final ranges = speciesEntry.value;
                                                    return ranges.map((range) {
                                                      // Check if we should show a single value instead of min/max
                                                      final showSingleValue = range.minValue.isEmpty || range.maxValue.isEmpty || 
                                                                        range.minValue.startsWith('<') || range.minValue.startsWith('>') ||
                                                                        range.maxValue.startsWith('<') || range.maxValue.startsWith('>');
                                                      
                                                      return TableRow(
                                                        decoration: BoxDecoration(
                                                          color: themeProvider.isDarkMode
                                                              ? const Color(0xFF1E1E1E)
                                                              : Colors.white,
                                                        ),
                                                        children: [
                                                          _buildTableCell(species, themeProvider, isFirstColumn: true),
                                                          if (showSingleValue)
                                                            _buildTableCell(
                                                              range.minValue.isNotEmpty ? range.minValue : range.maxValue, 
                                                              themeProvider,
                                                              isSingleValue: true
                                                            )
                                                          else
                                                            _buildTableCell(range.minValue, themeProvider),
                                                          if (!showSingleValue)
                                                            _buildTableCell(range.maxValue, themeProvider)
                                                          else
                                                            Container(), // Empty cell when showing single value
                                                          _buildTableCell(
                                                            ((range.panicLow != null && range.panicLow!.isNotEmpty) || 
                                                             (range.panicHigh != null && range.panicHigh!.isNotEmpty))
                                                                ? '${range.panicLow ?? '-'} - ${range.panicHigh ?? '-'}'
                                                                : '-',
                                                            themeProvider,
                                                          ),
                                                        ],
                                                      );
                                                    });
                                                  }).toList(),
                                                ],
                                              ),
                                            ),
                                          ),
                                          
                                          // Additional info (notes, reference)
                                          if ((firstRange.notes != null && firstRange.notes!.isNotEmpty) ||
                                              (firstRange.reference != null && firstRange.reference!.isNotEmpty))
                                            Padding(
                                              padding: const EdgeInsets.only(top: 12.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  if (firstRange.notes != null && firstRange.notes!.isNotEmpty)
                                                    Padding(
                                                      padding: const EdgeInsets.only(bottom: 4.0),
                                                      child: Text(
                                                        'Note: ${firstRange.notes}',
                                                        style: TextStyle(
                                                          color: themeProvider.isDarkMode
                                                              ? Colors.grey[500]
                                                              : Colors.grey[600],
                                                          fontSize: 12,
                                                        ),
                                                        textDirection: TextDirection.ltr,
                                                      ),
                                                    ),
                                                  if (firstRange.reference != null && firstRange.reference!.isNotEmpty)
                                                    Text(
                                                      'Reference: ${firstRange.reference}',
                                                      style: TextStyle(
                                                        color: themeProvider.isDarkMode
                                                            ? Colors.grey[500]
                                                            : Colors.grey[600],
                                                        fontSize: 12,
                                                      ),
                                                      textDirection: TextDirection.ltr,
                                                    ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                    ),
                ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterOptions(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text(
                      'فلتەرکردن',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                  
                  const Divider(height: 1),
                  
                  // Scrollable content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category filter section
                          Text(
                            'پۆلەکان',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                            textDirection: TextDirection.ltr,
                          ),
                          const SizedBox(height: 12),
                          
                          // Category chips
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildFilterChip(
                                'هەموو',
                                Icons.apps_rounded,
                                themeProvider.theme.colorScheme.primary,
                                _selectedCategory == null,
                                () {
                                  setModalState(() => _selectedCategory = null);
                                },
                                isDarkMode,
                              ),
                              ..._categories.map((category) => _buildFilterChip(
                                    category,
                                    Icons.label_rounded,
                                    themeProvider.theme.colorScheme.primary,
                                    _selectedCategory == category,
                                    () {
                                      setModalState(() => _selectedCategory = category);
                                    },
                                    isDarkMode,
                                  )),
                            ],
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Species filter section
                          Text(
                            'جۆری ئاژەڵ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                            textDirection: TextDirection.ltr,
                          ),
                          const SizedBox(height: 12),
                          
                          // Species chips
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildFilterChip(
                                'هەموو',
                                Icons.apps_rounded,
                                themeProvider.theme.colorScheme.primary,
                                _selectedSpecies == null,
                                () {
                                  setModalState(() => _selectedSpecies = null);
                                },
                                isDarkMode,
                              ),
                              ..._speciesList.map((species) => _buildFilterChip(
                                    species,
                                    Icons.pets_outlined,
                                    themeProvider.theme.colorScheme.primary,
                                    _selectedSpecies == species,
                                    () {
                                      setModalState(() => _selectedSpecies = species);
                                    },
                                    isDarkMode,
                                  )),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Bottom action buttons
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[100],
                      border: Border(
                        top: BorderSide(
                          color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _selectedCategory = null;
                                _selectedSpecies = null;
                              });
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('ڕێکخستنەوە'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(
                                color: isDarkMode ? Colors.grey[700]! : Colors.grey[400]!,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {}); // Trigger rebuild of main page
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: Text(
                              'جێبەجێکردن (${_filteredRanges.length})',
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: themeProvider.theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  
  Widget _buildFilterChip(
    String label,
    IconData icon,
    Color color,
    bool isSelected,
    VoidCallback onTap,
    bool isDarkMode,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? color
              : isDarkMode
                  ? Colors.grey[850]
                  : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? color
                : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : isDarkMode
                      ? Colors.grey[400]
                      : Colors.grey[700],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : isDarkMode
                        ? Colors.grey[300]
                        : Colors.grey[800],
              ),
              textDirection: TextDirection.ltr,
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.check_circle,
                size: 14,
                color: Colors.white,
              ),
            ],
          ],
        ),
      ),
    );
  }
}