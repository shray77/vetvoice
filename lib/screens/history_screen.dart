import 'package:flutter/material.dart';
import '../services/history_service.dart';
import '../utils/app_theme.dart';

/// HistoryScreen — экран истории расчётов дозировок
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
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(
        title: const Text('История расчётов'),
        actions: [
          if (_histService.history.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_sweep_rounded, color: AppTheme.textSecondaryColor(context)),
              tooltip: 'Очистить историю',
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppTheme.cardColor(ctx),
                    title: const Text('Очистить историю?'),
                    content: Text(
                      'Будет удалено ${_histService.history.length} записей из истории расчётов.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Отмена'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Очистить', style: TextStyle(color: AppTheme.errorRed)),
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.safeGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.history_rounded, size: 48, color: AppTheme.safeGreen),
          ),
          const SizedBox(height: 16),
          Text(
            'История расчётов пуста',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Здесь появятся ваши расчёты доз\nдля быстрого повторного просмотра',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textTertiaryColor(context), height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: _histService.history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = _histService.history[index];
        return Dismissible(
          key: ValueKey('${entry.timestamp}_${entry.drugId}_$index'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: AppTheme.errorRed,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            ),
            child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
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
    final isDark = AppTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderColor(context)),
        boxShadow: AppTheme.cardShadow(context),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.safeGreen.withOpacity(isDark ? 0.25 : 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: AppTheme.safeGreen,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        entry.drugName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryColor(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      entry.formattedTime,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textTertiaryColor(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _buildParamChip(context, '🐾 ${entry.animal}'),
                    _buildParamChip(context, '⚖️ ${entry.weightKg.toStringAsFixed(1)} кг'),
                    if (entry.method.isNotEmpty)
                      _buildParamChip(context, '📍 ${entry.method}'),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.safeGreen.withOpacity(isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.safeGreen.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.medication_rounded,
                        color: AppTheme.safeGreen,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        entry.formattedResult,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.safeGreen,
                        ),
                      ),
                      if (entry.frequency.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          '• ${entry.frequency}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondaryColor(context),
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
    );
  }

  Widget _buildParamChip(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.isDark(context) ? AppTheme.darkSurfaceLight : AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor(context), fontWeight: FontWeight.w500),
      ),
    );
  }
}
