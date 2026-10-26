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
//   2. Выбирает вид животного (КРС / МРС / Свиньи / Птица)
//   3. Указывает дату введения
//   4. Получает даты безопасного употребления мяса/молока/яиц
//
// Зависимости:
//   - VetProvider для доступа к drugs
//   - AppTheme

import 'package:flutter/material.dart';
import '../models/calc_drug.dart';
import '../providers/vet_provider.dart';
import '../utils/app_theme.dart';
// v1.18.0 (Фаза 2): каркас + DrugPicker вместо самописного _DrugSelector
import '../widgets/common/app_scaffold.dart';
import '../widgets/common/drug_picker.dart';
import '../widgets/common/haptics.dart';
import '../widgets/common/status_chip.dart';

class WithdrawalCalculatorScreen extends StatefulWidget {
  final VetProvider vetProvider;

  const WithdrawalCalculatorScreen({
    super.key,
    required this.vetProvider,
  });

  @override
  State<WithdrawalCalculatorScreen> createState() =>
      _WithdrawalCalculatorScreenState();
}

class _WithdrawalCalculatorScreenState
    extends State<WithdrawalCalculatorScreen> {
  CalcDrug? _selectedDrug;
  String _selectedAnimal = 'КРС';
  DateTime _applicationDate = DateTime.now();
  List<WithdrawalResult> _results = [];

  final List<String> _productAnimals = [
    'КРС',
    'МРС',
    'Свиньи',
    'Птица',
  ];

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
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
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

    // Из withdrawalText — парсим «Мясо: 28 сут; Молоко: 120 ч»
    final withdrawalText = drug.withdrawalText;
    if (withdrawalText.isNotEmpty) {
      // Парсим «Мясо: N сут/дн/ч; Молоко: N ч/сут; Яйца: N сут»
      final patterns = [
        ('Мясо', RegExp(r'мясо[^\d]*(\d+)\s*(сут|дн|ч|час)', caseSensitive: false), Icons.restaurant),
        ('Молоко', RegExp(r'молоко[^\d]*(\d+)\s*(сут|дн|ч|час)', caseSensitive: false), Icons.water_drop),
        ('Яйца', RegExp(r'яйц[^\d]*(\d+)\s*(сут|дн|ч|час)', caseSensitive: false), Icons.egg),
      ];
      for (final (product, regex, icon) in patterns) {
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
            product: product,
            icon: icon,
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
}

class WithdrawalResult {
  final String product;
  final IconData icon;
  final int waitHours;
  final DateTime safeDate;
  final String rawText;

  const WithdrawalResult({
    required this.product,
    required this.icon,
    required this.waitHours,
    required this.safeDate,
    required this.rawText,
  });

  String get waitTimeFormatted {
    if (waitHours >= 24) {
      final days = waitHours ~/ 24;
      final hours = waitHours % 24;
      if (hours == 0) return '$days дн';
      return '$days дн $hours ч';
    }
    return '$waitHours ч';
  }

  String get safeDateFormatted {
    return '${safeDate.day.toString().padLeft(2, '0')}.'
        '${safeDate.month.toString().padLeft(2, '0')}.'
        '${safeDate.year}';
  }
}

class _WithdrawalResultCard extends StatelessWidget {
  final WithdrawalResult result;

  const _WithdrawalResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(result.icon, size: 32, color: AppTheme.safeGreen),
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
                ],
              ),
            ),
            const Icon(Icons.check_circle,
                color: AppTheme.safeGreen, size: 32),
          ],
        ),
      ),
    );
  }
}

// v1.18.0: класс _DrugSelector удалён — его заменяет общий DrugPicker
// (поиск с нормализацией ®/ё, loose-матчем и ранжированием).
