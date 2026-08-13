import 'package:flutter/foundation.dart';

/// Модель препарата из реестра зарегистрированных ветеринарных препаратов РФ
class RegistryDrug {
  final int id;
  final String tradeName;
  final String inn;
  final String form;
  final String dosage;
  final List<String> animals;
  final String pharmacologicalGroup;
  final String indications;
  final String contraindications;
  final String sideEffects;
  final String shelfLife;
  final String storageConditions;
  final String releaseConditions;
  final String manufacturer;
  final String registrationNumber;
  final String registrationDate;
  final String composition;
  final String packaging;

  const RegistryDrug({
    required this.id,
    required this.tradeName,
    required this.inn,
    required this.form,
    required this.dosage,
    required this.animals,
    required this.pharmacologicalGroup,
    required this.indications,
    required this.contraindications,
    required this.sideEffects,
    required this.shelfLife,
    required this.storageConditions,
    required this.releaseConditions,
    required this.manufacturer,
    required this.registrationNumber,
    required this.registrationDate,
    required this.composition,
    required this.packaging,
  });

  factory RegistryDrug.fromJson(Map<String, dynamic> json) {
    // ⚠️ Фикс B-13: null-safe парсинг.
    return RegistryDrug(
      id: (json['id'] as num?)?.toInt() ?? 0,
      tradeName: json['trade_name'] as String? ?? '',
      inn: json['inn'] as String? ?? '',
      form: json['form'] as String? ?? '',
      dosage: json['dosage'] as String? ?? '',
      animals: (json['animals'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      pharmacologicalGroup: json['pharmacological_group'] as String? ?? '',
      indications: json['indications'] as String? ?? '',
      contraindications: json['contraindications'] as String? ?? '',
      sideEffects: json['side_effects'] as String? ?? '',
      shelfLife: json['shelf_life'] as String? ?? '',
      storageConditions: json['storage_conditions'] as String? ?? '',
      releaseConditions: json['release_conditions'] as String? ?? '',
      manufacturer: json['manufacturer'] as String? ?? '',
      registrationNumber: json['registration_number'] as String? ?? '',
      registrationDate: json['registration_date'] as String? ?? '',
      composition: json['composition'] as String? ?? '',
      packaging: json['packaging'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trade_name': tradeName,
      'inn': inn,
      'form': form,
      'dosage': dosage,
      'animals': animals,
      'pharmacological_group': pharmacologicalGroup,
      'indications': indications,
      'contraindications': contraindications,
      'side_effects': sideEffects,
      'shelf_life': shelfLife,
      'storage_conditions': storageConditions,
      'release_conditions': releaseConditions,
      'manufacturer': manufacturer,
      'registration_number': registrationNumber,
      'registration_date': registrationDate,
      'composition': composition,
      'packaging': packaging,
    };
  }

  /// Проверяет, подходит ли препарат для указанного животного
  bool isForAnimal(String animalName) {
    return animals.any((a) => a.toLowerCase() == animalName.toLowerCase());
  }

  /// Короткое название для отображения
  String get displayName => tradeName.replaceAll('®', '').trim();

  /// Форма выпуска (коротко)
  String get shortForm {
    if (form.contains('раствор для инъекций')) return 'р-р д/инъекц.';
    if (form.contains('таблетки')) return 'таб.';
    if (form.contains('порошок')) return 'пор.';
    if (form.contains('суспензия')) return 'сусп.';
    if (form.contains('вакцина')) return 'вакцина';
    return form.length > 30 ? '${form.substring(0, 30)}...' : form;
  }

  /// Это рецептурный препарат?
  bool get isPrescription {
    return releaseConditions.toLowerCase().contains('рецепт');
  }

  /// Это вакцина?
  bool get isVaccine {
    return pharmacologicalGroup.toLowerCase().contains('вакцин');
  }

  @override
  String toString() {
    return 'RegistryDrug(id: $id, tradeName: $tradeName, inn: $inn)';
  }
}

/// База данных реестра препаратов
class DrugRegistry {
  final String version;
  final String source;
  final String lastUpdated;
  final int totalDrugs;
  final List<RegistryDrug> drugs;

  const DrugRegistry({
    required this.version,
    required this.source,
    required this.lastUpdated,
    required this.totalDrugs,
    required this.drugs,
  });

  factory DrugRegistry.fromJson(Map<String, dynamic> json) {
    // ⚠️ Фикс B-13: null-safe парсинг + per-item try/catch.
    final list = <RegistryDrug>[];
    final raw = json['drugs'] as List<dynamic>?;
    if (raw != null) {
      for (int i = 0; i < raw.length; i++) {
        try {
          list.add(RegistryDrug.fromJson(raw[i] as Map<String, dynamic>));
        } catch (e) {
          debugPrint('⚠️ Ошибка парсинга препарата реестра #$i: $e');
        }
      }
    }
    final total = (json['total_drugs'] as num?)?.toInt() ?? list.length;
    return DrugRegistry(
      version: json['version'] as String? ?? '1.0',
      source: json['source'] as String? ?? 'unknown',
      lastUpdated: json['last_updated'] as String? ?? '',
      totalDrugs: total,
      drugs: list,
    );
  }

  /// Получить препараты для конкретного животного
  List<RegistryDrug> getDrugsForAnimal(String animalName) {
    return drugs.where((d) => d.isForAnimal(animalName)).toList();
  }

  /// Поиск по названию
  List<RegistryDrug> searchByName(String query) {
    if (query.isEmpty) return [];
    final lowerQuery = query.toLowerCase();
    return drugs
        .where((d) =>
            d.tradeName.toLowerCase().contains(lowerQuery) ||
            d.inn.toLowerCase().contains(lowerQuery))
        .toList();
  }

  /// Получить препараты по фармгруппе
  List<RegistryDrug> getByPharmacologicalGroup(String group) {
    return drugs
        .where((d) => d.pharmacologicalGroup.toLowerCase().contains(group.toLowerCase()))
        .toList();
  }

  /// Получить все вакцины
  List<RegistryDrug> get vaccines => drugs.where((d) => d.isVaccine).toList();

  /// Получить все рецептурные препараты
  List<RegistryDrug> get prescriptionDrugs =>
      drugs.where((d) => d.isPrescription).toList();

  /// Статистика по животным
  Map<String, int> get animalStats {
    final stats = <String, int>{};
    for (final drug in drugs) {
      for (final animal in drug.animals) {
        stats[animal] = (stats[animal] ?? 0) + 1;
      }
    }
    return stats;
  }
}
