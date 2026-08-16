import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/calc_drug.dart';
import '../providers/vet_provider.dart';

class SearchResult {
  final CalcDrug drug;
  final int score;
  final List<String> matchedTerms;

  const SearchResult({
    required this.drug,
    required this.score,
    required this.matchedTerms,
  });
}

/// Сервис полнотекстового и семантического поиска препаратов по симптомам, показаниям и синдромам
class SymptomSearchService {
  static final SymptomSearchService _instance = SymptomSearchService._internal();
  factory SymptomSearchService() => _instance;
  SymptomSearchService._internal();

  static const String _assetPath = 'assets/data/drugs_calc.json';

  static const Set<String> _stopWords = {
    'и', 'или', 'не', 'на', 'в', 'с', 'по', 'для', 'при', 'к', 'от',
    'до', 'из', 'у', 'о', 'об', 'за', 'что', 'это', 'как', 'так',
    'the', 'a', 'an', 'of', 'for', 'and', 'or', 'to', 'in', 'on',
    'at', 'by', 'with', 'from', 'as',
  };

  // Русские окончания для стемминга
  static const List<String> _russianEndings = [
    'ами', 'ями', 'ого', 'его', 'ому', 'ему', 'ыми', 'ими',
    'ых', 'их', 'ой', 'ей', 'ам', 'ям', 'ов', 'ев', 'ах', 'ях',
    'ия', 'ии', 'ию', 'ие', 'ые', 'ое', 'ая', 'яя', 'ую', 'юю',
    'ат', 'ят', 'ет', 'ит', 'ть', 'ти', 'ся', 'сь',
    'а', 'я', 'у', 'ю', 'е', 'о', 'ы', 'и', 'ь',
  ];

  // Синонимы и связанные термины в ветеринарии
  static const Map<String, List<String>> _synonyms = {
    'рвот': ['тошнот', 'рвотн', 'маропитант', 'церукал', 'метоклопрамид', 'гастрит'],
    'тошнот': ['рвот', 'рвотн'],
    'понос': ['диаре', 'энтерит', 'жидк стул', 'колит', 'гастроэнтерит'],
    'диаре': ['понос', 'энтерит', 'колит', 'гастроэнтерит'],
    'мастит': ['вымя', 'маститн', 'молочн желез'],
    'отит': ['ушн', 'ух', 'слухов проход'],
    'ух': ['отит', 'ушн'],
    'зуд': ['дерматит', 'аллерги', 'чешет', 'алопеци', 'кожи', 'экзем'],
    'блох': ['клещ', 'эктопаразит', 'инсектоакарицид', 'акарицид', 'инсектицид', 'фипронил'],
    'клещ': ['блох', 'эктопаразит', 'инсектоакарицид', 'акарицид', 'пироплазмоз', 'бабезиоз'],
    'глист': ['гельминт', 'нематод', 'цестод', 'дегельминтизац', 'паразит', 'аскарид'],
    'гельминт': ['глист', 'нематод', 'цестод', 'дегельминтизац'],
    'глаз': ['конъюнктивит', 'кератит', 'глазн', 'слезотечен', 'блефарит'],
    'конъюнктивит': ['глаз', 'кератит', 'глазн'],
    'сустав': ['артрит', 'артроз', 'хромот', 'нпвс', 'бол', 'синовит'],
    'бол': ['обезболиван', 'анальгези', 'нпвс', 'спазм', 'воспален', 'мелоксикам'],
    'температур': ['лихорадк', 'жар', 'гипертерми', 'жаропонижающ'],
    'лихорадк': ['температур', 'жар', 'гипертерми'],
    'кашел': ['бронхит', 'пневмони', 'трахеит', 'легк', 'дыхательн'],
    'пневмони': ['кашел', 'бронхит', 'легк', 'антибиотик'],
    'ран': ['язв', 'порез', 'заживлен', 'антисептик', 'травм', 'шов'],
    'сердц': ['кардио', 'сердечн', 'миокард', 'ветмедин', 'пимобендан', 'хсн'],
    'почк': ['нефрит', 'почечн', 'хпн', 'цистит', 'урологич'],
    'цистит': ['почк', 'мочеиспускан', 'мочев', 'урологич'],
    'печен': ['гепатит', 'печеночн', 'гепатопротектор'],
  };

  static const Map<String, String> _speciesKeywords = {
    'собак': 'Собаки',
    'пёс': 'Собаки',
    'пес': 'Собаки',
    'щен': 'Собаки',
    'кошк': 'Кошки',
    'кот': 'Кошки',
    'котят': 'Кошки',
    'коров': 'КРС',
    'бык': 'КРС',
    'теленок': 'КРС',
    'телёнок': 'КРС',
    'крс': 'КРС',
    'свин': 'Свиньи',
    'порос': 'Свиньи',
    'хряк': 'Свиньи',
    'овц': 'Овцы',
    'баран': 'Овцы',
    'ягнен': 'Овцы',
    'коз': 'Овцы',
    'лошад': 'Лошади',
    'кон': 'Лошади',
    'жереб': 'Лошади',
    'птиц': 'Птица',
    'кур': 'Птица',
    'цыплен': 'Птица',
    'кролик': 'Кролики',
  };

  final Map<String, Set<int>> _index = {};
  final Map<int, CalcDrug> _drugs = {};
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  int get indexedDrugs => _drugs.length;

  /// Инициализация индекса (из VetProvider или файла)
  Future<void> init() async {
    if (_isLoaded && _drugs.isNotEmpty) return;

    try {
      // 1. Пробуем взять уже загруженные данные из VetProvider (0 мс задержки)
      final provider = VetProvider();
      if (provider.allCalcDrugs.isNotEmpty) {
        _buildIndexFromDrugs(provider.allCalcDrugs);
        _isLoaded = true;
        debugPrint('✅ SymptomSearch: быстрый старт из VetProvider (${_drugs.length} преп., ${_index.length} токенов)');
        return;
      }

      // 2. Иначе парсим в фоне через Isolate
      final jsonString = await rootBundle.loadString(_assetPath);
      final rawList = await Isolate.run(() {
        final data = jsonDecode(jsonString) as Map<String, dynamic>;
        return (data['drugs_calc'] as List<dynamic>? ?? []);
      });

      final drugs = <CalcDrug>[];
      for (final item in rawList) {
        if (item is Map<String, dynamic>) {
          try {
            drugs.add(CalcDrug.fromJson(item));
          } catch (_) {}
        }
      }

      _buildIndexFromDrugs(drugs);
      _isLoaded = true;
      debugPrint('✅ SymptomSearch: фоновая загрузка (${_drugs.length} преп., ${_index.length} токенов)');
    } catch (e) {
      debugPrint('❌ SymptomSearch init error: $e');
    }
  }

  void _buildIndexFromDrugs(List<CalcDrug> drugs) {
    _drugs.clear();
    _index.clear();

    for (final drug in drugs) {
      _drugs[drug.id] = drug;

      final text = '${drug.name} ${drug.inn} ${drug.indications} ${drug.category} '
          '${drug.subcategory ?? ""} ${drug.animals.join(" ")}';
      final tokens = _tokenize(text);

      for (final token in tokens) {
        _index.putIfAbsent(token, () => {}).add(drug.id);
      }
    }
  }

  /// Стемминг русского слова (усечение окончаний)
  static String _stem(String word) {
    word = word.toLowerCase().trim();
    if (word.length <= 3) return word;
    for (final ending in _russianEndings) {
      if (word.endsWith(ending) && (word.length - ending.length) >= 3) {
        return word.substring(0, word.length - ending.length);
      }
    }
    return word;
  }

  /// Корректная токенизация с поддержкой русского языка
  List<String> _tokenize(String text) {
    final lower = text.toLowerCase();
    // Сохраняем кириллицу, латиницу, цифры и дефис
    final cleaned = lower.replaceAll(RegExp(r'[^a-zа-яё0-9\s\-]'), ' ');
    final rawTokens = cleaned.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);

    final result = <String>{};
    for (final t in rawTokens) {
      if (t.length >= 3 && !_stopWords.contains(t)) {
        result.add(_stem(t));
      }
    }
    return result.toList();
  }

  /// Полнотекстовый и синонимический поиск по симптомам
  List<SearchResult> search(String query, {String? animalFilter, int limit = 30}) {
    if (!_isLoaded && _drugs.isEmpty) {
      final provider = VetProvider();
      if (provider.allCalcDrugs.isNotEmpty) {
        _buildIndexFromDrugs(provider.allCalcDrugs);
        _isLoaded = true;
      }
    }

    if (query.trim().isEmpty) return [];

    final rawTokens = _tokenize(query);
    if (rawTokens.isEmpty) return [];

    // Определяем вид животного из запроса или фильтра
    String? targetAnimal = animalFilter;
    for (final token in rawTokens) {
      if (_speciesKeywords.containsKey(token)) {
        targetAnimal = _speciesKeywords[token];
        break;
      }
    }

    // Расширяем токены синонимами
    final queryTokens = <String>{...rawTokens};
    for (final token in rawTokens) {
      if (_synonyms.containsKey(token)) {
        queryTokens.addAll(_synonyms[token]!);
      }
      _synonyms.forEach((key, synList) {
        if (key.startsWith(token) || token.startsWith(key)) {
          queryTokens.addAll(synList);
        }
      });
    }

    final Map<int, int> scores = {};
    final Map<int, Set<String>> matched = {};

    for (final token in queryTokens) {
      final isOriginalToken = rawTokens.contains(token);
      final weightMultiplier = isOriginalToken ? 3 : 1;

      // 1. Точное совпадение основы
      final exactIds = _index[token];
      if (exactIds != null) {
        for (final id in exactIds) {
          scores[id] = (scores[id] ?? 0) + (3 * weightMultiplier);
          matched.putIfAbsent(id, () => {}).add(token);
        }
      }

      // 2. Префиксное совпадение
      _index.forEach((key, ids) {
        if (key != token && (key.startsWith(token) || token.startsWith(key))) {
          for (final id in ids) {
            scores[id] = (scores[id] ?? 0) + (1 * weightMultiplier);
            matched.putIfAbsent(id, () => {}).add(key);
          }
        }
      });
    }

    // Бонус за соответствие животному
    if (targetAnimal != null && targetAnimal.isNotEmpty) {
      for (final id in scores.keys.toList()) {
        final drug = _drugs[id];
        if (drug != null && drug.isForAnimal(targetAnimal)) {
          scores[id] = (scores[id] ?? 0) + 5;
        }
      }
    }

    // Сортировка по очкам
    final sortedIds = scores.keys.toList()
      ..sort((a, b) {
        final scoreCmp = scores[b]!.compareTo(scores[a]!);
        if (scoreCmp != 0) return scoreCmp;
        // При равных очках предпочтение препаратам с дозировкой
        final drugA = _drugs[a]!;
        final drugB = _drugs[b]!;
        return (drugB.dosePerKg > 0 ? 1 : 0).compareTo(drugA.dosePerKg > 0 ? 1 : 0);
      });

    return sortedIds.take(limit).map((id) {
      return SearchResult(
        drug: _drugs[id]!,
        score: scores[id]!,
        matchedTerms: matched[id]!.take(4).toList(),
      );
    }).toList();
  }

  /// Популярные частые запросы для ветеринаров
  List<String> get popularQueries => [
    'рвота у собаки',
    'понос у кошки',
    'мастит у коров',
    'отит у собак',
    'зуд и аллергия',
    'блохи и клещи',
    'глисты у щенка',
    'конъюнктивит',
    'артрит и хромота',
    'пневмония и кашель',
    'обезболивание после операции',
    'интоксикация и отравление',
  ];
}
