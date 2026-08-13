import 'package:flutter/foundation.dart';

/// Стадия нарушения функции органа
class AdjustmentStage {
  final String name;
  final String? creatinineRange;
  final String? adjustment;
  final String? intervalMultiplier;

  const AdjustmentStage({
    required this.name,
    this.creatinineRange,
    this.adjustment,
    this.intervalMultiplier,
  });

  factory AdjustmentStage.fromJson(String key, Map<String, dynamic> json) {
    return AdjustmentStage(
      name: key,
      creatinineRange: json['creatinine_range'] as String?,
      adjustment: json['adjustment'] as String?,
      intervalMultiplier: json['interval_multiplier'] as String?,
    );
  }
}

/// Корректировка для конкретного препарата
class DrugAdjustment {
  final String drug;
  final bool? nephrotoxic;
  final bool? hepatotoxic;
  final String adjustment;
  final String? alternative;
  final String? monitoring;

  const DrugAdjustment({
    required this.drug,
    this.nephrotoxic,
    this.hepatotoxic,
    required this.adjustment,
    this.alternative,
    this.monitoring,
  });

  factory DrugAdjustment.fromJson(Map<String, dynamic> json) {
    return DrugAdjustment(
      drug: json['drug'] as String? ?? '',
      nephrotoxic: json['nephrotoxic'] as bool?,
      hepatotoxic: json['hepatotoxic'] as bool?,
      adjustment: json['adjustment'] as String? ?? '',
      alternative: json['alternative'] as String?,
      monitoring: json['monitoring'] as String?,
    );
  }
}

/// Группа корректировок по органу/состоянию (почка, печень и т.д.)
class OrganAdjustment {
  final Map<String, AdjustmentStage> stages;
  final List<DrugAdjustment> drugs;

  const OrganAdjustment({
    required this.stages,
    required this.drugs,
  });

  factory OrganAdjustment.fromJson(Map<String, dynamic> json) {
    final stages = <String, AdjustmentStage>{};
    final stagesRaw = json['stages'] as Map<String, dynamic>?;
    if (stagesRaw != null) {
      stagesRaw.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          stages[key] = AdjustmentStage.fromJson(key, value);
        }
      });
    }
    final drugs = <DrugAdjustment>[];
    final drugsRaw = json['drugs'] as List<dynamic>?;
    if (drugsRaw != null) {
      for (int i = 0; i < drugsRaw.length; i++) {
        try {
          drugs.add(DrugAdjustment.fromJson(drugsRaw[i] as Map<String, dynamic>));
        } catch (e) {
          debugPrint('⚠️ DrugAdjustment #$i parse error: $e');
        }
      }
    }
    return OrganAdjustment(stages: stages, drugs: drugs);
  }

  DrugAdjustment? findByDrug(String drugName) {
    final q = drugName.toLowerCase();
    for (final d in drugs) {
      if (d.drug.toLowerCase().contains(q) || q.contains(d.drug.toLowerCase())) {
        return d;
      }
    }
    return null;
  }
}

/// Возрастные корректировки
class AgeAdjustments {
  final List<DrugAdjustment>? neonates;
  final List<DrugAdjustment>? pediatric;
  final List<DrugAdjustment>? geriatric;

  const AgeAdjustments({this.neonates, this.pediatric, this.geriatric});

  factory AgeAdjustments.fromJson(Map<String, dynamic> json) {
    List<DrugAdjustment>? parseList(List<dynamic>? raw) {
      if (raw == null) return null;
      final list = <DrugAdjustment>[];
      for (int i = 0; i < raw.length; i++) {
        try {
          list.add(DrugAdjustment.fromJson(raw[i] as Map<String, dynamic>));
        } catch (e) {
          debugPrint('⚠️ AgeAdjustment parse error: $e');
        }
      }
      return list;
    }

    return AgeAdjustments(
      neonates: parseList(json['neonates'] as List?),
      pediatric: parseList(json['pediatric'] as List?),
      geriatric: parseList(json['geriatric'] as List?),
    );
  }
}

/// Беременность и лактация
class PregnancyAdjustment {
  final List<String> safe;
  final List<String> caution;
  final List<String> contraindicated;
  final List<String>? lactationNotes;

  const PregnancyAdjustment({
    required this.safe,
    required this.caution,
    required this.contraindicated,
    this.lactationNotes,
  });

  factory PregnancyAdjustment.fromJson(Map<String, dynamic> json) {
    List<String> strList(dynamic raw) {
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return [];
    }

    return PregnancyAdjustment(
      safe: strList(json['safe']),
      caution: strList(json['caution']),
      contraindicated: strList(json['contraindicated']),
      lactationNotes: json['lactation_notes'] is List
          ? (json['lactation_notes'] as List).map((e) => e.toString()).toList()
          : null,
    );
  }

  /// Проверяет статус препарата при беременности
  String? checkPregnancy(String drugName) {
    final q = drugName.toLowerCase();
    for (final s in contraindicated) {
      if (s.toLowerCase().contains(q) || q.contains(s.toLowerCase())) {
        return 'ПРОТИВОПОКАЗАН при беременности';
      }
    }
    for (final s in caution) {
      if (s.toLowerCase().contains(q) || q.contains(s.toLowerCase())) {
        return 'С ОСТОРОЖНОСТЬЮ при беременности';
      }
    }
    for (final s in safe) {
      if (s.toLowerCase().contains(q) || q.contains(s.toLowerCase())) {
        return 'Разрешён при беременности';
      }
    }
    return null;
  }
}

/// Полная база корректировок доз
class DoseAdjustmentDatabase {
  final OrganAdjustment? renal;
  final OrganAdjustment? hepatic;
  final OrganAdjustment? cardiac;
  final AgeAdjustments? age;
  final PregnancyAdjustment? pregnancy;

  const DoseAdjustmentDatabase({
    this.renal,
    this.hepatic,
    this.cardiac,
    this.age,
    this.pregnancy,
  });

  factory DoseAdjustmentDatabase.fromJson(Map<String, dynamic> json) {
    return DoseAdjustmentDatabase(
      renal: json['renal_adjustment'] is Map
          ? OrganAdjustment.fromJson(json['renal_adjustment'] as Map<String, dynamic>)
          : null,
      hepatic: json['hepatic_adjustment'] is Map
          ? OrganAdjustment.fromJson(json['hepatic_adjustment'] as Map<String, dynamic>)
          : null,
      cardiac: json['cardiac_adjustment'] is Map
          ? OrganAdjustment.fromJson(json['cardiac_adjustment'] as Map<String, dynamic>)
          : null,
      age: json['age_adjustments'] is Map
          ? AgeAdjustments.fromJson(json['age_adjustments'] as Map<String, dynamic>)
          : null,
      pregnancy: json['pregnancy_lactation'] is Map
          ? PregnancyAdjustment.fromJson(json['pregnancy_lactation'] as Map<String, dynamic>)
          : null,
    );
  }
}