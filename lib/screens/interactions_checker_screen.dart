// InteractionsCheckerScreen — интерактивная проверка совместимости препаратов.
//
// Пользователь добавляет 2-3 препарата, видит все их взаимодействия.
// Использует drug_interactions.json (severity: critical/warning/info
// → severity-лестница DS: warning → major, info → minor, VV-026).
//
// Логика:
//   1. Загружаем drug_interactions.json
//   2. Строим индекс: (drug1, drug2) -> [interaction]
//   3. Пользователь добавляет препараты (по названию или МНН)
//   4. Проверяем все пары выбранных препаратов
//   5. Показываем результаты с цветовой кодировкой по severity
//
// Зависимости:
//   - drug_interactions.json (assets/data/advanced/)
//   - VetProvider для поиска препаратов

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/calc_drug.dart';
import '../models/drug_interaction.dart';
import '../models/mia.dart';
import '../theme/ds.dart';
import '../providers/vet_provider.dart';
import '../utils/app_theme.dart';

class DrugInteractionExtended {
  final String drug1;
  final String drug2;
  final String severity;
  final String effect;
  final String consequence;
  final String recommendation;

  const DrugInteractionExtended({
    required this.drug1,
    required this.drug2,
    required this.severity,
    required this.effect,
    required this.consequence,
    required this.recommendation,
  });

  factory DrugInteractionExtended.fromJson(Map<String, dynamic> json) {
    return DrugInteractionExtended(
      drug1: json['drug1'] as String? ?? '',
      drug2: json['drug2'] as String? ?? '',
      severity: json['severity'] as String? ?? '',
      effect: json['effect'] as String? ?? '',
      consequence: json['consequence'] as String? ?? '',
      recommendation: json['recommendation'] as String? ?? '',
    );
  }

  /// ⚠ Фикс VV-026 (ревью 26.11.2026): drug_interactions.json пишет severity
  /// как critical/warning/info (73 пары: 18/49/6), а геттеры ниже понимали
  /// только critical/major/moderate/minor — 55 из 73 пар показывали сырое
  /// «warning» с серой иконкой help и не сортировались по опасности.
  /// Маппинг: warning → major, info → minor (moderate оставлен для
  /// совместимости; неизвестное значение — наименее опасный уровень).
  SeverityLevel get severityLevel {
    switch (severity) {
      case 'critical':
        return SeverityLevel.critical;
      case 'major':
      case 'warning':
        return SeverityLevel.major;
      case 'moderate':
        return SeverityLevel.moderate;
      case 'minor':
      case 'info':
        return SeverityLevel.minor;
      default:
        return SeverityLevel.minor;
    }
  }

  /// Порядок опасности для сортировки (0 — самый опасный).
  int get severityRank {
    switch (severityLevel) {
      case SeverityLevel.critical:
        return 0;
      case SeverityLevel.major:
        return 1;
      case SeverityLevel.moderate:
        return 2;
      case SeverityLevel.minor:
        return 3;
    }
  }

  /// ⚠ Фикс C1 (аудит 26.11.2026): бейджи — единая severity-лестница DS
  /// (SeverityColors), а не raw Colors.amber/orange с withOpacity
  /// (жёлтый текст давал 1.51:1).
  Color severityColor(Brightness brightness) =>
      SeverityColors.text(severityLevel, brightness);

  String get severityLabel {
    switch (severity) {
      case 'critical':
        return 'Критическое';
      case 'major':
      case 'warning':
        return 'Серьёзное';
      case 'moderate':
        return 'Умеренное';
      case 'minor':
      case 'info':
        return 'Незначительное';
      default:
        return severity;
    }
  }

  IconData get severityIcon {
    switch (severity) {
      case 'critical':
        return Icons.dangerous;
      case 'major':
      case 'warning':
        return Icons.warning;
      case 'moderate':
        return Icons.info;
      case 'minor':
      case 'info':
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }
}

class InteractionsCheckerScreen extends StatefulWidget {
  final VetProvider vetProvider;

  const InteractionsCheckerScreen({super.key, required this.vetProvider});

  @override
  State<InteractionsCheckerScreen> createState() =>
      _InteractionsCheckerScreenState();
}

class _InteractionsCheckerScreenState extends State<InteractionsCheckerScreen> {
  List<DrugInteractionExtended> _allInteractions = [];
  final Map<String, List<DrugInteractionExtended>> _index = {};
  bool _isLoading = true;

  /// ⚠ Фикс B1 (аудит 26.11.2026): раньше ошибка чтения базы молча
  /// оставляла пустой список — на пустом списке рисовался зелёный
  /// «Взаимодействий не найдено», и врач принимал решение «можно вместе»
  /// на несуществующей проверке. Теперь: ошибка загрузки — честный
  /// error-state с «Повторить»; пустой список — только после успешной
  /// загрузки.
  bool _loadFailed = false;
  final List<CalcDrug> _selectedDrugs = [];
  List<DrugInteractionExtended> _foundInteractions = [];

  @override
  void initState() {
    super.initState();
    _loadInteractions();
  }

  Future<void> _loadInteractions() async {
    // Первый вызов идёт из initState (spinner ещё не построен) — setState
    // не нужен; повторный (кнопка «Повторить») переключает экран на spinner.
    if (mounted && !_isLoading) setState(() => _isLoading = true);
    try {
      final jsonString = await rootBundle
          .loadString('assets/data/advanced/drug_interactions.json');
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final list = data['interactions'] as List<dynamic>? ?? [];
      _allInteractions = list
          .map((i) =>
              DrugInteractionExtended.fromJson(i as Map<String, dynamic>))
          .toList();
      // Строим индекс: drug_name (lower) -> [interactions]
      for (final inter in _allInteractions) {
        final d1 = inter.drug1.toLowerCase();
        final d2 = inter.drug2.toLowerCase();
        _index.putIfAbsent(d1, () => []).add(inter);
        _index.putIfAbsent(d2, () => []).add(inter);
      }
      _loadFailed = false;
    } catch (e) {
      debugPrint('Interactions load error: $e');
      _loadFailed = true;
    }
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  void _checkInteractions() {
    final found = <DrugInteractionExtended>[];
    for (int i = 0; i < _selectedDrugs.length; i++) {
      for (int j = i + 1; j < _selectedDrugs.length; j++) {
        final drug1 = _selectedDrugs[i];
        final drug2 = _selectedDrugs[j];
        // Ищем по name и inn
        for (final name1 in [drug1.name, drug1.inn]) {
          for (final name2 in [drug2.name, drug2.inn]) {
            final interactions = _index[name1.toLowerCase()] ?? [];
            for (final inter in interactions) {
              if ((inter.drug1.toLowerCase() == name1.toLowerCase() &&
                      inter.drug2.toLowerCase() == name2.toLowerCase()) ||
                  (inter.drug1.toLowerCase() == name2.toLowerCase() &&
                      inter.drug2.toLowerCase() == name1.toLowerCase())) {
                if (!found.any((f) =>
                    f.drug1 == inter.drug1 && f.drug2 == inter.drug2)) {
                  found.add(inter);
                }
              }
            }
          }
        }
      }
    }
    setState(() {
      _foundInteractions = found;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Проверка совместимости')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadFailed
              ? _buildLoadError()
              : _buildCheckerBody(),
    );
  }

  /// Тело проверки: выбранные препараты + результаты. Отдельный метод —
  /// при ошибке загрузки базы вместо него рисуется error-state (B1).
  Widget _buildCheckerBody() {
    return Column(
      children: [
        // Список выбранных препаратов
        Container(
          padding: const EdgeInsets.all(AppTheme.paddingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Выбранные препараты',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (_selectedDrugs.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedDrugs.clear();
                          _foundInteractions.clear();
                        });
                      },
                      icon: const Icon(Icons.clear_all, size: 16),
                      label: const Text('Очистить',
                          style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_selectedDrugs.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundGray,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Center(
                    child: Text(
                      'Добавьте 2+ препарата для проверки совместимости',
                      // v1.16: textTertiary был почти невидим на светлом фоне
                      style:
                          TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _selectedDrugs.asMap().entries.map((entry) {
                    final i = entry.key;
                    final drug = entry.value;
                    return Chip(
                      label: Text('${i + 1}. ${drug.name}',
                          style: const TextStyle(fontSize: 12)),
                      onDeleted: () {
                        setState(() {
                          _selectedDrugs.removeAt(i);
                          _checkInteractions();
                        });
                      },
                      backgroundColor: AppTheme.safeGreen.withOpacity(0.1),
                      side: BorderSide(
                          color: AppTheme.safeGreen.withOpacity(0.3)),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 8),
              // Кнопка добавить
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showAddDrugDialog,
                  icon: const Icon(Icons.add),
                  label: Text(
                    _selectedDrugs.isEmpty
                        ? 'Добавить первый препарат'
                        : 'Добавить ещё препарат',
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Результаты проверки
        Expanded(
          child: _selectedDrugs.length < 2
              ? _buildHint()
              : _foundInteractions.isEmpty
                  ? _buildSafeResult()
                  : _buildInteractionsList(),
        ),
      ],
    );
  }

  /// B1: честный error-state при незагруженной базе — вместо ложного
  /// зелёного «Взаимодействий не найдено» на пустом списке.
  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 64, color: AppTheme.textTertiary),
            const SizedBox(height: 16),
            Text(
              'База не загрузилась — проверка недоступна',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Не удалось прочитать базу взаимодействий. '
              'База поставляется в комплекте — повторите попытку.',
              style: TextStyle(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadInteractions,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHint() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.science, size: 64, color: AppTheme.textTertiary),
          const SizedBox(height: 16),
          Text(
            'Добавьте минимум 2 препарата',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'База: ${_allInteractions.length} взаимодействий',
            style: TextStyle(color: AppTheme.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildSafeResult() {
    // ⚠ Фикс C2 (аудит 26.11.2026): успех — theme-aware зелёный
    // (safeGreen из светлой палитры на тёмном фоне давал 2.4–2.9:1).
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final green = isDark ? AppTheme.safeGreenLight : AppTheme.success;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 72, color: green),
          const SizedBox(height: 16),
          Text(
            'Взаимодействий не найдено',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Проверено ${_selectedDrugs.length} препаратов',
            style: TextStyle(color: AppTheme.textTertiary),
          ),
          const SizedBox(height: 24),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(color: Colors.blue.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 18),
                    SizedBox(width: 8),
                    Text('Внимание',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Отсутствие найденных взаимодействий не означает полную '
                  'безопасность комбинации. Всегда консультируйтесь с '
                  'инструкцией производителя.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Идея №4: stewardship-напоминание и при «чистом» результате —
          // взаимодействий нет, а классы важности ВОЗ остаются фактом.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: _buildStewardshipSection(),
          ),
        ],
      ),
    );
  }

  /// Идея №4: выбранные препараты с MIA-классами (для stewardship-блока).
  /// Машина напоминает, человек решает: классы важности ВОЗ выводятся
  /// наравне с фармакологическими взаимодействиями.
  List<(CalcDrug, MiaInfo)> get _miaEntries {
    final db = widget.vetProvider.miaDatabase;
    if (db == null) return const [];
    final out = <(CalcDrug, MiaInfo)>[];
    for (final d in _selectedDrugs) {
      final info = db.resolve(d.id);
      if (info != null && info.hasClasses) out.add((d, info));
    }
    return out;
  }

  Color _miaColor(BuildContext context, String categoryId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (categoryId) {
      case 'humans_only':
      case 'hp':
        return isDark ? DsDark.red : DsLight.red;
      case 'cia':
        return isDark ? DsDark.orange : DsLight.orange;
      case 'nmi':
        return isDark ? DsDark.green : DsLight.green;
      default:
        return isDark ? DsDark.blue : DsLight.blue;
    }
  }

  Widget _buildStewardshipSection() {
    final entries = _miaEntries;
    if (entries.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topCount = entries
        .where((e) => (e.$2.worstCategory?.rank ?? 0) >= 4)
        .length;
    final fg = isDark ? DsDark.blue : DsLight.blue;
    final textFg = isDark ? DsDark.text : DsLight.text;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fg.withOpacity(isDark ? 0.10 : 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withOpacity(isDark ? 0.40 : 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.health_and_safety_outlined, color: fg, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Разумное использование антимикробных (ВОЗ MIA 2024)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final (drug, info) in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4, right: 8),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _miaColor(
                          context, info.worstCategory?.id ?? 'hia'),
                    ),
                  ),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: '${drug.name} — ',
                        style: TextStyle(fontSize: 12.5, color: textFg),
                        children: [
                          TextSpan(
                            text: info.classNamesLine,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600),
                          ),
                          TextSpan(
                            text:
                                ' (${info.worstCategory?.short ?? ''})',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? DsDark.faint : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Text(
            topCount > 0
                ? 'В комбинации $topCount препаратов классов, важных для '
                    'медицины человека: обоснование клинически, посев/чувствительность, '
                    'минимально достаточный курс. Напоминание, не запрет.'
                : 'Классы важности ВОЗ — ориентир при выборе: машина напоминает, '
                    'человек решает.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? DsDark.faint : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionsList() {
    // Сортируем по severity (critical → minor).
    // ⚠ Фикс VV-026: сортировка идёт по severityRank модели, который
    // понимает реальные значения базы (warning → major, info → minor):
    // раньше 55 из 73 пар попадали в «неизвестный» хвост списка.
    final sorted = List<DrugInteractionExtended>.from(_foundInteractions)
      ..sort((a, b) => a.severityRank.compareTo(b.severityRank));

    final hasStewardship = _miaEntries.isNotEmpty;
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      itemCount: sorted.length + (hasStewardship ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == sorted.length) return _buildStewardshipSection();
        return _InteractionCard(interaction: sorted[index]);
      },
    );
  }

  void _showAddDrugDialog() {
    // allDrugs у провайдера — List<dynamic> (CalcDrug + RegistryDrug):
    // для проверки совместимостей берём только расчётные препараты.
    final allDrugs = widget.vetProvider.allDrugs.whereType<CalcDrug>().toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        // ⚠ Фикс B3 (аудит 26.11.2026): высота считалась в контексте
        // РОДИТЕЛЯ без учёта viewInsets — autofocus-поле уезжало под
        // клавиатуру. Теперь высота — от окна в контексте шторки,
        // а сама шторка поднимается над клавиатурой нижним Padding.
        final keyboard = MediaQuery.viewInsetsOf(ctx).bottom;
        final availableHeight = MediaQuery.sizeOf(ctx).height - keyboard;
        return Padding(
          padding: EdgeInsets.only(bottom: keyboard),
          child: Container(
            height: availableHeight * 0.85,
            padding: const EdgeInsets.all(AppTheme.paddingMedium),
            child: _AddDrugSearch(
              allDrugs: allDrugs,
              excludeDrugs: _selectedDrugs,
              onSelected: (drug) {
                setState(() {
                  _selectedDrugs.add(drug);
                  if (_selectedDrugs.length >= 2) {
                    _checkInteractions();
                  }
                });
                Navigator.pop(ctx);
              },
            ),
          ),
        );
      },
    );
  }
}

class _InteractionCard extends StatelessWidget {
  final DrugInteractionExtended interaction;

  const _InteractionCard({required this.interaction});

  @override
  Widget build(BuildContext context) {
    // C1/C2: severity- и success-цвета — от фактической яркости темы.
    final brightness = Theme.of(context).brightness;
    final level = interaction.severityLevel;
    final color = interaction.severityColor(brightness);
    // C2: зелёный успеха — DsDark.accent на тёмном, AA-зелёный на светлом
    // (фиксированный светлый safeGreen давал в тёмной теме 2.4–2.9:1).
    final successFg = brightness == Brightness.dark
        ? AppTheme.safeGreenLight
        : AppTheme.accentText;
    final successBg = brightness == Brightness.dark
        ? AppTheme.darkPrimaryContainer
        : AppTheme.successContainer;

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.paddingSmall),
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 4)),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок
            Row(
              children: [
                Icon(interaction.severityIcon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${interaction.drug1} + ${interaction.drug2}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // C1: бейдж — SeverityColors.text/bg (жёлтый на жёлтом
                // давал 1.51:1); C15: fontSize 10 → 11.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: SeverityColors.bg(level, brightness),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    interaction.severityLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: SeverityColors.onBg(level, brightness),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            // Эффект
            if (interaction.effect.isNotEmpty)
              _InfoRow(label: 'Эффект', value: interaction.effect),
            // Последствия
            if (interaction.consequence.isNotEmpty)
              _InfoRow(label: 'Последствие', value: interaction.consequence),
            // Рекомендация
            if (interaction.recommendation.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  // C2: success-подложка — theme-aware (в тёмной теме был
                  // светлый зелёный остров с тёмным текстом 2.4–2.9:1).
                  color: successBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb, color: successFg, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        interaction.recommendation,
                        style: TextStyle(
                          fontSize: 12,
                          color: successFg,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddDrugSearch extends StatefulWidget {
  final List<CalcDrug> allDrugs;
  final List<CalcDrug> excludeDrugs;
  final Function(CalcDrug) onSelected;

  const _AddDrugSearch({
    required this.allDrugs,
    required this.excludeDrugs,
    required this.onSelected,
  });

  @override
  State<_AddDrugSearch> createState() => _AddDrugSearchState();
}

class _AddDrugSearchState extends State<_AddDrugSearch> {
  final TextEditingController _controller = TextEditingController();
  List<CalcDrug> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.allDrugs
        .where((d) => !widget.excludeDrugs.contains(d))
        .toList();
  }

  // ⚠ Фикс VV-024 (ревью 26.11.2026): контроллер не освобождался —
  // утечка на каждое открытие шторки.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _filter(String query) {
    final q = query.toLowerCase();
    setState(() {
      _filtered = widget.allDrugs.where((d) {
        if (widget.excludeDrugs.contains(d)) return false;
        return d.name.toLowerCase().contains(q) ||
            d.inn.toLowerCase().contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Добавить препарат',
                  style: Theme.of(context).textTheme.headlineMedium),
            ),
            // C19: явное закрытие шторки — не только свайпом вниз.
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Закрыть',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            // C10: labelText — после ввода видно, что это за поле
            // (hint исчезает при вводе; единицы здесь не нужны).
            labelText: 'Название или МНН',
            hintText: 'Поиск по названию или МНН...',
            prefixIcon: const Icon(Icons.search),
            // v1.16: filled/fillColor убраны — наследуют theme-aware inputDecorationTheme
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: _filter,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            itemCount: _filtered.length > 100 ? 100 : _filtered.length,
            itemBuilder: (context, index) {
              final drug = _filtered[index];
              final catColor = AppTheme.getCategoryColor(drug.category);
              return ListTile(
                leading: Container(
                  width: 4,
                  height: 32,
                  decoration: BoxDecoration(
                    color: catColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                title: Text(drug.name, style: const TextStyle(fontSize: 14)),
                subtitle: Text(drug.inn,
                    style: const TextStyle(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                onTap: () => widget.onSelected(drug),
              );
            },
          ),
        ),
      ],
    );
  }
}
