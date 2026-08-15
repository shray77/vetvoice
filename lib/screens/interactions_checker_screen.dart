import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/calc_drug.dart';
import '../models/drug_interaction.dart';
import '../providers/vet_provider.dart';
import '../utils/app_theme.dart';

class DrugInteractionExtended {
  final String drug1;
  final String drug2;
  final String severity;
  final String effect;
  final String consequence;
  final String recommendation;

  const DrugInteractionExtended({
    required this.drug1,
    required this.drug2,
    required this.severity,
    required this.effect,
    required this.consequence,
    required this.recommendation,
  });

  factory DrugInteractionExtended.fromJson(Map<String, dynamic> json) {
    return DrugInteractionExtended(
      drug1: json['drug1'] as String? ?? '',
      drug2: json['drug2'] as String? ?? '',
      severity: json['severity'] as String? ?? '',
      effect: json['effect'] as String? ?? '',
      consequence: json['consequence'] as String? ?? '',
      recommendation: json['recommendation'] as String? ?? '',
    );
  }

  Color get severityColor {
    switch (severity) {
      case 'critical':
        return AppTheme.errorRed;
      case 'major':
        return AppTheme.warningOrange;
      case 'moderate':
        return const Color(0xFFEAB308);
      case 'minor':
        return AppTheme.safeGreen;
      default:
        return AppTheme.textSecondary;
    }
  }

  String get severityLabel {
    switch (severity) {
      case 'critical':
        return 'Критическое';
      case 'major':
        return 'Серьёзное';
      case 'moderate':
        return 'Умеренное';
      case 'minor':
        return 'Незначительное';
      default:
        return severity;
    }
  }

  IconData get severityIcon {
    switch (severity) {
      case 'critical':
        return Icons.dangerous_rounded;
      case 'major':
        return Icons.warning_amber_rounded;
      case 'moderate':
        return Icons.info_outline_rounded;
      case 'minor':
        return Icons.check_circle_outline_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }
}

class InteractionsCheckerScreen extends StatefulWidget {
  final VetProvider vetProvider;

  const InteractionsCheckerScreen({super.key, required this.vetProvider});

  @override
  State<InteractionsCheckerScreen> createState() => _InteractionsCheckerScreenState();
}

class _InteractionsCheckerScreenState extends State<InteractionsCheckerScreen> {
  List<DrugInteractionExtended> _allInteractions = [];
  final Map<String, List<DrugInteractionExtended>> _index = {};
  bool _isLoading = true;
  final List<CalcDrug> _selectedDrugs = [];
  List<DrugInteractionExtended> _foundInteractions = [];

  @override
  void initState() {
    super.initState();
    _loadInteractions();
  }

  Future<void> _loadInteractions() async {
    try {
      final jsonString = await rootBundle
          .loadString('assets/data/advanced/drug_interactions.json');
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final list = data['interactions'] as List<dynamic>? ?? [];
      _allInteractions = list
          .map((i) => DrugInteractionExtended.fromJson(i as Map<String, dynamic>))
          .toList();
      for (final inter in _allInteractions) {
        final d1 = inter.drug1.toLowerCase();
        final d2 = inter.drug2.toLowerCase();
        _index.putIfAbsent(d1, () => []).add(inter);
        _index.putIfAbsent(d2, () => []).add(inter);
      }
    } catch (e) {
      debugPrint('Interactions load error: $e');
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _checkInteractions() {
    final found = <DrugInteractionExtended>[];
    for (int i = 0; i < _selectedDrugs.length; i++) {
      for (int j = i + 1; j < _selectedDrugs.length; j++) {
        final drug1 = _selectedDrugs[i];
        final drug2 = _selectedDrugs[j];
        for (final name1 in [drug1.name, drug1.inn]) {
          for (final name2 in [drug2.name, drug2.inn]) {
            final interactions = _index[name1.toLowerCase()] ?? [];
            for (final inter in interactions) {
              if ((inter.drug1.toLowerCase() == name1.toLowerCase() &&
                      inter.drug2.toLowerCase() == name2.toLowerCase()) ||
                  (inter.drug1.toLowerCase() == name2.toLowerCase() &&
                      inter.drug2.toLowerCase() == name1.toLowerCase())) {
                if (!found.any((f) =>
                    f.drug1 == inter.drug1 && f.drug2 == inter.drug2)) {
                  found.add(inter);
                }
              }
            }
          }
        }
      }
    }
    setState(() {
      _foundInteractions = found;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(title: const Text('Проверка совместимости')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.safeGreen))
          : Column(
              children: [
                // Панель выбранных препаратов
                Container(
                  margin: const EdgeInsets.all(16),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Выбранные препараты (${_selectedDrugs.length})',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimaryColor(context),
                            ),
                          ),
                          if (_selectedDrugs.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedDrugs.clear();
                                  _foundInteractions.clear();
                                });
                              },
                              child: const Text(
                                'Очистить',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.errorRed,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_selectedDrugs.isEmpty)
                        Text(
                          'Добавьте 2 или более препаратов для сопоставления',
                          style: TextStyle(color: AppTheme.textTertiaryColor(context), fontSize: 13),
                        )
                      else
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _selectedDrugs.asMap().entries.map((entry) {
                            final i = entry.key;
                            final drug = entry.value;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.safeGreen.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.safeGreen.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    drug.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimaryColor(context),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedDrugs.removeAt(i);
                                        _checkInteractions();
                                      });
                                    },
                                    child: Icon(Icons.close, size: 14, color: AppTheme.textSecondaryColor(context)),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _showAddDrugDialog,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text(_selectedDrugs.isEmpty ? 'Добавить препарат' : 'Добавить ещё'),
                        ),
                      ),
                    ],
                  ),
                ),

                // Результаты проверки
                Expanded(
                  child: _selectedDrugs.length < 2
                      ? _buildHint()
                      : _foundInteractions.isEmpty
                          ? _buildSafeResult()
                          : _buildInteractionsList(),
                ),
              ],
            ),
    );
  }

  Widget _buildHint() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.science_outlined, size: 48, color: AppTheme.textTertiaryColor(context)),
          const SizedBox(height: 14),
          Text(
            'Добавьте минимум 2 препарата',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'База содержит ${_allInteractions.length} взаимодействий',
            style: TextStyle(fontSize: 12, color: AppTheme.textTertiaryColor(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildSafeResult() {
    final isDark = AppTheme.isDark(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.safeGreen.withOpacity(isDark ? 0.2 : 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: AppTheme.safeGreen, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              'Несовместимостей не найдено',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Проверена комбинация ${_selectedDrugs.length} препаратов',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractionsList() {
    final severityOrder = {'critical': 0, 'major': 1, 'moderate': 2, 'minor': 3};
    final sorted = List<DrugInteractionExtended>.from(_foundInteractions)
      ..sort((a, b) =>
          (severityOrder[a.severity] ?? 4).compareTo(severityOrder[b.severity] ?? 4));

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return _InteractionCard(interaction: sorted[index]);
      },
    );
  }

  void _showAddDrugDialog() {
    final allDrugs = widget.vetProvider.allDrugs;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(AppTheme.paddingMedium),
          decoration: BoxDecoration(
            color: AppTheme.cardColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: _AddDrugSearch(
            allDrugs: allDrugs,
            excludeDrugs: _selectedDrugs,
            onSelected: (drug) {
              setState(() {
                _selectedDrugs.add(drug);
                if (_selectedDrugs.length >= 2) {
                  _checkInteractions();
                }
              });
              Navigator.pop(ctx);
            },
          ),
        );
      },
    );
  }
}

class _InteractionCard extends StatelessWidget {
  final DrugInteractionExtended interaction;

  const _InteractionCard({required this.interaction});

  @override
  Widget build(BuildContext context) {
    final color = interaction.severityColor;
    final isDark = AppTheme.isDark(context);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: color.withOpacity(0.35), width: 1.5),
        boxShadow: AppTheme.cardShadow(context),
      ),
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(interaction.severityIcon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${interaction.drug1} + ${interaction.drug2}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  interaction.severityLabel,
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (interaction.effect.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              interaction.effect,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
          ],
          if (interaction.consequence.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Последствия: ${interaction.consequence}',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor(context)),
            ),
          ],
          if (interaction.recommendation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurfaceLight : AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.tips_and_updates_outlined, size: 14, color: AppTheme.safeGreen),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      interaction.recommendation,
                      style: TextStyle(fontSize: 11, color: AppTheme.textPrimaryColor(context)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddDrugSearch extends StatefulWidget {
  final List<dynamic> allDrugs;
  final List<CalcDrug> excludeDrugs;
  final ValueChanged<CalcDrug> onSelected;

  const _AddDrugSearch({
    required this.allDrugs,
    required this.excludeDrugs,
    required this.onSelected,
  });

  @override
  State<_AddDrugSearch> createState() => _AddDrugSearchState();
}

class _AddDrugSearchState extends State<_AddDrugSearch> {
  final TextEditingController _controller = TextEditingController();
  List<CalcDrug> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filter('');
  }

  void _filter(String query) {
    final q = query.toLowerCase().trim();
    final excludeIds = widget.excludeDrugs.map((d) => d.id).toSet();

    final calcDrugs = widget.allDrugs
        .whereType<CalcDrug>()
        .where((d) => !excludeIds.contains(d.id))
        .toList();

    if (q.isEmpty) {
      _filtered = calcDrugs.take(50).toList();
    } else {
      _filtered = calcDrugs
          .where((d) =>
              d.name.toLowerCase().contains(q) ||
              d.inn.toLowerCase().contains(q))
          .take(50)
          .toList();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Выберите препарат',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close, color: AppTheme.textSecondaryColor(context)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          autofocus: true,
          style: TextStyle(fontSize: 14, color: AppTheme.textPrimaryColor(context)),
          decoration: const InputDecoration(
            hintText: 'Поиск по названию или МНН...',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: _filter,
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.separated(
            itemCount: _filtered.length,
            separatorBuilder: (_, __) => Divider(color: AppTheme.dividerColor(context), height: 1),
            itemBuilder: (context, index) {
              final drug = _filtered[index];
              return ListTile(
                title: Text(
                  drug.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                subtitle: drug.inn.isNotEmpty
                    ? Text(
                        drug.inn,
                        style: TextStyle(fontSize: 12, color: AppTheme.textTertiaryColor(context)),
                      )
                    : null,
                onTap: () => widget.onSelected(drug),
              );
            },
          ),
        ),
      ],
    );
  }
}
