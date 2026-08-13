// InteractionsCheckerScreen — интерактивная проверка совместимости препаратов.
//
// Пользователь добавляет 2-3 препарата, видит все их взаимодействия.
// Использует drug_interactions.json (severity: critical/major/moderate/minor).
//
// Логика:
//   1. Загружаем drug_interactions.json
//   2. Строим индекс: (drug1, drug2) -> [interaction]
//   3. Пользователь добавляет препараты (по названию или МНН)
//   4. Проверяем все пары выбранных препаратов
//   5. Показываем результаты с цветовой кодировкой по severity
//
// Зависимости:
//   - drug_interactions.json (assets/data/advanced/)
//   - VetProvider для поиска препаратов

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
        return Colors.amber;
      case 'minor':
        return AppTheme.safeGreen;
      default:
        return AppTheme.textSecondary;
    }
  }

  String get severityLabel {
    switch (severity) {
      case 'critical':
        return '⚠️ Критическое';
      case 'major':
        return '🔴 Серьёзное';
      case 'moderate':
        return '🟡 Умеренное';
      case 'minor':
        return '🟢 Незначительное';
      default:
        return severity;
    }
  }

  IconData get severityIcon {
    switch (severity) {
      case 'critical':
        return Icons.dangerous;
      case 'major':
        return Icons.warning;
      case 'moderate':
        return Icons.info;
      case 'minor':
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }
}

class InteractionsCheckerScreen extends StatefulWidget {
  final VetProvider vetProvider;

  const InteractionsCheckerScreen({super.key, required this.vetProvider});

  @override
  State<InteractionsCheckerScreen> createState() =>
      _InteractionsCheckerScreenState();
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
          .map((i) =>
              DrugInteractionExtended.fromJson(i as Map<String, dynamic>))
          .toList();
      // Строим индекс: drug_name (lower) -> [interactions]
      for (final inter in _allInteractions) {
        final d1 = inter.drug1.toLowerCase();
        final d2 = inter.drug2.toLowerCase();
        _index.putIfAbsent(d1, () => []).add(inter);
        _index.putIfAbsent(d2, () => []).add(inter);
      }
    } catch (e) {
      debugPrint('Interactions load error: $e');
    }
    setState(() {
      _isLoading = false;
    });
  }

  void _checkInteractions() {
    final found = <DrugInteractionExtended>[];
    for (int i = 0; i < _selectedDrugs.length; i++) {
      for (int j = i + 1; j < _selectedDrugs.length; j++) {
        final drug1 = _selectedDrugs[i];
        final drug2 = _selectedDrugs[j];
        // Ищем по name и inn
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
      appBar: AppBar(title: const Text('🧪 Проверка совместимости')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Список выбранных препаратов
                Container(
                  padding: const EdgeInsets.all(AppTheme.paddingMedium),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Выбранные препараты',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          if (_selectedDrugs.isNotEmpty)
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _selectedDrugs.clear();
                                  _foundInteractions.clear();
                                });
                              },
                              icon: const Icon(Icons.clear_all, size: 16),
                              label: const Text('Очистить',
                                  style: TextStyle(fontSize: 12)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_selectedDrugs.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundGray,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          ),
                          child: const Center(
                            child: Text(
                              'Добавьте 2+ препарата для проверки совместимости',
                              style:
                                  TextStyle(color: AppTheme.textTertiary, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _selectedDrugs.asMap().entries.map((entry) {
                            final i = entry.key;
                            final drug = entry.value;
                            return Chip(
                              label: Text('${i + 1}. ${drug.name}',
                                  style: const TextStyle(fontSize: 12)),
                              onDeleted: () {
                                setState(() {
                                  _selectedDrugs.removeAt(i);
                                  _checkInteractions();
                                });
                              },
                              backgroundColor: AppTheme.safeGreen.withOpacity(0.1),
                              side: BorderSide(
                                  color: AppTheme.safeGreen.withOpacity(0.3)),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 8),
                      // Кнопка добавить
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _showAddDrugDialog,
                          icon: const Icon(Icons.add),
                          label: Text(
                            _selectedDrugs.isEmpty
                                ? 'Добавить первый препарат'
                                : 'Добавить ещё препарат',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
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
          const Text('🧪', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            'Добавьте минимум 2 препарата',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'База: ${_allInteractions.length} взаимодействий',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildSafeResult() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('✅', style: TextStyle(fontSize: 72)),
          const SizedBox(height: 16),
          Text(
            'Взаимодействий не найдено',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Проверено ${_selectedDrugs.length} препаратов',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(color: Colors.blue.withOpacity(0.2)),
            ),
            child: const Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 18),
                    SizedBox(width: 8),
                    Text('Внимание',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Отсутствие найденных взаимодействий не означает полную '
                  'безопасность комбинации. Всегда консультируйтесь с '
                  'инструкцией производителя.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionsList() {
    // Сортируем по severity (critical → minor)
    final severityOrder = {'critical': 0, 'major': 1, 'moderate': 2, 'minor': 3};
    final sorted = List<DrugInteractionExtended>.from(_foundInteractions)
      ..sort((a, b) =>
          (severityOrder[a.severity] ?? 4)
              .compareTo(severityOrder[b.severity] ?? 4));

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        return _InteractionCard(interaction: sorted[index]);
      },
    );
  }

  void _showAddDrugDialog() {
    final allDrugs = widget.vetProvider.allDrugs.whereType<CalcDrug>().toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(AppTheme.paddingMedium),
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

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.paddingSmall),
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 4)),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок
            Row(
              children: [
                Icon(interaction.severityIcon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${interaction.drug1} + ${interaction.drug2}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    interaction.severityLabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            // Эффект
            if (interaction.effect.isNotEmpty)
              _InfoRow(label: 'Эффект', value: interaction.effect),
            // Последствия
            if (interaction.consequence.isNotEmpty)
              _InfoRow(label: 'Последствие', value: interaction.consequence),
            // Рекомендация
            if (interaction.recommendation.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.safeGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb,
                        color: AppTheme.safeGreen, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        interaction.recommendation,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.safeGreenDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddDrugSearch extends StatefulWidget {
  final List<CalcDrug> allDrugs;
  final List<CalcDrug> excludeDrugs;
  final Function(CalcDrug) onSelected;

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
    _filtered = widget.allDrugs
        .where((d) => !widget.excludeDrugs.contains(d))
        .toList();
  }

  void _filter(String query) {
    final q = query.toLowerCase();
    setState(() {
      _filtered = widget.allDrugs.where((d) {
        if (widget.excludeDrugs.contains(d)) return false;
        return d.name.toLowerCase().contains(q) ||
            d.inn.toLowerCase().contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Добавить препарат',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Поиск по названию или МНН...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: AppTheme.backgroundGray,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: _filter,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            itemCount: _filtered.length > 100 ? 100 : _filtered.length,
            itemBuilder: (context, index) {
              final drug = _filtered[index];
              final catColor = AppTheme.getCategoryColor(drug.category);
              return ListTile(
                leading: Container(
                  width: 4,
                  height: 32,
                  decoration: BoxDecoration(
                    color: catColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                title: Text(drug.name, style: const TextStyle(fontSize: 14)),
                subtitle: Text(drug.inn,
                    style: const TextStyle(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                onTap: () => widget.onSelected(drug),
              );
            },
          ),
        ),
      ],
    );
  }
}
