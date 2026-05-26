class Disease {
  final String id;
  final String name;
  final String cause;
  final String control;
  final String kurdish;
  final String symptoms;
  final String category;
  final String imageUrl;

  Disease({
    required this.id,
    required this.name,
    required this.cause,
    required this.control,
    required this.kurdish,
    required this.symptoms,
    this.category = '',
    this.imageUrl = '',
  });

  factory Disease.fromJson(Map<String, dynamic> json) {
    return Disease(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      cause: json['cause'] ?? '',
      control: json['control'] ?? '',
      kurdish: json['kurdish'] ?? '',
      symptoms: json['symptoms'] ?? '',
      category: json['category'] ?? '',
      imageUrl: json['imageUrl'] ?? json['image_url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'cause': cause,
      'control': control,
      'kurdish': kurdish,
      'symptoms': symptoms,
      'category': category,
      'imageUrl': imageUrl,
    };
  }
}