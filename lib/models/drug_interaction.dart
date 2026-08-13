import 'package:flutter/foundation.dart';

/// Взаимодействие двух препаратов
class DrugInteraction {
  final String drug1;
  final String drug2;
  final String severity; // critical, warning, info
  final String effect;
  final String consequence;
  final String recommendation;

  const DrugInteraction({
    required this.drug1,
    required this.drug2,
    required this.severity,
    required this.effect,
    required this.consequence,
    required this.recommendation,
  });

  factory DrugInteraction.fromJson(Map<String, dynamic> json) {
    // ⚠️ Фикс B-13: null-safe парсинг.
    return DrugInteraction(
      drug1: json['drug1'] as String? ?? '',
      drug2: json['drug2'] as String? ?? '',
      severity: json['severity'] as String? ?? 'info',
      effect: json['effect'] as String? ?? '',
      consequence: json['consequence'] as String? ?? '',
      recommendation: json['recommendation'] as String? ?? '',
    );
  }

  bool get isCritical => severity == 'critical';
  bool get isWarning => severity == 'warning';
  bool get isInfo => severity == 'info';
}

/// База взаимодействий
class InteractionDatabase {
  final List<DrugInteraction> interactions;

  const InteractionDatabase({required this.interactions});

  factory InteractionDatabase.fromJson(Map<String, dynamic> json) {
    // ⚠️ Фикс B-13: null-safe + per-item try/catch.
    final list = <DrugInteraction>[];
    final raw = json['interactions'] as List<dynamic>?;
    if (raw != null) {
      for (int i = 0; i < raw.length; i++) {
        try {
          list.add(DrugInteraction.fromJson(raw[i] as Map<String, dynamic>));
        } catch (e) {
          debugPrint('⚠️ Ошибка парсинга взаимодействия #$i: $e');
        }
      }
    }
    return InteractionDatabase(interactions: list);
  }

  /// Проверяет взаимодействие между двумя препаратами
  DrugInteraction? checkInteraction(String drug1, String drug2) {
    final d1 = drug1.toLowerCase();
    final d2 = drug2.toLowerCase();
    
    for (final interaction in interactions) {
      final i1 = interaction.drug1.toLowerCase();
      final i2 = interaction.drug2.toLowerCase();
      
      // Точное или частичное совпадение
      if ((_matches(d1, i1) && _matches(d2, i2)) ||
          (_matches(d1, i2) && _matches(d2, i1))) {
        return interaction;
      }
    }
    return null;
  }

  /// Проверяет все взаимодействия для списка препаратов
  List<DrugInteraction> checkAllInteractions(List<String> drugNames) {
    final results = <DrugInteraction>[];
    
    for (int i = 0; i < drugNames.length; i++) {
      for (int j = i + 1; j < drugNames.length; j++) {
        final interaction = checkInteraction(drugNames[i], drugNames[j]);
        if (interaction != null) {
          results.add(interaction);
        }
      }
    }
    
    return results;
  }

  bool _matches(String drug, String pattern) {
    return drug.contains(pattern) || pattern.contains(drug);
  }
}
