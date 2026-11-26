// FavoritesService — управление избранными препаратами.
//
// Использует SharedPreferences для持久ного хранения списка drug_id.
// Не требует сервера/BD — всё локально.
//
// Использование:
//   final favService = FavoritesService();
//   await favService.init();
//   await favService.toggleFavorite(123);
//   final isFav = favService.isFavorite(123);
//   final favIds = favService.favorites;  // List<int>
//
// В UI:
//   IconButton(
//     icon: Icon(favService.isFavorite(drug.id) ? Icons.star : Icons.star_border),
//     onPressed: () => favService.toggleFavorite(drug.id),
//   )

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService extends ChangeNotifier {
  // v1.16.1: синглтон — один инстанс между result_card и favorites_screen.
  FavoritesService._internal();
  static final FavoritesService _instance = FavoritesService._internal();
  factory FavoritesService() => _instance;

  static const String _key = 'vetvoice_favorites';
  static const int _maxFavorites = 200;  // ограничение, чтобы не засорять

  List<int> _favorites = [];

  // ⚠ Фикс VV-018 (ревью 26.11.2026): кеш Future<SharedPreferences>.
  // init() из UI вызывается БЕЗ await (result_card.dart), а _save() работал
  // через `_prefs?.` и до завершения getInstance() молча нет-опил: состояние
  // в памяти расходилось с диском и пропадало после перезапуска. Теперь
  // init() и _save() ждут один и тот же Future — гонка исчезла без правок
  // виджетов. Неудача в кеше не оседает — повторный вызов ретраит.
  Future<SharedPreferences>? _prefsFuture;
  Future<void>? _initFuture;

  /// Единая точка доступа к SharedPreferences: один Future на сессию —
  /// его ждут и init(), и _save().
  Future<SharedPreferences> _getPrefs() {
    final cached = _prefsFuture;
    if (cached != null) return cached;
    final future = SharedPreferences.getInstance();
    return _prefsFuture = future.then(
      (prefs) => prefs,
      onError: (Object e) {
        _prefsFuture = null; // transient-сбой плагина — кеш сбрасываем
        throw e;
      },
    );
  }

  /// Список ID избранных препаратов (отсортирован: свежие — в начале).
  List<int> get favorites => List.unmodifiable(_favorites);

  /// Инициализация — загрузка из SharedPreferences.
  /// Идемпотентна: повторные вызовы — no-op. Вызывается при старте приложения.
  ///
  /// VV-018: мемоизируется in-flight Future (не bool-флаг): параллельные
  /// init() разделяют одну загрузку, после успеха повторный вызов — no-op,
  /// после неудачи — ретрай.
  Future<void> init() {
    final inFlight = _initFuture;
    if (inFlight != null) return inFlight;
    final future = _init();
    _initFuture = future;
    return future;
  }

  Future<void> _init() async {
    try {
      _loadFavorites(await _getPrefs());
    } catch (e) {
      _initFuture = null; // неудача не мемоизируется — ретрай возможен
      rethrow;
    }
  }

  void _loadFavorites(SharedPreferences prefs) {
    final list = prefs.getStringList(_key) ?? [];
    _favorites = list.map((s) => int.tryParse(s) ?? 0).where((n) => n > 0).toList();
    notifyListeners();
  }

  Future<void> _save() async {
    // VV-018: ждём тот же Future, что и init() — запись больше не теряется
    // в гонке «init() без await + мгновенный тумблер звезды».
    final prefs = await _getPrefs();
    final list = _favorites.map((n) => n.toString()).toList();
    await prefs.setStringList(_key, list);
  }

  /// Проверить, в избранном ли препарат.
  bool isFavorite(int drugId) {
    return _favorites.contains(drugId);
  }

  /// Добавить в избранное (если ещё не там).
  /// Возвращает true если добавлено, false если уже было.
  Future<bool> addToFavorites(int drugId) async {
    if (_favorites.contains(drugId)) return false;
    _favorites.insert(0, drugId);  // в начало — свежие сверху
    // Если превышен лимит — удаляем самый старый
    if (_favorites.length > _maxFavorites) {
      _favorites = _favorites.sublist(0, _maxFavorites);
    }
    await _save();
    notifyListeners();
    return true;
  }

  /// Убрать из избранного.
  /// Возвращает true если удалено.
  Future<bool> removeFromFavorites(int drugId) async {
    final removed = _favorites.remove(drugId);
    if (removed) {
      await _save();
      notifyListeners();
    }
    return removed;
  }

  /// Переключить состояние (добавить/убрать).
  /// Возвращает новое состояние (true — в избранном).
  Future<bool> toggleFavorite(int drugId) async {
    if (isFavorite(drugId)) {
      await removeFromFavorites(drugId);
      return false;
    } else {
      await addToFavorites(drugId);
      return true;
    }
  }

  /// Очистить всё избранное.
  Future<void> clear() async {
    _favorites.clear();
    await _save();
    notifyListeners();
  }
}
