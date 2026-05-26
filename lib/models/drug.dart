class Drug {
  final String id;
  final String name;
  final String description;
  final String otherInfo;
  final String sideEffect;
  final String usage;
  final String drugClass;
  final String kurdish;
  final String category;
  final String imageUrl;
  final String withdrawalTimes;
  final String drugInteractions;
  final String contraindications;
  final String speciesDosages;
  final String tradeNames;

  Drug({
    required this.id,
    required this.name,
    required this.description,
    required this.kurdish,
    this.category = '',
    this.otherInfo = '',
    this.sideEffect = '',
    this.usage = '',
    this.drugClass = '',
    this.imageUrl = '',
    this.withdrawalTimes = '',
    this.drugInteractions = '',
    this.contraindications = '',
    this.speciesDosages = '',
    this.tradeNames = '',
  });

  factory Drug.fromJson(Map<String, dynamic> json) {
    return Drug(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? json['drug_name'] ?? '',
      description: json['description'] ?? '',
      otherInfo: json['otherInfo'] ?? json['other_info'] ?? '',
      sideEffect: json['sideEffect'] ?? json['side_effect'] ?? '',
      usage: json['usage'] ?? json['use'] ?? '',
      drugClass: json['drug_class'] ?? json['class'] ?? '',
      kurdish: json['kurdish'] ?? '',
      category: json['category'] ?? '',
      imageUrl: json['imageUrl'] ?? json['image_url'] ?? '',
      withdrawalTimes: json['withdrawalTimes'] ?? json['withdrawal_times'] ?? '',
      drugInteractions: json['drugInteractions'] ?? json['drug_interactions'] ?? '',
      contraindications: json['contraindications'] ?? '',
      speciesDosages: json['speciesDosages'] ?? json['species_dosages'] ?? '',
      tradeNames: json['tradeNames'] ?? json['trade_names'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'class': drugClass,
      'description': description,
      'usage': usage,
      'sideEffect': sideEffect,
      'contraindications': contraindications,
      'drug_interactions': drugInteractions,
      'withdrawal_times': withdrawalTimes,
      'species_dosages': speciesDosages,
      'trade_names': tradeNames,
      'otherInfo': otherInfo,
      'kurdish': kurdish,
      'imageUrl': imageUrl,
    };
  }
}