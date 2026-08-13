// FavoritesScreen — экран избранных препаратов.
//
// Показывает список избранных препаратов с возможностью быстро
// перейти к расчёту дозы или убрать из избранного.
//
// Зависимости:
//   - FavoritesService (lib/services/favorites_service.dart)
//   - VetProvider (lib/providers/vet_provider.dart)
//   - AppTheme (lib/utils/app_theme.dart)

import 'package:flutter/material.dart';
import '../models/calc_drug.dart';
import '../providers/vet_provider.dart';
import '../services/favorites_service.dart';
import '../utils/app_theme.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final FavoritesService _favService = FavoritesService();
  final VetProvider _vetProvider = VetProvider();
  List<CalcDrug> _favoriteDrugs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _favService.init();
    // Используем уже загруженную базу (initialize() вызывается в main.dart)
    _loadFavorites();
  }

  void _loadFavorites() {
    final allDrugs = _vetProvider.allDrugs.whereType<CalcDrug>().toList();
    final favIds = _favService.favorites.toSet();
    setState(() {
      _favoriteDrugs = allDrugs.where((d) => favIds.contains(d.id)).toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('⭐ Избранное'),
        actions: [
          if (_favoriteDrugs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Очистить избранное',
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Очистить избранное?'),
                    content: Text(
                      'Будет удалено ${_favoriteDrugs.length} '
                      'препаратов из избранного.',
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
                  await _favService.clear();
                  _loadFavorites();
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favoriteDrugs.isEmpty
              ? _buildEmptyState()
              : _buildFavoritesList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('⭐', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            'Избранное пустое',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Нажмите ⭐ на карточке препарата,\nчтобы добавить его сюда',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      itemCount: _favoriteDrugs.length,
      itemBuilder: (context, index) {
        final drug = _favoriteDrugs[index];
        return _FavoriteDrugCard(
          drug: drug,
          onRemove: () async {
            await _favService.removeFromFavorites(drug.id);
            _loadFavorites();
          },
          onTap: () {
            // Возвращаемся на главный экран с этим препаратом
            Navigator.pop(context, drug);
          },
        );
      },
    );
  }
}

class _FavoriteDrugCard extends StatelessWidget {
  final CalcDrug drug;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const _FavoriteDrugCard({
    required this.drug,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final catColor = AppTheme.getCategoryColor(drug.category);
    final catIcon = AppTheme.getCategoryIcon(drug.category);

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.paddingSmall),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.paddingMedium),
          child: Row(
            children: [
              // Цветовая полоска категории
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: catColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              // Иконка категории
              Text(catIcon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              // Название + МНН
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      drug.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (drug.inn.isNotEmpty)
                      Text(
                        drug.inn,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: catColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        drug.category,
                        style: TextStyle(
                          fontSize: 10,
                          color: catColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Кнопка убрать из избранного
              IconButton(
                icon: const Icon(Icons.star, color: AppTheme.warningOrange),
                onPressed: onRemove,
                tooltip: 'Убрать из избранного',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
