import 'package:flutter/material.dart';
import '../models/calc_drug.dart';
import '../models/drug_registry.dart';
import '../utils/app_theme.dart';

/// Выпадающий список препаратов с поиском, категориями и сортировкой
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
    if (d is CalcDrug) {
      final items = <String>[];
      if (d.inn.isNotEmpty) items.add(d.inn);
      if (d.form.isNotEmpty) items.add(d.form);
      return items.join(' • ');
    }
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

  void _updateFilteredDrugs() {
    final query = _searchController.text.toLowerCase().trim();

    final sortedDrugs = List<dynamic>.from(widget.drugs)
      ..sort((a, b) => _getSortKey(a).compareTo(_getSortKey(b)));

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
    final isDark = AppTheme.isDark(context);

    return Column(
      children: [
        TextField(
          controller: _searchController,
          focusNode: _focusNode,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor(context),
          ),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: TextStyle(color: AppTheme.textTertiaryColor(context), fontSize: 14),
            prefixIcon: Icon(Icons.search, color: AppTheme.textSecondaryColor(context), size: 20),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: AppTheme.textSecondaryColor(context), size: 18),
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
            margin: const EdgeInsets.only(top: 6),
            constraints: const BoxConstraints(maxHeight: 280),
            decoration: BoxDecoration(
              color: AppTheme.cardColor(context),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(color: AppTheme.borderColor(context)),
              boxShadow: AppTheme.cardShadow(context),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _filteredDrugs.length > 80 ? 80 : _filteredDrugs.length,
                separatorBuilder: (_, __) => Divider(
                  color: AppTheme.dividerColor(context),
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                ),
                itemBuilder: (context, index) {
                  final drug = _filteredDrugs[index];
                  final hasCalc = _hasCalc(drug);
                  final isSelected = drug == widget.selectedDrug;
                  final String category = (drug is CalcDrug) ? drug.category : '';
                  final catColor = AppTheme.getCategoryColor(category);
                  final catIcon = AppTheme.getCategoryIcon(category);

                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 4,
                          height: 30,
                          decoration: BoxDecoration(
                            color: catColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(catIcon, style: const TextStyle(fontSize: 18)),
                      ],
                    ),
                    title: Text(
                      _getDrugName(drug),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? AppTheme.safeGreen
                            : AppTheme.textPrimaryColor(context),
                      ),
                    ),
                    subtitle: Row(
                      children: [
                        if (category.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: catColor.withOpacity(isDark ? 0.2 : 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              category.length > 18 ? '${category.substring(0, 16)}…' : category,
                              style: TextStyle(
                                fontSize: 9,
                                color: catColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            _getSubtitle(drug),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textTertiaryColor(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    trailing: hasCalc
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.safeGreen.withOpacity(isDark ? 0.2 : 0.1),
                              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            ),
                            child: const Text(
                              'расчёт',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
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
          ),

        if (_showDropdown && _filteredDrugs.isEmpty && _searchController.text.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.cardColor(context),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(color: AppTheme.borderColor(context)),
            ),
            child: Text(
              'Ничего не найдено по запросу "${_searchController.text}"',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondaryColor(context),
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}
