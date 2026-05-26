import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import '../utils/page_transition.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import '../providers/history_provider.dart';
import '../models/note.dart';
import 'dart:convert';

class NoteDetailsPage extends StatefulWidget {
  final Note note;
  final bool isEditable;
  final bool showHeaderImage;

  const NoteDetailsPage({Key? key, required this.note, this.isEditable = false, this.showHeaderImage = true}) : super(key: key);

  @override
  State<NoteDetailsPage> createState() => _NoteDetailsPageState();
}

class _NoteDetailsPageState extends State<NoteDetailsPage> {
  late TextEditingController _textController;
  bool _isEditing = false;
  bool _showPreview = false;
  List<Map<String, dynamic>> _sections = [];

  // Convert Google Drive share/preview links to direct-view image URLs
  String _resolveImageUrl(String url) {
    try {
      if (url.isEmpty) return url;
      final uri = Uri.parse(url);
      if (uri.host.contains('drive.google.com')) {
        if (uri.path.startsWith('/uc') && uri.queryParameters['id'] != null) {
          final id = uri.queryParameters['id'];
          return 'https://drive.google.com/uc?export=view&id=$id';
        }

        final fileIdMatch = RegExp(r"/d/([^/]+)").firstMatch(uri.path);
        String? id = fileIdMatch?.group(1);
        id = id ?? uri.queryParameters['id'];

        if (id != null && id.isNotEmpty) {
          return 'https://drive.google.com/uc?export=view&id=$id';
        }
      }
    } catch (_) {
      // If parsing fails, return original URL
    }
    return url;
  }

  void _showFullScreenImage(BuildContext context, String imageUrl, String title) {
    // Title intentionally not shown in fullscreen per user request
    Navigator.of(context).push(
      createRoute(
        Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // Image viewer
              Positioned.fill(
                child: PhotoView(
                  imageProvider: CachedNetworkImageProvider(_resolveImageUrl(imageUrl)),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 3,
                  backgroundDecoration: const BoxDecoration(color: Colors.black),
                ),
              ),
              // Close button overlay (top-left)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
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

  @override
  void initState() {
    super.initState();
    _parseNoteContent();
    _textController = TextEditingController(text: widget.note.description ?? '');
    
    // Add to history after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<HistoryProvider>(context, listen: false)
          .addToHistory(widget.note.name, 'note', 'Viewed note details');
    });
  }

  // Parse note content to extract sections
  void _parseNoteContent() {
    if (widget.note.description == null || widget.note.description!.isEmpty) {
      return;
    }

    try {
      // Try to parse as JSON first
      final Map<String, dynamic> jsonData = json.decode(widget.note.description!);
      if (jsonData.containsKey('sections') && jsonData['sections'] is List) {
        _sections = List<Map<String, dynamic>>.from(jsonData['sections']);
      }
    } catch (e) {
      // If not JSON, treat as regular text
      _sections = [];
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // Normalize and validate a per-section image URL. Returns null if invalid.
  String? _safeImageUrlForSection(Map<String, dynamic> section, int index) {
    try {
      final dynamic rawVal = section['image_url'] ?? section['imageUrl'];
      if (rawVal == null) return null;
      final raw = rawVal.toString().trim();
      if (raw.isEmpty) return null;

      final uri = Uri.tryParse(raw);
      if (uri == null || uri.scheme.isEmpty || (uri.scheme != 'https' && uri.scheme != 'http')) {
        return null;
      }
      // Encode spaces and special chars safely
      final normalized = Uri.parse(Uri.decodeFull(raw)).toString();
      return _resolveImageUrl(normalized);
    } catch (e) {
      return null;
    }
  }

  // Method to format text with proper line breaks and structure
  String _formatText(String text) {
    // Replace ### and * with bullet points for better readability
    text = text.replaceAll('###', '\n• ');
    // Handle asterisk bullets at the start of a line
    text = text.replaceAll(RegExp(r'(^|\n)\*\s*'), '\n• ');
    
    // Clean up multiple line breaks
    text = text.replaceAll(RegExp(r'\n\s*\n'), '\n\n');
    
    // Remove leading/trailing whitespace
    text = text.trim();
    
    return text;
  }

  // Method to create styled text with better formatting
  Widget _buildFormattedText(String content, ThemeProvider themeProvider, LanguageProvider languageProvider) {
    List<Widget> widgets = [];
    
    // Split content by ** to separate headings from regular text
    List<String> parts = content.split('**');
    
    for (int i = 0; i < parts.length; i++) {
      String part = parts[i].trim();
      if (part.isEmpty) continue;
      
      // Even indices are regular text, odd indices are headings
      if (i % 2 == 0) {
        // Regular text - process ### for bullet points
        String formattedText = _formatText(part);
        List<String> lines = formattedText.split('\n');
        
        for (String line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      // Sub-heading starting with ##
      if (trimmed.startsWith('##')) {
        final subHeading = trimmed.replaceFirst(RegExp(r'^##\s*'), '');
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Directionality(
              textDirection: languageProvider.textDirection,
              child: Text(
                subHeading,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: themeProvider.isDarkMode ? const Color(0xFF4A7EB5) : const Color(0xFF1A3460),
                  height: 1.5,
                  fontFamily: 'Inter',
                ),
                textAlign: languageProvider.isRTL ? TextAlign.right : TextAlign.left,
              ),
            ),
          ),
        );
        continue;
      }

      // Bullet points starting with • or *
      if (trimmed.startsWith('•') || trimmed.startsWith('*')) {
        final bulletText = trimmed.startsWith('*')
            ? trimmed.replaceFirst(RegExp(r'^\*\s*'), '• ')
            : trimmed;
        widgets.add(
          Padding(
            padding: EdgeInsets.only(
              left: languageProvider.isRTL ? 0 : 16,
              right: languageProvider.isRTL ? 16 : 0,
              bottom: 4,
            ),
            child: Directionality(
              textDirection: languageProvider.textDirection,
              child: Text(
                bulletText,
                style: TextStyle(
                  fontSize: 16,
                  color: themeProvider.isDarkMode ? Colors.grey[400] : Colors.black87,
                  height: 1.6,
                  fontFamily: 'Inter',
                ),
                textAlign: languageProvider.isRTL ? TextAlign.right : TextAlign.left,
              ),
            ),
          ),
        );
        continue;
      }
          if (line.trim().isEmpty) {
            widgets.add(const SizedBox(height: 8));
            continue;
          }
          
          // Style bullet points
          if (line.trim().startsWith('•')) {
            widgets.add(
              Padding(
                padding: EdgeInsets.only(
                  left: languageProvider.isRTL ? 0 : 16,
                  right: languageProvider.isRTL ? 16 : 0,
                  bottom: 4,
                ),
                child: Directionality(
                  textDirection: languageProvider.textDirection,
                  child: Text(
                    line,
                    style: TextStyle(
                      fontSize: 16,
                      color: themeProvider.isDarkMode 
                        ? Colors.grey[400] 
                        : Colors.black87,
                      height: 1.6,
                      fontFamily: 'Inter',
                    ),
                    textAlign: languageProvider.isRTL ? TextAlign.right : TextAlign.left,
                  ),
                ),
              ),
            );
          } else {
            // Regular text
            widgets.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Directionality(
                  textDirection: languageProvider.textDirection,
                  child: Text(
                    line,
                    style: TextStyle(
                      fontSize: 16,
                      color: themeProvider.isDarkMode 
                        ? Colors.grey[400] 
                        : Colors.black87,
                      height: 1.6,
                      fontFamily: 'Inter',
                    ),
                    textAlign: languageProvider.isRTL ? TextAlign.right : TextAlign.left,
                  ),
                ),
              ),
            );
          }
        }
      } else {
        // This is a heading (text between **)
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Directionality(
              textDirection: languageProvider.textDirection,
              child: Text(
                part,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.isDarkMode 
                    ? const Color(0xFF4A7EB5) 
                    : const Color(0xFF1A3460),
                  height: 1.4,
                  fontFamily: 'Inter',
                ),
                textAlign: languageProvider.isRTL ? TextAlign.right : TextAlign.left,
              ),
            ),
          ),
        );
      }
    }
    
    return Column(
      crossAxisAlignment: languageProvider.isRTL 
          ? CrossAxisAlignment.end 
          : CrossAxisAlignment.start,
      children: widgets,
    );
  }

  // Method to insert formatting at cursor position
  void _insertFormatting(String format) {
    final text = _textController.text;
    final selection = _textController.selection;
    
    if (selection.isValid) {
      final newText = text.replaceRange(
        selection.start,
        selection.end,
        format,
      );
      
      _textController.text = newText;
      
      // Move cursor to appropriate position
      int cursorPosition;
      if (format == '****') {
        cursorPosition = selection.start + 2; // Place cursor between **
      } else {
        cursorPosition = selection.start + format.length;
      }
      
      _textController.selection = TextSelection.collapsed(offset: cursorPosition);
    }
  }

  // Method to wrap selected text with formatting
  void _wrapSelection(String startFormat, String endFormat) {
    final text = _textController.text;
    final selection = _textController.selection;
    
    if (selection.isValid && selection.start != selection.end) {
      final selectedText = text.substring(selection.start, selection.end);
      final newText = text.replaceRange(
        selection.start,
        selection.end,
        '$startFormat$selectedText$endFormat',
      );
      
      _textController.text = newText;
      _textController.selection = TextSelection.collapsed(
        offset: selection.start + startFormat.length + selectedText.length + endFormat.length,
      );
    }
  }

  // Formatting toolbar
  Widget _buildFormattingToolbar(ThemeProvider themeProvider) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    
    return Directionality(
      textDirection: languageProvider.textDirection,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: themeProvider.isDarkMode ? Colors.grey[800] : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: languageProvider.isRTL 
              ? CrossAxisAlignment.end 
              : CrossAxisAlignment.start,
          children: [
            // Formatting buttons
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Directionality(
                textDirection: languageProvider.textDirection,
                child: Row(
                  children: [
                    _buildToolbarButton(
                      icon: Icons.title,
                      label: 'سەرناو',
                      onTap: () => _insertFormatting('****'),
                      themeProvider: themeProvider,
                    ),
                    const SizedBox(width: 8),
                    _buildToolbarButton(
                      icon: Icons.subtitles,
                      label: 'ژێرسەرناو',
                      onTap: () => _insertFormatting('## '),
                      themeProvider: themeProvider,
                    ),
                    const SizedBox(width: 8),
                    _buildToolbarButton(
                      icon: Icons.format_list_bulleted,
                      label: 'خاڵ',
                      onTap: () => _insertFormatting('* '),
                      themeProvider: themeProvider,
                    ),
                    const SizedBox(width: 8),
                    _buildToolbarButton(
                      icon: Icons.format_bold,
                      label: 'قەڵەو',
                      onTap: () => _wrapSelection('**', '**'),
                      themeProvider: themeProvider,
                    ),
                    const SizedBox(width: 8),
                    _buildToolbarButton(
                      icon: Icons.visibility,
                      label: 'پێشبینین',
                      onTap: () => setState(() => _showPreview = !_showPreview),
                      themeProvider: themeProvider,
                      isActive: _showPreview,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            // Formatting guide
            Text(
              'ڕێنمایی فۆرماتکردن:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
                fontFamily: 'Inter',
              ),
              textAlign: languageProvider.isRTL ? TextAlign.right : TextAlign.left,
            ),
            const SizedBox(height: 4),
            _buildFormatGuide('**دەق** = سەرناو', themeProvider),
            _buildFormatGuide('## دەق = ژێرسەرناو', themeProvider),
            _buildFormatGuide('* دەق = خاڵی لیست', themeProvider),
            _buildFormatGuide('دەقی ئاسایی = پەرەگرافی ئاسایی', themeProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ThemeProvider themeProvider,
    bool isActive = false,
  }) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive 
            ? (themeProvider.isDarkMode ? const Color(0xFF1A3460) : const Color(0xFF4A7EB5).withValues(alpha: 0.15))
            : (themeProvider.isDarkMode ? Colors.grey[700] : Colors.white),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          border: Border.all(
            color: themeProvider.isDarkMode ? Colors.grey[600]! : Colors.grey[300]!,
          ),
        ),
        child: Directionality(
          textDirection: languageProvider.textDirection,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: languageProvider.isRTL ? [
              // RTL: Text first, then icon
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isActive 
                    ? (themeProvider.isDarkMode ? Colors.white : Colors.blue[700])
                    : (themeProvider.isDarkMode ? Colors.white : Colors.black87),
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                icon,
                size: 18,
                color: isActive 
                  ? (themeProvider.isDarkMode ? Colors.white : Colors.blue[700])
                  : (themeProvider.isDarkMode ? Colors.white : Colors.black87),
              ),
            ] : [
              // LTR: Icon first, then text
              Icon(
                icon,
                size: 18,
                color: isActive 
                  ? (themeProvider.isDarkMode ? Colors.white : Colors.blue[700])
                  : (themeProvider.isDarkMode ? Colors.white : Colors.black87),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isActive 
                    ? (themeProvider.isDarkMode ? Colors.white : Colors.blue[700])
                    : (themeProvider.isDarkMode ? Colors.white : Colors.black87),
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormatGuide(String text, ThemeProvider themeProvider) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Directionality(
        textDirection: languageProvider.textDirection,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: themeProvider.isDarkMode ? Colors.grey[400] : Colors.grey[600],
            fontFamily: 'Inter',
          ),
          textAlign: languageProvider.isRTL ? TextAlign.right : TextAlign.left,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.theme.scaffoldBackgroundColor,
      body: Directionality(
        textDirection: languageProvider.textDirection,
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: themeProvider.isDarkMode 
                    ? themeProvider.theme.colorScheme.surface 
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
                        children: languageProvider.isRTL ? [
                          // RTL layout: Edit button on left, back button on right
                          if (widget.isEditable)
                            IconButton(
                              icon: Icon(
                                _isEditing ? Icons.save : Icons.edit,
                                color: themeProvider.isDarkMode ? Colors.white : Colors.white,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isEditing = !_isEditing;
                                  if (!_isEditing) {
                                    _showPreview = false;
                                    // Here you would typically save the changes
                                    // widget.note.description = _textController.text;
                                  }
                                });
                              },
                            )
                          else
                            const SizedBox.shrink(), // Empty space when not editable
                          IconButton(
                            icon: Icon(Icons.arrow_forward, color: themeProvider.isDarkMode ? Colors.white : Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ] : [
                          // LTR layout: Back button on left, edit button on right
                          IconButton(
                            icon: Icon(Icons.arrow_back, color: themeProvider.isDarkMode ? Colors.white : Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          if (widget.isEditable)
                            IconButton(
                              icon: Icon(
                                _isEditing ? Icons.save : Icons.edit,
                                color: themeProvider.isDarkMode ? Colors.white : Colors.white,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isEditing = !_isEditing;
                                  if (!_isEditing) {
                                    _showPreview = false;
                                    // Here you would typically save the changes
                                    // widget.note.description = _textController.text;
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                    // Note Image (optional)
                    if (widget.showHeaderImage && widget.note.imageUrl != null && widget.note.imageUrl!.isNotEmpty)
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
                          child: GestureDetector(
                            onTap: () => _showFullScreenImage(context, widget.note.imageUrl!, widget.note.name),
                            child: CachedNetworkImage(
                              imageUrl: _resolveImageUrl(widget.note.imageUrl!),
                              fit: BoxFit.cover,
                              placeholder: (ctx, url) => Container(
                                color: themeProvider.isDarkMode ? Colors.grey[800] : Colors.grey[200],
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: themeProvider.isDarkMode ? Colors.white : Colors.grey[600],
                                  ),
                                ),
                              ),
                              errorWidget: (ctx, url, err) => Container(
                                color: themeProvider.isDarkMode ? Colors.grey[800] : Colors.grey[200],
                                child: Icon(
                                  Icons.broken_image,
                                  color: themeProvider.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                  size: 50,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Note Name
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: Text(
                        widget.note.name,
                        style: TextStyle(
                          color: themeProvider.isDarkMode
                              ? themeProvider.theme.colorScheme.onSurface
                              : Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            
            // Content sections
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Formatting toolbar (only show when editing)
                  if (_isEditing) ...[
                    _buildFormattingToolbar(themeProvider),
                    const SizedBox(height: 16),
                  ],
                  
                  // Main content area
                  _buildContentSection(themeProvider, languageProvider),
                ],
              ),
            ),
          ],
        ),
      ),
      )
    );
  }

  Widget _buildContentSection(ThemeProvider themeProvider, LanguageProvider languageProvider) {
    // If we have sections, display them; otherwise show regular content
    if (_sections.isNotEmpty && !_isEditing) {
      return _buildSectionsView(themeProvider, languageProvider);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: languageProvider.isRTL 
            ? CrossAxisAlignment.end 
            : CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          
          // Content area - either editor or formatted text
          if (_isEditing) ...[
            // Text editor
            Directionality(
              textDirection: languageProvider.textDirection,
              child: TextField(
                controller: _textController,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textDirection: languageProvider.textDirection,
                style: TextStyle(
                  fontSize: 16,
                  color: themeProvider.isDarkMode 
                    ? Colors.grey[400] 
                    : Colors.black87,
                  height: 1.6,
                ),
              decoration: InputDecoration(
                hintText: 'دەقەکەت لێرە بنووسە...\n\n**دەق** بەکاربهێنە بۆ سەرناو\n## بەکاربهێنە بۆ ژێرسەرناو\n* بەکاربهێنە بۆ خاڵی لیست',
                hintStyle: TextStyle(
                  color: themeProvider.isDarkMode 
                    ? Colors.grey[600] 
                    : Colors.grey[500],
                  fontFamily: 'Inter',
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: themeProvider.isDarkMode 
                      ? Colors.grey[600]! 
                      : Colors.grey[300]!,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: themeProvider.isDarkMode 
                      ? Colors.grey[600]! 
                      : Colors.grey[300]!,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: themeProvider.isDarkMode 
                        ? const Color(0xFF4A7EB5)
                        : const Color(0xFF1A3460),
                  ),
                ),
                filled: true,
                fillColor: themeProvider.isDarkMode 
                  ? Colors.grey[800] 
                  : Colors.grey[50],
              ),
            ),
            ),
            
            // Preview toggle
            if (_showPreview) ...[
              const SizedBox(height: 16),
              Divider(
                color: themeProvider.isDarkMode 
                  ? Colors.grey[600] 
                  : Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Directionality(
                textDirection: languageProvider.textDirection,
                child: Text(
                  'پێشبینین:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.isDarkMode 
                      ? Colors.white 
                      : Colors.black87,
                    fontFamily: 'Inter',
                  ),
                  textAlign: languageProvider.isRTL ? TextAlign.right : TextAlign.left,
                ),
              ),
              const SizedBox(height: 8),
              _buildFormattedText(_textController.text, themeProvider, languageProvider),
            ],
          ] else ...[
            // Formatted text display
            _buildFormattedText(widget.note.description ?? '', themeProvider, languageProvider),
          ],
        ],
      ),
    );
  }

  // Build sections view for structured content
  Widget _buildSectionsView(ThemeProvider themeProvider, LanguageProvider languageProvider) {
    return Column(
      children: _sections.asMap().entries.map((entry) {
        int index = entry.key;
        Map<String, dynamic> section = entry.value;
        final imageUrl = _safeImageUrlForSection(section, index);
        
        return Container(
          width: double.infinity,
          margin: EdgeInsets.only(bottom: index < _sections.length - 1 ? 16 : 0),
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
            crossAxisAlignment: languageProvider.isRTL 
                ? CrossAxisAlignment.end 
                : CrossAxisAlignment.start,
            children: [
              // Section title
              if (section['title'] != null && section['title'].toString().isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text(
                      section['title'].toString(),
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
              ],
              
              // Section content
              if (section['content'] != null && section['content'].toString().isNotEmpty)
                _buildSectionContent(section['content'].toString(), themeProvider, languageProvider),

              // Optional image under the content
              if (imageUrl != null && imageUrl.isNotEmpty) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: GestureDetector(
                    onTap: () => _showFullScreenImage(context, imageUrl, section['title']?.toString() ?? widget.note.name),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 180,
                      placeholder: (ctx, url) => Container(
                        height: 180,
                        color: themeProvider.isDarkMode ? Colors.grey[800] : Colors.grey[200],
                        child: Center(
                          child: CircularProgressIndicator(
                            color: themeProvider.isDarkMode ? Colors.white : Colors.grey[600],
                          ),
                        ),
                      ),
                      errorWidget: (ctx, url, err) {
                        if (kDebugMode) debugPrint('[NoteDetails] Failed to load section image: $url err: ${err.toString()}');
                        return Container(
                        height: 180,
                        color: themeProvider.isDarkMode ? Colors.grey[800] : Colors.grey[200],
                        child: Icon(
                          Icons.broken_image,
                          color: themeProvider.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          size: 40,
                        ),
                      );
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  // Build content for a specific section
  Widget _buildSectionContent(String content, ThemeProvider themeProvider, LanguageProvider languageProvider) {
    List<Widget> widgets = [];
    
    // Split content by lines
    List<String> lines = content.split('\n');
    
    for (String line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;
      
      // Handle bullet points
      if (line.startsWith('•') || line.startsWith('*')) {
        final bulletText = line.startsWith('*')
            ? line.replaceFirst(RegExp(r'^\*\s*'), '• ')
            : line;
        
        widgets.add(
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(
              right: 20,
              bottom: 8,
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                bulletText,
                style: TextStyle(
                  fontSize: 16,
                  color: themeProvider.isDarkMode ? Colors.grey[300] : Colors.black87,
                  height: 1.6,
                  fontFamily: 'Inter',
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ),
        );
      }
      // Handle sub-headings
      else if (line.startsWith('##')) {
        final subHeading = line.replaceFirst(RegExp(r'^##\s*'), '');
        widgets.add(
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                subHeading,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: themeProvider.isDarkMode ? const Color(0xFF4A7EB5) : const Color(0xFF1A3460),
                  height: 1.5,
                  fontFamily: 'Inter',
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ),
        );
      }
      // Regular paragraph text
      else {
        widgets.add(
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 8),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                line,
                style: TextStyle(
                  fontSize: 16,
                  color: themeProvider.isDarkMode ? Colors.grey[300] : Colors.black87,
                  height: 1.6,
                  fontFamily: 'Inter',
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ),
        );
      }
    }
    
    return Column(
      crossAxisAlignment: languageProvider.isRTL 
          ? CrossAxisAlignment.end 
          : CrossAxisAlignment.start,
      children: widgets,
    );
  }
}