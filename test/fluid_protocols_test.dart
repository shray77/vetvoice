import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetvoice_ai/models/fluid_therapy.dart';

/// Находка аудита (ревью 26.11.2026, блок VV-012): protocol в JSON —
/// список шагов-фаз, а модель ждала строку → все 4 протокола молча
/// выбрасывались per-item catch-ем, вкладка «Протоколы» была пустой.
void main() {
  late FluidTherapyDatabase db;

  setUpAll(() {
    final raw =
        File('assets/data/advanced/fluid_therapy.json').readAsStringSync();
    db = FluidTherapyDatabase.fromJson(
        jsonDecode(raw) as Map<String, dynamic>);
  });

  test('все 4 специальных протокола парсятся (вкладка «Протоколы» живая)', () {
    expect(db.specialProtocols.length, 4,
        reason: 'До фикса — 0: жёсткий `protocol as String?` на списке фаз '
            'кидал TypeError, per-item catch глотал протокол целиком');
  });

  test('Парвовирусный энтерит: 3 фазы с жидкостью и скоростью', () {
    final parvo = db.specialProtocols
        .firstWhere((p) => p.name.contains('Парвовирусный'));
    expect(parvo.protocol.length, 3);
    expect(parvo.protocol.first.phase, 'стабилизация');
    expect(parvo.protocol.first.fluid, contains('Рингер-Лактат'));
    expect(parvo.protocol.first.rate, isNotNull);
  });

  test('display строки шага: фаза + жидкость + скорость (+ notes)', () {
    final parvo = db.specialProtocols
        .firstWhere((p) => p.name.contains('Парвовирусный'));
    final line = parvo.protocol.first.display;
    expect(line, contains('стабилизация'));
    expect(line, contains('Рингер-Лактат'));
    expect(line, contains('мл/кг'));
  });

  test('Отёк лёгких: терапевтические шаги (therapy/dose/frequency) парсятся',
      () {
    final edema = db.specialProtocols
        .firstWhere((p) => p.name.contains('лёгких'));
    expect(
      edema.protocol.any((s) => s.therapy == 'фуросемид' && s.dose != null),
      isTrue,
      reason: 'У «Отёка лёгких» фазы и терапии вперемешку — модель обязана '
          'читать и то, и другое',
    );
    expect(edema.protocol, isNotEmpty);
    expect(
      edema.protocol.every((s) => s.display.isNotEmpty),
      isTrue,
      reason: 'Каждый шаг обязан собираться в осмысленную строку карточки',
    );
  });
}
