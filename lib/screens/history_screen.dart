// HistoryScreen — экран истории расчётов.
//
// Показывает последние 50 расчётов доз с датой, названием препарата,
// животным, весом и результатом. Поддерживает очистку истории
// и удаление отдельных записей.
//
// Зависимости:
//   - HistoryService (lib/services/history_service.dart)

import 'package:flutter/material.dart';
import '../services/history_service.dart';
import '../utils/app_theme.dart';
import '../widgets/common/app_scaffold.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/skeleton.dart';

/// D12 (ревью 26.11.2026): честная русская плюрализация — раньше диалог
/// очистки говорил «Будет удалено 1 записей».
///
/// Правило: n%10 == 1 && n%100 != 11 → одна форма; n%10 ∈ 2..4 и
/// n%100 ∉ 12..14 → «мало»; иначе — «много».
String pluralizeRu(int n, String one, String few, String many) {
  final abs = n.abs();
  final mod10 = abs % 10;
  final mod100 = abs % 100;
  if (mod10 == 1 && mod100 != 11) return one;
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
  return many;
}

/// «1 запись / 2 записи / 5 записей» (для диалога очистки истории).
String historyRecordsPlural(int n) =>
    pluralizeRu(n, 'запись', 'записи', 'записей');

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final HistoryService _histService = HistoryService();

  // ⚠ Фикс B8 (аудит 26.11.2026): до завершения init() история пуста —
  // экран мигал «История пустая» до первой загрузки. Теперь до init —
  // честный скелетон списка.
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _histService.init();
    // ⚠ Фикс VV-021 (ревью 26.11.2026): setState после await без
    // mounted — крашился при быстром «назад» с экрана.
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'История расчётов',
      actions: [
        if (_histService.history.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Очистить историю',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Очистить историю?'),
                  // D12: 1 запись / 2 записи / 5 записей.
                  content: Text(
                    'Будет удалено: ${_histService.history.length} '
                    '${historyRecordsPlural(_histService.history.length)} истории.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Отмена'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Очистить'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await _histService.clear();
                if (mounted) setState(() {});
              }
            },
          ),
      ],
      body: _isLoading
          ? const SkeletonList()
          : _histService.history.isEmpty
              ? _buildEmptyState()
              : _buildHistoryList(),
    );
  }

  Widget _buildEmptyState() {
    // v1.17.0: общий EmptyState вместо self-made Column — theme-aware
    // (старый Colors.grey[600] слепнул в тёмной теме)
    return const EmptyState(
      icon: Icons.history,
      title: 'История пустая',
      message: 'Здесь появятся ваши расчёты\nпосле первого использования',
    );
  }

  Widget _buildHistoryList() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      itemCount: _histService.history.length,
      itemBuilder: (context, index) {
        final entry = _histService.history[index];
        return Dismissible(
          key: ValueKey('${entry.timestamp}_${entry.drugId}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            color: AppTheme.errorRed,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) async {
            await _histService.removeAt(index);
            if (mounted) setState(() {});
          },
          child: _HistoryEntryCard(
            entry: entry,
            onDismiss: () async {
              // C20: удаление — не только свайпом (явная кнопка с тултипом).
              await _histService.removeAt(index);
              if (mounted) setState(() {});
            },
          ),
        );
      },
    );
  }
}

class _HistoryEntryCard extends StatelessWidget {
  final HistoryEntry entry;
  final VoidCallback? onDismiss;

  const _HistoryEntryCard({required this.entry, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.paddingSmall),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        child: Row(
          children: [
            // Иконка-часы
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.safeGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child:   Icon(
                Icons.access_time,
                color: AppTheme.safeGreen,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            // Основная информация
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.drugName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // B8: Colors.grey[500] на белой карточке = 2.68:1 —
                      // заменён на theme-aware токен второстепенного текста.
                      Text(
                        entry.formattedTime,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 12,
                    children: [
                      _Chip(label: entry.animal),
                      _Chip(label: '${entry.weightKg.toStringAsFixed(1)} кг'),
                      if (entry.method.isNotEmpty)
                        _Chip(label: entry.method),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Результат — выделено
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.safeGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.safeGreen.withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                          Icon(
                          Icons.medication,
                          color: AppTheme.safeGreen,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          entry.formattedResult,
                          style:   TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.safeGreen,
                          ),
                        ),
                        if (entry.frequency.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            '· ${entry.frequency}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // C20: явная кнопка удаления (свайп остаётся).
            if (onDismiss != null)
              IconButton(
                icon: Icon(Icons.delete_outline,
                    color: AppTheme.errorRed),
                tooltip: 'Удалить',
                onPressed: onDismiss,
              ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;

  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        // B8: raw Colors.grey[200]/[700] — светлый чип в тёмной теме;
        // теперь theme-aware токены.
        color: AppTheme.fieldFill,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}
