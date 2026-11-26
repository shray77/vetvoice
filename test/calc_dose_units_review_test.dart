import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetvoice_ai/models/calc_drug.dart';

/// Юнит-гейт на РЕАЛЬНОЙ базе: критические фиксы блока A ревью 26.11.2026 —
/// единицы доз (мкг/кг, мл/кг вида, мг/кг корма, МЕ, ме/кг) и «нули»
/// (VV-001/002/007/008/009/010/011/013).
void main() {
  late CalcDrugDatabase db;

  setUpAll(() {
    final raw = File('assets/data/drugs_calc.json').readAsStringSync();
    db = CalcDrugDatabase.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  });

  CalcDrug byId(int id) => db.drugs.firstWhere((d) => d.id == id);

  group('VV-001: мкг/кг переводится в мг/кг до деления на мг/мл', () {
    // Обе реальные мкг/кг-записи базы (Регостенол #915, Геставет Прост
    // #2304) имеют fixed_dose по КРС — ветка fixed приоритетнее, поэтому
    // формулу проверяем синтетикой (паттерн calc_drug_test), а реальность
    // фиксированных доз фиксируем отдельным тестом ниже.
    CalcDrug micrograms() => CalcDrug(
          id: 915,
          name: 'Регостенол (тест мкг)',
          inn: 'простагландин',
          form: 'раствор',
          unit: 'мл',
          concentration: 0.25,
          concentrationUnit: 'мг/мл',
          dosePerKg: 0.96,
          doseMin: 0.768,
          doseMax: 1.152,
          doseUnit: 'мкг/кг',
          animals: const ['КРС'],
          method: 'в/м',
          contraindications: const CalcContraindications(),
        );

    test('0.96 мкг/кг, conc 0.25 мг/мл, 500 кг → 1.92 мл (не 1920)', () {
      final r = micrograms().calculateDose(500, 'КРС');
      expect(r.type, DoseType.calculated);
      expect(r.volumeMl, closeTo(1.92, 0.01),
          reason: '(0.96 мкг/кг / 1000) × 500 кг / 0.25 мг/мл = 1.92 мл. '
              'Раньше мкг не переводился — выходило 1920 «мл» (передоз ×1000).');
      expect(r.note, contains('мкг/кг'));
    });

    test('реальные #915/#2304: fixed_dose по КРС приоритетнее — честный текст',
        () {
      final r915 = byId(915).calculateDose(500, 'КРС');
      expect(r915.type, DoseType.fixed);
      expect(r915.displayText, '2 мл в/м однократно');
      final r2304 = byId(2304).calculateDose(500, 'Свиньи');
      expect(r2304.type, DoseType.fixed);
      expect(r2304.displayText, '1 мл в/м');
    });
  });

  group('VV-002: объёмная доза вида (мл/кг) не делится на концентрацию', () {
    test('Зинаприм #480: КРС 0.1 мл/кг × 500 кг = 50 мл, а не 1.25', () {
      final r = byId(480).calculateDose(500, 'КРС');
      expect(r.type, DoseType.calculated);
      expect(r.volumeMl, closeTo(50, 0.01),
          reason: 'animal_specific КРС = 0.1 мл/кг при топовых мг/кг: раньше '
              'ветка выбиралась по топовой единице и делила объёмную дозу на '
              'концентрацию 40 мг/мл → 1.25 мл (×40 недодоза)');
      expect(r.note, contains('мл/кг'));
    });
  });

  group('VV-007: мг/кг корма не умножается на вес животного', () {
    test('Робимикс #42 (30 мг/кг корма), Птица 1 кг → unknown', () {
      final r = byId(42).calculateDose(1, 'Птица');
      expect(r.type, DoseType.unknown,
          reason: 'Доза на килограмм КОРМА не сводится к массе тела: раньше '
              '30 × 1 / 66 = «0.45 мл» — численный мусор');
    });
  });

  group('VV-008: МЕ-дозы', () {
    test('Полиген #409 (75 000 МЕ/кг, conc 300 мг/мл), Птица 6 кг → unknown',
        () {
      final r = byId(409).calculateDose(6, 'Птица');
      expect(r.type, DoseType.unknown,
          reason: 'Концентрация в МЕ не указана — несводимо. Раньше массовая '
              'ветка делила МЕ на мг/мл: 75 000 × 6 / 300 = «1500 мл» птице '
              '(кейс владельца: «2 л в птицу 6 кг — как-то странно»)');
      expect(r.volumeMl, 0);
    });

    test('Ронколейкин #1758 (МЕ в dose_per_kg + conc 50 000 МЕ/мл), '
        'Собаки 10 кг → 2 мл', () {
      final r = byId(1758).calculateDose(10, 'Собаки');
      expect(r.type, DoseType.calculated);
      expect(r.volumeMl, closeTo(2.0, 0.01),
          reason: '10 000 МЕ/кг × 10 кг / 50 000 МЕ/мл = 2 мл. Раньше при '
              'выбранном виде МЕ-значения из dose_per_kg не считались вовсе '
              '(unknown вместо честных мл).');
    });
  });

  group('VV-009: «ме/кг» нижним регистром распознаётся как МЕ', () {
    // Все реальные «ме/кг»-записи (Отоферонол Голд #1428, ДЕЛЬЦИД® #1669,
    // Зоошампунь Луговой #1741) имеют fixed_dose «наружно» — честная ветка
    // fixed срабатывает раньше. Само распознавание регистра проверяем
    // синтетикой.
    CalcDrug lowercaseMe() => CalcDrug(
          id: 1428,
          name: 'Капли ушные (тест ме/кг)',
          inn: 'тест',
          form: 'капли',
          unit: 'мл',
          concentration: 1,
          concentrationUnit: 'мг/мл',
          dosePerKg: 6,
          doseUnit: 'ме/кг',
          animals: const ['Собаки'],
          method: 'наружно',
          contraindications: const CalcContraindications(),
          animalSpecific: {
            'Собаки': const AnimalSpecificDose(
              dosePerKg: 6,
              doseUnit: 'ме/кг',
            ),
          },
        );

    test('доза 6 «ме/кг», conc 1 мг/мл, 10 кг → unknown, не «60 мл»', () {
      final r = lowercaseMe().calculateDose(10, 'Собаки');
      expect(r.type, DoseType.unknown,
          reason: 'Доза в МЕ при концентрации в мг/мл несводима без '
              'МЕ-концентрации. Раньше «ме/кг» считался как мг: 6 × 10 / 1 = '
              '«60 мл» ушных капель');
      expect(r.volumeMl, 0);
    });

    test('реальные #1428/#1741: fixed_dose «наружно» приоритетнее', () {
      expect(byId(1428).calculateDose(10, 'Собаки').type, DoseType.fixed);
      expect(
          byId(1741).calculateDose(10, 'Собаки').displayText, 'наружно');
    });
  });

  group('VV-010: примечание показывает единицу дозы вида', () {
    test('Повервит WSP #2320: птица 20–50 мг/кг (не «мл/кг»)', () {
      final r = byId(2320).calculateDose(1, 'Птица');
      expect(r.type, DoseType.calculated);
      expect(r.note, contains('мг/кг'),
          reason: 'Единица берётся из animal_specific.doseUnit (мг/кг), '
              'а не топовой (мл/кг)');
      expect(r.note, isNot(contains('мл/кг')));
    });
  });

  group('VV-011: таблетки (unit=шт) — количество, а не «0 мл»', () {
    test('Фунгин® таблетки #9 (собаки 5 мг/кг, 200 мг/таб), 10 кг → 0.25 шт',
        () {
      final r = byId(9).calculateDose(10, 'Собаки');
      expect(r.type, DoseType.calculated);
      expect(r.volumeMl, 0,
          reason: 'Таблетки — не миллилитры');
      expect(r.count, closeTo(0.25, 0.001),
          reason: '5 мг/кг × 10 кг / 200 мг/таб = 0.25 таблетки');
      expect(r.isPieces, isTrue);
      expect(r.volume, closeTo(0.25, 0.001));
      expect(r.displayText, contains('шт'));
    });
  });

  group('VV-013: NaN/±inf/отрицательный вес → unknown', () {
    test('NaN', () {
      final r = byId(480).calculateDose(double.nan, 'Собаки');
      expect(r.type, DoseType.unknown);
      expect(r.displayText, isNot(contains('NaN')));
    });

    test('отрицательный вес', () {
      final r = byId(480).calculateDose(-100, 'Собаки');
      expect(r.type, DoseType.unknown);
    });

    test('бесконечность', () {
      final r = byId(480).calculateDose(double.infinity, 'Собаки');
      expect(r.type, DoseType.unknown);
    });
  });

  group('Регрессия: массовая ветка не сломана диспетчеризацией единиц', () {
    test('Зинаприм #480: Собаки 15 мг/кг, conc 40 мг/мл, 10 кг → 3.75 мл', () {
      final r = byId(480).calculateDose(10, 'Собаки');
      expect(r.type, DoseType.calculated);
      expect(r.volumeMl, closeTo(3.75, 0.01));
    });

    test('фикс B-3 (диапазон) жив: середина диапазона, не fallback', () {
      final r = byId(480).calculateDose(500, 'КРС');
      // КРС идёт по мл/кг-ветке вида — регрессии нет
      expect(r.volumeMl, closeTo(50, 0.01));
    });
  });
}
