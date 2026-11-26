import 'package:flutter_test/flutter_test.dart';
import 'package:vetvoice_ai/screens/history_screen.dart';

/// D12 (ревью 26.11.2026): диалог очистки истории говорил
/// «Будет удалено 1 записей». Хелпер pluralizeRu (history_screen.dart)
/// теперь используют история («запись») и избранное («препарат»).
void main() {
  group('D12: pluralizeRu — русская плюрализация', () {
    test('одна форма: 1, 21, 101, 1001', () {
      for (final n in [1, 21, 101, 1001]) {
        expect(pluralizeRu(n, 'запись', 'записи', 'записей'), 'запись',
            reason: '$n запись');
      }
    });

    test('мало: 2-4, 22-24, 102-104', () {
      for (final n in [2, 3, 4, 22, 23, 24, 102, 103, 104]) {
        expect(pluralizeRu(n, 'запись', 'записи', 'записей'), 'записи',
            reason: '$n записи');
      }
    });

    test('много: 0, 5-20, 11-14, 100, 111, 1000', () {
      for (final n in [0, 5, 10, 11, 12, 13, 14, 20, 100, 111, 1000]) {
        expect(pluralizeRu(n, 'запись', 'записи', 'записей'), 'записей',
            reason: '$n записей');
      }
    });

    test('historyRecordsPlural — случаи диалога очистки истории', () {
      expect(historyRecordsPlural(1), 'запись');
      expect(historyRecordsPlural(2), 'записи');
      expect(historyRecordsPlural(5), 'записей');
      expect(historyRecordsPlural(11), 'записей');
      expect(historyRecordsPlural(21), 'запись');
      expect(historyRecordsPlural(50), 'записей');
    });

    test('препараты (избранное): 1 препарат / 2 препарата / 5 препаратов', () {
      expect(pluralizeRu(1, 'препарат', 'препарата', 'препаратов'), 'препарат');
      expect(pluralizeRu(2, 'препарат', 'препарата', 'препаратов'), 'препарата');
      expect(
          pluralizeRu(5, 'препарат', 'препарата', 'препаратов'), 'препаратов');
      expect(
          pluralizeRu(2401, 'препарат', 'препарата', 'препаратов'),
          'препарат',
          reason: '2401 % 100 = 01 — форма «одна»');
    });

    test('протоколы и взаимодействия (настройки): 124 протокола / 73 взаимодействия', () {
      expect(
          pluralizeRu(124, 'протокол', 'протокола', 'протоколов'), 'протокола');
      expect(pluralizeRu(73, 'взаимодействие', 'взаимодействия',
          'взаимодействий'),
          'взаимодействия');
    });
  });
}
