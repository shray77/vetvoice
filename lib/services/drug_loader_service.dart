import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

/// Сервис надёжного локального хранения и обновления баз препаратов
class DrugLoaderService {
  static const String _githubBase =
      'https://raw.githubusercontent.com/shray77/vetvoice/main/assets/data';
  static const String _gitlabBase =
      'https://gitlab.com/shray77/vetvoice/-/raw/main/assets/data';

  static const String _cacheVersionKey = 'vetvoice_db_cache_version';
  static const String _lastUpdateCheckKey = 'vetvoice_last_update_check';

  /// Загрузка базы: Local-First принцип.
  /// 1. Сначала мгновенно загружается локальная база (из persistent cache или assets)
  /// 2. Приложение стартует без зависаний за доли секунды
  /// 3. Фоновая проверка обновлений запускается асинхронно без блокировки UI
  static Future<LoadResult> loadDatabase() async {
    // 1. Проверяем локальный персистентный кэш на диске
    final cachedResult = await _loadFromLocalCache();
    if (cachedResult != null &&
        cachedResult.calcDatabase != null &&
        cachedResult.calcDatabase!.drugs.isNotEmpty) {
      debugPrint('📦 База успешно загружена из локального дискового кэша (${cachedResult.totalDrugs} преп.)');
      // В фоне проверяем обновления без блокировки
      _checkForUpdatesInBackground();
      return cachedResult;
    }

    // 2. Если кэша ещё нет — загружаем из встроенных assets (100% гарантия наличия)
    debugPrint('📦 Загрузка базы из встроенных assets...');
    final assetResult = await _loadFromAssets();

    // В фоне проверяем обновления
    _checkForUpdatesInBackground();

    return assetResult;
  }

  /// Загрузка из локального кэша в ApplicationDocumentsDirectory
  static Future<LoadResult?> _loadFromLocalCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (!cacheDir.existsSync()) return null;

      final calcFile = File('${cacheDir.path}/drugs_calc.json');
      if (!calcFile.existsSync()) return null;

      final calcStr = await calcFile.readAsString();
      var calcDatabase = CalcDrugDatabase.fromJson(jsonDecode(calcStr) as Map<String, dynamic>);

      // Гарантия: если в кэше потерялись животные, подгружаем их из assets
      if (calcDatabase.animals.isEmpty) {
        final localAnimals = await _loadLocalAnimals();
        if (localAnimals.isNotEmpty) {
          calcDatabase = CalcDrugDatabase(
            version: calcDatabase.version,
            source: calcDatabase.source,
            lastUpdated: calcDatabase.lastUpdated,
            drugs: calcDatabase.drugs,
            animals: localAnimals,
          );
        }
      }

      DrugRegistry? registry;
      final regFile = File('${cacheDir.path}/drugs_registry.json');
      if (regFile.existsSync()) {
        final regStr = await regFile.readAsString();
        registry = DrugRegistry.fromJson(jsonDecode(regStr) as Map<String, dynamic>);
      }

      // Догружаем остальные справочники из assets/кэша
      final assetResult = await _loadFromAssets();

      return LoadResult(
        database: assetResult.database,
        registry: registry ?? assetResult.registry,
        calcDatabase: calcDatabase,
        dosageDatabase: assetResult.dosageDatabase,
        interactionDatabase: assetResult.interactionDatabase,
        antidoteDatabase: assetResult.antidoteDatabase,
        emergencyDatabase: assetResult.emergencyDatabase,
        sideEffectsDatabase: assetResult.sideEffectsDatabase,
        withdrawalDatabase: assetResult.withdrawalDatabase,
        doseAdjustmentDatabase: assetResult.doseAdjustmentDatabase,
        unofficialDatabase: assetResult.unofficialDatabase,
        fluidTherapyDatabase: assetResult.fluidTherapyDatabase,
        verifiedDosageDatabase: assetResult.verifiedDosageDatabase,
        fromNetwork: false,
        source: 'Локальная база (${calcDatabase.drugs.length} препаратов)',
      );
    } catch (e) {
      debugPrint('⚠️ Ошибка чтения дискового кэша: $e');
      return null;
    }
  }

  /// Загрузка из встроенных ресурсов APK/Assets
  static Future<LoadResult> _loadFromAssets() async {
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

    try {
      final str = await rootBundle.loadString('assets/data/drugs_calc.json');
      calcDatabase = CalcDrugDatabase.fromJson(jsonDecode(str) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error drugs_calc.json: $e');
    }

    try {
      final str = await rootBundle.loadString('assets/data/drugs_registry.json');
      registry = DrugRegistry.fromJson(jsonDecode(str) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error drugs_registry.json: $e');
    }

    try {
      final str = await rootBundle.loadString('assets/data/drugs.json');
      database = DrugDatabase.fromJson(jsonDecode(str) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error drugs.json: $e');
    }

    try {
      final str = await rootBundle.loadString('assets/data/dosage_database.json');
      dosageDatabase = DosageDatabase.fromJson(jsonDecode(str) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error dosage_database.json: $e');
    }

    try {
      final str = await rootBundle.loadString('assets/data/advanced/drug_interactions.json');
      interactionDatabase = InteractionDatabase.fromJson(jsonDecode(str) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error drug_interactions.json: $e');
    }

    try {
      final str = await rootBundle.loadString('assets/data/advanced/antidotes.json');
      antidoteDatabase = AntidoteDatabase.fromJson(jsonDecode(str) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error antidotes.json: $e');
    }

    try {
      final str = await rootBundle.loadString('assets/data/advanced/emergency_protocols.json');
      emergencyDatabase = EmergencyDatabase.fromJson(jsonDecode(str) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error emergency_protocols.json: $e');
    }

    try {
      final str = await rootBundle.loadString('assets/data/advanced/side_effects.json');
      sideEffectsDatabase = SideEffectsDatabase.fromJson(jsonDecode(str) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error side_effects.json: $e');
    }

    try {
      final str = await rootBundle.loadString('assets/data/advanced/withdrawal_by_product.json');
      withdrawalDatabase = WithdrawalDatabase.fromJson(jsonDecode(str) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error withdrawal_by_product.json: $e');
    }

    try {
      final str = await rootBundle.loadString('assets/data/advanced/dose_adjustments.json');
      doseAdjustmentDatabase = DoseAdjustmentDatabase.fromJson(jsonDecode(str) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error dose_adjustments.json: $e');
    }

    try {
      final str = await rootBundle.loadString('assets/data/unofficial_protocols.json');
      unofficialDatabase = UnofficialProtocolDatabase.fromJson(jsonDecode(str) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error unofficial_protocols.json: $e');
    }

    try {
      final str = await rootBundle.loadString('assets/data/advanced/fluid_therapy.json');
      fluidTherapyDatabase = FluidTherapyDatabase.fromJson(jsonDecode(str) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error fluid_therapy.json: $e');
    }

    try {
      final str = await rootBundle.loadString('assets/data/verified_dosages.json');
      verifiedDosageDatabase = VerifiedDosageDatabase.fromJson(jsonDecode(str) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error verified_dosages.json: $e');
    }

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
      fromNetwork: false,
      source: 'Офлайн (${calcDatabase?.drugs.length ?? registry?.totalDrugs ?? 0} препаратов)',
    );
  }

  /// Фоновая проверка обновлений (не блокирует UI)
  static Future<void> _checkForUpdatesInBackground() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getInt(_lastUpdateCheckKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Проверяем не чаще 1 раза в сутки
      if (now - lastCheck < 24 * 60 * 60 * 1000) {
        return;
      }

      final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      try {
        // Проверяем версию на GitHub
        final req = await client.getUrl(Uri.parse('$_githubBase/drugs_calc.json'));
        final res = await req.close();
        if (res.statusCode == 200) {
          final body = await res.transform(utf8.decoder).join();
          final json = jsonDecode(body) as Map<String, dynamic>;
          final remoteDrugs = json['drugs'] as List<dynamic>?;

          if (remoteDrugs != null && remoteDrugs.isNotEmpty) {
            // Сохраняем в кэш
            final cacheDir = await _getCacheDirectory();
            await cacheDir.create(recursive: true);
            final calcFile = File('${cacheDir.path}/drugs_calc.json');
            await calcFile.writeAsString(body, flush: true);
            debugPrint('✅ Фоновое обновление базы сохранено на диск');
          }
        }
        await prefs.setInt(_lastUpdateCheckKey, now);
      } finally {
        client.close(force: true);
      }
    } catch (e) {
      debugPrint('ℹ️ Фоновая проверка обновлений пропущена: $e');
    }
  }

  /// Получение директории кэша
  static Future<Directory> _getCacheDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();
    return Directory('${docDir.path}/vetvoice_data');
  }

  /// Загрузка списка животных из assets
  static Future<List<Animal>> _loadLocalAnimals() async {
    try {
      final str = await rootBundle.loadString('assets/data/drugs_calc.json');
      final json = jsonDecode(str) as Map<String, dynamic>;
      final animalsRaw = json['animals'] as List<dynamic>?;
      if (animalsRaw == null) return [];
      final animals = <Animal>[];
      for (final a in animalsRaw) {
        if (a is Map<String, dynamic>) {
          animals.add(Animal.fromJson(a));
        }
      }
      return animals;
    } catch (e) {
      debugPrint('⚠️ Ошибка загрузки животных: $e');
      return [];
    }
  }

  /// Загрузка JSON из assets
  static Future<Map<String, dynamic>?> loadJsonAsset(String path) async {
    try {
      final str = await rootBundle.loadString(path);
      return jsonDecode(str) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error loading $path: $e');
      return null;
    }
  }
}