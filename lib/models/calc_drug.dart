import 'package:flutter/foundation.dart';
import 'drug.dart';
import 'vaccine_specific.dart';
import '../utils/species_safety.dart';

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
  /// ⚠ Фикс B-3: ранее диапазон doseMin/doseMax игнорировался, если dosePerKg=0,
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

  /// ⚠ Фикс S-1 (Task 183): сырая строка концентрации, если в базе она
  /// НЕ число («5 МЕ, 10 МЕ», «10 г», «#####» — 218 записей xlsx-конверта).
  /// Расчёт через такую концентрацию невозможен (concentration=0,
  /// калькулятор честно уходит в «по инструкции»), но строка хранится
  /// для отображения в справочнике и диагностики данных.
  final String? concentrationText;
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
  
  /// Подходит ли для калькулятора (скрыть шампуни, ошейники и т.д.)
  final bool calculatorApplicable;

  /// 🆕 Специфичные для вакцин поля (если form_type == 'vaccine')
  final VaccineSpecific? vaccineSpecific;

  const CalcDrug({
    required this.id,
    required this.name,
    required this.inn,
    required this.form,
    this.formType = 'injection',
    this.unit = 'мл',
    required this.concentration,
    required this.concentrationUnit,
    this.concentrationText,
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

    // ⚠ Фикс S-1 (Task 183): concentration в xlsx-конверте бывает СТРОКОЙ
    // («5 МЕ, 10 МЕ», «6 000 000 МЕ; 12 000 000 МЕ», «10 г», «#####»).
    // Жёсткий каст `as num?` кидал TypeError, per-item catch в
    // CalcDrugDatabase.fromJson глотал запись ЦЕЛИКОМ — препараты молча
    // исчезали из калькулятора (Окситоцин, Канинсулин, Гепарин, Катозал,
    // Фоллимаг...). Теперь: число — как раньше; строка — НЕ числовая
    // концентрация для расчёта (0 + сырая строка в concentrationText).
    final concJson = json['concentration'];
    final double concentrationRaw = concJson is num ? concJson.toDouble() : 0.0;
    final String? concentrationTextValue = concJson is String ? concJson : null;
    final concentrationUnit = json['concentration_unit'] as String? ?? 'мг/мл';
    final concentrationMeRaw = (json['concentration_me'] as num?)?.toDouble() ?? 0;

    // ⚠ Фикс B-4: если concentration_unit содержит "МЕ" (международные единицы),
    // но в JSON concentration_me не задан — значение в поле concentration
    // на самом деле является концентрацией в МЕ/мл. Переносим его в concentrationMe,
    // чтобы calculateDose() корректно считал объём через МЕ-ветку.
    // Это затрагивает 18 препаратов (Димоксан WS, Энроколи, Интроцил, Авидокс и т.д.),
    // у которых ранее (доза мг/кг × вес) / concentration_МЕ = численный мусор.
    // (S-1: строковые концентрации в перенос не участвуют — там числового
    // значения нет вовсе, concentrationRaw=0.)
    double concentration = concentrationRaw;
    double concentrationMe = concentrationMeRaw;
    if (concentrationUnit.toUpperCase().contains('МЕ') &&
        concentrationMe == 0 &&
        concentrationRaw > 0) {
      concentrationMe = concentrationRaw;
      concentration = 0;
    }

    return CalcDrug(
      id: json['id'] as int,
      name: json['name'] as String,
      inn: json['inn'] as String? ?? '',
      form: json['form'] as String? ?? '',
      formType: json['form_type'] as String? ?? 'injection',
      unit: json['unit'] as String? ?? 'мл',
      concentration: concentration,
      concentrationUnit: concentrationUnit,
      concentrationText: concentrationTextValue,
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
      category: json['category'] as String? ?? 'прочие',
      subcategory: json['subcategory'] as String?,
      indications: json['indications'] as String? ?? '',
      animalSpecific: animalSpecific,
      calculatorApplicable: json['calculator_applicable'] as bool? ?? true,
      // 🆕 Парсим vaccine_specific для вакцин
      vaccineSpecific: json['vaccine_specific'] != null
          ? VaccineSpecific.fromJson(
              json['vaccine_specific'] as Map<String, dynamic>)
          : null,
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
    // ⚠ Фикс VV-013 (ревью 26.11.2026): NaN/±inf/неположительный вес раньше
    // проходили все проверки (для NaN `weight <= 0` — false) и давали
    // «NaN мл» либо отрицательный объём.
    if (weightKg.isNaN || weightKg.isInfinite || weightKg <= 0) {
      return DoseCalculation(
        type: DoseType.unknown,
        displayText: 'Рассчитайте по инструкции',
        volumeMl: 0,
        note: 'Укажите корректный вес (положительное число)',
      );
    }

    // Если есть фиксированная доза для животного
    if (fixedDose != null && fixedDose!.containsKey(animalName)) {
      return DoseCalculation(
        type: DoseType.fixed,
        displayText: fixedDose![animalName]!,
        volumeMl: 0,
        note: 'Фиксированная доза',
      );
    }

    // 🔑 Сначала ищем дозу для конкретного животного
    double actualDosePerKg = dosePerKg;
    double actualDoseMin = doseMin;
    double actualDoseMax = doseMax;
    String doseNote = '';
    String animalFrequency = frequency;

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
      // Если есть только диапазон (dosePerKg=0) — берём середину как «дозу по
      // умолчанию» (фикс B-3: диапазонные дозировки не уводят в передоз).
      actualDosePerKg = animalDose.dosePerKg > 0
          ? animalDose.dosePerKg
          : (animalDose.doseMin + animalDose.doseMax) / 2;
      actualDoseMin =
          animalDose.doseMin > 0 ? animalDose.doseMin : animalDose.dosePerKg;
      actualDoseMax =
          animalDose.doseMax > 0 ? animalDose.doseMax : animalDose.dosePerKg;
      doseNote = animalDose.notes;
      if (animalDose.frequency.isNotEmpty) {
        animalFrequency = animalDose.frequency;
      }
    }

    // ⚠ Фикс VV-002/VV-010 (ревью 26.11.2026): эффективная единица дозы —
    // своя у вида (animal_specific.doseUnit), иначе топовая. Раньше объёмные
    // ветки ветвились по ТОПОВОЙ единице, а гвард согласованности — по
    // единице вида: Зинаприм (КРС 0.1 мл/кг при топовых мг/кг, conc 40 мг/мл)
    // проваливался в массовую ветку и делил объёмную дозу на концентрацию
    // («1.25 мл» вместо 50, ×40 недодоза), а примечание рисовало топовую
    // единицу («20–50 мл/кг» у Повервита WSP вместо «мг/кг»).
    final AnimalSpecificDose? usedAnimalDose =
        (animalDose != null && animalDose.hasDose) ? animalDose : null;
    final String effectiveUnit =
        usedAnimalDose != null && usedAnimalDose.doseUnit.isNotEmpty
            ? usedAnimalDose.doseUnit
            : doseUnit;
    // ⚠ Фикс VV-009 (ревью 26.11.2026): «ме/кг» нижним регистром не
    // распознавался и считался как мг (Отоферонол Голд: «60 мл» ушных капель
    // собаке 10 кг) — единицы сравниваем регистронезависимо.
    final String unitUpper = effectiveUnit.toUpperCase();

    // ⚠ Фикс VV-007 (ревью 26.11.2026): «мг/кг корма» (ppm, 13 записей) —
    // доза на килограмм КОРМА, а не массы тела: умножение на вес животного
    // физически бессмысленно (Робимикс, птица 1 кг → «0.45 мл»).
    if (effectiveUnit.contains('корма')) {
      return DoseCalculation(
        type: DoseType.unknown,
        displayText: 'Рассчитайте по инструкции',
        volumeMl: 0,
        note: 'Доза указана на кг корма — норму задают по потреблению корма',
      );
    }

    // 🆕 МЕ-дозы (международные единицы) — единая ветка по эффективной единице.
    // ⚠ Фиксы VV-008/VV-009 (ревью 26.11.2026): раньше МЕ-доза без
    // concentrationMe проваливалась в массовую ветку и делилась на мг/мл
    // (Полиген: 75 000 МЕ/кг × 6 кг / 300 мг/мл = «1500 мл» птице), МЕ-значения
    // из dose_per_kg при выбранном виде вовсе не считались (Ронколейкин:
    // unknown вместо честных мл), а «ме/кг» нижним регистром считался как мг.
    // Теперь: единица МЕ — считаем через concentrationMe; её нет — честный
    // unknown → «по инструкции».
    if (unitUpper.contains('МЕ')) {
      // Значения: каноничные МЕ-поля вида, иначе «мг»-поля (xlsx-конверт
      // кладёт МЕ-числа в dose_per_kg/min/max: Полиген, Ронколейкин).
      double mePer = actualDosePerKg;
      double meMin = actualDoseMin;
      double meMax = actualDoseMax;
      if (usedAnimalDose != null && usedAnimalDose.hasMeDose) {
        mePer = usedAnimalDose.doseMePerKg > 0
            ? usedAnimalDose.doseMePerKg
            : (usedAnimalDose.doseMeMin + usedAnimalDose.doseMeMax) / 2;
        meMin = usedAnimalDose.doseMeMin > 0
            ? usedAnimalDose.doseMeMin
            : usedAnimalDose.doseMePerKg;
        meMax = usedAnimalDose.doseMeMax > 0
            ? usedAnimalDose.doseMeMax
            : usedAnimalDose.doseMePerKg;
      }
      if (mePer <= 0) {
        return DoseCalculation(
          type: DoseType.unknown,
          displayText: 'Рассчитайте по инструкции',
          volumeMl: 0,
          note: 'Доза в МЕ не указана',
        );
      }
      if (concentrationMe <= 0) {
        return DoseCalculation(
          type: DoseType.unknown,
          displayText: 'Рассчитайте по инструкции',
          volumeMl: 0,
          note: 'Доза ${_formatMe(mePer)} МЕ/кг, но концентрация в МЕ не '
              'указана — объём по инструкции',
        );
      }
      // «МЕ/животное» — на вес не умножается.
      final volume = effectiveUnit.contains('животное')
          ? mePer / concentrationMe
          : (mePer * weightKg) / concentrationMe;
      String note = _formatMe(mePer) + ' МЕ/кг';
      if (meMin != meMax && meMin > 0) {
        note = '${_formatMe(meMin)}-${_formatMe(meMax)} МЕ/кг';
      }
      if (doseNote.isNotEmpty) {
        note += '\n$doseNote';
      }
      return DoseCalculation(
        type: DoseType.calculated,
        displayText: _formatVolume(volume, unit),
        volumeMl: unit == 'мл' ? volume : 0,
        volumeGrams: unit == 'г' ? volume : 0,
        count: unit == 'шт' ? volume : 0,
        note: note,
        dosePerKg: mePer,
        doseMin: meMin,
        doseMax: meMax,
        frequency: animalFrequency,
      );
    }

    // ⚠ Фикс S-2 (Task 183) + VV-002 (ревью 26.11.2026): ОБЪЁМНАЯ доза
    // (мл/кг, мл/животное) проверяется ДО массовой ветки с делением на
    // концентрацию и ветвится по ЭФФЕКТИВНОЙ единице вида:
    // Натрия хлорид 0.9% — корова 500 кг получала «5.6 мл» вместо 50 (×9);
    // Зинаприм КРС — «1.25 мл» вместо 50 (×40). Объёмная доза уже выражена
    // в объёме на единицу — концентрация в ней не участвует. Отдельный гвард
    // согласованности юнитов (философия B-4: несводимые юниты не делятся)
    // больше не нужен: вся диспетчеризация идёт по одной эффективной единице.
    if (effectiveUnit.contains('мл/животное')) {
      // Фиксированный объём на животное — на вес не умножается.
      final volume = actualDosePerKg;
      return DoseCalculation(
        type: DoseType.calculated,
        displayText: _formatVolume(volume, 'мл'),
        volumeMl: unit == 'г' ? 0.0 : volume,
        volumeGrams: unit == 'г' ? volume : 0.0,
        count: unit == 'шт' ? volume : 0,
        note: effectiveUnit,
        dosePerKg: actualDosePerKg,
        frequency: animalFrequency,
      );
    }
    if (effectiveUnit.contains('мл/кг')) {
      final volume = actualDosePerKg * weightKg;
      String note = '$actualDosePerKg ${effectiveUnit}';
      if (actualDoseMin != actualDoseMax && actualDoseMin > 0) {
        note = '$actualDoseMin-$actualDoseMax ${effectiveUnit}';
      }
      if (doseNote.isNotEmpty) {
        note += '\n$doseNote';
      }
      return DoseCalculation(
        type: DoseType.calculated,
        displayText: _formatVolume(volume, unit),
        volumeMl: unit == 'мл' ? volume : 0,
        volumeGrams: unit == 'г' ? volume : 0,
        count: unit == 'шт' ? volume : 0,
        note: note,
        dosePerKg: actualDosePerKg,
        doseMin: actualDoseMin,
        doseMax: actualDoseMax,
        frequency: animalFrequency,
      );
    }

    // Расчёт: (доза мг/кг × вес) / концентрация = объём
    if (concentration > 0 && actualDosePerKg > 0) {
      // ⚠ Фикс VV-001 (ревью 26.11.2026): «мкг/кг» не переводился в мг/кг —
      // деление на мг/мл давало передоз ×1000 (Регостенол и Геставет Прост,
      // КРС 500 кг, 0.96 мкг/кг, conc 0.25 мг/мл → «1920 мл» вместо 1.92 мл).
      final bool isMicrograms = unitUpper.contains('МКГ');
      final double doseMgPerKg =
          isMicrograms ? actualDosePerKg / 1000 : actualDosePerKg;
      final double doseMgMin = isMicrograms ? actualDoseMin / 1000 : actualDoseMin;
      final double doseMgMax = isMicrograms ? actualDoseMax / 1000 : actualDoseMax;
      final volume = (doseMgPerKg * weightKg) / concentration;
      // VV-010: единица в примечании — эффективная (вида), значения — как в базе.
      String note = '$actualDosePerKg $effectiveUnit';
      if (actualDoseMin != actualDoseMax && actualDoseMin > 0) {
        note = '$actualDoseMin-$actualDoseMax $effectiveUnit';
      }
      if (doseNote.isNotEmpty) {
        note += '\n$doseNote';
      }
      return DoseCalculation(
        type: DoseType.calculated,
        displayText: _formatVolume(volume, unit),
        volumeMl: unit == 'мл' ? volume : 0,
        volumeGrams: unit == 'г' ? volume : 0,
        count: unit == 'шт' ? volume : 0,
        note: note,
        // Слайдер ручной дозы работает в мг/кг: мкг-записи отдаём уже в мг.
        dosePerKg: doseMgPerKg,
        doseMin: doseMgMin,
        doseMax: doseMgMax,
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
          riskWarnings.add('✗ ЗАПРЕЩЕНО ПРИ БЕРЕМЕННОСТИ для $animalName!');
        }
        // Если вид НЕ в списке — не блокируем (препарат разрешён для этого вида)
      } else {
        // Нет per-species списка — блокируем для ВСЕХ видов
        riskWarnings.add('✗ ЗАПРЕЩЕНО ПРИ БЕРЕМЕННОСТИ!');
      }
    }
    // Task 230: per-species список — семантика как у беременности:
    // пустой список = флаг действует для всех видов препарата.
    if (isLactating && contraindications.lactation) {
      if (contraindications.lactationContraindicatedAnimals.isEmpty ||
          _listContainsAnimal(contraindications.lactationContraindicatedAnimals,
              animalName)) {
        riskWarnings.add('✗ ЗАПРЕЩЕНО ПРИ ЛАКТАЦИИ'
            '${animalName != null && animalName.isNotEmpty ? " для $animalName" : ""}!');
      }
    }
    if (isYoung && contraindications.young) {
      if (contraindications.youngContraindicatedAnimals.isEmpty ||
          _listContainsAnimal(contraindications.youngContraindicatedAnimals,
              animalName)) {
        riskWarnings.add('✗ ЗАПРЕЩЕНО МОЛОДНЯКУ!');
      }
    }
    
    // === ПРЕДУПРЕЖДЕНИЯ С ОСТОРОЖНОСТЬЮ ===
    if (isOld && contraindications.old) {
      if (contraindications.oldContraindicatedAnimals.isEmpty ||
          _listContainsAnimal(
              contraindications.oldContraindicatedAnimals, animalName)) {
        warnings.add('⚠ С осторожностью для пожилых животных');
      }
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
      // Task 230: видоспецифичные предупреждения своей дозы (animal_specific)
      final animalDose = animalSpecific[animalName] ??
          animalSpecific.entries
              .where((e) => e.key.toLowerCase() == animalName.toLowerCase())
              .firstOrNull?.value;
      if (animalDose != null) {
        warnings.addAll(animalDose.warnings);
      }
      final animalWarns = contraindications.getWarningsForAnimal(animalName);
      // Фильтруем - убираем предупреждения для другого пола
      for (final w in animalWarns) {
        // Если в тексте есть маркеры пола, проверяем соответствие
        final lowerW = w.toLowerCase();
        // Task 230: «кабел» была опечаткой — предупреждения для кобелей
        // не матчились никогда (нулевой фильтр пола)
        if (lowerW.contains('самц') || lowerW.contains('кобел') || lowerW.contains('производител')) {
          if (gender != 'male') continue; // Пропускаем предупреждения для самцов
        }
        // Task 184: скобки вокруг последнего звена — без них приоритет
        // && резал выражение как a || b || (c && d) «случайно верно».
        if (lowerW.contains('самк') ||
            lowerW.contains('тёлк') ||
            lowerW.contains('сука') ||
            (lowerW.contains('кошка') && lowerW.contains('беремен'))) {
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
    // Task 230: общие побочки фильтруются по выбранному виду —
    // «ЛАМИНИТ у лошадей!» (#814 Прималакт) не показывается КРС
    final result = SpeciesSafetyFilter.filterForAnimal(sideEffects, animalName);
    
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

  /// ⚠ Фикс VV-011 (ревью 26.11.2026): количество таблеток/саше (unit='шт',
  /// 212 записей калькулятора) — раньше «1.5 шт» жило только в displayText,
  /// объёмные поля оставались 0 → провайдер показывал «0 мл» вместо
  /// «1.5 шт». Теперь количество — полноправный результат ветвей расчёта.
  final double count;
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
    this.count = 0,
    required this.note,
    this.dosePerKg = 0,
    this.doseMin = 0,
    this.doseMax = 0,
    this.frequency = '',
  });

  bool get hasCalculation => type == DoseType.calculated || type == DoseType.fixed;
  bool get hasRange => doseMin > 0 && doseMax > 0 && doseMin < doseMax;
  bool get isGrams => volumeGrams > 0;

  /// Доза выражена в штуках (таблетки/саше), не в объёме.
  bool get isPieces => count > 0;
  double get volume => volumeMl > 0 ? volumeMl : (volumeGrams > 0 ? volumeGrams : count);
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

/// Task 230: входит ли вид в per-species список (регистронезависимо).
bool _listContainsAnimal(List<String> speciesList, String? animalName) {
  if (animalName == null || animalName.isEmpty) return false;
  return speciesList.any((a) => a.toLowerCase() == animalName.toLowerCase());
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
  /// Task 230: per-species списки лактации/молодняка/пожилых — та же
  /// семантика: пустой список = флаг для всех видов препарата
  final List<String> lactationContraindicatedAnimals;
  final List<String> youngContraindicatedAnimals;
  final List<String> oldContraindicatedAnimals;

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
    this.lactationContraindicatedAnimals = const [],
    this.youngContraindicatedAnimals = const [],
    this.oldContraindicatedAnimals = const [],
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

    // Task 230: лактация/молодняк/пожилые — per-species (аналог беременности)
    final lactationContraindicatedAnimals =
        _parseSpeciesList(json['lactation_contraindicated_animals']);
    final youngContraindicatedAnimals =
        _parseSpeciesList(json['young_contraindicated_animals']);
    final oldContraindicatedAnimals =
        _parseSpeciesList(json['old_contraindicated_animals']);

    return CalcContraindications(
      pregnancy: json['pregnancy'] as bool? ?? false,
      lactation: json['lactation'] as bool? ?? false,
      young: json['young'] as bool? ?? false,
      old: json['old'] as bool? ?? false,
      // ⚠ Фикс S-1 (Task 183): warnings бывает СТРОКОЙ, а не списком
      // («КАТЕГОРИЧЕСКИ ЗАПРЕЩЁН ЛОШАДЯМ (фатальный энтероколит)...») —
      // ещё 233 записи валились на `as List` и глотались per-item catch
      // (второй класс молчаливых потерь после concentration-строк).
      // Строка = одно предупреждение целиком.
      warnings: _parseStringList(json['warnings']),
      animalWarnings: animalWarnings,
      animalSideEffects: animalSideEffects,
      maleWarnings: maleWarnings,
      femaleWarnings: femaleWarnings,
      genderAnimalWarnings: genderAnimalWarnings,
      pregnancyContraindicatedAnimals: pregnancyContraindicatedAnimals,
      lactationContraindicatedAnimals: lactationContraindicatedAnimals,
      youngContraindicatedAnimals: youngContraindicatedAnimals,
      oldContraindicatedAnimals: oldContraindicatedAnimals,
    );
  }
  
  /// Task 230: список видов из JSON-поля (строка = один вид).
  static List<String> _parseSpeciesList(dynamic raw) {
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.isNotEmpty) return [raw];
    return [];
  }

  /// Список строк из JSON-поля, которое бывает и списком, и одиночной
  /// строкой (S-1: xlsx-конверт кладёт текст предупреждения строкой).
  static List<String> _parseStringList(dynamic raw) {
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.isNotEmpty) return [raw];
    return [];
  }

  /// Получить все предупреждения для конкретного животного
  List<String> getWarningsForAnimal(String animalName) {
    // Task 230: общий текст режется по виду — «Запрещено для кроликов»
    // не выезжает КРС; animal_warnings добавляются только своему виду
    final result = SpeciesSafetyFilter.filterForAnimal(warnings, animalName);
    
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
          debugPrint('⚠ Ошибка парсинга препарата #$i: $e');
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
          debugPrint('⚠ Ошибка парсинга животного #$i: $e');
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
