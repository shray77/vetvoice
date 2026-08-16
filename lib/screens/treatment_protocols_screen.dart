// TreatmentProtocolsScreen — экран протоколов лечения.
//
// Показывает 124 протокола из treatment_protocols.json.
// Каждый протокол = {diagnosis, species, treatment: {primary, support, symptomatic}}.
//
// Возможности:
//   - Поиск по диагнозу/виду животного
//   - Фильтр по category (особо опасные / инфекционные / и т.д.)
//   - Раскрытие протокола → список препаратов с дозами
//   - Кнопка «Применить» → передаёт первый препарат в калькулятор
//
// Зависимости:
//   - treatment_protocols.json (assets/data/advanced/)
//   - AppTheme (lib/utils/app_theme.dart)

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/calc_drug.dart';
import '../providers/vet_provider.dart';
import '../utils/app_theme.dart';

class TreatmentProtocol {
  final int diseaseId;
  final String diagnosis;
  final String code;
  final String category;
  final String categoryName;
  final List<String> species;
  final String pathogenType;
  final String severity;
  final String orderNumber;
  final Map<String, dynamic> treatment;

  const TreatmentProtocol({
    required this.diseaseId,
    required this.diagnosis,
    required this.code,
    required this.category,
    required this.categoryName,
    required this.species,
    required this.pathogenType,
    required this.severity,
    required this.orderNumber,
    required this.treatment,
  });

  factory TreatmentProtocol.fromJson(Map<String, dynamic> json) {
    return TreatmentProtocol(
      diseaseId: (json['disease_id'] as num?)?.toInt() ?? 0,
      diagnosis: json['diagnosis'] as String? ?? '',
      code: json['code'] as String? ?? '',
      category: json['category'] as String? ?? '',
      categoryName: json['category_name'] as String? ?? '',
      species: (json['species'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      pathogenType: json['pathogen_type'] as String? ?? '',
      severity: json['severity'] as String? ?? '',
      orderNumber: json['order_number'] as String? ?? '',
      treatment: json['treatment'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Получить список всех препаратов в протоколе.
  List<Map<String, dynamic>> get allDrugs {
    final result = <Map<String, dynamic>>[];
    for (final section in ['primary', 'support', 'symptomatic', 'prevention']) {
      final s = treatment[section];
      if (s is Map<String, dynamic>) {
        final drugs = s['drugs'];
        if (drugs is List) {
          for (final d in drugs) {
            if (d is Map<String, dynamic>) {
              final copy = Map<String, dynamic>.from(d);
              copy['section'] = _sectionLabel(section);
              result.add(copy);
            }
          }
        }
      }
    }
    return result;
  }

  String _sectionLabel(String section) {
    switch (section) {
      case 'primary':
        return 'Основное лечение';
      case 'support':
        return 'Поддерживающая терапия';
      case 'symptomatic':
        return 'Симптоматическое';
      case 'prevention':
        return 'Профилактика';
      default:
        return section;
    }
  }

  Color get severityColor {
    switch (severity) {
      case 'severe':
        return AppTheme.errorRed;
      case 'moderate':
        return AppTheme.warningOrange;
      case 'mild':
        return AppTheme.safeGreen;
      default:
        return AppTheme.textSecondary;
    }
  }

  String get severityLabel {
    switch (severity) {
      case 'severe':
        return 'Тяжёлое';
      case 'moderate':
        return 'Средней тяжести';
      case 'mild':
        return 'Лёгкое';
      default:
        return severity;
    }
  }
}

class TreatmentProtocolsScreen extends StatefulWidget {
  final VetProvider vetProvider;
  final void Function(CalcDrug)? onDrugSelected;

  const TreatmentProtocolsScreen({
    super.key,
    required this.vetProvider,
    this.onDrugSelected,
  });

  @override
  State<TreatmentProtocolsScreen> createState() =>
      _TreatmentProtocolsScreenState();
}

class _TreatmentProtocolsScreenState extends State<TreatmentProtocolsScreen> {
  List<TreatmentProtocol> _allProtocols = [];
  List<TreatmentProtocol> _filtered = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadProtocols();
  }

  Future<void> _loadProtocols() async {
    try {
      final jsonString = await rootBundle
          .loadString('assets/data/advanced/treatment_protocols.json');
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final list = data['protocols'] as List<dynamic>? ?? [];
      _allProtocols = list
          .map((p) => TreatmentProtocol.fromJson(p as Map<String, dynamic>))
          .toList();
      _filtered = _allProtocols;
    } catch (e) {
      debugPrint('TreatmentProtocols load error: $e');
    }
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filtered = _allProtocols.where((p) {
        // Фильтр по категории
        if (_selectedCategory != null && p.category != _selectedCategory) {
          return false;
        }
        // Фильтр по поиску
        if (query.isEmpty) return true;
        return p.diagnosis.toLowerCase().contains(query) ||
            p.code.toLowerCase().contains(query) ||
            p.species.any((s) => s.toLowerCase().contains(query)) ||
            p.pathogenType.toLowerCase().contains(query);
      }).toList();
    });
  }

  List<String> get _categories {
    final cats = _allProtocols.map((p) => p.category).toSet().toList();
    cats.sort();
    return cats;
  }

  String _categoryLabel(String cat) {
    return _allProtocols
        .firstWhere((p) => p.category == cat, orElse: () => _allProtocols.first)
        .categoryName;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('📜 Протоколы лечения')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Поиск
                Container(
                  padding: const EdgeInsets.all(AppTheme.paddingMedium),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Поиск: диагноз, вид, код...',
                      prefixIcon: const Icon(Icons.search,
                          color: AppTheme.safeGreen),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _applyFilters();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppTheme.backgroundGray,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusLarge),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (_) {
                      setState(() {});
                      _applyFilters();
                    },
                  ),
                ),
                // Фильтр по категориям
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      FilterChip(
                        label: const Text('Все'),
                        selected: _selectedCategory == null,
                        onSelected: (_) {
                          setState(() {
                            _selectedCategory = null;
                          });
                          _applyFilters();
                        },
                      ),
                      const SizedBox(width: 6),
                      ..._categories.map((cat) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: Text(_categoryLabel(cat)),
                            selected: _selectedCategory == cat,
                            onSelected: (_) {
                              setState(() {
                                _selectedCategory =
                                    _selectedCategory == cat ? null : cat;
                              });
                              _applyFilters();
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Счётчик
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${_filtered.length} протоколов',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ),
                ),
                // Список протоколов
                Expanded(
                  child: _filtered.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(AppTheme.paddingMedium),
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            return _ProtocolCard(
                              protocol: _filtered[index],
                              vetProvider: widget.vetProvider,
                              onDrugSelected: widget.onDrugSelected,
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📜', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            'Не найдено протоколов',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ],
      ),
    );
  }
}

class _ProtocolCard extends StatefulWidget {
  final TreatmentProtocol protocol;
  final VetProvider vetProvider;
  final void Function(CalcDrug)? onDrugSelected;

  const _ProtocolCard({
    required this.protocol,
    required this.vetProvider,
    this.onDrugSelected,
  });

  @override
  State<_ProtocolCard> createState() => _ProtocolCardState();
}

class _ProtocolCardState extends State<_ProtocolCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.protocol;
    final sevColor = p.severityColor;

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.paddingSmall),
      child: Column(
        children: [
          // Заголовок
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusLarge)),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.paddingMedium),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 50,
                    decoration: BoxDecoration(
                      color: sevColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.diagnosis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          children: [
                            if (p.code.isNotEmpty)
                              _MiniChip(
                                  label: p.code, color: AppTheme.maleBlue),
                            _MiniChip(
                                label: p.severityLabel, color: sevColor),
                            if (p.species.isNotEmpty)
                              _MiniChip(
                                  label: p.species.take(3).join(', '),
                                  color: AppTheme.textSecondary),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          // Раскрытое содержимое
          if (_expanded)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p.pathogenType.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Тип: ${p.pathogenType}',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ),
                  ...p.allDrugs.map((d) => _ProtocolDrugItem(
                        drug: d,
                        vetProvider: widget.vetProvider,
                        onDrugSelected: widget.onDrugSelected,
                      )),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ProtocolDrugItem extends StatelessWidget {
  final Map<String, dynamic> drug;
  final VetProvider vetProvider;
  final void Function(CalcDrug)? onDrugSelected;

  const _ProtocolDrugItem({
    required this.drug,
    required this.vetProvider,
    this.onDrugSelected,
  });

  @override
  Widget build(BuildContext context) {
    final name = drug['name'] as String? ?? '';
    final inn = drug['inn'] as String? ?? '';
    final dose = drug['dose'] as String? ?? '';
    final route = drug['route'] as String? ?? '';
    final frequency = drug['frequency'] as String? ?? '';
    final duration = drug['duration'] as String? ?? '';
    final section = drug['section'] as String? ?? '';
    final pharmGroup = drug['pharm_group'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.backgroundGray,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (section.isNotEmpty)
                  Text(
                    section,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.textTertiary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
            if (inn.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  inn,
                  style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                      fontStyle: FontStyle.italic),
                ),
              ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                if (dose.isNotEmpty) _MiniInfo(label: '💊 $dose'),
                if (route.isNotEmpty) _MiniInfo(label: '📍 $route'),
                if (frequency.isNotEmpty) _MiniInfo(label: '⏰ $frequency'),
                if (duration.isNotEmpty) _MiniInfo(label: '📅 $duration'),
              ],
            ),
            if (pharmGroup.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  pharmGroup,
                  style: TextStyle(
                      fontSize: 10, color: AppTheme.textTertiary),
                ),
              ),
            // Кнопка «Применить»
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  // Найдём препарат в vetProvider
                  final calcDrug = vetProvider.findCalcDrugByName(name);
                  if (calcDrug != null && onDrugSelected != null) {
                    onDrugSelected!(calcDrug);
                    Navigator.pop(context);
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Препарат "$name" не найден в базе калькулятора'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.calculate, size: 16),
                label: const Text('Рассчитать дозу', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  final String label;

  const _MiniInfo({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        color: AppTheme.textSecondary,
      ),
    );
  }
}
