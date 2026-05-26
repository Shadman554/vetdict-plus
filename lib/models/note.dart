class Note {
  final String name;
  final String? description;
  final String? imageUrl;
  final String? category;

  Note({
    required this.name,
    this.description,
    this.imageUrl,
    this.category,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'category': category,
    };
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      name: json['name'] as String? ?? '',
      description: (json['description'] as String?)?.trim().isEmpty ?? true
          ? null
          : json['description'] as String,
      imageUrl: (json['image_url'] as String?)?.trim().isEmpty ?? true
          ? null
          : json['image_url'] as String,
      category: (json['category'] as String?)?.trim().isEmpty ?? true
          ? null
          : json['category'] as String,
    );
  }
}
