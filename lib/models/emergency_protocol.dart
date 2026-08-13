import 'package:flutter/foundation.dart';

/// Шаг протокола
class ProtocolStep {
  final int step;
  final String action;
  final String detail;

  const ProtocolStep({
    required this.step,
    required this.action,
    required this.detail,
  });

  factory ProtocolStep.fromJson(Map<String, dynamic> json) {
    // ⚠️ Фикс B-13: null-safe.
    return ProtocolStep(
      step: (json['step'] as num?)?.toInt() ?? 0,
      action: json['action'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
    );
  }
}

/// Препарат в протоколе
class ProtocolDrug {
  final String drug;
  final String dose;
  final String route;
  final String frequency;

  const ProtocolDrug({
    required this.drug,
    required this.dose,
    required this.route,
    required this.frequency,
  });

  factory ProtocolDrug.fromJson(Map<String, dynamic> json) {
    // ⚠️ Фикс B-13: null-safe.
    return ProtocolDrug(
      drug: json['drug'] as String? ?? '',
      dose: json['dose'] as String? ?? '',
      route: json['route'] as String? ?? '',
      frequency: json['frequency'] as String? ?? '',
    );
  }
}

/// Emergency протокол
class EmergencyProtocol {
  final String name;
  final String code;
  final String indication;
  final List<ProtocolStep> algorithm;
  final List<ProtocolDrug> drugs;
  final List<String> monitoring;
  final String? termination;
  final String? notes;

  const EmergencyProtocol({
    required this.name,
    required this.code,
    required this.indication,
    required this.algorithm,
    required this.drugs,
    required this.monitoring,
    this.termination,
    this.notes,
  });

  factory EmergencyProtocol.fromJson(Map<String, dynamic> json) {
    // ⚠️ Фикс B-13: null-safe + per-item try/catch для вложенных списков.
    final algorithmList = <ProtocolStep>[];
    final algRaw = json['algorithm'] as List<dynamic>?;
    if (algRaw != null) {
      for (int i = 0; i < algRaw.length; i++) {
        try {
          algorithmList.add(ProtocolStep.fromJson(algRaw[i] as Map<String, dynamic>));
        } catch (e) {
          debugPrint('⚠️ ProtocolStep #$i parse error: $e');
        }
      }
    }
    final drugsList = <ProtocolDrug>[];
    final drugsRaw = json['drugs'] as List<dynamic>?;
    if (drugsRaw != null) {
      for (int i = 0; i < drugsRaw.length; i++) {
        try {
          drugsList.add(ProtocolDrug.fromJson(drugsRaw[i] as Map<String, dynamic>));
        } catch (e) {
          debugPrint('⚠️ ProtocolDrug #$i parse error: $e');
        }
      }
    }
    return EmergencyProtocol(
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      indication: json['indication'] as String? ?? '',
      algorithm: algorithmList,
      drugs: drugsList,
      monitoring: (json['monitoring'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      termination: json['termination'] as String?,
      notes: json['notes'] as String?,
    );
  }
}

/// База emergency протоколов
class EmergencyDatabase {
  final List<EmergencyProtocol> protocols;

  const EmergencyDatabase({required this.protocols});

  factory EmergencyDatabase.fromJson(Map<String, dynamic> json) {
    // ⚠️ Фикс B-13: per-item try/catch.
    final list = <EmergencyProtocol>[];
    final raw = json['protocols'] as List<dynamic>?;
    if (raw != null) {
      for (int i = 0; i < raw.length; i++) {
        try {
          list.add(EmergencyProtocol.fromJson(raw[i] as Map<String, dynamic>));
        } catch (e) {
          debugPrint('⚠️ Ошибка парсинга emergency протокола #$i: $e');
        }
      }
    }
    return EmergencyDatabase(protocols: list);
  }

  EmergencyProtocol? findByCode(String code) {
    if (protocols.isEmpty) return null;
    final lower = code.toLowerCase();
    for (final p in protocols) {
      if (p.code.toLowerCase() == lower) return p;
    }
    return null;
  }

  List<EmergencyProtocol> search(String query) {
    final q = query.toLowerCase();
    return protocols.where((p) =>
      p.name.toLowerCase().contains(q) ||
      p.indication.toLowerCase().contains(q) ||
      p.code.toLowerCase().contains(q)
    ).toList();
  }
}
