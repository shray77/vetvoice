/// SpeciesSafetyFilter — рантайм-фильтр видоспецифичных предупреждений
/// и побочных эффектов по выбранному животному (Task 230, 2026-11-24).
///
/// Проблема (полевой контекст): 1522 из 2401 препарата несут
/// видоспецифичный текст в ОБЩИХ полях warnings / side_effects —
/// «Запрещено для кроликов», «ЛАМИНИТ у лошадей!», «Не применять
/// несушкам» — и калькулятор показывает КРС запрет для кроликов,
/// кошке — запрет для щенков, корове — ламинат лошадей. Чужие виды
/// засоряют карточку и размывают реальные риски выбранного вида.
///
/// Двухслойное решение:
///  1) долгосрочное — миграция текста в структурные поля
///     contraindications.animal_warnings / animal_side_effects /
///     animal_specific.<вид> (модель парсит их уже сейчас, в базе пусто);
///  2) настоящее — sentence-фильтр на рантайме: работает на текущей
///     базе без миграции, после миграции сам собой превращается в no-op.
///
/// Правило клинически консервативно: предложение скрывается ТОЛЬКО если
/// оно упоминает хотя бы один вид и НИ ОДИН из упомянутых не равен
/// выбранному. Безвидовые предложения и предложения про выбранный вид
/// видимы всегда: цена возможного «шума» ниже цены потери предупреждения.
///
/// Матчер word-aware, границы слов обязательны — иначе жди беды:
///  «аминогликозидам» не должен матчиться как МРС (корень «коз»),
///  «курс лечения» — как Птица («кур»), «тельность» — как КРС («тел»).
/// Поэтому PREFIX-стемы прикладываются к НАЧАЛУ слова, а короткие
/// спорные корни (коз/кур/кот/сук) — только ТОЧНЫМ совпадением
/// словоформы. Словарь сверен полным проходом по базе: 690 уникальных
/// warning-строк + 110 side-effect-строк, все точные совпадения
/// («курам-несушкам», «беременных сук», «дойных овец и коз») —
/// легитимные видовые ссылки; ложные (свинцовый=свинцовый металл,
/// не свинья) прикрыты _prefixExceptions.
class SpeciesSafetyFilter {
  SpeciesSafetyFilter._();

  /// PREFIX-стемы по каноническим видам animals-справочника drugs_calc.json.
  /// Слово НАЧИНАЕТСЯ со стема: «кроликам» → «кролик», «телятам» → «телят».
  /// «жвачн»/«рубц» стоят у КРС И МРС: «взрослые жвачные с развитым
  /// рубцовым пищеварением» — это коровы И овцы с козами (44+33 вхождений
  /// в базе); стем только у МРС прятал бы эти запреты от КРС.
  static const Map<String, List<String>> _prefixStems = {
    'КРС': [
      'коров', 'телят', 'телок', 'телк', 'телоч', 'бык', 'стельн', 'жвачн', 'рубц',
    ],
    'МРС': ['овец', 'овц', 'ягнят', 'жвачн', 'рубц'],
    'Свиньи': ['свин', 'порос', 'хряк'],
    'Собаки': ['собак', 'щенк', 'кобел', 'псов'],
    'Кошки': ['кошк', 'котят', 'котен', 'кошач'],
    'Лошади': ['лошад', 'жереб'],
    'Птица': ['птиц', 'птич', 'несушк', 'цыплят', 'бройлер', 'инде', 'гус', 'яйц'],
    'Пчёлы': ['пчел'],
    'Пушные звери': ['пушн', 'норк', 'собол', 'лисиц', 'шиншил'],
    'Кролики': ['кролик', 'крольч'],
  };

  /// Точные словоформы: короткие корни, где префикс ловил бы мусор.
  /// «коз» в «аминогликозидам», «кур» в «курс» — только полные слова.
  static const Map<String, Set<String>> _exactWords = {
    'КРС': {'крс'},
    'МРС': {
      'мрс', 'коз', 'козы', 'козам', 'козами', 'козах',
      'козел', 'козла', 'козлов',
    },
    'Собаки': {
      'пес', 'пса', 'псу', 'псом', 'псы', 'псов', 'псами',
      'сук', 'суки', 'сукам', 'суками',
    },
    'Кошки': {
      'кот', 'кота', 'коту', 'коты', 'котов', 'котам', 'котами', 'котах',
    },
    'Лошади': {'конь', 'коня', 'коню', 'коней', 'коням'},
    'Птица': {
      'кур', 'куры', 'куру', 'курам', 'курами', 'курах', 'куриц', 'курица',
    },
  };

  /// Ложные префиксы: слово начинается с корня вида, но видом НЕ является.
  /// «при свинцовых отравлениях» — металл свинец, не Свиньи (#919 базы).
  static const Map<String, List<String>> _prefixExceptions = {
    'Свиньи': ['свинц'],
  };

  /// Виды вне приложения (морские свинки, хомяки, олени, верблюды...):
  /// упоминаются в тексте инструкций, но не выбираются в калькуляторе.
  /// Их предложения скрываются у всех 10 поддерживаемых видов.
  static const List<String> _unsupportedPrefixes = [
    'морск', 'хомяк', 'олен', 'рептил', 'грызун', 'экзот', 'верблюд', 'буйвол',
  ];

  static final RegExp _wordRe = RegExp(r'[а-я]+');

  static String _norm(String s) =>
      s.toLowerCase().replaceAll('ё', 'е');

  /// Канонические виды, поддерживаемые калькулятором.
  static Iterable<String> get supportedSpecies => _prefixStems.keys;

  static String? _canonical(String animalName) {
    final n = _norm(animalName);
    if (n.isEmpty) return null;
    for (final k in _prefixStems.keys) {
      if (_norm(k) == n) return k;
    }
    return null; // вид вне справочника — фильтр его не трогает
  }

  /// Виды из 10 поддерживаемых, упомянутые в тексте.
  static Set<String> mentionedSpecies(String text) {
    final normText = _norm(text);
    // «морск* свин*» — морские свинки (вид вне приложения), а «ремонтные
    // свинки» — это Свиньи (5 из 7 «свинк» в базе). Дифференциатор —
    // «морск» в том же тексте: тогда ЛЮБОЕ слово на «свин» (свинках,
    // свинкам — и свинок с беглой гласной, свинк-а → свин-ок) за Свиней
    // не считается. В базе нет случая «свиньям и морским свинкам» рядом.
    final hasMorsk = normText.contains('морск');
    final found = <String>{};
    for (final m in _wordRe.allMatches(normText)) {
      final w = m.group(0)!;
      for (final entry in _prefixStems.entries) {
        if (entry.key == 'Свиньи' && hasMorsk && w.startsWith('свин')) {
          continue; // морские свинки — не свиньи
        }
        final exceptions = _prefixExceptions[entry.key] ?? const <String>[];
        if (exceptions.any(w.startsWith)) continue;
        if (entry.value.any(w.startsWith)) {
          found.add(entry.key);
          continue;
        }
        final exact = _exactWords[entry.key];
        if (exact != null && exact.contains(w)) found.add(entry.key);
      }
    }
    return found;
  }

  /// Упоминает ли текст вид вне приложения (морские свинки и т.п.).
  static bool mentionsUnsupportedSpecies(String text) {
    for (final m in _wordRe.allMatches(_norm(text))) {
      final w = m.group(0)!;
      if (_unsupportedPrefixes.any(w.startsWith)) return true;
    }
    return false;
  }

  /// Актуально ли предложение выбранному виду. Клинически консервативно:
  /// упомяны только чужие виды или unsupported-виды — скрываем; выбранного
  /// вида среди упомянутых нет, но и никаких видов нет — показываем всем.
  static bool isRelevant(String text, String animalName) {
    final mentioned = mentionedSpecies(text);
    if (mentioned.isNotEmpty) {
      return mentioned.contains(_canonical(animalName));
    }
    return !mentionsUnsupportedSpecies(text);
  }

  /// Упоминает ли СВОБОДНЫЙ текст данный вид — для species-полей
  /// side_effects.json («кошки», «кошки чувствительнее», «собаки»).
  static bool textMentionsAnimal(String text, String animalName) {
    final canonical = _canonical(animalName);
    if (canonical == null) return false;
    return mentionedSpecies(text).contains(canonical);
  }

  /// Фильтр списка строк (warnings / side_effects): внутри каждой строки
  /// режем предложения, чужие виду — выбрасываем. Строки, оставшиеся
  /// пустыми, выбрасываются целиком.
  static List<String> filterForAnimal(
      List<String> strings, String animalName) {
    final out = <String>[];
    for (final s in strings) {
      final f = filterTextForAnimal(s, animalName);
      if (f.isNotEmpty) out.add(f);
    }
    return out;
  }

  /// Фильтр одной строки: предложения про чужие виды вырезаются.
  /// Вид вне справочника (пустой animalName, голосовые протоколы) —
  /// консервативно возвращаем текст без фильтрации.
  static String filterTextForAnimal(String text, String animalName) {
    if (text.isEmpty) return text;
    final canonical = _canonical(animalName);
    if (canonical == null) return text;
    final kept = <String>[];
    for (final sent in _splitSentences(text)) {
      if (isRelevant(sent, canonical)) kept.add(sent);
    }
    return kept.join(' ');
  }

  /// Сплит на предложения: конец [.!?;] с последующим пробелом/концом,
  /// плюс переводы строк. Точка внутри «12 мес. (крупные породы...)»
  /// не сплитит — разделитель это знак + пробел, а не середина слова.
  static List<String> _splitSentences(String text) {
    final t = text.replaceAll('\r', ' ');
    final out = <String>[];
    for (final para in t.split('\n')) {
      var buf = '';
      for (var i = 0; i < para.length; i++) {
        final ch = para[i];
        buf += ch;
        final isEnd = ch == '.' || ch == '!' || ch == '?' || ch == ';';
        final nextIsSpace =
            i + 1 >= para.length || _isSpaceChar(para[i + 1]);
        if (isEnd && nextIsSpace) {
          final s = buf.trim();
          if (s.isNotEmpty) out.add(s);
          buf = '';
        }
      }
      final tail = buf.trim();
      if (tail.isNotEmpty) out.add(tail);
    }
    return out;
  }

  static bool _isSpaceChar(String ch) =>
      ch == ' ' || ch == '\t' || ch == '\u00A0';
}
