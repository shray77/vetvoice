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
        _buildGenderButton(Gender.male, 'Самец', '♂'),
        const SizedBox(width: 12),
        _buildGenderButton(Gender.female, 'Самка', '♀'),
      ],
    );
  }

  Widget _buildGenderButton(Gender gender, String label, String icon) {
    final isSelected = selectedGender == gender;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => onGenderChanged(gender),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected 
                ? (gender == Gender.male ? AppTheme.maleBlue : AppTheme.femalePink)
                : AppTheme.backgroundFor(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
              color: isSelected 
                  ? (gender == Gender.male ? AppTheme.maleBlue : AppTheme.femalePink)
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Text(
                icon,
                style: TextStyle(
                  fontSize: 28,
                  color: isSelected ? AppTheme.white : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppTheme.white : AppTheme.textPrimary,
                ),
              ),
            ],
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
        Text(
          pregnancyTerm,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PregnancyPeriod.values.map((period) {
            return _buildPeriodChip(period);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPeriodChip(PregnancyPeriod period) {
    final isSelected = selectedPeriod == period;
    final isWarning = period == PregnancyPeriod.late || period == PregnancyPeriod.mid;
    
    return GestureDetector(
      onTap: () => onPeriodChanged(period),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? (isWarning ? AppTheme.warningOrange : AppTheme.safeGreen)
              : AppTheme.backgroundFor(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border.all(
            color: isSelected 
                ? (isWarning ? AppTheme.warningOrange : AppTheme.safeGreen)
                : Colors.transparent,
          ),
        ),
        child: Text(
          period.displayName,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? AppTheme.white : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// Виджет для выбора возраста - УДОБНЫЙ!
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок с категорией
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Возраст',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _getCategoryColor().withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                border: Border.all(color: _getCategoryColor().withOpacity(0.3)),
              ),
              child: Text(
                currentCategory.displayName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _getCategoryColor(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Кнопки категорий возраста
        Row(
          children: [
            _buildCategoryButton(AgeCategory.young, '👶 Молодой', AppTheme.safeGreen),
            const SizedBox(width: 8),
            _buildCategoryButton(AgeCategory.adult, '🐕 Взрослый', AppTheme.maleBlue),
            const SizedBox(width: 8),
            _buildCategoryButton(AgeCategory.old, '🦳 Пожилой', AppTheme.warningOrange),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Ввод точного возраста с кнопками +/-
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.backgroundFor(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Кнопка минус
              _buildStepButton(Icons.remove, () {
                final newValue = (ageMonths - 1).clamp(1, 240);
                onAgeChanged(newValue);
              }),
              
              const SizedBox(width: 12),
              
              // Текущий возраст
              Container(
                constraints: const BoxConstraints(minWidth: 100),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  border: Border.all(color: AppTheme.dividerGray),
                ),
                child: Text(
                  _formatAge(ageMonths),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Кнопка плюс
              _buildStepButton(Icons.add, () {
                final newValue = (ageMonths + 1).clamp(1, 240);
                onAgeChanged(newValue);
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryButton(AgeCategory category, String label, Color color) {
    final isSelected = currentCategory == category;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          // Устанавливаем примерный возраст для категории
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
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            border: Border.all(
              color: isSelected ? color : color.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppTheme.white : color,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildStepButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.backgroundGray,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border.all(color: AppTheme.dividerGray),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 24, color: AppTheme.textPrimary),
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.dividerGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Пол (скрыт для пчёл, рыбы и т.д.)
          if (showGender) ...[
            const Text(
              'Пол животного',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            GenderSelector(
              selectedGender: gender,
              onGenderChanged: onGenderChanged,
            ),

            // Беременность (только для самок)
            if (gender == Gender.female) ...[
              const SizedBox(height: 20),
              PregnancySelector(
                selectedPeriod: pregnancyPeriod,
                onPeriodChanged: onPregnancyChanged,
                pregnancyTerm: pregnancyTerm,
              ),
            ],
            const SizedBox(height: 20),
          ],

          // Возраст
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
