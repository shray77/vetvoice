import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetvoice_ai/screens/interactions_checker_screen.dart';
import 'package:vetvoice_ai/utils/app_theme.dart';

/// ⚠ Фикс VV-026 (ревью 26.11.2026): drug_interactions.json пишет severity
/// как critical/warning/info (18/49/6 из 73 пар), а экран взаимодействий
/// понимал только critical/major/moderate/minor — 55 из 73 пар показывали
/// сырое «warning» серой иконкой help и падали в хвост сортировки.
///
/// Гейт на РЕАЛЬНОЙ базе (паттерн real_database_test.dart): все severity
/// из ассета обязаны маппиться на внятные уровни severity-лестницы DS,
/// а сортировка — ставить critical первым.
void main() {
  late List<DrugInteractionExtended> interactions;

  setUpAll(() {
    final raw =
        File('assets/data/advanced/drug_interactions.json').readAsStringSync();
    final data = jsonDecode(raw) as Map<String, dynamic>;
    interactions = (data['interactions'] as List<dynamic>)
        .map((i) =>
            DrugInteractionExtended.fromJson(i as Map<String, dynamic>))
        .toList();
  });

  group('VV-026: severity из реальной базы маппится на внятные уровни', () {
    test('база читается целиком: 73 пары', () {
      expect(interactions.length, 73,
          reason: 'В базе drug_interactions.json 73 пары препаратов. '
              'Потеря пары = молчаливая «безопасность» комбинации.');
    });

    test('в базе только критичные значения: critical/warning/info', () {
      final severities = interactions.map((i) => i.severity).toSet();
      expect(severities, {'critical', 'warning', 'info'},
          reason: 'Появление нового значения severity в базе — повод '
              'пересмотреть маппинг в DrugInteractionExtended');
    });

    test('каждая пара получает уровень лестницы DS и читаемую подпись', () {
      for (final i in interactions) {
        // Не должно остаться «сырого» значения из базы в бейдже
        expect(i.severityLabel, isNot(i.severity),
            reason: 'severity "${i.severity}" (${i.drug1} + ${i.drug2}) '
                'должен маппиться на читаемую подпись, а не показываться как есть');
        expect(i.severityIcon, isNot(Icons.help),
            reason: 'Серая иконка help = непонятный уровень '
                '(${i.drug1} + ${i.drug2})');
        expect(i.severityColor(Brightness.light),
            isNot(AppTheme.textSecondary),
            reason: 'Серый цвет бейджа = непонятный уровень '
                '(${i.drug1} + ${i.drug2})');
        expect(i.severityColor(Brightness.dark),
            isNot(AppTheme.textSecondary),
            reason: 'Серый цвет бейджа в тёмной теме = непонятный уровень '
                '(${i.drug1} + ${i.drug2})');
      }
    });

    test('warning → major, info → minor, critical → critical', () {
      DrugInteractionExtended bySeverity(String s) =>
          interactions.firstWhere((i) => i.severity == s,
              orElse: () => throw StateError('в базе нет пары с severity $s'));

      expect(bySeverity('critical').severityLevel, SeverityLevel.critical);
      expect(bySeverity('critical').severityRank, 0);
      expect(bySeverity('critical').severityLabel, 'Критическое');

      expect(bySeverity('warning').severityLevel, SeverityLevel.major,
          reason: 'база пишет warning — экран обязан понимать это как major');
      expect(bySeverity('warning').severityRank, 1);
      expect(bySeverity('warning').severityLabel, 'Серьёзное');
      expect(bySeverity('warning').severityIcon, Icons.warning);

      expect(bySeverity('info').severityLevel, SeverityLevel.minor,
          reason: 'база пишет info — экран обязан понимать это как minor');
      expect(bySeverity('info').severityRank, 3);
      expect(bySeverity('info').severityLabel, 'Незначительное');
      expect(bySeverity('info').severityIcon, Icons.check_circle);
    });

    test('легаси-значения major/moderate/minor тоже поняты', () {
      const major = DrugInteractionExtended(
        drug1: 'a', drug2: 'b', severity: 'major',
        effect: '', consequence: '', recommendation: '',
      );
      expect(major.severityLevel, SeverityLevel.major);
      expect(major.severityLabel, 'Серьёзное');

      const moderate = DrugInteractionExtended(
        drug1: 'a', drug2: 'b', severity: 'moderate',
        effect: '', consequence: '', recommendation: '',
      );
      expect(moderate.severityLevel, SeverityLevel.moderate);
      expect(moderate.severityRank, 2);
      expect(moderate.severityLabel, 'Умеренное');

      const minor = DrugInteractionExtended(
        drug1: 'a', drug2: 'b', severity: 'minor',
        effect: '', consequence: '', recommendation: '',
      );
      expect(minor.severityLevel, SeverityLevel.minor);
      expect(minor.severityLabel, 'Незначительное');
    });

    test('сортировка по severityRank ставит critical первым', () {
      // Тот же компаратор, что в _buildInteractionsList
      final sorted = List<DrugInteractionExtended>.from(interactions)
        ..sort((a, b) => a.severityRank.compareTo(b.severityRank));

      expect(sorted.first.severity, 'critical',
          reason: 'Первым в списке должен быть самый опасный уровень');

      // Ранги неубывают (стабильность сортировки по опасности)
      for (int i = 1; i < sorted.length; i++) {
        expect(sorted[i].severityRank >= sorted[i - 1].severityRank, isTrue,
            reason: 'Позиция $i: более опасная пара не может стоять '
                'ниже менее опасной');
      }

      // Все critical раньше всех info
      final lastCritical = sorted.lastIndexWhere((i) => i.severityRank == 0);
      final firstInfo = sorted.indexWhere((i) => i.severityRank == 3);
      expect(lastCritical < firstInfo, isTrue,
          reason: 'critical обязан сортироваться выше minor/info');
    });
  });
}
