import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetvoice_ai/models/calc_drug.dart';

/// Юнит-гейт на РЕАЛЬНОЙ базе (Task 183, фиксы S-1/S-2).
///
/// До Task 183 ни один тест не грузил реальный assets/data/drugs_calc.json —
/// юниты были синтетическими, и два медицинских бага жили в рантайме
/// незаметно для CI (55/55 зелёных при фактически дырявой базе):
///
/// S-1 — толерантный парсинг: concentration бывает СТРОКОЙ («5 МЕ, 10 МЕ»,
/// «6 000 000 МЕ; 12 000 000 МЕ», «10 г», «#####» — 218 записей), а
/// contraindications.warnings бывает строкой вместо списка (ещё 233).
/// Жёсткие касты кидали TypeError, per-item catch глотал запись ЦЕЛИКОМ:
/// 440 из 2401 препаратов (18 %) молча отсутствовали в приложении —
/// включая Окситоцин, Канинсулин, Гепарин, Катозал, Фоллимаг.
///
/// S-2 — объёмные дозы: мл/кг — это уже объём на килограмм, делить его
/// на концентрацию нельзя. Раньше ветка «(доза × вес) / концентрация»
/// стояла выше объёмной: натрия хлорид 0.9% корове 500 кг давал «5.6 мл»
/// вместо 50 (×9 занижение инфузии), Кофеин-бензоат 20% — ×200,
/// Гамавит с мусорной концентрацией 0.02 мг/мл — 250 мл вместо 5 (×50,
/// передоз).
void main() {
  late CalcDrugDatabase db;

  setUpAll(() {
    final raw = File('assets/data/drugs_calc.json').readAsStringSync();
    db = CalcDrugDatabase.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  });

  CalcDrug byName(String name) => db.drugs.firstWhere((d) => d.name == name);

  group('S-1: реальная база парсится ЦЕЛИКОМ', () {
    test('2401/2401 записей — потери 0', () {
      expect(db.drugs.length, 2401,
          reason: 'Каждая запись drugs_calc.json обязана доходить до '
              'калькулятора. Потеря записи = «тихая ерунда» (класс Task 178): '
              'приложение не падает, препарат просто отсутствует. Аудит '
              'Task 183 насчитал 440 молча выброшенных (218 concentration-'
              'строк + 233 warnings-строки − 11 пересечений).');
    });

    test('Окситоцин не потерян: строковая концентрация → текст, не расчёт', () {
      final oxytocin = byName('Окситоцин');
      expect(oxytocin.concentrationText, '5 МЕ, 10 МЕ',
          reason: 'Сырая строка концентрации сохраняется для отображения');
      expect(oxytocin.concentration, 0,
          reason: '«5 МЕ, 10 МЕ» — не числовая концентрация для расчёта');
      // Явное МЕ-поле при этом живо (перенос B-4 его не трогает)
      expect(oxytocin.concentrationMe, 10.0);
      // Task 191: дозы окситоцина — МЕ НА ЖИВОТНОЕ (медвет.рф: коровы в/м
      // 30±10 МЕ/гол, свиноматки 20) — юнит «мг/кг» врали, калькулятор
      // умножал ЕД на вес. Парадигма fixed (как Триспазвит в Task 187):
      // калькулятору нечего считать — честная инструкция «МЕ на животное»
      final r = oxytocin.calculateDose(500, 'КРС');
      expect(r.type, DoseType.fixed,
          reason: 'окситоцин дозируется в МЕ на животное, не мг/кг');
      expect(r.volumeMl, 0);
      expect(oxytocin.calculatorApplicable, isFalse);
      expect(oxytocin.fixedDose?['КРС'], contains('30-50 МЕ'));
    });

    test('Канинсулин, Гепарин и Катозал парсятся (инсулин/антикоагулянт)', () {
      // Ключевые медицинские препараты из списка 440 потерь аудита.
      expect(db.drugs.any((d) => d.name == 'Канинсулин'), isTrue,
          reason: 'Инсулин не имеет права молча исчезать из справочника');
      expect(db.drugs.any((d) => d.name == 'Гепарин натрия-ЭНДОФАРМ'), isTrue);
      expect(db.drugs.any((d) => d.name == 'Катозал®'), isTrue);
    });

    test('warnings-строка становится списком из одного предупреждения', () {
      final florforte = byName('Флорфорте');
      expect(florforte.contraindications.warnings, hasLength(1),
          reason: 'Строка «КАТЕГОРИЧЕСКИ ЗАПРЕЩЁН ЛОШАДЯМ…» — одно '
              'предупреждение целиком, не пустой список и не потеря записи');
      expect(florforte.contraindications.warnings.first, contains('ЛОШАДЯМ'),
          reason: 'Критическое предупреждение обязано доезжать до врача');
    });
  });

  group('S-2: объёмная доза (мл/кг) не делится на концентрацию', () {
    test('Натрия хлорид 0.9%: корова 500 кг → 50 мл (не 5.6)', () {
      // «Натрия хлорид АРМ»: 0.1 мл/кг для КРС, concentration 9 мг/мл.
      final nacl = byName('Натрия хлорид АРМ');
      final r = nacl.calculateDose(500, 'КРС');
      expect(r.type, DoseType.calculated);
      expect(r.volumeMl, closeTo(50.0, 0.01),
          reason: '0.1 мл/кг × 500 кг = 50 мл. Старая ветка делила на '
              'концентрацию 9 мг/мл и давала 5.6 мл — ×9 занижение объёма '
              'инфузии.');
    });

    test('Гамавит: собака 10 кг → 5 мл (не 250)', () {
      // «Гамавит»: 0.5 мл/кг для собак, мусорная concentration 0.02 мг/мл.
      final gamavit = byName('Гамавит');
      final r = gamavit.calculateDose(10, 'Собаки');
      expect(r.type, DoseType.calculated);
      expect(r.volumeMl, closeTo(5.0, 0.01),
          reason: '0.5 мл/кг × 10 кг = 5 мл. Старая ветка делила на '
              'мусорную концентрацию 0.02 мг/мл и давала 250 мл — '
              '×50 завышение (передоз).');
    });

    test('Раствор Рингера-Локка: корова 500 кг → 100 мл (не 11)', () {
      // КРС: 0.2 мл/кг (animal_specific), концентрация 9 мг/мл.
      final ringer = byName('Раствор Рингера-Локка');
      final r = ringer.calculateDose(500, 'КРС');
      expect(r.type, DoseType.calculated);
      expect(r.volumeMl, closeTo(100.0, 0.01));
    });

    test('Кофеин-бензоат 20%: мг/кг через концентрацию (Task 185 выправил юнит)', () {
      final caffeine = byName('Кофеин-бензоат натрия 20% раствор для инъекций');
      final r = caffeine.calculateDose(500, 'КРС');
      // Task 185: «10 мл/кг КРС» (4.5 л в/в!) исправлено на мг/кг —
      // 10 мг/кг × 500 кг / 200 мг/мл = 25 мл. Тест писался под старые
      // мл/кг-данные (ожидал 5000) — парадигма данных сменилась осознанно.
      expect(r.type, DoseType.calculated);
      expect(r.volumeMl, closeTo(25.0, 0.01));
    });

    test('Кальция борглюконат: корова 500 кг → 500 мл (не 5)', () {
      final borgluconate = byName('Кальция борглюконат');
      final r = borgluconate.calculateDose(500, 'КРС'); // 1 мл/кг, conc 100
      expect(r.type, DoseType.calculated);
      expect(r.volumeMl, closeTo(500.0, 0.01));
    });

    test('КОНТРОЛЬ: массовая доза (мг/кг) по-прежнему делится на концентрацию',
        () {
      // «Марбофлоксацин 10%»: КРС 2 мг/кг, concentration 100 мг/мл:
      // (2 × 500) / 100 = 10 мл — классический путь не сломан фиксами.
      final marbofloxacin = byName('Марбофлоксацин 10%');
      final r = marbofloxacin.calculateDose(500, 'КРС');
      expect(r.type, DoseType.calculated);
      expect(r.volumeMl, closeTo(10.0, 0.01));
    });

    test('запись-смешение юнитов не даёт мусорного объёма', () {
      // «Триспазвит»: до Task 187 топовая доза мл/кг, а доза Собак — МЕ/кг
      // (запись-смешение xlsx-конверта «30000 МЕ; 40000 МЕ; 20 мг») — B-4
      // возвращал честный unknown. Task 187 закрыл класс иначе: комплексные
      // витаминные с неразложимой conc — парадигма «на животное по
      // инструкции» (dose_unit fixed + calculator_applicable false), доза
      // МЕ-смешения снесена. Калькулятору нечего считать — и он честно
      // показывает инструкцию, а не мусорный объём.
      final trispavit = byName('Триспазвит');
      final r = trispavit.calculateDose(10, 'Собаки');
      expect(r.type, DoseType.fixed,
          reason: 'Task 187: комплексный витаминный состав — дозирование '
              'на животное по инструкции, числовой объём не существует');
      expect(r.volumeMl, 0);
      expect(trispavit.calculatorApplicable, isFalse,
          reason: 'мусорная conc-строка не должна попадать в расчётный путь');
    });
  });
}
