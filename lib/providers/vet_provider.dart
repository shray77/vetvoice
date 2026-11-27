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
import '../models/mia.dart';
import '../services/drug_loader_service.dart';
import '../services/theme_service.dart';
import '../utils/concentration_parser.dart';
import '../utils/species_safety.dart';
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

  // === НОВОЕ (идея №4): WHO MIA — stewardship-слой на препарате ===
  final MiaInfo? miaInfo;
  
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

  // === Расчёт на стадо (акселератор, 26.11.2026): доза на голову +
  // суммарное количество препарата на поголовье. 1 = одиночное животное. ===
  final int herdCount;

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
    this.miaInfo,
    this.dosePerKg = 0,
    this.doseMin = 0,
    this.doseMax = 0,
    this.doseUnit = 'мг/кг',
    this.weight = 0,
    this.concentration = 0,
    this.withdrawalText = '',
    this.isFixedDose = false,
    this.fixedDoseText = '',
    this.herdCount = 1,
  });

  bool get hasWithdrawalText => withdrawalText.isNotEmpty;

  bool get hasError => error.isNotEmpty;
  bool get hasContraindications => contraindications.isNotEmpty;
  bool get hasSideEffects => sideEffects.isNotEmpty;
  bool get hasRiskWarnings => riskWarnings.isNotEmpty;
  bool get hasDoseRange => doseMin > 0 && doseMax > 0 && doseMin < doseMax;
  bool get hasInteractions => interactions.isNotEmpty;
  bool get hasMia => miaInfo != null;

  /// Расчёт на стадо: поголовье больше одной головы.
  bool get isHerd => herdCount > 1;

  /// Суммарное количество препарата на всё стадо (в тех же единицах,
  /// что и доза на голову: мл / г / шт).
  String get formattedHerdVolume {
    final total = volume * herdCount;
    if (total >= 100) return '${total.toStringAsFixed(0)} $unit';
    if (total >= 10) return '${total.toStringAsFixed(1)} $unit';
    if (total >= 1) return '${total.toStringAsFixed(2)} $unit';
    return '${total.toStringAsFixed(3)} $unit';
  }

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
    MiaInfo? miaInfo,
    double? dosePerKg,
    double? doseMin,
    double? doseMax,
    String? doseUnit,
    double? weight,
    double? concentration,
    bool? isFixedDose,
    String? fixedDoseText,
    String? withdrawalText,
    int? herdCount,
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
      miaInfo: miaInfo ?? this.miaInfo,
      dosePerKg: dosePerKg ?? this.dosePerKg,
      doseMin: doseMin ?? this.doseMin,
      doseMax: doseMax ?? this.doseMax,
      doseUnit: doseUnit ?? this.doseUnit,
      weight: weight ?? this.weight,
      concentration: concentration ?? this.concentration,
      isFixedDose: isFixedDose ?? this.isFixedDose,
      fixedDoseText: fixedDoseText ?? this.fixedDoseText,
      withdrawalText: withdrawalText ?? this.withdrawalText,
      herdCount: herdCount ?? this.herdCount,
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

  /// Тестовый шов (Task 194): подсадить базы без DrugLoaderService —
  /// проверять фильтры поиска и реестровый путь на реальных данных
  /// из файлов (паттерн real_database_test).
  @visibleForTesting
  void debugSetCore({
    required CalcDrugDatabase calcDatabase,
    DrugRegistry? registry,
    DosageDatabase? dosageDatabase,
  }) {
    _calcDatabase = calcDatabase;
    _registry = registry;
    _dosageDatabase = dosageDatabase;
  }

  // VV-034: прежний bool-гард _initialized заменён мемоизацией in-flight
  // Future (_initFuture) — см. initialize().

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
  MiaDatabase? _miaDatabase;
  
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

  // === Расчёт на стадо (акселератор, 26.11.2026): режим + поголовье ===
  bool _herdMode = false;
  int _herdCount = 10;
  
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
  bool get herdMode => _herdMode;
  int get herdCount => _herdCount;
  
  // === НОВОЕ: Геттеры для новых баз ===
  InteractionDatabase? get interactionDatabase => _interactionDatabase;
  AntidoteDatabase? get antidoteDatabase => _antidoteDatabase;
  EmergencyDatabase? get emergencyDatabase => _emergencyDatabase;
  SideEffectsDatabase? get sideEffectsDatabase => _sideEffectsDatabase;
  TreatmentProtocolDatabase? get treatmentProtocolDatabase => _treatmentProtocolDatabase;
  MiaDatabase? get miaDatabase => _miaDatabase;
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
      // Task 194: но НЕ прячем записи с фиксированными дозами (вакцины,
      // МЕ-препараты): окситоцин после медсверки Task 191 носит
      // calculator_applicable=false и исчезал из поиска — юзера
      // уводило в реестровую запись с нулями («0.000 мл» на любом весе,
      // полевой репорт по КРС). fixed_dose по видам — полноценный
      // результат калькулятора.
      all.addAll(_calcDatabase!.drugs.where(
          (d) => d.calculatorApplicable || (d.fixedDose?.isNotEmpty ?? false)));
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
      // Task 194: фиксированные дозы — не повод прятать (см. allDrugs).
      final calcDrugs = _calcDatabase!.getDrugsForAnimal(animalName)
          .where((d) =>
              d.calculatorApplicable || (d.fixedDose?.isNotEmpty ?? false))
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
        .map((s) => s.trim().toLowerCase().replaceAll('ё', 'е'))
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
  ///
  /// ⚠ Фикс VV-034 (ревью 26.11.2026): мемоизируется in-flight Future, а не
  /// bool-флаг до await. Раньше гард `_initialized = true` ДО await без
  /// сброса в catch навсегда оставлял провайдер «инициализированным» после
  /// transient-ошибки чтения assets — все экраны жили с пустыми базами,
  /// ретрая не было. Теперь успешно завершённая инициализация не
  /// перезапускается (повторные вызовы — мгновенный no-op, как и раньше),
  /// а после ошибки мемо сбрасывается — повторный initialize() ретраит
  /// загрузку. Паттерном согласовано с VV-035 (in-flight мемоизация
  /// DrugLoaderService.loadCore).
  Completer<void> _extendedCompleter = Completer<void>();
  Future<void>? _initFuture;

  /// Готовность вторичных баз (СТАДИЯ 2). Никогда не бросает исключение.
  Future<void> get extendedReady => _extendedCompleter.future;

  Future<void> initialize() {
    final inFlight = _initFuture;
    if (inFlight != null) return inFlight; // успех или загрузка в полёте
    // Ретрай после ошибки: старый completer уже завершён в catch — создаём
    // свежий, чтобы extendedReady новой попытки честно ждал СТАДИЮ 2.
    if (_extendedCompleter.isCompleted) {
      _extendedCompleter = Completer<void>();
    }
    final future = _initialize();
    _initFuture = future;
    return future;
  }

  Future<void> _initialize() async {
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

      // VV-033: частичная потеря базы дозировок (битые записи пропущены)
      // — факт обязан быть виден наверху, а не тихо потерян.
      if (loadResult.skippedDosageCount > 0) {
        debugPrint('⚠ База дозировок: пропущено битых МНН-записей: '
            '${loadResult.skippedDosageCount}');
      }

      // v1.16.4: «Версия базы» в настройках вечно показывала «Загрузка...» —
      // ThemeService.setDatabaseInfo не вызывался НИГДЕ (мёртвый фиче-код).
      // Заполняем сразу после ядра: version/last_updated лежат в самом JSON.
      final db = _calcDatabase;
      if (db != null) {
        final buf = StringBuffer('v${db.version} · ${db.drugs.length} препаратов');
        if (db.lastUpdated.isNotEmpty) buf.write(' · обновлено ${db.lastUpdated}');
        buf.write(' · в комплекте'); // v1.20.1: assets-only, сетевого апдейта нет
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
      _initFuture = null; // VV-034: сброс мемо — повторный initialize() ретраит
      if (!_extendedCompleter.isCompleted) {
        _extendedCompleter.complete(); // не оставляем вечный Future
      }
      return;
    }

    // === СТАДИЯ 2: фоном, не блокирует home ===
    unawaited(_loadExtendedDatabases());
  }

  /// v1.16.3: вторичные базы + болезни + протоколы лечения — строго после
  /// первого кадра. Ошибки гасим: эти базы факультативны для расчёта доз,
  /// экраны уже имеют null-guard'ы.
  ///
  /// ⚠ Фикс VV-017 (ревью 26.11.2026): внешний try/catch всего тела. Раньше
  /// сбой вне per-spec блоков (parseExtended и др.) улетал из unawaited() в
  /// unhandled zone: auxiliary-базы молча оставались null, extendedReady при
  /// этом «успешно» резолвился. Теперь и сбой логируется, и complete() у
  /// extendedReady гарантирован в finally.
  Future<void> _loadExtendedDatabases() async {
    try {
      final ext = await DrugLoaderService.parseExtended();
      if (ext != null) {
        _antidoteDatabase = ext.antidoteDatabase;
        _emergencyDatabase = ext.emergencyDatabase;
        _sideEffectsDatabase = ext.sideEffectsDatabase;
        _miaDatabase = ext.miaDatabase;
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
    } catch (e) {
      // VV-017: гарантия — сбой ЛЮБОЙ auxiliary-базы не уходит в unhandled
      // zone (unawaited) и не оставляет extendedReady висеть.
      debugPrint('⚠ Extended databases not loaded: $e');
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

    // Task 230: реестровый contraindications — свободный текст, где
    // видовые запреты живут вперемешку с общими («противопоказан
    // лошадям...», «не применять несушкам...»). Режем предложения про
    // чужие виды: выбранному виду — только его предупреждения.
    final contraText = animalName.isNotEmpty
        ? SpeciesSafetyFilter.filterTextForAnimal(
            drug.contraindications, animalName)
        : drug.contraindications;

    var result = DoseResult(
      drugName: drug.tradeName,
      drugForm: drug.form,
      method: 'См. инструкцию',
      hasDosage: false,
      hasResult: true,
      registryDrug: drug,
      note: drug.indications,
      contraindications: contraText.isNotEmpty ? [contraText] : [],
    );

    if (_dosageDatabase == null) {
      return result;
    }

    final innList = drug.inn
        .split(RegExp('[,;]'))
        .map((s) => s.trim().toLowerCase().replaceAll('ё', 'е'))
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
    double concentrationMe = 0;
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

      // ⚠ Фикс VV-060 (ревью 27.11.2026): МЕ-концентрация собственного
      // вещества — отдельным вызовом, единицы смешивать нельзя.
      concentrationMe = ConcentrationParser.parseMeConcentrationForSubstance(
          drug.composition, innList.first);
    }

    if (concentration == 0 && drug.dosage.isNotEmpty) {
      concentration = ConcentrationParser.parseFromDosageField(drug.dosage);
    }

    // ⚠ Фикс VV-062 (ревью 27.11.2026): МЕ-доза (эритропоэтин, ретинол,
    // холекальциферол — 6 реестровых записей) делится ТОЛЬКО на
    // МЕ-концентрацию. Раньше doseValue честно возвращала МЕ/кг, а делили
    // её на первую попавшуюся мг/мл из состава (Тривит: ретинол 500 МЕ/кг
    // × 10 кг ÷ «20 мг» витамина Е = 250 «мл» мусора). МЕ-доза без
    // МЕ-концентрации уходит в честную карточку «по инструкции» ниже —
    // паттерн Task 194, а не численный мусор.
    final bool meDose = animalDosage.doseIuKg > 0;
    final bool meDoseWithoutMeConc = meDose && concentrationMe <= 0;
    final bool mgDose =
        animalDosage.doseMgKg > 0 || animalDosage.doseMcgKg > 0;
    // Блок обязан ПОСЧИТАТЬ объём — иначе карточка напечатает «0.000 мл»
    // при hasDosage=true (полевой репорт Task 194: окситоцин на КРС,
    // мг-доза при концентрации только в МЕ/ЕД).
    final bool calculable = animalDosage.doseMlKg > 0 ||
        (meDose && concentrationMe > 0) ||
        (mgDose && concentration > 0);

    if (_weight > 0 && !meDoseWithoutMeConc && calculable) {
      double volumeMl = 0;
      String note = '';

      if (animalDosage.doseMlKg > 0) {
        volumeMl = animalDosage.doseMlKg * _weight;
        note = '${animalDosage.doseMlKg} мл/кг';
      } else if (meDose) {
        volumeMl = (animalDosage.doseIuKg * _weight) / concentrationMe;
        note =
            '${animalDosage.formattedDose} × ${_weight.toStringAsFixed(1)} кг ÷ $concentrationMe МЕ/мл';
      } else if (concentration > 0) {
        // ⚠ Фикс VV-066 (ревью 27.11.2026): мкг-доза (дарбэпоэтин
        // 1 мкг/кг) переводится в мг до деления на мг/мл — иначе передоз
        // ×1000 (реестровый аналог VV-001 калькуляторной ветки).
        final double doseMgKg = animalDosage.doseMgKg > 0
            ? animalDosage.doseMgKg
            : animalDosage.doseMcgKg / 1000;
        volumeMl = (doseMgKg * _weight) / concentration;
        note = '${animalDosage.formattedDose} × ${_weight.toStringAsFixed(1)} кг ÷ $concentration $concentrationUnit';
      }

      final warnings = <String>[];
      if (contraText.isNotEmpty) {
        warnings.add(contraText);
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

    // Task 194: концентрация не распарсилась и мл/кг-дозы нет — раньше
    // возвращали volume=0 с hasDosage=true, и карточка печатала огромное
    // зелёное «0.000 мл» на любом весе (полевой репорт: окситоцин на КРС).
    // Честный результат — инфо-карточка «по инструкции» с дозой из реестра.
    // ⚠ Фикс VV-062 (ревью 27.11.2026): сюда же честно уходит МЕ-доза без
    // МЕ-концентрации в составе.
    final meHint = meDoseWithoutMeConc
        ? '⚠ Концентрация в МЕ не найдена в составе — рассчитайте объём по инструкции.\n'
        : '';
    return DoseResult(
      drugName: drug.tradeName,
      drugForm: drug.form,
      method: animalDosage.route,
      frequency: animalDosage.frequency,
      hasDosage: false,
      hasResult: true,
      registryDrug: drug,
      note: 'Дозировка: ${animalDosage.formattedDose}\n$meHint${animalDosage.notes}\n\n${drug.indications}',
      contraindications: contraText.isNotEmpty ? [contraText] : [],
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

    // ⚠ Фикс VV-064 (ревью 27.11.2026): слайдер делил МЕ-дозу на мг/мл
    // (Акваколистин: 50 000 МЕ/кг × 6,6 кг ÷ 127 мг/мл ≈ 2600 «мл») —
    // смотрел только на ТОПОВУЮ единицу препарата и при МЕ-ветке без
    // concentrationMe проваливался в массовую. Теперь диспетчеризация та
    // же, что в CalcDrug.calculateDose: решает ЭФФЕКТИВНАЯ единица —
    // единица выбранного вида важнее топовой; МЕ без МЕ-концентрации —
    // честный 0, не мг/мл-мусор.
    final animalName = selectedAnimal?.name ?? '';
    AnimalSpecificDose? animalDose = drug.animalSpecific[animalName];
    if (animalDose == null) {
      for (final e in drug.animalSpecific.entries) {
        if (e.key.toLowerCase() == animalName.toLowerCase()) {
          animalDose = e.value;
          break;
        }
      }
    }
    final effectiveUnit =
        (animalDose != null && animalDose.doseUnit.isNotEmpty)
            ? animalDose.doseUnit
            : drug.doseUnit;
    final unitUpper = effectiveUnit.toUpperCase();

    double volume = 0;
    // ⚠ Фикс S-2 (Task 183): ручная корректировка дозы обязана повторять
    // ветвление CalcDrug.calculateDose — объёмная доза (мл/кг) НЕ делится
    // на концентрацию (раньше слайдер пересчитывал мл/кг-препараты в
    // мусор: Рингер-Локк/Гамавит — те же ×9/×50, что и в основном расчёте).
    // ⚠ Фикс VV-001/VV-008 (ревью 26.11.2026): и единицы тоже — мкг/кг
    // (÷1000 перед делением на мг/мл), МЕ (÷concentrationMe), иначе —
    // честный 0 без мусора.
    // ⚠ Фикс VV-007 (ревью 26.11.2026): доза на кг КОРМА — объёма не
    // существует, норму задают по потреблению корма.
    if (effectiveUnit.contains('корма')) {
      volume = 0;
    } else if (unitUpper.contains('МЕ')) {
      if (drug.concentrationMe > 0) {
        volume = effectiveUnit.contains('животное')
            ? customDosePerKg / drug.concentrationMe
            : (customDosePerKg * _weight) / drug.concentrationMe;
      } // нет МЕ-концентрации → честный 0, не мг/мл
    } else if (effectiveUnit.contains('мл/животное')) {
      volume = customDosePerKg; // фикс на животное — вес не умножается
    } else if (effectiveUnit.contains('мл/кг')) {
      volume = customDosePerKg * _weight;
    } else if (drug.concentration > 0) {
      final double doseMgPerKg =
          unitUpper.contains('МКГ') ? customDosePerKg / 1000 : customDosePerKg;
      volume = (doseMgPerKg * _weight) / drug.concentration;
    }

    _result = _result.copyWith(
      volume: volume,
      dosePerKg: customDosePerKg,
    );
  }

  // === Расчёт на стадо (акселератор, 26.11.2026) ===

  /// Вкл/выкл режима «стадо»: доза на голову + суммарное количество на
  /// всё поголовье. Вес в поле ввода трактуется как средний вес головы.
  void setHerdMode(bool value) {
    if (_herdMode == value) return;
    _herdMode = value;
    if (_selectedCalcDrug != null) {
      _recalculate();
    } else if (_selectedRegistryDrug != null) {
      _result = _result.copyWith(herdCount: _herdMode ? _herdCount : 1);
    }
  }

  /// Поголовье стада (1…1 000 000 голов).
  void setHerdCount(int value) {
    final v = value < 1 ? 1 : (value > 1000000 ? 1000000 : value);
    if (_herdCount == v) return;
    _herdCount = v;
    if (_herdMode) {
      if (_selectedCalcDrug != null) {
        _recalculate();
      } else if (_selectedRegistryDrug != null) {
        _result = _result.copyWith(herdCount: _herdCount);
      }
    }
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
      // Task 230: состояние лактации впервые достижимо из UI — раньше
      // хардкод false держал 885 lactation-флагов базы мёртвыми
      isLactating: _gender == Gender.female &&
          _pregnancyPeriod == PregnancyPeriod.lactating,
      isYoung: ageCategory == AgeCategory.young,
      isOld: ageCategory == AgeCategory.old,
      animalName: animal?.name,
      gender: _gender == Gender.male ? 'male' : 'female',
    );
    
    final sideEffects = drug.getSideEffectsForAnimal(animal?.name ?? '');

    // === НОВОЕ: Проверяем взаимодействия ===
    final interactions = checkInteractions();
    
    // === НОВОЕ: Получаем побочные эффекты из базы ===
    // Task 230: сперва по МНН (чистое совпадение), затем по торговому
    // названию; видовые эффекты (species) — только выбранному виду:
    // «ототоксичность, кошки чувствительнее» не выезжает КРС.
    final drugSideEffects = drug.inn.isNotEmpty
        ? (getSideEffects(drug.inn) ?? getSideEffects(drug.name))
        : getSideEffects(drug.name);
    final allSideEffects = [...sideEffects];
    if (drugSideEffects != null) {
      final animalName = animal?.name ?? '';
      for (final se in drugSideEffects.sideEffects) {
        if (animalName.isNotEmpty && !se.matchesAnimal(animalName)) continue;
        if (!allSideEffects.contains(se.effect)) {
          allSideEffects.add('${se.effect}${se.action.isNotEmpty ? " → ${se.action}" : ""}');
        }
      }
    }

    // ⚠ Фикс VV-005 (ревью 26.11.2026): критическое предупреждение MDR1
    // (тест для пород группы колли перед ивермектином) жило только в JSON —
    // модель поле не читала, владелец колли не видел риск нейротоксикоза.
    final mdr1Test = drugSideEffects?.mdr1Test;
    if (mdr1Test != null && mdr1Test.isNotEmpty) {
      allSideEffects.insert(0, 'MDR1-тест (породы группы колли): $mdr1Test');
    }

    _result = DoseResult(
      // ⚠ Фикс VV-011 (ревью 26.11.2026): у таблеток/саше (unit='шт') объём
      // был 0 → «0 мл» вместо «1.5 шт»; теперь количество — полноправный
      // результат, единица результата честная ('шт'/'г'/'мл').
      volume: doseCalc.volume,
      unit: doseCalc.isGrams ? 'г' : (doseCalc.isPieces ? 'шт' : 'мл'),
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
      miaInfo: _miaDatabase?.resolve(drug.id),
      // Расчёт на стадо (акселератор, 26.11.2026)
      herdCount: _herdMode ? _herdCount : 1,
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

  /// ⚠ Фикс VV-008 (ревью 26.11.2026): голосовой поиск выбирал записи с
  /// calculator_applicable=false (Полиген: 75 000 МЕ/кг без концентрации в
  /// МЕ) — калькулятор по ним честно уходит в «по инструкции», но такая
  /// запись перехватывала выбор раньше пригодной. Голос берёт только
  /// применимые к расчёту записи или записи с фиксированными дозами
  /// (паттерн Task 194: окситоцин носит calculator_applicable=false, но его
  /// fixed_dose — полноценный результат калькулятора).
  bool _voiceSelectable(CalcDrug d) =>
      d.calculatorApplicable || (d.fixedDose?.isNotEmpty ?? false);

  /// Поиск препарата по названию/МНН.
  /// Если животное выбрано — сначала ищет среди препаратов для него.
  bool findDrugByName(String name) {
    final lower = name.toLowerCase().trim();
    final animalName = selectedAnimal?.name;
    
    // === 1. Сначала ищем точное совпадение среди препаратов для выбранного животного ===
    if (_calcDatabase != null && animalName != null) {
      for (final d in _calcDatabase!.drugs) {
        if (!d.isForAnimal(animalName)) continue;
        // VV-008: голос не выбирает неприменимые к расчёту записи
        if (!_voiceSelectable(d)) continue;
        if (d.name.toLowerCase() == lower || d.inn.toLowerCase() == lower) {
          selectDrug(d);
          return true;
        }
      }
    }
    
    // === 2. Потом точное совпадение по всем CalcDrug ===
    if (_calcDatabase != null) {
      for (final d in _calcDatabase!.drugs) {
        // VV-008: голос не выбирает неприменимые к расчёту записи
        if (!_voiceSelectable(d)) continue;
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
        // VV-008: голос не выбирает неприменимые к расчёту записи
        if (!_voiceSelectable(d)) continue;
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
        // VV-008: голос не выбирает неприменимые к расчёту записи
        if (!_voiceSelectable(d)) continue;
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
        // VV-008: голос не выбирает неприменимые к расчёту записи
        if (!_voiceSelectable(d)) continue;
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
      // Расчёт на стадо (акселератор, 26.11.2026)
      if (_result.isHerd) {
        buffer.write(
            'На стадо (${_result.herdCount} голов): ${_result.formattedHerdVolume}. ');
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
