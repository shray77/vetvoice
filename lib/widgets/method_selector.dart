import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Способ введения препарата
enum AdministrationMethod {
  intramuscular('Внутримышечно', 'в/м', Icons.vaccines),
  subcutaneous('Подкожно', 'п/к', Icons.water_drop),
  intravenous('Внутривенно', 'в/в', Icons.bloodtype),
  oral('Перорально', 'per os', Icons.medication),
  external('Наружно', 'наружно', Icons.healing),
  inhalation('Ингаляционно', 'ингаляц.', Icons.air),
  intrauterine('Внутриматочно', 'в/мат.', Icons.science),
  intramammary('Интрацистернально', 'в/цист.', Icons.water);

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
  
  /// Возвращает метод по названию (для выбора по умолчанию)
  static AdministrationMethod? findInString(String methodString) {
    final methods = parseFromString(methodString);
    return methods.isNotEmpty ? methods.first : null;
  }
}

/// Виджет выбора способа введения препарата
class MethodSelector extends StatelessWidget {
  /// Строка с доступными методами из препарата
  final String availableMethodsString;
  /// Выбранный метод (null = автоматический выбор)
  final AdministrationMethod? selectedMethod;
  /// Колбэк при выборе метода
  final ValueChanged<AdministrationMethod?>? onMethodChanged;
  /// Показать опцию "Автоматический выбор"
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
    // Парсим доступные методы из строки
    final availableMethods = AdministrationMethod.parseFromString(availableMethodsString);
    
    // Если только один метод или нет методов - не показываем селектор
    if (availableMethods.length <= 1 && !showAutoOption) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.backgroundGray,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.dividerGray),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AdministrationMethod?>(
          value: selectedMethod,
          isExpanded: true,
          hint: Row(
            children: [
              Icon(Icons.vaccines_outlined, size: 18, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Text(
                availableMethodsString,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          items: [
            if (showAutoOption)
              const DropdownMenuItem<AdministrationMethod?>(
                value: null,
                child: Row(
                  children: [
                    Icon(Icons.auto_fix_high, size: 18, color: AppTheme.textTertiary),
                    SizedBox(width: 8),
                    Text('Автоматический выбор'),
                  ],
                ),
              ),
            ...availableMethods.map((m) => DropdownMenuItem<AdministrationMethod?>(
                  value: m,
                  child: Row(
                    children: [
                      Icon(m.icon, size: 18, color: AppTheme.textSecondary),
                      const SizedBox(width: 8),
                      Text(m.displayName),
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

/// Компактный виджет для отображения выбранного метода
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.maleBlue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border.all(
            color: AppTheme.maleBlue.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(method.icon, size: 16, color: AppTheme.maleBlue),
            const SizedBox(width: 6),
            Text(
              method.displayName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.maleBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
