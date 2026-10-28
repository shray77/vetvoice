import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/drug.dart';
import '../models/drug_registry.dart';
import '../models/calc_drug.dart';
import '../models/dosage_database.dart';
import '../models/disease.dart';
import '../models/drug_interaction.dart';
import '../models/antidote.dart';
import '../models/emergency_protocol.dart';
import '../models/side_effects.dart';
import '../models/treatment_protocol.dart';
import '../models/withdrawal.dart';
import '../models/dose_adjustment.dart';
import '../models/unofficial_protocol.dart';
import '../models/fluid_therapy.dart';
import '../models/verified_dosage.dart';
import '../services/drug_loader_service.dart';
import '../services/theme_service.dart';
import '../utils/concentration_parser.dart';
import '../widgets/method_selector.dart';

/// Результат расчёта дозы
class DoseResult {
  final double volume;
  final String unit;
  final String drugName;
  final String drugForm;
  final String method;
  final String frequency;
  final String courseDays;
  final int withdrawalDays;
  final String error;
  final String warning;
  final List<String> contraindications;
  final List<String> sideEffects;
  final bool hasDosage;
  final bool hasResult;
  final CalcDrug? calcDrug;
  final RegistryDrug? registryDrug;
  final String note;
  final String selectedMethodName;
  
  // КРИТИЧЕСКИЕ предупреждения (ЗАПРЕЩЕНО!) - показывать очень заметно
  final List<String> riskWarnings;
  
  // === НОВОЕ: Взаимодействия ===
  final List<DrugInteraction> interactions;
  final String? antidoteInfo;
  
  // Для регулировки дозы
  final double dosePerKg;
  final double doseMin;
  final double doseMax;
  final String doseUnit;
  final double weight;
  final double concentration;

  // Детальный срок ожидания (мясо/молоко/яйца по видам)
  final String withdrawalText;

  // Фиксированная доза (вакцины, иммунобиологические)
  final bool isFixedDose;
  final String fixedDoseText;

  const DoseResult({
    this.volume = 0,
    this.unit = 'мл',
    this.drugName = '',
    this.drugForm = '',
    this.method = '',
    this.frequency = '',
    this.courseDays = '',
    this.withdrawalDays = 0,
    this.error = '',
    this.warning = '',
    this.contraindications = const [],
    this.sideEffects = const [],
    this.hasDosage = false,
    this.hasResult = false,
    this.calcDrug,
    this.registryDrug,
    this.note = '',
    this.selectedMethodName = '',
    this.riskWarnings = const [],
    this.interactions = const [],
    this.antidoteInfo,
    this.dosePerKg = 0,
    this.doseMin = 0,
    this.doseMax = 0,
    this.doseUnit = 'мг/кг',
    this.weight = 0,
    this.concentration = 0,
    this.withdrawalText = '',
    this.isFixedDose = false,
    this.fixedDoseText = '',
  });

  bool get hasWithdrawalText => withdrawalText.isNotEmpty;

  bool get hasError => error.isNotEmpty;
  bool get hasContraindications => contraindications.isNotEmpty;
  bool get hasSideEffects => sideEffects.isNotEmpty;
  bool get hasRiskWarnings => riskWarnings.isNotEmpty;
  bool get hasDoseRange => doseMin > 0 && doseMax > 0 && doseMin < doseMax;
  bool get hasInteractions => interactions.isNotEmpty;

  String get formattedVolume {
    if (volume >= 100) return '${volume.toStringAsFixed(0)} $unit';
    if (volume >= 10) return '${volume.toStringAsFixed(1)} $unit';
    if (volume >= 1) return '${volume.toStringAsFixed(2)} $unit';
    return '${volume.toStringAsFixed(3)} $unit';
  }

  DoseResult copyWith({
    double? volume,
    String? unit,
    String? drugName,
    String? drugForm,
    String? method,
    String? frequency,
    String? courseDays,
    int? withdrawalDays,
    String? error,
    String? warning,
    List<String>? contraindications,
    List<String>? sideEffects,
    bool? hasDosage,
    bool? hasResult,
    CalcDrug? calcDrug,
    RegistryDrug? registryDrug,
    String? note,
    String? selectedMethodName,
    List<String>? riskWarnings,
    List<DrugInteraction>? interactions,
    String? antidoteInfo,
    double? dosePerKg,
    double? doseMin,
    double? doseMax,
    String? doseUnit,
    double? weight,
    double? concentration,
    bool? isFixedDose,
    String? fixedDoseText,
    String? withdrawalText,
  }) {
    return DoseResult(
      volume: volume ?? this.volume,
      unit: unit ?? this.unit,
      drugName: drugName ?? this.drugName,
      drugForm: drugForm ?? this.drugForm,
      method: method ?? this.method,
      frequency: frequency ?? this.frequency,
      courseDays: courseDays ?? this.courseDays,
      withdrawalDays: withdrawalDays ?? this.withdrawalDays,
      error: error ?? this.error,
      warning: warning ?? this.warning,
      contraindications: contraindications ?? this.contraindications,
      sideEffects: sideEffects ?? this.sideEffects,
      hasDosage: hasDosage ?? this.hasDosage,
      hasResult: hasResult ?? this.hasResult,
      calcDrug: calcDrug ?? this.calcDrug,
      registryDrug: registryDrug ?? this.registryDrug,
      note: note ?? this.note,
      selectedMethodName: selectedMethodName ?? this.selectedMethodName,
      riskWarnings: riskWarnings ?? this.riskWarnings,
      interactions: interactions ?? this.interactions,
      antidoteInfo: antidoteInfo ?? this.antidoteInfo,
      dosePerKg: dosePerKg ?? this.dosePerKg,
      doseMin: doseMin ?? this.doseMin,
      doseMax: doseMax ?? this.doseMax,
      doseUnit: doseUnit ?? this.doseUnit,
      weight: weight ?? this.weight,
      concentration: concentration ?? this.concentration,
      isFixedDose: isFixedDose ?? this.isFixedDose,
      fixedDoseText: fixedDoseText ?? this.fixedDoseText,
      withdrawalText: withdrawalText ?? this.withdrawalText,
    );
  }
}

/// State-хранилище приложения.
///
/// ⚠ Q-2: Ранее в pubspec.yaml была подключена зависимость `provider: ^6.1.2`,
/// но ни `VetProvider extends ChangeNotifier`, ни `ChangeNotifierProvider` в
/// `main.dart` не использовались — состояние пробрасывалось через прямые
/// `setState` вызовы в `HomeScreen`. Зависимость была удалена как мёртвый код.
///
/// Если в будущем понадобится реактивное обновление с нескольких экранов —
/// миграция тривиальна:
///   1. `class VetProvider extends ChangeNotifier`
///   2. `notifyListeners()` в конце каждого сеттера (selectAnimal, setWeight, ...)
///   3. В `main.dart`: `ChangeNotifierProvider(create: (_) => VetProvider(), child: ...)`
///   4. В виджетах: `context.watch<VetProvider>()` / `context.read<VetProvider>()`
class VetProvider {
  // v1.16.1: синглтон. Раньше home_screen и favorites_screen создавали
  // РАЗНЫЕ инстансы — избранное перечитывало все базы с нуля (долгая
  // загрузка) и состояние не совпадало между экранами.
  VetProvider._internal();
  static final VetProvider _instance = VetProvider._internal();
  factory VetProvider() => _instance;

  bool _initialized = false;

  CalcDrugDatabase? _calcDatabase;
  DrugRegistry? _registry;
  DosageDatabase? _dosageDatabase;
  // Новые подключённые базы
  WithdrawalDatabase? _withdrawalDatabase;
  DoseAdjustmentDatabase? _doseAdjustmentDatabase;
  UnofficialProtocolDatabase? _unofficialDatabase;
  FluidTherapyDatabase? _fluidTherapyDatabase;
  VerifiedDosageDatabase? _verifiedDosageDatabase;
  DiseaseDatabase? _diseaseDatabase;
  
  // === НОВОЕ ===
  InteractionDatabase? _interactionDatabase;
  AntidoteDatabase? _antidoteDatabase;
  EmergencyDatabase? _emergencyDatabase;
  SideEffectsDatabase? _sideEffectsDatabase;
  TreatmentProtocolDatabase? _treatmentProtocolDatabase;
  
  String? _selectedAnimalId;
  CalcDrug? _selectedCalcDrug;
  RegistryDrug? _selectedRegistryDrug;
  double _weight = 0;
  DoseResult _result = const DoseResult();
  AdministrationMethod? _selectedMethod;
  
  bool _isLoading = true;
  String _statusMessage = 'Загрузка...';
  bool _isOnline = false;

  Gender _gender = Gender.male;
  PregnancyPeriod _pregnancyPeriod = PregnancyPeriod.notPregnant;
  int _ageMonths = 12;
  String _searchQuery = '';
  WeightValidationResult? _weightValidation;
  
  // === НОВОЕ: История выбранных препаратов для проверки взаимодействий ===
  final List<String> _selectedDrugHistory = [];

  // Геттеры
  bool get isLoading => _isLoading;
  String get statusMessage => _statusMessage;
  bool get isOnline => _isOnline;
  DoseResult get result => _result;
  WeightValidationResult? get weightValidation => _weightValidation;
  String? get selectedAnimalId => _selectedAnimalId;
  CalcDrug? get selectedDrug => _selectedCalcDrug;
  RegistryDrug? get selectedRegistryDrug => _selectedRegistryDrug;
  AdministrationMethod? get selectedMethod => _selectedMethod;
  
  Gender get gender => _gender;
  PregnancyPeriod get pregnancyPeriod => _pregnancyPeriod;
  int get ageMonths => _ageMonths;
  double get weight => _weight;
  String get searchQuery => _searchQuery;
  
  // === НОВОЕ: Геттеры для новых баз ===
  InteractionDatabase? get interactionDatabase => _interactionDatabase;
  AntidoteDatabase? get antidoteDatabase => _antidoteDatabase;
  EmergencyDatabase? get emergencyDatabase => _emergencyDatabase;
  SideEffectsDatabase? get sideEffectsDatabase => _sideEffectsDatabase;
  TreatmentProtocolDatabase? get treatmentProtocolDatabase => _treatmentProtocolDatabase;
  List<String> get selectedDrugHistory => _selectedDrugHistory;

  /// Публичный доступ к базе расчётных препаратов (для favorites и др.).
  /// Загружается в initialize(); до него — null.
  CalcDrugDatabase? get calcDatabase => _calcDatabase;
  
  int get totalDrugs => _registry?.totalDrugs ?? _calcDatabase?.drugs.length ?? 0;
  int get calcDrugsCount => _calcDatabase?.drugs.length ?? 0;
  int get dosageCount => _dosageDatabase?.dosages.length ?? 0;
  int get withdrawalCount => _withdrawalDatabase?.drugs.length ?? 0;
  int get unofficialCount => _unofficialDatabase?.records.length ?? 0;
  int get fluidSolutionsCount => _fluidTherapyDatabase?.solutions.length ?? 0;
  int get verifiedCount => _verifiedDosageDatabase?.dosages.length ?? 0;
  int get diseasesCount => _diseaseDatabase?.diseases.length ?? 0;
  int get interactionsCount => _interactionDatabase?.interactions.length ?? 0;
  int get antidotesCount => _antidoteDatabase?.poisonings.length ?? 0;
  int get emergencyCount => _emergencyDatabase?.protocols.length ?? 0;
  int get treatmentProtocolsCount => _treatmentProtocolDatabase?.protocols.length ?? 0;
  
  DiseaseDatabase? get diseaseDatabase => _diseaseDatabase;
  WithdrawalDatabase? get withdrawalDatabase => _withdrawalDatabase;
  DoseAdjustmentDatabase? get doseAdjustmentDatabase => _doseAdjustmentDatabase;
  UnofficialProtocolDatabase? get unofficialDatabase => _unofficialDatabase;
  FluidTherapyDatabase? get fluidTherapyDatabase => _fluidTherapyDatabase;
  VerifiedDosageDatabase? get verifiedDosageDatabase => _verifiedDosageDatabase;

  Animal? get selectedAnimal {
    if (_calcDatabase == null || _selectedAnimalId == null) return null;
    // ⚠ Фикс B-12: ранее orElse возвращал _calcDatabase!.animals.first
    // (тихо возвращало КРС при несоответствии id), что приводило к расчёту дозы
    // для неправильного животного. Теперь возвращаем null — UI покажет «выберите животное».
    try {
      return _calcDatabase!.animals.firstWhere(
        (a) => a.id == _selectedAnimalId,
      );
    } catch (_) {
      return null;
    }
  }

  List<Animal> get animals => _calcDatabase?.animals ?? [];

  /// Все препараты (для поиска)
  List<dynamic> get allDrugs {
    final List<dynamic> all = [];
    
    if (_calcDatabase != null) {
      // Фильтруем - скрываем шампуни, ошейники и т.д.
      all.addAll(_calcDatabase!.drugs.where((d) => d.calculatorApplicable));
    }
    
    if (_registry != null) {
      final calcNames = _calcDatabase?.drugs.map((d) => d.name.toLowerCase()).toSet() ?? {};
      for (final d in _registry!.drugs) {
        if (!calcNames.contains(d.tradeName.toLowerCase())) {
          all.add(d);
        }
      }
    }
    
    if (_searchQuery.isNotEmpty) {
      final q = normalizeForSearch(_searchQuery);
      final loose = _looseKey(_searchQuery);
      return all.where((d) {
        if (d is CalcDrug) {
          return _matchesSearchQuery(name: d.name, inn: d.inn, query: q, looseQuery: loose);
        }
        if (d is RegistryDrug) {
          return _matchesSearchQuery(name: d.tradeName, inn: d.inn, query: q, looseQuery: loose);
        }
        return false;
      }).toList();
    }

    return all;
  }

  /// v1.16.4: нормализация для поиска. Полевой репорт #4: «нет АСД-10 для
  /// протокола чумы КРС» — препарат в базе ЕСТЬ («АСД®-10», id 128), но
  /// пользователь вводит «асд-10» без ®, а подстрока «асд-10» в «асд®-10»
  /// разорвана символом ® → contains = false → «не найден». Кроме того ё/е
  /// должны быть эквивалентны («Пчелы» ↔ «Пчёлы»).
  static String normalizeForSearch(String s) {
    return s
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'[®™©]'), '')
        .trim();
  }

  /// «Мягкий» ключ: только буквы/цифры — для второго прохода, когда запрос
  /// набран с другими разделителями («асд 10» / «асд10» ↔ «асд-10»). 
  static String _looseKey(String s) {
    return normalizeForSearch(s).replaceAll(RegExp(r'[^a-zа-я0-9]'), '');
  }

  /// Матч препарата под поисковый запрос: точная нормализованная подстрока,
  /// затем — loose-проход (запрос от 3 символов, иначе шум).
  static bool _matchesSearchQuery({
    required String name,
    required String inn,
    required String query,
    required String looseQuery,
  }) {
    final n = normalizeForSearch(name);
    final i = normalizeForSearch(inn);
    if (n.contains(query) || i.contains(query)) return true;
    if (looseQuery.length >= 3) {
      if (_looseKey(name).contains(looseQuery) ||
          _looseKey(inn).contains(looseQuery)) {
        return true;
      }
    }
    return false;
  }

  /// 🆕 Sprint 2: Найти CalcDrug по названию (для протоколов лечения)
  CalcDrug? findCalcDrugByName(String name) {
    if (_calcDatabase == null) return null;
    final q = normalizeForSearch(name);
    if (q.isEmpty) return null;
    final loose = _looseKey(name);
    try {
      return _calcDatabase!.drugs.firstWhere(
        (d) => _matchesSearchQuery(
          name: d.name,
          inn: d.inn,
          query: q,
          looseQuery: loose,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Препараты для выбранного животного
  List<dynamic> get availableDrugs {
    final animal = selectedAnimal;
    if (animal == null) return allDrugs;

    final List<dynamic> filtered = [];
    final animalName = animal.name;
    
    if (_calcDatabase != null) {
      // Фильтруем - скрываем шампуни, ошейники и т.д.
      final calcDrugs = _calcDatabase!.getDrugsForAnimal(animalName)
          .where((d) => d.calculatorApplicable)
          .toList();
      debugPrint('📊 CalcDrugs для $animalName: ${calcDrugs.length} шт');
      filtered.addAll(calcDrugs);
    } else {
      debugPrint('⚠ _calcDatabase is null!');
    }
    
    if (_registry != null) {
      final calcNames = filtered
          .whereType<CalcDrug>()
          .map((d) => d.name.toLowerCase())
          .toSet();
      
      var regDrugs = _registry!.getDrugsForAnimal(animalName);
      if (regDrugs.isEmpty) {
        regDrugs = _registry!.drugs.where((d) => d.animals.isEmpty).toList();
      }
      
      for (final d in regDrugs) {
        if (calcNames.contains(d.tradeName.toLowerCase())) continue;
        
        if (_dosageDatabase != null && _hasDosageInDatabase(d, animalName)) {
          filtered.add(d);
        }
      }
    }
    
    debugPrint('📊 Всего препаратов для $animalName: ${filtered.length}');

    if (_searchQuery.isNotEmpty) {
      final q = normalizeForSearch(_searchQuery);
      final loose = _looseKey(_searchQuery);
      return filtered.where((d) {
        if (d is CalcDrug) {
          return _matchesSearchQuery(name: d.name, inn: d.inn, query: q, looseQuery: loose);
        }
        if (d is RegistryDrug) {
          return _matchesSearchQuery(name: d.tradeName, inn: d.inn, query: q, looseQuery: loose);
        }
        return false;
      }).toList();
    }

    return filtered;
  }

  bool _hasDosageInDatabase(RegistryDrug drug, String animalName) {
    if (_dosageDatabase == null) return false;
    
    final innList = drug.inn
        .split(RegExp('[,;]'))
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toList();

    if (innList.isEmpty) return false;

    final substanceDosage = _dosageDatabase!.findByInnList(innList);
    if (substanceDosage == null) return false;

    final animalDosage = substanceDosage.getForAnimal(animalName);
    return animalDosage != null && animalDosage.hasDosage;
  }

  /// Инициализация (v1.16.3: двухстадийная).
  ///
  /// СТАДИЯ 1 — ядро (препараты калькулятора, реестр, дозировки, совместимость):
  /// home становится интерактивным примерно вдвое быстрее, «секунд 5 загрузка
  /// баз» больше не блокирует выбор животного/препарата.
  /// СТАДИЯ 2 — вторичные базы (антидоты, инфузии, каренция, неофициальные
  /// протоколы...) парсятся фоном; [extendedReady] резолвится, когда всё
  /// готово — home по нему дорисовывает навигационные кнопки.
  /// Повторные вызовы — мгновенный no-op.
  final Completer<void> _extendedCompleter = Completer<void>();

  /// Готовность вторичных баз (СТАДИЯ 2). Никогда не бросает исключение.
  Future<void> get extendedReady => _extendedCompleter.future;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true; // гард ДО await — параллельные вызовы не задвоят загрузку
    try {
      _isLoading = true;
      _statusMessage = 'Загрузка баз препаратов...';

      // === СТАДИЯ 1: ядро для расчёта доз ===
      final loadResult = await DrugLoaderService.loadCore();
      _calcDatabase = loadResult.calcDatabase;
      _registry = loadResult.registry;
      _dosageDatabase = loadResult.dosageDatabase;
      _interactionDatabase = loadResult.interactionDatabase;
      _isOnline = loadResult.fromNetwork;
      _statusMessage = loadResult.source;

      // v1.16.4: «Версия базы» в настройках вечно показывала «Загрузка...» —
      // ThemeService.setDatabaseInfo не вызывался НИГДЕ (мёртвый фиче-код).
      // Заполняем сразу после ядра: version/last_updated лежат в самом JSON.
      final db = _calcDatabase;
      if (db != null) {
        final buf = StringBuffer('v${db.version} · ${db.drugs.length} препаратов');
        if (db.lastUpdated.isNotEmpty) buf.write(' · обновлено ${db.lastUpdated}');
        buf.write(loadResult.fromNetwork ? ' · сеть' : ' · кеш');
        unawaited(ThemeService().setDatabaseInfo(buf.toString()));
      }

      // DEBUG: Проверяем загрузку животных
      if (_calcDatabase != null) {
        debugPrint('✅ CalcDatabase loaded: ${_calcDatabase!.drugs.length} drugs');
        debugPrint('✅ Animals loaded: ${_calcDatabase!.animals.length}');
        for (final a in _calcDatabase!.animals) {
          debugPrint('  🐾 ${a.name} (${a.id}): ${a.minWeight}-${a.maxWeight} kg');
        }
      } else {
        debugPrint('❌ CalcDatabase is NULL!');
      }

      _isLoading = false;
      // ядро готово — home интерактивен
    } catch (e) {
      _isLoading = false;
      _statusMessage = 'Ошибка: $e';
      _extendedCompleter.complete(); // не оставляем вечный Future
      return;
    }

    // === СТАДИЯ 2: фоном, не блокирует home ===
    unawaited(_loadExtendedDatabases());
  }

  /// v1.16.3: вторичные базы + болезни + протоколы лечения — строго после
  /// первого кадра. Ошибки гасим: эти базы факультативны для расчёта доз,
  /// экраны уже имеют null-guard'ы.
  Future<void> _loadExtendedDatabases() async {
    try {
      final ext = await DrugLoaderService.parseExtended();
      if (ext != null) {
        _antidoteDatabase = ext.antidoteDatabase;
        _emergencyDatabase = ext.emergencyDatabase;
        _sideEffectsDatabase = ext.sideEffectsDatabase;
        _withdrawalDatabase = ext.withdrawalDatabase;
        _doseAdjustmentDatabase = ext.doseAdjustmentDatabase;
        _unofficialDatabase = ext.unofficialDatabase;
        _fluidTherapyDatabase = ext.fluidTherapyDatabase;
        _verifiedDosageDatabase = ext.verifiedDosageDatabase;
        debugPrint('✅ Extended databases loaded (стадия 2)');
      }

      // Болезни (v1.16.2: parse в background-isolate)
      try {
        final diseaseRaw =
            await DrugLoaderService.getRawJson('assets/data/diseases.json');
        if (diseaseRaw != null) {
          _diseaseDatabase = await DrugLoaderService.parseInIsolate(
              diseaseRaw, DiseaseDatabase.fromJson);
          if (_diseaseDatabase != null) {
            debugPrint('✅ Loaded ${_diseaseDatabase!.diseases.length} diseases');
          }
        }
      } catch (e) {
        debugPrint('⚠ Diseases not loaded: $e');
      }

      // Протоколы лечения (v1.16.2: тоже в изоляте)
      try {
        final treatmentRaw = await DrugLoaderService.getRawJson(
            'assets/data/advanced/treatment_protocols.json');
        if (treatmentRaw != null) {
          _treatmentProtocolDatabase = await DrugLoaderService.parseInIsolate(
              treatmentRaw, TreatmentProtocolDatabase.fromJson);
          if (_treatmentProtocolDatabase != null) {
            debugPrint(
                '✅ Loaded ${_treatmentProtocolDatabase!.protocols.length} treatment protocols');
          }
        }
      } catch (e) {
        debugPrint('⚠ Treatment protocols not loaded: $e');
      }
    } finally {
      if (!_extendedCompleter.isCompleted) _extendedCompleter.complete();
    }
  }

  void setSearchQuery(String q) => _searchQuery = q;

  void selectAnimal(String id) {
    _selectedAnimalId = id;
    _selectedCalcDrug = null;
    _selectedRegistryDrug = null;
    _result = const DoseResult();
    _selectedDrugHistory.clear();
    if (_weight > 0) _validateWeight(_weight);
  }

  /// v1.16.4: подбор животного калькулятора по видам из протокола лечения.
  /// Полевой репорт #4: «автоматом не подставляет животное хотя бы из
  /// протоколов, только препарат». Виды в протоколах не совпадают 1-в-1 с
  /// названиями животных базы: «Пчелы»/«Пчёлы» (е/ё), «Пушные» vs
  /// «Пушные звери», опечатки регистра («КРс»), служебное «Все». Матчим
  /// первый вид, который узнаётся одним из животных (нормализация ё→е,
  /// префиксы в обе стороны). Возвращает id выбранного животного или null.
  /// ⚠ НЕ сбрасывает препарат (в отличие от selectAnimal) — вызывать ДО
  /// selectDrug, чтобы из протокола прилетали ОБА: и вид, и препарат.
  String? selectAnimalFromSpecies(List<String> species) {
    if (_calcDatabase == null || species.isEmpty) return null;
    String norm(String s) =>
        s.toLowerCase().replaceAll('ё', 'е').trim();
    for (final s in species) {
      final target = norm(s);
      if (target.isEmpty || target == 'все') continue;
      for (final a in _calcDatabase!.animals) {
        final name = norm(a.name);
        if (name.isEmpty) continue;
        if (name == target || name.startsWith(target) || target.startsWith(name)) {
          _selectedAnimalId = a.id;
          if (_weight > 0) _validateWeight(_weight);
          return a.id;
        }
      }
    }
    return null;
  }

  void selectDrug(dynamic drug) {
    if (drug is CalcDrug) {
      _selectedCalcDrug = drug;
      _selectedRegistryDrug = null;
      
      // Добавляем в историю, но убираем предыдущее вхождение этого же препарата
      // чтобы не было ложного взаимодействия "препарат с самим собой"
      _selectedDrugHistory.remove(drug.name);
      _selectedDrugHistory.add(drug.name);
      _recalculate();
    } else if (drug is RegistryDrug) {
      selectRegistryDrug(drug);
    }
    _searchQuery = '';
  }

  void selectRegistryDrug(RegistryDrug drug) {
    _selectedRegistryDrug = drug;
    _selectedCalcDrug = null;
    
    // Добавляем в историю, убираем дубликаты этого же препарата
    _selectedDrugHistory.remove(drug.tradeName);
    _selectedDrugHistory.add(drug.tradeName);
    
    final doseResult = _calculateFromRegistry(drug);
    _result = doseResult;
  }

  /// === НОВОЕ: Проверяет взаимодействия для выбранных препаратов ===
  List<DrugInteraction> checkInteractions() {
    if (_interactionDatabase == null || _selectedDrugHistory.length < 2) {
      return [];
    }
    return _interactionDatabase!.checkAllInteractions(_selectedDrugHistory);
  }

  /// === НОВОЕ: Ищет антидот ===
  Antidote? findAntidote(String toxin) {
    return _antidoteDatabase?.findByToxin(toxin);
  }

  /// === НОВОЕ: Ищет emergency протокол ===
  List<EmergencyProtocol> searchEmergency(String query) {
    return _emergencyDatabase?.search(query) ?? [];
  }

  /// === НОВОЕ: Получает побочные эффекты ===
  DrugSideEffects? getSideEffects(String drugName) {
    return _sideEffectsDatabase?.findByDrug(drugName);
  }

  /// Очищает историю препаратов
  void clearDrugHistory() {
    _selectedDrugHistory.clear();
    _result = _result.copyWith(interactions: []);
  }

  DoseResult _calculateFromRegistry(RegistryDrug drug) {
    final animal = selectedAnimal;
    final animalName = animal?.name ?? '';

    var result = DoseResult(
      drugName: drug.tradeName,
      drugForm: drug.form,
      method: 'См. инструкцию',
      hasDosage: false,
      hasResult: true,
      registryDrug: drug,
      note: drug.indications,
      contraindications: drug.contraindications.isNotEmpty ? [drug.contraindications] : [],
    );

    if (_dosageDatabase == null) {
      return result;
    }

    final innList = drug.inn
        .split(RegExp('[,;]'))
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toList();

    if (innList.isEmpty) {
      return result;
    }

    final substanceDosage = _dosageDatabase!.findByInnList(innList);
    if (substanceDosage == null) {
      return result.copyWith(
        note: '${drug.indications}\n\nДозировка не найдена в базе. Проверьте инструкцию.',
      );
    }

    final animalDosage = substanceDosage.getForAnimal(animalName);
    if (animalDosage == null || !animalDosage.hasDosage) {
      final available = substanceDosage.availableAnimals;
      return result.copyWith(
        note: '${drug.indications}\n\n⚠ Дозировка доступна для: ${available.join(', ')}',
      );
    }

    double concentration = 0;
    String concentrationUnit = 'мг/мл';

    if (drug.composition.isNotEmpty) {
      concentration = ConcentrationParser.parseConcentrationForSubstance(
        drug.composition, innList.first);
      concentrationUnit = ConcentrationParser.getConcentrationUnit(drug.composition);

      if (concentration == 0) {
        final parsed = ConcentrationParser.parseFromComposition(drug.composition);
        if (parsed.isNotEmpty) {
          concentration = parsed.values.first;
        }
      }
    }

    if (concentration == 0 && drug.dosage.isNotEmpty) {
      concentration = ConcentrationParser.parseFromDosageField(drug.dosage);
    }

    if (_weight > 0 && (concentration > 0 || animalDosage.doseMlKg > 0)) {
      double volumeMl = 0;
      String note = '';

      if (animalDosage.doseMlKg > 0) {
        volumeMl = animalDosage.doseMlKg * _weight;
        note = '${animalDosage.doseMlKg} мл/кг';
      } else if (concentration > 0) {
        final doseMg = animalDosage.doseValue * _weight;
        volumeMl = doseMg / concentration;
        note = '${animalDosage.formattedDose} × ${_weight.toStringAsFixed(1)} кг ÷ $concentration $concentrationUnit';
      }

      final warnings = <String>[];
      if (drug.contraindications.isNotEmpty) {
        warnings.add(drug.contraindications);
      }
      if (animalDosage.notes.isNotEmpty) {
        warnings.add('ℹ️ ${animalDosage.notes}');
      }

      // === НОВОЕ: Проверяем взаимодействия ===
      final interactions = checkInteractions();
      
      return DoseResult(
        volume: volumeMl,
        unit: 'мл',
        drugName: drug.tradeName,
        drugForm: drug.form,
        method: animalDosage.route,
        frequency: animalDosage.frequency,
        hasDosage: true,
        hasResult: true,
        registryDrug: drug,
        note: note,
        contraindications: warnings,
        warning: animalDosage.notes,
        interactions: interactions,
      );
    }

    return DoseResult(
      drugName: drug.tradeName,
      drugForm: drug.form,
      method: animalDosage.route,
      frequency: animalDosage.frequency,
      hasDosage: true,
      hasResult: true,
      registryDrug: drug,
      note: 'Дозировка: ${animalDosage.formattedDose}\n${animalDosage.notes}\n\n${drug.indications}',
      contraindications: drug.contraindications.isNotEmpty ? [drug.contraindications] : [],
    );
  }

  void setWeight(double w) {
    _weight = w;
    _validateWeight(w);
    if (_selectedCalcDrug != null) {
      _recalculate();
    } else if (_selectedRegistryDrug != null) {
      _result = _calculateFromRegistry(_selectedRegistryDrug!);
    }
  }

  void setGender(Gender g) {
    _gender = g;
    if (g == Gender.male) _pregnancyPeriod = PregnancyPeriod.notPregnant;
    if (_selectedCalcDrug != null) {
      _recalculate();
    } else if (_selectedRegistryDrug != null) {
      _result = _calculateFromRegistry(_selectedRegistryDrug!);
    }
  }

  void setPregnancyPeriod(PregnancyPeriod p) {
    _pregnancyPeriod = p;
    if (_selectedCalcDrug != null) {
      _recalculate();
    } else if (_selectedRegistryDrug != null) {
      _result = _calculateFromRegistry(_selectedRegistryDrug!);
    }
  }

  void setAgeMonths(int m) {
    _ageMonths = m;
    if (_selectedCalcDrug != null) {
      _recalculate();
    } else if (_selectedRegistryDrug != null) {
      _result = _calculateFromRegistry(_selectedRegistryDrug!);
    }
  }
  
  void setMethod(AdministrationMethod? method) {
    _selectedMethod = method;
    if (_selectedCalcDrug != null) {
      _recalculate();
    } else if (_selectedRegistryDrug != null) {
      _result = _calculateFromRegistry(_selectedRegistryDrug!);
    }
  }
  
  void setCustomDose(double customDosePerKg) {
    final drug = _selectedCalcDrug;
    if (drug == null || _weight <= 0) return;

    double volumeMl = 0;
    // ⚠ Фикс S-2 (Task 183): ручная корректировка дозы обязана повторять
    // ветвление CalcDrug.calculateDose — объёмная доза (мл/кг) НЕ делится
    // на концентрацию (раньше слайдер пересчитывал мл/кг-препараты в
    // мусор: Рингер-Локк/Гамавит — те же ×9/×50, что и в основном расчёте).
    if (drug.doseUnit.contains('мл/кг')) {
      volumeMl = customDosePerKg * _weight;
    } else if (drug.doseUnit.contains('мл/животное')) {
      volumeMl = customDosePerKg; // фикс на животное — вес не умножается
    } else if (drug.concentration > 0) {
      volumeMl = (customDosePerKg * _weight) / drug.concentration;
    }

    _result = _result.copyWith(
      volume: volumeMl,
      dosePerKg: customDosePerKg,
    );
  }

  void _validateWeight(double w) {
    final animal = selectedAnimal;
    if (animal != null && w > 0) {
      _weightValidation = animal.validateWeight(w);
    } else {
      _weightValidation = null;
    }
  }

  AgeCategory get ageCategory {
    final animal = selectedAnimal;
    if (animal != null) return animal.getAgeCategory(_ageMonths);
    return AgeCategory.adult;
  }

  void _recalculate() {
    final drug = _selectedCalcDrug;
    final animal = selectedAnimal;
    
    if (drug == null) return;

    if (_weight <= 0) {
      _result = DoseResult(
        drugName: drug.name,
        drugForm: drug.form,
        error: 'Укажите вес животного',
        calcDrug: drug,
      );
      return;
    }

    if (_weightValidation?.hasError == true) {
      _result = DoseResult(
        drugName: drug.name,
        drugForm: drug.form,
        error: _weightValidation!.error,
        calcDrug: drug,
      );
      return;
    }

    final doseCalc = drug.calculateDose(_weight, animal?.name ?? '');
    
    // Определяем тип дозы (фиксированная или расчётная)
    final isFixed = doseCalc.type == DoseType.fixed;
    final fixedText = isFixed ? doseCalc.displayText : '';
    
    final contraResult = drug.checkContraindications(
      isPregnant: _gender == Gender.female && _pregnancyPeriod.isPregnant,
      isLactating: false,
      isYoung: ageCategory == AgeCategory.young,
      isOld: ageCategory == AgeCategory.old,
      animalName: animal?.name,
      gender: _gender == Gender.male ? 'male' : 'female',
    );
    
    final sideEffects = drug.getSideEffectsForAnimal(animal?.name ?? '');

    // === НОВОЕ: Проверяем взаимодействия ===
    final interactions = checkInteractions();
    
    // === НОВОЕ: Получаем побочные эффекты из базы ===
    final drugSideEffects = getSideEffects(drug.name);
    final allSideEffects = [...sideEffects];
    if (drugSideEffects != null) {
      for (final se in drugSideEffects.sideEffects) {
        if (!allSideEffects.contains(se.effect)) {
          allSideEffects.add('${se.effect}${se.action.isNotEmpty ? " → ${se.action}" : ""}');
        }
      }
    }

    _result = DoseResult(
      volume: doseCalc.volumeMl > 0 ? doseCalc.volumeMl : doseCalc.volumeGrams,
      unit: doseCalc.isGrams ? 'г' : 'мл',
      drugName: drug.name,
      drugForm: drug.form,
      method: drug.method,
      frequency: isFixed ? '' : drug.frequency,
      courseDays: drug.courseDays,
      withdrawalDays: drug.withdrawalDays,
      withdrawalText: drug.withdrawalText,
      warning: _weightValidation?.warning ?? '',
      contraindications: contraResult.warnings,
      riskWarnings: contraResult.riskWarnings,
      sideEffects: allSideEffects,
      hasDosage: doseCalc.hasCalculation,
      hasResult: true,
      calcDrug: drug,
      note: isFixed ? '' : doseCalc.note,
      interactions: interactions,
      dosePerKg: drug.dosePerKg,
      doseMin: drug.doseMin,
      doseMax: drug.doseMax,
      doseUnit: drug.doseUnit,
      weight: _weight,
      concentration: drug.concentration,
      isFixedDose: isFixed,
      fixedDoseText: fixedText,
    );
  }

  void reset() {
    _selectedAnimalId = null;
    _selectedCalcDrug = null;
    _selectedRegistryDrug = null;
    _weight = 0;
    _result = const DoseResult();
    _weightValidation = null;
    _gender = Gender.male;
    _pregnancyPeriod = PregnancyPeriod.notPregnant;
    _ageMonths = 12;
    _searchQuery = '';
    _selectedMethod = null;
    _selectedDrugHistory.clear();
  }

  /// Поиск препарата по названию/МНН.
  /// Если животное выбрано — сначала ищет среди препаратов для него.
  bool findDrugByName(String name) {
    final lower = name.toLowerCase().trim();
    final animalName = selectedAnimal?.name;
    
    // === 1. Сначала ищем точное совпадение среди препаратов для выбранного животного ===
    if (_calcDatabase != null && animalName != null) {
      for (final d in _calcDatabase!.drugs) {
        if (!d.isForAnimal(animalName)) continue;
        if (d.name.toLowerCase() == lower || d.inn.toLowerCase() == lower) {
          selectDrug(d);
          return true;
        }
      }
    }
    
    // === 2. Потом точное совпадение по всем CalcDrug ===
    if (_calcDatabase != null) {
      for (final d in _calcDatabase!.drugs) {
        if (d.name.toLowerCase() == lower || d.inn.toLowerCase() == lower) {
          selectDrug(d);
          return true;
        }
      }
    }

    // === 3. Содержит название — среди препаратов для животного ===
    if (_calcDatabase != null && animalName != null) {
      for (final d in _calcDatabase!.drugs) {
        if (!d.isForAnimal(animalName)) continue;
        if (d.name.toLowerCase().contains(lower) || 
            d.inn.toLowerCase().contains(lower)) {
          selectDrug(d);
          return true;
        }
      }
    }
    
    // === 4. Содержит название — по всем CalcDrug ===
    if (_calcDatabase != null) {
      for (final d in _calcDatabase!.drugs) {
        if (d.name.toLowerCase().contains(lower) || 
            d.inn.toLowerCase().contains(lower)) {
          selectDrug(d);
          return true;
        }
      }
    }
    
    // === 5. Обратное совпадение (INN содержится в запросе) — только длинные МНН >= 5 символов,
    // и INN должен быть не короче 60% длины запроса чтобы избежать ложных совпадений ===
    if (_calcDatabase != null) {
      for (final d in _calcDatabase!.drugs) {
        final innLower = d.inn.toLowerCase();
        if (innLower.length >= 5 && innLower.length >= (lower.length * 0.6) && lower.contains(innLower)) {
          selectDrug(d);
          return true;
        }
      }
    }
    
    // === 6. Реестр препаратов ===
    if (_registry != null) {
      // Сначала ищем среди препаратов для животного
      if (animalName != null) {
        final animalDrugs = _registry!.getDrugsForAnimal(animalName)
            .where((d) =>
                d.tradeName.toLowerCase() == lower ||
                d.inn.toLowerCase() == lower)
            .toList();
        if (animalDrugs.isNotEmpty) {
          selectDrug(animalDrugs.first);
          return true;
        }
      }
      
      // Потом по всему реестру
      final drugs = _registry!.searchByName(name);
      if (drugs.isNotEmpty) {
        selectDrug(drugs.first);
        return true;
      }
    }
    
    return false;
  }
  
  bool findDrugByINNAndConcentration(String inn, double? concentration) {
    if (_calcDatabase == null) return false;
    
    final animalName = selectedAnimal?.name;
    final innLower = inn.toLowerCase();
    
    var drugs = _calcDatabase!.drugs.where((d) => 
      d.inn.toLowerCase() == innLower
    ).toList();
    
    if (drugs.isEmpty) {
      return findDrugByName(inn);
    }
    
    // Если животное выбрано — приоритет препаратам для него
    if (animalName != null && drugs.length > 1) {
      final animalDrugs = drugs.where((d) => d.isForAnimal(animalName)).toList();
      if (animalDrugs.isNotEmpty) {
        drugs = animalDrugs;
      }
    }
    
    if (concentration != null && concentration > 0) {
      try {
        final d = drugs.firstWhere((d) => 
          d.concentration == concentration || 
          d.concentration == concentration * 10 ||
          d.concentration == concentration * 100
        );
        selectDrug(d);
        return true;
      } catch (_) {
      }
    }
    
    selectDrug(drugs.first);
    return true;
  }

  String getResultSpeechText() {
    if (!_result.hasResult) return '';
    
    final buffer = StringBuffer();
    
    if (_result.hasDosage && _result.volume > 0) {
      buffer.write('${_result.drugName}: ');
      buffer.write('${_result.formattedVolume} ');
      buffer.write('${_result.method}. ');
      
      if (_result.frequency.isNotEmpty) {
        buffer.write('${_result.frequency}. ');
      }
      
      if (_result.courseDays.isNotEmpty) {
        buffer.write('Курс: ${_result.courseDays}. ');
      }
    } else if (_result.hasDosage && _result.isFixedDose) {
      buffer.write('${_result.drugName}. ');
      buffer.write('Доза: ${_result.fixedDoseText}. ');
      if (_result.method.isNotEmpty) {
        buffer.write('${_result.method}. ');
      }
    } else if (_result.hasDosage) {
      buffer.write('${_result.drugName}. ');
      buffer.write('Укажите вес для расчёта дозы. ');
    } else {
      buffer.write('${_result.drugName}. ');
      buffer.write('Дозировка по инструкции. ');
    }
    
    if (_result.hasContraindications && _result.contraindications.isNotEmpty) {
      buffer.write('Внимание! ${_result.contraindications.first} ');
    }
    
    if (_result.warning.isNotEmpty) {
      buffer.write('${_result.warning} ');
    }
    
    if (_result.withdrawalDays > 0) {
      buffer.write('Срок ожидания ${_result.withdrawalDays} дней. ');
    }
    
    return buffer.toString();
  }
}
