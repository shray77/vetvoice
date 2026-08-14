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
  int _resultCount = 0;

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
    _resultCount = list.length;
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      backgroundColor: AppTheme.backgroundGray,
      appBar: AppBar(
        title: const Text('Неофициальные протоколы'),
        backgroundColor: AppTheme.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          Text('$_resultCount', style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.paddingMedium),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Поиск по МНН, названию, описанию...',
                prefixIcon: Icon(Icons.search, color: AppTheme.textTertiary),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          if (widget.selectedAnimal == null)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.paddingMedium),
                children: ['Собаки', 'Кошки', 'КРС', 'МРС', 'Свиньи', 'Птица', 'Лошади'].map((a) {
                  final sel = _filterAnimal == a;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(a, style: TextStyle(fontSize: 12, color: sel ? AppTheme.white : AppTheme.textSecondary)),
                      selected: sel,
                      backgroundColor: AppTheme.white,
                      selectedColor: AppTheme.safeGreen,
                      side: BorderSide(color: sel ? AppTheme.safeGreen : AppTheme.dividerGray),
                      onSelected: (_) => setState(() => _filterAnimal = _filterAnimal == a ? null : a),
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: list.isEmpty
                ? Center(child: Text(_searchQuery.isEmpty ? 'Нет данных' : 'Ничего не найдено',
                    style: const TextStyle(color: AppTheme.textTertiary, fontSize: 14)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.paddingMedium),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _buildCard(list[i])),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(UnofficialRecord p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.white, borderRadius: BorderRadius.circular(AppTheme.radiusMedium), boxShadow: AppTheme.softShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.drugNameInn, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          if (p.tradeNames.isNotEmpty)
            Text(p.tradeNames.take(3).join(', '), style: const TextStyle(fontSize: 12, color: AppTheme.maleBlue)),
          if (p.form.isNotEmpty) Text(p.form, style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary)),
          if (p.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(p.description.length > 150 ? '${p.description.substring(0, 150)}...' : p.description,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4)),
          ],
          if (p.animalDosages.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 16),
            ...p.animalDosages.take(3).map((d) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 7, right: 6),
                    decoration: const BoxDecoration(color: AppTheme.safeGreen, shape: BoxShape.circle)),
                  Text('${d.animal}: ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Expanded(child: Text('${d.doseMin > 0 ? d.doseMin : ''}${d.doseMin != d.doseMax ? '-${d.doseMax}' : ''} ${d.unit} ${d.route}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
                ],
              ),
            )),
            if (p.animalDosages.length > 3)
              Text('+ ещё ${p.animalDosages.length - 3} дозировок', style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
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
