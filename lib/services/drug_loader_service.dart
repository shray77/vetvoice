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

/// Сервис для загрузки баз препаратов
class DrugLoaderService {
  static const String _gitlabBase =
      'https://gitlab.com/shray77/vetvoice/-/raw/main/assets/data';
  static const String _advancedDir = '$_gitlabBase/advanced';

  static String get _gitlabRegistryUrl => '$_gitlabBase/drugs_registry.json';
  static String get _gitlabCalcUrl => '$_gitlabBase/drugs_calc.json';
  static String get _gitlabDrugsUrl => '$_gitlabBase/drugs.json';
  static String get _gitlabDosageUrl => '$_gitlabBase/dosage_database.json';
  static String get _gitlabInteractionsUrl => '$_advancedDir/drug_interactions.json';
  static String get _gitlabAntidotesUrl => '$_advancedDir/antidotes.json';
  static String get _gitlabEmergencyUrl => '$_advancedDir/emergency_protocols.json';
  static String get _gitlabSideEffectsUrl => '$_advancedDir/side_effects.json';
  static String get _gitlabTreatmentProtocolsUrl => '$_advancedDir/treatment_protocols.json';
  // Новые URL для ранее мёртвых файлов
  static String get _gitlabWithdrawalUrl => '$_advancedDir/withdrawal_by_product.json';
  static String get _gitlabDoseAdjUrl => '$_advancedDir/dose_adjustments.json';
  static String get _gitlabFluidUrl => '$_advancedDir/fluid_therapy.json';

  static const Duration _networkTimeout = Duration(seconds: 20);

  /// Загружает все базы
  static Future<LoadResult> loadDatabase() async {
    try {
      final networkResult = await _loadFromNetwork();
      if (networkResult != null) {
        if (networkResult.calcDatabase != null && 
            networkResult.calcDatabase!.animals.isEmpty) {
          debugPrint('⚠️ Сетевая база без животных! Подгружаем из assets...');
          try {
            final localAnimals = await _loadLocalAnimals();
            if (localAnimals.isNotEmpty) {
              final patchedCalc = CalcDrugDatabase(
                version: networkResult.calcDatabase!.version,
                source: networkResult.calcDatabase!.source,
                lastUpdated: networkResult.calcDatabase!.lastUpdated,
                drugs: networkResult.calcDatabase!.drugs,
                animals: localAnimals,
              );
              debugPrint('✅ Животные подгружены из assets: ${localAnimals.length} шт.');
              return LoadResult(
                database: networkResult.database,
                registry: networkResult.registry,
                calcDatabase: patchedCalc,
                dosageDatabase: networkResult.dosageDatabase,
                interactionDatabase: networkResult.interactionDatabase,
                antidoteDatabase: networkResult.antidoteDatabase,
                emergencyDatabase: networkResult.emergencyDatabase,
                sideEffectsDatabase: networkResult.sideEffectsDatabase,
                withdrawalDatabase: networkResult.withdrawalDatabase,
                doseAdjustmentDatabase: networkResult.doseAdjustmentDatabase,
                unofficialDatabase: networkResult.unofficialDatabase,
                fluidTherapyDatabase: networkResult.fluidTherapyDatabase,
                verifiedDosageDatabase: networkResult.verifiedDosageDatabase,
                fromNetwork: true,
                source: '${networkResult.source} + локальные животные',
              );
            }
          } catch (e) {
            debugPrint('⚠️ Ошибка загрузки животных из assets: $e');
          }
        }
        debugPrint('✅ Базы загружены из GitLab');
        return networkResult;
      }
    } catch (e) {
      debugPrint('⚠️ Ошибка сети: $e');
    }

    debugPrint('📦 Загрузка из assets (offline)');
    return await _loadFromAssets();
  }

  /// Загружает список животных из локального assets
  static Future<List<Animal>> _loadLocalAnimals() async {
    try {
      final str = await rootBundle.loadString('assets/data/drugs_calc.json');
      final json = jsonDecode(str) as Map<String, dynamic>;
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

  /// Загружает JSON-файл по HTTP
  static Future<T?> _fetchJson<T>(HttpClient client, String url, T Function(Map<String, dynamic>) fromJson) async {
    try {
      final req = await client.getUrl(Uri.parse(url));
      final res = await req.close();
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        return fromJson(jsonDecode(body) as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('⚠️ Ошибка загрузки $url: $e');
    }
    return null;
  }

  static Future<LoadResult?> _loadFromNetwork() async {
    final client = HttpClient();
    client.connectionTimeout = _networkTimeout;
    try {
      DrugRegistry? registry;
      CalcDrugDatabase? calcDatabase;
      DrugDatabase? database;
      DosageDatabase? dosageDatabase;
      InteractionDatabase? interactionDatabase;
      AntidoteDatabase? antidoteDatabase;
      EmergencyDatabase? emergencyDatabase;
      SideEffectsDatabase? sideEffectsDatabase;
      WithdrawalDatabase? withdrawalDatabase;
      DoseAdjustmentDatabase? doseAdjustmentDatabase;
      FluidTherapyDatabase? fluidTherapyDatabase;

      // Основные базы
      registry = await _fetchJson(client, _gitlabRegistryUrl, DrugRegistry.fromJson);
      if (registry != null) debugPrint('✅ Реестр: ${registry.totalDrugs} препаратов');

      calcDatabase = await _fetchJson(client, _gitlabCalcUrl, CalcDrugDatabase.fromJson);
      if (calcDatabase != null) debugPrint('✅ База расчётов: ${calcDatabase.drugs.length} препаратов');

      database = await _fetchJson(client, _gitlabDrugsUrl, DrugDatabase.fromJson);

      dosageDatabase = await _fetchJson(client, _gitlabDosageUrl, DosageDatabase.fromJson);
      if (dosageDatabase != null) debugPrint('✅ База дозировок: ${dosageDatabase.dosages.length} МНН');

      // Advanced базы
      interactionDatabase = await _fetchJson(client, _gitlabInteractionsUrl, InteractionDatabase.fromJson);
      if (interactionDatabase != null) debugPrint('✅ Взаимодействия: ${interactionDatabase.interactions.length} пар');

      antidoteDatabase = await _fetchJson(client, _gitlabAntidotesUrl, AntidoteDatabase.fromJson);
      if (antidoteDatabase != null) debugPrint('✅ Антидоты: ${antidoteDatabase.poisonings.length} токсинов');

      emergencyDatabase = await _fetchJson(client, _gitlabEmergencyUrl, EmergencyDatabase.fromJson);
      if (emergencyDatabase != null) debugPrint('✅ Emergency: ${emergencyDatabase.protocols.length} протоколов');

      sideEffectsDatabase = await _fetchJson(client, _gitlabSideEffectsUrl, SideEffectsDatabase.fromJson);
      if (sideEffectsDatabase != null) debugPrint('✅ Побочные эффекты: ${sideEffectsDatabase.drugs.length} препаратов');

      // === Ранее мёртвые файлы — теперь подключены ===
      withdrawalDatabase = await _fetchJson(client, _gitlabWithdrawalUrl, WithdrawalDatabase.fromJson);
      if (withdrawalDatabase != null) debugPrint('✅ Сроки ожидания: ${withdrawalDatabase.drugs.length} препаратов');

      doseAdjustmentDatabase = await _fetchJson(client, _gitlabDoseAdjUrl, DoseAdjustmentDatabase.fromJson);
      if (doseAdjustmentDatabase != null) debugPrint('✅ Корректировки доз загружены');

      fluidTherapyDatabase = await _fetchJson(client, _gitlabFluidUrl, FluidTherapyDatabase.fromJson);
      if (fluidTherapyDatabase != null) debugPrint('✅ Инфузионная терапия: ${fluidTherapyDatabase.solutions.length} растворов');

      if (registry != null || calcDatabase != null || database != null) {
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
          fluidTherapyDatabase: fluidTherapyDatabase,
          fromNetwork: true,
          source: 'Онлайн (${registry?.totalDrugs ?? 0} препаратов, ${interactionDatabase?.interactions.length ?? 0} взаимодействий)',
        );
      }
    } catch (e) {
      debugPrint('Network error: $e');
    } finally {
      client.close(force: true);
    }
    return null;
  }

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

    // === Ранее мёртвые файлы — теперь загружаются из assets ===
    try {
      final str = await rootBundle.loadString('assets/data/advanced/withdrawal_by_product.json');
      withdrawalDatabase = WithdrawalDatabase.fromJson(jsonDecode(str) as Map<String, dynamic>);
      debugPrint('✅ Сроки ожидания (assets): ${withdrawalDatabase!.drugs.length} препаратов');
    } catch (e) {
      debugPrint('Error withdrawal_by_product.json: $e');
    }

    try {
      final str = await rootBundle.loadString('assets/data/advanced/dose_adjustments.json');
      doseAdjustmentDatabase = DoseAdjustmentDatabase.fromJson(jsonDecode(str) as Map<String, dynamic>);
      debugPrint('✅ Корректировки доз (assets) загружены');
    } catch (e) {
      debugPrint('Error dose_adjustments.json: $e');
    }

    try {
      final str = await rootBundle.loadString('assets/data/unofficial_protocols.json');
      unofficialDatabase = UnofficialProtocolDatabase.fromJson(jsonDecode(str) as Map<String, dynamic>);
      debugPrint('✅ Неофициальные протоколы (assets): ${unofficialDatabase!.records.length} записей');
    } catch (e) {
      debugPrint('Error unofficial_protocols.json: $e');
    }

    try {
      final str = await rootBundle.loadString('assets/data/advanced/fluid_therapy.json');
      fluidTherapyDatabase = FluidTherapyDatabase.fromJson(jsonDecode(str) as Map<String, dynamic>);
      debugPrint('✅ Инфузионная терапия (assets): ${fluidTherapyDatabase!.solutions.length} растворов');
    } catch (e) {
      debugPrint('Error fluid_therapy.json: $e');
    }

    try {
      final str = await rootBundle.loadString('assets/data/verified_dosages.json');
      verifiedDosageDatabase = VerifiedDosageDatabase.fromJson(jsonDecode(str) as Map<String, dynamic>);
      debugPrint('✅ Верифицированные дозировки (assets): ${verifiedDosageDatabase!.dosages.length} препаратов');
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
      source: 'Офлайн (${registry?.totalDrugs ?? calcDatabase?.drugs.length ?? 0} препаратов)',
    );
  }

  static String get updateUrl => _gitlabCalcUrl;

  static Future<bool> isNetworkAvailable() async {
    try {
      final result = await InternetAddress.lookup('gitlab.com');
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Загружает JSON из assets
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