class NormalRange {
  final String id;
  final String name;
  final String? parameter;
  final String unit;
  final String minValue;
  final String maxValue;
  final String? panicLow;
  final String? panicHigh;
  final String? notes;
  final String? reference;
  final String? category;
  final String? species;
  final String? sex;
  final String? ageRange;
  final String? description;
  final String? imageUrl;

  NormalRange({
    required this.id,
    required this.name,
    this.parameter,
    required this.unit,
    required this.minValue,
    required this.maxValue,
    this.panicLow,
    this.panicHigh,
    this.notes,
    this.reference,
    this.category,
    this.species,
    this.sex,
    this.ageRange,
    this.description,
    this.imageUrl,
  });

  factory NormalRange.fromJson(Map<String, dynamic> json) {
    return NormalRange(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      parameter: json['parameter'],
      unit: json['unit'] ?? '',
      minValue: json['min_value']?.toString() ?? '',
      maxValue: json['max_value']?.toString() ?? '',
      panicLow: json['panic_low']?.toString(),
      panicHigh: json['panic_high']?.toString(),
      notes: json['note'],
      reference: json['reference'],
      category: json['category'],
      species: json['species'],
      sex: json['sex'],
      ageRange: json['age_range'],
      description: json['description'],
      imageUrl: json['image_url'],
    );
  }

  factory NormalRange.fromMap(String id, Map<String, dynamic> data) {
    return NormalRange(
      id: id,
      name: data['name'] ?? '',
      parameter: data['parameter'],
      unit: data['unit'] ?? '',
      minValue: data['min_value']?.toString() ?? '',
      maxValue: data['max_value']?.toString() ?? '',
      panicLow: data['panic_low']?.toString(),
      panicHigh: data['panic_high']?.toString(),
      notes: data['note'],
      reference: data['reference'],
      category: data['category'],
      species: data['species'],
      sex: data['sex'],
      ageRange: data['age_range'],
      description: data['description'],
      imageUrl: data['image_url'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'unit': unit,
      'minValue': minValue,
      'maxValue': maxValue,
      'notes': notes,
      'category': category,
      'species': species,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'parameter': parameter,
      'unit': unit,
      'min_value': minValue,
      'max_value': maxValue,
      'panic_low': panicLow,
      'panic_high': panicHigh,
      'note': notes,
      'reference': reference,
      'category': category,
      'species': species,
      'sex': sex,
      'age_range': ageRange,
      'description': description,
      'image_url': imageUrl,
    };
  }
}
