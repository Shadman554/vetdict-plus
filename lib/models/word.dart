class Word {
  final String id;
  final String name;
  final String kurdish;
  final String arabic;
  final String description;
  final String imageUrl;

  Word({
    required this.id,
    required this.name,
    required this.kurdish,
    required this.arabic,
    required this.description,
    this.imageUrl = '',
  });

  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      kurdish: json['kurdish'] as String? ?? '',
      arabic: json['arabic'] as String? ?? '',
      description: json['description'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'kurdish': kurdish,
      'arabic': arabic,
      'description': description,
      'imageUrl': imageUrl,
    };
  }
}
