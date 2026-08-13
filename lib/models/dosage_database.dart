/// База дозировок активных веществ (МНН)
class DosageDatabase {
  final String version;
  final String description;
  final String lastUpdated;
  final Map<String, ActiveSubstanceDosage> dosages;

  const DosageDatabase({
    required this.version,
    required this.description,
    required this.lastUpdated,
    required this.dosages,
  });

  factory DosageDatabase.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>? ?? {};
    final dosagesRaw = json['dosages'] as Map<String, dynamic>? ?? {};

    return DosageDatabase(
      version: meta['version'] as String? ?? '1.0.0',
      description: meta['description'] as String? ?? '',
      lastUpdated: meta['last_updated'] as String? ?? '',
      dosages: dosagesRaw.map((key, value) =>
        MapEntry(key, ActiveSubstanceDosage.fromJson(value as Map<String, dynamic>))),
    );
  }

  /// Найти дозировку по МНН (регистронезависимый поиск)
  ActiveSubstanceDosage? findByInn(String inn) {
    final lowerInn = inn.toLowerCase().trim();

    // Прямой поиск
    if (dosages.containsKey(lowerInn)) {
      return dosages[lowerInn];
    }

    // Поиск по частичному совпадению
    for (final entry in dosages.entries) {
      if (entry.key.toLowerCase() == lowerInn) {
        return entry.value;
      }
      // Проверяем, входит ли МНН препарата в ключ базы
      if (entry.key.toLowerCase().contains(lowerInn) ||
          lowerInn.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }

    return null;
  }

  /// Найти дозировку по нескольким активным веществам
  /// Возвращает первую найденную
  ActiveSubstanceDosage? findByInnList(List<String> innList) {
    for (final inn in innList) {
      final found = findByInn(inn);
      if (found != null) return found;
    }
    return null;
  }

  /// Получить список всех МНН
  List<String> get allInn => dosages.keys.toList();
}

/// Дозировка активного вещества для разных животных
class ActiveSubstanceDosage {
  final AnimalDosage? dogs;
  final AnimalDosage? cats;
  final AnimalDosage? cattle;
  final AnimalDosage? pigs;
  final AnimalDosage? sheep;
  final AnimalDosage? horses;
  final AnimalDosage? poultry;

  const ActiveSubstanceDosage({
    this.dogs,
    this.cats,
    this.cattle,
    this.pigs,
    this.sheep,
    this.horses,
    this.poultry,
  });

  factory ActiveSubstanceDosage.fromJson(Map<String, dynamic> json) {
    return ActiveSubstanceDosage(
      dogs: json['dogs'] != null
          ? AnimalDosage.fromJson(json['dogs'] as Map<String, dynamic>)
          : null,
      cats: json['cats'] != null
          ? AnimalDosage.fromJson(json['cats'] as Map<String, dynamic>)
          : null,
      cattle: json['cattle'] != null
          ? AnimalDosage.fromJson(json['cattle'] as Map<String, dynamic>)
          : null,
      pigs: json['pigs'] != null
          ? AnimalDosage.fromJson(json['pigs'] as Map<String, dynamic>)
          : null,
      sheep: json['sheep'] != null
          ? AnimalDosage.fromJson(json['sheep'] as Map<String, dynamic>)
          : null,
      horses: json['horses'] != null
          ? AnimalDosage.fromJson(json['horses'] as Map<String, dynamic>)
          : null,
      poultry: json['poultry'] != null
          ? AnimalDosage.fromJson(json['poultry'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Получить дозировку по имени животного
  AnimalDosage? getForAnimal(String animalName) {
    final lower = animalName.toLowerCase();
    if (lower.contains('собак') || lower.contains('dog')) return dogs;
    if (lower.contains('кошк') || lower.contains('cat')) return cats;
    if (lower.contains('крс') || lower.contains('cattle') || lower.contains('коро')) return cattle;
    if (lower.contains('свин') || lower.contains('pig')) return pigs;
    if (lower.contains('овц') || lower.contains('sheep')) return sheep;
    if (lower.contains('лошад') || lower.contains('horse')) return horses;
    if (lower.contains('птиц') || lower.contains('poultry') || lower.contains('куриц')) return poultry;
    return null;
  }

  /// Список животных, для которых есть дозировка
  List<String> get availableAnimals {
    final list = <String>[];
    if (dogs != null) list.add('Собаки');
    if (cats != null) list.add('Кошки');
    if (cattle != null) list.add('КРС');
    if (pigs != null) list.add('Свиньи');
    if (sheep != null) list.add('Овцы');
    if (horses != null) list.add('Лошади');
    if (poultry != null) list.add('Птица');
    return list;
  }
}

/// Дозировка для конкретного животного
class AnimalDosage {
  final double doseMgKg;       // мг/кг
  final double doseMlKg;       // мл/кг (для наружных)
  final double doseIuKg;       // МЕ/кг (для инсулина и др.)
  final double doseMcgKg;      // мкг/кг
  final String frequency;
  final String route;
  final String notes;

  const AnimalDosage({
    this.doseMgKg = 0,
    this.doseMlKg = 0,
    this.doseIuKg = 0,
    this.doseMcgKg = 0,
    this.frequency = '',
    this.route = '',
    this.notes = '',
  });

  factory AnimalDosage.fromJson(Map<String, dynamic> json) {
    return AnimalDosage(
      doseMgKg: (json['dose_mg_kg'] as num?)?.toDouble() ?? 0,
      doseMlKg: (json['dose_ml_kg'] as num?)?.toDouble() ?? 0,
      doseIuKg: (json['dose_iu_kg'] as num?)?.toDouble() ?? 0,
      doseMcgKg: (json['dose_mcg_kg'] as num?)?.toDouble() ?? 0,
      frequency: json['frequency'] as String? ?? '',
      route: json['route'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
    );
  }

  /// Есть ли дозировка
  bool get hasDosage => doseMgKg > 0 || doseMlKg > 0 || doseIuKg > 0 || doseMcgKg > 0;

  /// Тип дозировки
  String get doseType {
    if (doseMgKg > 0) return 'мг/кг';
    if (doseMlKg > 0) return 'мл/кг';
    if (doseIuKg > 0) return 'МЕ/кг';
    if (doseMcgKg > 0) return 'мкг/кг';
    return '';
  }

  /// Значение дозировки
  double get doseValue {
    if (doseMgKg > 0) return doseMgKg;
    if (doseMlKg > 0) return doseMlKg;
    if (doseIuKg > 0) return doseIuKg;
    if (doseMcgKg > 0) return doseMcgKg;
    return 0;
  }

  /// Форматированная дозировка
  String get formattedDose {
    if (!hasDosage) return '';
    final value = doseValue;
    if (value >= 1) return '${value.toStringAsFixed(1)} $doseType';
    return '${value.toStringAsFixed(3)} $doseType';
  }
}
