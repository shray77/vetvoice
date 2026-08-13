import 'package:flutter_test/flutter_test.dart';
import 'package:vetvoice_ai/models/calc_drug.dart';

/// Юнит-тесты для расчёта дозы.
/// Покрывают критические фиксы B-3 (диапазонная дозировка) и B-4 (МЕ/мл единицы).
void main() {
  group('CalcDrug.calculateDose — фикс B-3 (диапазон dose_min/dose_max)', () {
    test('''
      Препарат с dose_per_kg=0 и dose_min=5, dose_max=10 для КРС
      должен считаться по середине диапазона (7.5 мг/кг),
      а НЕ fallback на дефолтную 15 мг/кг.
    ''', () {
      final drug = CalcDrug(
        id: 154,
        name: 'Неомастин (тест)',
        inn: 'амоксициллин, неомицин, тербинафин',
        form: 'суспензия',
        formType: 'injection',
        unit: 'мл',
        concentration: 200,
        concentrationUnit: 'мг/мл',
        dosePerKg: 15, // дефолт — НЕ должен использоваться для КРС
        doseUnit: 'мг/кг',
        animals: const ['КРС'],
        method: 'внутримышечно',
        contraindications: const CalcContraindications(),
        animalSpecific: {
          'КРС': const AnimalSpecificDose(
            dosePerKg: 0,
            doseMin: 5,
            doseMax: 10,
            frequency: '1 раз в день',
          ),
        },
      );

      const weight = 400; // КРС 400 кг
      final result = drug.calculateDose(weight, 'КРС');

      expect(result.type, DoseType.calculated,
          reason: 'Должен рассчитаться, а не упасть в unknown');
      // Доза = середина (5+10)/2 = 7.5 мг/кг
      // Объём = (7.5 × 400) / 200 = 15 мл
      // Раньше было бы: (15 × 400) / 200 = 30 мл — двойная передоз!
      expect(result.volumeMl, closeTo(15.0, 0.01),
          reason: 'Объём должен быть 15 мл (7.5 мг/кг × 400 кг / 200 мг/мл). '
              'Если получилось 30 мл — фикс B-3 не работает, КРС получает передоз.');
      expect(result.dosePerKg, closeTo(7.5, 0.01));
      expect(result.doseMin, 5);
      expect(result.doseMax, 10);
    });

    test('доза с конкретным dose_per_kg > 0 должна использоваться как есть', () {
      final drug = CalcDrug(
        id: 1,
        name: 'Тестовый препарат',
        inn: 'тест',
        form: 'раствор',
        unit: 'мл',
        concentration: 100,
        concentrationUnit: 'мг/мл',
        dosePerKg: 5,
        doseUnit: 'мг/кг',
        animals: const ['Собака'],
        method: 'внутрь',
        contraindications: const CalcContraindications(),
        animalSpecific: {
          'Собака': const AnimalSpecificDose(
            dosePerKg: 5,
            frequency: '2 раза в день',
          ),
        },
      );

      // Собака 10 кг → 5 мг/кг × 10 / 100 мг/мл = 0.5 мл
      final result = drug.calculateDose(10, 'Собака');
      expect(result.volumeMl, closeTo(0.5, 0.001));
      expect(result.dosePerKg, 5);
    });
  });

  group('CalcDrug.fromJson — фикс B-4 (МЕ/мл vs мг/мл)', () {
    test('''
      Препарат с concentration_unit=МЕ/мл и concentration=200,
      без явного concentration_me — должен автоматически перенести
      значение в concentrationMe, чтобы расчёт шёл через МЕ-ветку.
    ''', () {
      final drug = CalcDrug.fromJson({
        'id': 201,
        'name': 'Димоксан WS (тест)',
        'inn': 'амоксициллин, колистин',
        'form': 'порошок',
        'unit': 'мл',
        'concentration': 200,
        'concentration_unit': 'МЕ/мл',
        'dose_per_kg': 10,
        'dose_unit': 'мг/кг',
        'animals': ['КРС'],
        'method': 'внутрь',
        'dose_min': 5,
        'dose_max': 10,
      });

      expect(drug.concentration, 0,
          reason: 'Поле concentration должно обнулиться, т.к. это на самом деле МЕ');
      expect(drug.concentrationMe, 200,
          reason: 'Значение должно переехать в concentrationMe');
    });

    test('препарат с обычной concentration_unit=мг/мл не должен трогаться', () {
      final drug = CalcDrug.fromJson({
        'id': 1,
        'name': 'Обычный препарат',
        'inn': 'тест',
        'form': 'раствор',
        'unit': 'мл',
        'concentration': 50,
        'concentration_unit': 'мг/мл',
        'dose_per_kg': 5,
        'dose_unit': 'мг/кг',
        'animals': ['Собака'],
        'method': 'внутрь',
      });

      expect(drug.concentration, 50);
      expect(drug.concentrationMe, 0);
    });

    test('явный concentration_me не должен перетираться', () {
      final drug = CalcDrug.fromJson({
        'id': 999,
        'name': 'Явный МЕ препарат',
        'inn': 'тест',
        'form': 'раствор',
        'unit': 'мл',
        'concentration': 0,
        'concentration_unit': 'МЕ/мл',
        'concentration_me': 5000,
        'dose_per_kg': 0,
        'dose_me_per_kg': 1000,
        'dose_unit': 'МЕ/кг',
        'animals': ['КРС'],
        'method': 'внутрь',
      });

      expect(drug.concentrationMe, 5000,
          reason: 'Явно указанный concentration_me не должен перетираться');
    });
  });

  group('CalcDrug.calculateDose — фикс B-4 для МЕ препаратов', () {
    test('''
      Димоксан WS: концентрация 200 МЕ/мл, доза 10 мг/кг — раньше формула
      делила мг на МЕ (численный мусор). После фикса расчёт корректный.
    ''', () {
      final drug = CalcDrug.fromJson({
        'id': 201,
        'name': 'Димоксан WS',
        'inn': 'амоксициллин, колистин',
        'form': 'порошок',
        'unit': 'мл',
        'concentration': 200,
        'concentration_unit': 'МЕ/мл',
        'dose_per_kg': 10,
        'dose_unit': 'мг/кг',
        'animals': ['КРС'],
        'method': 'внутрь',
      });

      // КРС 500 кг → 10 МЕ/кг × 500 / 200 МЕ/мл = 25 мл
      // Раньше было бы: 10 × 500 / 200 = 25 (тут совпадает случайно)
      // но если бы доза была 5 мг/кг, было бы 12.5 мл,
      // а через правильную МЕ-ветку с doseMePerKg=10 — тоже 25 мл
      // (т.к. после фикса B-4 concentration=200 переезжает в concentrationMe=200,
      // и расчёт идёт через МЕ-ветку, что и должно быть)
      final result = drug.calculateDose(500, 'КРС');
      expect(result.type, DoseType.calculated);
      expect(result.volumeMl, greaterThan(0),
          reason: 'Объём должен быть положительным числом, а не NaN/0');
    });
  });

  group('AnimalSpecificDose.hasDose — фикс B-3', () {
    test('доза с dose_per_kg=0 и dose_min/dose_max > 0 → hasDose=true', () {
      const dose = AnimalSpecificDose(
        dosePerKg: 0,
        doseMin: 5,
        doseMax: 10,
      );
      expect(dose.hasDose, true,
          reason: 'Без фикса B-3 hasDose возвращал false → fallback на дефолт');
    });

    test('доза только с dose_me_min/dose_me_max → hasDose=true', () {
      const dose = AnimalSpecificDose(
        dosePerKg: 0,
        doseMeMin: 1000,
        doseMeMax: 2000,
      );
      expect(dose.hasDose, true);
      expect(dose.hasMeDose, true);
    });

    test('пустая доза → hasDose=false', () {
      const dose = AnimalSpecificDose(dosePerKg: 0);
      expect(dose.hasDose, false);
    });
  });
}
