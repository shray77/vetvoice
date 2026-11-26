import 'package:flutter/foundation.dart';

/// Стадия нарушения функции органа
class AdjustmentStage {
  final String name;
  final String? creatinineRange;
  final String? adjustment;
  final String? intervalMultiplier;

  const AdjustmentStage({
    required this.name,
    this.creatinineRange,
    this.adjustment,
    this.intervalMultiplier,
  });

  factory AdjustmentStage.fromJson(String key, Map<String, dynamic> json) {
    return AdjustmentStage(
      name: key,
      creatinineRange: json['creatinine_range'] as String?,
      adjustment: json['adjustment'] as String?,
      intervalMultiplier: json['interval_multiplier'] as String?,
    );
  }
}

/// Корректировка для конкретного препарата
class DrugAdjustment {
  final String drug;
  final bool? nephrotoxic;
  final bool? hepatotoxic;
  final String adjustment;
  final String? alternative;
  final String? monitoring;

  const DrugAdjustment({
    required this.drug,
    this.nephrotoxic,
    this.hepatotoxic,
    required this.adjustment,
    this.alternative,
    this.monitoring,
  });

  factory DrugAdjustment.fromJson(Map<String, dynamic> json) {
    return DrugAdjustment(
      drug: json['drug'] as String? ?? '',
      nephrotoxic: json['nephrotoxic'] as bool?,
      hepatotoxic: json['hepatotoxic'] as bool?,
      adjustment: json['adjustment'] as String? ?? '',
      alternative: json['alternative'] as String?,
      monitoring: json['monitoring'] as String?,
    );
  }
}

/// Группа корректировок по органу/состоянию (почка, печень и т.д.)
class OrganAdjustment {
  final Map<String, AdjustmentStage> stages;
  final List<DrugAdjustment> drugs;

  const OrganAdjustment({
    required this.stages,
    required this.drugs,
  });

  factory OrganAdjustment.fromJson(Map<String, dynamic> json) {
    final stages = <String, AdjustmentStage>{};
    final stagesRaw = json['stages'] as Map<String, dynamic>?;
    if (stagesRaw != null) {
      stagesRaw.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          stages[key] = AdjustmentStage.fromJson(key, value);
        }
      });
    }
    final drugs = <DrugAdjustment>[];
    final drugsRaw = json['drugs'] as List<dynamic>?;
    if (drugsRaw != null) {
      for (int i = 0; i < drugsRaw.length; i++) {
        try {
          drugs.add(DrugAdjustment.fromJson(drugsRaw[i] as Map<String, dynamic>));
        } catch (e) {
          debugPrint('⚠️ DrugAdjustment #$i parse error: $e');
        }
      }
    }
    return OrganAdjustment(stages: stages, drugs: drugs);
  }

  DrugAdjustment? findByDrug(String drugName) {
    final q = drugName.toLowerCase();
    for (final d in drugs) {
      if (d.drug.toLowerCase().contains(q) || q.contains(d.drug.toLowerCase())) {
        return d;
      }
    }
    return null;
  }
}

/// Возрастная группа корректировок дозы.
///
/// ⚠ Фикс (ревью 26.11.2026, находка аудита VV-004-блока): в реальном JSON
/// age_adjustments — это MAP-ы с описанием группы ({description, issues,
/// general_rule, drugs_avoid, safe_drugs} у neonates; {description, issues,
/// warnings, dose_adjustment} у pediatric; {description, issues, general_rule,
/// drugs_careful, monitoring} у geriatric), а модель ждала List → TypeError,
/// и лоадер глотал ВСЮ базу dose_adjustments.json per-DB catch-ем —
/// pregnancy/lactation-данные (включая фиксы VV-004/049/050) не доезжали до
/// рантайма вовсе. Теперь группа — честная карта полей, все необязательные.
class AgeGroupAdjustment {
  final String description;
  final List<String> issues;
  final String? generalRule;
  final List<String> warnings;
  final String? doseAdjustment;
  final List<String> drugsAvoid;
  final List<String> safeDrugs;
  final List<String> drugsCareful;
  final List<String> monitoring;

  const AgeGroupAdjustment({
    this.description = '',
    this.issues = const [],
    this.generalRule,
    this.warnings = const [],
    this.doseAdjustment,
    this.drugsAvoid = const [],
    this.safeDrugs = const [],
    this.drugsCareful = const [],
    this.monitoring = const [],
  });

  factory AgeGroupAdjustment.fromJson(Map<String, dynamic> json) {
    List<String> strList(dynamic raw) {
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return const [];
    }

    return AgeGroupAdjustment(
      description: json['description'] as String? ?? '',
      issues: strList(json['issues']),
      generalRule: json['general_rule'] as String?,
      warnings: strList(json['warnings']),
      doseAdjustment: json['dose_adjustment'] as String?,
      drugsAvoid: strList(json['drugs_avoid']),
      safeDrugs: strList(json['safe_drugs']),
      drugsCareful: strList(json['drugs_careful']),
      monitoring: strList(json['monitoring']),
    );
  }
}

/// Возрастные корректировки
class AgeAdjustments {
  final AgeGroupAdjustment? neonates;
  final AgeGroupAdjustment? pediatric;
  final AgeGroupAdjustment? geriatric;

  const AgeAdjustments({this.neonates, this.pediatric, this.geriatric});

  factory AgeAdjustments.fromJson(Map<String, dynamic> json) {
    AgeGroupAdjustment? parse(dynamic raw) {
      if (raw is Map<String, dynamic>) {
        return AgeGroupAdjustment.fromJson(raw);
      }
      return null;
    }

    return AgeAdjustments(
      neonates: parse(json['neonates']),
      pediatric: parse(json['pediatric']),
      geriatric: parse(json['geriatric']),
    );
  }
}

/// Противопоказанный при беременности препарат (мини-модель).
///
/// ⚠ Фикс VV-050 (ревью 26.11.2026): contraindicated в реальном JSON —
/// список map вида {'drug': 'тетрациклины', 'reason': 'поражение печени,
/// зубы'}; прежний strList() делал e.toString() → «{drug: тетрациклины,
/// reason: …}» — сравнение через contains было хрупким, причина терялась.
/// Теперь drug и reason парсятся в отдельные поля; список строк из тех же
/// данных по-прежнему работает (reason = null).
class ContraindicatedDrug {
  final String drug;
  final String? reason;

  const ContraindicatedDrug({required this.drug, this.reason});

  /// Элемент списка — map (drug + reason) или строка (только drug).
  /// Толерантный парсинг без жёстких кастов (S-1-паттерн Task 183):
  /// кривой элемент не должен ронять всю базу корректировок.
  factory ContraindicatedDrug.fromJson(dynamic raw) {
    if (raw is Map) {
      return ContraindicatedDrug(
        drug: raw['drug']?.toString() ?? '',
        reason: raw['reason']?.toString(),
      );
    }
    return ContraindicatedDrug(drug: raw.toString());
  }

  /// Отображение: причина есть → «тетрациклины — поражение печени, зубы»,
  /// нет → просто название (VV-050).
  String get display {
    final r = reason?.trim();
    return (r == null || r.isEmpty) ? drug : '$drug — $r';
  }
}

/// Беременность и лактация
class PregnancyAdjustment {
  final List<String> safe;
  final List<String> caution;

  /// Было List<String> — map-записи с reason превращались в мусорные
  /// строки (⚠ Фикс VV-050, ревью 26.11.2026; см. ContraindicatedDrug).
  final List<ContraindicatedDrug> contraindicated;

  /// ⚠ Фикс VV-049 (ревью 26.11.2026): в реальном JSON lactation_notes —
  /// СТРОКА («Большинство препаратов проникает в молоко…»), а не список;
  /// жёсткое `is List` всегда отдавало null. Теперь строка = одно
  /// замечание (_parseStringOrList-паттерн из side_effects.dart, Task 230).
  final List<String>? lactationNotes;

  const PregnancyAdjustment({
    required this.safe,
    required this.caution,
    required this.contraindicated,
    this.lactationNotes,
  });

  factory PregnancyAdjustment.fromJson(Map<String, dynamic> json) {
    List<String> strList(dynamic raw) {
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return [];
    }

    // VV-050: contraindicated — список строк ИЛИ список map с drug+reason.
    final contraindicated = <ContraindicatedDrug>[];
    final ciRaw = json['contraindicated'];
    if (ciRaw is List) {
      contraindicated.addAll(ciRaw.map(ContraindicatedDrug.fromJson));
    }

    return PregnancyAdjustment(
      safe: strList(json['safe']),
      caution: strList(json['caution']),
      contraindicated: contraindicated,
      lactationNotes: _parseStringOrList(json['lactation_notes']),
    );
  }

  /// Список-или-строка → List<String>; отсутствует/пусто → null
  /// (S-1-паттерн толерантного парсинга, как в side_effects.dart).
  static List<String>? _parseStringOrList(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    if (raw is String && raw.trim().isNotEmpty) return [raw.trim()];
    return null;
  }

  /// Нормализация МНН: регистр, ё→е, срезка ®™© (паттерн Task 230 из
  /// side_effects.dart: «Катозал®» ≠ «катозал»).
  static String _normInn(String s) => s
      .toLowerCase()
      .replaceAll('ё', 'е')
      .replaceAll(RegExp(r'[®™©]'), '')
      .trim();

  /// Токены МНН: буквы/цифры; скобки и пунктуация — разделители
  /// («макролиды (кроме тилмикозина)» ≠ один токен-подстрока).
  static List<String> _innTokens(String s) => RegExp(r'[a-zа-я0-9]+')
      .allMatches(_normInn(s))
      .map((m) => m.group(0)!)
      .toList();

  /// Токены совпадают: точное равенство ЛИБО общий префикс-стем от 5
  /// символов — падежные окончания («пенициллин» ~ «пенициллины»,
  /// «тилмикозин» ~ «тилмикозина»). Короче 5 — только точное равенство,
  /// чтобы «НПВС» (4) не ловил произвольные «нпв…».
  static bool _tokenMatches(String a, String b) {
    if (a == b) return true;
    final shorter = a.length < b.length ? a : b;
    return shorter.length >= 5 &&
        (a.length < b.length ? b : a).startsWith(shorter);
  }

  /// Запись-группа с исключениями: «макролиды (кроме тилмикозина)» →
  /// база «макролиды» + исключение «тилмикозина». «Кроме» распознаётся и
  /// без скобок: всё до него — база, всё после — исключения (разделители
  /// , ; / «и»). Без «кроме» — вся запись база, исключений нет.
  static (String, List<String>) _splitExclusions(String raw) {
    final norm = _normInn(raw);
    final idx = norm.indexOf('кроме');
    if (idx < 0) return (norm, const <String>[]);
    final base = norm.substring(0, idx).trim();
    final exceptions = norm
        .substring(idx + 'кроме'.length)
        .split(RegExp(r'[,;/]|\sи\s'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return (base, exceptions);
  }

  /// Матчится ли МНН-запрос к записи группы.
  /// Исключения сильнее базы и проверяются ПЕРВЫМИ: совпал с «кроме X» —
  /// запись не матчится, даже если совпала и сама группа (⚠ Фикс VV-004,
  /// ревью 26.11.2026: раньше «тилмикозин» ловился подстрокой в «макролиды
  /// (кроме тилмикозина)» и получал «Разрешён при беременности»).
  static bool _entryMatches(String entry, List<String> queryTokens) {
    final (base, exceptions) = _splitExclusions(entry);
    for (final ex in exceptions) {
      final exTokens = _innTokens(ex);
      final hit = exTokens.any(
        (t) => queryTokens.any((q) => _tokenMatches(t, q)),
      );
      if (hit) return false;
    }
    final baseTokens = _innTokens(base);
    if (baseTokens.isEmpty) return false;
    return baseTokens.any(
      (t) => queryTokens.any((q) => _tokenMatches(t, q)),
    );
  }

  /// Проверяет статус препарата при беременности.
  ///
  /// ⚠ Фикс VV-004 (ревью 26.11.2026): вместо наивного substring-поиска
  /// s.contains(q) || q.contains(s) — (1) записи понимают исключения
  /// «кроме X», (2) МНН матчится целыми токенами (стем-толерантно к
  /// падежам), (3) нормализация запроса: регистр, ё→е, срезка ®™©.
  /// Порядок проверки прежний: contraindicated → caution → safe.
  String? checkPregnancy(String drugName) {
    final queryTokens = _innTokens(drugName);
    if (queryTokens.isEmpty) return null;
    for (final c in contraindicated) {
      if (_entryMatches(c.drug, queryTokens)) {
        // VV-050: причина больше не теряется — «…: тетрациклины —
        // поражение печени, зубы»; без причины формат прежний.
        final r = c.reason?.trim();
        return (r == null || r.isEmpty)
            ? 'ПРОТИВОПОКАЗАН при беременности'
            : 'ПРОТИВОПОКАЗАН при беременности: ${c.display}';
      }
    }
    for (final s in caution) {
      if (_entryMatches(s, queryTokens)) {
        return 'С ОСТОРОЖНОСТЬЮ при беременности';
      }
    }
    for (final s in safe) {
      if (_entryMatches(s, queryTokens)) {
        return 'Разрешён при беременности';
      }
    }
    return null;
  }
}

/// Полная база корректировок доз
class DoseAdjustmentDatabase {
  final OrganAdjustment? renal;
  final OrganAdjustment? hepatic;
  final OrganAdjustment? cardiac;
  final AgeAdjustments? age;
  final PregnancyAdjustment? pregnancy;

  const DoseAdjustmentDatabase({
    this.renal,
    this.hepatic,
    this.cardiac,
    this.age,
    this.pregnancy,
  });

  factory DoseAdjustmentDatabase.fromJson(Map<String, dynamic> json) {
    return DoseAdjustmentDatabase(
      renal: json['renal_adjustment'] is Map
          ? OrganAdjustment.fromJson(json['renal_adjustment'] as Map<String, dynamic>)
          : null,
      hepatic: json['hepatic_adjustment'] is Map
          ? OrganAdjustment.fromJson(json['hepatic_adjustment'] as Map<String, dynamic>)
          : null,
      cardiac: json['cardiac_adjustment'] is Map
          ? OrganAdjustment.fromJson(json['cardiac_adjustment'] as Map<String, dynamic>)
          : null,
      age: json['age_adjustments'] is Map
          ? AgeAdjustments.fromJson(json['age_adjustments'] as Map<String, dynamic>)
          : null,
      pregnancy: json['pregnancy_lactation'] is Map
          ? PregnancyAdjustment.fromJson(json['pregnancy_lactation'] as Map<String, dynamic>)
          : null,
    );
  }
}