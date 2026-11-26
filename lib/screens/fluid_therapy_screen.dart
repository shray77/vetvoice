import 'package:flutter/material.dart';
import '../models/fluid_therapy.dart';
import '../utils/app_theme.dart';
import '../utils/decimal_input.dart';
import '../widgets/common/app_scaffold.dart';

class FluidTherapyScreen extends StatefulWidget {
  final FluidTherapyDatabase db;
  const FluidTherapyScreen({super.key, required this.db});

  @override
  State<FluidTherapyScreen> createState() => _FluidTherapyScreenState();
}

class _FluidTherapyScreenState extends State<FluidTherapyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  double? _weightInput;
  int _dehydrationPercent = 5;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _calcMaintenance() {
    final w = _weightInput;
    if (w == null || w <= 0) return 'Укажите вес животного';
    final ml = w * 50; // 50 мл/кг/сут
    return '${ml.toStringAsFixed(0)} мл/сут (${(ml/24).toStringAsFixed(1)} мл/ч)';
  }

  String _calcDeficit() {
    final w = _weightInput;
    if (w == null || w <= 0) return 'Укажите вес';
    final deficit = w * _dehydrationPercent * 10; // 10 мл/кг/%
    final hourlyRate = deficit / 24;
    final signs = _dehydrationPercent <= 5
        ? 'Слабость, сухость кожи'
        : _dehydrationPercent <= 8
            ? 'Запавшие глаза, тургор снижен'
            : 'Шок, холодные конечности';
    return 'Дефицит: ${deficit.toStringAsFixed(0)} мл (${hourlyRate.toStringAsFixed(1)} мл/ч)\nПризнаки: $signs';
  }

  Widget _buildSolutionCard(FluidSolution s) {
    // Ревью 26.11.2026, VV-051: цвет суточного лимита — severity-лестница
    // DS от фактической яркости темы (Theme.of(context), не светлые
    // константы — иначе нечитаемо в тёмной, класс бага VV-065).
    final brightness = Theme.of(context).brightness;
    final warnColor = SeverityColors.text(SeverityLevel.major, brightness);
    // C2: бейдж типа раствора — theme-aware зелёный (фиксированный светлый
    // safeGreen давал 2.4–2.9:1 на тёмном фоне).
    final isDark = brightness == Brightness.dark;
    final green = isDark ? AppTheme.safeGreenLight : AppTheme.accentText;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(s.type,
                    style: TextStyle(
                        fontSize: 11, color: green, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(s.name, style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
            ],
          ),
          const SizedBox(height: 8),
          Text(s.composition, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6, runSpacing: 4,
            children: s.indications.map((ind) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.backgroundGray,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(ind, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            )).toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.speed, size: 14, color: AppTheme.textTertiary),
              const SizedBox(width: 4),
              Expanded(child: Text('Скорость: ${s.rate}', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
            ],
          ),
          // Ревью 26.11.2026, VV-051: суточный потолок коллоидов
          // (max_dose, Гелофузин/Венофундин ГЭК) и период полувыведения
          // (half_life) были в JSON, но не доезжали до карточки — лимит
          // можно было молча превысить.
          if (s.maxDose != null && s.maxDose!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.warning_amber, size: 14, color: warnColor),
                const SizedBox(width: 4),
                Expanded(child: Text('Макс. доза: ${s.maxDose}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: warnColor))),
              ],
            ),
          ],
          if (s.halfLife != null && s.halfLife!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: AppTheme.textTertiary),
                const SizedBox(width: 4),
                Expanded(child: Text('T½: ${s.halfLife}', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProtocolCard(FluidSpecialProtocol p) {
    // C2: additives — theme-aware зелёный (светлый токен слеп в тёмной теме).
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final green = isDark ? AppTheme.safeGreenLight : AppTheme.accentText;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_hospital, color: AppTheme.errorRed, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(p.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppTheme.maleBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(p.species, style: const TextStyle(fontSize: 11, color: AppTheme.maleBlue, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Ревью 26.11.2026, находка аудита VV-012-блока: protocol —
          // список фаз/шагов (раньше все протоколы молча выбрасывались
          // при парсинге, вкладка была пустой). Рисуем каждый шаг строкой.
          if (p.protocol.isEmpty)
            Text('Протокол не распарсен — проверьте данные',
                style: TextStyle(fontSize: 13, color: AppTheme.warningOrange))
          else
            ...p.protocol.map((s) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '• ${s.display}',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.4),
                  ),
                )),
          if (p.additives.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 4,
                children: p.additives.map((a) => Text('$a ', style: TextStyle(fontSize: 12, color: green))).toList()),
          ],
          if (p.monitoring.isNotEmpty) ...[
            const Divider(height: 24),
            Text('Мониторинг:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 4,
              children: p.monitoring.map((m) => Text('$m ', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary))).toList()),
          ],
        ],
      ),
    );
  }

  Widget _buildAdditiveCard(FluidAdditive a) {
    // Ревью 26.11.2026, VV-012: monitoring (условие остановки инфузии)
    // выделяем severity-лестницей DS от фактической яркости темы
    // (Theme.of(context), не светлые константы — иначе нечитаемо в
    // тёмной, класс бага VV-065).
    final brightness = Theme.of(context).brightness;
    final monitorColor = SeverityColors.text(SeverityLevel.major, brightness);
    // C2: дозы — theme-aware зелёный (светлый токен слеп в тёмной теме).
    final green = brightness == Brightness.dark
        ? AppTheme.safeGreenLight
        : AppTheme.accentText;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.white, borderRadius: BorderRadius.circular(AppTheme.radiusMedium), boxShadow: AppTheme.softShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.science, color: AppTheme.maleBlue, size: 20),
              const SizedBox(width: 8),
              Text(a.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Text('Показание: ${a.indication}', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          if (a.concentration.isNotEmpty) Text('Концентрация: ${a.concentration}', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          if (a.doses.isNotEmpty) Text(a.doses.entries.map((e) => '${e.key}: ${e.value}').join(', '), style: TextStyle(fontSize: 13, color: green, fontWeight: FontWeight.w500)),
          // Ревью 26.11.2026, VV-012: max_rate был в модели, но не
          // выводился — потолок скорости инфузии KCl врач не видел.
          if (a.maxRate.isNotEmpty) Text('Макс. скорость: ${a.maxRate}', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          if (a.notes.isNotEmpty) Text(a.notes, style: const TextStyle(fontSize: 12, color: AppTheme.warningOrange, fontStyle: FontStyle.italic)),
          // Ревью 26.11.2026, VV-012: правило остановки инфузии (у
          // Ca-глюконата 10% — «ЭКГ (брадикардия = остановить!)») раньше
          // терялось при парсинге. Теперь — отдельной заметной строкой
          // с warning_amber на severity-подложке DS, а не тихими notes.
          if (a.monitoring != null && a.monitoring!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: SeverityColors.bg(SeverityLevel.major, brightness),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, size: 16, color: monitorColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Мониторинг: ${a.monitoring}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: SeverityColors.onBg(SeverityLevel.major, brightness)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCalcTab() {
    // C2: результат — theme-aware зелёный (фиксированный светлый safeGreen
    // давал 2.4–2.9:1 на тёмном фоне).
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final green = isDark ? AppTheme.safeGreenLight : AppTheme.accentText;
    // C14: ошибка валидации («Укажите вес») — не результат расчёта.
    final hasWeight = _weightInput != null && _weightInput! > 0;
    return ListView(
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      children: [
        TextField(
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            // C10: labelText с единицами — после ввода видно, что это за поле
            // (hint исчезает при вводе).
            labelText: 'Вес животного (кг)',
            hintText: 'Вес животного (кг)',
            prefixIcon: Icon(Icons.scale, color: AppTheme.textTertiary),
          ),
          // Task 178: RU-запятая — раньше «12,5» давало null и поле
          // просило «Укажите вес» при введённом значении.
          onChanged: (v) => setState(() => _weightInput = parseDecimal(v)),
        ),
        const SizedBox(height: 24),
        const Text('Поддерживающая доза', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('50 мл/кг/сут', style: TextStyle(fontSize: 13, color: AppTheme.textTertiary)),
        const SizedBox(height: 8),
        // C14: «Укажите вес» раньше жил в зелёном блоке с fontWeight 600 —
        // выглядел как рассчитанная доза. Теперь — цвет ошибки и без
        // «успешного» жирного вида.
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: hasWeight
                ? green.withOpacity(0.08)
                : AppTheme.errorRed.withOpacity(0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          child: Text(
            hasWeight ? _calcMaintenance() : 'Укажите вес животного',
            style: TextStyle(
              fontSize: hasWeight ? 18 : 14,
              fontWeight: hasWeight ? FontWeight.w600 : FontWeight.w500,
              color: hasWeight ? green : AppTheme.errorRed,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Дефицит жидкости', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Дегидратация: ', style: TextStyle(fontSize: 14)),
            Expanded(child: Slider(value: _dehydrationPercent.toDouble(), min: 3, max: 12, divisions: 9,
              activeColor: AppTheme.warningOrange,
              onChanged: (v) => setState(() => _dehydrationPercent = v.round()))),
            Text('$_dehydrationPercent%', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.warningOrange)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: hasWeight
                ? AppTheme.warningOrange.withOpacity(0.08)
                : AppTheme.errorRed.withOpacity(0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          child: Text(
            hasWeight
                ? _calcDeficit()
                : 'Укажите вес животного для расчёта дефицита',
            style: TextStyle(
              fontSize: 15,
              color: hasWeight ? AppTheme.textPrimary : AppTheme.errorRed,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Шоковая доза (кристаллоиды)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppTheme.errorRed.withOpacity(0.08), borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Собаки: 20-30 мл/кг болюс, повторять до стабилизации', style: TextStyle(fontSize: 14)),
              SizedBox(height: 4),
              Text('Кошки: 10-15 мл/кг болюс', style: TextStyle(fontSize: 14)),
              SizedBox(height: 4),
              Text('Максимум: 60-90 мл/кг (собаки), 40-50 мл/кг (кошки)', style: TextStyle(fontSize: 12, color: AppTheme.textTertiary)),
            ],
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Инфузионная терапия',
      bottom: TabBar(
        controller: _tabController,
        labelColor: AppTheme.safeGreen,
        unselectedLabelColor: AppTheme.textTertiary,
        indicatorColor: AppTheme.safeGreen,
        tabs: const [Tab(text: 'Калькулятор'), Tab(text: 'Растворы'), Tab(text: 'Протоколы'), Tab(text: 'Добавки')],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCalcTab(),
          ListView.builder(
            padding: const EdgeInsets.all(AppTheme.paddingMedium),
            itemCount: widget.db.solutions.length,
            itemBuilder: (_, i) => _buildSolutionCard(widget.db.solutions[i]),
          ),
          ListView.builder(
            padding: const EdgeInsets.all(AppTheme.paddingMedium),
            itemCount: widget.db.specialProtocols.length,
            itemBuilder: (_, i) => _buildProtocolCard(widget.db.specialProtocols[i]),
          ),
          ListView.builder(
            padding: const EdgeInsets.all(AppTheme.paddingMedium),
            itemCount: widget.db.additives.length,
            // Ревью 26.11.2026, VV-012: карточка добавки вынесена в
            // _buildAdditiveCard — наравне с растворами и протоколами.
            itemBuilder: (_, i) => _buildAdditiveCard(widget.db.additives[i]),
          ),
        ],
      ),
    );
  }
}
