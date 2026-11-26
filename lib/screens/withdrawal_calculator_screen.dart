// WithdrawalCalculatorScreen — калькулятор каренции (waiting period).
//
// После применения препарата корова даёт молоко. Когда можно пить?
// Когда мясо безопасно? Зависит от withdrawal_days и withdrawal_by_product.
//
// Использует:
//   - drug.withdrawal_days (глобальная каренция в днях)
//   - drug.withdrawalText (детально: «Мясо: 28 сут; Молоко: 120 ч»)
//   - withdrawal_by_product.json (если есть детальные данные)
//
// Логика:
//   1. Пользователь выбирает препарат
//   2. Выбирает вид животного (КРС / МРС / Свиньи / Птица / …)
//   3. Указывает дату введения
//   4. Получает даты безопасного употребления мяса/молока/яиц
//
// ⚠ Фикс (ревью 26.11.2026, VV-029): вид теперь УЧИТЫВАЕТСЯ. В приоритете
// видовые правила из withdrawal_by_product.json (поиск по МНН препарата,
// видовой блок продуктов, значения — ДОСЛОВНО, включая запреты «ЗАПРЕЩЁН» /
// «НЕ ДЛЯ ДОЙНЫХ!»). Если видовых данных нет — прежний fallback
// withdrawalText/withdrawalDays, но продукты фильтруются по релевантности
// виду (у Птицы — мясо/яйца, у КРС/МРС — мясо/молоко, у остальных — мясо).
//
// Зависимости:
//   - VetProvider для доступа к drugs и withdrawalDatabase
//   - AppTheme

import 'package:flutter/material.dart';
import '../models/calc_drug.dart';
import '../models/withdrawal.dart';
import '../providers/vet_provider.dart';
import '../utils/app_theme.dart';
// v1.18.0 (Фаза 2): каркас + DrugPicker вместо самописного _DrugSelector
import '../widgets/common/app_scaffold.dart';
import '../widgets/common/drug_picker.dart';
import '../widgets/common/haptics.dart';
import '../widgets/common/status_chip.dart';

class WithdrawalCalculatorScreen extends StatefulWidget {
  final VetProvider vetProvider;

  /// Инъекция «сегодня» для golden-тестов (Task 179): экран рендерит
  /// дату введения текстом (дд.мм.гггг) и производные от неё сроки
  /// каренции — DateTime.now() по умолчанию делает голден зависимым
  /// от ДНЯ снятия базы: красный каждый следующий день, молча
  /// (Task 178–179: вскрыто снятием continue-on-error в CI).
  final DateTime? initialDate;

  /// Границы пикера дат для тестов (Task 184): при инъектированном
  /// [initialDate] живые firstDate/lastDate от DateTime.now() рано или
  /// поздно дают initialDate > lastDate — assert showDatePicker при
  /// открытии пикера. null — прежнее живое окно (год назад … +30 дней).
  final DateTime? firstDate;
  final DateTime? lastDate;

  const WithdrawalCalculatorScreen({
    super.key,
    required this.vetProvider,
    this.initialDate,
    this.firstDate,
    this.lastDate,
  });

  @override
  State<WithdrawalCalculatorScreen> createState() =>
      _WithdrawalCalculatorScreenState();
}

class _WithdrawalCalculatorScreenState
    extends State<WithdrawalCalculatorScreen> {
  CalcDrug? _selectedDrug;
  String _selectedAnimal = 'КРС';
  // детерминизм голденов: инъекция или «сегодня» (см. виджет выше)
  late DateTime _applicationDate = widget.initialDate ?? DateTime.now();
  // границы пикера: инъекция или живое окно (см. firstDate/lastDate)
  DateTime get _pickerFirstDate =>
      widget.firstDate ?? DateTime.now().subtract(const Duration(days: 365));
  DateTime get _pickerLastDate =>
      widget.lastDate ?? DateTime.now().add(const Duration(days: 30));
  List<WithdrawalResult> _results = [];

  // ⚠ Фикс (ревью 26.11.2026, VV-029): прежние 4 вида (КРС/МРС/Свиньи/
  // Птица) дополнены видами, по которым в withdrawal_by_product.json есть
  // видовые сроки (Собаки/Кошки — ципрофлоксацин, Лошади — кетопрофен,
  // Кролики — толтразурил…). Без них селектор врал «вид не важен».
  static const List<String> _productAnimals = [
    'КРС',
    'МРС',
    'Свиньи',
    'Птица',
    'Кролики',
    'Собаки',
    'Кошки',
    'Лошади',
  ];

  /// Ключи видов в withdrawal_by_product.json для каждого вида выбора.
  /// «МРС» покрывает и ключ «Овцы» (в базе они взаимозаменяемы: у одних
  /// записей «МРС», у других «Овцы»). «Пушные звери» ↔ «Пушные» — алиасы
  /// одного вида (как в selectAnimalFromSpecies: ё→е, регистр неважен).
  static const Map<String, List<String>> _speciesDbKeys = {
    'КРС': ['КРС'],
    'МРС': ['МРС', 'Овцы'],
    'Свиньи': ['Свиньи'],
    'Птица': ['Птица'],
    'Кролики': ['Кролики'],
    'Собаки': ['Собаки'],
    'Кошки': ['Кошки'],
    'Лошади': ['Лошади'],
    'Пушные звери': ['Пушные звери', 'Пушные'],
  };

  /// Продукты, релевантные виду: у Птицы — мясо/яйца, у КРС/МРС — мясо/
  /// молоко, у остальных — только мясо. Прежний экран рисовал «Молоко» и
  /// для Птицы/Собак, где молока нет.
  static const Map<String, List<String>> _speciesProducts = {
    'КРС': ['meat', 'milk'],
    'МРС': ['meat', 'milk'],
    'Свиньи': ['meat'],
    'Птица': ['meat', 'eggs'],
    'Кролики': ['meat'],
    'Собаки': ['meat'],
    'Кошки': ['meat'],
    'Лошади': ['meat'],
    'Пушные звери': ['meat'],
  };

  /// Подписи и иконки продуктов.
  static const Map<String, String> _productLabels = {
    'meat': 'Мясо',
    'milk': 'Молоко',
    'eggs': 'Яйца',
  };
  static const Map<String, IconData> _productIcons = {
    'meat': Icons.restaurant,
    'milk': Icons.water_drop,
    'eggs': Icons.egg,
  };

  /// Нормализация имени вида: нижний регистр, ё→е, без краёв.
  static String _norm(String s) =>
      s.toLowerCase().replaceAll('ё', 'е').trim();

  /// Выбор пользователя → канонический вид из _speciesDbKeys (точное
  /// совпадение, затем префикс в обе стороны — «Пушные» ↔ «Пушные звери»).
  /// null — вид не распознан (видовых ключей нет).
  static String? _canonicalSpecies(String animal) {
    final n = _norm(animal);
    if (n.isEmpty) return null;
    for (final e in _speciesDbKeys.entries) {
      if (_norm(e.key) == n) return e.key;
    }
    for (final e in _speciesDbKeys.entries) {
      final k = _norm(e.key);
      if (k.startsWith(n) || n.startsWith(k)) return e.key;
    }
    return null;
  }

  /// Ключи withdrawal_by_product.json для выбранного вида.
  static List<String> _dbKeysFor(String animal) =>
      _speciesDbKeys[_canonicalSpecies(animal) ?? ''] ?? const [];

  /// Продукты, релевантные выбранному виду (нераспознанный вид — мясо).
  List<String> _relevantProducts() =>
      _speciesProducts[_canonicalSpecies(_selectedAnimal) ?? ''] ??
      const ['meat'];

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Калькулятор каренции',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Описание
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Расчёт даты, когда молоко/мясо безопасно после '
                      'применения препарата',
                      style: TextStyle(fontSize: 13, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Выбор препарата
            const Text(
              'Препарат',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            // v1.18.0: _DrugSelector заменён общим DrugPicker (Фаза 1).
            // Было: свой TextField с contains БЕЗ нормализации ®/ё —
            // «асд10»/«асд-10» не находили «АСД®-10» (класс бага v1.16.4).
            // Список сужен до препаратов с каренцией — как раньше.
            DrugPicker(
              drugs: widget.vetProvider.allDrugs
                  .whereType<CalcDrug>()
                  .where((d) =>
                      d.withdrawalDays > 0 || d.withdrawalText.isNotEmpty)
                  .toList(),
              hint: 'Название или МНН…',
              resultsMaxHeight: 240,
              onSelected: (drug) {
                setState(() {
                  _selectedDrug = drug;
                  _calculate();
                });
              },
            ),
            if (_selectedDrug != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: StatusChip(
                    label: 'Выбрано: ${_selectedDrug!.name}',
                    severity: StatusSeverity.success,
                    icon: Icons.medication_rounded,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Выбор животного
            const Text(
              'Вид животного',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: _productAnimals.map((animal) {
                return ChoiceChip(
                  label: Text(animal),
                  selected: _selectedAnimal == animal,
                  onSelected: (_) {
                    // Фаза 3: выбор вида животного — selectionClick.
                    AppHaptics.select();
                    setState(() {
                      _selectedAnimal = animal;
                      _calculate();
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Дата введения
            const Text(
              'Дата введения препарата',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  // v1.19.0: русская локаль (flutter_localizations в main) —
                  // календарь «31 декабря 2026» вместо «31 Dec 2026».
                  initialDate: _applicationDate,
                  // Task 184: границы инъектируемы (см. firstDate/lastDate) —
                  // иначе при injected initialDate пикер ловит assert
                  // «initialDate > lastDate» после ухода «сегодня» за окно.
                  firstDate: _pickerFirstDate,
                  lastDate: _pickerLastDate,
                );
                if (date != null) {
                  // Фаза 3: дата принята — подтверждение хаптиком.
                  AppHaptics.confirm();
                  setState(() {
                    _applicationDate = date;
                    _calculate();
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundGray,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        color: AppTheme.safeGreen, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      '${_applicationDate.day.toString().padLeft(2, '0')}.'
                      '${_applicationDate.month.toString().padLeft(2, '0')}.'
                      '${_applicationDate.year}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const Spacer(),
                    Icon(Icons.edit, color: AppTheme.textTertiary, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Результаты
            if (_results.isNotEmpty) ...[
              const Text(
                'Результат',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ..._results.map((r) => _WithdrawalResultCard(result: r)),
            ] else if (_selectedDrug != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Column(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange, size: 32),
                    SizedBox(height: 8),
                    Text(
                      'Для этого препарата нет данных по каренции',
                      style: TextStyle(fontSize: 13, color: Colors.orange),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Смотрите инструкцию производителя',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _calculate() {
    if (_selectedDrug == null) {
      setState(() {
        _results = [];
      });
      return;
    }

    final results = <WithdrawalResult>[];
    final drug = _selectedDrug!;

    // ⚠ Фикс (ревью 26.11.2026, VV-029): выбор вида ни на что не влиял —
    // читались только withdrawalText/withdrawalDays (первое попавшееся
    // «мясо: N дн» — от КРС, даже при выбранной Птице). Теперь в
    // приоритете видовые правила withdrawal_by_product.json — они
    // показываются ДОСЛОВНО, включая запреты. Fallback (видовых данных
    // нет) — прежняя логика, но продукты фильтруются по релевантности
    // виду (у Птицы нет молока, у Собак — молока и яиц).
    if (_tryCalculateFromSpeciesDatabase(drug, results)) {
      setState(() {
        _results = results;
      });
      return;
    }

    // Из withdrawalText — парсим «Мясо: 28 сут; Молоко: 120 ч»
    final withdrawalText = drug.withdrawalText;
    if (withdrawalText.isNotEmpty) {
      // Парсим «Мясо: N сут/дн/ч; Молоко: N ч/сут; Яйца: N сут»
      final patterns = [
        ('meat', RegExp(r'мясо[^\d]*(\d+)\s*(сут|дн|ч|час)', caseSensitive: false)),
        ('milk', RegExp(r'молоко[^\d]*(\d+)\s*(сут|дн|ч|час)', caseSensitive: false)),
        ('eggs', RegExp(r'яйц[^\d]*(\d+)\s*(сут|дн|ч|час)', caseSensitive: false)),
      ];
      // VV-029: только продукты, релевантные выбранному виду.
      final relevant = _relevantProducts().toSet();
      for (final (type, regex) in patterns) {
        if (!relevant.contains(type)) continue;
        final m = regex.firstMatch(withdrawalText);
        if (m != null) {
          final num = int.parse(m.group(1)!);
          final unit = m.group(2)!.toLowerCase();
          int hours;
          if (unit.startsWith('ч')) {
            hours = num;
          } else {
            hours = num * 24;
          }
          final safeDate = _applicationDate.add(Duration(hours: hours));
          results.add(WithdrawalResult(
            product: _productLabels[type] ?? type,
            icon: _productIcons[type] ?? Icons.restaurant,
            waitHours: hours,
            safeDate: safeDate,
            rawText: '${m.group(0)}',
          ));
        }
      }
    }

    // Fallback: используем withdrawal_days (глобальная каренция в днях)
    if (results.isEmpty && drug.withdrawalDays > 0) {
      final safeDate =
          _applicationDate.add(Duration(days: drug.withdrawalDays));
      results.add(WithdrawalResult(
        product: 'Мясо (общая каренция)',
        icon: Icons.restaurant,
        waitHours: drug.withdrawalDays * 24,
        safeDate: safeDate,
        rawText: '${drug.withdrawalDays} дней',
      ));
    }

    setState(() {
      _results = results;
    });
  }

  /// Видовые сроки из withdrawal_by_product.json (ревью 26.11.2026,
  /// VV-029). Возвращает true, если результаты собраны из базы — тогда
  /// fallback withdrawalText/withdrawalDays не нужен. Каждое значение
  /// показывается дословно: int → дата «безопасно с», строка-запрет
  /// («ЗАПРЕЩЁН», «НЕ ДЛЯ ДОЙНЫХ!») → без даты, красным; null → честное
  /// «Не указан».
  bool _tryCalculateFromSpeciesDatabase(
    CalcDrug drug,
    List<WithdrawalResult> out,
  ) {
    final entry =
        widget.vetProvider.withdrawalDatabase?.findByInn(drug.inn);
    if (entry == null) return false;

    // Видовой блок: ключи выбранного вида (МРС покрывает и «Овцы»), при
    // отсутствии — глобальный «all» (гамавит/катозал: 0 суток всем видам).
    // Пустой видовой блок (празиквантел: «Собаки»: {}) данных не несёт —
    // пропускаем, честнее уйти в fallback.
    WithdrawalProduct? species;
    for (final key in _dbKeysFor(_selectedAnimal)) {
      final sp = entry.products[key];
      if (sp != null &&
          (sp.meat != null || sp.milk != null || sp.eggs != null)) {
        species = sp;
        break;
      }
    }
    species ??= _speciesWithValues(entry.products['all']);
    if (species == null) return false;

    for (final type in _relevantProducts()) {
      final raw = switch (type) {
        'meat' => species.meat,
        'milk' => species.milk,
        'eggs' => species.eggs,
        _ => null,
      };
      out.add(_resultFor(type, raw));
    }
    return true;
  }

  /// Блок продуктов с хотя бы одним значением или null (см. выше).
  static WithdrawalProduct? _speciesWithValues(WithdrawalProduct? sp) {
    if (sp == null) return null;
    return (sp.meat != null || sp.milk != null || sp.eggs != null) ? sp : null;
  }

  /// Карточка результата по сырому значению базы: int → числовая
  /// каренция с датой; String → дословно (запрет); null → «Не указан».
  WithdrawalResult _resultFor(String type, dynamic raw) {
    final product = _productLabels[type] ?? type;
    final icon = _productIcons[type] ?? Icons.help_outline;
    if (raw is int) {
      return WithdrawalResult(
        product: product,
        icon: icon,
        waitHours: raw * 24,
        safeDate: _applicationDate.add(Duration(days: raw)),
        rawText: '$raw суток',
      );
    }
    return WithdrawalResult(
      product: product,
      icon: icon,
      waitHours: null,
      safeDate: null,
      rawText: raw is String ? raw : 'Не указан',
    );
  }
}

class WithdrawalResult {
  final String product;
  final IconData icon;

  /// Числовая каренция в часах. null — строковое значение из базы
  /// (запрет «ЗАПРЕЩЁН» / «НЕ ДЛЯ ДОЙНЫХ!» или «Не указан»):
  /// даты безопасного употребления нет (ревью 26.11.2026, VV-006/VV-029).
  final int? waitHours;

  /// Дата безопасного употребления; null при строковом значении.
  final DateTime? safeDate;
  final String rawText;

  const WithdrawalResult({
    required this.product,
    required this.icon,
    required this.waitHours,
    required this.safeDate,
    required this.rawText,
  });

  /// Строка-запрет из базы («ЗАПРЕЩЁН», «НЕ ДЛЯ ДОЙНЫХ!») — красный
  /// акцент в карточке, без даты. «Не указан» красным не считается.
  bool get isProhibition {
    if (safeDate != null) return false;
    final t = rawText.toUpperCase();
    return t.isNotEmpty && t != 'НЕ УКАЗАН';
  }

  String get waitTimeFormatted {
    final h = waitHours;
    if (h == null) return rawText; // запрет/«Не указан» — дословно
    if (h >= 24) {
      final days = h ~/ 24;
      final hours = h % 24;
      if (hours == 0) return '$days дн';
      return '$days дн $hours ч';
    }
    return '$h ч';
  }

  String get safeDateFormatted {
    final d = safeDate;
    if (d == null) return rawText;
    return '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.'
        '${d.year}';
  }
}

class _WithdrawalResultCard extends StatelessWidget {
  final WithdrawalResult result;

  const _WithdrawalResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    // VV-006/VV-029: запрет («ЗАПРЕЩЁН», «НЕ ДЛЯ ДОЙНЫХ!») — красным,
    // без даты; «Не указан» — нейтрально; число — прежняя зелёная карточка.
    final ban = result.isProhibition;
    final hasDate = result.safeDate != null;
    final muted = !hasDate && !ban; // «Не указан» — без акцента
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              result.icon,
              size: 32,
              color: ban
                  ? AppTheme.errorRed
                  : (muted ? AppTheme.textTertiary : AppTheme.safeGreen),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.product,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (hasDate) ...[
                    Text(
                      'Безопасно с: ${result.safeDateFormatted}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.safeGreen,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Каренция: ${result.waitTimeFormatted}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ] else ...[
                    // Дословное значение базы: запрет или честное
                    // «Не указан» — даты не выдумываем.
                    Text(
                      result.rawText,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: ban ? AppTheme.errorRed : AppTheme.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ban
                          ? 'Применение продукта запрещено — смотрите '
                              'инструкцию производителя'
                          : 'Точных данных в базе нет — смотрите '
                              'инструкцию производителя',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              ban ? Icons.block : Icons.check_circle,
              color: ban
                  ? AppTheme.errorRed
                  : (muted ? AppTheme.textTertiary : AppTheme.safeGreen),
              size: 32,
            ),
          ],
        ),
      ),
    );
  }
}

// v1.18.0: класс _DrugSelector удалён — его заменяет общий DrugPicker
// (поиск с нормализацией ®/ё, loose-матчем и ранжированием).
