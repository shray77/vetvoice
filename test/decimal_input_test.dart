import 'package:flutter_test/flutter_test.dart';
import 'package:vetvoice_ai/utils/decimal_input.dart';

/// Гейт-кейсы Task 178: «абсурдные, но реальные» вводы пользователя.
///
/// Регрессия, ради которой всё затевалось: ветеринар на русском телефоне
/// печатает вес «12,5» (decimal-клавиатура RU-локали даёт запятую) —
/// до фикса double.tryParse возвращал null и вес молча становился 0.
void main() {
  group('parseDecimal — ручной ввод с клавиатуры', () {
    test('точка — классический ввод', () {
      expect(parseDecimal('12.5'), 12.5);
    });

    test('запятая — русская локаль (регрессия Task 178)', () {
      expect(parseDecimal('12,5'), 12.5);
    });

    test('запятая с пробелами по краям', () {
      expect(parseDecimal('  12,5 '), 12.5);
    });

    test('целое число', () {
      expect(parseDecimal('15'), 15.0);
    });

    test('пустая строка и пробелы → null (поле очищено)', () {
      expect(parseDecimal(''), isNull);
      expect(parseDecimal('   '), isNull);
    });

    test('мусор → null, не краш', () {
      expect(parseDecimal('м'), isNull);
      expect(parseDecimal('двенадцать'), isNull);
    });

    test('двойной разделитель «12,5,5» → null', () {
      expect(parseDecimal('12,5,5'), isNull);
    });

    test('отрицательное проходит — гвард диапазонов не в парсере', () {
      // Парсер не судит: минус легитимно доезжает до калькулятора,
      // где его обязан отклонить гвард (infusion: w <= 0 → отказ).
      expect(parseDecimal('-5'), -5.0);
    });
  });
}
