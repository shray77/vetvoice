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
  static const String _key = 'vetvoice_favorites';
  static const int _maxFavorites = 200;  // ограничение, чтобы не засорять

  SharedPreferences? _prefs;
  List<int> _favorites = [];

  /// Список ID избранных препаратов (отсортирован: свежие — в начале).
  List<int> get favorites => List.unmodifiable(_favorites);

  /// Инициализация — загрузка из SharedPreferences.
  /// Вызывается один раз при старте приложения.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadFavorites();
  }

  void _loadFavorites() {
    final list = _prefs?.getStringList(_key) ?? [];
    _favorites = list.map((s) => int.tryParse(s) ?? 0).where((n) => n > 0).toList();
    notifyListeners();
  }

  Future<void> _save() async {
    final list = _favorites.map((n) => n.toString()).toList();
    await _prefs?.setStringList(_key, list);
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
