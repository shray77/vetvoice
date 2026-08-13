import 'package:flutter/foundation.dart';

/// Пол животного
enum Gender {
  male,
  female,
}

/// Период беременности
enum PregnancyPeriod {
  notPregnant,
  early,    // 1/3 срока
  mid,      // 2/3 срока
  late,     // 3/3 срока (перед родами)
}

/// Возрастная категория
enum AgeCategory {
  young,    // Молодняк
  adult,    // Взрослое
  old,      // Пожилое
}

/// Расширение для Gender
extension GenderExtension on Gender {
  String get displayName {
    switch (this) {
      case Gender.male:
        return 'Самец';
      case Gender.female:
        return 'Самка';
    }
  }

  String get icon {
    switch (this) {
      case Gender.male:
        return '♂';
      case Gender.female:
        return '♀';
    }
  }
}

/// Расширение для PregnancyPeriod
extension PregnancyPeriodExtension on PregnancyPeriod {
  String get displayName {
    switch (this) {
      case PregnancyPeriod.notPregnant:
        return 'Не беременна';
      case PregnancyPeriod.early:
        return 'Ранний срок (1/3)';
      case PregnancyPeriod.mid:
        return 'Средний срок (2/3)';
      case PregnancyPeriod.late:
        return 'Поздний срок (3/3)';
    }
  }

  bool get isPregnant => this != PregnancyPeriod.notPregnant;
}

/// Расширение для AgeCategory
extension AgeCategoryExtension on AgeCategory {
  String get displayName {
    switch (this) {
      case AgeCategory.young:
        return 'Молодняк';
      case AgeCategory.adult:
        return 'Взрослое';
      case AgeCategory.old:
        return 'Пожилое';
    }
  }
}

/// Противопоказания препарата
class Contraindications {
  final bool pregnancy;           // Противопоказан при беременности
  final bool lactation;           // Противопоказан при лактации
  final bool young;               // Противопоказан молодняку
  final bool old;                 // Осторожно для пожилых
  final List<String> warnings;    // Дополнительные предупреждения

  const Contraindications({
    this.pregnancy = false,
    this.lactation = false,
    this.young = false,
    this.old = false,
    this.warnings = const [],
  });

  factory Contraindications.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const Contraindications();
    return Contraindications(
      pregnancy: json['pregnancy'] as bool? ?? false,
      lactation: json['lactation'] as bool? ?? false,
      young: json['young'] as bool? ?? false,
      old: json['old'] as bool? ?? false,
      warnings: (json['warnings'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pregnancy': pregnancy,
      'lactation': lactation,
      'young': young,
      'old': old,
      'warnings': warnings,
    };
  }
}

/// Корректировка дозы
class DoseAdjustment {
  final double? youngMultiplier;   // Множитель для молодняка
  final double? oldMultiplier;     // Множитель для пожилых
  final double? pregnancyMultiplier; // Множитель для беременных

  const DoseAdjustment({
    this.youngMultiplier,
    this.oldMultiplier,
    this.pregnancyMultiplier,
  });

  factory DoseAdjustment.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const DoseAdjustment();
    return DoseAdjustment(
      youngMultiplier: (json['young_multiplier'] as num?)?.toDouble(),
      oldMultiplier: (json['old_multiplier'] as num?)?.toDouble(),
      pregnancyMultiplier: (json['pregnancy_multiplier'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (youngMultiplier != null) 'young_multiplier': youngMultiplier,
      if (oldMultiplier != null) 'old_multiplier': oldMultiplier,
      if (pregnancyMultiplier != null) 'pregnancy_multiplier': pregnancyMultiplier,
    };
  }
}

/// Модель препарата для базы данных VetVoice AI
class Drug {
  final int id;
  final String name;
  final double dose;
  final String unit;
  final List<String> animals;
  final String method;
  final String methodShort;
  final String activeIngredient;
  final int withdrawalDays;
  final String description;
  final Contraindications contraindications;
  final DoseAdjustment doseAdjustment;

  const Drug({
    required this.id,
    required this.name,
    required this.dose,
    this.unit = 'ml/kg',
    required this.animals,
    required this.method,
    this.methodShort = '',
    this.activeIngredient = '',
    this.withdrawalDays = 0,
    this.description = '',
    this.contraindications = const Contraindications(),
    this.doseAdjustment = const DoseAdjustment(),
  });

  factory Drug.fromJson(Map<String, dynamic> json) {
    // ⚠️ Фикс B-13: null-safe парсинг. Раньше 'as int'/'as String'/'as num'
    // кидали TypeError на одном битом поле, что приводило к потере всего файла
    // (вышестоящий try/catch в DrugLoaderService._loadFromAssets дискардил весь JSON).
    // Теперь каждое поле имеет безопасный fallback.
    return Drug(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      dose: (json['dose'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] as String? ?? 'ml/kg',
      animals: (json['animals'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      method: json['method'] as String? ?? '',
      methodShort: json['method_short'] as String? ?? '',
      activeIngredient: json['active_ingredient'] as String? ?? '',
      withdrawalDays: (json['withdrawal_days'] as num?)?.toInt() ?? 0,
      description: json['description'] as String? ?? '',
      contraindications: Contraindications.fromJson(
          json['contraindications'] as Map<String, dynamic>?),
      doseAdjustment: DoseAdjustment.fromJson(
          json['dose_adjustment'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'dose': dose,
      'unit': unit,
      'animals': animals,
      'method': method,
      'method_short': methodShort,
      'active_ingredient': activeIngredient,
      'withdrawal_days': withdrawalDays,
      'description': description,
      'contraindications': contraindications.toJson(),
      'dose_adjustment': doseAdjustment.toJson(),
    };
  }

  /// Проверяет, подходит ли препарат для указанного животного
  bool isForAnimal(String animalName) {
    return animals.any((a) => a.toLowerCase() == animalName.toLowerCase());
  }

  /// Рассчитывает дозу с учетом корректировок
  double calculateDose(double weightKg, {AgeCategory? age, bool isPregnant = false}) {
    double multiplier = 1.0;

    if (age == AgeCategory.young && doseAdjustment.youngMultiplier != null) {
      multiplier = doseAdjustment.youngMultiplier!;
    } else if (age == AgeCategory.old && doseAdjustment.oldMultiplier != null) {
      multiplier = doseAdjustment.oldMultiplier!;
    }

    if (isPregnant && doseAdjustment.pregnancyMultiplier != null) {
      multiplier *= doseAdjustment.pregnancyMultiplier!;
    }

    return dose * weightKg * multiplier;
  }

  /// Проверяет противопоказания для заданных условий
  List<String> checkContraindications({
    Gender? gender,
    PregnancyPeriod? pregnancy,
    AgeCategory? age,
  }) {
    final warnings = <String>[];

    // Проверка беременности
    if (gender == Gender.female && pregnancy != null && pregnancy.isPregnant) {
      if (contraindications.pregnancy) {
        warnings.add('⚠️ ПРОТИВОПОКАЗАН при беременности!');
      }
      if (pregnancy == PregnancyPeriod.late) {
        warnings.add('⚠️ Осторожно: поздний срок беременности');
      }
    }

    // Проверка лактации (упрощенно - после родов)
    if (gender == Gender.female && pregnancy == PregnancyPeriod.notPregnant) {
      // Можно добавить отдельное поле для лактации
    }

    // Проверка возраста
    if (age == AgeCategory.young && contraindications.young) {
      warnings.add('⚠️ Противопоказан молодняку!');
    }
    if (age == AgeCategory.old && contraindications.old) {
      warnings.add('⚠️ С осторожностью для пожилых животных');
    }

    // Дополнительные предупреждения
    warnings.addAll(contraindications.warnings);

    return warnings;
  }

  @override
  String toString() {
    return 'Drug(id: $id, name: $name, dose: $dose $unit)';
  }
}

/// Модель животного с ограничениями
class Animal {
  final String id;
  final String name;
  final String icon;
  final String description;
  final double minWeight;
  final double maxWeight;
  final String weightHint;
  final String pregnancyTerm;      // Название беременности (стельность, сукотность и т.д.)
  final int gestationDays;         // Срок беременности в днях
  final List<AgeGroup> ageGroups;  // Возрастные группы
  final bool hasGender;           // Нужно ли выбирать пол (пчёлам, рыбе — нет)

  const Animal({
    required this.id,
    required this.name,
    required this.icon,
    this.description = '',
    this.minWeight = 0.1,
    this.maxWeight = 2000,
    this.weightHint = '',
    this.pregnancyTerm = 'Беременность',
    this.gestationDays = 280,
    this.ageGroups = const [],
    this.hasGender = true,
  });

  factory Animal.fromJson(Map<String, dynamic> json) {
    // ⚠️ Фикс B-13: null-safe парсинг с fallback на пустые значения.
    return Animal(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      description: json['description'] as String? ?? '',
      minWeight: (json['min_weight'] as num?)?.toDouble() ?? 0.1,
      maxWeight: (json['max_weight'] as num?)?.toDouble() ?? 2000,
      weightHint: json['weight_hint'] as String? ?? '',
      pregnancyTerm: json['pregnancy_term'] as String? ?? 'Беременность',
      gestationDays: (json['gestation_days'] as num?)?.toInt() ?? 280,
      ageGroups: (json['age_groups'] as List<dynamic>?)
              ?.map((e) => AgeGroup.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      hasGender: json['has_gender'] as bool? ?? true,
    );
  }

  /// Получить возрастную категорию по возрасту в месяцах
  AgeCategory getAgeCategory(int ageMonths) {
    for (final group in ageGroups) {
      if (ageMonths <= group.maxMonths) {
        return group.category;
      }
    }
    return AgeCategory.old;
  }

  /// Проверяет, находится ли вес в допустимом диапазоне
  WeightValidationResult validateWeight(double weight) {
    if (weight <= 0) {
      return WeightValidationResult(
        isValid: false,
        error: 'Укажите вес животного',
        level: ValidationLevel.error,
      );
    }

    if (weight < minWeight) {
      return WeightValidationResult(
        isValid: false,
        error: 'Слишком маленький вес для $name! Минимум: ${minWeight.toStringAsFixed(1)} кг',
        level: ValidationLevel.error,
        hint: weightHint,
      );
    }

    if (weight > maxWeight) {
      return WeightValidationResult(
        isValid: false,
        error: 'Слишком большой вес для $name! Максимум: ${maxWeight.toStringAsFixed(0)} кг',
        level: ValidationLevel.error,
        hint: weightHint,
      );
    }

    // Предупреждения о необычном весе
    if (minWeight > 1 && weight < minWeight * 2) {
      return WeightValidationResult(
        isValid: true,
        warning: 'Вес на нижней границе нормы для $name',
        level: ValidationLevel.warning,
        hint: weightHint,
      );
    }

    if (weight > maxWeight * 0.8) {
      return WeightValidationResult(
        isValid: true,
        warning: 'Вес на верхней границе нормы для $name',
        level: ValidationLevel.warning,
        hint: weightHint,
      );
    }

    return WeightValidationResult(
      isValid: true,
      level: ValidationLevel.ok,
    );
  }

  @override
  String toString() {
    return 'Animal(id: $id, name: $name, weight: $minWeight-$maxWeight kg)';
  }
}

/// Возрастная группа
class AgeGroup {
  final String name;
  final AgeCategory category;
  final int maxMonths;
  final String description;

  const AgeGroup({
    required this.name,
    required this.category,
    required this.maxMonths,
    this.description = '',
  });

  factory AgeGroup.fromJson(Map<String, dynamic> json) {
    // ⚠️ Фикс B-13: null-safe парсинг.
    return AgeGroup(
      name: json['name'] as String? ?? '',
      category: AgeCategory.values.firstWhere(
        (e) => e.name == (json['category'] as String? ?? 'adult'),
        orElse: () => AgeCategory.adult,
      ),
      maxMonths: (json['max_months'] as num?)?.toInt() ?? 120,
      description: json['description'] as String? ?? '',
    );
  }
}

/// Результат валидации веса
class WeightValidationResult {
  final bool isValid;
  final String error;
  final String warning;
  final String hint;
  final ValidationLevel level;

  const WeightValidationResult({
    required this.isValid,
    required this.level,
    this.error = '',
    this.warning = '',
    this.hint = '',
  });

  bool get hasError => error.isNotEmpty;
  bool get hasWarning => warning.isNotEmpty;
  bool get hasHint => hint.isNotEmpty;
}

/// Уровень валидации
enum ValidationLevel {
  ok,
  warning,
  error,
}

/// Модель базы данных препаратов
class DrugDatabase {
  final String version;
  final String source;
  final String lastUpdated;
  final List<Drug> drugs;
  final List<Animal> animals;

  const DrugDatabase({
    required this.version,
    required this.source,
    required this.lastUpdated,
    required this.drugs,
    required this.animals,
  });

  factory DrugDatabase.fromJson(Map<String, dynamic> json) {
    // ⚠️ Фикс B-13: null-safe парсинг + per-item try/catch.
    // Один битый препарат/животное больше не убивает весь файл.
    final drugsList = <Drug>[];
    final drugsRaw = json['drugs'] as List<dynamic>?;
    if (drugsRaw != null) {
      for (int i = 0; i < drugsRaw.length; i++) {
        try {
          drugsList.add(Drug.fromJson(drugsRaw[i] as Map<String, dynamic>));
        } catch (e) {
          debugPrint('⚠️ Ошибка парсинга препарата #$i: $e');
        }
      }
    }
    final animalsList = <Animal>[];
    final animalsRaw = json['animals'] as List<dynamic>?;
    if (animalsRaw != null) {
      for (int i = 0; i < animalsRaw.length; i++) {
        try {
          animalsList.add(Animal.fromJson(animalsRaw[i] as Map<String, dynamic>));
        } catch (e) {
          debugPrint('⚠️ Ошибка парсинга животного #$i: $e');
        }
      }
    }
    return DrugDatabase(
      version: json['version'] as String? ?? '1.0',
      source: json['source'] as String? ?? 'unknown',
      lastUpdated: json['last_updated'] as String? ?? '',
      drugs: drugsList,
      animals: animalsList,
    );
  }

  /// Получить препараты для конкретного животного
  List<Drug> getDrugsForAnimal(String animalName) {
    return drugs.where((d) => d.isForAnimal(animalName)).toList();
  }

  /// Получить животное по ID
  Animal? getAnimalById(String id) {
    try {
      return animals.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Найти препарат по названию
  Drug? findDrugByName(String name) {
    try {
      return drugs.firstWhere(
        (d) => d.name.toLowerCase().contains(name.toLowerCase()),
      );
    } catch (_) {
      return null;
    }
  }
}
