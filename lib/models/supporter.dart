class Supporter {
  final String? id;
  final String name;
  final String title;
  final String? color;
  final String? icon;
  final String? imageUrl;
  final String? description;
  final int? displayOrder;
  final String? createdAt;
  final String? updatedAt;

  Supporter({
    this.id,
    required this.name,
    required this.title,
    this.color,
    this.icon,
    this.imageUrl,
    this.description,
    this.displayOrder,
    this.createdAt,
    this.updatedAt,
  });

  factory Supporter.fromJson(Map<String, dynamic> json) {
    return Supporter(
      id: json['id']?.toString(),
      name: json['name'] as String? ?? '',
      title: json['title'] as String? ?? '',
      color: json['color'] as String?,
      icon: json['icon'] as String?,
      imageUrl: json['image_url'] as String?,
      description: json['description'] as String?,
      displayOrder: json['display_order'] as int?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'title': title,
      'color': color,
      'icon': icon,
      'image_url': imageUrl,
      'description': description,
      'display_order': displayOrder,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
