import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetvoice_ai/models/dose_adjustment.dart';

/// Находка аудита (ревью 26.11.2026, блок VV-004): age_adjustments в
/// реальном JSON — MAP-и ({description, issues, general_rule, drugs_avoid,
/// safe_drugs} и т.п.), а модель ждала List → TypeError, и лоадер глотал
/// ВСЮ базу dose_adjustments.json per-DB catch-ем — pregnancy/lactation
/// (включая фиксы VV-004/049/050) не доезжали до рантайма вовсе.
void main() {
  test('база корректировок доз парсится ЦЕЛИКОМ', () {
    final raw =
        File('assets/data/advanced/dose_adjustments.json').readAsStringSync();
    final db = DoseAdjustmentDatabase.fromJson(
        jsonDecode(raw) as Map<String, dynamic>);

    expect(db.pregnancy, isNotNull,
        reason: 'До фикса TypeError в age_adjustments глотал всю базу: '
            'pregnancy/lactation были null в рантайме');
    expect(db.age, isNotNull);
  });

  test('age-группы — честные map-ы: описание, «избегать», мониторинг', () {
    final raw =
        File('assets/data/advanced/dose_adjustments.json').readAsStringSync();
    final db = DoseAdjustmentDatabase.fromJson(
        jsonDecode(raw) as Map<String, dynamic>);

    final neonates = db.age!.neonates;
    expect(neonates, isNotNull);
    expect(neonates!.description, isNotEmpty);
    expect(neonates.drugsAvoid, isNotEmpty,
        reason: '«тетрациклины» и пр. обязаны доезжать из базы');
    expect(neonates.safeDrugs, isNotEmpty);

    final geriatric = db.age!.geriatric;
    expect(geriatric, isNotNull);
    expect(geriatric!.monitoring, isNotEmpty);
  });
}
