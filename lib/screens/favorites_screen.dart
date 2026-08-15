import 'package:flutter/material.dart';
import '../models/calc_drug.dart';
import '../providers/vet_provider.dart';
import '../services/favorites_service.dart';
import '../utils/app_theme.dart';

/// FavoritesScreen — экран избранных препаратов
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
    await _vetProvider.initialize();
    _loadFavorites();
  }

  void _loadFavorites() {
    final allDrugs = _vetProvider.allDrugs.whereType<CalcDrug>().toList();
    final favIds = _favService.favorites.toSet();
    if (mounted) {
      setState(() {
        _favoriteDrugs = allDrugs.where((d) => favIds.contains(d.id)).toList();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(
        title: const Text('Избранное'),
        actions: [
          if (_favoriteDrugs.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_sweep_rounded, color: AppTheme.textSecondaryColor(context)),
              tooltip: 'Очистить избранное',
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppTheme.cardColor(ctx),
                    title: const Text('Очистить избранное?'),
                    content: Text(
                      'Будет удалено ${_favoriteDrugs.length} препаратов из списка избранного.',
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
                  await _favService.clear();
                  _loadFavorites();
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.safeGreen))
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.warningOrange.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.star_border_rounded, size: 48, color: AppTheme.warningOrange),
          ),
          const SizedBox(height: 16),
          Text(
            'Список избранного пуст',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Нажмите ⭐ на карточке любого препарата,\nчтобы сохранить его для быстрого доступа',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textTertiaryColor(context), height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: _favoriteDrugs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final drug = _favoriteDrugs[index];
        return _FavoriteDrugCard(
          drug: drug,
          onRemove: () async {
            await _favService.removeFromFavorites(drug.id);
            _loadFavorites();
          },
          onTap: () {
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
    final isDark = AppTheme.isDark(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.paddingMedium),
          decoration: BoxDecoration(
            color: AppTheme.cardColor(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(color: AppTheme.borderColor(context)),
            boxShadow: AppTheme.cardShadow(context),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: catColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(catIcon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      drug.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimaryColor(context),
                      ),
                    ),
                    if (drug.inn.isNotEmpty)
                      Text(
                        drug.inn,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor(context),
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: catColor.withOpacity(isDark ? 0.25 : 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        drug.category,
                        style: TextStyle(
                          fontSize: 10,
                          color: catColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.star_rounded, color: AppTheme.warningOrange),
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
