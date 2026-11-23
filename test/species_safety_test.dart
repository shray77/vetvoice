import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetvoice_ai/models/calc_drug.dart';
import 'package:vetvoice_ai/models/drug.dart';
import 'package:vetvoice_ai/models/side_effects.dart';
import 'package:vetvoice_ai/providers/vet_provider.dart';
import 'package:vetvoice_ai/utils/species_safety.dart';

/// Task 230 (2026-11-24): видовая привязка побочек/предупреждений.
///
/// Паттерн real_database_test: юниты на РЕАЛЬНОЙ базе (1522 из 2401
/// препаратов несут видоспецифичный текст в общих полях). Матрица:
/// «Запрещено для кроликов» не показывается КРС, «ЛАМИНИТ у лошадей!»
/// не показывается корове, «щенки/котята» — только своим видам,
/// unsupported-виды (морские свинки) скрываются у всех 10 видов.
void main() {
  late CalcDrugDatabase db;

  setUpAll(() {
    final raw = File('assets/data/drugs_calc.json').readAsStringSync();
    db = CalcDrugDatabase.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  });

  CalcDrug byId(int id) => db.drugs.firstWhere((d) => d.id == id);
  CalcDrug byName(String name) => db.drugs.firstWhere((d) => d.name == name);

  group('SpeciesSafetyFilter: словарь word-aware', () {
    test('ложных срабатываний нет: аминогликозид ≠ МРС, курс ≠ Птица', () {
      // «Не применять одновременно с аминогликозидами» — 58 строк базы
      // с голым substring-стемом «коз» tagged МРС ложно.
      expect(
          SpeciesSafetyFilter.mentionedSpecies(
              'Не применять одновременно с аминогликозидами'),
          isEmpty);
      expect(SpeciesSafetyFilter.mentionedSpecies('Курс лечения 5 дней'),
          isEmpty);
      expect(SpeciesSafetyFilter.mentionedSpecies('Длительность курса'), isEmpty);
    });

    test('«свинцовых отравлениях» — не Свиньи (металл ≠ вид, #919)', () {
      expect(
          SpeciesSafetyFilter.mentionedSpecies(
              'Запрещено при свинцовых отравлениях'),
          isEmpty);
    });

    test('«свинк»-омоним: ремонтные свинки = Свиньи, морские = нет', () {
      // 5 из 7 «свинк» в базе — «ремонтным свинкам» (молодые свиноматки),
      // 2 — «морских свинках». Дифференциатор — «морск» в тексте.
      expect(
          SpeciesSafetyFilter.mentionedSpecies(
              'Не применять ремонтным свинкам'),
          contains('Свиньи'));
      expect(
          SpeciesSafetyFilter.mentionedSpecies(
              'Противопоказано кроликам, морским свинкам и хомякам'),
          isNot(contains('Свиньи')));
    });

    test('«жвачным с рубцовым пищеварением» — КРС И МРС (#40 базы)', () {
      // 44+33 вхождения «жвачн»/«рубц» — взрослые жвачные = коровы И овцы
      // с козами. Стем только у МРС прятал бы эти запреты от коров.
      const t = 'Запрещается применение взрослым жвачным животным '
          'с развитым рубцовым пищеварением';
      final m = SpeciesSafetyFilter.mentionedSpecies(t);
      expect(m, containsAll(['КРС', 'МРС']));
      expect(SpeciesSafetyFilter.isRelevant(t, 'КРС'), isTrue);
      expect(SpeciesSafetyFilter.isRelevant(t, 'МРС'), isTrue);
      expect(SpeciesSafetyFilter.isRelevant(t, 'Собаки'), isFalse);
    });

    test('точные словоформы: козам/курам-несушкам/беременных сук', () {
      expect(SpeciesSafetyFilter.mentionedSpecies('Не применять козам'),
          contains('МРС'));
      expect(
          SpeciesSafetyFilter.mentionedSpecies(
              'Запрещается применение курам-несушкам'),
          contains('Птица'));
      expect(
          SpeciesSafetyFilter.mentionedSpecies(
              'Запрещено иммунизировать беременных сук'),
          contains('Собаки'));
    });

    test('sentence-фильтр: чужие виды режутся, свои и безвидовые остаются', () {
      final f = SpeciesSafetyFilter.filterTextForAnimal(
          'Повышенная чувствительность к фторхинолонам. '
          'Щенки до 12 месяцев (крупные породы до 18 месяцев). '
          'Котята до 8 недель.',
          'КРС');
      expect(f, contains('фторхинолонам'));
      expect(f, isNot(contains('Щенки')));
      expect(f, isNot(contains('Котята')));
    });

    test('unsupported-виды скрываются у всех 10, кролики — кроликам', () {
      const t = 'Запрещено для кроликов, морских свинок, хомяков';
      for (final a in SpeciesSafetyFilter.supportedSpecies) {
        if (a == 'Кролики') continue;
        expect(SpeciesSafetyFilter.isRelevant(t, a), isFalse,
            reason: 'вид $a не должен видеть запрет для кроликов');
      }
      expect(SpeciesSafetyFilter.isRelevant(t, 'Кролики'), isTrue);
    });

    test('вид вне справочника — фильтр не режет (консервативно)', () {
      const t = 'Противопоказан экзотическим животным';
      expect(SpeciesSafetyFilter.filterTextForAnimal(t, ''), t);
    });
  });

  group('реальная база: видовая матрица', () {
    test('#975 Амоксициллин 15% ЛА: кролики — только Кроликам', () {
      final d = byId(975);
      final cattle =
          d.contraindications.getWarningsForAnimal('КРС').join(' ');
      expect(cattle, isNot(contains('кролик')));
      expect(cattle, isNot(contains('морских свинок')));
      // Регрессия CI-фейла: «морских свинок» (беглая гласная: свинк-а →
      // свин-ок) не должны матчиться как Свиньи — свиньям этот запрет
      // про декоративных грызунов не показывается.
      final pig =
          d.contraindications.getWarningsForAnimal('Свиньи').join(' ');
      expect(pig, isNot(contains('морских свинок')));
      final rabbit =
          d.contraindications.getWarningsForAnimal('Кролики').join(' ');
      expect(rabbit, contains('кролик'));
    });

    test('#814 Прималакт: «ЛАМИНИТ у лошадей» — только Лошадям', () {
      final d = byId(814);
      final cattle = d.getSideEffectsForAnimal('КРС').join(' ');
      expect(cattle, isNot(contains('ЛАМИНИТ')));
      final horse = d.getSideEffectsForAnimal('Лошади').join(' ');
      expect(horse, contains('ЛАМИНИТ'));
    });

    test('#929 Мастиет Форте: «ЛАМИНИТ у лошадей» не показывается КРС', () {
      final d = byId(929);
      final cattle = d.getSideEffectsForAnimal('КРС').join(' ');
      expect(cattle, isNot(contains('ЛАМИНИТ')));
      final horse = d.getSideEffectsForAnimal('Лошади').join(' ');
      expect(horse, contains('ЛАМИНИТ'));
    });

    test('#15 Марбофлоксацин 10%: щенки/котята — только своим видам', () {
      final d = byId(15);
      final cattle =
          d.contraindications.getWarningsForAnimal('КРС').join(' ');
      expect(cattle, isNot(contains('Щенки')));
      expect(cattle, isNot(contains('Котята')));
      expect(cattle, contains('лактации для видов: КРС, Свиньи'),
          reason: 'беременность/лактация для КРС в списке — остаётся видимой');

      final dog = d.contraindications.getWarningsForAnimal('Собаки').join(' ');
      expect(dog, contains('Щенки'));
      expect(dog, isNot(contains('Котята')));
      expect(dog, isNot(contains('для видов: КРС, Свиньи')),
          reason: 'беременность/лактация только для КРС и Свиней — собаке не показывать');

      final cat = d.contraindications.getWarningsForAnimal('Кошки').join(' ');
      expect(cat, contains('Котята'));
      expect(cat, isNot(contains('Щенки')));
    });

    test('Флорфорте: запрет ЛОШАДЯМ — только Лошадям (строка-warnings)', () {
      // S-1: warnings бывает одиночной строкой, а не списком —
      // фильтр обязан работать и через неё.
      final d = byName('Флорфорте');
      final pig = d.contraindications.getWarningsForAnimal('Свиньи').join(' ');
      expect(pig, isNot(contains('ЛОШАДЯМ')));
      expect(pig, isNot(contains('несушкам')));
      final horse =
          d.contraindications.getWarningsForAnimal('Лошади').join(' ');
      expect(horse, contains('ЛОШАДЯМ'));
    });
  });

  group('лактация: 885 флагов начинают работать (PregnancyPeriod.lactating)', () {
    test('#814 Прималакт: дойная корова видит ЗАПРЕЩЕНО ПРИ ЛАКТАЦИИ', () {
      final d = byId(814);
      final lactating = d.checkContraindications(
        isPregnant: false,
        isLactating: true,
        isYoung: false,
        isOld: false,
        animalName: 'КРС',
        gender: 'female',
      );
      expect(lactating.riskWarnings.join(' '), contains('ЛАКТАЦИИ'));

      final dry = d.checkContraindications(
        isPregnant: false,
        isLactating: false,
        isYoung: false,
        isOld: false,
        animalName: 'КРС',
        gender: 'female',
      );
      expect(dry.riskWarnings, isEmpty);
    });

    test('VetProvider: чип лактации доезжает до riskWarnings результата', () {
      final vp = VetProvider();
      vp.debugSetCore(calcDatabase: db);
      vp.selectAnimal('cattle');
      vp.selectDrug(byId(814));
      vp.setWeight(500);
      vp.setGender(Gender.female);
      vp.setPregnancyPeriod(PregnancyPeriod.lactating);
      expect(vp.result.riskWarnings.join(' '), contains('ЛАКТАЦИИ'));

      vp.setPregnancyPeriod(PregnancyPeriod.notPregnant);
      expect(
          vp.result.riskWarnings
              .where((w) => w.contains('ЛАКТАЦИИ')),
          isEmpty);
      vp.reset();
    });

    test('PregnancyPeriod.lactating не считается беременностью', () {
      expect(PregnancyPeriod.lactating.isPregnant, isFalse);
      expect(PregnancyPeriod.late.isPregnant, isTrue);
    });
  });

  group('side_effects.json: species списком + matchesAnimal', () {
    test('SideEffect парсит строку, список и пусто; матчится по виду', () {
      final legacy = SideEffect.fromJson(
          {'effect': 'ототоксичность', 'species': 'кошки', 'action': ''});
      expect(legacy.species, ['кошки']);
      expect(legacy.matchesAnimal('Кошки'), isTrue);
      expect(legacy.matchesAnimal('Собаки'), isFalse);
      expect(legacy.matchesAnimal('КРС'), isFalse);

      final canonical = SideEffect.fromJson(
          {'effect': 'x', 'species': ['Кошки'], 'action': ''});
      expect(canonical.matchesAnimal('Кошки'), isTrue);

      final generic =
          SideEffect.fromJson({'effect': 'рвота', 'action': ''});
      expect(generic.species, isNull);
      expect(generic.matchesAnimal('КРС'), isTrue);
    });

    test('реальная advanced/side_effects.json: видовые эффекты валидны', () {
      final raw = File('assets/data/advanced/side_effects.json')
          .readAsStringSync();
      final database = SideEffectsDatabase.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
      final gentamicin = database.findByDrug('гентамицин')!;
      final oto = gentamicin.sideEffects
          .firstWhere((e) => e.effect.contains('ототоксичност'));
      expect(oto.matchesAnimal('Кошки'), isTrue,
          reason: 'ототоксичность гентамицина — видовой эффект кошек');
      expect(oto.matchesAnimal('Собаки'), isFalse);
      expect(oto.matchesAnimal('КРС'), isFalse);

      final tylosine = database.findByDrug('тилозин')!;
      final diarrhea = tylosine.sideEffects
          .firstWhere((e) => e.effect == 'диарея');
      expect(diarrhea.matchesAnimal('Лошади'), isTrue);
      expect(diarrhea.matchesAnimal('Свиньи'), isFalse,
          reason: 'диарея тилозина — риск лошадей, не свиней');
    });
  });
}
