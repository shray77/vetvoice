import 'package:flutter/material.dart';
import '../models/calc_drug.dart';
import '../models/drug_interaction.dart';
import '../models/drug_registry.dart';
import '../utils/app_theme.dart';

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

  // ⚠ Фикс VV-023 (ревью 26.11.2026): контроллеры создавались прямо в
  // build() на каждый введённый символ и не освобождались — утечка
  // TextEditingController на каждый кадр ввода. Теперь они персистентные
  // поля State; TextField реагирует на изменения как раньше (onChanged),
  // поле синхронизируется при выборе из подсказок и очистке.
  final TextEditingController _drug1Controller = TextEditingController();
  final TextEditingController _drug2Controller = TextEditingController();

  @override
  void dispose() {
    _drug1Controller.dispose();
    _drug2Controller.dispose();
    super.dispose();
  }

  /// Получить имя и МНН препарата.
  /// ⚠ Фикс VV-025 (ревью 26.11.2026): allDrugs из VetProvider — это
  /// объекты CalcDrug (name/inn) и RegistryDrug (tradeName/inn), а не Map:
  /// имя бралось из toString(), МНН всегда был '' — автодополнение не
  /// находило препараты. Map оставлен как fallback.
  String _getDrugName(dynamic drug) {
    if (drug is CalcDrug) return drug.name;
    if (drug is RegistryDrug) return drug.tradeName;
    if (drug is Map) {
      return drug['name'] as String? ?? drug['trade_name'] as String? ?? '';
    }
    return drug.toString();
  }

  String _getDrugInn(dynamic drug) {
    if (drug is CalcDrug) return drug.inn;
    if (drug is RegistryDrug) return drug.inn;
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
    // C3: весь блок — theme-aware (раньше кроме этого контейнера жили
    // Colors.grey.shade700/50/300 и black87: в тёмной теме — светлый
    // остров с нечитаемым текстом).
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // v1.16: theme-aware — в тёмной теме был белый остров с белым текстом
        color: isDark ? AppTheme.darkSurface : AppTheme.white,
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
                Icon(Icons.compare_arrows, color: AppTheme.safeGreen),
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
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),

          // Препарат 1
          _buildDrugSelector(
            controller: _drug1Controller,
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
              // VV-023: поле держим синхронным с выбором (раньше это
              // делал пересозданный контроллер в build()).
              _drug1Controller.text = name;
            }),
          ),
          const SizedBox(height: 12),

          // Препарат 2
          _buildDrugSelector(
            controller: _drug2Controller,
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
              _drug2Controller.text = name;
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
              // ⚠ Фикс A5 (аудит 26.11.2026): styleFrom применяет
              // backgroundColor ко ВСЕМ состояниям (внутри — All), и
              // disabled-кнопка была неотличима от активной. Теперь —
              // resolveWith: disabled = приглушённые фон/текст.
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.disabled)
                        ? AppTheme.safeGreen.withOpacity(0.35)
                        : AppTheme.safeGreen),
                foregroundColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.disabled)
                        ? Colors.white.withOpacity(0.6)
                        : Colors.white),
                padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(vertical: 12)),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
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
    required TextEditingController controller,
    required String label,
    required String query,
    required String? selectedName,
    required ValueChanged<String> onQueryChanged,
    required void Function(String name, String inn) onSelected,
  }) {
    final results = _searchDrugs(query);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          // VV-023: персистентный контроллер из State — больше не
          // пересоздаётся (и не течёт) на каждый символ.
          controller: controller,
          onChanged: onQueryChanged,
          decoration: InputDecoration(
            hintText: selectedName ?? 'Начните вводить название...',
            hintStyle: TextStyle(
              color: selectedName != null
                  ? AppTheme.textPrimary
                  : AppTheme.textTertiary,
            ),
            prefixIcon: Icon(Icons.medication, size: 20,
                color: AppTheme.textTertiary),
            suffixIcon: selectedName != null
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      controller.clear();
                      onQueryChanged('');
                    },
                  )
                : null,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.dividerGray),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.dividerGray),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:   BorderSide(color: AppTheme.safeGreen, width: 2),
            ),
          ),
        ),
        if (results.isNotEmpty && selectedName == null)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 150),
            decoration: BoxDecoration(
              // C3: theme-aware — в тёмной теме светлый grey.shade50
              // давал белый остров поверх тёмной плашки.
              color: isDark ? AppTheme.darkSurfaceLight : AppTheme.fieldFill,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.dividerGray),
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
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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
    // ⚠ Фикс A2 (аудит 26.11.2026): вердикты — самые важные строки экрана,
    // а красились в raw Colors.red/orange/blue с withOpacity-тонировками
    // (контраст 1.5–3:1). Теперь — единая severity-лестница DS:
    // critical → critical, warning → major, info → minor.
    final brightness = Theme.of(context).brightness;
    final isCritical = interaction.isCritical;
    final isWarning = interaction.isWarning;
    final level = isCritical
        ? SeverityLevel.critical
        : (isWarning ? SeverityLevel.major : SeverityLevel.minor);
    final color = SeverityColors.text(level, brightness);
    final containerBg = SeverityColors.bg(level, brightness);
    final onContainerBg = SeverityColors.onBg(level, brightness);
    // Успешная рекомендация — theme-aware зелёный (в тёмной теме был
    // светлый green.shade50-остров с тёмным текстом).
    final isDark = brightness == Brightness.dark;
    final successFg =
        isDark ? AppTheme.safeGreenLight : AppTheme.accentText;
    final successBg =
        isDark ? AppTheme.darkPrimaryContainer : AppTheme.successContainer;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: containerBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Icon(
                  isCritical ? Icons.dangerous : (isWarning ? Icons.warning_amber : Icons.info_outline),
                  color: color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isCritical
                        ? 'КРИТИЧЕСКОЕ ВЗАИМОДЕЙСТВИЕ'
                        : (isWarning ? '⚠ Взаимодействие обнаружено' : 'Информация'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
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
                    color: containerBg,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: color),
                  ),
                  child: Text(
                    interaction.effect,
                    style: TextStyle(fontSize: 13, color: onContainerBg),
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
                    color: successBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline, size: 16, color: successFg),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          interaction.recommendation,
                          style: TextStyle(fontSize: 12, color: successFg),
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
    // A2: «взаимодействий нет» — theme-aware успех, а не Colors.green
    // (light-токены слепли в тёмной теме).
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppTheme.safeGreenLight : AppTheme.accentText;
    final bg = isDark ? AppTheme.darkPrimaryContainer : AppTheme.successContainer;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Взаимодействий не обнаружено',
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}