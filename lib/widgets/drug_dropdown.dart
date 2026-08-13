import 'package:flutter/material.dart';
import '../models/calc_drug.dart';
import '../models/drug_registry.dart';
import '../utils/app_theme.dart';

/// Выпадающий список препаратов с поиском и сортировкой
class DrugDropdown extends StatefulWidget {
  final List<dynamic> drugs;
  final dynamic selectedDrug;
  final Function(dynamic) onDrugSelected;
  final String hintText;

  const DrugDropdown({
    super.key,
    required this.drugs,
    this.selectedDrug,
    required this.onDrugSelected,
    this.hintText = 'Выберите препарат',
  });

  @override
  State<DrugDropdown> createState() => _DrugDropdownState();
}

class _DrugDropdownState extends State<DrugDropdown> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _showDropdown = false;
  List<dynamic> _filteredDrugs = [];

  @override
  void initState() {
    super.initState();
    _searchController.text = _getDrugName(widget.selectedDrug);
    _updateFilteredDrugs();
  }

  @override
  void didUpdateWidget(DrugDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newName = _getDrugName(widget.selectedDrug);
    if (_searchController.text != newName && newName.isNotEmpty) {
      _searchController.text = newName;
    }
    // Обновляем список если drugs изменился
    if (oldWidget.drugs != widget.drugs) {
      _updateFilteredDrugs();
    }
  }

  String _getDrugName(dynamic d) {
    if (d is CalcDrug) return d.name;
    if (d is RegistryDrug) return d.tradeName;
    return '';
  }

  String _getSubtitle(dynamic d) {
    if (d is CalcDrug) return '${d.inn} • ${d.form}';
    if (d is RegistryDrug) {
      final parts = <String>[];
      if (d.inn.isNotEmpty) parts.add(d.inn);
      if (d.form.isNotEmpty) parts.add(d.shortForm);
      return parts.join(' • ');
    }
    return '';
  }
  
  String _getSortKey(dynamic d) {
    if (d is CalcDrug) return d.name.toLowerCase();
    if (d is RegistryDrug) return d.tradeName.toLowerCase();
    return '';
  }

  bool _hasCalc(dynamic d) => d is CalcDrug;

  /// Обновляет отфильтрованный и отсортированный список
  void _updateFilteredDrugs() {
    final query = _searchController.text.toLowerCase().trim();
    
    // Сортируем от А до Я
    final sortedDrugs = List<dynamic>.from(widget.drugs)
      ..sort((a, b) => _getSortKey(a).compareTo(_getSortKey(b)));
    
    // Фильтруем если есть запрос
    if (query.isEmpty) {
      _filteredDrugs = sortedDrugs;
    } else {
      _filteredDrugs = sortedDrugs.where((d) {
        if (d is CalcDrug) {
          return d.name.toLowerCase().contains(query) ||
                 d.inn.toLowerCase().contains(query);
        }
        if (d is RegistryDrug) {
          return d.tradeName.toLowerCase().contains(query) ||
                 d.inn.toLowerCase().contains(query);
        }
        return false;
      }).toList();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          focusNode: _focusNode,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: const TextStyle(color: AppTheme.textTertiary),
            prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: AppTheme.textSecondary),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _showDropdown = false;
                        _updateFilteredDrugs();
                      });
                    },
                  )
                : null,
          ),
          onChanged: (_) {
            setState(() {
              _updateFilteredDrugs();
              _showDropdown = true;
            });
          },
          onTap: () {
            setState(() {
              _updateFilteredDrugs();
              _showDropdown = true;
            });
          },
        ),

        if (_showDropdown && _filteredDrugs.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 300),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(color: AppTheme.dividerGray),
              boxShadow: AppTheme.softShadow,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _filteredDrugs.length > 100 ? 100 : _filteredDrugs.length,
              itemBuilder: (context, index) {
                final drug = _filteredDrugs[index];
                final hasCalc = _hasCalc(drug);
                final isSelected = drug == widget.selectedDrug;
                // 🆕 Цвет категории
                final String category = (drug is CalcDrug) ? drug.category : '';
                final catColor = AppTheme.getCategoryColor(category);
                final catIcon = AppTheme.getCategoryIcon(category);

                return ListTile(
                  dense: true,
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 🆕 Цветовая полоска категории слева
                      Container(
                        width: 4,
                        height: 32,
                        decoration: BoxDecoration(
                          color: catColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 🆕 Иконка категории
                      Text(catIcon, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 4),
                      // Existing: индикатор hasCalc
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: hasCalc ? AppTheme.safeGreen : AppTheme.maleBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  title: Text(
                    _getDrugName(drug),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppTheme.safeGreen : AppTheme.textPrimary,
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      // 🆕 Бейдж категории
                      if (category.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: catColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: catColor.withOpacity(0.4), width: 0.5),
                          ),
                          child: Text(
                            category.length > 20 ? '${category.substring(0, 18)}…' : category,
                            style: TextStyle(
                              fontSize: 9,
                              color: catColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          _getSubtitle(drug),
                          style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  trailing: hasCalc
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.safeGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'расчёт',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.safeGreen,
                            ),
                          ),
                        )
                      : null,
                  onTap: () {
                    widget.onDrugSelected(drug);
                    _searchController.text = _getDrugName(drug);
                    setState(() => _showDropdown = false);
                    _focusNode.unfocus();
                  },
                );
              },
            ),
          ),
          
        // Показываем если ничего не найдено
        if (_showDropdown && _filteredDrugs.isEmpty && _searchController.text.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.backgroundFor(context),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Text(
              'Ничего не найдено по запросу "${_searchController.text}"',
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}
