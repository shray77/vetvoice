import 'package:flutter/foundation.dart';

import '../utils/species_safety.dart';

/// Побочный эффект
class SideEffect {
  final String effect;
  final String? age;
  final String? dose;
  final String? condition;
  /// Task 230: виды, к которым эффект относится; null/пусто —
  /// видонезависимый. База переведена на канонические списки
  /// (["Кошки"]), строка («кошки») — переходная форма.
  final List<String>? species;
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
      species: _parseSpecies(json['species']),
      breeds: json['breeds'] as String?,
      frequency: json['frequency'] as String?,
      action: json['action'] as String? ?? '',
    );
  }

  /// Task 230: список видов — и список, и одиночная строка (переходная
  /// форма базы); пустое/нулевое — видонезависимый эффект.
  static List<String>? _parseSpecies(dynamic raw) {
    if (raw is List) {
      final list =
          raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
      return list.isEmpty ? null : list;
    }
    if (raw is String && raw.trim().isNotEmpty) return [raw.trim()];
    return null;
  }

  /// Относится ли эффект к виду: видонезависимые (species пуст) — ко
  /// всем; видовые — только «своим» («кошки чувствительнее» → Кошки,
  /// не КРС/Собакам).
  bool matchesAnimal(String animalName) {
    final sp = species;
    if (sp == null || sp.isEmpty) return true;
    for (final s in sp) {
      if (SpeciesSafetyFilter.textMentionsAnimal(s, animalName)) return true;
    }
    return false;
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
    // Task 230: нормализация (ё→е, ®™©) вместо голого lowercase —
    // «Катозал®» не совпадал с «катозал». Инвертированный contains
    // (запрос содержит ключ) — только для ключей от 5 символов:
    // короткие ключи ловили мусор; прямое вхождение — без порога.
    final q = _normKey(drugName);
    if (q.isEmpty) return null;
    for (final d in drugs) {
      final k = _normKey(d.drug);
      if (k.contains(q) || (k.length >= 5 && q.contains(k))) {
        return d;
      }
    }
    return null;
  }

  static String _normKey(String s) => s
      .toLowerCase()
      .replaceAll('ё', 'е')
      .replaceAll(RegExp(r'[®™©]'), '')
      .trim();
}
