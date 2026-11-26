import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetvoice_ai/services/history_service.dart';

/// ⚠ Фикс VV-018 (ревью 26.11.2026): init() из UI вызывается БЕЗ await
/// (result_card.dart), а _save() нет-опил через `_prefs?.` до готовности
/// SharedPreferences — запись истории жила только в памяти и пропадала
/// после перезапуска. Теперь init()/_save() ждут один и тот же кеш
/// Future<SharedPreferences> — гонка исчезла без правок виджетов.
///
/// SharedPreferences мокается штатным setMockInitialValues (без плагина
/// сервис не тестируется).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('VV-018: addCalculation без await init() доезжает до хранилища',
      () async {
    SharedPreferences.setMockInitialValues({});
    final service = HistoryService();

    // Как в result_card.dart: init() НЕ await-ится.
    final initFuture = service.init();

    // Мгновенный расчёт до завершения init().
    await service.addCalculation(
      drugId: 5,
      drugName: 'Маропитант',
      inn: 'маропитант',
      animal: 'Собаки',
      weightKg: 12.5,
      dosePerKg: 1.0,
      volumeMl: 2.5,
      method: 'внутримышечно',
      frequency: '1 раз в день',
    );

    await initFuture;

    // Запись обязана доехать до хранилища: раньше _save() нет-опил
    // (SharedPreferences ещё не готов) — после перезапуска история была
    // пуста.
    final persisted =
        (await SharedPreferences.getInstance()).getString('vetvoice_history');
    expect(persisted, isNotNull,
        reason: 'гонка init()/запись: _save() обязан ждать prefs, '
            'а не молча пропускать запись');

    final list = jsonDecode(persisted!) as List<dynamic>;
    expect(list, hasLength(1));
    final entry = list.first as Map<String, dynamic>;
    expect(entry['drug_name'], 'Маропитант');
    expect(entry['volume_ml'], 2.5);
  });

  test('VV-018: повторный init() — no-op, удаление доезжает до хранилища',
      () async {
    // Мемо init() у синглтона уже готов (прошлый тест): повторный вызов —
    // no-op, в памяти остаётся запись (перезапуск-сессия покрыта прямым
    // чтением JSON из хранилища в тесте выше).
    final service = HistoryService();
    await service.init();

    expect(service.history, hasLength(1),
        reason: 'идемпотентный init() не затирает состояние сессии');
    expect(service.history.first.drugName, 'Маропитант');

    // И удаление доезжает до хранилища.
    await service.removeAt(0);
    final persisted =
        (await SharedPreferences.getInstance()).getString('vetvoice_history');
    expect(jsonDecode(persisted!) as List<dynamic>, isEmpty);
  });
}
