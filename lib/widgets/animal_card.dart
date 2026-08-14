import 'package:flutter/material.dart';
import '../models/drug.dart';
import '../utils/app_theme.dart';

/// Карточка выбора животного
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.safeGreen.withOpacity(0.1) : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(
            color: isSelected ? AppTheme.safeGreen : AppTheme.backgroundFor(context),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? AppTheme.greenGlow : AppTheme.softShadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Эмодзи животного
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.safeGreen.withOpacity(0.15)
                    : AppTheme.backgroundFor(context),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Center(
                child: Text(
                  _getAnimalEmoji(animal.id),
                  style: TextStyle(
                    fontSize: 30,
                    height: 1.0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Название
            Text(
              animal.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppTheme.safeGreen : AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Возвращает эмодзи для животного по id
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
