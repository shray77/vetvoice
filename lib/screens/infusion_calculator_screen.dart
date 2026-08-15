import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// InfusionCalculatorScreen — калькулятор скорости инфузии и капель
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
  int _dropsPerMl = 20;
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

    double doseMcgKgMin = dose;
    switch (_doseUnit) {
      case 'мг/кг/мин':
        doseMcgKgMin = dose * 1000;
        break;
      case 'мг/кг/ч':
        doseMcgKgMin = dose * 1000 / 60;
        break;
      case 'мл/кг/ч':
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

    double concMcgMl = conc;
    switch (_concentrationUnit) {
      case 'мг/мл':
        concMcgMl = conc * 1000;
        break;
      case 'мкг/мл':
        concMcgMl = conc;
        break;
      case '%':
        concMcgMl = conc * 10000;
        break;
    }

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
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(title: const Text('Калькулятор инфузий')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
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
                  _buildInputField(
                    controller: _weightController,
                    label: 'Вес пациента (кг)',
                    hint: 'напр. 15',
                    icon: Icons.scale_rounded,
                  ),
                  const SizedBox(height: 12),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildInputField(
                          controller: _doseController,
                          label: 'Доза',
                          hint: 'напр. 5',
                          icon: Icons.medication_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Единица', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondaryColor(context))),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _doseUnit,
                              isDense: true,
                              dropdownColor: AppTheme.cardColor(context),
                              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
                              items: _doseUnits
                                  .map((u) => DropdownMenuItem(value: u, child: Text(u, style: TextStyle(fontSize: 11, color: AppTheme.textPrimaryColor(context)))))
                                  .toList(),
                              onChanged: (v) {
                                setState(() => _doseUnit = v!);
                                _calculate();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildInputField(
                          controller: _concentrationController,
                          label: 'Концентрация',
                          hint: 'напр. 4',
                          icon: Icons.science_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Единица', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondaryColor(context))),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _concentrationUnit,
                              isDense: true,
                              dropdownColor: AppTheme.cardColor(context),
                              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
                              items: _concentrationUnits
                                  .map((u) => DropdownMenuItem(value: u, child: Text(u, style: TextStyle(fontSize: 11, color: AppTheme.textPrimaryColor(context)))))
                                  .toList(),
                              onChanged: (v) {
                                setState(() => _concentrationUnit = v!);
                                _calculate();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _buildInputField(
                    controller: _volumeController,
                    label: 'Объём раствора (мл, опционально)',
                    hint: 'напр. 500',
                    icon: Icons.water_drop_rounded,
                  ),
                  const SizedBox(height: 14),

                  Text(
                    'Капель на 1 мл системы:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondaryColor(context)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _dropOptions.map((d) {
                      final isSel = _dropsPerMl == d;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _dropsPerMl = d;
                            _calculate();
                          });
                        },
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSel
                                ? AppTheme.safeGreen.withOpacity(isDark ? 0.25 : 0.12)
                                : (isDark ? AppTheme.darkSurfaceLight : AppTheme.surfaceLight),
                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            border: Border.all(
                              color: isSel ? AppTheme.safeGreen : AppTheme.borderColor(context),
                            ),
                          ),
                          child: Text(
                            '$d кап/мл',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                              color: isSel ? AppTheme.safeGreen : AppTheme.textPrimaryColor(context),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            if (_result > 0)
              _buildResults(isDark)
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.infoBlue.withOpacity(isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(color: AppTheme.infoBlue.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppTheme.infoBlue, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Заполните вес, дозу и концентрацию для автоматического расчёта скорости инфузии',
                        style: TextStyle(fontSize: 12, color: AppTheme.textPrimaryColor(context)),
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

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
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
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryColor(context)),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 18, color: AppTheme.textSecondaryColor(context)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          onChanged: (_) => _calculate(),
        ),
      ],
    );
  }

  Widget _buildResults(bool isDark) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.safeGreen.withOpacity(0.18) : AppTheme.safeGreenSoft,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(color: AppTheme.safeGreen.withOpacity(0.35)),
            boxShadow: AppTheme.cardShadow(context),
          ),
          child: Column(
            children: [
              Text(
                'СКОРОСТЬ ИНФУЗИИ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: isDark ? AppTheme.safeGreenLight : AppTheme.safeGreenDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${_result.toStringAsFixed(1)} мл/ч',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppTheme.safeGreenLight : AppTheme.safeGreenDark,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildResultPill(
                    icon: Icons.water_drop_rounded,
                    label: 'Капель в минуту',
                    value: _dropsPerMin.toStringAsFixed(0),
                    isDark: isDark,
                  ),
                  if (_durationHours > 0)
                    _buildResultPill(
                      icon: Icons.timer_outlined,
                      label: 'Длительность',
                      value: _durationHours < 1
                          ? '${(_durationHours * 60).toStringAsFixed(0)} мин'
                          : '${_durationHours.toStringAsFixed(1)} ч',
                      isDark: isDark,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultPill({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppTheme.safeGreen),
              const SizedBox(width: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
            ],
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: AppTheme.textTertiaryColor(context)),
          ),
        ],
      ),
    );
  }
}
