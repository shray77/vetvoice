import 'package:flutter/material.dart';
import '../models/calc_drug.dart';
import '../models/vaccine_specific.dart';
import '../utils/app_theme.dart';

/// VaccineCard — карточка для вакцин и иммунобиологических препаратов
class VaccineCard extends StatefulWidget {
  final CalcDrug? drug;
  final String? drugName;
  final String? drugInn;
  final VaccineSpecific? vaccine;
  final String? category;
  final VoidCallback? onSpeak;

  const VaccineCard({
    super.key,
    this.drug,
    this.drugName,
    this.drugInn,
    this.vaccine,
    this.category,
    this.onSpeak,
  });

  @override
  State<VaccineCard> createState() => _VaccineCardState();
}

class _VaccineCardState extends State<VaccineCard> {
  final TextEditingController _animalsController = TextEditingController(text: '1');
  int? _selectedVialOption;

  VaccineSpecific? get _vaccine => widget.vaccine ?? widget.drug?.vaccineSpecific;
  String get _name => widget.drugName ?? widget.drug?.name ?? 'Вакцина';
  String get _inn => widget.drugInn ?? widget.drug?.inn ?? '';

  @override
  void initState() {
    super.initState();
    final v = _vaccine;
    if (v != null && v.dosesPerVialOptions.isNotEmpty) {
      _selectedVialOption = v.dosesPerVialOptions.first;
    }
  }

  @override
  void dispose() {
    _animalsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = _vaccine;
    if (v == null) return const SizedBox.shrink();

    final isDark = AppTheme.isDark(context);
    final typeColor = Color(v.vaccineType.colorHex);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: typeColor.withOpacity(0.4), width: 1.5),
        boxShadow: AppTheme.cardShadow(context),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок карточки
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(isDark ? 0.25 : 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Center(
                    child: Text(
                      v.vaccineType.icon,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryColor(context),
                        ),
                      ),
                      if (_inn.isNotEmpty)
                        Text(
                          _inn,
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: AppTheme.textSecondaryColor(context),
                          ),
                        ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 6,
                        children: [
                          if (v.vaccineType.displayName.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: typeColor.withOpacity(isDark ? 0.25 : 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                v.vaccineType.displayName,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: typeColor,
                                ),
                              ),
                            ),
                          if (v.animal.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.maleBlue.withOpacity(isDark ? 0.25 : 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                v.animal,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.maleBlue,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (widget.onSpeak != null)
                  IconButton(
                    icon: const Icon(Icons.volume_up_rounded, color: AppTheme.safeGreen),
                    onPressed: widget.onSpeak,
                    tooltip: 'Озвучить',
                  ),
              ],
            ),

            const SizedBox(height: 16),
            Divider(color: AppTheme.dividerColor(context), height: 1),
            const SizedBox(height: 14),

            // Разовая доза
            _buildInfoRow(
              context,
              icon: Icons.vaccines_rounded,
              label: 'Разовая доза',
              value: v.formattedSingleDose,
              valueColor: AppTheme.safeGreen,
              isBold: true,
            ),

            // Путь введения
            if (v.route.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildInfoRow(
                context,
                icon: Icons.navigation_rounded,
                label: 'Путь введения',
                value: v.route,
              ),
            ],

            // Фасовка
            if (v.dosesPerVial != null || v.dosesPerVialOptions.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildInfoRow(
                context,
                icon: Icons.inventory_2_rounded,
                label: 'Фасовка',
                value: v.formattedPackaging,
              ),
            ],

            // Схема вакцинации
            if (v.schedule.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildInfoRow(
                context,
                icon: Icons.event_repeat_rounded,
                label: 'Схема',
                value: v.schedule,
              ),
            ],

            // Особые указания / Заметки
            if (v.notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildInfoRow(
                context,
                icon: Icons.info_outline_rounded,
                label: 'Указания',
                value: v.notes,
              ),
            ],

            // Калькулятор флаконов на поголовье
            if ((v.dosesPerVial != null && v.dosesPerVial! > 0) || v.dosesPerVialOptions.isNotEmpty) ...[
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
                      value: _selectedVialOption ?? v.dosesPerVialOptions.first,
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
    bool isBold = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondaryColor(context)),
        const SizedBox(width: 10),
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
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
    final vialsNeeded = (count / dosesPerVial).ceil();
    final isDark = AppTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.safeGreen.withOpacity(isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.safeGreen.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Потребуется флаконов:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryColor(context)),
          ),
          Text(
            '$vialsNeeded фл. ($count доз)',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppTheme.safeGreen,
            ),
          ),
        ],
      ),
    );
  }
}
