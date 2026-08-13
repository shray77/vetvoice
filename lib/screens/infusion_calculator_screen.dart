// InfusionCalculatorScreen — калькулятор скорости инфузии.
//
// Рассчитывает:
//   - Скорость введения (мл/ч) по дозе (мкг/кг/мин) и весу
//   - Количество капель в минуту
//   - Длительность инфузии (по объёму раствора)
//   - Объём препарата для добавления в растворитель
//
// Формулы:
//   скорость_мл_ч = (доза_мкг_кг_мин × вес_кг × 60) / концентрация_мг_мл
//   капли_мин = скорость_мл_ч / 60 × drops_per_ml (обычно 20)
//   длительность_ч = объём_мл / скорость_мл_ч
//
// Зависимости:
//   - fluid_therapy.json (опционально, для пресетов растворов)

import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class InfusionCalculatorScreen extends StatefulWidget {
  const InfusionCalculatorScreen({super.key});

  @override
  State<InfusionCalculatorScreen> createState() =>
      _InfusionCalculatorScreenState();
}

class _InfusionCalculatorScreenState extends State<InfusionCalculatorScreen> {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _doseController = TextEditingController();
  final TextEditingController _concentrationController = TextEditingController();
  final TextEditingController _volumeController = TextEditingController();

  String _doseUnit = 'мкг/кг/мин';
  String _concentrationUnit = 'мг/мл';
  int _dropsPerMl = 20; // стандарт для макро-капель
  double _result = 0;
  double _dropsPerMin = 0;
  double _durationHours = 0;

  final List<String> _doseUnits = [
    'мкг/кг/мин',
    'мг/кг/мин',
    'мг/кг/ч',
    'мл/кг/ч',
    'МЕ/кг/ч',
  ];

  final List<String> _concentrationUnits = ['мг/мл', 'мкг/мл', 'МЕ/мл', '%'];
  final List<int> _dropOptions = [10, 15, 20, 60];

  void _calculate() {
    final weight = double.tryParse(_weightController.text.replaceAll(',', '.'));
    final dose = double.tryParse(_doseController.text.replaceAll(',', '.'));
    final conc = double.tryParse(_concentrationController.text.replaceAll(',', '.'));
    final volume = double.tryParse(_volumeController.text.replaceAll(',', '.'));

    if (weight == null || dose == null || conc == null || conc == 0) {
      setState(() {
        _result = 0;
        _dropsPerMin = 0;
        _durationHours = 0;
      });
      return;
    }

    // Конвертируем дозу в мкг/кг/мин
    double doseMcgKgMin = dose;
    switch (_doseUnit) {
      case 'мг/кг/мин':
        doseMcgKgMin = dose * 1000;
        break;
      case 'мг/кг/ч':
        doseMcgKgMin = dose * 1000 / 60;
        break;
      case 'мл/кг/ч':
        // Для мл/кг/ч концентрация не нужна — считаем напрямую
        final mlPerHour = dose * weight;
        setState(() {
          _result = mlPerHour;
          _dropsPerMin = mlPerHour / 60 * _dropsPerMl;
          _durationHours = (volume != null && mlPerHour > 0)
              ? volume / mlPerHour
              : 0;
        });
        return;
      case 'МЕ/кг/ч':
        // Для МЕ/кг/ч нужна концентрация в МЕ/мл
        if (_concentrationUnit != 'МЕ/мл') {
          setState(() {
            _result = 0;
          });
          return;
        }
        final mePerHour = dose * weight;
        final mlPerHour = mePerHour / conc;
        setState(() {
          _result = mlPerHour;
          _dropsPerMin = mlPerHour / 60 * _dropsPerMl;
          _durationHours = (volume != null && mlPerHour > 0)
              ? volume / mlPerHour
              : 0;
        });
        return;
    }

    // Конвертируем концентрацию в мкг/мл
    double concMcgMl = conc;
    switch (_concentrationUnit) {
      case 'мг/мл':
        concMcgMl = conc * 1000;
        break;
      case 'мкг/мл':
        concMcgMl = conc;
        break;
      case '%':
        // 1% = 10 мг/мл = 10000 мкг/мл
        concMcgMl = conc * 10000;
        break;
    }

    // Скорость инфузии: мл/час
    // = (доза_мкг_кг_мин × вес_кг × 60 мин) / концентрация_мкг_мл
    final mlPerHour = (doseMcgKgMin * weight * 60) / concMcgMl;

    setState(() {
      _result = mlPerHour;
      _dropsPerMin = mlPerHour / 60 * _dropsPerMl;
      _durationHours = (volume != null && mlPerHour > 0)
          ? volume / mlPerHour
          : 0;
    });
  }

  @override
  void dispose() {
    _weightController.dispose();
    _doseController.dispose();
    _concentrationController.dispose();
    _volumeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('💧 Калькулятор инфузии')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInputField(
              controller: _weightController,
              label: 'Вес животного (кг)',
              hint: 'например, 20',
              icon: '⚖️',
              onChanged: (_) => _calculate(),
            ),
            const SizedBox(height: 12),
            // Доза
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildInputField(
                    controller: _doseController,
                    label: 'Доза',
                    hint: 'например, 5',
                    icon: '💊',
                    onChanged: (_) => _calculate(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _doseUnit,
                    decoration: const InputDecoration(
                      labelText: 'Единица',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: _doseUnits
                        .map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 12))))
                        .toList(),
                    onChanged: (v) {
                      setState(() => _doseUnit = v!);
                      _calculate();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Концентрация
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildInputField(
                    controller: _concentrationController,
                    label: 'Концентрация',
                    hint: 'например, 4',
                    icon: '🧪',
                    onChanged: (_) => _calculate(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _concentrationUnit,
                    decoration: const InputDecoration(
                      labelText: 'Единица',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: _concentrationUnits
                        .map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 12))))
                        .toList(),
                    onChanged: (v) {
                      setState(() => _concentrationUnit = v!);
                      _calculate();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Объём раствора (опционально)
            _buildInputField(
              controller: _volumeController,
              label: 'Объём раствора (мл) — опционально',
              hint: 'например, 500',
              icon: '💧',
              onChanged: (_) => _calculate(),
            ),
            const SizedBox(height: 12),
            // Drops per ml
            Row(
              children: [
                const Text('🔢 Капель/мл:'),
                const SizedBox(width: 8),
                ..._dropOptions.map((d) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ChoiceChip(
                      label: Text('$d'),
                      selected: _dropsPerMl == d,
                      onSelected: (_) {
                        setState(() {
                          _dropsPerMl = d;
                          _calculate();
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 24),
            // Результат
            if (_result > 0) _buildResults(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String icon,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 8),
          child: Text(icon, style: const TextStyle(fontSize: 20)),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 40),
        filled: true,
        fillColor: AppTheme.backgroundGray,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: onChanged,
    );
  }

  Widget _buildResults() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.safeGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(color: AppTheme.safeGreen.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              const Text('⚡ Скорость инфузии', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
              const SizedBox(height: 4),
              Text(
                '${_result.toStringAsFixed(1)} мл/ч',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.safeGreen,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ResultChip(
                    icon: '💧',
                    label: 'Капель/мин',
                    value: _dropsPerMin.toStringAsFixed(0),
                  ),
                  if (_durationHours > 0)
                    _ResultChip(
                      icon: '⏱',
                      label: 'Длительность',
                      value: _durationHours < 1
                          ? '${(_durationHours * 60).toStringAsFixed(0)} мин'
                          : '${_durationHours.toStringAsFixed(1)} ч',
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Стандартные капельницы: 20 кап/мл (макро), 60 кап/мл (микро). '
                  'Проверьте калибровку системы.',
                  style: TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResultChip extends StatelessWidget {
  final String icon;
  final String label;
  final String value;

  const _ResultChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}
