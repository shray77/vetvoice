import 'package:flutter/material.dart';
import '../models/drug_interaction.dart';
import '../utils/app_theme.dart';

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

    final isDark = AppTheme.isDark(context);
    final hasCritical = interactions.any((i) => i.isCritical);
    final hasWarning = interactions.any((i) => i.isWarning);

    final alertColor = hasCritical
        ? AppTheme.errorRed
        : (hasWarning ? AppTheme.warningOrange : AppTheme.infoBlue);

    final alertBg = isDark
        ? alertColor.withOpacity(0.12)
        : (hasCritical
            ? AppTheme.errorRedSoft
            : (hasWarning ? AppTheme.warningOrangeSoft : AppTheme.infoBlueSoft));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: alertBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: alertColor.withOpacity(0.35), width: 1.5),
        boxShadow: AppTheme.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок алерта
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: alertColor.withOpacity(isDark ? 0.2 : 0.15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLarge - 1)),
            ),
            child: Row(
              children: [
                Icon(
                  hasCritical
                      ? Icons.dangerous_rounded
                      : (hasWarning ? Icons.warning_amber_rounded : Icons.info_outline_rounded),
                  color: alertColor,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasCritical
                        ? 'КРИТИЧЕСКОЕ ВЗАИМОДЕЙСТВИЕ'
                        : (hasWarning ? 'Внимание: взаимодействие' : 'Совместимость препаратов'),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: alertColor,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (onDismiss != null)
                  GestureDetector(
                    onTap: onDismiss,
                    child: Icon(Icons.close, size: 18, color: alertColor),
                  ),
              ],
            ),
          ),

          // Список взаимодействий
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            itemCount: interactions.length,
            separatorBuilder: (_, __) => Divider(
              color: alertColor.withOpacity(0.2),
              height: 16,
            ),
            itemBuilder: (context, idx) => _buildInteractionItem(context, interactions[idx]),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionItem(BuildContext context, DrugInteraction interaction) {
    final isDark = AppTheme.isDark(context);
    final isCrit = interaction.isCritical;
    final itemColor = isCrit ? AppTheme.errorRed : AppTheme.warningOrange;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Пара препаратов
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: itemColor.withOpacity(isDark ? 0.25 : 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${interaction.drug1} + ${interaction.drug2}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: itemColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Эффект
        if (interaction.effect.isNotEmpty) ...[
          Text(
            interaction.effect,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          const SizedBox(height: 4),
        ],

        // Последствия
        if (interaction.consequence.isNotEmpty) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('↳ ', style: TextStyle(color: itemColor, fontWeight: FontWeight.bold)),
              Expanded(
                child: Text(
                  interaction.consequence,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor(context),
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],

        // Рекомендация
        if (interaction.recommendation.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.safeGreen.withOpacity(isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.safeGreen.withOpacity(0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.tips_and_updates_outlined, size: 14, color: AppTheme.safeGreen),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    interaction.recommendation,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.safeGreenLight : AppTheme.safeGreenDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
