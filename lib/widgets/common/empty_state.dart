// EmptyState — единый плейсхолдер «пусто» (Фаза 1, v1.17.0).
//
// ЗАЧЕМ: у каждого экрана свой self-made «пустой» экран с эмодзи-Text и
// Colors.grey[600] (в тёмной теме — серый на чёрном, читается плохо).
// EmptyState даёт: иконку/эмодзи в тонированном круге, заголовок, подсказку
// и опциональную кнопку действия — все цвета theme-aware.
//
// Демо-встраивание v1.17.0: favorites_screen (⭐), history_screen (🕒) —
// заодно исправляет слепнущий в тёмной теме Colors.grey[600].
import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class EmptyState extends StatelessWidget {
  /// Материальная иконка (приоритет, если задана и icon, и emoji).
  final IconData? icon;
  final String? emoji;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    this.icon,
    this.emoji,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final Color circleFill =
        AppTheme.isDarkNow ? AppTheme.darkSurfaceLight : AppTheme.primaryContainer;
    final Color circleFg =
        AppTheme.isDarkNow ? AppTheme.darkPrimary : AppTheme.accentText;

    return Center(
      child: SingleChildScrollView(
        // На маленьких экранах с клавиатурой контент не должен обрезаться
        padding: const EdgeInsets.all(AppTheme.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null)
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: circleFill,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 44, color: circleFg),
              )
            else if (emoji != null)
              Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: circleFill,
                  shape: BoxShape.circle,
                ),
                child: Text(emoji!, style: const TextStyle(fontSize: 44)),
              ),
            const SizedBox(height: AppTheme.paddingMedium),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTheme.fontSizeSubtitle,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTheme.fontSizeBody,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppTheme.paddingLarge),
              // FilledButton из темы Фазы 0: высота ≥48dp, контраст по WCAG
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.arrow_forward, size: 20),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
