import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/drug.dart';
import '../models/drug_registry.dart';
import '../models/calc_drug.dart';
import '../models/dosage_database.dart';
import '../models/drug_interaction.dart';
import '../models/antidote.dart';
import '../models/emergency_protocol.dart';
import '../models/side_effects.dart';
import '../models/withdrawal.dart';
import '../models/dose_adjustment.dart';
import '../models/unofficial_protocol.dart';
import '../models/fluid_therapy.dart';
import '../models/verified_dosage.dart';
import '../models/mia.dart';

/// Результат загрузки баз
class LoadResult {
  final DrugDatabase? database;
  final DrugRegistry? registry;
  final CalcDrugDatabase? calcDatabase;
  final DosageDatabase? dosageDatabase;
  final InteractionDatabase? interactionDatabase;
  final AntidoteDatabase? antidoteDatabase;
  final EmergencyDatabase? emergencyDatabase;
  final SideEffectsDatabase? sideEffectsDatabase;
  // === Новые подключённые базы ===
  final WithdrawalDatabase? withdrawalDatabase;
  final DoseAdjustmentDatabase? doseAdjustmentDatabase;
  final UnofficialProtocolDatabase? unofficialDatabase;
  final FluidTherapyDatabase? fluidTherapyDatabase;
  final VerifiedDosageDatabase? verifiedDosageDatabase;
  final bool fromNetwork;
  final String source;

  const LoadResult({
    this.database,
    this.registry,
    this.calcDatabase,
    this.dosageDatabase,
    this.interactionDatabase,
    this.antidoteDatabase,
    this.emergencyDatabase,
    this.sideEffectsDatabase,
    this.withdrawalDatabase,
    this.doseAdjustmentDatabase,
    this.unofficialDatabase,
    this.fluidTherapyDatabase,
    this.verifiedDosageDatabase,
    required this.fromNetwork,
    required this.source,
  });

  int get totalDrugs => registry?.totalDrugs ?? calcDatabase?.drugs.length ?? database?.drugs.length ?? 0;
  int get calcDrugsCount => calcDatabase?.drugs.length ?? database?.drugs.length ?? 0;
  int get dosageCount => dosageDatabase?.dosages.length ?? 0;
  int get interactionCount => interactionDatabase?.interactions.length ?? 0;
  int get antidoteCount => antidoteDatabase?.poisonings.length ?? 0;
  int get emergencyCount => emergencyDatabase?.protocols.length ?? 0;
  int get sideEffectsCount => sideEffectsDatabase?.drugs.length ?? 0;
  int get withdrawalCount => withdrawalDatabase?.drugs.length ?? 0;
  int get unofficialCount => unofficialDatabase?.records.length ?? 0;
  int get fluidSolutionsCount => fluidTherapyDatabase?.solutions.length ?? 0;
}

/// Спецификация одной базы: где лежит (assets) и как парсить.
class _DbSpec {
  final String fileName; // имя файла (идентификатор базы)
  final String assetPath; // путь в бандле
  final Object Function(Map<String, dynamic>) fromJson;

  const _DbSpec({
    required this.fileName,
    required this.assetPath,
    required this.fromJson,
  });
}

/// Сервис для загрузки баз препаратов.
///
/// v1.20.1 — assets-only: сетевого апдейта больше НЕТ.
/// Прежний механизм (GitLab raw + дисковый кеш 24 ч) вырублен: GitLab-копия
/// репозитория протухла — GitHub давно мастер, а «обновление» баз с GitLab
/// могло откатить данные НАЗАД на дорефакторные (фиксы доз Task 182/186
/// живут только в assets GitHub). Обновление баз теперь = новый релиз APK.
///
///  • loadDatabase()/loadCore() мемоизированы — один раз на сессию;
///  • тяжёлый jsonDecode больших файлов уходит в background-isolate;
///  • staged-загрузка (ядро сразу, вторичные базы после первого кадра)
///    сохранена — старт дома по-прежнему быстрый.
class DrugLoaderService {
  /// Файлы больше этого размера декодируются в background-isolate.
  static const int _isolateDecodeThreshold = 512 * 1024;

  /// Мемо: базы собираются один раз на сессию.
  static LoadResult? _memo;

  // v1.16.3: staged-загрузка. Ядро (расчёт доз на home) парсим сразу,
  // остальные базы — фоном ПОСЛЕ первого кадра: «секунд 5 пишет что идёт
  // загрузка баз» сокращается примерно вдвое (unofficial_protocols 5.7МБ +
  // verified_dosages 6МБ + treatment_protocols 1МБ уходят с критического пути).
  static const Set<String> _coreFileNames = {
    'drugs_calc.json', // 7.0 МБ — препараты калькулятора + животные
    'drugs_registry.json', // 7.3 МБ — реестр (выбор препарата)
    'dosage_database.json', // дозировки по МНН
    'drug_interactions.json', // предупреждения совместимости в result_card
  };
  static LoadResult? _coreMemo;

  /// v1.16.3: источник последней _loadOnce — для корректного статуса в UI
  /// (loadCore вызывает _buildResult уже ПОСЛЕ _loadOnce).
  static bool _lastLoadWasOnline = false;
  static String? _lastLoadSource;

  /// Сырые JSON-строки последней загрузки (assetPath → содержимое).
  /// Переиспользуется SymptomSearchService и др. без повторного чтения.
  static Map<String, String>? _lastRaws;
  static Map<String, String>? get cachedRaws => _lastRaws;

  /// Таблица всех баз. Порядок = порядок в LoadResult.
  static final Map<String, _DbSpec> _specs = {
    'drugs_registry.json': _DbSpec(
      fileName: 'drugs_registry.json',
      assetPath: 'assets/data/drugs_registry.json',
      fromJson: DrugRegistry.fromJson,
    ),
    'drugs_calc.json': _DbSpec(
      fileName: 'drugs_calc.json',
      assetPath: 'assets/data/drugs_calc.json',
      fromJson: CalcDrugDatabase.fromJson,
    ),
    'drugs.json': _DbSpec(
      fileName: 'drugs.json',
      assetPath: 'assets/data/drugs.json',
      fromJson: DrugDatabase.fromJson,
    ),
    'dosage_database.json': _DbSpec(
      fileName: 'dosage_database.json',
      assetPath: 'assets/data/dosage_database.json',
      fromJson: DosageDatabase.fromJson,
    ),
    'drug_interactions.json': _DbSpec(
      fileName: 'drug_interactions.json',
      assetPath: 'assets/data/advanced/drug_interactions.json',
      fromJson: InteractionDatabase.fromJson,
    ),
    'antidotes.json': _DbSpec(
      fileName: 'antidotes.json',
      assetPath: 'assets/data/advanced/antidotes.json',
      fromJson: AntidoteDatabase.fromJson,
    ),
    'emergency_protocols.json': _DbSpec(
      fileName: 'emergency_protocols.json',
      assetPath: 'assets/data/advanced/emergency_protocols.json',
      fromJson: EmergencyDatabase.fromJson,
    ),
    'side_effects.json': _DbSpec(
      fileName: 'side_effects.json',
      assetPath: 'assets/data/advanced/side_effects.json',
      fromJson: SideEffectsDatabase.fromJson,
    ),
    'withdrawal_by_product.json': _DbSpec(
      fileName: 'withdrawal_by_product.json',
      assetPath: 'assets/data/advanced/withdrawal_by_product.json',
      fromJson: WithdrawalDatabase.fromJson,
    ),
    'dose_adjustments.json': _DbSpec(
      fileName: 'dose_adjustments.json',
      assetPath: 'assets/data/advanced/dose_adjustments.json',
      fromJson: DoseAdjustmentDatabase.fromJson,
    ),
    'fluid_therapy.json': _DbSpec(
      fileName: 'fluid_therapy.json',
      assetPath: 'assets/data/advanced/fluid_therapy.json',
      fromJson: FluidTherapyDatabase.fromJson,
    ),
    'unofficial_protocols.json': _DbSpec(
      fileName: 'unofficial_protocols.json',
      assetPath: 'assets/data/unofficial_protocols.json',
      fromJson: UnofficialProtocolDatabase.fromJson,
    ),
    'verified_dosages.json': _DbSpec(
      fileName: 'verified_dosages.json',
      assetPath: 'assets/data/verified_dosages.json',
      fromJson: VerifiedDosageDatabase.fromJson,
    ),
    // Идея №4: WHO MIA 2024 — таблица классов + сгенерированный гейтом
    // слой решений. Dart НЕ резолвит INN сам: lookup по id препарата.
    'mia_classes.json': _DbSpec(
      fileName: 'mia_classes.json',
      assetPath: 'assets/data/mia_classes.json',
      fromJson: MiaDatabase.fromJson,
    ),
    'mia_drugs.json': _DbSpec(
      fileName: 'mia_drugs.json',
      assetPath: 'assets/data/mia_drugs.json',
      fromJson: MiaDrugMap.fromJson,
    ),
  };

  // ============================================================
  // Публичный API
  // ============================================================

  /// Загружает все базы (кешировано на сессию).
  static Future<LoadResult> loadDatabase() async {
    if (_memo != null) return _memo!;
    final result = await _loadOnce();
    _memo = result;
    return result;
  }

  /// v1.16.3: СТАДИЯ 1 — только ядро для home (расчёт доз, выбор препарата,
  /// совместимость). Сырьё читается целиком (assets), но парсинг
  /// вторичных баз откладывается до [parseExtended].
  static Future<LoadResult> loadCore() async {
    if (_coreMemo != null) return _coreMemo!;
    final raws = await _loadRaws();
    final result = await _buildResult(raws,
        online: _lastLoadWasOnline,
        source: _lastLoadSource,
        coreOnly: true);
    _coreMemo = result;
    return result;
  }

  /// v1.16.3: СТАДИЯ 2 — парсинг остальных баз из уже прочитанного сырья
  /// ([_lastRaws]). Вызывается фоном после первого кадра; вернёт null,
  /// если loadCore ещё не отработал.
  static Future<ExtendedDatabases?> parseExtended() async {
    final raws = _lastRaws;
    if (raws == null) return null;
    final specs = _specs.values
        .where((s) => raws.containsKey(s.assetPath))
        .where((s) => !_coreFileNames.contains(s.fileName))
        .toList();
    final parsedList = <Object?>[];
    const batchSize = 4;
    for (int i = 0; i < specs.length; i += batchSize) {
      final batch = specs.sublist(i, (i + batchSize).clamp(0, specs.length));
      final part = await Future.wait(batch.map((spec) async {
        final raw = raws[spec.assetPath]!;
        try {
          return await compute(_parseIsolateEntry<Object>, (raw, spec.fromJson));
        } catch (e) {
          debugPrint('⚠️ [DrugLoader] Ошибка парсинга ${spec.fileName}: $e');
          return null;
        }
      }));
      parsedList.addAll(part);
    }

    DrugDatabase? database;
    AntidoteDatabase? antidoteDatabase;
    EmergencyDatabase? emergencyDatabase;
    SideEffectsDatabase? sideEffectsDatabase;
    WithdrawalDatabase? withdrawalDatabase;
    DoseAdjustmentDatabase? doseAdjustmentDatabase;
    UnofficialProtocolDatabase? unofficialDatabase;
    FluidTherapyDatabase? fluidTherapyDatabase;
    VerifiedDosageDatabase? verifiedDosageDatabase;
    MiaDatabase? miaDatabase;
    MiaDrugMap? miaDrugMap;
    for (final parsed in parsedList) {
      if (parsed == null) continue;
      if (parsed is DrugDatabase) {
        database = parsed;
      } else if (parsed is AntidoteDatabase) {
        antidoteDatabase = parsed;
        debugPrint('✅ Антидоты: ${antidoteDatabase.poisonings.length} токсинов');
      } else if (parsed is EmergencyDatabase) {
        emergencyDatabase = parsed;
        debugPrint('✅ Emergency: ${emergencyDatabase.protocols.length} протоколов');
      } else if (parsed is SideEffectsDatabase) {
        sideEffectsDatabase = parsed;
        debugPrint('✅ Побочные эффекты: ${sideEffectsDatabase.drugs.length} препаратов');
      } else if (parsed is WithdrawalDatabase) {
        withdrawalDatabase = parsed;
        debugPrint('✅ Сроки ожидания: ${withdrawalDatabase.drugs.length} препаратов');
      } else if (parsed is DoseAdjustmentDatabase) {
        doseAdjustmentDatabase = parsed;
        debugPrint('✅ Корректировки доз загружены');
      } else if (parsed is UnofficialProtocolDatabase) {
        unofficialDatabase = parsed;
        debugPrint('✅ Неофициальные протоколы: ${unofficialDatabase.records.length} записей');
      } else if (parsed is FluidTherapyDatabase) {
        fluidTherapyDatabase = parsed;
        debugPrint('✅ Инфузионная терапия: ${fluidTherapyDatabase.solutions.length} растворов');
      } else if (parsed is VerifiedDosageDatabase) {
        verifiedDosageDatabase = parsed;
        debugPrint('✅ Верифицированные дозировки: ${verifiedDosageDatabase.dosages.length} препаратов');
      } else if (parsed is MiaDatabase) {
        miaDatabase = parsed;
        debugPrint('✅ WHO MIA: ${miaDatabase.classes.length} классов (издание 2024)');
      } else if (parsed is MiaDrugMap) {
        miaDrugMap = parsed;
        debugPrint('✅ WHO MIA: слой на ${miaDrugMap.entries.length} препаратов базы');
      }
    }
    return ExtendedDatabases(
      database: database,
      miaDatabase:
          miaDatabase?.withDrugMap(miaDrugMap ?? const MiaDrugMap({})),
      antidoteDatabase: antidoteDatabase,
      emergencyDatabase: emergencyDatabase,
      sideEffectsDatabase: sideEffectsDatabase,
      withdrawalDatabase: withdrawalDatabase,
      doseAdjustmentDatabase: doseAdjustmentDatabase,
      unofficialDatabase: unofficialDatabase,
      fluidTherapyDatabase: fluidTherapyDatabase,
      verifiedDosageDatabase: verifiedDosageDatabase,
    );
  }

  /// Сырой JSON по assetPath: сначала из памяти (последняя загрузка),
  /// затем из assets. Для вторичных потребителей (поиск по симптомам).
  static Future<String?> getRawJson(String assetPath) async {
    final cached = _lastRaws?[assetPath];
    if (cached != null) return cached;
    try {
      return await rootBundle.loadString(assetPath);
    } catch (e) {
      debugPrint('[DrugLoader] getRawJson($assetPath): $e');
      return null;
    }
  }

  /// v1.16.2: decode + parse произвольного JSON в background-isolate.
  /// Используется для болезней/протоколов лечения (vet_provider) и любых
  /// внешних потребителей — тяжёлый fromJson больше не считает на главном
  /// изоляте. Вернёт null при ошибке (вызывающий решает, что делать).
  static Future<T?> parseInIsolate<T>(
      String raw, T Function(Map<String, dynamic>) fromJson) async {
    try {
      return await compute(_parseIsolateEntry<T>, (raw, fromJson));
    } catch (e) {
      debugPrint('⚠️ [DrugLoader] parseInIsolate: $e');
      return null;
    }
  }

  // ============================================================
  // Основной конвейер загрузки
  // ============================================================

  /// v1.20.1: чтение сырья — ТОЛЬКО assets. Сети больше нет (см. доккласс):
  /// GitLab-зеркало протухло, «обновление» с него откатывало бы фиксы данных.
  static Future<Map<String, String>> _loadRaws() async {
    debugPrint('📦 [DrugLoader] Загрузка баз из assets (assets-only)');
    _lastLoadWasOnline = false;
    _lastLoadSource = 'Локальные базы (обновляются вместе с приложением)';
    return _readAssetRaws();
  }

  /// Загружает и парсит ВСЕ базы (legacy-путь; home использует loadCore+parseExtended).
  static Future<LoadResult> _loadOnce() async {
    final raws = await _loadRaws();
    return await _buildResult(raws,
        online: _lastLoadWasOnline, source: _lastLoadSource);
  }

  /// Собирает LoadResult из сырых JSON-строк (assetPath → содержимое).
  ///
  /// v1.16.2: decode+parse КАЖДОЙ базы — в background-isolate (батчами по 4).
  /// Раньше jsonDecode уходил в изолят только для больших файлов, а fromJson
  /// ВСЕГДА считался на главном изоляте: суммарно 3-5 с тормозили UI на
  /// каждом старте («секунд 5 пишет что идет загрузка баз»), даже когда
  /// базы были в дисковом кеше.
  static Future<LoadResult> _buildResult(
    Map<String, String> raws, {
    required bool online,
    String? source,
    bool coreOnly = false,
  }) async {
    // Сырьё доступно вторичным потребителям (SymptomSearchService) без
    // повторного чтения — в т.ч. при старте из дискового кеша.
    _lastRaws = raws;

    DrugDatabase? database;
    DrugRegistry? registry;
    CalcDrugDatabase? calcDatabase;
    DosageDatabase? dosageDatabase;
    InteractionDatabase? interactionDatabase;
    AntidoteDatabase? antidoteDatabase;
    EmergencyDatabase? emergencyDatabase;
    SideEffectsDatabase? sideEffectsDatabase;
    WithdrawalDatabase? withdrawalDatabase;
    DoseAdjustmentDatabase? doseAdjustmentDatabase;
    UnofficialProtocolDatabase? unofficialDatabase;
    FluidTherapyDatabase? fluidTherapyDatabase;
    VerifiedDosageDatabase? verifiedDosageDatabase;

    final specs = _specs.values
        .where((s) => raws.containsKey(s.assetPath))
        // v1.16.3: coreOnly — парсим только ядро, вторичные базы ждёт
        // parseExtended() после первого кадра.
        .where((s) => !coreOnly || _coreFileNames.contains(s.fileName))
        .toList();
    final parsedList = <Object?>[];
    const batchSize = 4; // не плодим 13 изолятов разом на low-end устройствах
    for (int i = 0; i < specs.length; i += batchSize) {
      final batch =
          specs.sublist(i, (i + batchSize).clamp(0, specs.length));
      final part = await Future.wait(batch.map((spec) async {
        final raw = raws[spec.assetPath]!;
        try {
          return await compute(_parseIsolateEntry<Object>, (raw, spec.fromJson));
        } catch (e) {
          debugPrint('⚠️ [DrugLoader] Ошибка парсинга ${spec.fileName}: $e');
          return null;
        }
      }));
      parsedList.addAll(part);
    }

    for (final parsed in parsedList) {
      if (parsed == null) continue;
      if (parsed is DrugRegistry) {
        registry = parsed;
        debugPrint('✅ Реестр: ${registry.totalDrugs} препаратов');
      } else if (parsed is CalcDrugDatabase) {
        calcDatabase = parsed;
        debugPrint('✅ База расчётов: ${calcDatabase.drugs.length} препаратов');
      } else if (parsed is DrugDatabase) {
        database = parsed;
      } else if (parsed is DosageDatabase) {
        dosageDatabase = parsed;
        debugPrint('✅ База дозировок: ${dosageDatabase.dosages.length} МНН');
      } else if (parsed is InteractionDatabase) {
        interactionDatabase = parsed;
        debugPrint('✅ Взаимодействия: ${interactionDatabase.interactions.length} пар');
      } else if (parsed is AntidoteDatabase) {
        antidoteDatabase = parsed;
        debugPrint('✅ Антидоты: ${antidoteDatabase.poisonings.length} токсинов');
      } else if (parsed is EmergencyDatabase) {
        emergencyDatabase = parsed;
        debugPrint('✅ Emergency: ${emergencyDatabase.protocols.length} протоколов');
      } else if (parsed is SideEffectsDatabase) {
        sideEffectsDatabase = parsed;
        debugPrint('✅ Побочные эффекты: ${sideEffectsDatabase.drugs.length} препаратов');
      } else if (parsed is WithdrawalDatabase) {
        withdrawalDatabase = parsed;
        debugPrint('✅ Сроки ожидания: ${withdrawalDatabase.drugs.length} препаратов');
      } else if (parsed is DoseAdjustmentDatabase) {
        doseAdjustmentDatabase = parsed;
        debugPrint('✅ Корректировки доз загружены');
      } else if (parsed is UnofficialProtocolDatabase) {
        unofficialDatabase = parsed;
        debugPrint('✅ Неофициальные протоколы: ${unofficialDatabase.records.length} записей');
      } else if (parsed is FluidTherapyDatabase) {
        fluidTherapyDatabase = parsed;
        debugPrint('✅ Инфузионная терапия: ${fluidTherapyDatabase.solutions.length} растворов');
      } else if (parsed is VerifiedDosageDatabase) {
        verifiedDosageDatabase = parsed;
        debugPrint('✅ Верифицированные дозировки: ${verifiedDosageDatabase.dosages.length} препаратов');
      }
    }

    // База без животных — добираем из assets (защита от кривого JSON).
    if (calcDatabase != null && calcDatabase.animals.isEmpty) {
      try {
        final localAnimals = await _loadLocalAnimals();
        if (localAnimals.isNotEmpty) {
          calcDatabase = CalcDrugDatabase(
            version: calcDatabase.version,
            source: calcDatabase.source,
            lastUpdated: calcDatabase.lastUpdated,
            drugs: calcDatabase.drugs,
            animals: localAnimals,
          );
          debugPrint('✅ Животные подгружены из assets: ${localAnimals.length} шт.');
        }
      } catch (e) {
        debugPrint('⚠️ Ошибка загрузки животных из assets: $e');
      }
    }

    final resolvedSource = source ??
        (online
            ? 'Онлайн (${registry?.totalDrugs ?? 0} препаратов, ${interactionDatabase?.interactions.length ?? 0} взаимодействий)'
            : 'Офлайн (${registry?.totalDrugs ?? calcDatabase?.drugs.length ?? 0} препаратов)');

    return LoadResult(
      database: database,
      registry: registry,
      calcDatabase: calcDatabase,
      dosageDatabase: dosageDatabase,
      interactionDatabase: interactionDatabase,
      antidoteDatabase: antidoteDatabase,
      emergencyDatabase: emergencyDatabase,
      sideEffectsDatabase: sideEffectsDatabase,
      withdrawalDatabase: withdrawalDatabase,
      doseAdjustmentDatabase: doseAdjustmentDatabase,
      unofficialDatabase: unofficialDatabase,
      fluidTherapyDatabase: fluidTherapyDatabase,
      verifiedDosageDatabase: verifiedDosageDatabase,
      fromNetwork: online,
      source: resolvedSource,
    );
  }

  // ============================================================
  // Источники: assets
  // ============================================================

  /// Чтение всех (или только [onlyKeys]) баз из assets. assetPath → raw.
  static Future<Map<String, String>> _readAssetRaws({Set<String>? onlyKeys}) async {
    final raws = <String, String>{};
    for (final spec in _specs.values) {
      if (onlyKeys != null && !onlyKeys.contains(spec.assetPath)) continue;
      try {
        raws[spec.assetPath] = await rootBundle.loadString(spec.assetPath);
      } catch (e) {
        debugPrint('⚠️ [DrugLoader] Asset ${spec.assetPath}: $e');
      }
    }
    return raws;
  }

  // ============================================================
  // Утилиты
  // ============================================================

  /// jsonDecode с выносом тяжёлых файлов в background-isolate.
  static Future<Map<String, dynamic>> _decodeMap(String raw) async {
    if (raw.length > _isolateDecodeThreshold) {
      return compute(_decodeJsonInIsolate, raw);
    }
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  /// Загружает список животных из локального assets (патч сетевой базы).
  static Future<List<Animal>> _loadLocalAnimals() async {
    try {
      final str = await rootBundle.loadString('assets/data/drugs_calc.json');
      final json = await _decodeMap(str);
      final animalsRaw = json['animals'] as List<dynamic>?;
      if (animalsRaw == null) return [];
      final animals = <Animal>[];
      for (int i = 0; i < animalsRaw.length; i++) {
        try {
          animals.add(Animal.fromJson(animalsRaw[i] as Map<String, dynamic>));
        } catch (e) {
          debugPrint('⚠️ Ошибка парсинга животного #$i: $e');
        }
      }
      return animals;
    } catch (e) {
      debugPrint('⚠️ Ошибка загрузки животных: $e');
      return [];
    }
  }

  /// Загружает JSON из assets (публичный API — используется провайдером).
  static Future<Map<String, dynamic>?> loadJsonAsset(String path) async {
    try {
      final str = await rootBundle.loadString(path);
      return await _decodeMap(str);
    } catch (e) {
      debugPrint('Error loading $path: $e');
      return null;
    }
  }

  /// v1.20.1: сети в загрузчике больше нет — индикатор «устройство онлайн»
  /// для чипа на home-grid. Базы с DNS не связаны (assets-only).
  static Future<bool> isNetworkAvailable() async {
    try {
      final result = await InternetAddress.lookup('github.com');
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}

/// Top-level функция для compute(): jsonDecode + fromJson целиком в
/// background-isolate. Запись (raw, fromJson) отправляется между изолятами
/// одной isolate-group — tear-off статической функции модели отправляемый.
T _parseIsolateEntry<T>((String, T Function(Map<String, dynamic>)) msg) {
  final (raw, fromJson) = msg;
  return fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

/// Top-level функция для compute(): jsonDecode в background-isolate.
Map<String, dynamic> _decodeJsonInIsolate(String raw) {
  return jsonDecode(raw) as Map<String, dynamic>;
}

/// v1.16.3: результат СТАДИИ 2 — вторичные базы, парс которых уходит с
/// критического пути старта (домашний экран их для расчёта доз не ждёт).
class ExtendedDatabases {
  final DrugDatabase? database;
  final AntidoteDatabase? antidoteDatabase;
  final EmergencyDatabase? emergencyDatabase;
  final SideEffectsDatabase? sideEffectsDatabase;
  final WithdrawalDatabase? withdrawalDatabase;
  final DoseAdjustmentDatabase? doseAdjustmentDatabase;
  final UnofficialProtocolDatabase? unofficialDatabase;
  final FluidTherapyDatabase? fluidTherapyDatabase;
  final VerifiedDosageDatabase? verifiedDosageDatabase;
  final MiaDatabase? miaDatabase;

  const ExtendedDatabases({
    this.database,
    this.miaDatabase,
    this.antidoteDatabase,
    this.emergencyDatabase,
    this.sideEffectsDatabase,
    this.withdrawalDatabase,
    this.doseAdjustmentDatabase,
    this.unofficialDatabase,
    this.fluidTherapyDatabase,
    this.verifiedDosageDatabase,
  });
}
