import 'package:flutter/material.dart';
import '../models/unofficial_protocol.dart';
import '../utils/app_theme.dart';

class UnofficialRecordsScreen extends StatefulWidget {
  final UnofficialProtocolDatabase db;
  final String? selectedAnimal;
  const UnofficialRecordsScreen({super.key, required this.db, this.selectedAnimal});

  @override
  State<UnofficialRecordsScreen> createState() => _UnofficialRecordsScreenState();
}

class _UnofficialRecordsScreenState extends State<UnofficialRecordsScreen> {
  String _searchQuery = '';
  String? _filterAnimal;

  @override
  void initState() {
    super.initState();
    _filterAnimal = widget.selectedAnimal;
  }

  List<UnofficialRecord> get _filtered {
    var list = widget.db.records;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) =>
        p.drugNameInn.toLowerCase().contains(q) ||
        p.tradeNames.any((t) => t.toLowerCase().contains(q)) ||
        p.description.toLowerCase().contains(q)
      ).toList();
    }
    if (_filterAnimal != null && _filterAnimal!.isNotEmpty) {
      list = list.where((p) => p.animalDosages.any((d) => d.animal == _filterAnimal)).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(
        title: const Text('Неофициальные протоколы'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              style: TextStyle(fontSize: 14, color: AppTheme.textPrimaryColor(context), fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Поиск по МНН, названию, описанию...',
                prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textSecondaryColor(context)),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          if (widget.selectedAnimal == null)
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: ['Собаки', 'Кошки', 'КРС', 'МРС', 'Свиньи', 'Птица', 'Лошади'].map((a) {
                  final sel = _filterAnimal == a;
                  final isDark = AppTheme.isDark(context);
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () => setState(() => _filterAnimal = _filterAnimal == a ? null : a),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: sel
                              ? AppTheme.safeGreen.withOpacity(isDark ? 0.25 : 0.12)
                              : AppTheme.cardColor(context),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                          border: Border.all(color: sel ? AppTheme.safeGreen : AppTheme.borderColor(context)),
                        ),
                        child: Text(
                          a,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                            color: sel ? AppTheme.safeGreen : AppTheme.textPrimaryColor(context),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isEmpty ? 'Нет данных' : 'Ничего не найдено',
                      style: TextStyle(color: AppTheme.textTertiaryColor(context), fontSize: 14),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _buildCard(list[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(UnofficialRecord p) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderColor(context)),
        boxShadow: AppTheme.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            p.drugNameInn,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimaryColor(context)),
          ),
          if (p.tradeNames.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(p.tradeNames.take(3).join(', '), style: const TextStyle(fontSize: 12, color: AppTheme.maleBlue, fontWeight: FontWeight.w600)),
            ),
          if (p.form.isNotEmpty)
            Text(p.form, style: TextStyle(fontSize: 11, color: AppTheme.textTertiaryColor(context))),
          if (p.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              p.description.length > 150 ? '${p.description.substring(0, 150)}...' : p.description,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor(context), height: 1.4),
            ),
          ],
          if (p.animalDosages.isNotEmpty) ...[
            const SizedBox(height: 8),
            Divider(color: AppTheme.dividerColor(context), height: 14),
            ...p.animalDosages.take(3).map((d) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: const BoxDecoration(color: AppTheme.safeGreen, shape: BoxShape.circle),
                  ),
                  Text('${d.animal}: ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.textPrimaryColor(context))),
                  Expanded(
                    child: Text(
                      '${d.doseMin > 0 ? d.doseMin : ''}${d.doseMin != d.doseMax ? "-${d.doseMax}" : ""} ${d.unit} ${d.route}',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor(context)),
                    ),
                  ),
                ],
              ),
            )),
          ],
          if (p.warnings.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('⚠️ ${p.warnings}', style: const TextStyle(fontSize: 12, color: AppTheme.warningOrange)),
            ),
        ],
      ),
    );
  }
}
