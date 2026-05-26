import 'dart:math';
import '../models/quiz_question.dart';
import '../models/instrument.dart';
import '../models/slide.dart';
import '../services/api_service.dart';

class QuizService {
  static final QuizService _instance = QuizService._internal();
  factory QuizService() => _instance;
  QuizService._internal();

  List<Instrument> _instruments = [];
  List<Slide> _slides = [];
  bool _isLoaded = false;

  Future<void> _loadData() async {
    if (_isLoaded) return;

    try {
      final apiService = ApiService();
      
      // Load instruments from API
      _instruments = await apiService.fetchAllInstruments();
      
      // Load slides from all categories
      final urineSlides = await apiService.fetchUrineSlides();
      final stoolSlides = await apiService.fetchStoolSlides();
      final otherSlides = await apiService.fetchOtherSlides();
      
      _slides = [...urineSlides, ...stoolSlides, ...otherSlides];
      
      _isLoaded = true;
    } catch (e) {

      // Set empty lists if API fails
      _instruments = [];
      _slides = [];
      _isLoaded = true;
    }
  }

  Future<QuizQuestion> generateRandomQuestion() async {
    await _loadData();
    
    final random = Random();
    final useInstrument = random.nextBool();
    
    if (useInstrument && _instruments.isNotEmpty) {
      return await generateInstrumentQuestion();
    } else if (_slides.isNotEmpty) {
      return await generateSlideQuestion();
    } else {
      return await generateInstrumentQuestion(); // fallback
    }
  }

  Future<QuizQuestion> generateInstrumentQuestion() async {
    await _loadData();
    if (_instruments.isEmpty) {
      throw Exception('No instruments available for quiz');
    }
    
    final random = Random();
    final correctInstrument = _instruments[random.nextInt(_instruments.length)];
    
    // Get 3 other random instruments for incorrect options
    final otherInstruments = List<Instrument>.from(_instruments)
      ..remove(correctInstrument)
      ..shuffle();
    
    final incorrectOptions = otherInstruments
        .take(3)
        .map((instrument) => instrument.getName(false)) // Use Kurdish names
        .toList();
    
    final allOptions = [
      correctInstrument.getName(false), // Use Kurdish name
      ...incorrectOptions,
    ]..shuffle();

    return QuizQuestion(
      id: correctInstrument.id,
      imageUrl: correctInstrument.imageUrl,
      correctAnswer: correctInstrument.getName(false),
      options: allOptions,
      type: 'instrument',
    );
  }

  Future<QuizQuestion> generateSlideQuestion() async {
    await _loadData();
    if (_slides.isEmpty) {
      throw Exception('No slides available for quiz');
    }
    
    final random = Random();
    final correctSlide = _slides[random.nextInt(_slides.length)];
    
    // Get 3 other random slides for incorrect options
    final otherSlides = List<Slide>.from(_slides)
      ..remove(correctSlide)
      ..shuffle();
    
    final incorrectOptions = otherSlides
        .take(3)
        .map((slide) => slide.name)
        .toList();
    
    final allOptions = [
      correctSlide.name,
      ...incorrectOptions,
    ]..shuffle();

    return QuizQuestion(
      id: correctSlide.id,
      imageUrl: correctSlide.imageUrl,
      correctAnswer: correctSlide.name,
      options: allOptions,
      type: 'slide',
    );
  }
}
