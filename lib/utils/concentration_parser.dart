/// Утилита для парсинга концентрации из состава препарата
class ConcentrationParser {
  /// Парсит концентрацию из текста состава
  /// Возвращает Map с названием вещества и концентрацией в мг/мл
  static Map<String, double> parseFromComposition(String composition) {
    final result = <String, double>{};
    if (composition.isEmpty) return result;

    final lower = composition.toLowerCase();

    // Паттерны для поиска концентрации
    // "в 1 мл ... содержит 100 мг ..."
    // "в качестве действующего вещества ... - 100 мг"
    // "... 100 мг/мл ..."
    // "... 100 мг в 1 мл"

    final patterns = [
      // "в 1 мл ... содержит X мг"
      RegExp(r'в\s*1\s*мл[^.]*?(\d+(?:[.,]\d+)?)\s*мг'),
      // "X мг/мл"
      RegExp(r'(\d+(?:[.,]\d+)?)\s*мг\s*[/\\]\s*мл'),
      // "X мг в 1 мл"
      RegExp(r'(\d+(?:[.,]\d+)?)\s*мг[^.]*?в\s*1\s*мл'),
      // "содержит ... X мг"
      RegExp(r'содержит[^.]*?(\d+(?:[.,]\d+)?)\s*мг'),
      // "... - X мг/мл"
      RegExp(r'[—–-]\s*(\d+(?:[.,]\d+)?)\s*мг\s*[/\\]\s*мл'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(lower);
      if (match != null) {
        final value = double.tryParse(match.group(1)!.replaceAll(',', '.'));
        if (value != null && value > 0) {
          // Пытаемся определить вещество
          final substance = _extractSubstance(composition);
          if (substance.isNotEmpty) {
            result[substance] = value;
          } else {
            result['main'] = value;
          }
          break;
        }
      }
    }

    return result;
  }

  /// Извлекает название активного вещества из состава
  static String _extractSubstance(String composition) {
    // Ищем паттерны типа "флорфеникола", "амоксициллин" и т.д.
    final substancePattern = RegExp(
      r'(?:действующ(?:его|ее|им)\s*(?:веществ(?:а|о)|веществом)[^.]*)?'
      r'(\b[a-zа-яё]{4,}(?:ин|ол|ил|ид|ан|он|ат|ит)?\b)'
      r'\s*[—–-]?\s*(\d+(?:[.,]\d+)?)\s*мг',
      caseSensitive: false,
    );

    final match = substancePattern.firstMatch(composition);
    if (match != null) {
      return match.group(1)!.toLowerCase().trim();
    }

    return '';
  }

  /// Парсит концентрацию из поля дозировки
  static double parseFromDosageField(String dosage) {
    if (dosage.isEmpty) return 0;

    // "100 мг" -> 100 мг/мл (предполагаем)
    // "100 мг/мл" -> 100
    // "10%" -> 100 мг/мл (10% = 100 мг/мл для многих веществ)

    final lower = dosage.toLowerCase();

    // "X мг/мл"
    final mgPerMl = RegExp(r'(\d+(?:[.,]\d+)?)\s*мг\s*[/\\]\s*мл');
    var match = mgPerMl.firstMatch(lower);
    if (match != null) {
      return double.tryParse(match.group(1)!.replaceAll(',', '.')) ?? 0;
    }

    // "X%" - конвертируем в мг/мл (примерно)
    final percent = RegExp(r'(\d+(?:[.,]\d+)?)\s*%');
    match = percent.firstMatch(lower);
    if (match != null) {
      final pct = double.tryParse(match.group(1)!.replaceAll(',', '.')) ?? 0;
      // 1% ≈ 10 мг/мл (приблизительно)
      return pct * 10;
    }

    // "X мг" без указания объёма
    final mgOnly = RegExp(r'(\d+(?:[.,]\d+)?)\s*мг');
    match = mgOnly.firstMatch(lower);
    if (match != null) {
      final value = double.tryParse(match.group(1)!.replaceAll(',', '.'));
      if (value != null) {
        // Если указано "100 мг" без объёма, предполагаем что это в 1 мл
        // Но это может быть и в таблетке
        return value;
      }
    }

    return 0;
  }

  /// Парсит концентрацию из состава для конкретного вещества
  ///
  /// ⚠ Фикс VV-038 (ревью 26.11.2026): МНН раньше интерполировался в RegExp
  /// как есть. В реестре есть составы с метасимволами — «инсулин двухфазный
  /// [человеческий генно-инженерный]» (ВИНСУВЕТ микс 30/70), «бензилдиметил
  /// [3-(миристоиламино)пропил]аммония…» (МИСТИН®/Аргумистин®), «3-(2,2,2-
  /// триметилгидразиний)…» (Эмидонол) — скобки и диапазоны ломали компиляцию
  /// паттерна (FormatException прямо в расчёте дозы реестровой ветки) или
  /// матчили не то. Теперь МНН экранируется (RegExp.escape) и получает левую
  /// границу слова.
  ///
  /// Граница — НЕ `\b`: в Dart `\w` покрывает только ASCII (см. комментарий
  /// к _tokenize в symptom_search_service), кириллица под него не попадает —
  /// `\b` вообще не сматчил бы русское МНН. Поэтому явная проверка «слева не
  /// буква/цифра». Правая граница НЕ ставится: составы склоняют МНН
  /// («…эмидонолА 50 мг»), хвостовые буквы легальны.
  static double parseConcentrationForSubstance(String composition, String inn) {
    if (composition.isEmpty || inn.isEmpty) return 0;

    final lower = composition.toLowerCase();
    final innLower = inn.toLowerCase().trim();

    // Экранированное МНН + левая граница слова (не \b — см. докблок выше).
    final escapedInn = RegExp.escape(innLower);
    const wordStart = r'(?:^|[^a-zа-яё0-9])';

    // Ищем паттерн: "вещество - X мг" или "вещество: X мг"
    final patterns = [
      RegExp('$wordStart$escapedInn[^.]*?(\\d+(?:[.,]\\d+)?)\\s*мг'),
      RegExp('(\\d+(?:[.,]\\d+)?)\\s*мг[^.]*?$wordStart$escapedInn'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(lower);
      if (match != null) {
        return double.tryParse(match.group(1)!.replaceAll(',', '.')) ?? 0;
      }
    }

    return 0;
  }

  /// Определяет единицу измерения концентрации
  static String getConcentrationUnit(String composition) {
    final lower = composition.toLowerCase();

    if (lower.contains('мг/мл') || lower.contains('мг в 1 мл')) {
      return 'мг/мл';
    }
    if (lower.contains('мкг/мл')) {
      return 'мкг/мл';
    }
    if (lower.contains('%')) {
      return '%';
    }
    if (lower.contains('мг/табл') || lower.contains('мг в таблетке')) {
      return 'мг/таб';
    }
    if (lower.contains('ме/мл') || lower.contains('ме в 1 мл')) {
      return 'МЕ/мл';
    }

    // Не удаётся определить единицу — возвращаем пустую строку
    return '';
  }
}
