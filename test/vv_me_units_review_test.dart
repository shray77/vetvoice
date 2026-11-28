import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetvoice_ai/models/calc_drug.dart';
import 'package:vetvoice_ai/models/drug_registry.dart';
import 'package:vetvoice_ai/models/dosage_database.dart';
import 'package:vetvoice_ai/providers/vet_provider.dart';
import 'package:vetvoice_ai/utils/concentration_parser.dart';

/// Ревью 27.11.2026, блок МЕ (международные единицы): МЕ-числа нигде не
/// делятся на мг/мл — ни в реестровом пути, ни в слайдере ручной дозы;
/// парсер состава понимает МЕ/ME/IU/ЕД и «международных единиц»;
/// подписи не врут единицей (VV-060…VV-066).
///
/// Отчёт-виновник: реестровый путь делил МЕ/кг (doseValue для
/// эритропоэтина/ретинола/холекальциферола — 6 записей базы) на первую
/// попавшуюся мг/мл из состава (Тривит: ретинол «получал» 20 мг витамина
/// Е); слайдер ручной дозы делил МЕ на мг/мл по ТОПОВОЙ единице
/// (Акваколистин: 50 000 МЕ/кг × 6,6 кг ÷ 127 мг/мл ≈ 2600 «мл»).
void main() {
  late CalcDrugDatabase calcDb;
  late DrugRegistry registry;
  late DosageDatabase dosageDb;
  late List<Map<String, dynamic>> registryRaw;

  setUpAll(() {
    final raw = File('assets/data/drugs_registry.json').readAsStringSync();
    calcDb = CalcDrugDatabase.fromJson(
        jsonDecode(File('assets/data/drugs_calc.json').readAsStringSync())
            as Map<String, dynamic>);
    registry =
        DrugRegistry.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    dosageDb = DosageDatabase.fromJson(
        jsonDecode(File('assets/data/dosage_database.json').readAsStringSync())
            as Map<String, dynamic>);
    registryRaw = ((jsonDecode(raw) as Map<String, dynamic>)['drugs']
            as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .toList();
  });

  CalcDrug byId(int id) => calcDb.drugs.firstWhere((d) => d.id == id);

  Map<String, dynamic> regByName(String name) =>
      registryRaw.firstWhere((d) => d['trade_name'] == name);

  // Первое МНН — как в ветке расчёта (vet_provider._calculateFromRegistry).
  String firstInnOf(Map<String, dynamic> drug) =>
      ((drug['inn'] as String? ?? '').split(RegExp('[,;]')).first).trim();

  // VetProvider — синглтон: между тестами состояние живёт, поэтому reset.
  VetProvider provider() {
    final p = VetProvider();
    p.debugSetCore(
        calcDatabase: calcDb,
        registry: registry,
        dosageDatabase: dosageDb);
    p.reset();
    return p;
  }

  group('VV-060: парсер состава понимает МЕ и не подсовывает чужие мг', () {
    test('МЕ-концентрация: ME-латиница, «международных единиц», тыс-разделители',
        () {
      // Тривит (реальная запись): «ретинола ацетат (витамин А) - 30000 ME»
      final trivit = regByName('Тривит® раствор для инъекций');
      expect(
          ConcentrationParser.parseMeConcentrationForSubstance(
              trivit['composition'] as String, firstInnOf(trivit)),
          30000);
      // Витамин А масляный: «100000 международных единиц (ME)»
      final vitA = regByName('Витамин А масляный раствор');
      expect(
          ConcentrationParser.parseMeConcentrationForSubstance(
              vitA['composition'] as String, firstInnOf(vitA)),
          100000);
      // Гидрокол: «4.000.000 ME колистина сульфата» — число ПЕРЕД
      // веществом, точки-разделители тысяч
      final gidrokol = regByName('Гидрокол');
      expect(
          ConcentrationParser.parseMeConcentrationForSubstance(
              gidrokol['composition'] as String, firstInnOf(gidrokol)),
          4000000);
      // Димоксан: «колистина сульфат – 1 200 000 МЕ» — пробелы-тысячи
      expect(
          ConcentrationParser.parseMeConcentrationForSubstance(
              'В 1 г содержит: амоксициллина тригидрат – 200,0 мг, '
              'колистина сульфат – 1 200 000 МЕ',
              'колистин'),
          1200000);
    });

    test('мг-числа чужих веществ не становятся МЕ-концентрацией', () {
      // Утеротон: пропранолол 50 мг + окситоцин 30 ME — у пропранолола
      // первое число после названия НЕМЕ, МЕ-концентрации у него нет.
      expect(
          ConcentrationParser.parseMeConcentrationForSubstance(
              'в 1 мл содержит: пропранолола гидрохлорид - 50 мг, '
              'окситоцин - 30 ME',
              'пропранолол'),
          0);
    });

    test('анти-отравление: собственная МЕ-запись не даёт чужие мг (Тривит)',
        () {
      // Раньше: первое «N мг» после ретинола — «20 мг» витамина Е из того
      // же состава — становилось «его» концентрацией. Теперь честный 0:
      // собственная концентрация ретинола записана в МЕ.
      final trivit = regByName('Тривит® раствор для инъекций');
      expect(
          ConcentrationParser.parseConcentrationForSubstance(
              trivit['composition'] as String, firstInnOf(trivit)),
          0);
      // Мг-МНН по-прежнему парсятся как раньше (регрессия VV-038-гейта)
      expect(
          ConcentrationParser.parseConcentrationForSubstance(
              'В 1 мл препарата содержится флорфеникола 300 мг',
              'флорфеникол'),
          300);
    });

    test('полный прогон реальной базы — без исключений (паттерн VV-038)', () {
      var checked = 0;
      for (final drug in registryRaw) {
        final inn = drug['inn'] as String? ?? '';
        final composition = drug['composition'] as String? ?? '';
        if (inn.isEmpty || composition.isEmpty) continue;
        final fi = inn.split(RegExp('[,;]')).first.trim();
        if (fi.isEmpty) continue;
        checked++;
        // Все три вызова обязаны жить на ЛЮБОЙ строке реестра
        ConcentrationParser.parseConcentrationForSubstance(composition, fi);
        ConcentrationParser.parseMeConcentrationForSubstance(composition, fi);
        ConcentrationParser.getConcentrationUnit(composition);
      }
      expect(checked, greaterThan(2000),
          reason: 'гейт обязан прогонять ВСЮ базу, а не подвыборку');
    });
  });

  group('VV-061: getConcentrationUnit видит латиницу и ЕД', () {
    test('ME/мл, IU/ml, ЕД/мл, «ME в 1 мл» → МЕ/мл', () {
      expect(ConcentrationParser.getConcentrationUnit('в 1 мл 30000 ME/мл'),
          'МЕ/мл');
      expect(ConcentrationParser.getConcentrationUnit('инсулин 100 IU/ml'),
          'МЕ/мл');
      expect(
          ConcentrationParser.getConcentrationUnit('окситоцин 5 ЕД/мл'),
          'МЕ/мл');
      expect(ConcentrationParser.getConcentrationUnit('гормон 40 ME в 1 мл'),
          'МЕ/мл');
      // мг — как раньше
      expect(ConcentrationParser.getConcentrationUnit('в 1 мл 50 мг/мл'),
          'мг/мл');
    });
  });

  group('VV-062: реестровый путь — МЕ делится на МЕ-концентрацию', () {
    test('Тривит, собака 10 кг: 500 МЕ/кг ÷ 30000 МЕ/мл = 0.167 мл', () {
      final p = provider();
      p.selectAnimal(calcDb.animals.firstWhere((a) => a.name == 'Собаки').id);
      p.setWeight(10);
      p.selectRegistryDrug(registry.drugs
          .firstWhere((d) => d.tradeName == 'Тривит® раствор для инъекций'));
      final r = p.result;
      expect(r.hasDosage, isTrue);
      expect(r.volume, closeTo(0.1667, 0.001),
          reason: '500 МЕ/кг × 10 кг ÷ 30000 МЕ/мл. Раньше делили МЕ/кг на '
              '«20 мг» витамина Е из того же состава: 250 «мл» мусора');
      expect(r.note, contains('МЕ/мл'));
    });

    test('Витамин А масляный, собака 10 кг: 500 МЕ/кг ÷ 100000 = 0.05 мл',
        () {
      final p = provider();
      p.selectAnimal(calcDb.animals.firstWhere((a) => a.name == 'Собаки').id);
      p.setWeight(10);
      p.selectRegistryDrug(registry.drugs
          .firstWhere((d) => d.tradeName == 'Витамин А масляный раствор'));
      expect(p.result.volume, closeTo(0.05, 0.001),
          reason: '«100000 международных единиц» в составе — развёрнутая '
              'запись МЕ теперь парсится');
    });

    test('МЕ-доза без МЕ-концентрации → честная карточка (ШУСТРИК)', () {
      // Состав без МНН-названий («вит. А, В1…»), зато поле дозировки несёт
      // чужие мг — раньше 500 МЕ/кг × 10 кг ÷ 0.1 «мг/мл» = 50 000 «мл».
      final p = provider();
      p.selectAnimal(calcDb.animals.firstWhere((a) => a.name == 'Собаки').id);
      p.setWeight(10);
      p.selectRegistryDrug(registry.drugs
          .firstWhere((d) => d.tradeName == 'ШУСТРИК® поливитамины'));
      final r = p.result;
      expect(r.hasDosage, isFalse,
          reason: 'МЕ-доза без МЕ-концентрации не делится на мг/мл');
      expect(r.volume, 0);
      expect(r.note, contains('по инструкции'));
      expect(r.note, contains('МЕ'), reason: 'подсказка про МЕ-концентрацию');
    });
  });

  group('VV-066: мкг-доза реестра переводится в мг (дарбэпоэтин)', () {
    test('1 мкг/кг, conc 0.05 мг/мл, 10 кг → 0.2 мл (не 200)', () {
      final p = provider();
      p.selectAnimal(calcDb.animals.firstWhere((a) => a.name == 'Собаки').id);
      p.setWeight(10);
      // Синтетика по образцу реестра: дарбэпоэтина в реестре препаратов
      // нет, но запись дозы в базе есть (dogs/cats 1 мкг/кг).
      p.selectRegistryDrug(RegistryDrug.fromJson({
        'trade_name': 'Эпо-тест (синтетика VV-066)',
        'inn': 'дарбэпоэтин',
        'composition': 'в 1 мл дарбэпоэтина альфа - 0,05 мг',
      }));
      final r = p.result;
      expect(r.hasDosage, isTrue);
      expect(r.volume, closeTo(0.2, 0.01),
          reason: '(1 мкг/кг / 1000) × 10 кг ÷ 0.05 мг/мл = 0.2 мл. Раньше '
              'мкг делили как мг: 200 «мл» (передоз ×1000, реестровый '
              'аналог VV-001)');
    });
  });

  group('VV-064: setCustomDose — МЕ не делится на мг/мл', () {
    test('Акваколистин #1561: 50 000 МЕ/кг, conc 127 мг/мл → 0 (не ~2600)',
        () {
      final p = provider();
      p.selectDrug(byId(1561));
      p.setWeight(6.6);
      p.setCustomDose(50000);
      expect(p.result.volume, 0,
          reason: 'полевой репорт: 50 000 МЕ/кг × 6,6 кг ÷ 127 мг/мл ≈ '
              '2600 «мл». МЕ без МЕ-концентрации — честный 0');
    });

    test('Полиген #409: та же ловушка, conc 300 мг/мл → 0 (не 1100)', () {
      final p = provider();
      p.selectDrug(byId(409));
      p.setWeight(6);
      p.setCustomDose(50000);
      expect(p.result.volume, 0);
    });

    test('Аралис #303: единица ВИДА (Птица МЕ/кг) важнее топовой мг/кг', () {
      final p = provider();
      p.selectAnimal(calcDb.animals.firstWhere((a) => a.name == 'Птица').id);
      p.selectDrug(byId(303));
      p.setWeight(2);
      p.setCustomDose(50000);
      expect(p.result.volume, 0,
          reason: 'раньше смотрели топовую мг/кг: 50 000 × 2 ÷ 0.5 мг/мл = '
              '200 000 «мл»');
    });

    test('Аралис #303, КРС (мг/кг): массовая ветка не сломана — 35 мл', () {
      final p = provider();
      p.selectAnimal(calcDb.animals.firstWhere((a) => a.name == 'КРС').id);
      p.selectDrug(byId(303));
      p.setWeight(500);
      p.setCustomDose(0.035);
      expect(p.result.volume, closeTo(35, 0.1),
          reason: '0.035 мг/кг × 500 кг ÷ 0.5 мг/мл = 35 мл');
    });

    test('Оридэрмил #1565: МЕ с МЕ-концентрацией (B-4 перенос) — 6.6 мл', () {
      final p = provider();
      p.selectDrug(byId(1565)); // МЕ/кг, concentration_unit МЕ/мл → МЕ 10
      p.setWeight(6.6);
      p.setCustomDose(10);
      expect(p.result.volume, closeTo(6.6, 0.01),
          reason: '10 МЕ/кг × 6,6 кг ÷ 10 МЕ/мл = 6.6 мл — честная МЕ-ветка');
    });
  });

  group('VV-063: formattedDose показывает единицу записи', () {
    test('Пульмосол® С #73, КРС: диапазон в МЕ/кг, не «мг/кг»', () {
      final dose = byId(73).animalSpecific['КРС']!;
      expect(dose.formattedDose, contains('МЕ/кг'));
      expect(dose.formattedDose, isNot(contains('мг/кг')),
          reason: '25000-100000 — это МЕ/кг (колистин), а не мг/кг');
    });

    test('обычные мг-диапазоны — по-прежнему мг/кг', () {
      final dose = AnimalSpecificDose(
        dosePerKg: 0,
        doseMin: 5,
        doseMax: 10,
        doseUnit: 'мг/кг',
      );
      expect(dose.formattedDose, contains('мг/кг'));
    });
  });

  group('VV-065: строкочный concentration_me не роняет препарат', () {
    test('строка → concentrationMe 0 + сырой текст; запись живёт в базе', () {
      final raw = <String, dynamic>{
        'id': 999960,
        'name': 'Тест VV-065',
        'inn': 'тест',
        'form': 'раствор',
        'concentration': 10,
        'concentration_unit': 'мг/мл',
        'dose_per_kg': 5,
        'dose_unit': 'МЕ/кг',
        'concentration_me': '1000 МЕ/мл', // строка — мина класса S-1
        'method': 'в/м',
      };
      final db = CalcDrugDatabase.fromJson({
        'drugs_calc': [raw],
      });
      expect(db.drugs, hasLength(1),
          reason: 'жёсткий каст `as num?` ронял fromJson записи, per-item '
              'catch глотал препарат целиком');
      expect(db.drugs.single.concentrationMe, 0,
          reason: 'строка — не число: в расчёт не идёт');
      expect(db.drugs.single.concentrationMeText, '1000 МЕ/мл');
    });
  });

  group('VV-067 (сверка с vetvoice-data-canonical, Task 263)', () {
    // Сверка канонического слоя с расчётом приложения нашла классы, где
    // приложение делило мг-дозы на числа, которые массовыми концентрациями
    // не являются.
    CalcDrug make({
      required double conc,
      required String unit,
      double me = 0,
      String doseUnit = 'мг/кг',
      double dose = 1,
    }) =>
        CalcDrug.fromJson({
          'id': 4242,
          'name': 'Тест VV-067',
          'inn': 'тест',
          'form': 'раствор',
          'concentration': conc,
          'concentration_unit': unit,
          'concentration_me': me,
          'dose_per_kg': dose,
          'dose_unit': doseUnit,
        });

    test('МЕ-лейбл + me>0: мг-доза не делится на МЕ-число (Утеротон-класс)', () {
      // Утеротон® Форте #226: conc 50 «МЕ/мл», me 30, доза 0.5 мг/кг.
      // Раньше: 0.5 × 10 ÷ 50 = 0.1 «мл» мусора.
      final drug = make(conc: 50, unit: 'МЕ/мл', me: 30, dose: 0.5);
      expect(drug.concentration, 0,
          reason: 'единица объявила МЕ — массовой концентрации нет');
      expect(drug.concentrationMe, 30, reason: 'ME-поле живёт своим числом');
      final result = drug.calculateDose(10, 'Кошки');
      expect(result.type, DoseType.unknown);
    });

    test('МЕ-лейбл + me==0: B-4 перенос работает как раньше', () {
      final drug = make(conc: 10, unit: 'МЕ/мл', dose: 10, doseUnit: 'МЕ/кг');
      expect(drug.concentration, 0);
      expect(drug.concentrationMe, 10);
      final result = drug.calculateDose(10, 'Собаки');
      expect(result.type, DoseType.calculated);
      expect(result.volumeMl, closeTo(10, 1e-9)); // 10 МЕ/кг × 10 ÷ 10 МЕ/мл
    });

    test('percent-концентрация не делится как мг/мл (АвиБлю-класс)', () {
      // АвиБлю #2251: conc 17.8 «% (тиосульфат натрия)» — это 178 мг/мл,
      // а не 17.8; деление давало ×10 передоз.
      final drug = make(conc: 17.8, unit: '% (тиосульфат натрия)', dose: 12);
      expect(drug.concentration, 0);
      final result = drug.calculateDose(10, 'Птица');
      expect(result.type, DoseType.unknown);
    });

    test('fixed-запись с остаточным per_kg не считает мусор (Чистотел-класс)', () {
      // Чистотел пудра #1465: unit fixed, dose_per_kg 10, conc 4 мг/мл.
      final drug = make(conc: 4, unit: 'мг/мл', dose: 10, doseUnit: 'fixed');
      final result = drug.calculateDose(10, 'Свиньи');
      expect(result.type, DoseType.unknown);
      expect(result.volumeMl, 0);
    });

    test('реальная база: Утеротон #226 и Витамин А #587 больше не делят мг на МЕ', () {
      final uteroton = byId(226);
      expect(uteroton.concentration, 0,
          reason: 'Утеротон: unit МЕ/мл при me=30 — масса не определена');
      expect(uteroton.concentrationMe, 30);
      expect(uteroton.calculateDose(10, 'Кошки').type, DoseType.unknown);

      final vitaminA = byId(587);
      expect(vitaminA.concentration, 0,
          reason: 'Витамин А: conc=me=100000 под МЕ-лейблом — массы нет');
      expect(vitaminA.calculateDose(10, 'Собаки').type, DoseType.unknown);
    });
  });
}
