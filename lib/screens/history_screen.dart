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

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final HistoryService _histService = HistoryService();

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _histService.init();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🕒 История расчётов'),
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
                    content: Text(
                      'Будет удалено ${_histService.history.length} '
                      'записей истории.',
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
                  setState(() {});
                }
              },
            ),
        ],
      ),
      body: _histService.history.isEmpty
          ? _buildEmptyState()
          : _buildHistoryList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🕒', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            'История пустая',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Здесь появятся ваши расчёты\nпосле первого использования',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
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
            setState(() {});
          },
          child: _HistoryEntryCard(entry: entry),
        );
      },
    );
  }
}

class _HistoryEntryCard extends StatelessWidget {
  final HistoryEntry entry;

  const _HistoryEntryCard({required this.entry});

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
              child: const Icon(
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
                      Text(
                        entry.formattedTime,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 12,
                    children: [
                      _Chip(label: '🐾 ${entry.animal}'),
                      _Chip(label: '⚖️ ${entry.weightKg.toStringAsFixed(1)} кг'),
                      if (entry.method.isNotEmpty)
                        _Chip(label: '📍 ${entry.method}'),
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
                        const Icon(
                          Icons.medication,
                          color: AppTheme.safeGreen,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          entry.formattedResult,
                          style: const TextStyle(
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
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
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
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey[700],
        ),
      ),
    );
  }
}
