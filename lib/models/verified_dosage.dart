import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Верифицированная дозировка конкретного препарата (по торговому названию)
class VerifiedDosage {
  final String tradeName;
  final String source;
  final String url;
  final String inn;
  final double? concentration;
  final String? concentrationUnit;
  final String form;
  final List<String> animals;
  final Map<String, VerifiedAnimalDose> animalSpecific;
  final List<String>? warnings;
  final List<String>? contraindicationWarnings;

  const VerifiedDosage({
    required this.tradeName,
    required this.source,
    required this.url,
    required this.inn,
    this.concentration,
    this.concentrationUnit,
    required this.form,
    required this.animals,
    required this.animalSpecific,
    this.warnings,
    this.contraindicationWarnings,
  });

  factory VerifiedDosage.fromJson(String name, Map<String, dynamic> json) {
    final asp = <String, VerifiedAnimalDose>{};
    final aspRaw = json['animal_specific'] as Map<String, dynamic>?;
    if (aspRaw != null) {
      aspRaw.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          asp[key] = VerifiedAnimalDose.fromJson(value);
        }
      });
    }

    List<String>? parseWarnings(dynamic raw) {
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return null;
    }

    // warnings can be top-level _warnings or nested in contraindications
    final topWarnings = parseWarnings(json['_warnings']);
    final contraWarnings = json['contraindications'] is Map
        ? parseWarnings((json['contraindications'] as Map)['warnings'])
        : null;

    return VerifiedDosage(
      tradeName: name,
      source: json['_source'] as String? ?? '',
      url: json['_url'] as String? ?? '',
      inn: json['inn'] as String? ?? '',
      concentration: (json['concentration'] as num?)?.toDouble(),
      concentrationUnit: json['concentration_unit'] as String?,
      form: json['form'] as String? ?? '',
      animals: (json['animals'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      animalSpecific: asp,
      warnings: topWarnings,
      contraindicationWarnings: contraWarnings,
    );
  }
}

/// Дозировка для конкретного животного из верифицированных данных
class VerifiedAnimalDose {
  final double? dosePerKg;
  final double? doseMlPerKg;
  final String? calculation;
  final String method;
  final String frequency;
  final String? courseDays;
  final int? withdrawalDays;
  final int? withdrawalMilkDays;
  final String notes;

  const VerifiedAnimalDose({
    this.dosePerKg,
    this.doseMlPerKg,
    this.calculation,
    required this.method,
    required this.frequency,
    this.courseDays,
    this.withdrawalDays,
    this.withdrawalMilkDays,
    required this.notes,
  });

  factory VerifiedAnimalDose.fromJson(Map<String, dynamic> json) {
    return VerifiedAnimalDose(
      dosePerKg: (json['dose_per_kg'] as num?)?.toDouble(),
      doseMlPerKg: (json['dose_ml_per_kg'] as num?)?.toDouble(),
      calculation: json['_calculation'] as String?,
      method: json['method'] as String? ?? '',
      frequency: json['frequency'] as String? ?? '',
      courseDays: json['course_days']?.toString(),
      withdrawalDays: json['withdrawal_days'] as int?,
      withdrawalMilkDays: json['withdrawal_milk_days'] as int?,
      notes: json['notes'] as String? ?? '',
    );
  }
}

/// База верифицированных дозировок
class VerifiedDosageDatabase {
  final List<VerifiedDosage> dosages;
  final String? lastUpdated;
  final List<String>? sources;

  const VerifiedDosageDatabase({
    required this.dosages,
    this.lastUpdated,
    this.sources,
  });

  factory VerifiedDosageDatabase.fromJson(Map<String, dynamic> json) {
    final list = <VerifiedDosage>[];
    json.forEach((key, value) {
      if (key == '_meta') return;
      if (value is Map<String, dynamic>) {
        try {
          list.add(VerifiedDosage.fromJson(key, value));
        } catch (e) {
          debugPrint('⚠️ VerifiedDosage parse error for $key: $e');
        }
      }
    });
    final meta = json['_meta'] as Map<String, dynamic>?;
    return VerifiedDosageDatabase(
      dosages: list,
      lastUpdated: meta?['last_updated'] as String?,
      sources: meta?['sources'] is List
          ? (meta!['sources'] as List).map((e) => e.toString()).toList()
          : null,
    );
  }

  /// Ищет по торговому названию или МНН
  VerifiedDosage? findByName(String name) {
    final q = name.toLowerCase();
    for (final d in dosages) {
      if (d.tradeName.toLowerCase().contains(q) ||
          d.inn.toLowerCase().contains(q)) {
        return d;
      }
    }
    return null;
  }
}