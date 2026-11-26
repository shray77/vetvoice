import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetvoice_ai/services/drug_loader_service.dart';

/// ⚠ Фикс VV-035 (ревью 26.11.2026): мемоизировался РЕЗУЛЬТАТ, а не in-flight
/// Future — два параллельных loadCore() успевали ОБА пройти проверку
/// `_coreMemo == null` и запускали по два _loadRaws() (~20 МБ JSON) и по
/// два набора compute() — двойной memory spike и тормоза старта. Теперь
/// первый вызов создаёт Future, параллельный получает ТОТ ЖЕ.
///
/// Ретрай-ветка (сброс мемо при ошибке загрузки) требует симуляции сбоя
/// assets — без инъекции юнитами не покрывается: сброс происходит в catch
/// того же метода и тривиален (см. _loadCoreOnce/_loadOnce).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_mockAssetsChannel);

  test('VV-035: параллельные loadCore() разделяют один in-flight Future',
      () async {
    final first = DrugLoaderService.loadCore();
    final second = DrugLoaderService.loadCore();

    expect(identical(first, second), isTrue,
        reason: 'второй вызов обязан получить тот же Future, а не запускать '
            'вторую загрузку ~20 МБ JSON и второй набор compute()');

    final result = await first;
    expect(result.calcDatabase, isNotNull, reason: 'ядро загрузилось');
    expect(result.registry, isNotNull);
    expect(result.dosageDatabase, isNotNull);
  });

  test('VV-035 + VV-033: после успеха повторный loadCore() — тот же результат',
      () async {
    final again = DrugLoaderService.loadCore();
    final result = await again;

    // Мемоизированная загрузка отдаёт ядро целиком, а частичная потеря
    // базы дозировок (VV-033) не происходит: 671 МНН, 0 пропущено.
    expect(result.dosageDatabase?.dosages.length, 671);
    expect(result.skippedDosageCount, 0,
        reason: 'реальная база дозировок парсится без потерь (per-item '
            'защита VV-033 + проброс skippedCount в LoadResult)');
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
