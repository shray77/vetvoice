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
  State<TreatmentProtocolsScreen> createState() => _TreatmentProtocolsScreenState();
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
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
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
        if (_selectedCategory != null && p.category != _selectedCategory) {
          return false;
        }
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
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(title: const Text('Протоколы лечения')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.safeGreen))
          : Column(
              children: [
                // Поиск
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppTheme.textPrimaryColor(context),
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Поиск диагноза, кода, животного...',
                      prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textSecondaryColor(context)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: AppTheme.textSecondaryColor(context)),
                              onPressed: () {
                                _searchController.clear();
                                _applyFilters();
                              },
                            )
                          : null,
                    ),
                    onChanged: (_) {
                      setState(() {});
                      _applyFilters();
                    },
                  ),
                ),

                // Фильтр по категориям
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildFilterChip('Все', _selectedCategory == null, () {
                        setState(() => _selectedCategory = null);
                        _applyFilters();
                      }),
                      ..._categories.map((cat) {
                        return _buildFilterChip(
                          _categoryLabel(cat),
                          _selectedCategory == cat,
                          () {
                            setState(() {
                              _selectedCategory = _selectedCategory == cat ? null : cat;
                            });
                            _applyFilters();
                          },
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Счётчик
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Найдено протоколов: ${_filtered.length}',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor(context), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Список протоколов
                Expanded(
                  child: _filtered.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
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

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    final isDark = AppTheme.isDark(context);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.safeGreen.withOpacity(isDark ? 0.25 : 0.12)
                : AppTheme.cardColor(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            border: Border.all(
              color: isSelected ? AppTheme.safeGreen : AppTheme.borderColor(context),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppTheme.safeGreen : AppTheme.textPrimaryColor(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_rounded, size: 48, color: AppTheme.textTertiaryColor(context)),
          const SizedBox(height: 16),
          Text(
            'Протоколов не найдено',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryColor(context),
            ),
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
    final isDark = AppTheme.isDark(context);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderColor(context)),
        boxShadow: AppTheme.cardShadow(context),
      ),
      child: Column(
        children: [
          // Заголовок
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.paddingMedium),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 44,
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
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimaryColor(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (p.code.isNotEmpty)
                              _buildBadge(p.code, AppTheme.maleBlue, isDark),
                            _buildBadge(p.severityLabel, sevColor, isDark),
                            if (p.species.isNotEmpty)
                              _buildBadge(p.species.take(3).join(', '), AppTheme.textSecondaryColor(context), isDark),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ],
              ),
            ),
          ),

          // Раскрытое содержимое
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: AppTheme.dividerColor(context), height: 1),
                  const SizedBox(height: 12),
                  if (p.pathogenType.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Тип возбудителя: ${p.pathogenType}',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor(context)),
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

  Widget _buildBadge(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.25 : 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
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
    final dosage = drug['dosage'] as String? ?? '';
    final section = drug['section'] as String? ?? '';
    final isDark = AppTheme.isDark(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceLight : AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.maleBlue.withOpacity(isDark ? 0.25 : 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        section,
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.maleBlue),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryColor(context),
                        ),
                      ),
                    ),
                  ],
                ),
                if (inn.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      inn,
                      style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.textSecondaryColor(context)),
                    ),
                  ),
                if (dosage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Дозировка: $dosage',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.safeGreen),
                    ),
                  ),
              ],
            ),
          ),
          if (onDrugSelected != null)
            TextButton(
              onPressed: () {
                final found = vetProvider.findCalcDrugByName(name) ??
                    (inn.isNotEmpty ? vetProvider.findCalcDrugByName(inn) : null);
                if (found != null) {
                  onDrugSelected!(found);
                  Navigator.pop(context);
                }
              },
              child: const Text('Выбрать', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}
