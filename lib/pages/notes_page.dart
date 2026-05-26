import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../models/note.dart';
import '../services/sync_service.dart';
import '../services/encrypted_cache_service.dart';
import '../services/connectivity_service.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import '../widgets/offline_banner.dart';
import '../widgets/offline_error_state.dart';
import '../providers/history_provider.dart';
import 'note_details_page.dart';
import 'package:vetstan/utils/page_transition.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({Key? key}) : super(key: key);

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> with SingleTickerProviderStateMixin {
  static final SyncService _syncService = SyncService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<Note> _notes = [];
  List<Note> _filteredNotes = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _isOffline = false;

  bool _isValidHttpUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    try {
      final uri = Uri.parse(url.trim());
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  void _onNoteTap(BuildContext context, Note note) {
    try {
      // Add to history
      context.read<HistoryProvider>().addToHistory(
        note.name,
        'note',
        'Viewed note details'
      );

      // Navigate to note details with custom transition
      Navigator.push(
        context,
        createRoute(NoteDetailsPage(note: note)),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[NotesPage] Error navigating to note details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening note: $e')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _checkForUpdates();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final encCache = EncryptedCacheService();

    try {
      final bool online = await ConnectivityService.isOnline();

      if (mounted) setState(() => _isOffline = !online);

      if (online) {
        if (kDebugMode) debugPrint('[NotesPage] Loading notes from API...');
        final notesList = await _syncService.loadCategoryData<Note>('notes');
        final filtered = notesList.where((note) => note.name.isNotEmpty).toList();

        // Save to encrypted cache for offline use
        await encCache.saveNotes(filtered.map((n) => n.toJson()).toList());

        if (!mounted) return;
        setState(() {
          _notes = filtered;
          _filteredNotes = _notes;
          _isLoading = false;
        });
        if (kDebugMode) debugPrint('[NotesPage] Loaded ${_notes.length} notes from API');
      } else {
        // Offline: load from encrypted cache
        if (kDebugMode) debugPrint('[NotesPage] Offline, loading from encrypted cache...');
        final cached = await encCache.loadNotes();
        final notes = cached.map((json) => Note.fromJson(json)).where((n) => n.name.isNotEmpty).toList();

        if (!mounted) return;
        if (notes.isNotEmpty) {
          setState(() {
            _notes = notes;
            _filteredNotes = _notes;
            _isLoading = false;
          });
          if (kDebugMode) debugPrint('[NotesPage] Loaded ${notes.length} notes from encrypted cache');
        } else {
          setState(() {
            _isLoading = false;
            _hasError = false;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[NotesPage] Error loading notes, trying cache: $e');
      try {
        final cached = await encCache.loadNotes();
        final notes = cached.map((json) => Note.fromJson(json)).where((n) => n.name.isNotEmpty).toList();
        if (!mounted) return;
        if (notes.isNotEmpty) {
          setState(() {
            _notes = notes;
            _filteredNotes = _notes;
            _isLoading = false;
          });
          return;
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = !_isOffline;
        });
      }
    }
  }

  Future<void> _checkForUpdates() async {
    try {
      // For notes we don't have an incremental update API yet, so we force a full sync
      await _syncService.forceCategorySync('notes');
      if (!mounted) return;
      
      final updatedData = await _syncService.loadCategoryData<Note>('notes');
      if (!mounted) return;
      
      setState(() {
        _notes = updatedData.where((note) => note.name.isNotEmpty).toList();
        _filterNotes(_searchController.text);
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[NotesPage] Error checking for updates: $e');
      // Don't show error for background updates
    }
  }

  void _filterNotes(String query) {
    if (!mounted) return;
    
    setState(() {
      if (query.isEmpty) {
        _filteredNotes = _notes;
      } else {
        final queryLower = query.toLowerCase().trim();
        _filteredNotes = _notes.where((note) {
          return note.name.toLowerCase().contains(queryLower);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LanguageProvider>(
      builder: (context, themeProvider, languageProvider, _) {
        return Scaffold(
          backgroundColor: themeProvider.isDarkMode
              ? themeProvider.theme.scaffoldBackgroundColor
              : Colors.grey[50],
          appBar: _buildAppBar(themeProvider, languageProvider),
          body: _buildBody(themeProvider, languageProvider),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
  ) {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 4,
      surfaceTintColor: Colors.transparent,
      backgroundColor: themeProvider.isDarkMode
          ? themeProvider.theme.appBarTheme.backgroundColor
          : themeProvider.theme.colorScheme.primary,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: themeProvider.isDarkMode
              ? themeProvider.theme.colorScheme.onSurface
              : Colors.white,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Directionality(
        textDirection: languageProvider.textDirection,
        child: Text(
          'تێبینییەکان',
          style: TextStyle(
            color: themeProvider.isDarkMode
                ? themeProvider.theme.colorScheme.onSurface
                : Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
      ),
      centerTitle: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: _buildSearchBar(themeProvider, languageProvider),
      ),
    );
  }

  Widget _buildSearchBar(
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
  ) {
    return Container(
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
      child: Directionality(
        textDirection: languageProvider.textDirection,
        child: TextField(
          controller: _searchController,
          onChanged: _filterNotes,
          style: TextStyle(
            color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
            fontFamily: 'Inter',
          ),
          decoration: InputDecoration(
            hintText: 'گەڕان بە تێبینی...',
            hintStyle: TextStyle(
              color: themeProvider.isDarkMode
                  ? Colors.grey[600]
                  : Colors.grey[400],
              fontFamily: 'Inter',
            ),
            prefixIcon: !languageProvider.isRTL
                ? Icon(
                    Icons.search,
                    color: themeProvider.isDarkMode
                        ? Colors.grey[600]
                        : Colors.grey[400],
                  )
                : null,
            suffixIcon: languageProvider.isRTL
                ? Icon(
                    Icons.search,
                    color: themeProvider.isDarkMode
                        ? Colors.grey[600]
                        : Colors.grey[400],
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
  ) {
    if (_isOffline && !_isLoading) {
      return Column(
        children: [
          const OfflineBanner(),
          Expanded(child: _buildBodyContent(themeProvider, languageProvider)),
        ],
      );
    }
    return _buildBodyContent(themeProvider, languageProvider);
  }

  Widget _buildBodyContent(
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
  ) {
    if (_isLoading) {
      return Center(
        child: LoadingAnimationWidget.threeArchedCircle(
          color: themeProvider.theme.colorScheme.primary,
          size: 50,
        ),
      );
    }

    if (_hasError) {
      return _buildErrorState(themeProvider, languageProvider);
    }

    if (_filteredNotes.isEmpty && _notes.isNotEmpty) {
      return _buildNoResultsState(themeProvider, languageProvider);
    }

    if (_filteredNotes.isEmpty) {
      return _buildEmptyState(themeProvider, languageProvider);
    }

    return RefreshIndicator(
      onRefresh: _loadNotes,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          physics: const BouncingScrollPhysics(),
        ),
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          itemCount: _filteredNotes.length,
          itemBuilder: (context, index) {
            final note = _filteredNotes[index];
            final noteNumber = index + 1;
            return _buildNoteItem(
              context,
              note,
              noteNumber,
              themeProvider,
              languageProvider,
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorState(
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: Colors.red[400]),
            const SizedBox(height: 16),
            Directionality(
              textDirection: languageProvider.textDirection,
              child: Text(
                'هەڵەیەک ڕوویدا لە بارکردنی تێبینییەکان',
                style: TextStyle(
                  color: themeProvider.isDarkMode
                      ? Colors.grey[400]
                      : Colors.grey[600],
                  fontSize: 16,
                  fontFamily: 'Inter',
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Directionality(
              textDirection: languageProvider.textDirection,
              child: Text(
                'تکایە پشکنینی هێڵی ئینتەرنێت بکە',
                style: TextStyle(
                  color: themeProvider.isDarkMode
                      ? Colors.grey[500]
                      : Colors.grey[500],
                  fontSize: 12,
                  fontFamily: 'Inter',
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadNotes,
              child: Directionality(
                textDirection: languageProvider.textDirection,
                child: const Text(
                  'هەوڵدانەوە',
                  style: TextStyle(fontFamily: 'Inter'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
  ) {
    if (_isOffline) {
      return OfflineErrorState(onRetry: _loadNotes);
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notes_outlined,
            size: 80,
            color: themeProvider.isDarkMode
                ? Colors.grey[700]
                : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Directionality(
            textDirection: languageProvider.textDirection,
            child: Text(
              'هیچ تێبینییەک نەدۆزرایەوە',
              style: TextStyle(
                color: themeProvider.isDarkMode
                    ? Colors.grey[500]
                    : Colors.grey[500],
                fontSize: 18,
                fontFamily: 'Inter',
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState(
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: themeProvider.isDarkMode
                ? Colors.grey[700]
                : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Directionality(
            textDirection: languageProvider.textDirection,
            child: Text(
              'هیچ ئەنجامێک نەدۆزرایەوە بۆ گەڕانەکەت',
              style: TextStyle(
                color: themeProvider.isDarkMode
                    ? Colors.grey[500]
                    : Colors.grey[500],
                fontSize: 18,
                fontFamily: 'Inter',
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Directionality(
            textDirection: languageProvider.textDirection,
            child: Text(
              'تکایە وشەی گەڕان بگۆڕە',
              style: TextStyle(
                color: themeProvider.isDarkMode
                    ? Colors.grey[600]
                    : Colors.grey[400],
                fontSize: 14,
                fontFamily: 'Inter',
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteItem(
    BuildContext context,
    Note note,
    int noteNumber,
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        child: InkWell(
          onTap: () => _onNoteTap(context, note),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Directionality(
              textDirection: languageProvider.textDirection,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Section number
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: themeProvider.isDarkMode
                          ? const Color(0xFF1A3460).withValues(alpha: 0.35)
                          : const Color(0xFF1A3460).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: themeProvider.isDarkMode
                            ? const Color(0xFF4A7EB5)
                            : const Color(0xFF1A3460),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        noteNumber.toString(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: themeProvider.isDarkMode
                              ? const Color(0xFF4A7EB5)
                              : const Color(0xFF1A3460),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ),
                  // Note title
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: languageProvider.isRTL ? 8 : 0,
                        left: languageProvider.isRTL ? 0 : 8,
                      ),
                      child: Align(
                        alignment: languageProvider.isRTL
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Text(
                          note.name.isNotEmpty ? note.name : 'Unnamed Note',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: themeProvider.isDarkMode
                                ? Colors.white
                                : Colors.black87,
                            fontFamily: 'Inter',
                          ),
                          textAlign: languageProvider.isRTL
                              ? TextAlign.right
                              : TextAlign.left,
                        ),
                      ),
                    ),
                  ),
                  // Optional image
                  if (_isValidHttpUrl(note.imageUrl)) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: themeProvider.isDarkMode
                            ? Colors.grey[800]
                            : Colors.grey[200],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: note.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Center(
                            child: LoadingAnimationWidget.threeArchedCircle(
                              color: themeProvider.theme.colorScheme.primary,
                              size: 20,
                            ),
                          ),
                          errorWidget: (context, url, error) => Icon(
                            Icons.image_not_supported,
                            color: themeProvider.isDarkMode
                                ? Colors.grey[600]
                                : Colors.grey[400],
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}