/// Пол животного
enum Gender {
  male,
  female,
}

/// Период беременности
enum PregnancyPeriod {
  notPregnant,
  early, // 1/3 срока
  mid, // 2/3 срока
  late, // 3/3 срока (перед родами)
}

/// Возрастная категория
enum AgeCategory {
  young, // Молодняк
  adult, // Взрослое
  old, // Пожилое
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

/// Уровень валидации веса
enum ValidationLevel {
  ok,
  warning,
  error,
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

/// Модель животного с ограничениями
class Animal {
  final String id;
  final String name;
  final String icon;
  final String description;
  final double minWeight;
  final double maxWeight;
  final String weightHint;
  final String pregnancyTerm; // Название беременности (стельность, сукотность и т.д.)
  final int gestationDays; // Срок беременности в днях
  final List<AgeGroup> ageGroups; // Возрастные группы
  final bool hasGender; // Нужно ли выбирать пол (пчёлам, рыбе — нет)

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
      return const WeightValidationResult(
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

    return const WeightValidationResult(
      isValid: true,
      level: ValidationLevel.ok,
    );
  }

  @override
  String toString() {
    return 'Animal(id: $id, name: $name, weight: $minWeight-$maxWeight kg)';
  }
}
