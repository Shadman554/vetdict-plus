class Test {
  final String? id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? createdAt;

  Test({
    this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.createdAt,
  });

  factory Test.fromJson(Map<String, dynamic> json) {
    return Test(
      id: json['id']?.toString(),
      name: json['name'] as String? ?? '',
      description: (json['description'] as String?)?.trim().isEmpty ?? true
          ? null
          : json['description'] as String,
      imageUrl: (json['image_url'] as String?)?.trim().isEmpty ?? true
          ? null
          : json['image_url'] as String,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'created_at': createdAt,
    };
  }
}
