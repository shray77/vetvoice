import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Раствор для инфузионной терапии
class FluidSolution {
  final String name;
  final String type;
  final String composition;
  final List<String> indications;
  final String tonicity;
  final String rate;

  const FluidSolution({
    required this.name,
    required this.type,
    required this.composition,
    required this.indications,
    required this.tonicity,
    required this.rate,
  });

  factory FluidSolution.fromJson(Map<String, dynamic> json) {
    return FluidSolution(
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? '',
      composition: json['composition'] as String? ?? '',
      indications: (json['indications'] as List?)
          ?.map((e) => e.toString()).toList() ?? const [],
      tonicity: json['tonicity'] as String? ?? '',
      rate: json['rate'] as String? ?? '',
    );
  }
}

/// Добавка к раствору
class FluidAdditive {
  final String name;
  final String indication;
  final String concentration;
  final Map<String, String> doses;
  final String maxRate;
  final String notes;

  const FluidAdditive({
    required this.name,
    required this.indication,
    required this.concentration,
    required this.doses,
    required this.maxRate,
    required this.notes,
  });

  factory FluidAdditive.fromJson(Map<String, dynamic> json) {
    final rawDoses = json['doses'] as Map<String, dynamic>? ?? {};
    final doses = <String, String>{};
    rawDoses.forEach((k, v) => doses[k.toString()] = v.toString());
    return FluidAdditive(
      name: json['name'] as String? ?? '',
      indication: json['indication'] as String? ?? '',
      concentration: json['concentration'] as String? ?? '',
      doses: doses,
      maxRate: json['max_rate'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
    );
  }
}

/// Специальный протокол инфузии
class FluidSpecialProtocol {
  final String name;
  final String species;
  final String protocol;
  final List<String> additives;
  final List<String> monitoring;

  const FluidSpecialProtocol({
    required this.name,
    required this.species,
    required this.protocol,
    required this.additives,
    required this.monitoring,
  });

  factory FluidSpecialProtocol.fromJson(Map<String, dynamic> json) {
    return FluidSpecialProtocol(
      name: json['name'] as String? ?? '',
      species: json['species'] as String? ?? '',
      protocol: json['protocol'] as String? ?? '',
      additives: (json['additives'] as List?)
          ?.map((e) => e.toString()).toList() ?? const [],
      monitoring: (json['monitoring'] as List?)
          ?.map((e) => e.toString()).toList() ?? const [],
    );
  }
}

/// Полная база инфузионной терапии
class FluidTherapyDatabase {
  final Map<String, dynamic> formulas;
  final List<FluidSolution> solutions;
  final List<FluidAdditive> additives;
  final List<FluidSpecialProtocol> specialProtocols;
  final Map<String, dynamic>? bodySurfaceArea;

  const FluidTherapyDatabase({
    required this.formulas,
    required this.solutions,
    required this.additives,
    required this.specialProtocols,
    this.bodySurfaceArea,
  });

  factory FluidTherapyDatabase.fromJson(Map<String, dynamic> json) {
    final solutions = <FluidSolution>[];
    final solRaw = json['solutions'] as List<dynamic>?;
    if (solRaw != null) {
      for (int i = 0; i < solRaw.length; i++) {
        try {
          solutions.add(FluidSolution.fromJson(solRaw[i] as Map<String, dynamic>));
        } catch (e) {
          debugPrint('⚠️ FluidSolution #$i parse error: $e');
        }
      }
    }
    final additives = <FluidAdditive>[];
    final addRaw = json['additives'] as List<dynamic>?;
    if (addRaw != null) {
      for (int i = 0; i < addRaw.length; i++) {
        try {
          additives.add(FluidAdditive.fromJson(addRaw[i] as Map<String, dynamic>));
        } catch (e) {
          debugPrint('⚠️ FluidAdditive #$i parse error: $e');
        }
      }
    }
    final special = <FluidSpecialProtocol>[];
    const spRaw = null;
    final spRaw2 = json['special_protocols'] as List<dynamic>?;
    if (spRaw2 != null) {
      for (int i = 0; i < spRaw2.length; i++) {
        try {
          special.add(FluidSpecialProtocol.fromJson(spRaw2[i] as Map<String, dynamic>));
        } catch (e) {
          debugPrint('⚠️ FluidSpecialProtocol #$i parse error: $e');
        }
      }
    }
    return FluidTherapyDatabase(
      formulas: json['formulas'] as Map<String, dynamic>? ?? {},
      solutions: solutions,
      additives: additives,
      specialProtocols: special,
      bodySurfaceArea: json['body_surface_area'] as Map<String, dynamic>?,
    );
  }

  /// Ищет раствор по названию или показанию
  List<FluidSolution> findSolutions(String query) {
    final q = query.toLowerCase();
    return solutions.where((s) =>
      s.name.toLowerCase().contains(q) ||
      s.indications.any((ind) => ind.toLowerCase().contains(q))
    ).toList();
  }
}