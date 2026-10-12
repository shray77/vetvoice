// DrugPicker — самодостаточный выбор препарата с поиском (Фаза 1, v1.17.0).
//
// ЗАЧЕМ: сейчас выбор препарата живёт только на home (DrugDropdown + поиск по
// симптомам отдельно). Экранам протоколов/инфузий нужен свой подбор — раньше
// каждый бы собрал свой TextField со своей фильтрацией (и своей нормализацией,
// т.е. с новыми вариантами баги «АСД®-10 не находится»). DrugPicker
// инкапсулирует: нормализацию ®/ё через VetProvider.normalizeForSearch,
// loose-матч «асд10»→«АСД®-10», ранжирование (начало названия > середина),
// минимальную высоту результатов и пульсирующий live-region.
//
// АДДИТИВНО: в v1.17.0 не врезан ни в один экран (Fase 2 подключит к экранам
// протоколов/инфузий). Компилируется и ждёт.
import 'package:flutter/material.dart';
import '../../models/calc_drug.dart';
import '../../providers/vet_provider.dart';
import '../../utils/app_theme.dart';

class DrugPicker extends StatefulWidget {
  /// Явный список (для фильтрованных сценариев). null → все калькуляторные
  /// препараты из VetProvider (calculatorApplicable == true).
  final List<CalcDrug>? drugs;

  final ValueChanged<CalcDrug> onSelected;

  final String? hint;

  /// Максимальная высота списка результатов.
  final double resultsMaxHeight;

  const DrugPicker({
    super.key,
    this.drugs,
    required this.onSelected,
    this.hint,
    this.resultsMaxHeight = 280,
  });

  @override
  State<DrugPicker> createState() => _DrugPickerState();
}

class _DrugPickerState extends State<DrugPicker> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  List<CalcDrug> get _source {
    if (widget.drugs != null) return widget.drugs!;
    final db = VetProvider().calcDatabase;
    if (db == null) return const [];
    // Как и home: шампуни/ошейники в расчётном подборе не показываем
    return db.drugs.where((d) => d.calculatorApplicable).toList();
  }

  /// Только буквы/цифры — тот же «loose-ключ», что в VetProvider._looseKey:
  /// «асд10» находит «АСД®-10» (символ ® разрывает обычную подстроку).
  static String _loose(String s) =>
      VetProvider.normalizeForSearch(s).replaceAll(RegExp(r'[^a-zа-я0-9]'), '');

  /// Ранжированный поиск: (1) начало названия, (2) начало МНН,
  /// (3) вхождение в любом месте названия/МНН, (4) loose-вхождение.
  List<CalcDrug> _filtered(String query) {
    final src = _source;
    final q = VetProvider.normalizeForSearch(query.trim());
    if (q.length < 2) return const [];
    final lq = _loose(query);

    final startsName = <CalcDrug>[];
    final startsInn = <CalcDrug>[];
    final contains = <CalcDrug>[];
    final looseHits = <CalcDrug>[];

    for (final d in src) {
      final n = VetProvider.normalizeForSearch(d.name);
      final i = VetProvider.normalizeForSearch(d.inn);
      if (n.startsWith(q)) {
        startsName.add(d);
      } else if (i.startsWith(q)) {
        startsInn.add(d);
      } else if (n.contains(q) || i.contains(q)) {
        contains.add(d);
      } else if (lq.length >= 3 &&
          (_loose(d.name).contains(lq) || _loose(d.inn).contains(lq))) {
        looseHits.add(d);
      }
    }
    // Сортировка внутри групп — алфавит, чтобы список был предсказуем
    int byName(CalcDrug a, CalcDrug b) => a.name.compareTo(b.name);
    startsName.sort(byName);
    startsInn.sort(byName);
    contains.sort(byName);
    looseHits.sort(byName);
    return [...startsName, ...startsInn, ...contains, ...looseHits];
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered(_controller.text);
    final dbEmpty = _source.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focus,
          // Поле из темы Фазы 0 (fill/бордер/радиус уже брендовые)
          decoration: InputDecoration(
            hintText: widget.hint ?? 'Название или действующее вещество…',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      _controller.clear();
                      _focus.requestFocus();
                      if (mounted) setState(() {});
                    },
                  ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        if (dbEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(
                  'База препаратов ещё загружается…',
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeCaption,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else if (results.isEmpty && _controller.text.trim().length >= 2)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Text(
              'Ничего не найдено. Попробуйте начало названия или МНН.',
              style: TextStyle(
                fontSize: AppTheme.fontSizeCaption,
                color: AppTheme.textTertiary,
              ),
            ),
          )
        else if (results.isNotEmpty)
          Container(
            constraints: BoxConstraints(maxHeight: widget.resultsMaxHeight),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: const BorderRadius.all(
                Radius.circular(AppTheme.radiusMedium),
              ),
              border: Border.all(color: AppTheme.dividerGray),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: results.length,
              itemBuilder: (context, index) {
                final d = results[index];
                final subtitle = d.inn.isEmpty || d.inn == d.name
                    ? d.form
                    : '${d.inn} · ${d.form}';
                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: Text(
                    d.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeSmall,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  minVerticalPadding: 12,
                  onTap: () {
                    widget.onSelected(d);
                    _controller.clear();
                    setState(() {});
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
