import 'package:flutter/material.dart';
import '../models/calc_drug.dart';
import '../providers/vet_provider.dart';
import '../utils/app_theme.dart';

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
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(title: const Text('Калькулятор каренции')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Описание
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.infoBlue.withOpacity(isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: Border.all(color: AppTheme.infoBlue.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppTheme.infoBlue, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Расчёт даты безопасного использования молока, мяса и яиц после применения препарата',
                      style: TextStyle(fontSize: 12, color: AppTheme.textPrimaryColor(context), height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Карточка выбора параметров
            Container(
              padding: const EdgeInsets.all(AppTheme.paddingMedium),
              decoration: BoxDecoration(
                color: AppTheme.cardColor(context),
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                border: Border.all(color: AppTheme.borderColor(context)),
                boxShadow: AppTheme.cardShadow(context),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Препарат',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _DrugSelector(
                    vetProvider: widget.vetProvider,
                    selectedDrug: _selectedDrug,
                    onSelected: (drug) {
                      setState(() {
                        _selectedDrug = drug;
                        _calculate();
                      });
                    },
                  ),
                  const SizedBox(height: 14),

                  Text(
                    'Вид продуктивного животного',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _productAnimals.map((animal) {
                      final isSel = _selectedAnimal == animal;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedAnimal = animal;
                            _calculate();
                          });
                        },
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSel
                                ? AppTheme.safeGreen.withOpacity(isDark ? 0.25 : 0.12)
                                : (isDark ? AppTheme.darkSurfaceLight : AppTheme.surfaceLight),
                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            border: Border.all(
                              color: isSel ? AppTheme.safeGreen : AppTheme.borderColor(context),
                            ),
                          ),
                          child: Text(
                            animal,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                              color: isSel ? AppTheme.safeGreen : AppTheme.textPrimaryColor(context),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    'Дата последнего введения',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _applicationDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (date != null) {
                        setState(() {
                          _applicationDate = date;
                          _calculate();
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurfaceLight : AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        border: Border.all(color: AppTheme.borderColor(context)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, color: AppTheme.safeGreen, size: 18),
                          const SizedBox(width: 10),
                          Text(
                            '${_applicationDate.day.toString().padLeft(2, '0')}.'
                            '${_applicationDate.month.toString().padLeft(2, '0')}.'
                            '${_applicationDate.year}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimaryColor(context),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Изменить',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.safeGreen),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Результаты
            if (_results.isNotEmpty) ...[
              Text(
                'Сроки ожидания продукции',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
              const SizedBox(height: 10),
              ..._results.map((r) => _WithdrawalResultCard(result: r)),
            ] else if (_selectedDrug != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.warningOrange.withOpacity(isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(color: AppTheme.warningOrange.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppTheme.warningOrange, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      'Для данного препарата нет данных по каренции в базе',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.warningOrange,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Обратитесь к инструкции производителя',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor(context)),
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

    final withdrawalText = drug.withdrawalText;
    if (withdrawalText.isNotEmpty) {
      final patterns = [
        ('Мясо', RegExp(r'мясо[^\d]*(\d+)\s*(сут|дн|ч|час)', caseSensitive: false), '🥩'),
        ('Молоко', RegExp(r'молоко[^\d]*(\d+)\s*(сут|дн|ч|час)', caseSensitive: false), '🥛'),
        ('Яйца', RegExp(r'яйц[^\d]*(\d+)\s*(сут|дн|ч|час)', caseSensitive: false), '🥚'),
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

    if (results.isEmpty && drug.withdrawalDays > 0) {
      final safeDate =
          _applicationDate.add(Duration(days: drug.withdrawalDays));
      results.add(WithdrawalResult(
        product: 'Мясо (общая каренция)',
        icon: '🥩',
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
  final String icon;
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
      if (hours == 0) return '$days дн.';
      return '$days дн. $hours ч.';
    }
    return '$waitHours ч.';
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
    final isDark = AppTheme.isDark(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.safeGreen.withOpacity(0.35)),
        boxShadow: AppTheme.cardShadow(context),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.safeGreen.withOpacity(isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Center(
              child: Text(result.icon, style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.product,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Безопасно с ${result.safeDateFormatted}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppTheme.safeGreenLight : AppTheme.safeGreenDark,
                  ),
                ),
                Text(
                  'Период ожидания: ${result.waitTimeFormatted}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textTertiaryColor(context),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.verified_rounded, color: AppTheme.safeGreen, size: 28),
        ],
      ),
    );
  }
}

class _DrugSelector extends StatefulWidget {
  final VetProvider vetProvider;
  final CalcDrug? selectedDrug;
  final Function(CalcDrug) onSelected;

  const _DrugSelector({
    required this.vetProvider,
    required this.selectedDrug,
    required this.onSelected,
  });

  @override
  State<_DrugSelector> createState() => _DrugSelectorState();
}

class _DrugSelectorState extends State<_DrugSelector> {
  final TextEditingController _controller = TextEditingController();
  bool _showDropdown = false;
  List<CalcDrug> _filtered = [];

  @override
  void initState() {
    super.initState();
    if (widget.selectedDrug != null) {
      _controller.text = widget.selectedDrug!.name;
    }
    _filtered = widget.vetProvider.allDrugs
        .whereType<CalcDrug>()
        .where((d) => d.withdrawalDays > 0 || d.withdrawalText.isNotEmpty)
        .toList();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _controller,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor(context),
          ),
          decoration: InputDecoration(
            hintText: 'Выберите или найдите препарат...',
            prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textSecondaryColor(context)),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: AppTheme.textSecondaryColor(context)),
                    onPressed: () {
                      _controller.clear();
                      setState(() {
                        _showDropdown = false;
                      });
                    },
                  )
                : null,
          ),
          onChanged: (value) {
            final q = value.toLowerCase();
            setState(() {
              _showDropdown = value.isNotEmpty;
              _filtered = widget.vetProvider.allDrugs
                  .whereType<CalcDrug>()
                  .where((d) {
                if (d.withdrawalDays == 0 && d.withdrawalText.isEmpty) {
                  return false;
                }
                return d.name.toLowerCase().contains(q) ||
                    d.inn.toLowerCase().contains(q);
              }).toList();
            });
          },
          onTap: () {
            setState(() {
              _showDropdown = _controller.text.isNotEmpty;
            });
          },
        ),
        if (_showDropdown && _filtered.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: AppTheme.cardColor(context),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(color: AppTheme.borderColor(context)),
              boxShadow: AppTheme.cardShadow(context),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _filtered.length > 40 ? 40 : _filtered.length,
              separatorBuilder: (_, __) => Divider(color: AppTheme.dividerColor(context), height: 1),
              itemBuilder: (context, index) {
                final drug = _filtered[index];
                final catColor = AppTheme.getCategoryColor(drug.category);
                return ListTile(
                  dense: true,
                  leading: Container(
                    width: 4,
                    height: 28,
                    decoration: BoxDecoration(
                      color: catColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  title: Text(
                    drug.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor(context),
                    ),
                  ),
                  subtitle: Text(
                    drug.withdrawalText.isNotEmpty
                        ? drug.withdrawalText
                        : '${drug.withdrawalDays} дн.',
                    style: TextStyle(fontSize: 11, color: AppTheme.textTertiaryColor(context)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    widget.onSelected(drug);
                    _controller.text = drug.name;
                    setState(() {
                      _showDropdown = false;
                    });
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
