class Slide {
  final String id;
  final String name;
  final String species;
  final String imageUrl;
  final String createdAt;

  Slide({
    required this.id,
    required this.name,
    required this.species,
    required this.imageUrl,
    required this.createdAt,
  });

  factory Slide.fromJson(Map<String, dynamic> json) {
    return Slide(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      species: json['species'] ?? '',
      imageUrl: json['image_url'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'species': species,
      'image_url': imageUrl,
      'created_at': createdAt,
    };
  }
}
