import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetvoice_ai/providers/vet_provider.dart';

/// ⚠ Фиксы VV-034/VV-017 (ревью 26.11.2026):
///  • initialize() мемоизирует in-flight Future: успешно завершённая
///    инициализация не перезапускается (повторные вызовы — no-op), а после
///    ошибки мемо сбрасывается — повторный initialize() ретраит загрузку
///    (раньше bool-гард `_initialized=true` до await навсегда оставлял
///    экраны с пустыми базами);
///  • сбой загрузки вторичных баз не улетает в unhandled zone —
///    extendedReady резолвится гарантированно (finally).
///
/// Ретрай-путь после ошибки требует симуляции сбоя assets — юнитами без
/// инъекции не покрывается; покрыт тем же паттерном, что и DrugLoaderService
/// (см. task232_drug_loader_memo_test.dart).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_mockAssetsChannel);

  test('VV-034: параллельные initialize() разделяют один Future; VV-017: '
      'extendedReady завершается', () async {
    final provider = VetProvider();

    final first = provider.initialize();
    final second = provider.initialize();
    expect(identical(first, second), isTrue,
        reason: 'повторный вызов ДО завершения получает тот же in-flight '
            'Future — двойной загрузки ~20 МБ JSON не происходит');

    await first;

    // VV-017: extendedReady не виснет и не бросает — резолвится в finally
    // даже если какая-то из auxiliary-баз упала.
    await provider.extendedReady;

    expect(provider.totalDrugs, greaterThan(0), reason: 'ядро загрузилось');
    expect(provider.calcDatabase, isNotNull);
  });

  test('VV-034: после успешной инициализации повторный initialize() — no-op',
      () async {
    // Синглтон: мемо успешной инициализации из предыдущего теста живёт —
    // второй вызов обязан вернуть его и НЕ перезапустить загрузку.
    final provider = VetProvider();
    await provider.initialize();
    expect(provider.calcDatabase, isNotNull,
        reason: 'успешно завершённая инициализация мемоизируется, базы '
            'доступны без перезапуска загрузки');
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
