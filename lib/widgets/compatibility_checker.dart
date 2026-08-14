import 'package:flutter/material.dart';
import '../models/drug_interaction.dart';

/// Экран/диалог для проверки совместимости двух препаратов
class CompatibilityChecker extends StatefulWidget {
  final InteractionDatabase interactionDb;
  final List<dynamic> allDrugs; // CalcDrug или RegistryDrug
  final VoidCallback? onClose;

  const CompatibilityChecker({
    super.key,
    required this.interactionDb,
    required this.allDrugs,
    this.onClose,
  });

  @override
  State<CompatibilityChecker> createState() => _CompatibilityCheckerState();
}

class _CompatibilityCheckerState extends State<CompatibilityChecker> {
  String _drug1Query = '';
  String _drug2Query = '';
  String? _selectedDrug1Name;
  String? _selectedDrug2Name;
  String? _selectedDrug1Inn;
  String? _selectedDrug2Inn;
  DrugInteraction? _interactionResult;
  bool _searching = false;

  /// Получить имя и МНН препарата
  String _getDrugName(dynamic drug) {
    if (drug is Map) {
      return drug['name'] as String? ?? drug['trade_name'] as String? ?? '';
    }
    return drug.toString();
  }

  String _getDrugInn(dynamic drug) {
    if (drug is Map) {
      return drug['inn'] as String? ?? '';
    }
    return '';
  }

  List<Map<String, String>> _searchDrugs(String query) {
    if (query.isEmpty) return [];
    final q = query.toLowerCase();
    final results = <Map<String, String>>[];
    final seen = <String>{};

    for (final drug in widget.allDrugs) {
      final name = _getDrugName(drug);
      final inn = _getDrugInn(drug);
      if (name.toLowerCase().contains(q) || inn.toLowerCase().contains(q)) {
        if (!seen.contains(name)) {
          seen.add(name);
          results.add({'name': name, 'inn': inn});
        }
      }
      if (results.length >= 20) break;
    }
    return results;
  }

  void _checkCompatibility() {
    if (_selectedDrug1Name == null || _selectedDrug2Name == null) return;

    setState(() => _searching = true);

    // Проверяем по выбранным названиям и МНН
    final queries1 = <String>[];
    final queries2 = <String>[];

    if (_selectedDrug1Inn != null && _selectedDrug1Inn!.isNotEmpty) {
      queries1.add(_selectedDrug1Inn!.toLowerCase());
      // Также добавляем отдельные компоненты из составных МНН
      for (final part in _selectedDrug1Inn!.split(RegExp('[,;]'))) {
        final trimmed = part.trim().toLowerCase();
        if (trimmed.length > 3) queries1.add(trimmed);
      }
    }
    if (_selectedDrug1Name != null) {
      queries1.add(_selectedDrug1Name!.toLowerCase());
    }

    if (_selectedDrug2Inn != null && _selectedDrug2Inn!.isNotEmpty) {
      queries2.add(_selectedDrug2Inn!.toLowerCase());
      for (final part in _selectedDrug2Inn!.split(RegExp('[,;]'))) {
        final trimmed = part.trim().toLowerCase();
        if (trimmed.length > 3) queries2.add(trimmed);
      }
    }
    if (_selectedDrug2Name != null) {
      queries2.add(_selectedDrug2Name!.toLowerCase());
    }

    DrugInteraction? result;
    for (final q1 in queries1) {
      for (final q2 in queries2) {
        result = widget.interactionDb.checkInteraction(q1, q2);
        if (result != null) break;
      }
      if (result != null) break;
    }

    setState(() {
      _interactionResult = result;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок
          Row(
            children: [
              const Icon(Icons.compare_arrows, color: Colors.deepPurple),
              const SizedBox(width: 8),
              const Text(
                'Проверка совместимости',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (widget.onClose != null)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Выберите два препарата для проверки взаимодействий',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),

          // Препарат 1
          _buildDrugSelector(
            label: 'Препарат 1',
            query: _drug1Query,
            selectedName: _selectedDrug1Name,
            onQueryChanged: (v) => setState(() {
              _drug1Query = v;
              if (_selectedDrug1Name != null) {
                _selectedDrug1Name = null;
                _selectedDrug1Inn = null;
                _interactionResult = null;
              }
            }),
            onSelected: (name, inn) => setState(() {
              _selectedDrug1Name = name;
              _selectedDrug1Inn = inn;
              _drug1Query = name;
              _interactionResult = null;
            }),
          ),
          const SizedBox(height: 12),

          // Препарат 2
          _buildDrugSelector(
            label: 'Препарат 2',
            query: _drug2Query,
            selectedName: _selectedDrug2Name,
            onQueryChanged: (v) => setState(() {
              _drug2Query = v;
              if (_selectedDrug2Name != null) {
                _selectedDrug2Name = null;
                _selectedDrug2Inn = null;
                _interactionResult = null;
              }
            }),
            onSelected: (name, inn) => setState(() {
              _selectedDrug2Name = name;
              _selectedDrug2Inn = inn;
              _drug2Query = name;
              _interactionResult = null;
            }),
          ),
          const SizedBox(height: 16),

          // Кнопка проверки
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_selectedDrug1Name != null && _selectedDrug2Name != null && !_searching)
                  ? _checkCompatibility
                  : null,
              icon: _searching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: const Text('Проверить совместимость'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),

          // Результат
          if (_interactionResult != null)
            _buildResult(_interactionResult!)
          else if (_selectedDrug1Name != null &&
              _selectedDrug2Name != null &&
              !_searching &&
              _interactionResult == null)
            _buildNoInteraction(),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildDrugSelector({
    required String label,
    required String query,
    required String? selectedName,
    required ValueChanged<String> onQueryChanged,
    required void Function(String name, String inn) onSelected,
  }) {
    final results = _searchDrugs(query);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: TextEditingController(text: query)..selection = TextSelection.collapsed(offset: query.length),
          onChanged: onQueryChanged,
          decoration: InputDecoration(
            hintText: selectedName ?? 'Начните вводить название...',
            hintStyle: TextStyle(
              color: selectedName != null ? Colors.black87 : Colors.grey.shade400,
            ),
            prefixIcon: Icon(Icons.medication, size: 20, color: Colors.grey.shade500),
            suffixIcon: selectedName != null
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => onQueryChanged(''),
                  )
                : null,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.dividerFor(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.dividerFor(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
            ),
          ),
        ),
        if (results.isNotEmpty && selectedName == null)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 150),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.dividerFor(context)),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: results.length,
              itemBuilder: (context, index) {
                final drug = results[index];
                return InkWell(
                  onTap: () => onSelected(drug['name']!, drug['inn']!),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          drug['name']!,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        if (drug['inn']!.isNotEmpty)
                          Text(
                            drug['inn']!,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildResult(DrugInteraction interaction) {
    final isCritical = interaction.isCritical;
    final isWarning = interaction.isWarning;
    final color = isCritical ? Colors.red : (isWarning ? Colors.orange : Colors.blue);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Icon(
                  isCritical ? Icons.dangerous : (isWarning ? Icons.warning_amber : Icons.info_outline),
                  color: color,
                ),
                const SizedBox(width: 8),
                Text(
                  isCritical
                      ? '🚨 КРИТИЧЕСКОЕ ВЗАИМОДЕЙСТВИЕ'
                      : (isWarning ? '⚠️ Взаимодействие обнаружено' : 'ℹ️ Информация'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${interaction.drug1} + ${interaction.drug2}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    interaction.effect,
                    style: TextStyle(fontSize: 13, color: color.shade900),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('→ ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(interaction.consequence, style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline, size: 16, color: Colors.green.shade700),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          interaction.recommendation,
                          style: TextStyle(fontSize: 12, color: Colors.green.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoInteraction() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green),
          SizedBox(width: 8),
          Text(
            'Взаимодействий не обнаружено',
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}