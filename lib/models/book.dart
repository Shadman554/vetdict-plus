class Book {
  final String id;
  final String title;
  final String author;
  final String description;
  final String imageUrl;
  final String category;
  final String downloadUrl;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.imageUrl,
    required this.category,
    required this.downloadUrl,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? json['name'] ?? '',
      author: json['author'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['cover_url'] ?? json['image_url'] ?? json['imageUrl'] ?? '',
      category: json['category'] ?? '',
      downloadUrl: json['download_url'] ?? json['downloadUrl'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'author': author,
    'description': description,
    'image_url': imageUrl,
    'category': category,
    'download_url': downloadUrl,
  };
}