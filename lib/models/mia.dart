// Модель WHO Medically Important Antimicrobials (MIA, издание 2024).
//
// Идея №4 vet-digital-ideas: stewardship-гейт антибиотиков — НЕ новый
// инструмент, а слой напоминаний поверх существующей базы препаратов.
// Каждому антибактериальному (и любому, чьи компоненты — антимикробные)
// присваивается класс по официальной классификации ВОЗ:
//   humans_only → hp (HPCIA) → cia → hia → ia → nmi,
// плюс явные out_of_scope (антисептики, противогрибковые — вне рамок).
//
// Данные:
//   assets/data/mia_classes.json — таблица классов/категорий ВОЗ 2024
//     (33 класса, сверенных с официальным PDF; components — карта русских
//     компонентов INN, используется ТОЛЬКО гейтом scripts/mia_gate.py);
//   assets/data/mia_drugs.json   — СГЕНЕРИРОВАННЫЙ гейтом слой решений
//     {id препарата → классы / out_of_scope}. Dart не парсит INN и не
//     резолвит сам — только lookup по id: один источник истины, никакого
//     дрейфа правил между Python и Dart.
//
// Гейт в CI (scripts/mia_gate.py) гарантирует: покрытие всех
// антибактериальных базы, сверку таблицы с официальным списком ВОЗ и
// соответствие mia_drugs.json базе препаратов.
//
// Лицензия источника: WHO MIA List 2024, CC BY-NC-SA 3.0 IGO — атрибуция
// выводится в детальной плашке (источник обязателен при цитировании).

import 'package:flutter/foundation.dart';

/// Категория важности ВОЗ (разделы списка MIA 2024).
class MiaCategory {
  final String id; // humans_only | hp | cia | hia | ia | nmi
  final int rank; // больше = важнее для медицины человека
  final String short; // короткая подпись для чипа/плашки
  final String label; // развёрнутое название
  final String hint; // stewardship-совет категории

  const MiaCategory({
    required this.id,
    required this.rank,
    required this.short,
    required this.label,
    required this.hint,
  });

  static MiaCategory fromJson(String id, Map<String, dynamic> json) =>
      MiaCategory(
        id: id,
        rank: (json['rank'] as num).toInt(),
        short: json['short'] as String? ?? id,
        label: json['label'] as String? ?? id,
        hint: json['hint'] as String? ?? '',
      );
}

/// Антимикробный класс из официальной таблицы ВОЗ 2024.
class MiaClass {
  final String id;
  final String name; // русское название класса
  final String nameEn; // официальное английское (для сверки с первоисточником)
  final String category; // id категории
  final List<String> whoMembers; // примеры членов класса из текста ВОЗ
  final String stewardship; // совет разумного использования
  final String? note; // оговорка (например, про диоксидин)

  const MiaClass({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.category,
    this.whoMembers = const [],
    required this.stewardship,
    this.note,
  });

  static MiaClass fromJson(Map<String, dynamic> json) => MiaClass(
        id: json['id'] as String,
        name: json['name'] as String,
        nameEn: json['name_en'] as String,
        category: json['category'] as String,
        whoMembers: (json['who_members'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
        stewardship: json['stewardship'] as String? ?? '',
        note: json['note'] as String?,
      );
}

/// Результат разрешения препарата по MIA-слою.
class MiaInfo {
  /// Классы MIA, найденные в компонентах препарата (может быть несколько —
  /// комбинированные препараты).
  final List<MiaClass> classes;

  /// Категории найденных классов.
  final List<MiaCategory> categories;

  /// Явные out_of_scope-причины (антисептик/противогрибковый и т.п.).
  final List<String> outOfScope;

  const MiaInfo({
    required this.classes,
    required this.categories,
    required this.outOfScope,
  });

  bool get hasClasses => classes.isNotEmpty;
  bool get isOutOfScope => classes.isEmpty && outOfScope.isNotEmpty;

  /// Категория «худшего» (наиболее важного для медицины человека) класса
  /// в комбинации: ранг максимален. Для out_of_scope — null.
  MiaCategory? get worstCategory {
    if (categories.isEmpty) return null;
    return categories.reduce((a, b) => a.rank >= b.rank ? a : b);
  }

  /// Имена классов одной строкой (для компактной плашки).
  String get classNamesLine => classes.map((c) => c.name).join('; ');
}

/// Индекс сгенерированных решений {id препарата → классы/out_of_scope}.
@immutable
class MiaDrugMap {
  final Map<int, Map<String, dynamic>> entries;

  const MiaDrugMap(this.entries);

  static MiaDrugMap fromJson(Map<String, dynamic> json) {
    final drugs = json['drugs'] as Map<String, dynamic>? ?? {};
    final entries = <int, Map<String, dynamic>>{};
    drugs.forEach((key, value) {
      entries[int.tryParse(key) ?? -1] =
          (value as Map<String, dynamic>).cast<String, dynamic>();
    });
    return MiaDrugMap(entries);
  }
}

/// База MIA: таблица классов + присоединённый слой решений по препаратам.
class MiaDatabase {
  final String version;
  final String sourceTitle;
  final String sourceIsbn;
  final String sourceUrl;
  final Map<String, MiaCategory> categories;
  final Map<String, MiaClass> classes;
  final MiaDrugMap? drugMap;

  const MiaDatabase({
    this.version = '',
    this.sourceTitle = '',
    this.sourceIsbn = '',
    this.sourceUrl = '',
    this.categories = const {},
    this.classes = const {},
    this.drugMap,
  });

  /// Парсит mia_classes.json (таблица ВОЗ). Карта components/out_of_scope —
  /// прерогатива Python-гейта, Dart её не читает.
  static MiaDatabase fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>? ?? {};
    final cats = <String, MiaCategory>{};
    (json['categories'] as Map<String, dynamic>? ?? {}).forEach((id, value) {
      cats[id] = MiaCategory.fromJson(id, value as Map<String, dynamic>);
    });
    final cls = <String, MiaClass>{};
    for (final c in (json['classes'] as List<dynamic>? ?? [])) {
      final item = MiaClass.fromJson(c as Map<String, dynamic>);
      cls[item.id] = item;
    }
    return MiaDatabase(
      version: json['version'] as String? ?? '',
      sourceTitle: meta['source_title'] as String? ?? '',
      sourceIsbn: meta['source_isbn'] as String? ?? '',
      sourceUrl: meta['source_url'] as String? ?? '',
      categories: cats,
      classes: cls,
    );
  }

  /// Присоединяет сгенерированный слой решений (mia_drugs.json).
  MiaDatabase withDrugMap(MiaDrugMap map) => MiaDatabase(
        version: version,
        sourceTitle: sourceTitle,
        sourceIsbn: sourceIsbn,
        sourceUrl: sourceUrl,
        categories: categories,
        classes: classes,
        drugMap: map,
      );

  /// Разрешает препарат по id. null — препарата нет в MIA-слое (плашки не
  /// будет: не антимикробный или компоненты вне классификации).
  MiaInfo? resolve(int? drugId) {
    if (drugId == null) return null;
    final entry = drugMap?.entries[drugId];
    if (entry == null) return null;
    final classIds = (entry['c'] as List<dynamic>? ?? []);
    if (classIds.isEmpty && (entry['o'] as List<dynamic>? ?? []).isEmpty) {
      return null;
    }
    final cls = <MiaClass>[];
    final cats = <MiaCategory>[];
    for (final id in classIds) {
      final c = classes[id as String];
      if (c == null) {
        debugPrint('⚠ [MIA] класс $id из mia_drugs.json отсутствует в таблице');
        continue;
      }
      cls.add(c);
      final cat = categories[c.category];
      if (cat != null) cats.add(cat);
    }
    final out = (entry['o'] as List<dynamic>? ?? [])
        .map((e) => e as String)
        .toList();
    if (cls.isEmpty && out.isEmpty) return null;
    return MiaInfo(classes: cls, categories: cats, outOfScope: out);
  }
}
