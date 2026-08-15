import 'package:flutter/material.dart';
import '../models/calc_drug.dart';
import '../services/symptom_search_service.dart';
import '../utils/app_theme.dart';

/// SymptomSearchScreen — поиск препаратов по симптомам и показаниям
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
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
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
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(
        title: const Text('Поиск по симптомам'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.safeGreen))
          : Column(
              children: [
                // Поле поиска
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: false,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor(context),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Что у пациента? Напр. "рвота у собаки"',
                      prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textSecondaryColor(context)),
                      suffixIcon: _controller.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear_rounded, color: AppTheme.textSecondaryColor(context)),
                              onPressed: () {
                                _controller.clear();
                                _performSearch('');
                              },
                            )
                          : null,
                    ),
                    onSubmitted: _performSearch,
                    onChanged: (value) {
                      setState(() {});
                      Future.delayed(const Duration(milliseconds: 250), () {
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
                      ? _buildSuggestions(context, isDark)
                      : _results.isEmpty
                          ? _buildNoResults(context)
                          : _buildResultsList(context),
                ),
              ],
            ),
    );
  }

  Widget _buildSuggestions(BuildContext context, bool isDark) {
    final popular = _searchService.popularQueries;

    return ListView(
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      children: [
        Text(
          'Частые запросы',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondaryColor(context),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: popular.map((q) {
            return InkWell(
              onTap: () {
                _controller.text = q;
                _performSearch(q);
              },
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor(context),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  border: Border.all(color: AppTheme.borderColor(context)),
                ),
                child: Text(
                  q,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.infoBlue.withOpacity(isDark ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: AppTheme.infoBlue.withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.lightbulb_outline_rounded, color: AppTheme.infoBlue, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Возможности поиска',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.infoBlue),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '• Вводите симптомы («рвота», «диарея», «зуд»)\n'
                '• Заболевания («пиодермия», '
                '«мастит», «отит»)\n'
                '• Действующие вещества и МНН\n'
                '• Результаты ранжируются по релевантности и терапевтической силе',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textPrimaryColor(context),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoResults(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.textTertiaryColor(context).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_off_rounded, size: 40, color: AppTheme.textTertiary),
          ),
          const SizedBox(height: 16),
          Text(
            'Ничего не найдено',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Попробуйте изменить формулировку запроса',
            style: TextStyle(fontSize: 13, color: AppTheme.textTertiaryColor(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
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
    final isDark = AppTheme.isDark(context);
    final catColor = AppTheme.getCategoryColor(drug.category);
    final catIcon = AppTheme.getCategoryIcon(drug.category);

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ранг / Значок категории
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: catColor.withOpacity(isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Center(
                  child: Text(catIcon, style: const TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 12),

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
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimaryColor(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.safeGreen.withOpacity(isDark ? 0.25 : 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '★ ${result.score}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppTheme.safeGreenLight : AppTheme.safeGreenDark,
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
                            color: AppTheme.textSecondaryColor(context),
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                        ...result.matchedTerms.take(3).map((t) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.infoBlue.withOpacity(isDark ? 0.2 : 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                t,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.infoBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )),
                      ],
                    ),
                    if (drug.dosePerKg > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${drug.dosePerKg} ${drug.doseUnit} ${drug.method.isNotEmpty ? "• ${drug.method}" : ""}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.safeGreenLight : AppTheme.safeGreenDark,
                            fontWeight: FontWeight.w700,
                          ),
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
