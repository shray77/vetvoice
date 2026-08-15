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
  String? _selectedSpecies;

  static const List<(String, String)> _allSpeciesList = [
    ('Собака', '🐕'),
    ('Кошка', '🐈'),
    ('КРС', '🐄'),
    ('Лошадь', '🐎'),
    ('Свиньи', '🐖'),
    ('МРС', '🐑'),
    ('Птица', '🦜'),
    ('Грызуны', '🐹'),
  ];

  @override
  void initState() {
    super.initState();
    final curAnimal = widget.vetProvider.selectedAnimal?.name;
    if (curAnimal != null && curAnimal.isNotEmpty) {
      _selectedSpecies = curAnimal;
    }
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
      _applyFilters();
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
        if (_selectedSpecies != null && _selectedSpecies!.isNotEmpty) {
          final sLower = _selectedSpecies!.toLowerCase();
          final matchesSpecies = p.species.any((s) {
            final item = s.toLowerCase();
            return item.contains(sLower) || sLower.contains(item);
          });
          if (!matchesSpecies) return false;
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
                      hintText: 'Поиск диагноза, кода, препарата...',
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
                    onChanged: (_) => _applyFilters(),
                  ),
                ),

                // Фильтр по видам животных (с предвыбором активного животного)
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildFilterChip('🐾 Все виды', _selectedSpecies == null, () {
                        setState(() => _selectedSpecies = null);
                        _applyFilters();
                      }),
                      ..._allSpeciesList.map((pair) {
                        final (name, icon) = pair;
                        final isSel = _selectedSpecies?.toLowerCase() == name.toLowerCase();
                        return _buildFilterChip(
                          '$icon $name',
                          isSel,
                          () {
                            setState(() {
                              _selectedSpecies = isSel ? null : name;
                            });
                            _applyFilters();
                          },
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // Фильтр по категориям
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildSubFilterChip('Все категории', _selectedCategory == null, () {
                        setState(() => _selectedCategory = null);
                        _applyFilters();
                      }),
                      ..._categories.map((cat) {
                        return _buildSubFilterChip(
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
                        'Найдено протоколов: ${_filtered.length}'
                        '${_selectedSpecies != null ? ' для $_selectedSpecies' : ''}',
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
                            final protocol = _filtered[index];
                            return _ProtocolCard(
                              protocol: protocol,
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
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.safeGreen.withOpacity(isDark ? 0.3 : 0.15)
                : (isDark ? AppTheme.darkSurfaceLight : AppTheme.surfaceLight),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            border: Border.all(
              color: isSelected ? AppTheme.safeGreen : AppTheme.borderColor(context),
              width: isSelected ? 1.5 : 1,
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

  Widget _buildSubFilterChip(String label, bool isSelected, VoidCallback onTap) {
    final isDark = AppTheme.isDark(context);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.maleBlue.withOpacity(isDark ? 0.25 : 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppTheme.maleBlue : AppTheme.dividerColor(context),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppTheme.maleBlue : AppTheme.textSecondaryColor(context),
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
          Icon(Icons.search_off_rounded, size: 48, color: AppTheme.textTertiaryColor(context)),
          const SizedBox(height: 12),
          Text(
            'Протоколы не найдены',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimaryColor(context)),
          ),
          const SizedBox(height: 4),
          Text(
            'Попробуйте изменить вид животного или поисковый запрос',
            style: TextStyle(fontSize: 12, color: AppTheme.textTertiaryColor(context)),
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
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.protocol;
    final isDark = AppTheme.isDark(context);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderColor(context)),
        boxShadow: AppTheme.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.paddingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.diagnosis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimaryColor(context),
                              ),
                            ),
                            if (p.code.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  p.code,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondaryColor(context),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: p.severityColor.withOpacity(isDark ? 0.25 : 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          p.severityLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: p.severityColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (p.categoryName.isNotEmpty)
                        _buildTag(p.categoryName, AppTheme.safeGreen, isDark),
                      if (p.species.isNotEmpty)
                        _buildTag(p.species.join(', '), AppTheme.maleBlue, isDark),
                      if (p.pathogenType.isNotEmpty)
                        _buildTag(p.pathogenType, AppTheme.warningOrange, isDark),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Препаратов в схеме: ${p.allDrugs.length}',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor(context), fontWeight: FontWeight.w600),
                      ),
                      Icon(
                        _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.safeGreen,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Раскрытая схема
          if (_isExpanded) ...[
            Divider(color: AppTheme.dividerColor(context), height: 1),
            Padding(
              padding: const EdgeInsets.all(AppTheme.paddingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...p.allDrugs.map((d) => _buildDrugRow(context, d)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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

  Widget _buildDrugRow(BuildContext context, Map<String, dynamic> d) {
    final name = d['name'] as String? ?? '';
    final inn = d['inn'] as String? ?? '';
    final dose = d['dose'] as String? ?? '';
    final route = d['route'] as String? ?? '';
    final freq = d['frequency'] as String? ?? '';
    final duration = d['duration'] as String? ?? '';
    final note = d['note'] as String? ?? '';
    final section = d['section'] as String? ?? '';

    final calcDrug = widget.vetProvider.findCalcDrugByName(inn.isNotEmpty ? inn : name);
    final isDark = AppTheme.isDark(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceLight : AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (section.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          section.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: AppTheme.safeGreen,
                          ),
                        ),
                      ),
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimaryColor(context),
                      ),
                    ),
                    if (inn.isNotEmpty && inn != name)
                      Text(
                        inn,
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: AppTheme.textSecondaryColor(context),
                        ),
                      ),
                  ],
                ),
              ),
              if (calcDrug != null && widget.onDrugSelected != null)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                  icon: const Icon(Icons.calculate_rounded, size: 16, color: AppTheme.safeGreen),
                  label: const Text('Рассчитать', style: TextStyle(fontSize: 12, color: AppTheme.safeGreen)),
                  onPressed: () {
                    widget.onDrugSelected!(calcDrug);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (dose.isNotEmpty) _buildDetailChip('Доза: $dose'),
              if (route.isNotEmpty) _buildDetailChip('Путь: $route'),
              if (freq.isNotEmpty) _buildDetailChip('Частота: $freq'),
              if (duration.isNotEmpty) _buildDetailChip('Курс: $duration'),
            ],
          ),
          if (note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '💡 $note',
                style: TextStyle(fontSize: 11, color: AppTheme.textTertiaryColor(context)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailChip(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
    );
  }
}
