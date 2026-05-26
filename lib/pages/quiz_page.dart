import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../providers/theme_provider.dart';
import '../services/quiz_service.dart';
import '../models/quiz_question.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart'; // Add for haptic feedback
import 'package:cached_network_image/cached_network_image.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> with TickerProviderStateMixin {
  final QuizService _quizService = QuizService();

  QuizQuestion? _currentQuestion;
  bool _isLoading = false;
  bool _showResult = false;
  bool _isCorrect = false;
  String? _selectedAnswer;
  static const int _maxQuestions = 10;
  int _currentScore = 0;
  int _totalQuestions = 0;
  bool _pointsUpdated = false;
  bool _isSubmitting = false; // Add to prevent double submission

  // Category selection
  bool _showCategorySelection = true;
  String? _selectedCategory;

  // Track answered questions to avoid duplicates
  final Set<String> _answeredQuestions = {};

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
        id ??= uri.queryParameters['id'];

        if (id != null && id.isNotEmpty) {
          return 'https://drive.google.com/uc?export=view&id=$id';
        }
      }
    } catch (_) {
      // If parsing fails, just return original URL
    }
    return url;
  }

  // Animation controllers
  late AnimationController _progressAnimationController;
  late AnimationController _questionAnimationController;
  late AnimationController _optionAnimationController;
  late AnimationController _resultAnimationController; // Add result animation

  // Animations
  late Animation<double> _progressAnimation;
  late Animation<Offset> _questionSlideAnimation;
  late Animation<double> _questionFadeAnimation;
  late Animation<double> _resultScaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _questionAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _optionAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _resultAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressAnimationController,
      curve: Curves.easeInOut,
    ));

    _questionSlideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _questionAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _questionFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _questionAnimationController,
      curve: Curves.easeIn,
    ));

    _resultScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _resultAnimationController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _progressAnimationController.dispose();
    _questionAnimationController.dispose();
    _optionAnimationController.dispose();
    _resultAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadNewQuestion() async {
    if (_isLoading) return; // Prevent multiple loads

    // Strict check: ensure we don't load more than max questions
    if (_totalQuestions >= _maxQuestions) {
      _finalizeQuiz();
      return;
    }

    setState(() {
      _isLoading = true;
      _showResult = false;
      _selectedAnswer = null;
      _isSubmitting = false;
    });

    // Reset animations
    _questionAnimationController.reset();
    _optionAnimationController.reset();
    _resultAnimationController.reset();

    try {
      QuizQuestion question;
      int attempts = 0;
      const maxAttempts = 5;

      // Try to get a unique question
      do {
        if (_selectedCategory == 'instruments') {
          question = await _quizService.generateInstrumentQuestion();
        } else if (_selectedCategory == 'slides') {
          question = await _quizService.generateSlideQuestion();
        } else {
          question = await _quizService.generateRandomQuestion();
        }
        attempts++;
      } while (_answeredQuestions.contains(question.imageUrl) &&
          attempts < maxAttempts);

      if (question.imageUrl.isNotEmpty) {
        _answeredQuestions.add(question.imageUrl);
      }

      setState(() {
        _currentQuestion = question;
        _isLoading = false;
      });

      // Start animations
      await Future.delayed(const Duration(milliseconds: 100));
      _questionAnimationController.forward();
      _optionAnimationController.forward();

      // Update progress animation
      _progressAnimationController.animateTo(
        (_totalQuestions + 1) / _maxQuestions,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading question: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        _showErrorSnackBar('هەڵەیەک ڕووی دا لە بارکردنی پرسیار');
      }
    }
  }

  Future<void> _submitAnswer(String selectedAnswer) async {
    if (_currentQuestion == null || _selectedAnswer != null || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // Haptic feedback
    HapticFeedback.lightImpact();

    setState(() {
      _selectedAnswer = selectedAnswer;
      _isCorrect = selectedAnswer == _currentQuestion!.correctAnswer;
      _showResult = true;
      _totalQuestions++;
      _isSubmitting = false;
    });

    if (_isCorrect) {
      setState(() {
        _currentScore++;
      });
      HapticFeedback.mediumImpact(); // Success feedback
    } else {
      HapticFeedback.heavyImpact(); // Error feedback
    }

    // Animate result
    _resultAnimationController.forward();

    // Check if we've reached the maximum questions and auto-finalize
    if (_totalQuestions >= _maxQuestions) {
      // Auto-finalize after a short delay to show the result
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _finalizeQuiz();
        }
      });
    }
  }

  Future<void> _updateUserPoints(int points) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isSignedIn || authProvider.token == null) return;

    try {
      final response = await http.post(
        Uri.parse('${AuthProvider.baseUrl}/api/auth/add-points'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer ${authProvider.token}',
        },
        body: jsonEncode({'points': points}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          await authProvider.getCurrentUser();
        } catch (e) {
          if (kDebugMode) debugPrint('Warning: getCurrentUser failed after points update: $e');
        }
        if (mounted) {
          _showSuccessSnackBar('خاڵەکانت زیاد کرا: $points خاڵ');
        }
      } else {
        String serverMessage = 'نەتوانرا خاڵەکان نوێکرێتەوە (کۆد: ${response.statusCode})';
        try {
          final data = jsonDecode(response.body);
          final msg = data['message'] ?? data['detail'] ?? data['error'];
          if (msg is String && msg.trim().isNotEmpty) serverMessage = msg;
        } catch (_) {}
        if (mounted) _showErrorSnackBar(serverMessage);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error updating points: $e');
      if (mounted) _showErrorSnackBar('هەڵەیەک ڕووی دا لە نوێکردنەوەی خاڵەکان');
    }
  }

  // Helper method to format text with content inside {} as italic (scientific names)
  Widget _buildFormattedText(String text, TextStyle baseStyle) {
    final RegExp regex = RegExp(r'\{([^}]*)\}');
    final List<TextSpan> spans = [];
    int lastMatchEnd = 0;

    for (final Match match in regex.allMatches(text)) {
      // Add text before the match
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: baseStyle,
        ));
      }

      // Add the matched text (content inside {}) as italic (scientific name)
      spans.add(TextSpan(
        text: match.group(1),
        style: baseStyle.copyWith(fontStyle: FontStyle.italic),
      ));

      lastMatchEnd = match.end;
    }

    // Add remaining text after the last match
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: baseStyle,
      ));
    }

    // If no matches found, return the original text
    if (spans.isEmpty) {
      return Text(text, style: baseStyle);
    }

    return RichText(
      textAlign: TextAlign.start,
      text: TextSpan(children: spans),
    );
  }

  Future<void> _finalizeQuiz() async {
    if (_pointsUpdated) return;
    _pointsUpdated = true;

    final int totalPoints = _currentScore * 10;

    // Await points update so profile page shows correct data immediately after
    await _updateUserPoints(totalPoints);

    if (!mounted) return;

    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    final percentage = (_currentScore / _totalQuestions * 100).round();

    // Determine performance level
    String performanceMessage;
    IconData performanceIcon;
    Color performanceColor;

    if (percentage >= 80) {
      performanceMessage = 'نایاب! ئەدائێکی زۆر باش';
      performanceIcon = Icons.emoji_events;
      performanceColor = Colors.amber;
    } else if (percentage >= 60) {
      performanceMessage = 'ئافەرین! ئەدائێکی باش';
      performanceIcon = Icons.thumb_up;
      performanceColor = Colors.green;
    } else if (percentage >= 40) {
      performanceMessage = 'باشە! بەردەوام بە لە پێشکەوتن';
      performanceIcon = Icons.trending_up;
      performanceColor = const Color(0xFF4A7EB5);
    } else {
      performanceMessage = 'هەوڵی زیاتر بدە!';
      performanceIcon = Icons.fitness_center;
      performanceColor = Colors.orange;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Directionality(
          textDirection: languageProvider.textDirection,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(
                  performanceIcon,
                  color: performanceColor,
                  size: 32,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'ئەنجامی کۆتایی',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      children: [
                        // Score Circle
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                performanceColor,
                                performanceColor.withValues(alpha: 0.6),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: performanceColor.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '$percentage%',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          performanceMessage,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: performanceColor,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatItem(
                              icon: Icons.check_circle,
                              label: 'ڕاست',
                              value: '$_currentScore',
                              color: Colors.green,
                            ),
                            _buildStatItem(
                              icon: 'quiz.png',
                              label: 'کۆی گشتی',
                              value: '$_totalQuestions',
                              color: const Color(0xFF4A7EB5),
                            ),
                            _buildStatItem(
                              icon: Icons.stars,
                              label: 'خاڵ',
                              value: '$totalPoints',
                              color: Colors.amber,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _resetQuiz();
                },
                child: const Text(
                  'جۆری نوێ',
                  style: TextStyle(fontFamily: 'Inter'),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _resetForSameCategory();
                },
                child: const Text(
                  'دووبارە',
                  style: TextStyle(fontFamily: 'Inter'),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'دەرچوون',
                  style: TextStyle(fontFamily: 'Inter'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem({
    required dynamic icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        icon is IconData
            ? Icon(icon, color: color, size: 24)
            : Image.asset(
                'assets/Icons/$icon',
                width: 24,
                height: 24,
                color: color,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.quiz,
                    color: color,
                    size: 24,
                  );
                },
              ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontFamily: 'Inter',
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Inter'),
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(20),
        action: SnackBarAction(
          label: 'داخستن',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontFamily: 'Inter'),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _selectCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _showCategorySelection = false;
    });
    _loadNewQuestion();
  }

  void _resetQuiz() {
    setState(() {
      _showCategorySelection = true;
      _selectedCategory = null;
      _currentQuestion = null;
      _isLoading = false;
      _showResult = false;
      _isCorrect = false;
      _selectedAnswer = null;
      _currentScore = 0;
      _totalQuestions = 0;
      _pointsUpdated = false;
      _isSubmitting = false;
      _answeredQuestions.clear();
    });

    // Reset animations
    _progressAnimationController.reset();
    _questionAnimationController.reset();
    _optionAnimationController.reset();
    _resultAnimationController.reset();
  }

  void _resetForSameCategory() {
    setState(() {
      _currentQuestion = null;
      _isLoading = false;
      _showResult = false;
      _isCorrect = false;
      _selectedAnswer = null;
      _currentScore = 0;
      _totalQuestions = 0;
      _pointsUpdated = false;
      _isSubmitting = false;
      _answeredQuestions.clear();
    });

    // Reset animations
    _progressAnimationController.reset();
    _questionAnimationController.reset();
    _optionAnimationController.reset();
    _resultAnimationController.reset();

    // Load new question with same category
    _loadNewQuestion();
  }

  Widget _buildProgressBar() {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Calculate the current question number (not total answered)
    final currentQuestionNumber = _totalQuestions + (_showResult ? 0 : 1);
    final displayQuestionNumber = currentQuestionNumber.clamp(1, _maxQuestions);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'پرسیاری $displayQuestionNumber لە $_maxQuestions',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: themeProvider.theme.colorScheme.onSurface,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${((displayQuestionNumber) / _maxQuestions * 100).round()}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade800
                  : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
            child: AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, child) {
                return FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor:
                      (_totalQuestions / _maxQuestions).clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard({
    required String title,
    required String subtitle,
    required dynamic icon,
    required Color color,
    required VoidCallback onTap,
    required LanguageProvider languageProvider,
    required ThemeProvider themeProvider,
  }) {
    return Hero(
      tag: title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: themeProvider.isDarkMode
                  ? const Color(0xFF1E1E1E)
                  : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: themeProvider.isDarkMode
                  ? null
                  : [
                      BoxShadow(
                        color: color.withValues(alpha: 0.15),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: icon is IconData
                      ? Icon(
                          icon,
                          color: Colors.white,
                          size: 32,
                        )
                      : Image.asset(
                          'assets/Icons/$icon',
                          width: 32,
                          height: 32,
                          color: Colors.white,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.help_outline,
                              color: Colors.white,
                              size: 32,
                            );
                          },
                        ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Directionality(
                        textDirection: languageProvider.textDirection,
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: themeProvider.theme.colorScheme.onSurface,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Directionality(
                        textDirection: languageProvider.textDirection,
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: themeProvider.theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    color: color,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelection() {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    themeProvider.theme.colorScheme.primary,
                    themeProvider.theme.colorScheme.primary.withValues(alpha: 0.8),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  Expanded(
                    child: Directionality(
                      textDirection: languageProvider.textDirection,
                      child: const Text(
                        'جۆری تاقیکردنەوە',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 40),

                    // Header section with animation
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutBack,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            padding: const EdgeInsets.all(30),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  themeProvider.theme.colorScheme.primary
                                      .withValues(alpha: 0.1),
                                  themeProvider.theme.colorScheme.primary
                                      .withValues(alpha: 0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                color: themeProvider.theme.colorScheme.primary
                                    .withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: themeProvider.theme.colorScheme.primary.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.asset(
                                      'assets/Icons/quiz.png',
                                      width: 64,
                                      height: 64,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Icon(
                                          Icons.quiz,
                                          size: 64,
                                          color: themeProvider.theme.colorScheme.primary,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Directionality(
                                  textDirection: languageProvider.textDirection,
                                  child: Text(
                                    'جۆری تاقیکردنەوە هەڵبژێرە',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: themeProvider
                                          .theme.colorScheme.onSurface,
                                      fontFamily: 'Inter',
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Directionality(
                                  textDirection: languageProvider.textDirection,
                                  child: Text(
                                    'دەتوانیت تاقیکردنەوە لەسەر کەرەستەکان یان سڵایدەکان بکەیت',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: themeProvider
                                          .theme.colorScheme.onSurface
                                          .withValues(alpha: 0.7),
                                      fontFamily: 'Inter',
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 40),

                    // Category selection cards with staggered animation
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 50 * (1 - value)),
                          child: Opacity(
                            opacity: value,
                            child: _buildCategoryCard(
                              title: 'تاقیکردنەوەی کەرەستە پزیشکیەکان',
                              subtitle: 'تاقیکردنەوە لەسەر کەرەستە پزیشکیەکان',
                              icon: 'insturments.png',
                              color: const Color(0xFF4A7EB5),
                              onTap: () => _selectCategory('instruments'),
                              languageProvider: languageProvider,
                              themeProvider: themeProvider,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 50 * (1 - value)),
                          child: Opacity(
                            opacity: value,
                            child: _buildCategoryCard(
                              title: 'تاقیکردنەوەی سلایدەکان',
                              subtitle:
                                  'تاقیکردنەوە لەسەر سلایدە میکرۆسکۆپیەکان',
                              icon: 'slide.png',
                              color: Colors.green,
                              onTap: () => _selectCategory('slides'),
                              languageProvider: languageProvider,
                              themeProvider: themeProvider,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    // Check if user is authenticated
    if (!authProvider.isSignedIn) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                themeProvider.theme.colorScheme.primary.withValues(alpha: 0.1),
                themeProvider.theme.scaffoldBackgroundColor,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Custom App Bar
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.arrow_back,
                          color: themeProvider.theme.colorScheme.onSurface,
                        ),
                      ),
                      Expanded(
                        child: Directionality(
                          textDirection: languageProvider.textDirection,
                          child: Text(
                            'کوێز',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color:
                                  themeProvider.theme.colorScheme.onSurface,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 800),
                            curve: Curves.elasticOut,
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: Container(
                                  padding: const EdgeInsets.all(30),
                                  decoration: BoxDecoration(
                                    color: themeProvider.isDarkMode
                                        ? const Color(0xFF1E1E1E)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withValues(alpha: 0.3),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.lock_outline,
                                        size: 80,
                                        color: themeProvider
                                            .theme.colorScheme.primary,
                                      ),
                                      const SizedBox(height: 20),
                                      Directionality(
                                        textDirection:
                                            languageProvider.textDirection,
                                        child: Text(
                                          'تکایە بۆ بەژداریکردن لەم بەشە پێویستە ئەکاونتت هەبێت',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontFamily: 'Inter',
                                            fontWeight: FontWeight.w600,
                                            color: themeProvider
                                                .theme.colorScheme.onSurface,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      const SizedBox(height: 30),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.pushNamed(
                                              context,
                                              '/login',
                                              arguments: {
                                                'returnRoute': '/quiz'
                                              }, // Pass return route
                                            );
                                          },
                                          icon: const Icon(Icons.login),
                                          label: Directionality(
                                            textDirection:
                                                languageProvider.textDirection,
                                            child: const Text(
                                              'چوونەژوورەوە',
                                              style: TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: themeProvider
                                                .theme.colorScheme.primary,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 16),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            elevation: 3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
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

    // Show category selection if not selected yet
    if (_showCategorySelection) {
      return _buildCategorySelection();
    }

    return Scaffold(
      backgroundColor: themeProvider.theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar with Score
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: themeProvider.isDarkMode
                    ? const Color(0xFF1E1E1E)
                    : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (_totalQuestions > 0) {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            title: const Text(
                              'دەتەوێت بڕۆیتەوە؟',
                              style: TextStyle(fontFamily: 'Inter'),
                            ),
                            content: const Text(
                              'ئەگەر بڕۆیتەوە هەموو پێشکەوتنەکانت لەدەست دەچێت',
                              style: TextStyle(fontFamily: 'Inter'),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text(
                                  'مانەوە',
                                  style: TextStyle(fontFamily: 'Inter'),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  Navigator.of(context).pop();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: const Text(
                                  'دەرچوون',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                    icon: Icon(
                      Icons.arrow_back,
                      color: themeProvider.theme.colorScheme.onSurface,
                    ),
                  ),
                  Expanded(
                    child: Directionality(
                      textDirection: languageProvider.textDirection,
                      child: Text(
                        _selectedCategory == 'instruments'
                            ? 'کەرەستە پزیشکیەکان'
                            : _selectedCategory == 'slides'
                                ? 'سلایدەکان'
                                : 'تاقیکردنەوە',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: themeProvider.theme.colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _resultAnimationController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 0.9 + (_resultScaleAnimation.value * 0.1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                themeProvider.theme.colorScheme.primary,
                                themeProvider.theme.colorScheme.primary
                                    .withValues(alpha: 0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: themeProvider.theme.colorScheme.primary
                                    .withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.stars,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$_currentScore',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Progress Bar
            if (_currentQuestion != null) _buildProgressBar(),

            // Main Content
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: themeProvider.theme.colorScheme.primary,
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'بارکردنی پرسیار...',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _currentQuestion == null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(30),
                                  decoration: BoxDecoration(
                                    color: themeProvider.isDarkMode
                                        ? const Color(0xFF1E1E1E)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withValues(alpha: 0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        size: 60,
                                        color: Colors.orange.shade400,
                                      ),
                                      const SizedBox(height: 20),
                                      Directionality(
                                        textDirection:
                                            languageProvider.textDirection,
                                        child: Text(
                                          'هەڵەیەک ڕووی دا لە بارکردنی پرسیار',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontFamily: 'Inter',
                                            fontWeight: FontWeight.w600,
                                            color: themeProvider
                                                .theme.colorScheme.onSurface,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      ElevatedButton.icon(
                                        onPressed: _loadNewQuestion,
                                        icon: const Icon(Icons.refresh),
                                        label: Directionality(
                                          textDirection:
                                              languageProvider.textDirection,
                                          child: const Text(
                                            'هەوڵ بدەوە',
                                            style:
                                                TextStyle(fontFamily: 'Inter'),
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: themeProvider
                                              .theme.colorScheme.primary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.all(20),
                          child: AnimatedBuilder(
                            animation: _questionFadeAnimation,
                            builder: (context, child) {
                              return Opacity(
                                opacity: _questionFadeAnimation.value,
                                child: SlideTransition(
                                  position: _questionSlideAnimation,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      // Question Image Card
                                      Hero(
                                        tag:
                                            'question_image_${_currentQuestion!.imageUrl}',
                                        child: Container(
                                          height: 280,
                                          decoration: BoxDecoration(
                                            color: themeProvider.isDarkMode
                                                ? const Color(0xFF1E1E1E)
                                                : Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.grey
                                                    .withValues(alpha: 0.15),
                                                spreadRadius: 2,
                                                blurRadius: 15,
                                                offset: const Offset(0, 8),
                                              ),
                                            ],
                                          ),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            child: _currentQuestion!.imageUrl
                                                    .startsWith('assets/')
                                                ? Image.asset(
                                                    _currentQuestion!.imageUrl,
                                                    fit: BoxFit.contain,
                                                    width: double.infinity,
                                                    errorBuilder: (context,
                                                        error, stackTrace) {
                                                      return Container(
                                                        color: themeProvider
                                                                .isDarkMode
                                                            ? Colors.grey[800]
                                                            : Colors.grey[100],
                                                        child: Column(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .image_not_supported,
                                                              size: 50,
                                                              color: Colors
                                                                  .grey[400],
                                                            ),
                                                            const SizedBox(
                                                                height: 10),
                                                            Text(
                                                              'وێنە بەردەست نیە',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .grey[600],
                                                                fontFamily:
                                                                    'Inter',
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                  )
                                                : CachedNetworkImage(
                                                    imageUrl: _resolveImageUrl(_currentQuestion!.imageUrl),
                                                    fit: BoxFit.contain,
                                                    width: double.infinity,
                                                    placeholder: (context, url) => Container(
                                                      color: themeProvider.isDarkMode
                                                          ? Colors.grey[800]
                                                          : Colors.grey[100],
                                                      child: Center(
                                                        child: CircularProgressIndicator(
                                                          color: themeProvider.theme.colorScheme.primary,
                                                        ),
                                                      ),
                                                    ),
                                                    errorWidget: (context, url, error) => Container(
                                                      color: themeProvider.isDarkMode
                                                          ? Colors.grey[800]
                                                          : Colors.grey[100],
                                                      child: Column(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          Icon(
                                                            Icons.image_not_supported,
                                                            size: 50,
                                                            color: Colors.grey[400],
                                                          ),
                                                          const SizedBox(height: 10),
                                                          Text(
                                                            'وێنە بەردەست نیە',
                                                            style: TextStyle(
                                                              color: Colors.grey[600],
                                                              fontFamily: 'Inter',
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 24),

                                      // Question Text Card
                                      Container(
                                        padding: const EdgeInsets.all(24),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              themeProvider
                                                  .theme.colorScheme.primary
                                                  .withValues(alpha: 0.05),
                                              themeProvider
                                                  .theme.colorScheme.primary
                                                  .withValues(alpha: 0.02),
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: themeProvider
                                                .theme.colorScheme.primary
                                                .withValues(alpha: 0.1),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: themeProvider
                                                    .theme.colorScheme.primary,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: _currentQuestion!.type == 'instrument'
                                                  ? Image.asset(
                                                      'assets/Icons/insturments.png',
                                                      width: 24,
                                                      height: 24,
                                                      color: Colors.white,
                                                      errorBuilder: (context, error, stackTrace) {
                                                        return const Icon(
                                                          Icons.medical_services,
                                                          color: Colors.white,
                                                          size: 24,
                                                        );
                                                      },
                                                    )
                                                  : Image.asset(
                                                      'assets/Icons/slide.png',
                                                      width: 24,
                                                      height: 24,
                                                      color: Colors.white,
                                                      errorBuilder: (context, error, stackTrace) {
                                                        return const Icon(
                                                          Icons.biotech,
                                                          color: Colors.white,
                                                          size: 24,
                                                        );
                                                      },
                                                    ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Directionality(
                                                textDirection: languageProvider
                                                    .textDirection,
                                                child: Text(
                                                  _currentQuestion!.type ==
                                                          'instrument'
                                                      ? 'ناوی ئەم کەرەستە پزیشکییە چیە؟'
                                                      : 'ناوی ئەم سلایدە چیە؟',
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontFamily: 'Inter',
                                                    fontWeight: FontWeight.bold,
                                                    color: themeProvider
                                                        .theme
                                                        .colorScheme
                                                        .onSurface,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 24),

                                      // Answer Options
                                      AnimatedBuilder(
                                        animation: _optionAnimationController,
                                        builder: (context, child) {
                                          return Column(
                                            children: _currentQuestion!.options
                                                .asMap()
                                                .entries
                                                .map((entry) {
                                              final index = entry.key;
                                              final option = entry.value;
                                              final isSelected =
                                                  _selectedAnswer == option;
                                              final isCorrect = option ==
                                                  _currentQuestion!
                                                      .correctAnswer;

                                              Color? backgroundColor;
                                              Color? borderColor;
                                              Color? textColor;
                                              IconData? resultIcon;

                                              if (_showResult) {
                                                if (isCorrect) {
                                                  backgroundColor = Colors.green
                                                      .withValues(alpha: 0.1);
                                                  borderColor = Colors.green;
                                                  textColor =
                                                      Colors.green.shade700;
                                                  resultIcon =
                                                      Icons.check_circle;
                                                } else if (isSelected &&
                                                    !isCorrect) {
                                                  backgroundColor = Colors.red
                                                      .withValues(alpha: 0.1);
                                                  borderColor = Colors.red;
                                                  textColor =
                                                      Colors.red.shade700;
                                                  resultIcon = Icons.cancel;
                                                } else {
                                                  backgroundColor =
                                                      themeProvider.isDarkMode
                                                          ? const Color(0xFF1E1E1E)
                                                              .withValues(alpha: 0.5)
                                                          : Colors
                                                              .grey.shade100;
                                                  borderColor =
                                                      Colors.grey.shade400;
                                                  textColor =
                                                      Colors.grey.shade600;
                                                }
                                              } else if (isSelected) {
                                                backgroundColor = themeProvider
                                                    .theme.colorScheme.primary
                                                    .withValues(alpha: 0.1);
                                                borderColor = themeProvider
                                                    .theme.colorScheme.primary;
                                                textColor = themeProvider
                                                    .theme.colorScheme.primary;
                                              }

                                              return AnimatedContainer(
                                                duration: Duration(
                                                    milliseconds:
                                                        200 + (index * 100)),
                                                curve: Curves.easeOutBack,
                                                margin: const EdgeInsets.only(
                                                    bottom: 16),
                                                transform:
                                                    Matrix4.translationValues(
                                                  0,
                                                  (1 -
                                                          _optionAnimationController
                                                              .value) *
                                                      50,
                                                  0,
                                                ),
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    onTap: (_showResult ||
                                                            _isSubmitting)
                                                        ? null
                                                        : () => _submitAnswer(
                                                            option),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                    child: AnimatedContainer(
                                                      duration: const Duration(
                                                          milliseconds: 200),
                                                      padding:
                                                          const EdgeInsets.all(
                                                              20),
                                                      decoration: BoxDecoration(
                                                        color: backgroundColor ??
                                                            (themeProvider
                                                                    .isDarkMode
                                                                ? Colors.grey
                                                                    .shade900
                                                                : Colors.white),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(16),
                                                        border: Border.all(
                                                          color: borderColor ??
                                                              Colors.grey
                                                                  .shade300,
                                                          width: 2,
                                                        ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: (borderColor ??
                                                                    Colors.grey)
                                                                .withValues(alpha: 0.1),
                                                            spreadRadius: 1,
                                                            blurRadius: 8,
                                                            offset:
                                                                const Offset(
                                                                    0, 4),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          AnimatedContainer(
                                                            duration:
                                                                const Duration(
                                                                    milliseconds:
                                                                        200),
                                                            width: 40,
                                                            height: 40,
                                                            decoration:
                                                                BoxDecoration(
                                                              shape: BoxShape
                                                                  .circle,
                                                              color: (borderColor ??
                                                                      Colors
                                                                          .grey
                                                                          .shade400)
                                                                  .withValues(alpha: 0.2),
                                                              border:
                                                                  Border.all(
                                                                color: borderColor ??
                                                                    Colors.grey
                                                                        .shade400,
                                                                width: 2,
                                                              ),
                                                            ),
                                                            child: Center(
                                                              child: Text(
                                                                String.fromCharCode(65 +
                                                                    index), // A, B, C, D
                                                                style:
                                                                    TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: textColor ??
                                                                      themeProvider
                                                                          .theme
                                                                          .colorScheme
                                                                          .onSurface,
                                                                  fontSize: 16,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              width: 16),
                                                          Expanded(
                                                            child:
                                                                Directionality(
                                                              textDirection: option
                                                                      .contains(
                                                                          RegExp(
                                                                              r'[\u0600-\u06FF]'))
                                                                  ? TextDirection
                                                                      .rtl
                                                                  : TextDirection
                                                                      .ltr,
                                                              child:
                                                                  _buildFormattedText(
                                                                option,
                                                                TextStyle(
                                                                  fontSize: 16,
                                                                  fontFamily: option
                                                                          .contains(
                                                                              RegExp(r'[\u0600-\u06FF]'))
                                                                      ? 'Inter'
                                                                      : null,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: textColor ??
                                                                      themeProvider
                                                                          .theme
                                                                          .colorScheme
                                                                          .onSurface,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                          if (_showResult &&
                                                              resultIcon !=
                                                                  null)
                                                            AnimatedScale(
                                                              scale: _showResult
                                                                  ? 1.0
                                                                  : 0.0,
                                                              duration:
                                                                  const Duration(
                                                                      milliseconds:
                                                                          300),
                                                              curve: Curves
                                                                  .elasticOut,
                                                              child: Icon(
                                                                resultIcon,
                                                                color:
                                                                    borderColor,
                                                                size: 28,
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          );
                                        },
                                      ),

                                      const SizedBox(height: 32),

                                      // Next question / finish button
                                      if (_showResult)
                                        AnimatedSlide(
                                          offset: _showResult
                                              ? Offset.zero
                                              : const Offset(0, 1),
                                          duration:
                                              const Duration(milliseconds: 400),
                                          curve: Curves.easeOutBack,
                                          child: AnimatedOpacity(
                                            opacity: _showResult ? 1.0 : 0.0,
                                            duration: const Duration(
                                                milliseconds: 400),
                                            child: Container(
                                              width: double.infinity,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: themeProvider.theme
                                                        .colorScheme.primary
                                                        .withValues(alpha: 0.3),
                                                    blurRadius: 12,
                                                    offset: const Offset(0, 6),
                                                  ),
                                                ],
                                              ),
                                              child: ElevatedButton.icon(
                                                // More explicit check
                                                onPressed: _totalQuestions >=
                                                        _maxQuestions
                                                    ? _finalizeQuiz
                                                    : _loadNewQuestion,
                                                icon: Icon(
                                                  _totalQuestions >=
                                                          _maxQuestions
                                                      ? Icons.flag
                                                      : Icons.arrow_forward,
                                                  size: 20,
                                                ),
                                                label: Directionality(
                                                  textDirection:
                                                      languageProvider
                                                          .textDirection,
                                                  child: Text(
                                                    _totalQuestions >=
                                                            _maxQuestions
                                                        ? 'تەواوکردن'
                                                        : 'پرسیاری داهاتوو',
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontFamily: 'Inter',
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: themeProvider
                                                      .theme
                                                      .colorScheme
                                                      .primary,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 18),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                  ),
                                                  elevation: 0,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),

                                      const SizedBox(height: 20),
                                    ],
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
}
