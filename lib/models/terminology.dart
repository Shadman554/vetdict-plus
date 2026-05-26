import 'package:flutter/material.dart';

enum TerminologyClass {
  antibiotic,
  painkiller,
  antiviral,
  antiparasitic,
  hormone,
  other
}

extension TerminologyClassExtension on TerminologyClass {
  String get displayName {
    switch (this) {
      case TerminologyClass.antibiotic:
        return 'Antibiotics';
      case TerminologyClass.painkiller:
        return 'Painkillers';
      case TerminologyClass.antiviral:
        return 'Antivirals';
      case TerminologyClass.antiparasitic:
        return 'Antiparasitics';
      case TerminologyClass.hormone:
        return 'Hormones';
      case TerminologyClass.other:
        return 'Other';
    }
  }

  Color get color {
    switch (this) {
      case TerminologyClass.antibiotic:
        return const Color(0xFF1A3460);
      case TerminologyClass.painkiller:
        return Colors.red.shade700;
      case TerminologyClass.antiviral:
        return Colors.green.shade700;
      case TerminologyClass.antiparasitic:
        return Colors.purple.shade700;
      case TerminologyClass.hormone:
        return Colors.orange.shade700;
      case TerminologyClass.other:
        return Colors.grey.shade700;
    }
  }
}

class Terminology {
  final String id;
  final String name;
  final String kurdish;
  final String arabic;
  final String description;
  final String imageUrl;

  Terminology({
    required this.id,
    required this.name,
    required this.kurdish,
    required this.arabic,
    required this.description,
    this.imageUrl = '',
  });

  factory Terminology.fromJson(Map<String, dynamic> json) {
    return Terminology(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      kurdish: json['kurdish'] ?? '',
      arabic: json['arabic'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
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
