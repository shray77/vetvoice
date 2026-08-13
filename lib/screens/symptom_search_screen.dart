// SymptomSearchScreen — поиск препаратов по симптомам/показаниям.
//
// Killer feature для диагностики: ветврач вводит «рвота у собаки» —
// получает список препаратов с противорвотным действием.
//
// Логика:
//   - Строит обратный индекс по drug.indications + name + inn + category
//   - При вводе — пересекает множества, сортирует по релевантности
//   - Показывает топ-20 результатов с цветными карточками
//   - Подсказки популярных запросов
//
// Зависимости:
//   - SymptomSearchService (lib/services/symptom_search_service.dart)
//   - AppTheme (lib/utils/app_theme.dart)
//   - CalcDrug (lib/models/calc_drug.dart)

import 'package:flutter/material.dart';
import '../models/calc_drug.dart';
import '../services/symptom_search_service.dart';
import '../utils/app_theme.dart';

class SymptomSearchScreen extends StatefulWidget {
  final void Function(CalcDrug)? onDrugSelected;

  const SymptomSearchScreen({super.key, this.onDrugSelected});

  @override
  State<SymptomSearchScreen> createState() => _SymptomSearchScreenState();
}

class _SymptomSearchScreenState extends State<SymptomSearchScreen> {
  final SymptomSearchService _searchService = SymptomSearchService();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<SearchResult> _results = [];
  bool _isLoading = true;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _initSearch();
  }

  Future<void> _initSearch() async {
    await _searchService.init();
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
      });
      return;
    }
    setState(() {
      _results = _searchService.search(query, limit: 30);
      _hasSearched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔍 Поиск по симптомам'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Поле поиска
                Container(
                  padding: const EdgeInsets.all(AppTheme.paddingMedium),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: true,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Что у пациента? Например: рвота у собаки',
                      hintStyle: const TextStyle(
                          color: AppTheme.textTertiary, fontSize: 14),
                      prefixIcon:
                          const Icon(Icons.search, color: AppTheme.safeGreen),
                      suffixIcon: _controller.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  color: AppTheme.textSecondary),
                              onPressed: () {
                                _controller.clear();
                                _performSearch('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppTheme.backgroundFor(context),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusLarge),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusLarge),
                        borderSide: const BorderSide(
                            color: AppTheme.safeGreen, width: 2),
                      ),
                    ),
                    onSubmitted: _performSearch,
                    onChanged: (value) {
                      // Триггерим rebuild для suffixIcon
                      setState(() {});
                      // Дебаунс 300мс
                      Future.delayed(const Duration(milliseconds: 300), () {
                        if (_controller.text == value) {
                          _performSearch(value);
                        }
                      });
                    },
                  ),
                ),

                // Результаты или подсказки
                Expanded(
                  child: !_hasSearched
                      ? _buildSuggestions()
                      : _results.isEmpty
                          ? _buildNoResults()
                          : _buildResultsList(),
                ),
              ],
            ),
    );
  }

  /// Популярные запросы как подсказки
  Widget _buildSuggestions() {
    final popular = _searchService.popularQueries;
    return ListView(
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      children: [
        const Text(
          '💡 Популярные запросы',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: popular.map((q) {
            return ActionChip(
              label: Text(q),
              onPressed: () {
                _controller.text = q;
                _performSearch(q);
              },
              backgroundColor: AppTheme.safeGreen.withOpacity(0.1),
              side: BorderSide(
                  color: AppTheme.safeGreen.withOpacity(0.3), width: 1),
              labelStyle: const TextStyle(color: AppTheme.safeGreenDark),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(AppTheme.paddingMedium),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
                color: Colors.blue.withOpacity(0.2), width: 1),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Как это работает?',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                '• Поиск идёт по показаниям, МНН, названию и категории\n'
                '• Можно вводить симптомы («рвота»), диагнозы («пиодермия»)\n'
                '• Или действующие вещества («маропитант»)\n'
                '• Результаты отсортированы по релевантности',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🤷', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            'Ничего не найдено',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Попробуйте другие ключевые слова',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.paddingMedium, vertical: 8),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final r = _results[index];
        return _SearchResultCard(
          result: r,
          rank: index + 1,
          onTap: () {
            if (widget.onDrugSelected != null) {
              widget.onDrugSelected!(r.drug);
              Navigator.pop(context);
            }
          },
        );
      },
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  final SearchResult result;
  final int rank;
  final VoidCallback onTap;

  const _SearchResultCard({
    required this.result,
    required this.rank,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final drug = result.drug;
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ранг
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: rank <= 3
                      ? AppTheme.warningOrange.withOpacity(0.2)
                      : AppTheme.backgroundFor(context),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: rank <= 3
                          ? AppTheme.warningOrange
                          : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Цветовая полоска
              Container(
                width: 4,
                constraints: const BoxConstraints(minHeight: 60),
                decoration: BoxDecoration(
                  color: catColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              // Иконка
              Text(catIcon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              // Контент
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            drug.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Score badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.safeGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '★ ${result.score}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.safeGreenDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (drug.inn.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          drug.inn,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const SizedBox(height: 6),
                    // Бейдж категории + совпавшие термины
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: catColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            drug.category,
                            style: TextStyle(
                              fontSize: 9,
                              color: catColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        // Совпавшие термины
                        ...result.matchedTerms.map((t) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                    color: Colors.blue.withOpacity(0.3),
                                    width: 0.5),
                              ),
                              child: Text(
                                t,
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.blue,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            )),
                      ],
                    ),
                    // Доза (если есть)
                    if (drug.dosePerKg > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.medication,
                                size: 14, color: AppTheme.safeGreen),
                            const SizedBox(width: 4),
                            Text(
                              '${drug.dosePerKg} ${drug.doseUnit} '
                              '${drug.method.isNotEmpty ? "· ${drug.method}" : ""}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.safeGreenDark,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
