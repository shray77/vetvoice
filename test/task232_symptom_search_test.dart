import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetvoice_ai/services/symptom_search_service.dart';

/// ⚠ Фикс VV-042 (ревью 26.11.2026): построение индекса симптомов
/// (jsonDecode + CalcDrug.fromJson + _tokenize по ~7 МБ базы) раньше
/// оставалось на главном изоляте (в compute() уходил только jsonDecode) —
/// multi-секундный freeze UI. Теперь индекс строится целиком в
/// background-isolate, RegExp'ы токенизации — статические финальные.
/// Публичный API сервиса (init/search/popularQueries) сохранён.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_mockAssetsChannel);

  test('VV-042: init строит индекс в изоляте, поиск находит препараты',
      () async {
    final service = SymptomSearchService();
    await service.init();

    expect(service.isLoaded, isTrue, reason: 'индекс построен');
    expect(service.indexedDrugs, greaterThan(2000),
        reason: 'индексируется вся база калькулятора (~2400 записей)');

    // «рвота» — из popularQueries: запрос обязан находить препараты
    // (регрессия v1.16.2: кириллица вычищалась из токенов).
    final results = service.search('рвота');
    expect(results, isNotEmpty,
        reason: 'поисковый запрос из popularQueries обязан находить '
            'препараты');
    expect(results.first.matchedTerms, isNotEmpty);
    expect(results.first.drug.name, isNotEmpty);
  });
}

/// Мок канала 'flutter/assets' — rootBundle.loadString виснет без мока
/// (паттерн golden_all_screens_test/withdrawal_test): отдаём
/// assets/data/*.json напрямую с диска.
Future<void> _mockAssetsChannel() async {
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
}
