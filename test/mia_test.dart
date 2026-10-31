import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetvoice_ai/models/calc_drug.dart';
import 'package:vetvoice_ai/models/mia.dart';

/// Идея №4: юнит-гейт WHO MIA (stewardship-слой поверх базы ветвойс).
///
/// Тестирует ТРИ слоя:
///   1. Таблица классов (mia_classes.json) — полнота и официальный порядок
///      категорий издания ВОЗ 2024;
///   2. Сгенерированный слой решений (mia_drugs.json) — известные препараты
///      дают ожидаемые классы/категории (энрофлоксацин → HPCIA, колистин →
///      HPCIA, тиамулин → IA, авиламицин → вне медицины человека...);
///   3. Зеркало гейта scripts/mia_gate.py: КАЖДЫЙ антибактериальный из 638
///      получает класс или явный out_of_scope — иначе красный CI.
///
/// Конвенция «машина напоминает, человек решает»: плашка — не запрет,
/// поэтому тесты проверяют данные, а не клинические решения.
void main() {
  late MiaDatabase mia;
  late CalcDrugDatabase db;

  setUpAll(() {
    final classesRaw =
        File('assets/data/mia_classes.json').readAsStringSync();
    final drugsRaw = File('assets/data/mia_drugs.json').readAsStringSync();
    final map =
        MiaDrugMap.fromJson(jsonDecode(drugsRaw) as Map<String, dynamic>);
    mia = MiaDatabase.fromJson(
            jsonDecode(classesRaw) as Map<String, dynamic>)
        .withDrugMap(map);
    db = CalcDrugDatabase.fromJson(
        jsonDecode(File('assets/data/drugs_calc.json').readAsStringSync())
            as Map<String, dynamic>);
  });

  CalcDrug byName(String name) => db.drugs.firstWhere((d) => d.name == name);

  group('Таблица классов WHO MIA 2024', () {
    test('33 класса официального списка, id уникальны', () {
      expect(mia.classes.length, 33,
          reason: 'Таблицы 2-4 ВОЗ 2024: 24 класса «людям и животным» + '
              '8 «не разрешены у людей» + нитроксолиновый класс «только у '
              'людей». Сокращение = молчаливая потеря классификации.');
      expect(mia.classes.keys.toSet().length, mia.classes.length);
    });

    test('все шесть официальных категорий присутствуют', () {
      for (final id in ['humans_only', 'hp', 'cia', 'hia', 'ia', 'nmi']) {
        expect(mia.categories.containsKey(id), isTrue,
            reason: 'категория $id обязательна');
      }
    });

    test('ранги важности упорядочены: humans_only > hp > cia > hia > ia > nmi',
        () {
      final r = (String id) => mia.categories[id]!.rank;
      expect(r('humans_only'), greaterThan(r('hp')));
      expect(r('hp'), greaterThan(r('cia')));
      expect(r('cia'), greaterThan(r('hia')));
      expect(r('hia'), greaterThan(r('ia')));
      expect(r('ia'), greaterThan(r('nmi')));
    });

    test('у каждого класса непустой stewardship-совет', () {
      for (final c in mia.classes.values) {
        expect(c.stewardship.isNotEmpty, isTrue,
            reason: 'класс ${c.id}: пустой совет бессмыслен для плашки');
      }
    });
  });

  group('Известные препараты → классы ( mia_drugs.json )', () {
    test('Энроксил (энрофлоксацин) → хинолоны, HPCIA', () {
      final info = mia.resolve(byName('Энроксил® 10% раствор для инъекций').id);
      expect(info, isNotNull);
      expect(info!.classes.map((c) => c.id), contains('quinolones'));
      expect(info.worstCategory!.id, 'hp',
          reason: 'фторхинолоны — HPCIA по ВОЗ 2024');
    });

    test('Полимиксин 6 млн (колистин) → полимиксины, HPCIA', () {
      final info = mia.resolve(byName('Полимиксин 6 млн. МЕ и 12 млн. МЕ').id);
      expect(info, isNotNull);
      expect(info!.classes.map((c) => c.id), contains('polymyxins'));
      expect(info.worstCategory!.id, 'hp',
          reason: 'колистин — последняя линия у людей, mcr-гены идут по '
              'пищевой цепи');
    });

    test('Грануламокс (амоксициллин) → аминопенициллины, HIA (понижен в 2024)',
        () {
      final info = mia.resolve(byName('Грануламокс').id);
      expect(info, isNotNull);
      expect(info!.classes.map((c) => c.id), contains('pen_amino'));
      expect(info.worstCategory!.id, 'hia',
          reason: 'аминопенициллины понижены из CIA в HIA в издании 2024');
    });

    test('НаноТим (тиамулин) → плевромутилины, IA', () {
      final info = mia.resolve(byName('НаноТим').id);
      expect(info, isNotNull);
      expect(info!.classes.map((c) => c.id), contains('pleuromutilins'));
      expect(info.worstCategory!.id, 'ia');
    });

    test('Авиламакс (авиламицин) → ортозомицины, вне медицины человека', () {
      final info = mia.resolve(byName('Авиламакс').id);
      expect(info, isNotNull);
      expect(info!.classes.map((c) => c.id), contains('orthosomycins'));
      expect(info.worstCategory!.id, 'nmi',
          reason: 'кормовой ортозомицин без человеческого аналога (табл. 4)');
    });

    test('МониГран (монензин) → ионофоры, вне медицины человека', () {
      final info = mia.resolve(byName('МониГран').id);
      expect(info, isNotNull);
      expect(info!.classes.map((c) => c.id), contains('ionophores'));
      expect(info.worstCategory!.id, 'nmi');
    });

    test('Стоп-цистит (нитроксолин) → класс только для людей', () {
      final info =
          mia.resolve(byName('Стоп-цистит® таблетки').id);
      expect(info, isNotNull);
      expect(info!.classes.map((c) => c.id),
          contains('hydroxy_nitroquinolines'));
      expect(info.worstCategory!.id, 'humans_only',
          reason: 'по таблице 2 ВОЗ 2024 класс разрешён только у людей');
    });

    test('Гамарет (новобиоцин+пенициллин+неомицин+дигидрострептомицин) — '
        'три класса, худший CIA', () {
      final info =
          mia.resolve(byName('Гамарет интрамаммарная суспензия').id);
      expect(info, isNotNull);
      expect(info!.classes.map((c) => c.id),
          containsAll(['aminocoumarins', 'pen_narrow', 'aminoglycosides']));
      expect(info.worstCategory!.id, 'cia',
          reason: 'аминогликозиды (CIA) важнее пенициллинов (HIA) и '
              'аминокумаринов (вне медицины человека)');
    });

    test('Стоморджил (спирамицин+метронидазол) — кросс-категория: плашка и '
        'на противопаразитарных', () {
      final info = mia.resolve(byName('Стоморджил 2, 10, 20').id);
      expect(info, isNotNull);
      expect(info!.classes.map((c) => c.id),
          containsAll(['macrolides', 'nitroimidazoles']));
      expect(info.worstCategory!.id, 'cia');
    });

    test('Левомеколь-вет (левомицетин=хлорамфеникол) → амфениколы, HIA', () {
      final info = mia.resolve(byName('Мазь "Левомеколь-вет"').id);
      expect(info, isNotNull);
      expect(info!.classes.map((c) => c.id), contains('amphenicols'));
      expect(info.worstCategory!.id, 'hia');
    });

    test('Шампунь хлоргексидиновый (антибактериальные) → явный out_of_scope',
        () {
      final info = mia.resolve(byName(
              'Шампунь хлоргексидиновый с антибактериальным эффектом для животных')
          .id);
      expect(info, isNotNull);
      expect(info!.isOutOfScope, isTrue,
          reason: 'антисептик честно помечен вне классификации, а не '
              'молчаливо пропущен');
      expect(info.outOfScope.first, contains('антисептик'));
    });

    test('Мариния (маропитант, НПВС) → нет MIA-слоя, плашки не будет', () {
      expect(mia.resolve(byName('Мариния®').id), isNull);
    });
  });

  group('Зеркало гейта: покрытие реальной базы', () {
    test('у каждого антибактериального (638) есть класс или out_of_scope', () {
      final antibacterial =
          db.drugs.where((d) => d.category == 'Антибактериальные').toList();
      expect(antibacterial.length, 638);
      final unresolved = <String>[];
      for (final d in antibacterial) {
        final info = mia.resolve(d.id);
        if (info == null || (!info.hasClasses && !info.isOutOfScope)) {
          unresolved.add('${d.name} (inn=${d.inn})');
        }
      }
      expect(unresolved, isEmpty,
          reason: 'Гейт покрытия (идея №4): антибактериальный без класса '
              'MIA = красный CI. Не решены: ${unresolved.take(5).join(', ')}');
    });

    test('слой не пуст и ссылается только на классы таблицы', () {
      final raw = jsonDecode(File('assets/data/mia_drugs.json')
          .readAsStringSync()) as Map<String, dynamic>;
      final drugs = raw['drugs'] as Map<String, dynamic>;
      expect(drugs.length, greaterThan(700),
          reason: '638 антибактериальных + кросс-категорийные '
              '(Стоморджил, МониГран, Левомеколь и др.)');
      for (final entry in drugs.values) {
        for (final cid in (entry as Map<String, dynamic>)['c'] ?? []) {
          expect(mia.classes.containsKey(cid as String), isTrue,
              reason: 'mia_drugs.json ссылается на неизвестный класс $cid — '
                  'таблица и слой рассинхронизированы');
        }
      }
    });
  });
}
