// SymptomSearchService — поиск препаратов по показаниям/симптомам.
//
// Использует обратный индекс: для каждого ключевого слова из indications
// хранится список drug_id. При поиске — пересекаем множества.
//
// Источник данных: drugs_calc.json → drug.indications
//
// Использование:
//   final svc = SymptomSearchService();
//   await svc.init();
//   final results = svc.search('рвота у собаки');
//   // results: [{ drug: CalcDrug, score: 3, matched_terms: ['рвота', 'собак'] }]
//
// Алгоритм поиска:
//   1. Нормализуем запрос: lower-case, удаление пунктуации
//   2. Токенизация: разбиваем на слова, убираем стоп-слова
//   3. Для каждого токена ищем в обратном индексе
//   4. Сортируем по количеству совпадений (score)
//   5. Возвращаем top-N результатов

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/calc_drug.dart';

class SearchResult {
  final CalcDrug drug;
  final int score;             // количество совпавших токенов
  final List<String> matchedTerms;

  const SearchResult({
    required this.drug,
    required this.score,
    required this.matchedTerms,
  });
}

class SymptomSearchService {
  static const String _assetPath = 'assets/data/drugs_calc.json';

  // Стоп-слова — не индексируем
  static const Set<String> _stopWords = {
    'и', 'или', 'не', 'на', 'в', 'с', 'по', 'для', 'при', 'к', 'от',
    'до', 'из', 'у', 'о', 'об', 'за', 'что', 'это', 'как', 'так',
    'the', 'a', 'an', 'of', 'for', 'and', 'or', 'to', 'in', 'on',
    'at', 'by', 'with', 'from', 'as',
  };

  final Map<String, Set<int>> _index = {};  // token -> {drug_id, ...}
  final Map<int, CalcDrug> _drugs = {};     // drug_id -> CalcDrug
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  int get indexedDrugs => _drugs.length;

  /// Загрузить базу и построить индекс.
  Future<void> init() async {
    if (_isLoaded) return;
    try {
      final jsonString = await rootBundle.loadString(_assetPath);
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final drugsList = data['drugs_calc'] as List<dynamic>? ?? [];

      for (final drugJson in drugsList) {
        try {
          final drug = CalcDrug.fromJson(drugJson as Map<String, dynamic>);
          _drugs[drug.id] = drug;

          // Индексируем indications + name + inn + category
          final text = '${drug.indications} ${drug.name} ${drug.inn} '
              '${drug.category}';
          final tokens = _tokenize(text);
          for (final token in tokens) {
            _index.putIfAbsent(token, () => {}).add(drug.id);
          }
        } catch (e) {
          debugPrint('SymptomSearch: skip drug #$drugJson: $e');
        }
      }
      _isLoaded = true;
      debugPrint('SymptomSearch: ${_drugs.length} drugs, '
          '${_index.length} unique tokens');
    } catch (e) {
      debugPrint('SymptomSearch init error: $e');
    }
  }

  /// Токенизация текста: lower-case, удаление пунктуации, фильтр стоп-слов.
  List<String> _tokenize(String text) {
    final lower = text.toLowerCase();
    // Удаляем пунктуацию, оставляем буквы/цифры/пробелы
    final cleaned = lower.replaceAll(RegExp(r'[^\w\s\-]'), ' ');
    final tokens = cleaned.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    // Фильтр стоп-слов и слишком коротких
    return tokens
        .where((t) => t.length >= 3 && !_stopWords.contains(t))
        .toList();
  }

  /// Поиск препаратов по запросу.
  ///
  /// Возвращает список, отсортированный по убыванию score.
  /// [limit] — максимальное число результатов (по умолчанию 20).
  List<SearchResult> search(String query, {int limit = 20}) {
    if (!_isLoaded || query.trim().isEmpty) return [];

    final tokens = _tokenize(query);
    if (tokens.isEmpty) return [];

    // Подсчёт совпадений для каждого препарата
    final Map<int, int> scores = {};        // drug_id -> score
    final Map<int, Set<String>> matched = {}; // drug_id -> matched terms

    for (final token in tokens) {
      // Точное совпадение
      final ids = _index[token];
      if (ids != null) {
        for (final id in ids) {
          scores[id] = (scores[id] ?? 0) + 2;  // точное = 2 очка
          matched.putIfAbsent(id, () => {}).add(token);
        }
      }
      // Частичное совпадение (начинается с токена)
      _index.forEach((key, ids) {
        if (key.startsWith(token) && key != token) {
          for (final id in ids) {
            scores[id] = (scores[id] ?? 0) + 1;  // частичное = 1 очко
            matched.putIfAbsent(id, () => {}).add(token);
          }
        }
      });
    }

    // Сортируем по score (убывание)
    final sortedIds = scores.keys.toList()
      ..sort((a, b) => scores[b]!.compareTo(scores[a]!));

    return sortedIds.take(limit).map((id) {
      return SearchResult(
        drug: _drugs[id]!,
        score: scores[id]!,
        matchedTerms: matched[id]!.toList(),
      );
    }).toList();
  }

  /// Получить популярные поисковые запросы (для подсказок).
  List<String> get popularQueries => [
    'рвота у собаки',
    'понос у кошки',
    'глисты у кота',
    'блохи у собаки',
    'кашель у собаки',
    'ушная инфекция',
    'глазные капли',
    'обезболивающее',
    'антибиотик широкого спектра',
    'противовоспалительное',
    'температура у коровы',
    'мастит у коровы',
    'копытная гниль',
    'вакцина от бешенства',
    'дегельминтизация',
  ];
}
