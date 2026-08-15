import 'package:flutter/foundation.dart';
import '../models/animal.dart';
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
  final List<String> riskWarnings;
  final List<DrugInteraction> interactions;
  final String? antidoteInfo;
  final double dosePerKg;
  final double doseMin;
  final double doseMax;
  final String doseUnit;
  final double weight;
  final double concentration;
  final String withdrawalText;
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

/// State-хранилище приложения (Единый Singleton).
class VetProvider extends ChangeNotifier {
  static final VetProvider _instance = VetProvider._internal();
  factory VetProvider() => _instance;
  VetProvider._internal();

  CalcDrugDatabase? _calcDatabase;
  DrugRegistry? _registry;
  DosageDatabase? _dosageDatabase;
  WithdrawalDatabase? _withdrawalDatabase;
  DoseAdjustmentDatabase? _doseAdjustmentDatabase;
  UnofficialProtocolDatabase? _unofficialDatabase;
  FluidTherapyDatabase? _fluidTherapyDatabase;
  VerifiedDosageDatabase? _verifiedDosageDatabase;
  DiseaseDatabase? _diseaseDatabase;
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

  InteractionDatabase? get interactionDatabase => _interactionDatabase;
  AntidoteDatabase? get antidoteDatabase => _antidoteDatabase;
  EmergencyDatabase? get emergencyDatabase => _emergencyDatabase;
  SideEffectsDatabase? get sideEffectsDatabase => _sideEffectsDatabase;
  TreatmentProtocolDatabase? get treatmentProtocolDatabase => _treatmentProtocolDatabase;
  List<String> get selectedDrugHistory => _selectedDrugHistory;

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
    try {
      return _calcDatabase!.animals.firstWhere((a) => a.id == _selectedAnimalId);
    } catch (_) {
      return null;
    }
  }

  List<Animal> get animals => _calcDatabase?.animals ?? [];
  List<CalcDrug> get allCalcDrugs => _calcDatabase?.drugs ?? [];
  List<RegistryDrug> get allRegistryDrugs => _registry?.drugs ?? [];

  /// Все препараты (для поиска) с мгновенным поисковым индексом
  List<dynamic> get allDrugs {
    final List<dynamic> all = [];

    if (_calcDatabase != null) {
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
      final q = _searchQuery.toLowerCase().trim();
      return all.where((d) {
        if (d is CalcDrug) return d.searchIndex.contains(q);
        if (d is RegistryDrug) return d.searchIndex.contains(q);
        return false;
      }).toList();
    }

    return all;
  }

  /// Найти CalcDrug по названию (для протоколов лечения)
  CalcDrug? findCalcDrugByName(String name) {
    if (_calcDatabase == null) return null;
    final lower = name.toLowerCase().trim();
    try {
      return _calcDatabase!.drugs.firstWhere(
        (d) => d.searchIndex.contains(lower),
      );
    } catch (_) {
      return null;
    }
  }

  /// Препараты для выбранного животного с быстрым поиском
  List<dynamic> get availableDrugs {
    final animal = selectedAnimal;
    if (animal == null) return allDrugs;

    final List<dynamic> filtered = [];
    final animalName = animal.name;

    if (_calcDatabase != null) {
      final calcDrugs = _calcDatabase!.getDrugsForAnimal(animalName)
          .where((d) => d.calculatorApplicable)
          .toList();
      filtered.addAll(calcDrugs);
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

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      return filtered.where((d) {
        if (d is CalcDrug) return d.searchIndex.contains(q);
        if (d is RegistryDrug) return d.searchIndex.contains(q);
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

  /// Инициализация (выполняется один раз)
  Future<void> initialize() async {
    if (_calcDatabase != null && !_isLoading) return;

    try {
      _isLoading = true;
      _statusMessage = 'Загрузка баз препаратов...';
      notifyListeners();

      final loadResult = await DrugLoaderService.loadDatabase();
      _calcDatabase = loadResult.calcDatabase;
      _registry = loadResult.registry;
      _dosageDatabase = loadResult.dosageDatabase;
      _interactionDatabase = loadResult.interactionDatabase;
      _antidoteDatabase = loadResult.antidoteDatabase;
      _emergencyDatabase = loadResult.emergencyDatabase;
      _sideEffectsDatabase = loadResult.sideEffectsDatabase;
      _withdrawalDatabase = loadResult.withdrawalDatabase;
      _doseAdjustmentDatabase = loadResult.doseAdjustmentDatabase;
      _unofficialDatabase = loadResult.unofficialDatabase;
      _fluidTherapyDatabase = loadResult.fluidTherapyDatabase;
      _verifiedDosageDatabase = loadResult.verifiedDosageDatabase;
      _isOnline = loadResult.fromNetwork;
      _statusMessage = loadResult.source;

      // Болезни
      try {
        final diseaseData = await DrugLoaderService.loadJsonAsset('assets/data/diseases.json');
        if (diseaseData != null) {
          _diseaseDatabase = DiseaseDatabase.fromJson(diseaseData);
        }
      } catch (_) {}

      // Протоколы лечения
      try {
        final treatmentData = await DrugLoaderService.loadJsonAsset('assets/data/advanced/treatment_protocols.json');
        if (treatmentData != null) {
          _treatmentProtocolDatabase = TreatmentProtocolDatabase.fromJson(treatmentData);
        }
      } catch (_) {}

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _statusMessage = 'Ошибка: $e';
      notifyListeners();
    }
  }

  void setSearchQuery(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  void selectAnimal(String id) {
    _selectedAnimalId = id;
    _selectedCalcDrug = null;
    _selectedRegistryDrug = null;
    _result = const DoseResult();
    _selectedDrugHistory.clear();
    if (_weight > 0) _validateWeight(_weight);
    notifyListeners();
  }

  void selectDrug(dynamic drug) {
    if (drug is CalcDrug) {
      _selectedCalcDrug = drug;
      _selectedRegistryDrug = null;
      _selectedDrugHistory.remove(drug.name);
      _selectedDrugHistory.add(drug.name);
      _recalculate();
    } else if (drug is RegistryDrug) {
      selectRegistryDrug(drug);
    }
    _searchQuery = '';
    notifyListeners();
  }

  void selectRegistryDrug(RegistryDrug drug) {
    _selectedRegistryDrug = drug;
    _selectedCalcDrug = null;
    _selectedDrugHistory.remove(drug.tradeName);
    _selectedDrugHistory.add(drug.tradeName);
    _recalculate();
    _searchQuery = '';
    notifyListeners();
  }

  void setWeight(double w) {
    _weight = w;
    _validateWeight(w);
    _recalculate();
    notifyListeners();
  }

  void setGender(Gender g) {
    _gender = g;
    _recalculate();
    notifyListeners();
  }

  void setPregnancyPeriod(PregnancyPeriod p) {
    _pregnancyPeriod = p;
    _recalculate();
    notifyListeners();
  }

  void setAge(int months) {
    _ageMonths = months;
    _recalculate();
    notifyListeners();
  }

  void setMethod(AdministrationMethod method) {
    _selectedMethod = method;
    _recalculate();
    notifyListeners();
  }

  void reset() {
    _selectedAnimalId = null;
    _selectedCalcDrug = null;
    _selectedRegistryDrug = null;
    _selectedMethod = null;
    _weight = 0;
    _result = const DoseResult();
    _gender = Gender.male;
    _pregnancyPeriod = PregnancyPeriod.notPregnant;
    _ageMonths = 12;
    _searchQuery = '';
    _weightValidation = null;
    _selectedDrugHistory.clear();
    notifyListeners();
  }

  void _validateWeight(double w) {
    final animal = selectedAnimal;
    if (animal == null) {
      _weightValidation = null;
      return;
    }
    _weightValidation = animal.validateWeight(w);
  }

  void setCustomDose(double dose) {
    if (_result.calcDrug == null) return;
    final drug = _result.calcDrug!;

    double volume = 0;
    if (drug.concentration > 0) {
      volume = (dose * _weight) / drug.concentration;
    } else if (drug.concentrationMe > 0) {
      volume = (dose * _weight) / drug.concentrationMe;
    }

    _result = _result.copyWith(
      dosePerKg: dose,
      volume: volume,
    );
    notifyListeners();
  }

  List<DrugInteraction> checkInteractions(String drugName) {
    if (_interactionDatabase == null) return [];
    final allCurrent = List<String>.from(_selectedDrugHistory);
    if (!allCurrent.contains(drugName)) allCurrent.add(drugName);
    return _interactionDatabase!.checkAllInteractions(allCurrent);
  }

  Antidote? findAntidote(String toxin) {
    return _antidoteDatabase?.findByToxin(toxin);
  }

  List<EmergencyProtocol> searchEmergency(String query) {
    return _emergencyDatabase?.search(query) ?? [];
  }

  DrugSideEffects? getSideEffects(String drugName) {
    return _sideEffectsDatabase?.findByDrug(drugName);
  }

  void clearDrugHistory() {
    _selectedDrugHistory.clear();
    _result = _result.copyWith(interactions: []);
    notifyListeners();
  }

  DoseResult _calculateFromRegistry(RegistryDrug drug) {
    final animal = selectedAnimal;
    final animalName = animal?.name ?? '';

    var res = DoseResult(
      drugName: drug.tradeName,
      drugForm: drug.form,
      method: 'См. инструкцию',
      hasDosage: false,
      hasResult: true,
      registryDrug: drug,
      note: drug.indications,
      contraindications: drug.contraindications.isNotEmpty ? [drug.contraindications] : [],
    );

    if (_dosageDatabase == null) return res;

    final innList = drug.inn
        .split(RegExp('[,;]'))
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toList();

    if (innList.isEmpty) return res;

    final substanceDosage = _dosageDatabase!.findByInnList(innList);
    if (substanceDosage == null) {
      return res.copyWith(
        note: '${drug.indications}\n\n💡 Дозировка не найдена в базе. Проверьте инструкцию.',
      );
    }

    final animalDosage = substanceDosage.getForAnimal(animalName);
    if (animalDosage == null || !animalDosage.hasDosage) {
      final available = substanceDosage.availableAnimals;
      return res.copyWith(
        note: '${drug.indications}\n\n⚠️ Дозировка доступна для: ${available.join(', ')}',
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

    final calcDrug = CalcDrug(
      id: drug.id,
      name: drug.tradeName,
      inn: drug.inn,
      form: drug.form,
      formType: 'injection',
      unit: 'мл',
      concentration: concentration,
      concentrationUnit: concentrationUnit,
      dosePerKg: animalDosage.dosePerKg,
      doseMin: animalDosage.doseMin,
      doseMax: animalDosage.doseMax,
      doseUnit: animalDosage.doseUnit,
      animals: substanceDosage.availableAnimals,
      method: animalDosage.method.isNotEmpty ? animalDosage.method : 'См. инструкцию',
      frequency: animalDosage.frequency,
      courseDays: animalDosage.courseDays,
      withdrawalDays: 0,
      contraindications: const CalcContraindications(),
      category: drug.pharmacologicalGroup,
      indications: drug.indications,
      searchIndex: '${drug.tradeName} ${drug.inn} ${drug.pharmacologicalGroup}'.toLowerCase(),
    );

    return _calculateFromCalcDrug(calcDrug);
  }

  DoseResult _calculateFromCalcDrug(CalcDrug drug) {
    final animal = selectedAnimal;
    if (animal == null) {
      return const DoseResult(error: 'Выберите животное');
    }

    if (_weight <= 0) {
      return DoseResult(
        drugName: drug.name,
        drugForm: drug.form,
        calcDrug: drug,
        hasResult: true,
        hasDosage: false,
        note: 'Укажите вес для расчёта',
      );
    }

    final animalName = animal.name;
    final calc = drug.calculateDose(_weight, animalName);

    if (calc.type == DoseType.fixed) {
      return DoseResult(
        volume: 0,
        unit: drug.unit,
        drugName: drug.name,
        drugForm: drug.form,
        method: drug.method,
        frequency: drug.frequency,
        courseDays: drug.courseDays,
        withdrawalDays: drug.withdrawalDays,
        hasDosage: true,
        hasResult: true,
        calcDrug: drug,
        note: calc.note,
        isFixedDose: true,
        fixedDoseText: calc.displayText,
      );
    }

    if (calc.type == DoseType.notApplicable) {
      return DoseResult(
        error: calc.note,
        drugName: drug.name,
        calcDrug: drug,
      );
    }

    final doseDosePerKg = drug.dosePerKg;
    final doseMin = drug.doseMin;
    final doseMax = drug.doseMax;

    return DoseResult(
      volume: calc.volumeMl,
      unit: drug.unit,
      drugName: drug.name,
      drugForm: drug.form,
      method: drug.method,
      frequency: drug.frequency,
      courseDays: drug.courseDays,
      withdrawalDays: drug.withdrawalDays,
      withdrawalText: drug.withdrawalText,
      hasDosage: true,
      hasResult: true,
      calcDrug: drug,
      dosePerKg: doseDosePerKg,
      doseMin: doseMin,
      doseMax: doseMax,
      doseUnit: drug.doseUnit,
      weight: _weight,
      concentration: drug.concentration,
      note: calc.note,
    );
  }

  void _recalculate() {
    if (_selectedCalcDrug != null) {
      _result = _calculateFromCalcDrug(_selectedCalcDrug!);
    } else if (_selectedRegistryDrug != null) {
      _result = _calculateFromRegistry(_selectedRegistryDrug!);
    } else {
      _result = const DoseResult();
    }
  }
}
