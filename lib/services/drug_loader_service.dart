import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
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

/// Спецификация одной базы: где лежит (assets / сеть) и как парсить.
class _DbSpec {
  final String fileName; // имя файла в дисковом кеше
  final String assetPath; // путь в бандле (все базы есть в assets)
  final String? url; // GitLab raw (null — только assets)
  final Object Function(Map<String, dynamic>) fromJson;

  const _DbSpec({
    required this.fileName,
    required this.assetPath,
    this.url,
    required this.fromJson,
  });
}

/// Сервис для загрузки баз препаратов.
///
/// v1.16.1 — offline-first с дисковым кешем:
///  1. Свежий дисковый кеш (< 24 ч) → мгновенный старт БЕЗ сети.
///  2. Иначе — сеть (параллельно, таймаут 8 с) → кеш обновляется.
///  3. Нет сети и кеша → assets (как раньше), кеш создаётся из assets.
///
/// Дополнительно:
///  • loadDatabase() мемоизирован — один раз на сессию;
///  • тяжёлый jsonDecode больших файлов уходит в background-isolate;
///  • расхождение старой логики устранено: раньше в онлайн-режиме
///    терялись unofficial_protocols и verified_dosages (они грузились
///    только из assets) — теперь assets-only базы добираются всегда.
class DrugLoaderService {
  static const String _gitlabBase =
      'https://gitlab.com/shray77/vetvoice/-/raw/main/assets/data';
  static const String _advancedDir = '$_gitlabBase/advanced';

  static String get updateUrl => '$_gitlabBase/drugs_calc.json';

  static const Duration _networkTimeout = Duration(seconds: 8);
  static const Duration _cacheTtl = Duration(hours: 24);
  /// Файлы больше этого размера декодируются в background-isolate.
  static const int _isolateDecodeThreshold = 512 * 1024;

  /// Мемо: базы собираются один раз на сессию.
  static LoadResult? _memo;

  /// Сырые JSON-строки последней загрузки (assetPath → содержимое).
  /// Переиспользуется SymptomSearchService и др. без повторного чтения.
  static Map<String, String>? _lastRaws;
  static Map<String, String>? get cachedRaws => _lastRaws;

  /// Таблица всех баз. Порядок = порядок в LoadResult.
  static final Map<String, _DbSpec> _specs = {
    'drugs_registry.json': _DbSpec(
      fileName: 'drugs_registry.json',
      assetPath: 'assets/data/drugs_registry.json',
      url: '$_gitlabBase/drugs_registry.json',
      fromJson: DrugRegistry.fromJson,
    ),
    'drugs_calc.json': _DbSpec(
      fileName: 'drugs_calc.json',
      assetPath: 'assets/data/drugs_calc.json',
      url: '$_gitlabBase/drugs_calc.json',
      fromJson: CalcDrugDatabase.fromJson,
    ),
    'drugs.json': _DbSpec(
      fileName: 'drugs.json',
      assetPath: 'assets/data/drugs.json',
      url: '$_gitlabBase/drugs.json',
      fromJson: DrugDatabase.fromJson,
    ),
    'dosage_database.json': _DbSpec(
      fileName: 'dosage_database.json',
      assetPath: 'assets/data/dosage_database.json',
      url: '$_gitlabBase/dosage_database.json',
      fromJson: DosageDatabase.fromJson,
    ),
    'drug_interactions.json': _DbSpec(
      fileName: 'drug_interactions.json',
      assetPath: 'assets/data/advanced/drug_interactions.json',
      url: '$_advancedDir/drug_interactions.json',
      fromJson: InteractionDatabase.fromJson,
    ),
    'antidotes.json': _DbSpec(
      fileName: 'antidotes.json',
      assetPath: 'assets/data/advanced/antidotes.json',
      url: '$_advancedDir/antidotes.json',
      fromJson: AntidoteDatabase.fromJson,
    ),
    'emergency_protocols.json': _DbSpec(
      fileName: 'emergency_protocols.json',
      assetPath: 'assets/data/advanced/emergency_protocols.json',
      url: '$_advancedDir/emergency_protocols.json',
      fromJson: EmergencyDatabase.fromJson,
    ),
    'side_effects.json': _DbSpec(
      fileName: 'side_effects.json',
      assetPath: 'assets/data/advanced/side_effects.json',
      url: '$_advancedDir/side_effects.json',
      fromJson: SideEffectsDatabase.fromJson,
    ),
    'withdrawal_by_product.json': _DbSpec(
      fileName: 'withdrawal_by_product.json',
      assetPath: 'assets/data/advanced/withdrawal_by_product.json',
      url: '$_advancedDir/withdrawal_by_product.json',
      fromJson: WithdrawalDatabase.fromJson,
    ),
    'dose_adjustments.json': _DbSpec(
      fileName: 'dose_adjustments.json',
      assetPath: 'assets/data/advanced/dose_adjustments.json',
      url: '$_advancedDir/dose_adjustments.json',
      fromJson: DoseAdjustmentDatabase.fromJson,
    ),
    'fluid_therapy.json': _DbSpec(
      fileName: 'fluid_therapy.json',
      assetPath: 'assets/data/advanced/fluid_therapy.json',
      url: '$_advancedDir/fluid_therapy.json',
      fromJson: FluidTherapyDatabase.fromJson,
    ),
    // === Assets-only: в сети их нет, всегда из бандла ===
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
  };

  /// Ключи spec'ов по имени файла кеша (для чтения кеша).
  static Map<String, _DbSpec> get _specsByFileName =>
      {for (final e in _specs.entries) e.value.fileName: e.value};

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

  static Future<LoadResult> _loadOnce() async {
    // 1. Свежий дисковый кеш → мгновенный старт без сети.
    final cache = await _readDiskCache();
    final cacheHasCore = cache != null &&
        (cache.containsKey('assets/data/drugs_calc.json') ||
            cache.containsKey('assets/data/drugs_registry.json'));
    if (cache != null && cacheHasCore) {
      final fresh = await _isCacheFresh();
      if (fresh) {
        debugPrint('📦 [DrugLoader] Старт из дискового кеша: ${cache.length} файлов');
        final result = await _buildResult(cache, online: false, source: 'Кеш (офлайн-базы актуальны)');
        return result;
      }
      debugPrint('📦 [DrugLoader] Дисковый кеш старше 24 ч — обновляем из сети');
    }

    // 2. Сеть: параллельная загрузка, короткий таймаут.
    final netRaws = await _fetchNetworkRaws();
    if (netRaws.isNotEmpty) {
      debugPrint('🌐 [DrugLoader] Сетевые базы получены: ${netRaws.length} файлов');
      // assets-only базы добираем всегда (в сети их нет)
      final assetRaws = await _readAssetRaws(
        onlyKeys: _specs.values.where((s) => s.url == null).map((s) => s.assetPath).toSet(),
      );
      final allRaws = {...assetRaws, ...netRaws};
      unawaited(_writeDiskCache(netRaws)); // кеш сетевых — на следующий старт
      return await _buildResult(allRaws, online: true);
    }

    // 3. Нет сети и/или кеша → assets, кеш не трогаем (пусть лежит старый).
    debugPrint('📦 [DrugLoader] Офлайн — загрузка из assets');
    final assetRaws = await _readAssetRaws();
    return await _buildResult(assetRaws, online: false);
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

    final specs =
        _specs.values.where((s) => raws.containsKey(s.assetPath)).toList();
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

    // База без животных (сетевая или из кеша) — добираем из assets
    // (наследие фикса «Сетевая база без животных»).
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
  // Источники: сеть, assets, дисковый кеш
  // ============================================================

  /// Параллельная загрузка сетевых баз. Возвращает assetPath → raw.
  /// Считаем успехом, если получена хотя бы одна из трёх основных баз.
  static Future<Map<String, String>> _fetchNetworkRaws() async {
    final client = HttpClient();
    client.connectionTimeout = _networkTimeout;
    final raws = <String, String>{};
    try {
      final specs = _specs.values.where((s) => s.url != null).toList();
      final futures = specs.map((spec) async {
        try {
          final req = await client.getUrl(Uri.parse(spec.url!))
              .timeout(_networkTimeout);
          final res = await req.close().timeout(_networkTimeout);
          if (res.statusCode == 200) {
            final body = await res.transform(utf8.decoder).join();
            return MapEntry(spec, body);
          }
          debugPrint('⚠️ [DrugLoader] HTTP ${res.statusCode}: ${spec.fileName}');
        } catch (e) {
          debugPrint('⚠️ [DrugLoader] Сеть недоступна (${spec.fileName}): $e');
        }
        return null;
      });

      final results = await Future.wait(futures);
      for (final r in results) {
        if (r != null) raws[r.key.assetPath] = r.value;
      }

      // Нужна хотя бы одна из основных баз, иначе считаем сеть недоступной
      final coreOk = raws.containsKey('assets/data/drugs_registry.json') ||
          raws.containsKey('assets/data/drugs_calc.json') ||
          raws.containsKey('assets/data/drugs.json');
      if (!coreOk) {
        debugPrint('⚠️ [DrugLoader] Основные базы не получены — сеть считается недоступной');
        return {};
      }
    } catch (e) {
      debugPrint('⚠️ [DrugLoader] Ошибка сети: $e');
      return {};
    } finally {
      client.close(force: true);
    }
    return raws;
  }

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
  // Дисковый кеш (сетевые базы)
  // ============================================================

  static Directory? _cacheDir;

  static Future<Directory?> _getCacheDir() async {
    if (_cacheDir != null) return _cacheDir;
    try {
      final base = await getApplicationDocumentsDirectory();
      final dir = Directory('${base.path}/db_cache');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      _cacheDir = dir;
      return dir;
    } catch (e) {
      debugPrint('⚠️ [DrugLoader] Нет доступа к кеш-каталогу: $e');
      return null;
    }
  }

  static Future<Map<String, String>?> _readDiskCache() async {
    final dir = await _getCacheDir();
    if (dir == null) return null;
    final raws = <String, String>{};
    final byName = _specsByFileName;
    for (final entry in byName.entries) {
      final spec = entry.value;
      if (spec.url == null) continue; // assets-only в кеше не нуждаются
      try {
        final f = File('${dir.path}/${entry.key}');
        if (f.existsSync()) {
          raws[spec.assetPath] = await f.readAsString();
        }
      } catch (e) {
        debugPrint('⚠️ [DrugLoader] Кеш ${entry.key}: $e');
      }
    }
    return raws.isEmpty ? null : raws;
  }

  static Future<void> _writeDiskCache(Map<String, String> netRaws) async {
    final dir = await _getCacheDir();
    if (dir == null) return;
    final byAsset = {for (final e in _specs.entries) e.value.assetPath: e.value.fileName};
    for (final entry in netRaws.entries) {
      final fileName = byAsset[entry.key];
      if (fileName == null) continue;
      try {
        final f = File('${dir.path}/$fileName');
        await f.writeAsString(entry.value, flush: true);
      } catch (e) {
        debugPrint('⚠️ [DrugLoader] Запись кеша $fileName: $e');
      }
    }
    debugPrint('💾 [DrugLoader] Кеш обновлён: ${netRaws.length} файлов');
  }

  /// Свежесть кеша: самый новый файл младше [_cacheTtl].
  static Future<bool> _isCacheFresh() async {
    final dir = await _getCacheDir();
    if (dir == null) return false;
    try {
      DateTime? newest;
      for (final f in dir.listSync()) {
        if (f is File) {
          final m = f.statSync().modified;
          if (newest == null || m.isAfter(newest)) newest = m;
        }
      }
      if (newest == null) return false;
      return DateTime.now().difference(newest) < _cacheTtl;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // Утилиты
  // ============================================================

  /// jsonDecode с выносом тяжёлых файлов в background-isolate.
  static Future<Map<String, dynamic>> _decodeMap(String raw, {String hint = ''}) async {
    if (raw.length > _isolateDecodeThreshold) {
      return compute(_decodeJsonInIsolate, raw);
    }
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  /// Загружает список животных из локального assets (патч сетевой базы).
  static Future<List<Animal>> _loadLocalAnimals() async {
    try {
      final str = await rootBundle.loadString('assets/data/drugs_calc.json');
      final json = await _decodeMap(str, hint: 'animals');
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
      return await _decodeMap(str, hint: path.split('/').last);
    } catch (e) {
      debugPrint('Error loading $path: $e');
      return null;
    }
  }

  static Future<bool> isNetworkAvailable() async {
    try {
      final result = await InternetAddress.lookup('gitlab.com');
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
