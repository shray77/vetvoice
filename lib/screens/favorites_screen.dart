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
import '../widgets/common/app_scaffold.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/haptics.dart';
import '../widgets/common/skeleton.dart';
// D12: общий хелпер плюрализации (1 препарат / 2 препарата / 5 препаратов)
import 'history_screen.dart';

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

  /// C9 (аудит 26.11.2026): если базы не загрузились, «Избранное пустое» —
  /// ложь (оно неизвестно). Честный error-state с «Повторить» — без
  /// «проверьте сеть» (приложение офлайн, базы в комплекте).
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    // Повторный запуск (кнопка «Повторить») возвращает скелетон.
    if (mounted && !_isLoading) setState(() => _isLoading = true);
    await _favService.init();
    // ⚠ Фикс VV-020 (ревью 26.11.2026): два await без mounted-проверок,
    // затем _loadFavorites() звал setState уже после dispose при быстром
    // возврате с экрана — теперь после каждого await проверяем mounted.
    if (!mounted) return;
    // initialize() — публичный метод провайдера (как в home_screen):
    // грузит calc-базу, реестр и все справочники.
    await _vetProvider.initialize();
    if (!mounted) return;
    _loadFavorites();
  }

  void _loadFavorites() {
    // VV-020: гвард — метод зовут и из async-колбэков (после await).
    if (!mounted) return;
    final allDrugs = _vetProvider.calcDatabase?.drugs ?? [];
    final favIds = _favService.favorites.toSet();
    setState(() {
      _favoriteDrugs = allDrugs.where((d) => favIds.contains(d.id)).toList();
      _isLoading = false;
      // C9: calc-базы нет — это ошибка загрузки, а не «пусто».
      _loadFailed = _vetProvider.calcDatabase == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '⭐ Избранное',
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
                  // D12: 1 препарат / 2 препарата / 5 препаратов.
                  content: Text(
                    'Будет удалено: ${_favoriteDrugs.length} '
                    '${pluralizeRu(_favoriteDrugs.length, 'препарат', 'препарата', 'препаратов')} '
                    'из избранного.',
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
      body: _isLoading
          // Фаза 3: каркас списка вместо спиннера.
          ? const SkeletonList()
          : _loadFailed
              ? _buildLoadError()
              : _favoriteDrugs.isEmpty
                  ? _buildEmptyState()
                  : _buildFavoritesList(),
    );
  }

  /// C9: базы не загрузились — честная ошибка + «Повторить» (тот же путь,
  /// которым экран стартует загрузку: _initData → provider.initialize()).
  Widget _buildLoadError() {
    return EmptyState(
      icon: Icons.cloud_off_outlined,
      title: 'Не удалось загрузить',
      message: 'База препаратов не загрузилась — избранное недоступно.\n'
          'Повторите попытку.',
      actionLabel: 'Повторить',
      onAction: _initData,
    );
  }

  Widget _buildEmptyState() {
    // v1.17.0: общий EmptyState вместо self-made Column — theme-aware
    // (старый Colors.grey[600] слепнул в тёмной теме)
    return const EmptyState(
      icon: Icons.star,
      title: 'Избранное пустое',
      message: 'Нажмите на звёздочку у карточки препарата,\nчтобы добавить его сюда',
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
            // Фаза 3: удаление из избранного — подтверждение хаптиком.
            AppHaptics.confirm();
            await _favService.removeFromFavorites(drug.id);
            _loadFavorites();
          },
          onTap: () {
            // Возвращаемся на главный экран с этим препаратом
            AppHaptics.tap();
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
              Icon(catIcon, size: 24, color: catColor),
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
                          color: AppTheme.textTertiary,
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
