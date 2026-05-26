class NotificationModel {
  final String id; // Changed from int to String to match your API
  final String title;
  final String content;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {

    try {
      final notification = NotificationModel(
        id: json['id']?.toString() ?? '', // Convert to String
        title: json['title'] ?? '',
        content: json['body'] ?? json['content'] ?? '', // Your API uses 'body' instead of 'content'
        type: json['type'] ?? _inferTypeFromContent(json['title'] ?? '', json['body'] ?? ''), // Use API type field first, then infer
        isRead: _parseBool(json['is_read']) ?? false, // Handle string/bool conversion
        createdAt: () {
          final timestampStr = json['timestamp'] ?? json['created_at'] ?? DateTime.now().toIso8601String();
          // API sends UTC timestamps without 'Z' suffix, so we need to treat them as UTC
          final parsedDateTime = DateTime.parse(timestampStr);
          // If the timestamp doesn't have timezone info, treat it as UTC and convert to local
          if (!timestampStr.contains('Z') && !timestampStr.contains('+') && !timestampStr.contains('-')) {
            return DateTime.utc(
              parsedDateTime.year,
              parsedDateTime.month,
              parsedDateTime.day,
              parsedDateTime.hour,
              parsedDateTime.minute,
              parsedDateTime.second,
              parsedDateTime.millisecond,
              parsedDateTime.microsecond,
            ).toLocal();
          }
          return parsedDateTime;
        }(), // Your API uses 'timestamp'
      );

      return notification;
    } catch (e) {

      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'type': type,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  NotificationModel copyWith({
    String? id, // Changed from int to String
    String? title,
    String? content,
    String? type,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Helper method to infer notification type from content
  static String _inferTypeFromContent(String title, String body) {
    final content = '$title $body'.toLowerCase();

    
    if (content.contains('drug') || content.contains('medicine') || content.contains('دەرمان') || content.contains('دەوا')) {

      return 'drug';
    } else if (content.contains('disease') || content.contains('illness') || content.contains('نەخۆشی') || content.contains('دەرد')) {

      return 'diseases';
    } else if (content.contains('book') || content.contains('کتێب') || content.contains('پەرتووک')) {

      return 'books';
    } else if (content.contains('terminology') || content.contains('term') || content.contains('زاراوە') || content.contains('تێرم')) {

      return 'terminology';
    } else if (content.contains('slide') || content.contains('presentation') || content.contains('سلاید') || content.contains('پێشکەش')) {

      return 'slides';
    } else if (content.contains('test') || content.contains('exam') || content.contains('تاقیکردنەوە') || content.contains('پشکنین')) {

      return 'tests';
    } else if (content.contains('note') || content.contains('تێبینی') || content.contains('نۆت')) {

      return 'notes';
    } else if (content.contains('instrument') || content.contains('tool') || content.contains('ئامێر') || content.contains('کەرەستە')) {

      return 'instruments';
    } else if (content.contains('normal range') || content.contains('reference') || content.contains('نۆرماڵ رێنج') || content.contains('ئاسایی')) {

      return 'normal ranges';
    } else {

      return 'general';
    }
  }

  // Helper method to parse boolean values that might come as strings from API
  static bool? _parseBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true';
    }
    return null;
  }
}
