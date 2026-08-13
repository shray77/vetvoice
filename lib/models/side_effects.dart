import 'package:flutter/foundation.dart';

/// Побочный эффект
class SideEffect {
  final String effect;
  final String? age;
  final String? dose;
  final String? condition;
  final String? species;
  final String? breeds;
  final String? frequency;
  final String action;

  const SideEffect({
    required this.effect,
    this.age,
    this.dose,
    this.condition,
    this.species,
    this.breeds,
    this.frequency,
    required this.action,
  });

  factory SideEffect.fromJson(Map<String, dynamic> json) {
    // ⚠️ Фикс B-13: null-safe.
    return SideEffect(
      effect: json['effect'] as String? ?? '',
      age: json['age'] as String?,
      dose: json['dose'] as String?,
      condition: json['condition'] as String?,
      species: json['species'] as String?,
      breeds: json['breeds'] as String?,
      frequency: json['frequency'] as String?,
      action: json['action'] as String? ?? '',
    );
  }
}

/// Препарат с побочными эффектами
class DrugSideEffects {
  final String drug;
  final List<SideEffect> sideEffects;
  final List<String>? monitoring;
  final List<String>? riskFactors;
  final String? notes;
  final String? antidote;
  final String? therapeuticRange;

  const DrugSideEffects({
    required this.drug,
    required this.sideEffects,
    this.monitoring,
    this.riskFactors,
    this.notes,
    this.antidote,
    this.therapeuticRange,
  });

  factory DrugSideEffects.fromJson(Map<String, dynamic> json) {
    // ⚠️ Фикс B-13: null-safe + per-item try/catch.
    final effects = <SideEffect>[];
    final raw = json['side_effects'] as List<dynamic>?;
    if (raw != null) {
      for (int i = 0; i < raw.length; i++) {
        try {
          effects.add(SideEffect.fromJson(raw[i] as Map<String, dynamic>));
        } catch (e) {
          debugPrint('⚠️ SideEffect #$i parse error: $e');
        }
      }
    }
    return DrugSideEffects(
      drug: json['drug'] as String? ?? '',
      sideEffects: effects,
      monitoring: (json['monitoring'] as List?)?.map((e) => e.toString()).toList(),
      riskFactors: (json['risk_factors'] as List?)?.map((e) => e.toString()).toList(),
      notes: json['notes'] as String?,
      antidote: json['antidote'] as String?,
      therapeuticRange: json['therapeutic_range'] as String?,
    );
  }
}

/// База побочных эффектов
class SideEffectsDatabase {
  final List<DrugSideEffects> drugs;
  final Map<String, List<String>> generalPrinciples;

  const SideEffectsDatabase({
    required this.drugs,
    required this.generalPrinciples,
  });

  factory SideEffectsDatabase.fromJson(Map<String, dynamic> json) {
    // ⚠️ Фикс B-13: per-item try/catch.
    final list = <DrugSideEffects>[];
    final raw = json['drugs'] as List<dynamic>?;
    if (raw != null) {
      for (int i = 0; i < raw.length; i++) {
        try {
          list.add(DrugSideEffects.fromJson(raw[i] as Map<String, dynamic>));
        } catch (e) {
          debugPrint('⚠️ DrugSideEffects #$i parse error: $e');
        }
      }
    }
    // general_principles может отсутствовать — возвращаем пустой map.
    final Map<String, List<String>> principles = {};
    final gpRaw = json['general_principles'];
    if (gpRaw is Map) {
      gpRaw.forEach((k, v) {
        if (v is List) {
          principles[k.toString()] = v.map((e) => e.toString()).toList();
        }
      });
    }
    return SideEffectsDatabase(drugs: list, generalPrinciples: principles);
  }

  DrugSideEffects? findByDrug(String drugName) {
    final q = drugName.toLowerCase();
    for (final d in drugs) {
      if (d.drug.toLowerCase().contains(q) || q.contains(d.drug.toLowerCase())) {
        return d;
      }
    }
    return null;
  }
}
