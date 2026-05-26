class Instrument {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final String createdAt;
  final String category;

  Instrument({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.createdAt,
    this.category = '',
  });

  String getName(bool isEnglish) => name;
  String getDescription(bool isEnglish) => description;

  factory Instrument.fromJson(Map<String, dynamic> json) {
    return Instrument(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['image_url'] ?? '',
      createdAt: json['created_at'] ?? '',
      category: json['category'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'created_at': createdAt,
      'category': category,
    };
  }

  // Legacy compatibility methods
  factory Instrument.fromMap(Map<String, dynamic> map) {
    return Instrument.fromJson(map);
  }

  Map<String, dynamic> toMap() {
    return toJson();
  }
}
