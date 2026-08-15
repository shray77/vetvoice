import 'package:flutter/material.dart';
import '../models/drug_interaction.dart';
import '../utils/app_theme.dart';

/// Экран/диалог для интерактивной проверки совместимости двух препаратов
class CompatibilityChecker extends StatefulWidget {
  final InteractionDatabase interactionDb;
  final List<dynamic> allDrugs;
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
  final TextEditingController _drug1Controller = TextEditingController();
  final TextEditingController _drug2Controller = TextEditingController();

  String? _selectedDrug1Name;
  String? _selectedDrug2Name;
  String? _selectedDrug1Inn;
  String? _selectedDrug2Inn;

  DrugInteraction? _interactionResult;
  bool _checked = false;

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

    final queries1 = <String>[];
    final queries2 = <String>[];

    if (_selectedDrug1Inn != null && _selectedDrug1Inn!.isNotEmpty) {
      queries1.add(_selectedDrug1Inn!.toLowerCase());
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
      _checked = true;
    });
  }

  @override
  void dispose() {
    _drug1Controller.dispose();
    _drug2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.warningOrange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: const Icon(Icons.compare_arrows_rounded, color: AppTheme.warningOrange, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Совместимость препаратов',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryColor(context),
                    ),
                  ),
                ],
              ),
              if (widget.onClose != null)
                IconButton(
                  onPressed: widget.onClose,
                  icon: Icon(Icons.close, color: AppTheme.textSecondaryColor(context)),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Поле Препарат 1
          _buildDrugSearchField(
            context,
            label: 'Препарат 1',
            controller: _drug1Controller,
            onSelected: (name, inn) {
              setState(() {
                _selectedDrug1Name = name;
                _selectedDrug1Inn = inn;
                _drug1Controller.text = name;
                _checked = false;
              });
            },
          ),

          const SizedBox(height: 12),

          // Поле Препарат 2
          _buildDrugSearchField(
            context,
            label: 'Препарат 2',
            controller: _drug2Controller,
            onSelected: (name, inn) {
              setState(() {
                _selectedDrug2Name = name;
                _selectedDrug2Inn = inn;
                _drug2Controller.text = name;
                _checked = false;
              });
            },
          ),

          const SizedBox(height: 16),

          // Кнопка проверки
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_selectedDrug1Name != null && _selectedDrug2Name != null)
                  ? _checkCompatibility
                  : null,
              icon: const Icon(Icons.search_rounded, size: 20),
              label: const Text('Проверить совместимость'),
            ),
          ),

          if (_checked) ...[
            const SizedBox(height: 18),
            _buildResultView(context, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildDrugSearchField(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    required Function(String name, String inn) onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondaryColor(context),
          ),
        ),
        const SizedBox(height: 6),
        Autocomplete<Map<String, String>>(
          displayStringForOption: (option) => option['name'] ?? '',
          optionsBuilder: (textEditingValue) {
            return _searchDrugs(textEditingValue.text);
          },
          onSelected: (option) {
            onSelected(option['name'] ?? '', option['inn'] ?? '');
          },
          fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
            if (controller.text.isNotEmpty && textController.text.isEmpty) {
              textController.text = controller.text;
            }
            return TextField(
              controller: textController,
              focusNode: focusNode,
              style: TextStyle(fontSize: 14, color: AppTheme.textPrimaryColor(context)),
              decoration: InputDecoration(
                hintText: 'Введите название или МНН...',
                prefixIcon: Icon(Icons.medication_rounded, size: 18, color: AppTheme.textSecondaryColor(context)),
              ),
            );
          },
          optionsViewBuilder: (context, onSelectedOption, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                color: AppTheme.cardColor(context),
                child: Container(
                  width: MediaQuery.of(context).size.width - 64,
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: options.length,
                    separatorBuilder: (_, __) => Divider(color: AppTheme.dividerColor(context), height: 1),
                    itemBuilder: (context, index) {
                      final opt = options.elementAt(index);
                      return ListTile(
                        dense: true,
                        title: Text(
                          opt['name'] ?? '',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryColor(context)),
                        ),
                        subtitle: opt['inn']!.isNotEmpty
                            ? Text(
                                opt['inn']!,
                                style: TextStyle(fontSize: 11, color: AppTheme.textTertiaryColor(context)),
                              )
                            : null,
                        onTap: () => onSelectedOption(opt),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildResultView(BuildContext context, bool isDark) {
    if (_interactionResult == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.safeGreen.withOpacity(isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(color: AppTheme.safeGreen.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.safeGreen, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Взаимодействий не обнаружено',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.safeGreen),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Препараты можно применять параллельно при соблюдении дозировок',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor(context)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final res = _interactionResult!;
    final isCrit = res.isCritical;
    final alertColor = isCrit ? AppTheme.errorRed : AppTheme.warningOrange;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: alertColor.withOpacity(isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: alertColor.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isCrit ? Icons.dangerous_rounded : Icons.warning_amber_rounded, color: alertColor, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isCrit ? 'КРИТИЧЕСКАЯ НЕСОВМЕСТИМОСТЬ' : 'ВНИМАНИЕ ПРИ СОВМЕСТНОМ ПРИЕМЕ',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: alertColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (res.effect.isNotEmpty) ...[
            Text(
              res.effect,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimaryColor(context)),
            ),
            const SizedBox(height: 4),
          ],
          if (res.consequence.isNotEmpty) ...[
            Text(
              'Последствия: ${res.consequence}',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor(context)),
            ),
            const SizedBox(height: 6),
          ],
          if (res.recommendation.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.cardColor(context),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderColor(context)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, size: 16, color: AppTheme.safeGreen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      res.recommendation,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textPrimaryColor(context)),
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