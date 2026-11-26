import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetvoice_ai/models/side_effects.dart';
import 'package:vetvoice_ai/providers/vet_provider.dart';

/// VV-005 (ревью 26.11.2026): MDR1-тест для пород группы колли + расчёт на
/// стадо (акселератор, 26.11.2026).
void main() {
  group('VV-005: mdr1_test доезжает из базы в модель', () {
    late SideEffectsDatabase db;

    setUpAll(() {
      final raw =
          File('assets/data/advanced/side_effects.json').readAsStringSync();
      db = SideEffectsDatabase.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    });

    test('ивермектин: предупреждение MDR1 читается из базы', () {
      final d = db.findByDrug('ивермектин');
      expect(d, isNotNull,
          reason: 'Запись ивермектина обязана присутствовать в базе');
      expect(d!.mdr1Test, isNotNull,
          reason: 'mdr1_test есть в JSON — модель обязана его читать '
              '(раньше поле не существовало, владелец колли не видел '
              'риск нейротоксикоза)');
      expect(d.mdr1Test!, contains('колли'));
    });
  });

  group('Расчёт на стадо (акселератор, 26.11.2026): DoseResult', () {
    test('formattedHerdVolume: мл × поголовье', () {
      const r = DoseResult(
        volume: 2,
        unit: 'мл',
        herdCount: 300,
        hasResult: true,
      );
      expect(r.isHerd, isTrue);
      expect(r.formattedHerdVolume, '600 мл');
    });

    test('formattedHerdVolume: таблетки', () {
      const r = DoseResult(volume: 0.25, unit: 'шт', herdCount: 100);
      expect(r.formattedHerdVolume, '25.0 шт');
    });

    test('одиночное животное: isHerd = false, стадо не рисуется', () {
      const r = DoseResult(volume: 2, unit: 'мл');
      expect(r.isHerd, isFalse);
      expect(r.herdCount, 1);
    });

    test('copyWith сохраняет поголовье', () {
      const r = DoseResult(volume: 2, unit: 'мл', herdCount: 500);
      expect(r.copyWith(volume: 3).herdCount, 500);
      expect(r.copyWith(herdCount: 50).herdCount, 50);
    });
  });
}
