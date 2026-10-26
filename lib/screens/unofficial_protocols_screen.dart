import 'package:flutter/material.dart';
import '../models/unofficial_protocol.dart';
import '../utils/app_theme.dart';
import '../widgets/common/app_scaffold.dart';

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

  /// v1.18.1: человекочитаемые типы записей. В базе 8 типов — от официальных
  /// таблиц дозировок до форумных схем; без бейджа пользователь не понимал,
  /// «что для чего» (полевой отчёт v1.18.0).
  static const Map<String, String> _typeLabels = {
    'official_dosage_table': 'Официальные дозировки',
    'vidal_drug_instruction': 'Инструкция (Vidal)',
    'dosage_reference': 'Справочник доз',
    'wsava_essential_medicine': 'WSAVA — базовые препараты',
    'forum_protocol': 'Опыт с форума',
    'india_treatment_guideline': 'Гайдлайн (Индия)',
    'forum_dosage': 'Доза с форума',
    'forum_treatment_protocol': 'Схема с форума',
  };

  /// Нормализация поиска: регистр + ё→е (класс багов «асд-10 не находится»).
  static String _norm(String s) => s.toLowerCase().replaceAll('ё', 'е');

  @override
  void initState() {
    super.initState();
    _filterAnimal = widget.selectedAnimal;
  }

  List<UnofficialRecord> get _filtered {
    var list = widget.db.records;
    if (_searchQuery.isNotEmpty) {
      final q = _norm(_searchQuery);
      list = list.where((p) {
        // v1.18.1: расширенный поиск — «по темам». Помимо МНН/названий/
        // описания ищем в: форме выпуска, предупреждениях, видах животных,
        // примечаниях и путях введения дозировок (именно там лежат темы
        // вроде «прерывание беременности» у записей-схем).
        if (_norm(p.drugNameInn).contains(q)) return true;
        if (p.tradeNames.any((t) => _norm(t).contains(q))) return true;
        if (_norm(p.description).contains(q)) return true;
        if (_norm(p.form).contains(q)) return true;
        if (_norm(p.warnings).contains(q)) return true;
        if (p.animalDosages.any((d) =>
            _norm(d.animal).contains(q) ||
            _norm(d.notes).contains(q) ||
            _norm(d.route).contains(q))) {
          return true;
        }
        return false;
      }).toList();
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
    return AppScaffold(
      title: 'Неофициальные протоколы',
      actions: [
        Text('$_resultCount', style: TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
        const SizedBox(width: 8),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.paddingMedium),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Поиск: препарат, тема («пиометра»), вид…',
                prefixIcon: Icon(Icons.search, color: AppTheme.textTertiary),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          // v1.18.1: объяснялка базы — пользователь не понимал, что это
          // и зачем («где-то написано что и зачем, а где-то просто название»).
          Container(
            margin: const EdgeInsets.fromLTRB(
              AppTheme.paddingMedium, 0, AppTheme.paddingMedium, 8,
            ),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.maleBlue.withOpacity(0.07),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              border: Border.all(color: AppTheme.maleBlue.withOpacity(0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppTheme.maleBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Опыт практикующих врачей и справочники — не официальная '
                    'инструкция. Записи бывают по препарату (МНН в заголовке) '
                    'и по проблеме, например «прерывание беременности». '
                    'Тип записи — бейджем под заголовком.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
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
                    style: TextStyle(color: AppTheme.textTertiary, fontSize: 14)))
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
    final typeLabel = _typeLabels[p.recordType] ?? p.recordType;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.white, borderRadius: BorderRadius.circular(AppTheme.radiusMedium), boxShadow: AppTheme.softShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.drugNameInn, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          // v1.18.1: тип записи (откуда данные) — отвечает на вопрос
          // «что это: официальный справочник или форумный опыт».
          if (typeLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.maleBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  typeLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.maleBlue,
                  ),
                ),
              ),
            ),
          if (p.tradeNames.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(p.tradeNames.take(3).join(', '), style: const TextStyle(fontSize: 12, color: AppTheme.maleBlue)),
            ),
          if (p.form.isNotEmpty) Text(p.form, style: TextStyle(fontSize: 12, color: AppTheme.textTertiary)),
          if (p.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(p.description.length > 150 ? '${p.description.substring(0, 150)}...' : p.description,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4)),
          ] else if (p.animalDosages.isNotEmpty) ...[
            // v1.18.1: записи-схемы без описания — не молчим, а объясняем,
            // что у карточки есть содержимое ниже (полевой отчёт v1.18.0:
            // «а где-то просто название препарата»).
            const SizedBox(height: 6),
            // БЕЗ const: textTertiary — theme-aware геттер (упало в Release
            // APK #45: Constant evaluation error).
            Text(
              'Описание не указано — применяйте по дозировкам ниже',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: AppTheme.textTertiary,
              ),
            ),
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
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
                ],
              ),
            )),
            if (p.animalDosages.length > 3)
              Text('+ ещё ${p.animalDosages.length - 3} дозировок', style: TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
          ],
          if (p.warnings.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('⚠ ${p.warnings}', style: const TextStyle(fontSize: 12, color: AppTheme.warningOrange)),
            ),
        ],
      ),
    );
  }
}
