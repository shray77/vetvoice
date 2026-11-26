import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vetvoice_ai/models/withdrawal.dart';
import 'package:vetvoice_ai/providers/vet_provider.dart';
import 'package:vetvoice_ai/screens/withdrawal_calculator_screen.dart';

/// Ревью 26.11.2026: VV-006 + VV-029 — калькулятор каренции.
///
/// VV-006: строковые запреты в withdrawal_by_product.json («ЗАПРЕЩЁН»,
/// «НЕ ДЛЯ ДОЙНЫХ!», «НЕ ПРИМЕНЯТЬ несушкам!» — 24 значения) раньше
/// превращались в null → «Не указан»: явный запрет читался как «нет
/// ограничений». Теперь int → «N суток», String → дословно, null → «Не
/// указан».
///
/// VV-029: выбор вида не влиял на расчёт — читались только
/// withdrawalText/withdrawalDays. Теперь в приоритете видовые правила из
/// WithdrawalDatabase (поиск по МНН, включая составные), fallback —
/// прежняя логика, но продукты фильтруются по релевантности виду.
///
/// Паттерн real_database_test: юниты на РЕАЛЬНОЙ базе, виджет-тесты —
/// паттерн golden_all_screens_test (мок канала flutter/assets, синглтон
/// VetProvider прогревается в setUpAll ВНЕ fake-async зоны).
void main() {
  // ============================================================
  // VV-006 + VV-029: модель на реальной базе
  // ============================================================
  late WithdrawalDatabase db;

  setUpAll(() {
    final raw = File('assets/data/advanced/withdrawal_by_product.json')
        .readAsStringSync();
    db =
        WithdrawalDatabase.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  });

  group('VV-006: WithdrawalProduct — строковые запреты дословно', () {
    test('хлорамфеникол КРС: мясо и молоко ЗАПРЕЩЁН, не «Не указан»', () {
      final entry = db.findByInn('хлорамфеникол')!;
      expect(entry.findWithdrawal('КРС', 'meat'), 'ЗАПРЕЩЁН');
      expect(entry.findWithdrawal('КРС', 'milk'), 'ЗАПРЕЩЁН');
      expect(entry.findWithdrawal('КРС', 'meat'), isNot('Не указан'));
    });

    test('тилмикозин КРС: молоко НЕ ДЛЯ ДОЙНЫХ!', () {
      final entry = db.findByInn('тилмикозин')!;
      expect(entry.findWithdrawal('КРС', 'milk'), 'НЕ ДЛЯ ДОЙНЫХ!');
    });

    test('энрофлоксацин Птица: яйца НЕ ПРИМЕНЯТЬ несушкам!', () {
      final entry = db.findByInn('энрофлоксацин')!;
      expect(entry.findWithdrawal('Птица', 'eggs'), 'НЕ ПРИМЕНЯТЬ несушкам!');
    });

    test('int-значения форматируются как раньше: «N суток»', () {
      final entry = db.findByInn('энрофлоксацин')!;
      expect(entry.findWithdrawal('КРС', 'meat'), '14 суток');
      expect(entry.findWithdrawal('КРС', 'milk'), '5 суток');
    });

    test('fromJson: String дословно, int — сутки, null — честное «Не указан»',
        () {
      final p = WithdrawalProduct.fromJson({
        'meat': 'ЗАПРЕЩЁН',
        'milk': 'НЕ ДЛЯ ДОЙНЫХ!',
        'eggs': 10,
      });
      expect(p.formatMeat(), 'ЗАПРЕЩЁН');
      expect(p.formatMilk(), 'НЕ ДЛЯ ДОЙНЫХ!');
      expect(p.formatEggs(), '10 суток');

      final empty = WithdrawalProduct.fromJson({});
      expect(empty.formatMeat(), 'Не указан');
      expect(empty.formatMilk(), 'Не указан');
      expect(empty.formatEggs(), 'Не указан');
    });

    test('вид без видовых данных → null (отличимо от «Не указан»)', () {
      // Тилмикозин: только КРС и Свиньи — Лошадей в блоке нет вообще.
      final entry = db.findByInn('тилмикозин')!;
      expect(entry.findWithdrawal('Лошади', 'meat'), isNull);
    });
  });

  group('VV-029: findByInn — составные МНН', () {
    test('разделители « + » / «,» / «+» — одно и то же МНН', () {
      expect(
        db.findByInn('сульфадоксин + триметоприм')!.inn,
        'сульфадоксин+триметоприм',
      );
      expect(
        db.findByInn('сульфаметоксазол, триметоприм')!.inn,
        'сульфаметоксазол+триметоприм',
      );
    });

    test('монопрепарат внутри составного МНН препарата', () {
      // «энрофлоксацин, колистин» (Витроцил) → запись «энрофлоксацин».
      expect(db.findByInn('энрофлоксацин, колистин')!.inn, 'энрофлоксацин');
    });

    test('комбинация предпочитается одиночному компоненту', () {
      // «фебантел, пирантел, празиквантел» (Дронтал® плюс) → запись
      // комбинации «празиквантел+пирантел+фебантел», а не голый
      // «празиквантел» — ближе к составу препарата.
      expect(
        db.findByInn('фебантел, пирантел, празиквантел')!.inn,
        'празиквантел+пирантел+фебантел',
      );
    });

    test('точное одиночное МНН — как прежде', () {
      expect(db.findByInn('тилмикозин')!.inn, 'тилмикозин');
    });

    test('словоформа — прежний substring-фолбэк', () {
      // «хлортетрациклина гидрохлорид» ⊃ «хлортетрациклин».
      expect(
        db.findByInn('хлортетрациклина гидрохлорид')!.inn,
        'хлортетрациклин',
      );
    });

    test('чужое МНН → null: мадурицин ≠ робенидин', () {
      // Робимикс (робенидина гидрохлорид) ≠ «робенинцин (мадурицин
      // аммония)» — не выдумываем каренцию по похожему названию.
      expect(db.findByInn('робенидина гидрохлорид'), isNull);
      expect(db.findByInn(''), isNull);
    });
  });

  // ============================================================
  // VV-029: экран — вид влияет на результат
  // ============================================================
  group('VV-029: экран калькулятора каренции', () {
    late VetProvider vp;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({'disclaimer_accepted': true});
      // Мок канала 'flutter/assets': rootBundle.loadString виснет без
      // него — отдаём JSON напрямую с диска (паттерн golden-теста).
      TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (ByteData? message) async {
        if (message == null) return null;
        final key = utf8.decode(message.buffer.asUint8List());
        final rel = key.startsWith('/') ? key.substring(1) : key;
        final f = File(rel.startsWith('assets/') ? rel : 'assets/$rel');
        if (f.existsSync()) {
          return ByteData.view(f.readAsBytesSync().buffer);
        }
        return null;
      });
      // Базы — ВНЕ fake-async зоны; withdrawalDatabase грузится в
      // extended-волне (стадия 2), ждём extendedReady.
      vp = VetProvider();
      await vp.initialize();
      await vp.extendedReady;
      expect(
        vp.withdrawalDatabase,
        isNotNull,
        reason: 'withdrawal_by_product.json должен быть загружен',
      );
    });

    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WithdrawalCalculatorScreen(
            vetProvider: vp,
            // Детерминизм дат: 26.10.2026 + N суток (паттерн Task 179).
            initialDate: DateTime(2026, 10, 26),
            firstDate: DateTime(2025, 10, 26),
            lastDate: DateTime(2026, 11, 25),
          ),
        ),
      );
      await tester.pump();
    }

    /// Выбор препарата через DrugPicker: запрос → тап по ListTile.
    Future<void> selectDrug(
      WidgetTester tester,
      String query,
      String name,
    ) async {
      await tester.enterText(find.byType(TextField), query);
      await tester.pump();
      final tile = find.widgetWithText(ListTile, name).first;
      await tester.ensureVisible(tile);
      await tester.pump();
      await tester.tap(tile);
      await tester.pump();
    }

    testWidgets('КРС + тилмикозин: запрет «НЕ ДЛЯ ДОЙНЫХ!», не «Не указан»',
        (tester) async {
      await pumpScreen(tester);
      await selectDrug(tester, 'тилмакс', 'Тилмакс');

      // VV-006 через UI: запрет виден ДОСЛОВНО, а не «Не указан».
      expect(find.text('НЕ ДЛЯ ДОЙНЫХ!'), findsOneWidget);
      expect(find.text('Не указан'), findsNothing);
      expect(find.text('Мясо'), findsOneWidget);
      expect(find.text('Молоко'), findsOneWidget);

      // Видовые данные из базы (35 суток) важнее withdrawal_days (14):
      // 26.10.2026 + 35 суток = 30.11.2026.
      expect(find.text('Безопасно с: 30.11.2026'), findsOneWidget);
      expect(find.text('Каренция: 35 дн'), findsOneWidget);
    });

    testWidgets('Птица + энрофлоксацин: яйца под запретом, молока нет',
        (tester) async {
      await pumpScreen(tester);
      await selectDrug(tester, 'энроксил', 'Энроксил® 10% раствор для инъекций');

      // По умолчанию КРС: мясу и молоку есть числовая каренция.
      expect(find.text('Молоко'), findsOneWidget);
      expect(find.text('Каренция: 14 дн'), findsOneWidget);
      expect(find.text('Каренция: 5 дн'), findsOneWidget);

      // VV-029: переключение вида меняет результат.
      await tester.tap(find.text('Птица'));
      await tester.pump();

      expect(find.text('Яйца'), findsOneWidget);
      expect(find.text('НЕ ПРИМЕНЯТЬ несушкам!'), findsOneWidget);
      // У птицы молока нет — карточку «Молоко» не рисуем.
      expect(find.text('Молоко'), findsNothing);
      expect(find.text('Каренция: 14 дн'), findsOneWidget);
    });

    testWidgets('Собаки + энрофлоксацин: только мясо', (tester) async {
      await pumpScreen(tester);
      await selectDrug(tester, 'энроксил', 'Энроксил® 10% раствор для инъекций');

      await tester.tap(find.text('Собаки'));
      await tester.pump();

      expect(find.text('Мясо'), findsOneWidget);
      expect(find.text('Каренция: 14 дн'), findsOneWidget);
      expect(find.text('Молоко'), findsNothing);
      expect(find.text('Яйца'), findsNothing);
    });

    testWidgets('хлорамфеникол: «ЗАПРЕЩЁН» дословно, дату не выдумываем',
        (tester) async {
      await pumpScreen(tester);
      await selectDrug(
        tester,
        'барс',
        'БАРС® капли глазные', // inn: хлорамфеникол, нитрофурал
      );

      // Прежний is int превращал ЗАПРЕЩЁН в null → «Не указан».
      expect(find.text('ЗАПРЕЩЁН'), findsNWidgets(2)); // мясо и молоко КРС
      // Запрету не может быть «безопасной даты» — карточка без даты.
      expect(find.textContaining('Безопасно с'), findsNothing);
      expect(find.text('Не указан'), findsNothing);
    });

    testWidgets('вид без видовых данных — fallback, продукты по виду',
        (tester) async {
      await pumpScreen(tester);
      await selectDrug(tester, 'сальмогир', 'САЛЬМОГИР®'); // празиквантел

      // КРС: видовой блок из базы — мясо 14 суток, молоко 5.
      expect(find.text('Мясо'), findsOneWidget);
      expect(find.text('Молоко'), findsOneWidget);
      expect(find.text('Безопасно с: 31.10.2026'), findsOneWidget); // +5 сут

      // Собакам у празиквантела видовой блок ПУСТОЙ («Собаки»: {}) —
      // честно уходим в fallback (withdrawalText), и у Собак рисуем
      // только мясо, без молока.
      await tester.tap(find.text('Собаки'));
      await tester.pump();

      expect(find.text('Мясо'), findsOneWidget);
      expect(find.text('Каренция: 14 дн'), findsOneWidget);
      expect(find.text('Молоко'), findsNothing);
      expect(find.text('Яйца'), findsNothing);
    });
  });
}
