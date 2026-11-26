import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetvoice_ai/utils/concentration_parser.dart';

/// ⚠ Фикс VV-038 (ревью 26.11.2026): МНН интерполировался в RegExp без
/// экранирования. В реестре есть составы с метасимволами RegExp:
/// «инсулин двухфазный [человеческий генно-инженерный]» (ВИНСУВЕТ микс
/// 30/70), «бензилдиметил[3-(миристоиламино)пропил]аммония…» (МИСТИН®/
/// Аргумистин®), «3-(2,2,2-триметилгидразиний)…» (Эмидонол 20%),
/// «бис(пиридин-2,6-дикарбоксилат) германия» (Максидин 0,4) — скобки,
/// квадратные скобки и диапазоны ломали компиляцию паттерна (FormatException
/// прямо в расчёте дозы реестровой ветки) или матчили не то.
///
/// Проверяем на РЕАЛЬНОЙ базе (паттерн real_database_test): парсер не
/// бросает ни на одной записи и матчит корректно.
void main() {
  late List<Map<String, dynamic>> registryDrugs;

  setUpAll(() {
    final raw = File('assets/data/drugs_registry.json').readAsStringSync();
    final data = jsonDecode(raw) as Map<String, dynamic>;
    registryDrugs = (data['drugs'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .toList();
  });

  // Как в ветке расчёта (vet_provider._calculateFromRegistry): парсер
  // получает ПЕРВОЕ МНН из списка — inn.split(RegExp('[,;]')).first.
  Map<String, dynamic> byTradeName(String name) =>
      registryDrugs.firstWhere((d) => d['trade_name'] == name);

  double parseFor(Map<String, dynamic> drug) {
    final inn = drug['inn'] as String? ?? '';
    final composition = drug['composition'] as String? ?? '';
    final firstInn = inn.split(RegExp('[,;]')).first.trim();
    return ConcentrationParser.parseConcentrationForSubstance(
        composition, firstInn);
  }

  group('VV-038: метасимволы МНН не роняют парсер (реальная база)', () {
    test('полный прогон по всем записям с составом — без FormatException',
        () {
      var checked = 0;
      for (final drug in registryDrugs) {
        final inn = drug['inn'] as String? ?? '';
        final composition = drug['composition'] as String? ?? '';
        if (inn.isEmpty || composition.isEmpty) continue;
        checked++;
        // Старый код валил здесь: RegExp('бис(пиридин-2...') → «Unterminated
        // group», RegExp('инсулин двухфазный [человеческий генно-
        // инженерный]...') → «Range out of order in character class».
        parseFor(drug);
      }
      expect(checked, greaterThan(2000),
          reason: 'гейт обязан прогонять ВСЮ базу, а не подвыборку');
    });

    test('4 препарата из ревью: парсят без исключений, значения честные', () {
      // ВИНСУВЕТ микс 30/70: действующее вещество в МЕ («100 МЕ»), мг-числа
      // для МНН в составе нет — парсер обязан вернуть 0, а не выдумать из
      // скобок или упасть.
      final vinsuvet = byTradeName('ВИНСУВЕТ микс 30/70');
      expect(parseFor(vinsuvet), 0);

      // МИСТИН®: в составе граммы («0,01 г»), мг-числа нет → 0.
      expect(parseFor(byTradeName('МИСТИН®')), 0);

      // Эмидонол 20%: состав без мг-чисел → 0.
      expect(parseFor(byTradeName('Эмидонол 20%')), 0);

      // Аргумистин® раствор: и первое МНН, и ПОЛНОЕ МНН (с квадратными
      // скобками и вложенными скобками) обязаны парситься без исключений.
      final argumistin = byTradeName('Аргумистин® раствор');
      expect(parseFor(argumistin), 0);
      final composition = argumistin['composition'] as String;
      final fullInn = (argumistin['inn'] as String).trim();
      expect(
        () => ConcentrationParser.parseConcentrationForSubstance(
            composition, fullInn),
        returnsNormally,
        reason: 'полное МНН «коллоидное серебро, бензилдиметил[3-(миристо-'
            'иламино) пропил]аммоний» — сплошные метасимволы RegExp',
      );
    });

    test('метасимвольные МНН матчат корректно, а не вхолостую', () {
      // «бис(пиридин-2,6-дикарбоксилат) германия - 4,0 мг» → 4.0
      expect(parseFor(byTradeName('Максидин 0,4')), 4.0,
          reason: 'экранированное МНН находит свою концентрацию');

      // «тилмикозин (в виде тилмикозина фосфата) - 250 мг» → 250.
      // Старый код возвращал 0: группа (...) в МНН перехватывала capture.
      expect(parseFor(byTradeName('Тилмозин')), 250.0);

      // «содержит 50 мг/мл и 100 мг/мл эмидонола - 3-(2,2,2-…» → 50
      expect(parseFor(byTradeName('Эмидонол 5%, 10%')), 50.0);
    });
  });

  group('VV-038: границы слова без регрессий обычных МНН', () {
    test('склонения МНН по-прежнему матчатся (граница только слева)', () {
      // Составы пишут МНН в родительном падеже: «…эмидонолА 50 мг».
      expect(
        ConcentrationParser.parseConcentrationForSubstance(
            'В 1 мл содержится эмидонола 50 мг', 'эмидонол'),
        50.0,
      );
    });

    test('чужое МНН внутри слова не матчится', () {
      // «мистин» внутри «аргумистин» — не то вещество: левая граница
      // обязана отсекать совпадение в середине слова.
      expect(
        ConcentrationParser.parseConcentrationForSubstance(
            'В 1 мл аргумистина 100 мг', 'мистин'),
        0,
      );
    });

    test('обычные МНН без метасимволов матчатся как раньше', () {
      expect(
        ConcentrationParser.parseConcentrationForSubstance(
            'В 1 мл препарата содержится флорфеникола 300 мг',
            'флорфеникол'),
        300.0,
      );
      expect(
        ConcentrationParser.parseConcentrationForSubstance(
            'содержит 100 мг тилозина в 1 мл', 'тилозин'),
        100.0,
      );
    });
  });
}
