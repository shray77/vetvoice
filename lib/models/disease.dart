import 'package:flutter/foundation.dart';

/// Методическое указание
class MethodologicalInstruction {
  final String code;
  final String description;
  final String note;

  const MethodologicalInstruction({
    required this.code,
    required this.description,
    this.note = '',
  });

  factory MethodologicalInstruction.fromJson(Map<String, dynamic> json) {
    return MethodologicalInstruction(
      code: json['code'] as String? ?? '',
      description: json['description'] as String? ?? '',
      note: json['note'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'description': description,
      'note': note,
    };
  }
}

/// Модель болезни животного
class Disease {
  final num id;
  final String name;
  final String code;
  final String category;
  final List<String> animals;
  final List<String> methods;
  final List<MethodologicalInstruction> mu;
  final List<String> species;

  const Disease({
    required this.id,
    required this.name,
    required this.code,
    required this.category,
    required this.animals,
    this.methods = const [],
    this.mu = const [],
    this.species = const [],
  });

  factory Disease.fromJson(Map<String, dynamic> json) {
    // ⚠️ Фикс B-13: null-safe парсинг.
    return Disease(
      id: json['id'] as num? ?? 0,
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      category: json['category'] as String? ?? '',
      animals: (json['animals'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      methods: (json['methods'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      mu: (json['mu'] as List<dynamic>?)
              ?.map((e) => MethodologicalInstruction.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      species: (json['species'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'category': category,
      'animals': animals,
      'methods': methods,
      'mu': mu.map((m) => m.toJson()).toList(),
      'species': species,
    };
  }

  /// Проверяет, применима ли болезнь к указанному животному
  bool isForAnimal(String animalName) {
    return animals.any((a) => a.toLowerCase() == animalName.toLowerCase() || a == 'Все');
  }

  /// Человекочитаемое название категории
  String get categoryName {
    switch (category) {
      case 'particularly_dangerous':
        return 'Особо опасная';
      case 'infectious':
        return 'Инфекционная';
      case 'invasive':
        return 'Инвазионная';
      case 'fish_diseases':
        return 'Болезнь рыб';
      case 'bee_diseases':
        return 'Болезнь пчел';
      case 'non_contagious':
        return 'Незаразная';
      default:
        return category;
    }
  }

  /// Является ли болезнь особо опасной
  bool get isParticularlyDangerous => category == 'particularly_dangerous';

  @override
  String toString() {
    return 'Disease(id: $id, name: $name, code: $code, category: $category)';
  }
}

/// База данных болезней
class DiseaseDatabase {
  final String version;
  final String source;
  final String description;
  final Map<String, String> categories;
  final List<Disease> diseases;

  const DiseaseDatabase({
    required this.version,
    required this.source,
    required this.description,
    required this.categories,
    required this.diseases,
  });

  factory DiseaseDatabase.fromJson(Map<String, dynamic> json) {
    // ⚠️ Фикс B-13: null-safe парсинг + per-item try/catch.
    final diseasesList = <Disease>[];
    final diseasesRaw = json['diseases'] as List<dynamic>?;
    if (diseasesRaw != null) {
      for (int i = 0; i < diseasesRaw.length; i++) {
        try {
          diseasesList.add(Disease.fromJson(diseasesRaw[i] as Map<String, dynamic>));
        } catch (e) {
          // Игнорируем одну битую запись — остальное база грузится нормально.
          debugPrint('⚠️ Ошибка парсинга болезни #$i: $e');
        }
      }
    }
    // categories может отсутствовать или быть пустым — возвращаем пустой map.
    Map<String, String> categories = {};
    final catRaw = json['categories'];
    if (catRaw is Map) {
      try {
        categories = Map<String, String>.from(catRaw);
      } catch (e) {
        debugPrint('⚠️ Ошибка парсинга categories: $e');
      }
    }
    return DiseaseDatabase(
      version: json['version'] as String? ?? '1.0',
      source: json['source'] as String? ?? 'unknown',
      description: json['description'] as String? ?? '',
      categories: categories,
      diseases: diseasesList,
    );
  }

  /// Получить болезни для конкретного животного
  List<Disease> getDiseasesForAnimal(String animalName) {
    return diseases.where((d) => d.isForAnimal(animalName)).toList();
  }

  /// Получить особо опасные болезни
  List<Disease> getParticularlyDangerousDiseases() {
    return diseases.where((d) => d.isParticularlyDangerous).toList();
  }

  /// Найти болезнь по названию
  Disease? findDiseaseByName(String name) {
    try {
      return diseases.firstWhere(
        (d) => d.name.toLowerCase().contains(name.toLowerCase()),
      );
    } catch (_) {
      return null;
    }
  }

  /// Найти болезнь по коду
  Disease? findDiseaseByCode(String code) {
    try {
      return diseases.firstWhere(
        (d) => d.code.toLowerCase() == code.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }
}
