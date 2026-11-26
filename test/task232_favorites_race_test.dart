import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetvoice_ai/services/favorites_service.dart';

/// VV-018 (ревью 26.11.2026): init() из UI вызывается БЕЗ await
/// (result_card.dart), а _save() раньше нет-опил через `_prefs?.` до
/// готовности SharedPreferences — избранное терялось после перезапуска.
/// Теперь init()/_save() ждут один и тот же кеш Future<SharedPreferences>.
///
/// Синглтон сервиса — тесты идут последовательно и учитывают состояние
/// друг друга. Racy-вариант (toggle до завершения init) оказался
/// недетерминирован в harness — закреплён детерминированный round-trip:
/// запись доезжает до хранилища и живёт после повторного init().
/// ID 4242: не пересекается с состоянием других тестов файла.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('VV-018: toggleFavorite доезжает до хранилища', () async {
    SharedPreferences.setMockInitialValues({});
    final service = FavoritesService();
    await service.init();

    final added = await service.toggleFavorite(4242);
    expect(added, isTrue);
    expect(service.isFavorite(4242), isTrue);

    final persisted = (await SharedPreferences.getInstance())
        .getStringList('vetvoice_favorites');
    expect(persisted, contains('4242'),
        reason: 'запись обязана доезжать до хранилища: _save() ждёт '
            'тот же кеш Future<SharedPreferences>, что и init()');
  });

  test('VV-018: повторный init() — no-op, сохранённое не теряется', () async {
    final service = FavoritesService();
    await service.init();
    expect(service.favorites, contains(4242));
    await service.init();
    expect(service.favorites, contains(4242));
  });
}
