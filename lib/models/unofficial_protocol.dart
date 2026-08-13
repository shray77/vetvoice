import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Дозировка для конкретного животного из неофициального протокола
class UnofficialAnimalDose {
  final String animal;
  final double doseMin;
  final double doseMax;
  final String unit;
  final String route;
  final String frequency;
  final String notes;

  const UnofficialAnimalDose({
    required this.animal,
    required this.doseMin,
    required this.doseMax,
    required this.unit,
    required this.route,
    required this.frequency,
    required this.notes,
  });

  factory UnofficialAnimalDose.fromJson(Map<String, dynamic> json) {
    return UnofficialAnimalDose(
      animal: json['animal'] as String? ?? '',
      doseMin: (json['dose_min'] as num?)?.toDouble() ?? 0,
      doseMax: (json['dose_max'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] as String? ?? '',
      route: json['route'] as String? ?? '',
      frequency: json['frequency'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
    );
  }
}

/// Запись неофициального протокола
class UnofficialRecord {
  final String drugNameInn;
  final List<String> tradeNames;
  final String description;
  final String form;
  final List<UnofficialAnimalDose> animalDosages;
  final String warnings;
  final String source;
  final String sourceUrl;
  final String recordType;

  const UnofficialRecord({
    required this.drugNameInn,
    required this.tradeNames,
    required this.description,
    required this.form,
    required this.animalDosages,
    required this.warnings,
    required this.source,
    required this.sourceUrl,
    required this.recordType,
  });

  factory UnofficialRecord.fromJson(Map<String, dynamic> json) {
    // animal_dosages может быть JSON-строкой (legacy)
    List<UnofficialAnimalDose> parseDosages(dynamic raw) {
      if (raw is List) {
        final list = <UnofficialAnimalDose>[];
        for (int i = 0; i < raw.length; i++) {
          try {
            if (raw[i] is Map<String, dynamic>) {
              list.add(UnofficialAnimalDose.fromJson(raw[i] as Map<String, dynamic>));
            }
          } catch (e) {
            debugPrint('⚠️ UnofficialDose #$i parse error: $e');
          }
        }
        return list;
      }
      if (raw is String && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw) as List<dynamic>;
          return parseDosages(decoded);
        } catch (_) {}
      }
      return [];
    }

    return UnofficialRecord(
      drugNameInn: json['drug_name_inn'] as String? ?? '',
      tradeNames: (json['trade_names'] as List?)
          ?.map((e) => e.toString())
          .toList() ?? const [],
      description: json['description'] as String? ?? '',
      form: json['form'] as String? ?? '',
      animalDosages: parseDosages(json['animal_dosages']),
      warnings: json['warnings'] as String? ?? '',
      source: json['source'] as String? ?? '',
      sourceUrl: json['source_url'] as String? ?? '',
      recordType: json['record_type'] as String? ?? '',
    );
  }
}

/// База неофициальных протоколов
class UnofficialProtocolDatabase {
  final List<UnofficialRecord> records;

  const UnofficialProtocolDatabase({required this.records});

  factory UnofficialProtocolDatabase.fromJson(Map<String, dynamic> json) {
    final list = <UnofficialRecord>[];
    final raw = json['records'] as List<dynamic>?;
    if (raw != null) {
      for (int i = 0; i < raw.length; i++) {
        try {
          list.add(UnofficialRecord.fromJson(raw[i] as Map<String, dynamic>));
        } catch (e) {
          debugPrint('⚠️ UnofficialRecord #$i parse error: $e');
        }
      }
    }
    return UnofficialProtocolDatabase(records: list);
  }

  /// Ищет записи по МНН или названию
  List<UnofficialRecord> search(String query) {
    final q = query.toLowerCase();
    return records.where((r) {
      if (r.drugNameInn.toLowerCase().contains(q)) return true;
      return r.tradeNames.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  /// Ищет дозировку по МНН и виду животного
  List<UnofficialAnimalDose> findDosages(String inn, String animal) {
    final q = inn.toLowerCase();
    final results = <UnofficialAnimalDose>[];
    for (final r in records) {
      if (r.drugNameInn.toLowerCase().contains(q) || q.contains(r.drugNameInn.toLowerCase())) {
        results.addAll(r.animalDosages.where((d) =>
          d.animal.toLowerCase() == animal.toLowerCase()
        ));
      }
    }
    return results;
  }
}