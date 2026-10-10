// VaccineSpecific — модель для вакцин и иммунобиологических препаратов.
//
// В отличие от обычных препаратов (где доза = мг/кг × вес),
// у вакцин доза — это разовая (например «1 мл подкожно»),
// а флакон содержит N прививных доз.
//
// Источник данных: vaccine_extractor.py (парсит fsvps.dosage).
// Соответствующее поле в JSON: drug["vaccine_specific"]
//
// Интеграция в drugs_calc.json:
//   {
//     "id": 6,
//     "name": "ГАМБОХЕТЧ",
//     "form_type": "vaccine",                  // ← это поле уже есть
//     "calculator_applicable": false,          // ← важно: НЕ считаем через мг/кг
//     "vaccine_specific": {                   // ← НОВОЕ поле
//       "single_dose_ml": 4.0,
//       "single_dose_text": "4 см³ (2000, 4000, 5000 прививных доз)",
//       "doses_per_vial": 5000,
//       "doses_per_vial_options": [2000, 4000, 5000],
//       "route": "подкожно",
//       "schedule": "Повтор через 21 день",
//       "animal": "Птица",
//       "vaccine_type": "живая",
//       "notes": ""
//     }
//   }
//
// Использование в UI:
//   if (drug.formType == 'vaccine' && drug.vaccineSpecific != null) {
//     return VaccineCard(drug: drug);
//   } else {
//     return DoseCalculatorCard(drug: drug);  // обычный калькулятор
//   }

import 'package:flutter/foundation.dart';

/// Тип вакцины (для иконки и цвета в UI).
enum VaccineType {
  live,              // живая
  inactivated,       // инактивированная
  recombinant,       // рекомбинантная
  subunit,           // субъединичная
  anatoxin,          // анатоксин
  serum,             // сыворотка
  immunoglobulin,    // иммуноглобулин
  bacteriophage,     // бактериофаг
  unknown,           // не определён
}

extension VaccineTypeExtension on VaccineType {
  String get displayName {
    switch (this) {
      case VaccineType.live:
        return 'Живая';
      case VaccineType.inactivated:
        return 'Инактивированная';
      case VaccineType.recombinant:
        return 'Рекомбинантная';
      case VaccineType.subunit:
        return 'Субъединичная';
      case VaccineType.anatoxin:
        return 'Анатоксин';
      case VaccineType.serum:
        return 'Сыворотка';
      case VaccineType.immunoglobulin:
        return 'Иммуноглобулин';
      case VaccineType.bacteriophage:
        return 'Бактериофаг';
      case VaccineType.unknown:
        return '';
    }
  }

  /// Иконка для UI
  String get icon {
    switch (this) {
      case VaccineType.live:
        return '🦠';
      case VaccineType.inactivated:
        return '💉';
      case VaccineType.recombinant:
        return '🧬';
      case VaccineType.subunit:
        return '⚛️';
      case VaccineType.anatoxin:
        return '☣️';
      case VaccineType.serum:
      case VaccineType.immunoglobulin:
        return '🩸';
      case VaccineType.bacteriophage:
        return '噬';
      case VaccineType.unknown:
        return '💊';
    }
  }

  /// Цвет для UI (ARGB int)
  int get colorHex {
    switch (this) {
      case VaccineType.live:
        return 0xFFE53935; // красный — осторожно, живая
      case VaccineType.inactivated:
        return 0xFF1E88E5; // синий — безопасная
      case VaccineType.recombinant:
        return 0xFF8E24AA; // фиолетовый — современная
      case VaccineType.subunit:
        return 0xFF00897B; // бирюзовый
      case VaccineType.anatoxin:
        return 0xFFFB8C00; // оранжевый
      case VaccineType.serum:
      case VaccineType.immunoglobulin:
        return 0xFF6D4C41; // коричневый
      case VaccineType.bacteriophage:
        return 0xFF43A047; // зелёный
      case VaccineType.unknown:
        return 0xFF9E9E9E; // серый
    }
  }

  static VaccineType fromString(String? s) {
    if (s == null || s.isEmpty) return VaccineType.unknown;
    switch (s.toLowerCase()) {
      case 'живая':
        return VaccineType.live;
      case 'инактивированная':
        return VaccineType.inactivated;
      case 'рекомбинантная':
        return VaccineType.recombinant;
      case 'субъединичная':
        return VaccineType.subunit;
      case 'анатоксин':
        return VaccineType.anatoxin;
      case 'сыворотка':
        return VaccineType.serum;
      case 'иммуноглобулин':
        return VaccineType.immunoglobulin;
      case 'бактериофаг':
        return VaccineType.bacteriophage;
      default:
        return VaccineType.unknown;
    }
  }
}

/// Специфичные для вакцин поля.
/// Парсится из JSON-поля drug["vaccine_specific"].
class VaccineSpecific {
  /// Разовая доза в мл (если указана).
  /// Например, 1.0 для «1 мл (1 доза)».
  final double? singleDoseMl;

  /// Исходный текст разовой дозы из fsvps.dosage.
  /// Например, "4 см³ (2000, 4000, 5000 прививных доз)".
  final String singleDoseText;

  /// Количество прививных доз во флаконе (максимальное, если вариантов несколько).
  /// Например, 5000 для "2000, 4000, 5000 прививных доз".
  final int? dosesPerVial;

  /// Варианты фасовки (если в дозировке указано несколько).
  /// Например, [2000, 4000, 5000].
  final List<int> dosesPerVialOptions;

  /// Путь введения: «подкожно», «внутримышечно», «перорально», и т.д.
  final String route;

  /// Схема вакцинации: «Повтор через 21 день».
  final String schedule;

  /// Для кого предназначена: «Собаки», «Кошки», «Птица», и т.д.
  final String animal;

  /// Тип вакцины: живая, инактивированная, рекомбинантная, и т.д.
  final VaccineType vaccineType;

  /// Доп. заметки из fsvps (срок годности, условия хранения и т.д.).
  final String notes;

  const VaccineSpecific({
    this.singleDoseMl,
    this.singleDoseText = '',
    this.dosesPerVial,
    this.dosesPerVialOptions = const [],
    this.route = '',
    this.schedule = '',
    this.animal = '',
    this.vaccineType = VaccineType.unknown,
    this.notes = '',
  });

  factory VaccineSpecific.fromJson(Map<String, dynamic> json) {
    return VaccineSpecific(
      singleDoseMl: (json['single_dose_ml'] as num?)?.toDouble(),
      singleDoseText: json['single_dose_text'] as String? ?? '',
      dosesPerVial: (json['doses_per_vial'] as num?)?.toInt(),
      dosesPerVialOptions: (json['doses_per_vial_options'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      route: json['route'] as String? ?? '',
      schedule: json['schedule'] as String? ?? '',
      animal: json['animal'] as String? ?? '',
      vaccineType:
          VaccineTypeExtension.fromString(json['vaccine_type'] as String?),
      notes: json['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'single_dose_ml': singleDoseMl,
        'single_dose_text': singleDoseText,
        'doses_per_vial': dosesPerVial,
        'doses_per_vial_options': dosesPerVialOptions,
        'route': route,
        'schedule': schedule,
        'animal': animal,
        'vaccine_type': vaccineType.displayName.toLowerCase(),
        'notes': notes,
      };

  /// Есть ли достаточно данных для отображения карточки вакцины?
  bool get hasData =>
      singleDoseMl != null ||
      dosesPerVial != null ||
      singleDoseText.isNotEmpty;

  /// Сколько мл нужно для иммунизации N животных?
  /// Например: разовая доза 1 мл × 10 собак = 10 мл.
  double? calculateVolumeForAnimals(int animalCount) {
    if (singleDoseMl == null) return null;
    return singleDoseMl! * animalCount;
  }

  /// Сколько флаконов нужно для иммунизации N животных?
  /// Например: 10 собак × 1 мл = 10 мл. Флакон 100 доз × 1 мл = 100 мл.
  /// Нужно 10/100 = 0.1 флакона → 1 флакон (минимум).
  int? calculateVialsNeeded(int animalCount) {
    if (singleDoseMl == null || dosesPerVial == null || dosesPerVial == 0) {
      return null;
    }
    return (animalCount / dosesPerVial!).ceil();
  }

  /// Человекочитаемая разовая доза для UI.
  String get formattedSingleDose {
    if (singleDoseMl != null) {
      final ml = singleDoseMl!;
      String formatted;
      if (ml >= 100) {
        formatted = ml.toStringAsFixed(0);
      } else if (ml >= 1) {
        formatted = ml.toStringAsFixed(1);
      } else {
        formatted = ml.toStringAsFixed(2);
      }
      return '$formatted мл';
    }
    return singleDoseText.isNotEmpty ? singleDoseText : '—';
  }

  /// Человекочитаемая фасовка для UI.
  String get formattedPackaging {
    if (dosesPerVialOptions.isNotEmpty) {
      return '${dosesPerVialOptions.join(", ")} доз во флаконе';
    }
    if (dosesPerVial != null) {
      return '$dosesPerVial доз во флаконе';
    }
    return '—';
  }

  @override
  String toString() =>
      'VaccineSpecific(dose=$formattedSingleDose, vials=$formattedPackaging, '
      'route=$route, type=${vaccineType.displayName})';
}
