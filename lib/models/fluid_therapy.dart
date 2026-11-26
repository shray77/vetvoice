import 'package:flutter/foundation.dart';

/// Раствор для инфузионной терапии
class FluidSolution {
  final String name;
  final String type;
  final String composition;
  final List<String> indications;
  final String tonicity;
  final String rate;
  // Ревью 26.11.2026, VV-051: суточный потолок дозы коллоидов
  // (Гелофузин / Венофундин ГЭК — «20 мл/кг/сут») и период полувыведения
  // («4-6 часов») лежат в JSON, но fromJson их не читал — врач не видел
  // лимита и мог молча его превысить. null = поле в JSON отсутствует.
  final String? maxDose;
  final String? halfLife;

  const FluidSolution({
    required this.name,
    required this.type,
    required this.composition,
    required this.indications,
    required this.tonicity,
    required this.rate,
    this.maxDose,
    this.halfLife,
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
      // Ревью 26.11.2026, VV-051: max_dose / half_life доходят из JSON.
      maxDose: _tolerantString(json['max_dose']),
      halfLife: _tolerantString(json['half_life']),
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
  // Ревью 26.11.2026, VV-012: правило контроля при инфузии — у
  // Ca-глюконата 10% это условие НЕМЕДЛЕННОЙ ОСТАНОВКИ инфузии
  // («ЭКГ (брадикардия = остановить!)»). Поле было только в JSON,
  // fromJson его не читал — предупреждение не доезжало до врача.
  final String? monitoring;

  const FluidAdditive({
    required this.name,
    required this.indication,
    required this.concentration,
    required this.doses,
    required this.maxRate,
    required this.notes,
    this.monitoring,
  });

  factory FluidAdditive.fromJson(Map<String, dynamic> json) {
    final rawDoses = json['doses'] as Map<String, dynamic>? ?? {};
    final doses = <String, String>{};
    rawDoses.forEach((k, v) => doses[k.toString()] = v.toString());
    return FluidAdditive(
      name: json['name'] as String? ?? '',
      // Ревью 26.11.2026, VV-012: у части добавок (Ca-глюконат 10%,
      // MgSO4 25%) indication — СПИСОК, а не строка. Жёсткий `as String?`
      // кидал TypeError, а per-item catch в FluidTherapyDatabase.fromJson
      // молча выбрасывал запись ЦЕЛИКОМ — вместе с monitoring и прочими
      // полями (класс бага S-1 из Task 183). Принимаем строку и список.
      indication: _tolerantString(json['indication']) ?? '',
      concentration: json['concentration'] as String? ?? '',
      doses: doses,
      maxRate: json['max_rate'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      monitoring: _tolerantString(json['monitoring']),
    );
  }
}

/// Ревью 26.11.2026, VV-012: толерантный парсинг текстового поля JSON —
/// String | List | null. Список склеиваем через запятую, null остаётся
/// null (пустые строки не подставляем: экран различает «поля нет»).
String? _tolerantString(dynamic v) {
  if (v == null) return null;
  if (v is String) return v;
  if (v is List) return v.map((e) => e.toString()).join(', ');
  return v.toString();
}

/// Шаг/фаза протокола инфузии.
///
/// ⚠ Фикс (ревью 26.11.2026, находка аудита VV-012-блока): protocol в JSON —
/// список шагов-фаз ({phase, fluid, rate, duration?, notes?}, у «Отёка
/// лёгких» — и терапевтические шаги {therapy, dose?, frequency?, notes?}),
/// а модель ждала строку → TypeError, и все 4 протокола молча выбрасывались
/// per-item catch-ем — вкладка «Протоколы» была пустой. Поля шага —
/// необязательные, состав зависит от типа шага.
class FluidProtocolStep {
  final String? phase;
  final String? fluid;
  final String? rate;
  final String? duration;
  final String? notes;
  final String? therapy;
  final String? dose;
  final String? frequency;

  const FluidProtocolStep({
    this.phase,
    this.fluid,
    this.rate,
    this.duration,
    this.notes,
    this.therapy,
    this.dose,
    this.frequency,
  });

  factory FluidProtocolStep.fromJson(Map<String, dynamic> json) {
    return FluidProtocolStep(
      phase: json['phase'] as String?,
      fluid: json['fluid'] as String?,
      rate: json['rate'] as String?,
      duration: json['duration'] as String?,
      notes: json['notes'] as String?,
      therapy: json['therapy'] as String?,
      dose: json['dose'] as String?,
      frequency: json['frequency'] as String?,
    );
  }

  /// Строка карточки: «фаза/терапия: жидкость — доза — скорость — длительность»
  /// (+ notes). Пустые куски не склеиваются.
  String get display {
    final head = phase ?? therapy ?? '';
    final parts = <String>[
      if ((fluid ?? '').isNotEmpty) fluid!,
      if ((dose ?? '').isNotEmpty) dose!,
      if ((rate ?? '').isNotEmpty) rate!,
      if ((frequency ?? '').isNotEmpty) frequency!,
      if ((duration ?? '').isNotEmpty) duration!,
    ];
    final body = parts.join(' — ');
    var line = head.isEmpty ? body : (body.isEmpty ? head : '$head: $body');
    if ((notes ?? '').isNotEmpty) {
      line = line.isEmpty ? notes! : '$line ($notes!)';
    }
    return line;
  }
}

/// Специальный протокол инфузии
class FluidSpecialProtocol {
  final String name;
  final String species;
  final List<FluidProtocolStep> protocol;
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
    final steps = <FluidProtocolStep>[];
    final raw = json['protocol'];
    if (raw is List) {
      for (int i = 0; i < raw.length; i++) {
        if (raw[i] is Map<String, dynamic>) {
          try {
            steps.add(FluidProtocolStep.fromJson(
                raw[i] as Map<String, dynamic>));
          } catch (e) {
            debugPrint('⚠️ FluidProtocolStep #$i parse error: $e');
          }
        }
      }
    }
    return FluidSpecialProtocol(
      name: json['name'] as String? ?? '',
      species: json['species'] as String? ?? '',
      protocol: steps,
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
      s.indications.any((ind) => ind.toLowerCase().contains(q)),
    ).toList();
  }
}