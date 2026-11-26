import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetvoice_ai/models/verified_dosage.dart';

/// VV-003 (ревью 26.11.2026) — разбор фактов по верифицированной базе.
///
/// Заявка ревью: «из 2376 препаратов выживает 8 из-за `withdrawal_days as int?`
/// при double 28.0». Эмпирическая проверка на текущих данных (симуляция старых
/// кастов): потерь НЕТ — все 2376 записей парсятся и старым кодом. Double-
/// значения withdrawal_days живут на ВЕРХНЕМ уровне записи (который модель
/// вообще не читает), внутри animal_specific все int.
///
/// Что остаётся в силе: (а) num-толерантный каст — честный hardening против
/// будущих конвертов базы (паттерн S-1); (б) регрессионный замок: база
/// обязана парситься ЦЕЛИКОМ, любое молчаливое выпадение записей — красное.
void main() {
  late VerifiedDosageDatabase db;

  setUpAll(() {
    final raw = File('assets/data/verified_dosages.json').readAsStringSync();
    db = VerifiedDosageDatabase.fromJson(
        jsonDecode(raw) as Map<String, dynamic>);
  });

  test('база верифицированных доз парсится ЦЕЛИКОМ — 2376 записей', () {
    expect(db.dosages.length, 2376,
        reason: 'Каждая запись verified_dosages.json обязана доходить до '
            'приложения (per-item catch глотает молча — замок против '
            '«тихой ерунды» класса Task 178/S-1)');
  });

  test('Флорфорте доезжает до базы со своими видовыми дозами', () {
    final f = db.dosages.firstWhere((d) => d.tradeName == 'Флорфорте');
    expect(f.animalSpecific, isNotEmpty);
    expect(f.animalSpecific.values.any((a) => a.dosePerKg != null), isTrue);
  });

  test('видовые сроки ожидания читаются', () {
    final withWithdrawal = db.dosages
        .where((d) => d.animalSpecific.values
            .any((a) => (a.withdrawalDays ?? 0) > 0))
        .length;
    expect(withWithdrawal, greaterThan(5),
        reason: 'В базе 22 видовые записи со сроками ожидания мяса');
    final withMilk = db.dosages
        .where((d) => d.animalSpecific.values
            .any((a) => (a.withdrawalMilkDays ?? 0) > 0))
        .length;
    expect(withMilk, greaterThan(0));
  });

  test('hardening VV-003: double-значения сроков парсятся, запись не теряется',
      () {
    final vd = VerifiedAnimalDose.fromJson({
      'method': 'в/м',
      'frequency': '1 раз в сутки',
      'notes': '',
      'withdrawal_days': 28.0,
      'withdrawal_milk_days': 4.0,
    });
    expect(vd.withdrawalDays, 28,
        reason: 'num-толерантный каст: 28.0 → 28 (старый `as int?` бросал бы '
            'TypeError и per-item catch терял бы запись целиком)');
    expect(vd.withdrawalMilkDays, 4);
  });
}
