import 'package:flutter/material.dart';
import '../models/drug.dart';
import '../utils/app_theme.dart';

/// Виджет для выбора пола животного
class GenderSelector extends StatelessWidget {
  final Gender selectedGender;
  final ValueChanged<Gender> onGenderChanged;

  const GenderSelector({
    super.key,
    required this.selectedGender,
    required this.onGenderChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildGenderButton(context, Gender.male, 'Самец', '♂', AppTheme.maleBlue),
        const SizedBox(width: 12),
        _buildGenderButton(context, Gender.female, 'Самка', '♀', AppTheme.femalePink),
      ],
    );
  }

  Widget _buildGenderButton(
    BuildContext context,
    Gender gender,
    String label,
    String icon,
    Color activeColor,
  ) {
    final isSelected = selectedGender == gender;
    final isDark = AppTheme.isDark(context);

    final bg = isSelected
        ? (isDark ? activeColor.withOpacity(0.2) : activeColor.withOpacity(0.12))
        : (isDark ? AppTheme.darkSurfaceLight : AppTheme.surfaceLight);

    final border = isSelected
        ? activeColor
        : AppTheme.borderColor(context);

    final textCol = isSelected
        ? activeColor
        : AppTheme.textPrimaryColor(context);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onGenderChanged(gender),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(
                color: border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  icon,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: textCol,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: textCol,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Виджет для выбора периода беременности
class PregnancySelector extends StatelessWidget {
  final PregnancyPeriod selectedPeriod;
  final ValueChanged<PregnancyPeriod> onPeriodChanged;
  final String pregnancyTerm;

  const PregnancySelector({
    super.key,
    required this.selectedPeriod,
    required this.onPeriodChanged,
    this.pregnancyTerm = 'Беременность',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.child_care_rounded, size: 16, color: AppTheme.textSecondaryColor(context)),
            const SizedBox(width: 6),
            Text(
              pregnancyTerm,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondaryColor(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PregnancyPeriod.values.map((period) {
            return _buildPeriodChip(context, period);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPeriodChip(BuildContext context, PregnancyPeriod period) {
    final isSelected = selectedPeriod == period;
    final isWarning = period == PregnancyPeriod.late || period == PregnancyPeriod.mid;
    final isDark = AppTheme.isDark(context);
    final accent = isWarning ? AppTheme.warningOrange : AppTheme.safeGreen;

    final bg = isSelected
        ? (isDark ? accent.withOpacity(0.2) : accent.withOpacity(0.12))
        : (isDark ? AppTheme.darkSurfaceLight : AppTheme.surfaceLight);

    final border = isSelected ? accent : AppTheme.borderColor(context);
    final textCol = isSelected ? accent : AppTheme.textPrimaryColor(context);

    return InkWell(
      onTap: () => onPeriodChanged(period),
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border.all(
            color: border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          period.displayName,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: textCol,
          ),
        ),
      ),
    );
  }
}

/// Виджет для выбора возраста
class AgeSelector extends StatelessWidget {
  final int ageMonths;
  final ValueChanged<int> onAgeChanged;
  final AgeCategory currentCategory;

  const AgeSelector({
    super.key,
    required this.ageMonths,
    required this.onAgeChanged,
    required this.currentCategory,
  });

  @override
  Widget build(BuildContext context) {
    final catColor = _getCategoryColor();
    final isDark = AppTheme.isDark(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок с категорией
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Возраст пациента',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondaryColor(context),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: catColor.withOpacity(isDark ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                border: Border.all(color: catColor.withOpacity(0.3)),
              ),
              child: Text(
                currentCategory.displayName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: catColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Кнопки категорий возраста
        Row(
          children: [
            _buildCategoryButton(context, AgeCategory.young, '👶 Молодой', AppTheme.safeGreen),
            const SizedBox(width: 8),
            _buildCategoryButton(context, AgeCategory.adult, '🐕 Взрослый', AppTheme.maleBlue),
            const SizedBox(width: 8),
            _buildCategoryButton(context, AgeCategory.old, '🦳 Пожилой', AppTheme.warningOrange),
          ],
        ),

        const SizedBox(height: 10),

        // Ввод точного возраста с кнопками +/-
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurfaceLight : AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStepButton(context, Icons.remove, () {
                final newValue = (ageMonths - 1).clamp(1, 240);
                onAgeChanged(newValue);
              }),
              const SizedBox(width: 12),
              Container(
                constraints: const BoxConstraints(minWidth: 120),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor(context),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  border: Border.all(color: AppTheme.borderColor(context)),
                ),
                child: Text(
                  _formatAge(ageMonths),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 12),
              _buildStepButton(context, Icons.add, () {
                final newValue = (ageMonths + 1).clamp(1, 240);
                onAgeChanged(newValue);
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryButton(
    BuildContext context,
    AgeCategory category,
    String label,
    Color color,
  ) {
    final isSelected = currentCategory == category;
    final isDark = AppTheme.isDark(context);

    final bg = isSelected
        ? (isDark ? color.withOpacity(0.25) : color.withOpacity(0.12))
        : (isDark ? AppTheme.darkSurfaceLight : AppTheme.surfaceLight);

    return Expanded(
      child: InkWell(
        onTap: () {
          int defaultAge;
          switch (category) {
            case AgeCategory.young:
              defaultAge = 6;
              break;
            case AgeCategory.adult:
              defaultAge = 36;
              break;
            case AgeCategory.old:
              defaultAge = 120;
              break;
          }
          onAgeChanged(defaultAge);
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            border: Border.all(
              color: isSelected ? color : AppTheme.borderColor(context),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? color : AppTheme.textSecondaryColor(context),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildStepButton(BuildContext context, IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppTheme.cardColor(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
          child: Icon(icon, size: 20, color: AppTheme.textPrimaryColor(context)),
        ),
      ),
    );
  }

  Color _getCategoryColor() {
    switch (currentCategory) {
      case AgeCategory.young:
        return AppTheme.safeGreen;
      case AgeCategory.adult:
        return AppTheme.maleBlue;
      case AgeCategory.old:
        return AppTheme.warningOrange;
    }
  }

  String _formatAge(int months) {
    if (months < 12) {
      return '$months мес.';
    } else {
      final years = months ~/ 12;
      final remainingMonths = months % 12;
      if (remainingMonths == 0) {
        return '$years г.';
      }
      return '$years г. $remainingMonths мес.';
    }
  }
}

/// Расширенный виджет выбора параметров животного
class AnimalParamsSelector extends StatelessWidget {
  final Gender gender;
  final PregnancyPeriod pregnancyPeriod;
  final int ageMonths;
  final AgeCategory ageCategory;
  final String pregnancyTerm;
  final bool showGender;
  final ValueChanged<Gender> onGenderChanged;
  final ValueChanged<PregnancyPeriod> onPregnancyChanged;
  final ValueChanged<int> onAgeChanged;

  const AnimalParamsSelector({
    super.key,
    required this.gender,
    required this.pregnancyPeriod,
    required this.ageMonths,
    required this.ageCategory,
    required this.pregnancyTerm,
    this.showGender = true,
    required this.onGenderChanged,
    required this.onPregnancyChanged,
    required this.onAgeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          if (showGender) ...[
            Text(
              'Пол пациента',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondaryColor(context),
              ),
            ),
            const SizedBox(height: 10),
            GenderSelector(
              selectedGender: gender,
              onGenderChanged: onGenderChanged,
            ),
            if (gender == Gender.female) ...[
              const SizedBox(height: 16),
              PregnancySelector(
                selectedPeriod: pregnancyPeriod,
                onPeriodChanged: onPregnancyChanged,
                pregnancyTerm: pregnancyTerm,
              ),
            ],
            const SizedBox(height: 16),
            Divider(color: AppTheme.dividerColor(context), height: 1),
            const SizedBox(height: 16),
          ],
          AgeSelector(
            ageMonths: ageMonths,
            onAgeChanged: onAgeChanged,
            currentCategory: ageCategory,
          ),
        ],
      ),
    );
  }
}
