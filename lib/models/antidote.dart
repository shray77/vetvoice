import 'package:flutter/foundation.dart';

/// Антидот для отравления
class Antidote {
  final String toxin;
  final List<String> commonNames;
  final List<String> symptoms;
  final String antidote;
  final String antidoteDose;
  final String alternative;
  final String notes;
  final String prognosis;

  const Antidote({
    required this.toxin,
    required this.commonNames,
    required this.symptoms,
    required this.antidote,
    required this.antidoteDose,
    required this.alternative,
    required this.notes,
    required this.prognosis,
  });

  factory Antidote.fromJson(Map<String, dynamic> json) {
    // ⚠️ Фикс B-13: null-safe парсинг.
    return Antidote(
      toxin: json['toxin'] as String? ?? '',
      commonNames: (json['common_names'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      symptoms: (json['symptoms'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      antidote: json['antidote'] as String? ?? '',
      antidoteDose: json['antidote_dose'] as String? ?? '',
      alternative: json['alternative'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      prognosis: json['prognosis'] as String? ?? '',
    );
  }
}

/// База антидотов
class AntidoteDatabase {
  final List<Antidote> poisonings;

  const AntidoteDatabase({required this.poisonings});

  factory AntidoteDatabase.fromJson(Map<String, dynamic> json) {
    // ⚠️ Фикс B-13: null-safe парсинг + per-item try/catch.
    final list = <Antidote>[];
    final raw = json['poisonings'] as List<dynamic>?;
    if (raw != null) {
      for (int i = 0; i < raw.length; i++) {
        try {
          list.add(Antidote.fromJson(raw[i] as Map<String, dynamic>));
        } catch (e) {
          debugPrint('⚠️ Ошибка парсинга антидота #$i: $e');
        }
      }
    }
    return AntidoteDatabase(poisonings: list);
  }

  /// Ищет антидот по названию токсина или синониму
  Antidote? findByToxin(String query) {
    final q = query.toLowerCase();
    
    for (final p in poisonings) {
      if (p.toxin.toLowerCase().contains(q)) return p;
      for (final name in p.commonNames) {
        if (name.toLowerCase().contains(q)) return p;
      }
    }
    return null;
  }

  /// Ищет по симптомам
  List<Antidote> findBySymptom(String symptom) {
    final s = symptom.toLowerCase();
    return poisonings.where((p) => 
      p.symptoms.any((sym) => sym.toLowerCase().contains(s))
    ).toList();
  }
}
