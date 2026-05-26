
class QuizQuestion {
  final String id;
  final String imageUrl;
  final String correctAnswer;
  final List<String> options;
  final String type; // 'instrument' or 'slide'

  QuizQuestion({
    required this.id,
    required this.imageUrl,
    required this.correctAnswer,
    required this.options,
    required this.type,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      id: json['id']?.toString() ?? '',
      imageUrl: json['image_url'] ?? '',
      correctAnswer: json['correct_answer'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      type: json['type'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'image_url': imageUrl,
      'correct_answer': correctAnswer,
      'options': options,
      'type': type,
    };
  }
}
