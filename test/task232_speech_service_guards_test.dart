import 'package:flutter_test/flutter_test.dart';
import 'package:vetvoice_ai/services/speech_service.dart';

/// Task 232: ревью 26.11.2026 блок B (гонки/краши сервисов речи).
///
/// Чисто Dart-юнит-тесты guard-логики БЕЗ плагинов: сам SpeechService
/// инстанцировать нельзя (конструктор создаёт SpeechToText/FlutterTts и
/// дёргает синглтон GigaAmService → платформенные каналы), поэтому логика
/// вынесена в @visibleForTesting-хелперы (SpeakGuard, SpeechRestartScheduler)
/// и тестируется напрямую.
///
/// Покрывается:
/// - VV-039: счётчик параллельных speak() — эхо-защита снимается только
///   когда обнулился (completion первой озвучки больше не открывает
///   микрофон поверх второй);
/// - VV-014: отложенные рестарты hands-free живут в планировщике и
///   гасятся в dispose() — после dispose колбэк не выполняется и новые
///   рестарты не планируются;
/// - VV-041: явная остановка (cancelAll) отменяет отложенные рестарты,
///   планировщик остаётся рабочим; повторный schedule с тем же ключом
///   заменяет предыдущий таймер.
void main() {
  group('SpeakGuard (VV-039: счётчик параллельных озвучек)', () {
    test('эхо-защита держится, пока говорит хоть одна из параллельных озвучек',
        () {
      final guard = SpeakGuard();
      expect(guard.isSpeaking, isFalse, reason: 'до озвучек микрофон свободен');

      guard.begin(); // первая озвучка
      guard.begin(); // вторая параллельная
      expect(guard.active, 2);
      expect(guard.isSpeaking, isTrue);

      // Completion первой озвучки — вторая ещё говорит: защита НЕ снимается.
      expect(guard.end(), isFalse, reason: 'вторая озвучка ещё говорит');
      expect(guard.isSpeaking, isTrue);

      // Закончила вторая — только теперь защиту можно снять.
      expect(guard.end(), isTrue);
      expect(guard.isSpeaking, isFalse);
    });

    test('end() сверх нуля не уводит счётчик в минус (страховка finally)', () {
      final guard = SpeakGuard();
      guard.begin();
      expect(guard.end(), isTrue);
      // Двойной finally (например, сбой плагина после завершения) не должен
      // «открыть» несуществующую третью озвучку со знаком минус.
      expect(guard.end(), isFalse);
      expect(guard.active, 0);
      expect(guard.isSpeaking, isFalse);
    });

    test('reset() (ручная остановка TTS) открывает микрофон сразу', () {
      final guard = SpeakGuard();
      guard.begin();
      guard.begin();
      guard.reset();
      expect(guard.active, 0);
      expect(guard.isSpeaking, isFalse);
    });
  });

  group('SpeechRestartScheduler (VV-014/VV-041: отложенные рестарты)', () {
    test('dispose() гасит запланированный рестарт — колбэк не выполняется',
        () async {
      final scheduler = SpeechRestartScheduler();
      var fired = 0;
      scheduler.schedule(
        'afterTts',
        const Duration(milliseconds: 20),
        () => fired++,
      );
      expect(scheduler.isPending('afterTts'), isTrue);

      scheduler.dispose(); // dispose() сервиса
      expect(scheduler.isPending('afterTts'), isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(fired, 0, reason: 'рестарт мёртвого сервиса не должен сработать');
    });

    test('после dispose() новые рестарты не планируются (VV-014)', () async {
      final scheduler = SpeechRestartScheduler();
      scheduler.dispose();
      var fired = 0;
      scheduler.schedule('afterError', Duration.zero, () => fired++);
      expect(scheduler.isPending('afterError'), isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(fired, 0);
    });

    test('cancelAll() (явная остановка прослушивания) отменяет рестарты,\n'
        'но планировщик остаётся рабочим (VV-041)', () async {
      final scheduler = SpeechRestartScheduler();
      var fired = 0;
      scheduler.schedule(
        'afterResult',
        const Duration(milliseconds: 20),
        () => fired++,
      );
      scheduler.cancelAll(); // stopListening()
      expect(scheduler.isPending('afterResult'), isFalse);

      // После явной остановки hands-free может включиться снова —
      // новый рестарт должен спланироваться и выполниться.
      scheduler.schedule(
        'afterResult',
        const Duration(milliseconds: 20),
        () => fired++,
      );
      expect(scheduler.isPending('afterResult'), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(fired, 1, reason: 'выполняется только новый рестарт, старый отменён');
    });

    test('повторный schedule с тем же ключом заменяет предыдущий таймер',
        () async {
      final scheduler = SpeechRestartScheduler();
      var first = 0;
      var second = 0;
      scheduler.schedule(
        'afterResult',
        const Duration(milliseconds: 20),
        () => first++,
      );
      scheduler.schedule(
        'afterResult',
        const Duration(milliseconds: 20),
        () => second++,
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(first, 0, reason: 'старый таймер заменён, а не накоплен');
      expect(second, 1);
    });
  });
}
