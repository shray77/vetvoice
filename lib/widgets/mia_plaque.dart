// MiaPlaque — stewardship-плашка «разумного использования антимикробных»
// (идея №4 vet-digital-ideas: WHO MIA 2024 поверх базы ветвойс).
//
// Философия экосистемы: «машина напоминает, человек решает». Плашка НЕ
// запрещает и НЕ заменяет клиническое суждение — она показывает класс
// важности препарата по официальной классификации ВОЗ и совет категории.
// Тап — детали: классы, stewardship-советы и атрибуция источника
// (WHO MIA List 2024, CC BY-NC-SA 3.0 IGO).
//
// Стиль: паттерн InteractionWarning (Task 194) — DS-семантика цвета +
// альфа-фон + волосяная рамка, без эмодзи, Material-глифы с тинтом.
import 'package:flutter/material.dart';
import '../models/mia.dart';
import '../theme/ds.dart';

class MiaPlaque extends StatelessWidget {
  final MiaInfo info;

  const MiaPlaque({super.key, required this.info});

  /// Семантика цвета по категории: наивысшая тревога — красная, критическая
  /// важность — оранжевая, информационные — синие, «не применяется у людей» —
  /// зелёная (позитив для стюардшипа: классу человеческая терапия не угрожает).
  Color _fg(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cat = info.worstCategory?.id ?? 'out';
    switch (cat) {
      case 'humans_only':
      case 'hp':
        return isDark ? DsDark.red : DsLight.red;
      case 'cia':
        return isDark ? DsDark.orange : DsLight.orange;
      case 'nmi':
        return isDark ? DsDark.green : DsLight.green;
      default:
        return isDark ? DsDark.blue : DsLight.blue;
    }
  }

  IconData get _icon {
    final cat = info.worstCategory?.id ?? 'out';
    switch (cat) {
      case 'humans_only':
        return Icons.do_not_disturb_on_outlined;
      case 'hp':
        return Icons.health_and_safety;
      case 'cia':
        return Icons.health_and_safety_outlined;
      default:
        return Icons.eco_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = _fg(context);
    final cat = info.worstCategory;

    final title = info.isOutOfScope
        ? 'Вне классификации ВОЗ MIA'
        : 'ВОЗ MIA: ${cat?.label ?? ''}';
    final subtitle = info.isOutOfScope
        ? info.outOfScope.join('; ')
        : info.classNamesLine;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showDetails(context),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: fg.withOpacity(isDark ? 0.12 : 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: fg.withOpacity(isDark ? 0.45 : 0.35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_icon, color: fg, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isDark ? DsDark.text : DsLight.text,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, color: fg, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_icon, color: _fg(ctx), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Разумное использование антимикробных',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Классификация ВОЗ: medically important antimicrobials, издание 2024',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
              ),
              const SizedBox(height: 14),
              if (!info.isOutOfScope && info.worstCategory != null) ...[
                _CategoryBlock(category: info.worstCategory!),
                const SizedBox(height: 14),
              ],
              for (final c in info.classes) ...[
                _ClassBlock(miaClass: c),
                const SizedBox(height: 12),
              ],
              if (info.outOfScope.isNotEmpty)
                for (final reason in info.outOfScope) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline,
                          size: 16,
                          color: Theme.of(ctx).brightness == Brightness.dark
                              ? DsDark.faint
                              : Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          reason,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              const Divider(height: 24),
              Text(
                'Источник: WHO List of Medically Important Antimicrobials — '
                'A risk management tool for mitigating antimicrobial resistance '
                'due to non-human use. Geneva: World Health Organization; 2024 '
                '(ISBN 978-92-4-008461-2). Лицензия CC BY-NC-SA 3.0 IGO. '
                'Классификация — напоминание, не запрет: решение остаётся за '
                'ветеринаром.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(ctx).brightness == Brightness.dark
                          ? DsDark.faint
                          : Colors.grey.shade600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryBlock extends StatelessWidget {
  final MiaCategory category;

  const _CategoryBlock({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? DsDark.blue.withOpacity(0.14)
            : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category.label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(category.hint, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

class _ClassBlock extends StatelessWidget {
  final MiaClass miaClass;

  const _ClassBlock({required this.miaClass});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final faint = isDark ? DsDark.faint : Colors.grey.shade600;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          miaClass.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        Text(
          miaClass.nameEn,
          style: TextStyle(fontSize: 12, color: faint, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 4),
        Text(miaClass.stewardship, style: const TextStyle(fontSize: 13)),
        if (miaClass.note != null) ...[
          const SizedBox(height: 4),
          Text(
            'Примечание: ${miaClass.note}',
            style: TextStyle(fontSize: 12, color: faint),
          ),
        ],
      ],
    );
  }
}
