import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Способ введения препарата
enum AdministrationMethod {
  intramuscular('Внутримышечно', 'в/м', Icons.vaccines_rounded),
  subcutaneous('Подкожно', 'п/к', Icons.water_drop_rounded),
  intravenous('Внутривенно', 'в/в', Icons.bloodtype_rounded),
  oral('Перорально', 'per os', Icons.medication_rounded),
  external('Наружно', 'наружно', Icons.healing_rounded),
  inhalation('Ингаляционно', 'ингаляц.', Icons.air_rounded),
  intrauterine('Внутриматочно', 'в/мат.', Icons.science_rounded),
  intramammary('Интрацистернально', 'в/цист.', Icons.opacity_rounded);

  final String displayName;
  final String shortName;
  final IconData icon;

  const AdministrationMethod(this.displayName, this.shortName, this.icon);

  /// Парсит строку метода и возвращает список доступных методов
  static List<AdministrationMethod> parseFromString(String methodString) {
    final methods = <AdministrationMethod>[];
    final lower = methodString.toLowerCase();

    if (lower.contains('внутримышечн') || lower.contains('в/м')) {
      methods.add(AdministrationMethod.intramuscular);
    }
    if (lower.contains('подкожн') || lower.contains('п/к')) {
      methods.add(AdministrationMethod.subcutaneous);
    }
    if (lower.contains('внутривенн') || lower.contains('в/в')) {
      methods.add(AdministrationMethod.intravenous);
    }
    if (lower.contains('пероральн') || lower.contains('per os') || lower.contains('внутрь')) {
      methods.add(AdministrationMethod.oral);
    }
    if (lower.contains('наружн')) {
      methods.add(AdministrationMethod.external);
    }
    if (lower.contains('ингаляц')) {
      methods.add(AdministrationMethod.inhalation);
    }
    if (lower.contains('внутриматочн') || lower.contains('в/мат')) {
      methods.add(AdministrationMethod.intrauterine);
    }
    if (lower.contains('интрацистернальн') || lower.contains('в/цист')) {
      methods.add(AdministrationMethod.intramammary);
    }

    return methods;
  }

  /// Возвращает метод по названию
  static AdministrationMethod? findInString(String methodString) {
    final methods = parseFromString(methodString);
    return methods.isNotEmpty ? methods.first : null;
  }
}

/// Виджет выбора способа введения препарата
class MethodSelector extends StatelessWidget {
  final String availableMethodsString;
  final AdministrationMethod? selectedMethod;
  final ValueChanged<AdministrationMethod?>? onMethodChanged;
  final bool showAutoOption;

  const MethodSelector({
    super.key,
    required this.availableMethodsString,
    this.selectedMethod,
    this.onMethodChanged,
    this.showAutoOption = true,
  });

  @override
  Widget build(BuildContext context) {
    final availableMethods = AdministrationMethod.parseFromString(availableMethodsString);

    if (availableMethods.length <= 1 && !showAutoOption) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AdministrationMethod?>(
          value: selectedMethod,
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, color: AppTheme.textSecondaryColor(context)),
          dropdownColor: AppTheme.cardColor(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          hint: Row(
            children: [
              Icon(Icons.vaccines_rounded, size: 18, color: AppTheme.textSecondaryColor(context)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  availableMethodsString.isNotEmpty
                      ? availableMethodsString
                      : 'Автоматический выбор',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          items: [
            if (showAutoOption)
              DropdownMenuItem<AdministrationMethod?>(
                value: null,
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 18, color: AppTheme.safeGreen),
                    const SizedBox(width: 8),
                    Text(
                      'Автоматически: ${availableMethodsString.isNotEmpty ? availableMethodsString : "по инструкции"}',
                      style: TextStyle(color: AppTheme.textPrimaryColor(context), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ...availableMethods.map((m) => DropdownMenuItem<AdministrationMethod?>(
                  value: m,
                  child: Row(
                    children: [
                      Icon(m.icon, size: 18, color: AppTheme.maleBlue),
                      const SizedBox(width: 8),
                      Text(
                        m.displayName,
                        style: TextStyle(color: AppTheme.textPrimaryColor(context), fontSize: 13),
                      ),
                    ],
                  ),
                )),
          ],
          onChanged: onMethodChanged,
        ),
      ),
    );
  }
}

/// Компактный чип для отображения выбранного метода
class MethodChip extends StatelessWidget {
  final AdministrationMethod method;
  final VoidCallback? onTap;

  const MethodChip({
    super.key,
    required this.method,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.maleBlue.withOpacity(isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border.all(
            color: AppTheme.maleBlue.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(method.icon, size: 14, color: AppTheme.maleBlue),
            const SizedBox(width: 6),
            Text(
              method.displayName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.maleBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
