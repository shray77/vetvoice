import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetvoice_ai/models/fluid_therapy.dart';
import 'package:vetvoice_ai/screens/fluid_therapy_screen.dart';

/// Юнит-гейт на РЕАЛЬНОЙ базе assets/data/advanced/fluid_therapy.json
/// (по прецеденту real_database_test.dart / Task 183 — ревью 26.11.2026).
///
/// VV-012 — у «Ca-глюконат 10%» в JSON есть monitoring «ЭКГ (брадикардия =
/// остановить!)» — условие НЕМЕДЛЕННОЙ остановки инфузии. FluidAdditive.fromJson
/// его не читал. Хуже: у Ca-глюконата и MgSO4 indication — СПИСОК, и жёсткий
/// `as String?` кидал TypeError, а per-item catch в FluidTherapyDatabase.fromJson
/// молча выбрасывал запись ЦЕЛИКОМ (класс бага S-1 из Task 183): на вкладке
/// «Добавки» жили только 3 из 5 записей, правило остановки не доезжало до врача.
///
/// VV-051 — max_dose («20 мл/кг/сут» у Гелофузина/Венофундина ГЭК) и half_life
/// («4-6 часов») не читались FluidSolution.fromJson — суточный потолок коллоида
/// можно было молча превысить.
void main() {
  late FluidTherapyDatabase db;

  setUpAll(() {
    final raw =
        File('assets/data/advanced/fluid_therapy.json').readAsStringSync();
    db = FluidTherapyDatabase.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  });

  group('VV-012: monitoring и целостность добавок', () {
    test('все 5 добавок базы доходят до модели — потери 0', () {
      expect(db.additives.length, 5,
          reason: 'Каждая запись additives обязана доходить до вкладки '
              '«Добавки». До ревью 26.11.2026 Ca-глюконат 10% и MgSO4 25% '
              'молча выбрасывались per-item catch’ем: indication был '
              'списком, а не строкой.',
      );
    });

    test('Ca-глюконат 10% парсится целиком: indication-список склеен', () {
      final ca = db.additives.firstWhere((a) => a.name == 'Ca-глюконат 10%');
      expect(ca.indication, 'гипокальциемия, эклампсия, гиперкалиемия');
    });

    test('правило остановки инфузии доезжает из JSON в модель', () {
      final ca = db.additives.firstWhere((a) => a.name == 'Ca-глюконат 10%');
      expect(ca.monitoring, 'ЭКГ (брадикардия = остановить!)',
          reason: 'Условие немедленной остановки инфузии кальция — критично '
              'для безопасности, не может теряться при парсинге.',
      );
    });

    test('у добавок без monitoring поле — null, а не мусор', () {
      final kcl = db.additives.firstWhere((a) => a.name == 'KCl');
      expect(kcl.monitoring, isNull);
      expect(kcl.maxRate, '0.5 мЭкв/кг/ч');
    });
  });

  group('VV-051: суточные лимиты растворов', () {
    test('Гелофузин: maxDose и halfLife из JSON', () {
      final g = db.solutions.firstWhere((s) => s.name == 'Гелофузин');
      expect(g.maxDose, '20 мл/кг/сут');
      expect(g.halfLife, '4-6 часов');
    });

    test('Венофундин (ГЭК): видовой суточный лимит из JSON', () {
      final v = db.solutions.firstWhere((s) => s.name.contains('Венофундин'));
      expect(v.maxDose, '20 мл/кг/сут (собаки), 10 мл/кг/сут (кошки)');
      expect(v.halfLife, isNull,
          reason: 'у Венофундина half_life в JSON нет — null, не пустышка',
      );
    });

    test('без max_dose/half_life — null, карточка их не рисует', () {
      final rl = db.solutions.firstWhere((s) => s.name == 'Рингер-Лактат');
      expect(rl.maxDose, isNull);
      expect(rl.halfLife, isNull);
    });
  });

  group('VV-012/VV-051: экран', () {
    Future<void> pump(WidgetTester tester) async {
      // Высокий вьюпорт: карточки целиком (Гелофузин — 6-я из 7) без
      // ручного скролла в тесте.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: FluidTherapyScreen(db: db)));
      await tester.pumpAndSettle();
    }

    testWidgets('вкладка «Добавки»: правило остановки ЭКГ — заметной строкой',
        (tester) async {
      await pump(tester);
      await tester.tap(find.text('Добавки'));
      await tester.pumpAndSettle();

      expect(
        find.text('Мониторинг: ЭКГ (брадикардия = остановить!)'),
        findsOneWidget,
        reason: 'Правило остановки инфузии обязано быть на карточке Ca-глюконата',
      );
      expect(find.byIcon(Icons.warning_amber), findsOneWidget,
          reason: 'выделение — иконка warning_amber на severity-подложке',
      );
      // Запись не потерялась: карточка Ca-глюконата на месте
      expect(find.text('Ca-глюконат 10%'), findsOneWidget);
      // VV-012 заодно: потолок скорости KCl тоже доезжал только до модели
      expect(find.text('Макс. скорость: 0.5 мЭкв/кг/ч'), findsOneWidget);
    });

    testWidgets('вкладка «Растворы»: суточный лимит и T½ на карточке',
        (tester) async {
      await pump(tester);
      await tester.tap(find.text('Растворы'));
      await tester.pumpAndSettle();

      expect(find.text('Макс. доза: 20 мл/кг/сут'), findsOneWidget,
          reason: 'суточный потолок Гелофузина',
      );
      expect(
        find.text('Макс. доза: 20 мл/кг/сут (собаки), 10 мл/кг/сут (кошки)'),
        findsOneWidget,
        reason: 'видовой потолок Венофундина ГЭК',
      );
      expect(find.text('T½: 4-6 часов'), findsOneWidget,
          reason: 'период полувыведения Гелофузина',
      );
      expect(find.byIcon(Icons.schedule), findsOneWidget);
    });
  });
}
