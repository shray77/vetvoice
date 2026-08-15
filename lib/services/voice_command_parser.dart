import 'package:flutter/foundation.dart';

/// Голосовая команда
class VoiceCommand {
  final VoiceCommandType type;
  final String? parameter;

  const VoiceCommand(this.type, [this.parameter]);

  @override
  String toString() => 'VoiceCommand($type${parameter != null ? ', $parameter' : ''})';
}

/// Типы голосовых команд
enum VoiceCommandType {
  stop,        // "стоп", "хватит", "остановись"
  repeat,      // "повтори", "ещё раз"
  reset,       // "сброс", "новый расчёт", "заново"
  help,        // "помощь", "что умеешь"
  continuous,  // "hands-free", "режим без рук"
  animal,      // Выбор животного
  speakResult, // "озвучь результат", "скажи дозу"
  earMode,     // "ухо", "слушай", "включи ухо"
}

/// Парсер голосовых команд
class VoiceCommandParser {
  static final Map<VoiceCommandType, List<String>> _commands = {
    VoiceCommandType.stop: ['стоп', 'хватит', 'остановись', 'остановить', 'прекрати', 'выключи'],
    VoiceCommandType.repeat: ['повтори', 'ещё раз', 'повторить', 'скажи ещё'],
    VoiceCommandType.reset: ['сброс', 'новый расчёт', 'заново', 'очистить', 'сначала', 'новый'],
    VoiceCommandType.help: ['помощь', 'что умеешь', 'помоги', 'команды', 'инструкция'],
    VoiceCommandType.continuous: ['hands-free', 'без рук', 'режим без рук', 'свободные руки', 'автоматический режим'],
    VoiceCommandType.speakResult: ['скажи дозу', 'озвучь результат', 'сколько давать', 'напомни дозу', 'произнеси'],
    VoiceCommandType.earMode: ['ухо', 'слушай', 'включи ухо', 'слушать', 'начни слушать', 'голосовой режим'],
  };

  static VoiceCommand? parse(String input) {
    final lower = input.toLowerCase().trim();
    for (final entry in _commands.entries) {
      for (final keyword in entry.value) {
        if (lower.contains(keyword)) {
          return VoiceCommand(entry.key);
        }
      }
    }
    return null;
  }
}

/// Парсер голосового ввода для ветеринарных команд
class VoiceInputParser {
  // Алиасы животных
  static final Map<String, List<String>> _animalKeywords = {
    'cattle': [
      'крс', 'корова', 'коровы', 'корове', 'корову', 'коровой',
      'бык', 'быка', 'быку', 'быком',
      'теленок', 'телёнок', 'теленка', 'телёнка', 'теленку', 'телёнку',
      'телка', 'тёлка', 'телки', 'тёлки',
      'скот', 'скота', 'скоту',
      'бурёнка', 'буренка', 'бурёнки', 'буренки',
      'крупный рогатый', 'рогатый скот',
    ],
    'sheep': [
      'овца', 'овцы', 'овце', 'овцу', 'овцой',
      'баран', 'барана', 'барану', 'бараном',
      'ягненок', 'ягнёнок', 'ягненка', 'ягнёнка', 'ягненку', 'ягнёнку',
      'коза', 'козы', 'козе', 'козу', 'козой',
      'козел', 'козёл', 'козла', 'козлу',
      'козленок', 'козлёнок', 'козленка', 'козлёнка',
      'мрс', 'мелкий рогатый', 'мелкий скот',
    ],
    'horse': [
      'лошадь', 'лошади', 'лошадь', 'лошадью',
      'конь', 'коня', 'коню', 'конём',
      'пони',
      'жеребенок', 'жеребёнок', 'жеребенка', 'жеребёнка', 'жеребенку', 'жеребёнку',
      'мерин', 'мерина', 'мерину',
      'кобыла', 'кобылы', 'кобыле', 'кобылу',
      'жеребец', 'жеребца', 'жеребцу',
    ],
    'pig': [
      'свинья', 'свиньи', 'свинье', 'свинью', 'свиньей',
      'свин', 'свином',
      'хряк', 'хряка', 'хряку', 'хряком',
      'поросенок', 'поросёнок', 'поросенка', 'поросёнка', 'поросенку', 'поросёнку',
      'кабан', 'кабана', 'кабану',
    ],
    'poultry': [
      'птица', 'птицы', 'птице', 'птицу', 'птицей',
      'птиц', 'птичий', 'птичья',
      'курица', 'курицы', 'курице', 'курицу', 'курицей',
      'куры', 'кур', 'курам', 'курами',
      'петух', 'петуха', 'петуху', 'петухом',
      'цыплёнок', 'цыпленок', 'цыпленка', 'цыплёнка', 'цыпленку', 'цыплёнку',
      'утка', 'утки', 'утке', 'утку', 'уткой',
      'гусь', 'гуся', 'гусям', 'гусем',
      'индейка', 'индейки', 'индейке', 'индейку',
      'индюк', 'индюка', 'индюку',
      'индюшонок', 'индюшонка', 'индюшат',
    ],
    'dog': [
      'собака', 'собаки', 'собаке', 'собаку', 'собакой',
      'пёс', 'пес', 'пса', 'псу', 'псом',
      'щенок', 'щенка', 'щенку', 'щенком',
      'собачий', 'собачья',
      'кобель', 'кобеля', 'кобелю',
      'сука', 'суки', 'сук', 'суке',
    ],
    'cat': [
      'кошка', 'кошки', 'кошке', 'кошку', 'кошкой',
      'кот', 'кота', 'коту', 'котом',
      'котёнок', 'котенок', 'котенка', 'котёнка', 'котенку', 'котёнку',
      'кис', 'киса', 'кисы', 'кису',
      'мурка', 'мурки', 'мурке', 'мурку',
      'кошачий', 'кошачья',
    ],
    'rabbit': [
      'кролик', 'кролика', 'кролику', 'кроликом', 'кролики', 'кроликов',
      'крольчиха', 'крольчихи', 'крольчиху',
      'крольчонок', 'крольчонка', 'крольчата',
      'пушной', 'пушного', 'пушные', 'пушных', 'пушным',
      'пушной зверь', 'пушные звери', 'пушных зверей',
      'нутрия', 'нутрии', 'нутрию',
      'песец', 'песца', 'песцу',
      'лиса', 'лисы', 'лису', 'лисой',
      'лисица', 'лисицы', 'лисицу',
      'соболь', 'соболя', 'соболю',
      'хорек', 'хорь', 'хорька', 'хорьку',
      'норка', 'норки', 'норку',
      'шиншилла', 'шиншиллы', 'шиншиллу',
    ],
  };

  static final List<String> _maleKeywords = [
    'самец', 'самца', 'самцу', 'самцом',
    'мужской', 'мужского', 'мужская', 'мужской пол',
    'мальчик', 'мальчика',
    'жеребец', 'жеребца', 'жеребцу',
    'селезень', 'селезня',
    'он', 'его', 'нему',
  ];

  static final List<String> _femaleKeywords = [
    'самка', 'самки', 'самке', 'самку', 'самкой',
    'женский', 'женского', 'женская', 'женский пол',
    'девочка', 'девочки',
    'беремен', 'беременная', 'беременность', 'сукотность', 'сукотная',
    'стельн', 'стельная', 'стельность',
    'яжереб', 'жеребая', 'жеребость',
    'супорос', 'супоросная', 'суягность', 'суягная',
    'она', 'её', 'ее', 'ней',
  ];

  static final List<String> _ageKeywords = [
    'возраст', 'возраста', 'возрасту',
    'лет', 'год', 'года', 'году',
    'месяц', 'месяца', 'месяцев', 'месяцу',
    'неделя', 'недели', 'недель', 'неделю',
    'день', 'дня', 'дней',
    'старый', 'старая', 'старое',
    'молодой', 'молодая', 'молодое', 'молод',
    'щенок', 'щенка', 'котенок', 'котенка', 'теленок', 'теленка',
    'поросенок', 'поросенка', 'жеребенок', 'жеребенка',
    'ягненок', 'ягненка', 'цыпленок', 'цыпленка',
  ];

  static final List<String> _weightKeywords = [
    'вес', 'веса', 'весу', 'весит', 'весят',
    'килограмм', 'килограмма', 'килограммов', 'кило', 'кг', 'kg',
    'грамм', 'грамма', 'граммов', 'гр', 'г',
    'тонна', 'тонны', 'тонн', 'т',
    'масса', 'массой', 'весом',
  ];

  static final Map<String, List<String>> _drugKeywords = {
    'энрофлоксацин': ['энрофлоксацин', 'энрофлокс', 'энрофлон', 'байтрил', 'энромаг', 'энроксол', 'энрофлок'],
    'марбофлоксацин': ['марбофлоксацин', 'марбоцил', 'марбокил', 'марбофлок'],
    'данофлоксацин': ['данофлоксацин', 'адвоквайл', 'данофлок'],
    'амоксициллин': ['амоксициллин', 'амоксил', 'амоксиклав', 'синулокс', 'кламоксил', 'амоксогард', 'амоксицилин', 'амокс'],
    'ампициллин': ['ампициллин', 'ампицил', 'ампиокс', 'ампицилин'],
    'бензилпенициллин': ['бензилпенициллин', 'пенициллин', 'бициллин'],
    'цефтиофур': ['цефтиофур', 'экзенел', 'наксель'],
    'цефазолин': ['цефазолин', 'кефзол', 'цезолин'],
    'цефтриаксон': ['цефтриаксон', 'лендацин', 'роцефин'],
    'цефалексин': ['цефалексин', 'кефлекс', 'цефалекс'],
    'тилозин': ['тилозин', 'тилан', 'тилозинол', 'фармазин'],
    'тилмикозин': ['тилмикозин', 'микотил'],
    'линкомицин': ['линкомицин', 'линкоцин'],
    'клиндамицин': ['клиндамицин', 'антироб'],
    'окситетрациклин': ['окситетрациклин', 'террамицин', 'окситетран', 'тетрациклин'],
    'доксициклин': ['доксициклин', 'вибрамицин', 'доксивет'],
    'гентамицин': ['гентамицин', 'гентам', 'гарамицин'],
    'флорфеникол': ['флорфеникол', 'флуникол', 'нуфлор'],
    'ивермектин': ['ивермектин', 'ивермек', 'баймек', 'новомек'],
    'дорамектин': ['дорамектин', 'дектомакс'],
    'моксидектин': ['моксидектин', 'адвокейт'],
    'празиквантел': ['празиквантел', 'празицид', 'дронцит'],
    'толтразурил': ['толтразурил', 'байкокс', 'стоп-кокцид'],
    'фенбендазол': ['фенбендазол', 'панакур'],
    'альбендазол': ['альбендазол', 'немозол'],
    'фипронил': ['фипронил', 'барс', 'фронтлайн', 'фиприст'],
    'селамектин': ['селамектин', 'революшн', 'стронгхолд'],
    'мелоксикам': ['мелоксикам', 'меклокс', 'мелоксидил', 'метакам', 'локсиком'],
    'кетопрофен': ['кетопрофен', 'кетонал', 'кетофен'],
    'карпрофен': ['карпрофен', 'римадил', 'норокарп'],
    'робенакоксиб': ['робенакоксиб', 'онсариор'],
    'дексаметазон': ['дексаметазон', 'дексамет', 'дексафорт'],
    'преднизолон': ['преднизолон', 'преднизон'],
    'кетамин': ['кетамин', 'калипсол', 'кетанест'],
    'ксилазин': ['ксилазин', 'ромпун', 'ксиланит', 'рометар'],
    'золетил': ['золетил', 'тилетамин', 'золазепам'],
    'маропитант': ['маропитант', 'серения', 'церенния'],
    'метоклопрамид': ['метоклопрамид', 'церукал'],
    'фуросемид': ['фуросемид', 'лазикс'],
    'дифенгидрамин': ['дифенгидрамин', 'димедрол'],
    'гамавит': ['гамавит'],
    'катозал': ['катозал', 'бутофан'],
    'пимобендан': ['пимобендан', 'ветмедин'],
  };

  static final RegExp _concentrationPattern = RegExp(
    r'(\d+(?:[.,]\d+)?)\s*(?:процент|%|пр|процентов)',
  );

  static double? parseConcentration(String input) {
    final match = _concentrationPattern.firstMatch(input.toLowerCase());
    if (match != null) {
      return double.tryParse(match.group(1)!.replaceAll(',', '.'));
    }
    return null;
  }

  static DrugMatch? findDrug(String input, List<String>? availableDrugs) {
    final lower = input.toLowerCase();

    for (final entry in _drugKeywords.entries) {
      for (final alias in entry.value) {
        if (lower.contains(alias)) {
          final concentration = parseConcentration(input);
          return DrugMatch(
            inn: entry.key,
            matchedAlias: alias,
            concentration: concentration,
          );
        }
      }
    }

    if (availableDrugs != null) {
      for (final drug in availableDrugs) {
        if (lower.contains(drug.toLowerCase())) {
          return DrugMatch(inn: drug, matchedAlias: drug);
        }
      }

      final words = lower
          .replaceAll(RegExp(r'[^\w\sа-яё-]'), ' ')
          .split(RegExp(r'\s+'))
          .where((w) => w.length >= 4)
          .toList();

      String? bestDrug;
      int bestDistance = 999;
      for (final drug in availableDrugs) {
        final drugLower = drug.toLowerCase();
        final drugWords = drugLower
            .replaceAll(RegExp(r'[®(),\d.]'), ' ')
            .split(RegExp(r'\s+'))
            .where((w) => w.length >= 4)
            .toList();
        if (drugWords.isEmpty) continue;

        for (final drugWord in drugWords) {
          for (final inputWord in words) {
            final dist = _levenshtein(drugWord, inputWord);
            final threshold = drugWord.length >= 8 ? 3 : 2;
            if (dist <= threshold && dist < bestDistance) {
              bestDistance = dist;
              bestDrug = drug;
            }
          }
        }
      }

      if (bestDrug != null) {
        debugPrint('🎤 Fuzzy match: "$bestDrug" (dist=$bestDistance) для "$input"');
        return DrugMatch(inn: bestDrug, matchedAlias: bestDrug);
      }
    }

    return null;
  }

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    if (a.length < b.length) {
      final tmp = a; a = b; b = tmp;
    }
    var prevRow = List<int>.generate(b.length + 1, (i) => i);
    for (int i = 0; i < a.length; i++) {
      var curRow = List<int>.filled(b.length + 1, 0);
      curRow[0] = i + 1;
      for (int j = 0; j < b.length; j++) {
        final cost = a[i] == b[j] ? 0 : 1;
        curRow[j + 1] = [
          prevRow[j + 1] + 1,
          curRow[j + 1] + 1,
          prevRow[j] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
      prevRow = curRow;
    }
    return prevRow[b.length];
  }

  static AnimalMatch? findAnimal(String input) {
    final lower = input.toLowerCase();
    for (final entry in _animalKeywords.entries) {
      for (final alias in entry.value) {
        if (lower.contains(alias)) {
          return AnimalMatch(id: entry.key, matchedAlias: alias);
        }
      }
    }
    return null;
  }

  static GenderMatch? findGender(String input) {
    final lower = input.toLowerCase();
    for (final keyword in _femaleKeywords) {
      if (lower.contains(keyword)) {
        return GenderMatch(gender: VoiceGender.female, matchedAlias: keyword);
      }
    }
    for (final keyword in _maleKeywords) {
      if (lower.contains(keyword)) {
        return GenderMatch(gender: VoiceGender.male, matchedAlias: keyword);
      }
    }
    return null;
  }

  static AgeMatch? findAge(String input) {
    final lower = input.toLowerCase();
    final yearPatterns = [
      RegExp(r'(\d+)\s*(?:лет|год|года|году)'),
      RegExp(r'(?:возраст|лет|год|года)\s*(\d+)'),
      RegExp(r'(\d+)\s*(?:г|год)(?:\s|$)'),
    ];

    for (final pattern in yearPatterns) {
      final match = pattern.firstMatch(lower);
      if (match != null) {
        final yearsStr = match.group(1);
        if (yearsStr != null) {
          final years = int.tryParse(yearsStr);
          if (years != null && years > 0 && years < 50) {
            return AgeMatch(months: years * 12, matchedText: '$years лет');
          }
        }
      }
    }

    final monthPatterns = [
      RegExp(r'(\d+)\s*(?:месяц|месяца|месяцев|мес)'),
      RegExp(r'(?:возраст|месяц|месяца|месяцев)\s*(\d+)'),
    ];

    for (final pattern in monthPatterns) {
      final match = pattern.firstMatch(lower);
      if (match != null) {
        final monthsStr = match.group(1);
        if (monthsStr != null) {
          final months = int.tryParse(monthsStr);
          if (months != null && months > 0 && months < 600) {
            return AgeMatch(months: months, matchedText: '$months мес.');
          }
        }
      }
    }

    if (lower.contains('щенок') || lower.contains('щенку') || lower.contains('щенка')) {
      return const AgeMatch(months: 6, matchedText: 'щенок (до года)');
    }
    if (lower.contains('котёнок') || lower.contains('котенок') || lower.contains('котенку')) {
      return const AgeMatch(months: 6, matchedText: 'котёнок (до года)');
    }
    if (lower.contains('теленок') || lower.contains('телёнок') || lower.contains('телёнку')) {
      return const AgeMatch(months: 6, matchedText: 'телёнок (до года)');
    }
    return null;
  }

  static double? parseWeight(String input) {
    final lower = input.toLowerCase();
    final explicitWeightPatterns = [
      RegExp(r'(?:вес|весит|масса|весом)\s*(\d+(?:[.,]\d+)?)'),
      RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:килограмм|кило|кг|kg)(?:\s|$)'),
      RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:грамм|гр|г)(?:\s|$)'),
      RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:тонн|тонны|т)(?:\s|$)'),
    ];

    for (final pattern in explicitWeightPatterns) {
      final match = pattern.firstMatch(lower);
      if (match != null) {
        var weightStr = match.group(1)!.replaceAll(',', '.');
        weightStr = weightStr.replaceFirst(RegExp(r'^0+(?=\d)'), '');
        final weight = double.tryParse(weightStr);
        if (weight != null && weight > 0) {
          if (lower.contains('грамм') || lower.contains(' гр') || lower.contains(' г ')) {
            return weight / 1000;
          }
          if (lower.contains('тонн') || lower.contains(' тонны') || lower.contains(' т')) {
            return weight * 1000;
          }
          if (weight < 2000) return weight;
        }
      }
    }

    final numberPattern = RegExp(r'(\d+(?:[.,]\d+)?)');
    final allNumbers = numberPattern.allMatches(lower);
    for (final match in allNumbers) {
      final numberStr = match.group(1)!.replaceAll(',', '.');
      final number = double.tryParse(numberStr);
      if (number == null || number <= 0) continue;

      if (number >= 0.1 && number <= 500) {
        return number;
      }
    }

    return null;
  }

  static VoiceInputResult parse(String input, {List<String>? availableDrugs}) {
    final weight = parseWeight(input);
    final drug = findDrug(input, availableDrugs);
    final animal = findAnimal(input);
    final gender = findGender(input);
    final age = findAge(input);

    return VoiceInputResult(
      weight: weight,
      drugMatch: drug,
      animalMatch: animal,
      genderMatch: gender,
      ageMatch: age,
      rawText: input,
    );
  }
}

class DrugMatch {
  final String inn;
  final String matchedAlias;
  final double? concentration;

  const DrugMatch({
    required this.inn,
    required this.matchedAlias,
    this.concentration,
  });
}

class AnimalMatch {
  final String id;
  final String matchedAlias;

  const AnimalMatch({
    required this.id,
    required this.matchedAlias,
  });
}

enum VoiceGender {
  male,
  female,
}

class GenderMatch {
  final VoiceGender gender;
  final String matchedAlias;

  const GenderMatch({
    required this.gender,
    required this.matchedAlias,
  });
}

class AgeMatch {
  final int months;
  final String matchedText;

  const AgeMatch({
    required this.months,
    required this.matchedText,
  });
}

class VoiceInputResult {
  final double? weight;
  final DrugMatch? drugMatch;
  final AnimalMatch? animalMatch;
  final GenderMatch? genderMatch;
  final AgeMatch? ageMatch;
  final String rawText;

  const VoiceInputResult({
    this.weight,
    this.drugMatch,
    this.animalMatch,
    this.genderMatch,
    this.ageMatch,
    required this.rawText,
  });

  bool get hasWeight => weight != null && weight! > 0;
  bool get hasDrug => drugMatch != null;
  bool get hasAnimal => animalMatch != null;
  bool get hasGender => genderMatch != null;
  bool get hasAge => ageMatch != null;
}
