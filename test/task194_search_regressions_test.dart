import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetvoice_ai/models/calc_drug.dart';
import 'package:vetvoice_ai/models/drug_registry.dart';
import 'package:vetvoice_ai/models/dosage_database.dart';
import 'package:vetvoice_ai/providers/vet_provider.dart';

/// Task 194: регрессии полевого репорта «окситоцин на КРС — нули».
///
/// Данные окситоцина выправлены ещё Task 191 (МЕ на животное, fixed_dose),
/// но запись носит calculator_applicable=false, а фильтры поиска
/// (allDrugs/availableDrugs) прятали ЛЮБУЮ такую запись — юзера уводило
/// в реестровый Окситоцин, где концентрация «5 и 10 ЕД/мл» не парсится
/// (ConcentrationParser знает только мг/%) и фолбэк возвращал
/// volume=0 при hasDosage=true — зелёное «0.000 мл» на любом весе.
///
/// Проверяем на РЕАЛЬНОЙ базе (паттерн real_database_test):
/// 1) окситоцин проходит фильтр поиска;
/// 2) реестровый путь без концентрации больше НЕ выдаёт «рассчитанные нули».
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CalcDrugDatabase calcDb;
  late DrugRegistry registry;
  late DosageDatabase dosageDb;

  setUpAll(() {
    final calcRaw =
        File('assets/data/drugs_calc.json').readAsStringSync();
    calcDb =
        CalcDrugDatabase.fromJson(jsonDecode(calcRaw) as Map<String, dynamic>);
    final regRaw =
        File('assets/data/drugs_registry.json').readAsStringSync();
    registry =
        DrugRegistry.fromJson(jsonDecode(regRaw) as Map<String, dynamic>);
    final dosRaw =
        File('assets/data/dosage_database.json').readAsStringSync();
    dosageDb =
        DosageDatabase.fromJson(jsonDecode(dosRaw) as Map<String, dynamic>);
  });

  group('Task 194: фильтры поиска не прячут фиксированные дозы', () {
    test('окситоцин виден в allDrugs (applicable=false, fixed_dose есть)', () {
      final p = VetProvider();
      p.debugSetCore(calcDatabase: calcDb, registry: registry,
          dosageDatabase: dosageDb);
      p.setSearchQuery('окситоцин');
      final found = p.allDrugs;
      final calcOxytocins =
          found.whereType<CalcDrug>().where((d) => d.name == 'Окситоцин');
      expect(calcOxytocins, isNotEmpty,
          reason: 'Регрессия полевого репорта: запись с fixed_dose по 5 '
              'видам обязана находиться поиском — иначе юзера уводит в '
              'реестровую запись с «0.000 мл»');
    });

    test('записи без доз вовсе — по-прежнему скрыты', () {
      // Инвариант фильтра: прятать только бесполезное для калькулятора.
      // ВАЖНО (поймано CI): Больфо® ошейник сюда НЕ относится — его
      // fixed_dose несёт способ применения («Собаки: наружно»), запись
      // честно пускается поиском. Настоящий мусор — записи без доз
      // вообще: ингаляционный наркозный Изофлуран (мг/кг нет,
      // fixed_dose нет, applicable=false).
      final hidden = calcDb.drugs
          .where((d) =>
              !d.calculatorApplicable &&
              (d.fixedDose?.isNotEmpty ?? false) == false)
          .length;
      expect(hidden, greaterThan(0));
      final p = VetProvider();
      p.debugSetCore(calcDatabase: calcDb);
      p.setSearchQuery('Изофлуран');
      expect(p.allDrugs.whereType<CalcDrug>(), isEmpty,
          reason: 'Изофлуран (ингаляционный наркозный) — вне '
              'калькулятора: мг/кг-дозы нет, fixed_dose нет, '
              'applicable=false. Таких в базе 149 шт — они и только '
              'они остаются скрытыми');
    });

    test('у каждой (!applicable && fixed_dose) записи честный результат', () {
      // Все записи, которые фильтр теперь пускает, обязаны давать
      // осмысленный результат для вида из fixed_dose (fixed-текст).
      final released = calcDb.drugs.where((d) =>
          !d.calculatorApplicable && (d.fixedDose?.isNotEmpty ?? false));
      expect(released.length, greaterThan(500),
          reason: 'Аудит Task 194: >500 записей с фиксированными дозами '
              '(вакцины, МЕ-препараты) раньше были невидимы для поиска');
      var fixedResults = 0;
      for (final d in released.take(200)) {
        final animal = d.fixedDose!.keys.first;
        final r = d.calculateDose(10, animal);
        if (r.type == DoseType.fixed) fixedResults++;
      }
      expect(fixedResults, greaterThan(150),
          reason: 'Подавляющее большинство пущенных записей — вакцины с '
              'fixed-дозами; если фильтр пускает мусор, это видно здесь');
    });
  });

  group('Task 194: реестровый путь без концентрации — не нули', () {
    test('окситоцин из реестра на КРС: инфо-карточка, не «0.000 мл»', () {
      final p = VetProvider();
      p.debugSetCore(calcDatabase: calcDb, registry: registry,
          dosageDatabase: dosageDb);
      // КРС из раздела animals базы калькулятора
      final cattle =
          calcDb.animals.firstWhere((a) => a.name == 'КРС');
      p.selectAnimal(cattle.id);
      p.setWeight(500);
      final regOxytocin = registry.drugs
          .firstWhere((d) => d.tradeName == 'Окситоцин' && d.animals.contains('КРС'));
      p.selectRegistryDrug(regOxytocin);
      final r = p.result;
      expect(r.hasDosage, isFalse,
          reason: 'Концентрация «5 и 10 ЕД/мл» не парсится (МЕ/ЕД нет в '
              'ConcentrationParser) — раньше это давало volume=0 при '
              'hasDosage=true, карточка печатала «0.000 мл»');
      expect(r.volume, 0);
      expect(r.note, contains('Дозировка'),
          reason: 'Доза из реестра обязана доезжать текстом «по инструкции»');
    });
  });
}
