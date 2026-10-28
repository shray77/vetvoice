import 'package:flutter_test/flutter_test.dart';
import 'package:vetvoice_ai/services/speech_service.dart';

/// Гейт-кейсы M-6 (Task 183): юнит голосового веса берётся из САМОГО матча,
/// а не из глобальных contains по фразе.
///
/// Регрессия: «котёнок 400 г» (граммы в КОНЦЕ строки) возвращал 400 КГ —
/// contains(' г ') не матчит конец строки, конверсия не срабатывала.
/// Для кошек/кроликов это срезалось валидацией вида, для КРС/лошадей
/// 400 «кг» ехали в расчёт дозы.
void main() {
  group('SpeechService.parseWeight — граммы и юниты из матча', () {
    test('«400 г» в конце строки → 0.4 кг (регрессия M-6)', () {
      expect(SpeechService.parseWeight('котёнок 400 г'), closeTo(0.4, 0.001));
      expect(SpeechService.parseWeight('вес 400 г'), closeTo(0.4, 0.001));
    });

    test('граммы внутри строки → кг', () {
      expect(SpeechService.parseWeight('котёнок 400 грамм'), closeTo(0.4, 0.001));
      expect(SpeechService.parseWeight('щенок весит 35 гр'), closeTo(0.035, 0.001));
      expect(SpeechService.parseWeight('хомяк 50 г'), closeTo(0.05, 0.001));
    });

    test('килограммы работают как раньше', () {
      expect(SpeechService.parseWeight('собака 12,5 кг'), closeTo(12.5, 0.001));
      expect(SpeechService.parseWeight('корова 500 килограмм'), closeTo(500, 0.001));
      expect(SpeechService.parseWeight('вес 12.5'), closeTo(12.5, 0.001));
      expect(SpeechService.parseWeight('корова весит 500'), closeTo(500, 0.001));
    });

    test('тонны конвертируются', () {
      expect(SpeechService.parseWeight('бык 0.5 т'), closeTo(500, 0.001));
      expect(SpeechService.parseWeight('слон 2 тонны'), closeTo(2000, 0.001));
    });

    test('«г» внутри слова не является граммами (паттерн юнита)', () {
      // Явный юнит-паттерн требует границу после «г»: «3 года» НЕ
      // матчится как граммы (после «г» идёт «о»). Что эвристика
      // чисел-без-контекста делает с возрастными фразами — отдельный
      // вопрос (аудит 183, мелочь №10: одиночные «г»/«т» в ключевых
      // словах веса), здесь гейтится только юнит-паттерн.
      final w = SpeechService.parseWeight('собака 3 года');
      expect(w, isNot(closeTo(0.003, 0.0001)),
          reason: '«3 года» не должны превращаться в 3 грамма');
    });
  });
}
