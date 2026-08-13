// VaccineCard — UI-виджет для отображения вакцины.
//
// Используется вместо обычной карточки калькулятора, когда
// drug.formType == 'vaccine' && drug.vaccineSpecific != null.
//
// Логика:
//   - НЕ показывает поле ввода веса (вакцины — разовая доза, не мг/кг)
//   - Показывает разовую дозу, путь введения, схему вакцинации
//   - Позволяет рассчитать количество флаконов для N животных
//   - Показывает тип вакцины с цветовой кодировкой
//
// Зависимости: models/vaccine_specific.dart

import 'package:flutter/material.dart';
import '../models/vaccine_specific.dart';

class VaccineCard extends StatefulWidget {
  final String drugName;
  final String drugInn;
  final VaccineSpecific vaccine;
  final String category;

  const VaccineCard({
    super.key,
    required this.drugName,
    required this.drugInn,
    required this.vaccine,
    this.category = 'Иммунобиологические',
  });

  @override
  State<VaccineCard> createState() => _VaccineCardState();
}

class _VaccineCardState extends State<VaccineCard> {
  final TextEditingController _animalsController = TextEditingController(text: '1');
  int? _selectedVialOption;

  @override
  void initState() {
    super.initState();
    if (widget.vaccine.dosesPerVialOptions.isNotEmpty) {
      _selectedVialOption = widget.vaccine.dosesPerVialOptions.last;
    } else if (widget.vaccine.dosesPerVial != null) {
      _selectedVialOption = widget.vaccine.dosesPerVial;
    }
  }

  @override
  void dispose() {
    _animalsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vaccine;
    final vtypeColor = Color(v.vaccineType.colorHex);

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // === Заголовок ===
            Row(
              children: [
                Text(
                  v.vaccineType.icon,
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.drugName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (v.vaccineType.displayName.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: vtypeColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: vtypeColor, width: 1),
                          ),
                          child: Text(
                            v.vaccineType.displayName,
                            style: TextStyle(
                              color: vtypeColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // МНН
            if (widget.drugInn.isNotEmpty)
              Text(
                widget.drugInn,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
              ),

            const Divider(height: 24),

            // === Разовая доза ===
            _InfoRow(
              icon: '💊',
              label: 'Разовая доза',
              value: v.formattedSingleDose,
              valueColor: Colors.blue[700],
            ),

            // Путь введения
            if (v.route.isNotEmpty)
              _InfoRow(
                icon: '📍',
                label: 'Путь введения',
                value: v.route,
              ),

            // Схема вакцинации
            if (v.schedule.isNotEmpty)
              _InfoRow(
                icon: '📅',
                label: 'Схема',
                value: v.schedule,
              ),

            // Для кого
            if (v.animal.isNotEmpty)
              _InfoRow(
                icon: '🐾',
                label: 'Для кого',
                value: v.animal,
              ),

            const Divider(height: 24),

            // === Калькулятор флаконов ===
            if (v.dosesPerVial != null || v.dosesPerVialOptions.isNotEmpty)
              _VialCalculator(
                vaccine: v,
                animalsController: _animalsController,
                selectedVialOption: _selectedVialOption,
                onVialOptionChanged: (option) {
                  setState(() {
                    _selectedVialOption = option;
                  });
                },
              ),

            // Заметки
            if (v.notes.isNotEmpty) ...[
              const Divider(height: 24),
              _InfoRow(
                icon: '📝',
                label: 'Заметки',
                value: v.notes,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VialCalculator extends StatelessWidget {
  final VaccineSpecific vaccine;
  final TextEditingController animalsController;
  final int? selectedVialOption;
  final ValueChanged<int> onVialOptionChanged;

  const _VialCalculator({
    required this.vaccine,
    required this.animalsController,
    required this.selectedVialOption,
    required this.onVialOptionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '📦 Калькулятор флаконов',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8),

        // Количество животных
        Row(
          children: [
            const Text('Животных: '),
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              child: TextField(
                controller: animalsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) {
                  // trigger rebuild
                  (context as Element).markNeedsBuild();
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Выбор фасовки
        if (vaccine.dosesPerVialOptions.length > 1)
          Wrap(
            spacing: 6,
            children: vaccine.dosesPerVialOptions.map((option) {
              final selected = option == selectedVialOption;
              return ChoiceChip(
                label: Text('$option доз'),
                selected: selected,
                onSelected: (_) => onVialOptionChanged(option),
              );
            }).toList(),
          ),

        const SizedBox(height: 12),

        // Результат расчёта
        Builder(builder: (context) {
          final animals = int.tryParse(animalsController.text) ?? 0;
          if (animals <= 0 || selectedVialOption == null) {
            return const SizedBox.shrink();
          }
          final vials = (animals / selectedVialOption!).ceil();
          final volume = vaccine.calculateVolumeForAnimals(animals);

          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '💉 Нужно: $vials флакон(а) по $selectedVialOption доз',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[900],
                  ),
                ),
                if (volume != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Объём: ${volume.toStringAsFixed(volume >= 10 ? 1 : 2)} мл',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
