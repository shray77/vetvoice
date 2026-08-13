import 'package:flutter/foundation.dart';

/// Модель протокола лечения заболевания
class TreatmentDrug {
  final String name;
  final String inn;
  final String dose;
  final String route;
  final String frequency;
  final String duration;
  final String pharmGroup;
  final String waitingPeriod;

  const TreatmentDrug({
    this.name = '',
    this.inn = '',
    this.dose = '',
    this.route = '',
    this.frequency = '',
    this.duration = '',
    this.pharmGroup = '',
    this.waitingPeriod = '',
  });

  factory TreatmentDrug.fromJson(Map<String, dynamic> json) {
    return TreatmentDrug(
      name: json['name']?.toString() ?? '',
      inn: json['inn']?.toString() ?? '',
      dose: json['dose']?.toString() ?? '',
      route: json['route']?.toString() ?? '',
      frequency: json['frequency']?.toString() ?? '',
      duration: json['duration']?.toString() ?? '',
      pharmGroup: json['pharm_group']?.toString() ?? '',
      waitingPeriod: json['waiting_period']?.toString() ?? '',
    );
  }
}

class SupportiveTherapy {
  final String name;
  final String inn;
  final String dose;
  final String route;
  final String frequency;
  final String duration;

  const SupportiveTherapy({
    this.name = '',
    this.inn = '',
    this.dose = '',
    this.route = '',
    this.frequency = '',
    this.duration = '',
  });

  factory SupportiveTherapy.fromJson(Map<String, dynamic> json) {
    return SupportiveTherapy(
      name: json['name']?.toString() ?? '',
      inn: json['inn']?.toString() ?? '',
      dose: json['dose']?.toString() ?? '',
      route: json['route']?.toString() ?? '',
      frequency: json['frequency']?.toString() ?? '',
      duration: json['duration']?.toString() ?? '',
    );
  }
}

class TreatmentProtocol {
  final num? diseaseId;
  final String diagnosis;
  final String code;
  final String category;
  final String categoryName;
  final List<String> species;
  final String pathogenType;
  final String severity;
  final String orderNumber;
  final List<TreatmentDrug> primaryDrugs;
  final List<SupportiveTherapy> supportiveTherapy;
  final List<String> warnings;
  final List<String> notes;
  final String source;

  const TreatmentProtocol({
    this.diseaseId,
    this.diagnosis = '',
    this.code = '',
    this.category = '',
    this.categoryName = '',
    this.species = const [],
    this.pathogenType = '',
    this.severity = 'moderate',
    this.orderNumber = '',
    this.primaryDrugs = const [],
    this.supportiveTherapy = const [],
    this.warnings = const [],
    this.notes = const [],
    this.source = '',
  });

  factory TreatmentProtocol.fromJson(Map<String, dynamic> json) {
    final treatment = json['treatment'] as Map<String, dynamic>? ?? {};
    final primary = treatment['primary'] as Map<String, dynamic>? ?? {};
    final drugsList = primary['drugs'] as List<dynamic>? ?? [];
    final supportList = treatment['supportive'] as List<dynamic>? ?? [];

    // ⚠️ Фикс B-13: per-item try/catch — битой препарат в протоколе не должен
    // убивать весь протокол лечения.
    final drugs = <TreatmentDrug>[];
    for (int i = 0; i < drugsList.length; i++) {
      try {
        drugs.add(TreatmentDrug.fromJson(drugsList[i] as Map<String, dynamic>));
      } catch (e) {
        debugPrint('⚠️ TreatmentDrug #$i parse error: $e');
      }
    }
    final support = <SupportiveTherapy>[];
    for (int i = 0; i < supportList.length; i++) {
      try {
        support.add(SupportiveTherapy.fromJson(supportList[i] as Map<String, dynamic>));
      } catch (e) {
        debugPrint('⚠️ SupportiveTherapy #$i parse error: $e');
      }
    }

    return TreatmentProtocol(
      diseaseId: json['disease_id'],
      diagnosis: json['diagnosis']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      categoryName: json['category_name']?.toString() ?? '',
      species: (json['species'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      pathogenType: json['pathogen_type']?.toString() ?? '',
      severity: json['severity']?.toString() ?? 'moderate',
      orderNumber: json['order_number']?.toString() ?? '',
      primaryDrugs: drugs,
      supportiveTherapy: support,
      warnings: (json['warnings'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      notes: (json['notes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      source: json['source']?.toString() ?? '',
    );
  }

  bool get isParticularlyDangerous => category == 'particularly_dangerous';
  bool get hasPrimaryDrugs => primaryDrugs.isNotEmpty;
  bool get hasSupportiveTherapy => supportiveTherapy.isNotEmpty;

  /// Проверяет, есть ли протокол для данного вида животного
  bool isForSpecies(String speciesName) {
    return species.any((s) => s.toLowerCase() == speciesName.toLowerCase());
  }
}

/// База данных протоколов лечения
class TreatmentProtocolDatabase {
  final String version;
  final String description;
  final int totalProtocols;
  final List<TreatmentProtocol> protocols;

  const TreatmentProtocolDatabase({
    this.version = '',
    this.description = '',
    this.totalProtocols = 0,
    this.protocols = const [],
  });

  factory TreatmentProtocolDatabase.fromJson(Map<String, dynamic> json) {
    // ⚠️ Фикс B-13: per-item try/catch — один битой протокол не убивает всю базу.
    final list = <TreatmentProtocol>[];
    final raw = json['protocols'] as List<dynamic>?;
    if (raw != null) {
      for (int i = 0; i < raw.length; i++) {
        try {
          list.add(TreatmentProtocol.fromJson(raw[i] as Map<String, dynamic>));
        } catch (e) {
          debugPrint('⚠️ TreatmentProtocol #$i parse error: $e');
        }
      }
    }
    return TreatmentProtocolDatabase(
      version: json['version']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      totalProtocols: json['total_protocols'] as int? ?? list.length,
      protocols: list,
    );
  }

  /// Найти протокол по названию болезни (точное совпадение)
  TreatmentProtocol? findByDiseaseName(String name) {
    try {
      return protocols.firstWhere(
        (p) => p.diagnosis.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Найти протокол по ID болезни
  TreatmentProtocol? findByDiseaseId(num id) {
    try {
      return protocols.firstWhere((p) => p.diseaseId == id);
    } catch (_) {
      return null;
    }
  }

  /// Получить протоколы для конкретного вида животного
  List<TreatmentProtocol> getProtocolsForSpecies(String speciesName) {
    return protocols.where((p) => p.isForSpecies(speciesName)).toList();
  }

  /// Получить протоколы по категории
  List<TreatmentProtocol> getProtocolsByCategory(String category) {
    return protocols.where((p) => p.category == category).toList();
  }

  /// Поиск по названию болезни
  List<TreatmentProtocol> search(String query) {
    final q = query.toLowerCase();
    return protocols.where((p) => p.diagnosis.toLowerCase().contains(q)).toList();
  }
}
