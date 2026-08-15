import 'package:flutter/foundation.dart';
import 'animal.dart';
import 'vaccine_specific.dart';

/// Дозировка для конкретного животного
class AnimalSpecificDose {
  final double dosePerKg;
  final double doseMin;
  final double doseMax;
  final String frequency;
  final String notes;
  final List<String> warnings;
  final List<String> sideEffects;
  
  /// Доза в МЕ/кг (международные единицы) - для колистина, витаминов и т.д.
  final double doseMePerKg;
  final double doseMeMin;
  final double doseMeMax;
  final String doseUnit; // 'мг/кг', 'МЕ/кг', 'мл/кг'

  const AnimalSpecificDose({
    required this.dosePerKg,
    this.doseMin = 0,
    this.doseMax = 0,
    this.frequency = '',
    this.notes = '',
    this.warnings = const [],
    this.sideEffects = const [],
    this.doseMePerKg = 0,
    this.doseMeMin = 0,
    this.doseMeMax = 0,
    this.doseUnit = 'мг/кг',
  });

  factory AnimalSpecificDose.fromJson(Map<String, dynamic> json) {
    final doseUnit = json['dose_unit'] as String? ?? 'мг/кг';
    return AnimalSpecificDose(
      dosePerKg: (json['dose_per_kg'] as num?)?.toDouble() ?? 0,
      doseMin: (json['dose_min'] as num?)?.toDouble() ?? 0,
      doseMax: (json['dose_max'] as num?)?.toDouble() ?? 0,
      frequency: json['frequency'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      warnings: (json['warnings'] as List<dynamic>?)
              ?.map((e) => e.toString()).toList() ??
          const [],
      sideEffects: (json['side_effects'] as List<dynamic>?)
              ?.map((e) => e.toString()).toList() ??
          const [],
      doseMePerKg: (json['dose_me_per_kg'] as num?)?.toDouble() ?? 0,
      doseMeMin: (json['dose_me_min'] as num?)?.toDouble() ?? 0,
      doseMeMax: (json['dose_me_max'] as num?)?.toDouble() ?? 0,
      doseUnit: doseUnit,
    );
  }

  /// Есть ли доза (мг/кг, МЕ/кг или диапазон doseMin/doseMax).
  /// ⚠️ Фикс B-3: ранее диапазон doseMin/doseMax игнорировался, если dosePerKg=0,
  /// что приводило к silent overdose для препаратов с диапазонной дозировкой
  /// (например, Неомастин для КРС: dose_per_kg=0, dose_min=5, dose_max=10
  /// — fallback на 15 мг/кг давал 1.5×–3× передоз).
  bool get hasDose =>
      dosePerKg > 0 || doseMePerKg > 0 || hasRange || hasMeRange;
  bool get hasRange => doseMin > 0 && doseMax > 0 && doseMin <= doseMax;
  bool get hasMeRange =>
      doseMeMin > 0 && doseMeMax > 0 && doseMeMin <= doseMeMax;
  bool get hasMeDose => doseMePerKg > 0 || hasMeRange;

  String get formattedDose {
    if (hasMeDose) {
      if (doseMeMin > 0 && doseMeMax > 0 && doseMeMin < doseMeMax) {
        return '${_formatMe(doseMeMin)}-${_formatMe(doseMeMax)} МЕ/кг';
      }
      return '${_formatMe(doseMePerKg)} МЕ/кг';
    }
    if (hasRange) {
      return '$doseMin-$doseMax мг/кг';
    }
    return '$dosePerKg $doseUnit';
  }
  
  String _formatMe(double me) {
    if (me >= 1000000) return '${(me / 1000000).toStringAsFixed(1)} млн';
    if (me >= 1000) return '${(me / 1000).toStringAsFixed(0)} тыс';
    return me.toStringAsFixed(0);
  }
}

/// Препарат с расчётной дозировкой
class CalcDrug {
  final int id;
  final String name;
  final String inn;
  final String form;
  final String formType; // injection, tablet, powder, suspension, spot_on, topical
  final String unit; // мл, г, таблетки
  final double concentration;
  final String concentrationUnit;
  final double dosePerKg;
  final double doseMin;
  final double doseMax;
  final String doseUnit;
  final List<String> animals;
  
  /// Концентрация в МЕ (международные единицы) - для колистина, витаминов
  final double concentrationMe; // МЕ/мл или МЕ/г
  final String method;
  final String frequency;
  final String courseDays;
  final int withdrawalDays;
  final String withdrawalText;
  final Map<String, String>? fixedDose;
  final CalcContraindications contraindications;
  final List<String> sideEffects;
  
  /// Категория препарата
  final String category; // антибиотики, нпвс, противопаразитарные и т.д.
  final String? subcategory;
  
  /// Показания к применению
  final String indications;
  
  /// Дозировки для конкретных животных
  final Map<String, AnimalSpecificDose> animalSpecific;
  
  /// 🆕 Специфичные для вакцин поля (если form_type == 'vaccine')
  final VaccineSpecific? vaccineSpecific;

  /// Предрасчитанный поисковый индекс (name + inn + category) для моментального поиска (0.2 мс)
  final String searchIndex;

  const CalcDrug({
    required this.id,
    required this.name,
    required this.inn,
    required this.form,
    this.formType = 'injection',
    this.unit = 'мл',
    required this.concentration,
    required this.concentrationUnit,
    required this.dosePerKg,
    this.doseMin = 0,
    this.doseMax = 0,
    required this.doseUnit,
    required this.animals,
    this.concentrationMe = 0,
    required this.method,
    this.frequency = '',
    this.courseDays = '',
    this.withdrawalDays = 0,
    this.withdrawalText = '',
    this.fixedDose,
    required this.contraindications,
    this.sideEffects = const [],
    this.category = 'прочие',
    this.subcategory,
    this.indications = '',
    this.animalSpecific = const {},
    this.calculatorApplicable = true,
    this.vaccineSpecific,
    this.searchIndex = '',
  });

  /// Есть ли диапазон доз
  bool get hasDoseRange => doseMin > 0 && doseMax > 0 && doseMin < doseMax;

  factory CalcDrug.fromJson(Map<String, dynamic> json) {
    Map<String, String>? fixedDose;
    if (json['fixed_dose'] != null) {
      fixedDose = Map<String, String>.from(json['fixed_dose'] as Map);
    }

    // Парсим animal_specific дозы
    Map<String, AnimalSpecificDose> animalSpecific = {};
    if (json['animal_specific'] != null && json['animal_specific'] is Map) {
      final asMap = json['animal_specific'] as Map<String, dynamic>;
      asMap.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          animalSpecific[key] = AnimalSpecificDose.fromJson(value);
        }
      });
    }

    final concentrationUnit = json['concentration_unit'] as String? ?? 'мг/мл';
    final concentrationRaw = (json['concentration'] as num?)?.toDouble() ?? 0;
    final concentrationMeRaw = (json['concentration_me'] as num?)?.toDouble() ?? 0;

    double concentration = concentrationRaw;
    double concentrationMe = concentrationMeRaw;
    if (concentrationUnit.contains('МЕ') && concentrationMe == 0 && concentrationRaw > 0) {
      concentrationMe = concentrationRaw;
      concentration = 0;
    }

    final name = json['name'] as String? ?? '';
    final inn = json['inn'] as String? ?? '';
    final category = json['category'] as String? ?? 'прочие';

    return CalcDrug(
      id: json['id'] as int? ?? 0,
      name: name,
      inn: inn,
      form: json['form'] as String? ?? '',
      formType: json['form_type'] as String? ?? 'injection',
      unit: json['unit'] as String? ?? 'мл',
      concentration: concentration,
      concentrationUnit: concentrationUnit,
      dosePerKg: (json['dose_per_kg'] as num?)?.toDouble() ?? 0,
      doseMin: (json['dose_min'] as num?)?.toDouble() ?? (json['dose_per_kg'] as num?)?.toDouble() ?? 0,
      doseMax: (json['dose_max'] as num?)?.toDouble() ?? (json['dose_per_kg'] as num?)?.toDouble() ?? 0,
      doseUnit: json['dose_unit'] as String? ?? 'мг/кг',
      animals: (json['animals'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      concentrationMe: concentrationMe,
      method: json['method'] as String? ?? '',
      frequency: json['frequency'] as String? ?? '',
      courseDays: json['course_days'] as String? ?? '',
      withdrawalDays: json['withdrawal_days'] as int? ?? 0,
      withdrawalText: json['withdrawal_text'] as String? ?? '',
      fixedDose: fixedDose,
      contraindications: CalcContraindications.fromJson(
          json['contraindications'] as Map<String, dynamic>? ?? {}),
      sideEffects: (json['side_effects'] as List<dynamic>?)
              ?.map((e) => e.toString()).toList() ??
          const [],
      category: category,
      subcategory: json['subcategory'] as String?,
      indications: json['indications'] as String? ?? '',
      animalSpecific: animalSpecific,
      calculatorApplicable: json['calculator_applicable'] as bool? ?? true,
      vaccineSpecific: json['vaccine_specific'] != null
          ? VaccineSpecific.fromJson(
              json['vaccine_specific'] as Map<String, dynamic>)
          : null,
      searchIndex: '$name $inn $category'.toLowerCase(),
    );
  }

  /// 🆕 Является ли препарат вакциной?
  bool get isVaccine =>
      formType == 'vaccine' ||
      vaccineSpecific != null ||
      category == 'Иммунобиологические';

  /// Проверяет, подходит ли препарат для животного
  bool isForAnimal(String animalName) {
    return animals.any((a) => a.toLowerCase() == animalName.toLowerCase());
  }

  /// Рассчитывает дозу с учётом конкретного животного
  /// Возвращает объем в мл или текст для fixed_dose
  DoseCalculation calculateDose(double weightKg, String animalName) {
    // Если есть фиксированная доза для животного
    if (fixedDose != null && fixedDose!.containsKey(animalName)) {
      return DoseCalculation(
        type: DoseType.fixed,
        displayText: fixedDose![animalName]!,
        volumeMl: 0,
        note: 'Фиксированная доза',
      );
    }

    // 🔑 КЛЮЧЕВОЕ ИЗМЕНЕНИЕ: Сначала ищем дозу для конкретного животного!
    double actualDosePerKg = dosePerKg;
    double actualDoseMin = doseMin;
    double actualDoseMax = doseMax;
    String doseNote = '';
    String animalFrequency = frequency;
    
    // 🆕 Для МЕ (международные единицы)
    double actualDoseMePerKg = 0;
    double actualDoseMeMin = 0;
    double actualDoseMeMax = 0;
    bool useMeDose = false;
    
    // Ищем точное совпадение по названию животного
    AnimalSpecificDose? animalDose = animalSpecific[animalName];
    
    // Если не нашли, пробуем case-insensitive поиск
    if (animalDose == null) {
      for (final entry in animalSpecific.entries) {
        if (entry.key.toLowerCase() == animalName.toLowerCase()) {
          animalDose = entry.value;
          break;
        }
      }
    }
    
    if (animalDose != null && animalDose.hasDose) {
      // 🆕 Проверяем, есть ли доза в МЕ
      if (animalDose.hasMeDose && concentrationMe > 0) {
        useMeDose = true;
        // Если есть только диапазон (doseMePerKg=0) — берём середину как «дозу по умолчанию»
        actualDoseMePerKg = animalDose.doseMePerKg > 0
            ? animalDose.doseMePerKg
            : (animalDose.doseMeMin + animalDose.doseMeMax) / 2;
        actualDoseMeMin =
            animalDose.doseMeMin > 0 ? animalDose.doseMeMin : animalDose.doseMePerKg;
        actualDoseMeMax =
            animalDose.doseMeMax > 0 ? animalDose.doseMeMax : animalDose.doseMePerKg;
      } else {
        // Если есть только диапазон (dosePerKg=0) — берём середину как «дозу по умолчанию»
        // Это и есть фикc B-3: препараты с dose_per_kg=0, dose_min/dose_max > 0
        actualDosePerKg = animalDose.dosePerKg > 0
            ? animalDose.dosePerKg
            : (animalDose.doseMin + animalDose.doseMax) / 2;
        actualDoseMin =
            animalDose.doseMin > 0 ? animalDose.doseMin : animalDose.dosePerKg;
        actualDoseMax =
            animalDose.doseMax > 0 ? animalDose.doseMax : animalDose.dosePerKg;
      }
      doseNote = animalDose.notes;
      if (animalDose.frequency.isNotEmpty) {
        animalFrequency = animalDose.frequency;
      }
    } else if (doseUnit == 'МЕ/кг' && concentrationMe > 0) {
      // 🆕 Базовая доза в МЕ
      useMeDose = true;
      actualDoseMePerKg = dosePerKg;
      actualDoseMeMin = doseMin > 0 ? doseMin : dosePerKg;
      actualDoseMeMax = doseMax > 0 ? doseMax : dosePerKg;
    }

    // 🆕 Расчёт для МЕ
    if (useMeDose && concentrationMe > 0) {
      final volume = (actualDoseMePerKg * weightKg) / concentrationMe;
      String note = _formatMe(actualDoseMePerKg) + ' МЕ/кг';
      if (actualDoseMeMin != actualDoseMeMax && actualDoseMeMin > 0) {
        note = '${_formatMe(actualDoseMeMin)}-${_formatMe(actualDoseMeMax)} МЕ/кг';
      }
      if (doseNote.isNotEmpty) {
        note += '\n$doseNote';
      }
      return DoseCalculation(
        type: DoseType.calculated,
        displayText: _formatVolume(volume, unit),
        volumeMl: unit == 'мл' ? volume : 0,
        volumeGrams: unit == 'г' ? volume : 0,
        note: note,
        dosePerKg: actualDoseMePerKg,
        doseMin: actualDoseMeMin,
        doseMax: actualDoseMeMax,
        frequency: animalFrequency,
      );
    }

    // Расчёт: (доза мг/кг × вес) / концентрация = объем
    if (concentration > 0 && actualDosePerKg > 0) {
      final volume = (actualDosePerKg * weightKg) / concentration;
      String note = '${actualDosePerKg} ${doseUnit}';
      if (actualDoseMin != actualDoseMax && actualDoseMin > 0) {
        note = '$actualDoseMin-$actualDoseMax ${doseUnit}';
      }
      if (doseNote.isNotEmpty) {
        note += '\n$doseNote';
      }
      return DoseCalculation(
        type: DoseType.calculated,
        displayText: _formatVolume(volume, unit),
        volumeMl: unit == 'мл' ? volume : 0,
        volumeGrams: unit == 'г' ? volume : 0,
        note: note,
        dosePerKg: actualDosePerKg,
        doseMin: actualDoseMin,
        doseMax: actualDoseMax,
        frequency: animalFrequency,
      );
    }

    // Если доза в мл/кг или мл/животное
    if (doseUnit.contains('мл/кг') || doseUnit.contains('мл/животное')) {
      final volumeMl = actualDosePerKg * weightKg;
      return DoseCalculation(
        type: DoseType.calculated,
        displayText: _formatVolume(volumeMl, 'мл'),
        volumeMl: volumeMl,
        note: doseUnit,
        dosePerKg: actualDosePerKg,
        frequency: animalFrequency,
      );
    }

    return DoseCalculation(
      type: DoseType.unknown,
      displayText: 'Рассчитайте по инструкции',
      volumeMl: 0,
      note: 'Требуется расчёт по инструкции',
    );
  }
  
  String _formatMe(double me) {
    if (me >= 1000000) return '${(me / 1000000).toStringAsFixed(1)} млн';
    if (me >= 1000) return '${(me / 1000).toStringAsFixed(0)} тыс';
    return me.toStringAsFixed(0);
  }

  String _formatVolume(double value, String unit) {
    String formatted;
    if (value >= 100) {
      formatted = value.toStringAsFixed(0);
    } else if (value >= 10) {
      formatted = value.toStringAsFixed(1);
    } else if (value >= 1) {
      formatted = value.toStringAsFixed(2);
    } else {
      formatted = value.toStringAsFixed(3);
    }
    return '$formatted $unit';
  }

  /// Получить предупреждения о противопоказаниях
  /// Разделяет КРИТИЧЕСКИЕ (запрещено!) и обычные предупреждения
  /// Учитывает пол животного для фильтрации
  ContraindicationResult checkContraindications({
    required bool isPregnant,
    required bool isLactating,
    required bool isYoung,
    required bool isOld,
    String? animalName,
    String gender = 'male', // 'male' или 'female'
  }) {
    final riskWarnings = <String>[];  // КРИТИЧЕСКИЕ - ЗАПРЕЩЕНО!
    final warnings = <String>[];       // Обычные предупреждения

    // === КРИТИЧЕСКИЕ ПРЕДУПРЕЖДЕНИЯ (ЗАПРЕЩЕНО!) ===
    if (isPregnant && contraindications.pregnancy) {
      // Per-species проверка: если есть список видов, проверяем текущий вид
      if (contraindications.pregnancyContraindicatedAnimals.isNotEmpty) {
        if (animalName != null &&
            contraindications.pregnancyContraindicatedAnimals
                .any((a) => a.toLowerCase() == animalName.toLowerCase())) {
          riskWarnings.add('🚫 ЗАПРЕЩЕНО ПРИ БЕРЕМЕННОСТИ для $animalName!');
        }
        // Если вид НЕ в списке — не блокируем (препарат разрешён для этого вида)
      } else {
        // Нет per-species списка — блокируем для ВСЕХ видов
        riskWarnings.add('🚫 ЗАПРЕЩЕНО ПРИ БЕРЕМЕННОСТИ!');
      }
    }
    if (isLactating && contraindications.lactation) {
      riskWarnings.add('🚫 ЗАПРЕЩЕНО ПРИ ЛАКТАЦИИ!');
    }
    if (isYoung && contraindications.young) {
      riskWarnings.add('🚫 ЗАПРЕЩЕНО МОЛОДНЯКУ!');
    }
    
    // === ПРЕДУПРЕЖДЕНИЯ С ОСТОРОЖНОСТЬЮ ===
    if (isOld && contraindications.old) {
      warnings.add('⚠️ С осторожностью для пожилых животных');
    }
    
    // === ПРЕДУПРЕЖДЕНИЯ ПО ПОЛУ (показываем только для СООТВЕТСТВУЮЩЕГО пола!) ===
    if (gender == 'male' && contraindications.maleWarnings.isNotEmpty) {
      warnings.addAll(contraindications.maleWarnings);
    }
    if (gender == 'female' && contraindications.femaleWarnings.isNotEmpty) {
      warnings.addAll(contraindications.femaleWarnings);
    }
    
    // Gender-animal-specific warnings
    if (animalName != null && contraindications.genderAnimalWarnings.containsKey(animalName)) {
      final genderWarnings = contraindications.genderAnimalWarnings[animalName]!;
      if (genderWarnings.containsKey(gender)) {
        warnings.addAll(genderWarnings[gender]!);
      }
    }
    
    // === ПРЕДУПРЕЖДЕНИЯ ДЛЯ КОНКРЕТНОГО ЖИВОТНОГО ===
    if (animalName != null && animalName.isNotEmpty) {
      final animalWarns = contraindications.getWarningsForAnimal(animalName);
      // Фильтруем - убираем предупреждения для другого пола
      for (final w in animalWarns) {
        // Если в тексте есть маркеры пола, проверяем соответствие
        final lowerW = w.toLowerCase();
        if (lowerW.contains('самц') || lowerW.contains('кабел') || lowerW.contains('производител')) {
          if (gender != 'male') continue; // Пропускаем предупреждения для самцов
        }
        if (lowerW.contains('самк') || lowerW.contains('тёлк') || lowerW.contains('сука') || lowerW.contains('кошка') && lowerW.contains('беремен')) {
          if (gender != 'female') continue; // Пропускаем предупреждения для самок
        }
        warnings.add(w);
      }
    } else {
      warnings.addAll(contraindications.warnings);
    }

    return ContraindicationResult(
      riskWarnings: riskWarnings,
      warnings: warnings,
    );
  }
  
  /// Получить побочные эффекты для конкретного животного
  List<String> getSideEffectsForAnimal(String animalName) {
    final result = <String>[...sideEffects];
    
    // Добавляем побочки из animal_specific
    final animalDose = animalSpecific[animalName] ??
        animalSpecific.entries
            .where((e) => e.key.toLowerCase() == animalName.toLowerCase())
            .firstOrNull?.value;
    
    if (animalDose != null) {
      result.addAll(animalDose.sideEffects);
    }
    
    // Добавляем из contraindications
    result.addAll(contraindications.getSideEffectsForAnimal(animalName));
    
    return result;
  }

  @override
  String toString() => 'CalcDrug($name, $concentration$concentrationUnit, category: $category)';
}

/// Тип расчёта дозы
enum DoseType {
  calculated,
  fixed,
  unknown,
}

/// Результат расчёта дозы
class DoseCalculation {
  final DoseType type;
  final String displayText;
  final double volumeMl;
  final double volumeGrams;
  final String note;
  final double dosePerKg;
  final double doseMin;
  final double doseMax;
  final String frequency;

  const DoseCalculation({
    required this.type,
    required this.displayText,
    required this.volumeMl,
    this.volumeGrams = 0,
    required this.note,
    this.dosePerKg = 0,
    this.doseMin = 0,
    this.doseMax = 0,
    this.frequency = '',
  });

  bool get hasCalculation => type == DoseType.calculated || type == DoseType.fixed;
  bool get hasRange => doseMin > 0 && doseMax > 0 && doseMin < doseMax;
  bool get isGrams => volumeGrams > 0;
  double get volume => volumeMl > 0 ? volumeMl : volumeGrams;
}

/// Результат проверки противопоказаний
class ContraindicationResult {
  /// КРИТИЧЕСКИЕ предупреждения (ЗАПРЕЩЕНО!) - показывать очень заметно
  final List<String> riskWarnings;
  /// Обычные предупреждения
  final List<String> warnings;
  
  const ContraindicationResult({
    this.riskWarnings = const [],
    this.warnings = const [],
  });
  
  bool get hasRiskWarnings => riskWarnings.isNotEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
  List<String> get all => [...riskWarnings, ...warnings];
}

/// Противопоказания для расчётного препарата
class CalcContraindications {
  final bool pregnancy;
  final bool lactation;
  final bool young;
  final bool old;
  final List<String> warnings;
  /// Предупреждения для конкретных животных (ключ - название животного)
  final Map<String, List<String>> animalWarnings;
  /// Побочные эффекты для конкретных животных
  final Map<String, List<String>> animalSideEffects;
  /// Предупреждения только для самцов
  final List<String> maleWarnings;
  /// Предупреждения только для самок
  final List<String> femaleWarnings;
  /// Предупреждения для животных по полу (animal -> {male: [...], female: [...]})
  final Map<String, Map<String, List<String>>> genderAnimalWarnings;
  /// Список видов, для которых препарат противопоказан при беременности
  /// Если пустой, а pregnancy=true — противопоказан для ВСЕХ видов препарата
  final List<String> pregnancyContraindicatedAnimals;

  const CalcContraindications({
    this.pregnancy = false,
    this.lactation = false,
    this.young = false,
    this.old = false,
    this.warnings = const [],
    this.animalWarnings = const {},
    this.animalSideEffects = const {},
    this.maleWarnings = const [],
    this.femaleWarnings = const [],
    this.genderAnimalWarnings = const {},
    this.pregnancyContraindicatedAnimals = const [],
  });

  factory CalcContraindications.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CalcContraindications();
    
    // Парсим animal-specific warnings
    Map<String, List<String>> animalWarnings = {};
    if (json['animal_warnings'] != null && json['animal_warnings'] is Map) {
      final aw = json['animal_warnings'] as Map<String, dynamic>;
      aw.forEach((key, value) {
        if (value is List) {
          animalWarnings[key] = value.map((e) => e.toString()).toList();
        }
      });
    }
    
    // Парсим animal-specific side effects
    Map<String, List<String>> animalSideEffects = {};
    if (json['animal_side_effects'] != null && json['animal_side_effects'] is Map) {
      final ase = json['animal_side_effects'] as Map<String, dynamic>;
      ase.forEach((key, value) {
        if (value is List) {
          animalSideEffects[key] = value.map((e) => e.toString()).toList();
        }
      });
    }
    
    // Парсим предупреждения по полу
    List<String> maleWarnings = [];
    List<String> femaleWarnings = [];
    if (json['gender_warnings'] != null && json['gender_warnings'] is Map) {
      final gw = json['gender_warnings'] as Map<String, dynamic>;
      if (gw['male'] is List) {
        maleWarnings = (gw['male'] as List).map((e) => e.toString()).toList();
      }
      if (gw['female'] is List) {
        femaleWarnings = (gw['female'] as List).map((e) => e.toString()).toList();
      }
    }
    
    // Парсим gender-animal-specific warnings
    Map<String, Map<String, List<String>>> genderAnimalWarnings = {};
    if (json['gender_animal_warnings'] != null && json['gender_animal_warnings'] is Map) {
      final gaw = json['gender_animal_warnings'] as Map<String, dynamic>;
      gaw.forEach((animal, value) {
        if (value is Map) {
          final genderMap = <String, List<String>>{};
          value.forEach((gender, warnings) {
            if (warnings is List) {
              genderMap[gender] = warnings.map((e) => e.toString()).toList();
            }
          });
          genderAnimalWarnings[animal] = genderMap;
        }
      });
    }
    
    // Парсим per-species список противопоказаний при беременности
    List<String> pregnancyContraindicatedAnimals = [];
    if (json['pregnancy_contraindicated_animals'] is List) {
      pregnancyContraindicatedAnimals = (json['pregnancy_contraindicated_animals'] as List)
          .map((e) => e.toString())
          .toList();
    }

    return CalcContraindications(
      pregnancy: json['pregnancy'] as bool? ?? false,
      lactation: json['lactation'] as bool? ?? false,
      young: json['young'] as bool? ?? false,
      old: json['old'] as bool? ?? false,
      warnings: (json['warnings'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      animalWarnings: animalWarnings,
      animalSideEffects: animalSideEffects,
      maleWarnings: maleWarnings,
      femaleWarnings: femaleWarnings,
      genderAnimalWarnings: genderAnimalWarnings,
      pregnancyContraindicatedAnimals: pregnancyContraindicatedAnimals,
    );
  }
  
  /// Получить все предупреждения для конкретного животного
  List<String> getWarningsForAnimal(String animalName) {
    final result = <String>[...warnings];
    
    // Добавляем animal-specific warnings
    final animalSpecific = animalWarnings[animalName] ?? 
                          animalWarnings.entries
                              .where((e) => e.key.toLowerCase() == animalName.toLowerCase())
                              .firstOrNull?.value ?? [];
    result.addAll(animalSpecific);
    
    return result;
  }
  
  /// Получить побочные эффекты для конкретного животного
  List<String> getSideEffectsForAnimal(String animalName) {
    return animalSideEffects[animalName] ?? 
           animalSideEffects.entries
               .where((e) => e.key.toLowerCase() == animalName.toLowerCase())
               .firstOrNull?.value ?? [];
  }
}

/// База расчётных препаратов
class CalcDrugDatabase {
  final String version;
  final String source;
  final String lastUpdated;
  final List<CalcDrug> drugs;
  final List<Animal> animals;

  const CalcDrugDatabase({
    required this.version,
    required this.source,
    required this.lastUpdated,
    required this.drugs,
    required this.animals,
  });

  factory CalcDrugDatabase.fromJson(Map<String, dynamic> json) {
    // Безопасный парсинг препаратов
    final drugsList = <CalcDrug>[];
    final drugsRaw = json['drugs_calc'] as List<dynamic>?;
    if (drugsRaw != null) {
      for (int i = 0; i < drugsRaw.length; i++) {
        try {
          drugsList.add(CalcDrug.fromJson(drugsRaw[i] as Map<String, dynamic>));
        } catch (e) {
          debugPrint('⚠️ Ошибка парсинга препарата #$i: $e');
        }
      }
    }
    
    // Безопасный парсинг животных
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
    
    debugPrint('📊 CalcDrugDatabase: ${drugsList.length} drugs, ${animalsList.length} animals');
    
    return CalcDrugDatabase(
      version: json['version'] as String? ?? '5.0',
      source: json['source'] as String? ?? 'unknown',
      lastUpdated: json['last_updated'] as String? ?? '',
      drugs: drugsList,
      animals: animalsList,
    );
  }

  /// Получить препараты для животного
  List<CalcDrug> getDrugsForAnimal(String animalName) {
    return drugs.where((d) => d.isForAnimal(animalName) && d.calculatorApplicable).toList();
  }

  /// Получить все препараты для калькулятора (без шампуней, ошейников и т.д.)
  List<CalcDrug> get calculatorDrugs {
    return drugs.where((d) => d.calculatorApplicable).toList();
  }

  /// Найти по названию или МНН
  CalcDrug? findByName(String query) {
    final lower = query.toLowerCase();
    try {
      return drugs.firstWhere(
        (d) => d.name.toLowerCase().contains(lower) || 
               d.inn.toLowerCase().contains(lower),
      );
    } catch (_) {
      return null;
    }
  }
}
