import 'package:flutter/material.dart';
import '../models/drug_interaction.dart';
import '../theme/ds.dart';

// Task 194: тёмная тема взаимодействий. Блок жил на светлых Material-островах
// (red/orange/blue/green shade50-100): в графите это светлые пятна
// со светлым текстом и невидимыми shade200-рамками («не хватает границ»).
// Семантика переводится на DS-токены: цвет по серьёзности + альфа-фон,
// в тёмной теме — DsDark.* (тёплые светлые значения на графите).
class InteractionWarning extends StatelessWidget {
  final List<DrugInteraction> interactions;
  final VoidCallback? onDismiss;

  const InteractionWarning({
    super.key,
    required this.interactions,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (interactions.isEmpty) return const SizedBox.shrink();

    final critical = interactions.where((i) => i.isCritical).toList();
    final warnings = interactions.where((i) => i.isWarning).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final redFg = isDark ? DsDark.red : DsLight.red;
    final orangeFg = isDark ? DsDark.orange : DsLight.orange;
    final blueFg = isDark ? DsDark.blue : DsLight.blue;
    final greenFg = isDark ? DsDark.green : DsLight.green;
    final textFg = isDark ? DsDark.text : DsLight.text;

    final hasCritical = critical.isNotEmpty;
    final hasWarnings = warnings.isNotEmpty;
    final fg = hasCritical ? redFg : (hasWarnings ? orangeFg : blueFg);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: fg.withOpacity(isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withOpacity(isDark ? 0.45 : 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: fg.withOpacity(isDark ? 0.18 : 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Icon(
                  hasCritical
                      ? Icons.dangerous
                      : hasWarnings
                          ? Icons.warning_amber
                          : Icons.info_outline,
                  color: fg,
                ),
                const SizedBox(width: 8),
                Text(
                  hasCritical
                      ? 'КРИТИЧЕСКОЕ ВЗАИМОДЕЙСТВИЕ!'
                      : hasWarnings
                          ? '⚠ Взаимодействие препаратов'
                          : 'Информация',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),

          // Список взаимодействий
          ...interactions.map(
            (interaction) => _buildInteractionItem(
              interaction,
              isDark: isDark,
              redFg: redFg,
              orangeFg: orangeFg,
              greenFg: greenFg,
              textFg: textFg,
            ),
          ),

          if (onDismiss != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextButton(
                onPressed: onDismiss,
                child: const Text('Закрыть'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInteractionItem(
    DrugInteraction interaction, {
    required bool isDark,
    required Color redFg,
    required Color orangeFg,
    required Color greenFg,
    required Color textFg,
  }) {
    final effectFg = interaction.isCritical
        ? redFg
        : interaction.isWarning
            ? orangeFg
            : textFg;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Пара препаратов
          Text(
            '${interaction.drug1} + ${interaction.drug2}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: textFg,
            ),
          ),
          const SizedBox(height: 4),

          // Эффект
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: effectFg.withOpacity(isDark ? 0.16 : 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              interaction.effect,
              style: TextStyle(
                fontSize: 13,
                color: effectFg,
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Последствия
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('→ ',
                  style: TextStyle(fontWeight: FontWeight.bold, color: textFg)),
              Expanded(
                child: Text(
                  interaction.consequence,
                  style: TextStyle(fontSize: 13, color: textFg),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Рекомендация
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: greenFg.withOpacity(isDark ? 0.14 : 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: greenFg.withOpacity(isDark ? 0.4 : 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, size: 16, color: greenFg),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    interaction.recommendation,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? DsDark.text : DsLight.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
