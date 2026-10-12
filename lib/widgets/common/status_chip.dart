// StatusChip — «таблетка» статуса/серьёзности на токенах палитры (Фаза 1, v1.17.0).
//
// ЗАЧЕМ: по коду размазаны десятки самодельных бейджей («Каренция», «Рецепт»,
// severity-подписи взаимодействий) с хардкодом цветов — часть не знала о тёмной
// теме (белые на белом), часть — дефолтные M3-цвета мимо палитры.
// StatusChip даёт один вариант на все случаи: severity → контейнер/текст/иконка
// из токенов, светлая и тёмная темы из коробки.
//
// Касание: если задан onTap — минимальная высота 48dp (WCAG / полевые условия:
// перчатки, вибрация на весу). Без onTap — компактные 32dp (информационный).
import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

enum StatusSeverity { neutral, info, success, warning, danger }

class StatusChip extends StatelessWidget {
  final String label;
  final StatusSeverity severity;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool compact; // форс-компакт даже с onTap (не рекомендуется)

  const StatusChip({
    super.key,
    required this.label,
    this.severity = StatusSeverity.neutral,
    this.icon,
    this.onTap,
    this.compact = false,
  });

  // Светлая тема: заливка-контейнер + насыщенный текст (из токенов Фазы 0)
  Color get _lightFill {
    switch (severity) {
      case StatusSeverity.info:
        return AppTheme.infoContainer;
      case StatusSeverity.success:
        return AppTheme.successContainer;
      case StatusSeverity.warning:
        return AppTheme.warningContainer;
      case StatusSeverity.danger:
        return AppTheme.errorContainer;
      case StatusSeverity.neutral:
        return AppTheme.fieldFill;
    }
  }

  Color get _lightFg {
    switch (severity) {
      case StatusSeverity.info:
        return AppTheme.info;
      case StatusSeverity.success:
        return AppTheme.success;
      case StatusSeverity.warning:
        return AppTheme.warningOrange;
      case StatusSeverity.danger:
        return AppTheme.errorRed;
      case StatusSeverity.neutral:
        return AppTheme.textSecondary;
    }
  }

  // Тёмная тема: приглушённая заливка + светлые severity-цвета (токены dark*)
  Color get _darkFill {
    switch (severity) {
      case StatusSeverity.danger:
        return AppTheme.darkErrorContainer;
      case StatusSeverity.neutral:
        return AppTheme.darkFieldFill;
      default:
        return AppTheme.darkSurfaceLight;
    }
  }

  Color get _darkFg {
    switch (severity) {
      case StatusSeverity.info:
        return AppTheme.darkInfo;
      case StatusSeverity.success:
        return AppTheme.darkSuccess;
      case StatusSeverity.warning:
        return AppTheme.darkWarning;
      case StatusSeverity.danger:
        return AppTheme.darkError;
      case StatusSeverity.neutral:
        return AppTheme.darkTextSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fill = AppTheme.isDarkNow ? _darkFill : _lightFill;
    final fg = AppTheme.isDarkNow ? _darkFg : _lightFg;
    final interactive = onTap != null && !compact;
    final double hMin = interactive ? 48.0 : 32.0;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: interactive ? 20 : 16, color: fg),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: interactive ? 15 : 13,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ),
      ],
    );

    final BoxDecoration decoration = BoxDecoration(
      color: fill,
      borderRadius: const BorderRadius.all(Radius.circular(AppTheme.radiusPill)),
      border: Border.all(color: fg.withAlpha(80), width: 1),
    );

    final Widget chip = Container(
      constraints: BoxConstraints(minHeight: hMin),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: decoration,
      child: content,
    );

    if (onTap == null) return chip;

    // InkWell поверх — рябь в цвет текста чипа; констрейнт высоты держит
    // touch-target не ниже 48dp у интерактивных чипов.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(AppTheme.radiusPill)),
        splashColor: fg.withAlpha(40),
        child: chip,
      ),
    );
  }
}
