import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/animal.dart';
import '../utils/app_theme.dart';

/// Карточка выбора животного (современный Apple Health Style)
class AnimalCard extends StatelessWidget {
  final Animal animal;
  final bool isSelected;
  final VoidCallback onTap;

  const AnimalCard({
    super.key,
    required this.animal,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final cardBg = isSelected
        ? (isDark
            ? AppTheme.safeGreen.withOpacity(0.18)
            : AppTheme.safeGreenSoft)
        : AppTheme.cardColor(context);

    final borderColor = isSelected
        ? AppTheme.safeGreen
        : AppTheme.borderColor(context);

    final textColor = isSelected
        ? (isDark ? AppTheme.safeGreenLight : AppTheme.safeGreenDark)
        : AppTheme.textPrimaryColor(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: isSelected
                ? AppTheme.greenGlow(0.2)
                : AppTheme.cardShadow(context),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.safeGreen.withOpacity(0.2)
                      : (isDark
                          ? AppTheme.darkSurfaceLight
                          : AppTheme.surfaceLight),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Center(
                  child: Text(
                    _getAnimalEmoji(animal.id),
                    style: const TextStyle(
                      fontSize: 26,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                animal.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: textColor,
                  letterSpacing: -0.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getAnimalEmoji(String id) {
    switch (id) {
      case 'dog':
        return '🐕';
      case 'cat':
        return '🐈';
      case 'cattle':
        return '🐄';
      case 'sheep':
        return '🐑';
      case 'pig':
        return '🐷';
      case 'horse':
        return '🐴';
      case 'poultry':
        return '🐔';
      case 'bees':
        return '🐝';
      case 'fur_animals':
        return '🦊';
      case 'rabbit':
        return '🐰';
      default:
        return '🐾';
    }
  }
}
