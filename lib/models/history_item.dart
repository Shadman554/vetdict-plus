class HistoryItem {
  final String title;
  final String type; // 'drug', 'disease', or 'terminology'
  final DateTime timestamp;
  final String description;
  final dynamic data; // Store the complete object (Drug, Disease, or Word)

  HistoryItem({
    required this.title,
    required this.type,
    required this.timestamp,
    required this.description,
    this.data,
  });

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {
      'title': title,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'description': description,
    };
    
    // Store the complete object data
    if (data != null) {
      json['data'] = data.toJson();
    }
    
    return json;
  }

  static HistoryItem fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      title: json['title'],
      type: json['type'],
      timestamp: DateTime.parse(json['timestamp']),
      description: json['description'],
      data: json['data'], // Will be parsed later based on type
    );
  }
}
