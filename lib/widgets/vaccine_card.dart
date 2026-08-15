import 'package:flutter/material.dart';
import '../models/vaccine_specific.dart';
import '../utils/app_theme.dart';

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
    final isDark = AppTheme.isDark(context);
    final vtypeColor = Color(v.vaccineType.colorHex);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderColor(context)),
        boxShadow: AppTheme.cardShadow(context),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: vtypeColor.withOpacity(isDark ? 0.25 : 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Center(
                    child: Text(
                      v.vaccineType.icon.isNotEmpty ? v.vaccineType.icon : '💉',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.drugName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryColor(context),
                        ),
                      ),
                      if (v.vaccineType.displayName.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: vtypeColor.withOpacity(isDark ? 0.25 : 0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: vtypeColor.withOpacity(0.4), width: 1),
                          ),
                          child: Text(
                            v.vaccineType.displayName,
                            style: TextStyle(
                              color: vtypeColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            if (widget.drugInn.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                widget.drugInn,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryColor(context),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],

            const SizedBox(height: 16),
            Divider(color: AppTheme.dividerColor(context), height: 1),
            const SizedBox(height: 16),

            // Разовая доза
            _buildInfoRow(
              context,
              icon: Icons.medication_rounded,
              label: 'Разовая доза',
              value: v.formattedSingleDose,
              valueColor: AppTheme.maleBlue,
            ),

            // Путь введения
            if (v.route.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildInfoRow(
                context,
                icon: Icons.alt_route_rounded,
                label: 'Путь введения',
                value: v.route,
              ),
            ],

            // Схема
            if (v.schedule.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildInfoRow(
                context,
                icon: Icons.event_repeat_rounded,
                label: 'Схема',
                value: v.schedule,
              ),
            ],

            // Иммунитет
            if (v.immunityDuration.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildInfoRow(
                context,
                icon: Icons.shield_outlined,
                label: 'Иммунитет',
                value: v.immunityDuration,
              ),
            ],

            // Калькулятор флаконов
            if (v.hasDosesPerVial) ...[
              const SizedBox(height: 16),
              Divider(color: AppTheme.dividerColor(context), height: 1),
              const SizedBox(height: 14),
              Text(
                'Расчёт флаконов на поголовье',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _animalsController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(fontSize: 14, color: AppTheme.textPrimaryColor(context)),
                      decoration: const InputDecoration(
                        labelText: 'Количество голов',
                        suffixText: 'гол.',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  if (v.dosesPerVialOptions.length > 1) ...[
                    const SizedBox(width: 10),
                    DropdownButton<int>(
                      value: _selectedVialOption,
                      dropdownColor: AppTheme.cardColor(context),
                      items: v.dosesPerVialOptions
                          .map((opt) => DropdownMenuItem(
                                value: opt,
                                child: Text('$opt доз/фл', style: TextStyle(color: AppTheme.textPrimaryColor(context))),
                              ))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedVialOption = val),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              _buildVialsResult(context, v),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondaryColor(context)),
        const SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondaryColor(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppTheme.textPrimaryColor(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVialsResult(BuildContext context, VaccineSpecific v) {
    final count = int.tryParse(_animalsController.text) ?? 1;
    final dosesPerVial = _selectedVialOption ?? v.dosesPerVial ?? 1;
    final vials = (count / dosesPerVial).ceil();
    final totalDoses = vials * dosesPerVial;
    final leftover = totalDoses - count;
    final isDark = AppTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.safeGreen.withOpacity(isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: AppTheme.safeGreen.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Необходимо флаконов:',
            style: TextStyle(fontSize: 13, color: AppTheme.textPrimaryColor(context)),
          ),
          Text(
            '$vials шт. ${leftover > 0 ? "(остаток $leftover доз)" : ""}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isDark ? AppTheme.safeGreenLight : AppTheme.safeGreenDark,
            ),
          ),
        ],
      ),
    );
  }
}
