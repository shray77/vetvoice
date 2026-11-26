import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetvoice_ai/services/gigaam_service.dart';

/// Task 232: ревью 26.11.2026 блок B (гонки/краши сервисов речи).
///
/// VV-036: мемоизация in-flight Future в GigaAmService.initialize(). Сам
/// сервис инстанцировать нельзя (конструктор регистрирует method call
/// handler и лезет в SharedPreferences → платформенный канал), поэтому
/// мемоизация вынесена в @visibleForTesting-хелпер InFlightFuture и
/// тестируется напрямую:
/// - параллельные initialize() (тумблер setEnabled(true) + кнопка
///   «Загрузить» в gigaam_status_bar) получают один и тот же Future,
///   нативная загрузка модели не дёргается дважды;
/// - после завершения задачи следующий вызов запускает её заново;
/// - упавшая задача не оставляет мемоизацию «зависшей» (иначе все
///   последующие initialize() навсегда возвращали бы ошибочный Future).
void main() {
  group('InFlightFuture (VV-036: мемоизация in-flight initialize)', () {
    test('параллельные вызовы получают один Future, задача запускается один раз',
        () async {
      final inflight = InFlightFuture<bool>();
      var started = 0;
      final completer = Completer<bool>();
      Future<bool> task() {
        started++;
        return completer.future;
      }

      final first = inflight.run(task);
      final second = inflight.run(task); // «кнопка Загрузить» поверх тумблера

      expect(started, 1, reason: 'нативный initialize() не должен дёргаться дважды');
      expect(identical(first, second), isTrue, reason: 'параллельные вызовы делят один Future');
      expect(inflight.isRunning, isTrue);

      completer.complete(true);
      expect(await first, true);
      expect(await second, true);
      expect(inflight.isRunning, isFalse);
    });

    test('после завершения задачи следующий вызов запускает её заново',
        () async {
      final inflight = InFlightFuture<bool>();
      var started = 0;
      Future<bool> task() {
        started++;
        return Future<bool>.value(true);
      }

      await inflight.run(task); // первая загрузка завершилась
      expect(inflight.isRunning, isFalse);

      final result = await inflight.run(task); // повторный вызов — новая задача
      expect(result, true);
      expect(started, 2);
    });

    test('ошибка задачи не оставляет мемоизацию зависшей', () async {
      final inflight = InFlightFuture<bool>();
      var started = 0;
      Future<bool> task() {
        started++;
        return Future<bool>.error('native init failed');
      }

      await expectLater(inflight.run(task), throwsA('native init failed'));
      expect(inflight.isRunning, isFalse, reason: 'после ошибки слот свободен');

      // Следующий вызов должен запустить задачу заново, а не получить
      // закешированный ошибочный Future.
      await expectLater(inflight.run(task), throwsA('native init failed'));
      expect(started, 2);
    });
  });
}
