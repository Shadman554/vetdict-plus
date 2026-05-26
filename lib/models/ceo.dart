class CEO {
  final String? id;
  final String name;
  final String role;
  final String description;
  final String? color;
  final String? imageUrl;
  final String? facebookUrl;
  final String? instagramUrl;
  final String? viberUrl;
  final int? displayOrder;
  final String? createdAt;
  final String? updatedAt;

  CEO({
    this.id,
    required this.name,
    required this.role,
    required this.description,
    this.color,
    this.imageUrl,
    this.facebookUrl,
    this.instagramUrl,
    this.viberUrl,
    this.displayOrder,
    this.createdAt,
    this.updatedAt,
  });

  factory CEO.fromJson(Map<String, dynamic> json) {
    return CEO(
      id: json['id']?.toString(),
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? '',
      description: json['description'] as String? ?? '',
      color: json['color'] as String?,
      imageUrl: json['image_url'] as String?,
      facebookUrl: json['facebook_url'] as String?,
      instagramUrl: json['instagram_url'] as String?,
      viberUrl: json['viber_url'] as String?,
      displayOrder: json['display_order'] as int?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'description': description,
      'color': color,
      'image_url': imageUrl,
      'facebook_url': facebookUrl,
      'instagram_url': instagramUrl,
      'viber_url': viberUrl,
      'display_order': displayOrder,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
