import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetvoice_ai/models/dose_adjustment.dart';

/// Ревью 26.11.2026, блок VV-004 / VV-049 / VV-050 (dose_adjustments.json).
///
/// Паттерн real_database_test: гоняю юниты на РЕАЛЬНОМ ассете — синтетика
/// не заметила бы, что в базе lactation_notes — СТРОКА, а contraindicated —
/// список map {'drug','reason'} (именно так лежит в реальном JSON).
///
/// VV-004 — «тилмикозин» получал «Разрешён при беременности» через запись
/// «макролиды (кроме тилмикозина)»: substring-матч s.contains(q) ||
/// q.contains(s) не понимал исключений «кроме X». Фикс: исключения
/// разбираются, МНН матчится целыми токенами (стем-толерантно к падежам),
/// нормализация — регистр, ё→е, срезка ®™©.
///
/// VV-049 — lactation_notes в реальном JSON — строка «Большинство
/// препаратов проникает в молоко…», жёсткий `is List` всегда давал null.
///
/// VV-050 — contraindicated — список map вида {'drug': 'тетрациклины',
/// 'reason': 'поражение печени, зубы'}; strList() с e.toString() делал
/// «{drug: тетрациклины, reason: …}» и терял причину.
void main() {
  late PregnancyAdjustment pregnancy;

  setUpAll(() {
    final raw =
        File('assets/data/advanced/dose_adjustments.json').readAsStringSync();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    // pregnancy_lactation парсится напрямую, а не через
    // DoseAdjustmentDatabase.fromJson: пре-существующий крэш вне рамок
    // этого ревью-блока (пункта нет) — AgeAdjustments.fromJson
    // (dose_adjustment.dart:125) ждёт List в age_adjustments.neonates,
    // а в реальном JSON там map ({description, issues, drugs_avoid…}) →
    // TypeError; лоадер глотает его catch-ем, и вся база корректировок
    // падает в null ещё до pregnancy. Данные для VV-004/049/050 —
    // реальные, из того же ассета, без несвязанного крэша.
    pregnancy =
        PregnancyAdjustment.fromJson(json['pregnancy_lactation'] as Map<String, dynamic>);
  });

  group('VV-004: исключения «кроме» + токенный матчинг МНН', () {
    test('тилмикозин НЕ «Разрешён при беременности» (реальная база)', () {
      // Регрессия ревью: подстрока «тилмикозин» ловилась в safe-записи
      // «макролиды (кроме тилмикозина)». Тилмикозин явно исключён из
      // группы — данных о его статусе в базе нет → честный null.
      expect(pregnancy.checkPregnancy('тилмикозин'), isNull);
      expect(pregnancy.checkPregnancy('Тилмикозин'), isNull);
      // Родительный падеж из самой записи «(кроме тилмикозина)»:
      // стем-толерантность не должна открывать исключению «задний ход».
      expect(pregnancy.checkPregnancy('тилмикозина'), isNull);
      // Нормализация: ®™© и регистр не спасают от исключения.
      expect(pregnancy.checkPregnancy('Тилмикозин®'), isNull);
      expect(pregnancy.checkPregnancy('ТИЛМИКОЗИН'), isNull);
    });

    test('группа с исключением матчится сама по себе (реальная база)', () {
      // «макролиды (кроме тилмикозина)»: исключён только тилмикозин,
      // сама запись-группа остаётся в safe и работает как раньше.
      expect(
        pregnancy.checkPregnancy('макролиды'),
        'Разрешён при беременности',
      );
    });

    test('записи-группы без исключений ведут себя как раньше (реальная база)', () {
      expect(
        pregnancy.checkPregnancy('пенициллин'),
        'Разрешён при беременности',
      );
      // Падежное окончание: «пенициллин» ~ «пенициллины» (стем ≥ 5).
      expect(
        pregnancy.checkPregnancy('пенициллины'),
        'Разрешён при беременности',
      );
      expect(
        pregnancy.checkPregnancy('цефалоспорины'),
        'Разрешён при беременности',
      );
      expect(
        pregnancy.checkPregnancy('НПВС'),
        'С ОСТОРОЖНОСТЬЮ при беременности',
      );
      expect(
        pregnancy.checkPregnancy('метронидазол'),
        'С ОСТОРОЖНОСТЬЮ при беременности',
      );
    });

    test('простые записи матчатся: ампициллин, ё, ®, доп. токены (синтетика)', () {
      final p = PregnancyAdjustment.fromJson(const {
        'safe': ['ампициллин'],
      });
      expect(
        p.checkPregnancy('ампициллин'),
        'Разрешён при беременности',
      );
      // Регистр, ®™©, ё→е — нормализация запроса.
      expect(
        p.checkPregnancy('Ампициллин®'),
        'Разрешён при беременности',
      );
      // Падежное окончание запроса (стем-толерантность).
      expect(
        p.checkPregnancy('ампициллина'),
        'Разрешён при беременности',
      );
      // МНН в составе названия препарата: лишние токены не мешают.
      expect(
        p.checkPregnancy('ампициллин 10%'),
        'Разрешён при беременности',
      );
    });

    test('токенный матчинг не ловит подстроки-омонимы (синтетика)', () {
      final p = PregnancyAdjustment.fromJson(const {
        'caution': ['аминогликозиды'],
      });
      expect(
        p.checkPregnancy('аминогликозиды'),
        'С ОСТОРОЖНОСТЬЮ при беременности',
      );
      // «метронидазол» не «аминогликозиды»: токены целиком, «…азиды»
      // не совпадают ни равенством, ни префикс-стемом.
      expect(p.checkPregnancy('метронидазол'), isNull);
      // «тилозин» не «тилмикозин» и не группа: подстроки недостаточно.
      expect(p.checkPregnancy('тилозин'), isNull);
    });

    test('порядок проверки contraindicated → caution → safe прежний', () {
      final p = PregnancyAdjustment.fromJson(const {
        'safe': ['метронидазол'],
        'caution': ['метронидазол'],
        'contraindicated': ['метронидазол'],
      });
      expect(
        p.checkPregnancy('метронидазол'),
        'ПРОТИВОПОКАЗАН при беременности',
      );
    });
  });

  group('VV-049: lactation_notes — список ИЛИ строка', () {
    test('реальный JSON: строка про молоко не null (была всегда null)', () {
      expect(pregnancy.lactationNotes, isNotNull);
      expect(pregnancy.lactationNotes, isNotEmpty);
      expect(pregnancy.lactationNotes!.join(' '), contains('молоко'));
    });

    test('список по-прежнему работает; пусто/нет — честный null', () {
      final asList = PregnancyAdjustment.fromJson(const {
        'lactation_notes': ['первое замечание', 'второе замечание'],
      });
      expect(asList.lactationNotes, hasLength(2));
      expect(asList.lactationNotes![0], 'первое замечание');

      expect(PregnancyAdjustment.fromJson(const {}).lactationNotes, isNull);
      expect(
        PregnancyAdjustment.fromJson(const {'lactation_notes': '   '})
            .lactationNotes,
        isNull,
      );
    });
  });

  group('VV-050: contraindicated — список map с drug + reason', () {
    test('реальный JSON: map-записи парсятся, причина не теряется', () {
      expect(pregnancy.contraindicated, isNotEmpty);
      final tetracyclines = pregnancy.contraindicated.firstWhere(
        (c) => c.drug.contains('тетрациклины'),
      );
      expect(tetracyclines.drug, 'тетрациклины');
      expect(tetracyclines.reason, 'поражение печени, зубы');
      expect(
        tetracyclines.display,
        'тетрациклины — поражение печени, зубы',
      );
      // Раньше вместо drug был мусор «{drug: тетрациклины, …}».
      expect(tetracyclines.drug.contains('drug:'), isFalse);
    });

    test('checkPregnancy матчит по drug и отдаёт причину (реальная база)', () {
      final tetracyclines = pregnancy.checkPregnancy('тетрациклины')!;
      expect(tetracyclines, startsWith('ПРОТИВОПОКАЗАН при беременности'));
      expect(tetracyclines, contains('тетрациклины — поражение печени, зубы'));
      // Пример ревью про хрупкий contains-сравнение: мизопростол.
      final misoprostol = pregnancy.checkPregnancy('мизопростол')!;
      expect(
        misoprostol,
        'ПРОТИВОПОКАЗАН при беременности: мизопростол — абортивное действие',
      );
      // Диэтилстильбэстрол — второй пример ревью.
      final des = pregnancy.checkPregnancy('диэтилстильбэстрол')!;
      expect(des, contains('диэтилстильбэстрол — тератоген'));
    });

    test('список строк по-прежнему работает, reason = null', () {
      final p = PregnancyAdjustment.fromJson(const {
        'contraindicated': ['хлорамфеникол'],
      });
      expect(p.contraindicated, hasLength(1));
      expect(p.contraindicated.first.drug, 'хлорамфеникол');
      expect(p.contraindicated.first.reason, isNull);
      expect(p.contraindicated.first.display, 'хлорамфеникол');
      // Формат без причины — прежний, без «: drug».
      expect(
        p.checkPregnancy('хлорамфеникол'),
        'ПРОТИВОПОКАЗАН при беременности',
      );
    });

    test('map-запись с reason в fromJson (синтетика)', () {
      final p = PregnancyAdjustment.fromJson(const {
        'contraindicated': [
          {'drug': 'тетрациклины', 'reason': 'поражение печени, зубы'},
        ],
      });
      expect(p.contraindicated.first.drug, 'тетрациклины');
      expect(p.contraindicated.first.reason, 'поражение печени, зубы');
      expect(
        p.checkPregnancy('тетрациклины'),
        'ПРОТИВОПОКАЗАН при беременности: '
            'тетрациклины — поражение печени, зубы',
      );
    });
  });
}
