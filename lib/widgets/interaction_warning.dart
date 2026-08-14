import 'package:flutter/material.dart';
import '../models/drug_interaction.dart';

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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: critical.isNotEmpty 
            ? Colors.red.shade50 
            : warnings.isNotEmpty 
                ? Colors.orange.shade50 
                : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: critical.isNotEmpty 
              ? Colors.red.shade200 
              : warnings.isNotEmpty 
                  ? Colors.orange.shade200 
                  : Colors.blue.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: critical.isNotEmpty 
                  ? Colors.red.shade100 
                  : warnings.isNotEmpty 
                      ? AppTheme.warningOrange.withOpacity(0.15) 
                      : AppTheme.maleBlue.withOpacity(0.15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Icon(
                  critical.isNotEmpty 
                      ? Icons.dangerous 
                      : warnings.isNotEmpty 
                          ? Icons.warning_amber 
                          : Icons.info_outline,
                  color: critical.isNotEmpty 
                      ? Colors.red 
                      : warnings.isNotEmpty 
                          ? Colors.orange 
                          : Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(
                  critical.isNotEmpty 
                      ? '🚨 КРИТИЧЕСКОЕ ВЗАИМОДЕЙСТВИЕ!' 
                      : warnings.isNotEmpty 
                          ? '⚠️ Взаимодействие препаратов' 
                          : 'ℹ️ Информация',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: critical.isNotEmpty 
                        ? Colors.red.shade900 
                        : warnings.isNotEmpty 
                            ? Colors.orange.shade900 
                            : Colors.blue.shade900,
                  ),
                ),
              ],
            ),
          ),
          
          // Список взаимодействий
          ...interactions.map((interaction) => _buildInteractionItem(interaction)),
          
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

  Widget _buildInteractionItem(DrugInteraction interaction) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Пара препаратов
          Text(
            '${interaction.drug1} + ${interaction.drug2}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          
          // Эффект
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: interaction.isCritical 
                  ? Colors.red.shade100 
                  : interaction.isWarning 
                      ? AppTheme.warningOrange.withOpacity(0.15) 
                      : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              interaction.effect,
              style: TextStyle(
                fontSize: 13,
                color: interaction.isCritical 
                    ? Colors.red.shade900 
                    : Colors.grey.shade800,
              ),
            ),
          ),
          const SizedBox(height: 6),
          
          // Последствия
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('→ ', style: TextStyle(fontWeight: FontWeight.bold)),
              Expanded(
                child: Text(
                  interaction.consequence,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          
          // Рекомендация
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, size: 16, color: Colors.green.shade700),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    interaction.recommendation,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade900,
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
