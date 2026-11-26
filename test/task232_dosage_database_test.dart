import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetvoice_ai/models/dosage_database.dart';

/// ⚠ Фикс VV-033 (ревью 26.11.2026): DosageDatabase.fromJson жёстко кастовал
/// каждый элемент dosages к Map без per-item защиты — ОДНА битая запись
/// обнуляла ВСЮ базу (671 МНН): compute()-обёртка drug_loader'а подставляла
/// null, findByInnList() → null, реестровая ветка теряла дозировки молча.
/// Теперь битые записи пропускаются с debugPrint, факт потери пробрасывается
/// наверх полем skippedCount (DrugLoaderService → LoadResult).
void main() {
  test('битая запись не роняет базу: остальные МНН на месте', () {
    final db = DosageDatabase.fromJson({
      'meta': {'version': '2.0', 'last_updated': '2026-05-07'},
      'dosages': {
        'амоксициллин': {
          'dogs': {'dose_mg_kg': 15},
        },
        // битая запись №1: вообще не объект
        'битая-строка': 'не объект',
        // битая запись №2: МНН-запись — объект, но поле вида — не объект
        'битый-вид': {
          'dogs': 'не объект',
        },
        'тилозин': {
          'cattle': {'dose_mg_kg': 10},
        },
      },
    });

    expect(db.dosages.length, 2, reason: 'выжили только валидные записи');
    expect(db.skippedCount, 2,
        reason: 'факт частичной неудачи пробрасывается наверх (skippedCount)');
    expect(db.findByInn('амоксициллин'), isNotNull,
        reason: 'первая валидная запись на месте');
    expect(db.findByInn('тилозин'), isNotNull,
        reason: 'и после битых записей валидные не теряются');
    expect(db.findByInn('битая-строка'), isNull);
    expect(db.findByInnList(['битая-строка', 'тилозин']), isNotNull,
        reason: 'findByInnList проходит мимо битой записи');
    expect(
      db.dosages['амоксициллин']!.getForAnimal('Собаки')?.doseMgKg,
      15.0,
      reason: 'валидные записи продолжают работать как раньше',
    );
  });

  test('реальная база: 671 МНН, потерь 0', () {
    final raw = File('assets/data/dosage_database.json').readAsStringSync();
    final db =
        DosageDatabase.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    expect(db.dosages.length, 671,
        reason: 'в базе 671 МНН — как до фикса, ничего не потерялось');
    expect(db.skippedCount, 0,
        reason: 'реальная база обязана парситься целиком');
    expect(db.findByInn('амоксициллин'), isNotNull);
  });
}
