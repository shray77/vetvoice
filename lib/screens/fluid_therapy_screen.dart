import 'package:flutter/material.dart';
import '../models/fluid_therapy.dart';
import '../utils/app_theme.dart';

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
    final ml = w * 50;
    return '${ml.toStringAsFixed(0)} мл/сут (${(ml / 24).toStringAsFixed(1)} мл/ч)';
  }

  String _calcDeficit() {
    final w = _weightInput;
    if (w == null || w <= 0) return 'Укажите вес пациента';
    final deficit = w * _dehydrationPercent * 10;
    final hourlyRate = deficit / 24;
    final signs = _dehydrationPercent <= 5
        ? 'Слабость, сухость слизистых'
        : _dehydrationPercent <= 8
            ? 'Запавшие глаза, тургор снижен'
            : 'Гиповолемический шок, холодные конечности';
    return 'Дефицит: ${deficit.toStringAsFixed(0)} мл (${hourlyRate.toStringAsFixed(1)} мл/ч)\nПризнаки: $signs';
  }

  Widget _buildSolutionCard(FluidSolution s) {
    final isDark = AppTheme.isDark(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.safeGreen.withOpacity(isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  s.type,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.safeGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(s.composition, style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor(context))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: s.indications.map((ind) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurfaceLight : AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(ind, style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor(context))),
            )).toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.speed_rounded, size: 14, color: AppTheme.textTertiaryColor(context)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Скорость: ${s.rate}',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor(context)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProtocolCard(FluidSpecialProtocol p) {
    final isDark = AppTheme.isDark(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
          Row(
            children: [
              const Icon(Icons.local_hospital_rounded, color: AppTheme.errorRed, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  p.name,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimaryColor(context)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.maleBlue.withOpacity(isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  p.species,
                  style: const TextStyle(fontSize: 11, color: AppTheme.maleBlue, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(p.protocol, style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor(context), height: 1.4)),
          if (p.additives.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: p.additives.map((a) => Text('$a ', style: const TextStyle(fontSize: 12, color: AppTheme.safeGreen, fontWeight: FontWeight.w600))).toList(),
            ),
          ],
          if (p.monitoring.isNotEmpty) ...[
            Divider(color: AppTheme.dividerColor(context), height: 20),
            Text('Мониторинг:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondaryColor(context))),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: p.monitoring.map((m) => Text('$m ', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor(context)))).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCalcTab() {
    final isDark = AppTheme.isDark(context);

    return ListView(
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      children: [
        TextField(
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryColor(context)),
          decoration: InputDecoration(
            hintText: 'Вес животного (кг)',
            prefixIcon: Icon(Icons.scale_rounded, color: AppTheme.textSecondaryColor(context)),
          ),
          onChanged: (v) => setState(() => _weightInput = double.tryParse(v)),
        ),
        const SizedBox(height: 16),

        Text('Поддерживающая доза', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimaryColor(context))),
        const SizedBox(height: 2),
        Text('Норма: 50 мл/кг/сут', style: TextStyle(fontSize: 12, color: AppTheme.textTertiaryColor(context))),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.safeGreen.withOpacity(isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: AppTheme.safeGreen.withOpacity(0.3)),
          ),
          child: Text(_calcMaintenance(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.safeGreen)),
        ),
        const SizedBox(height: 18),

        Text('Дефицит жидкости', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimaryColor(context))),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('Дегидратация: ', style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor(context))),
            Expanded(
              child: Slider(
                value: _dehydrationPercent.toDouble(),
                min: 3,
                max: 12,
                divisions: 9,
                activeColor: AppTheme.warningOrange,
                onChanged: (v) => setState(() => _dehydrationPercent = v.round()),
              ),
            ),
            Text(
              '$_dehydrationPercent%',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.warningOrange),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.warningOrange.withOpacity(isDark ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: AppTheme.warningOrange.withOpacity(0.25)),
          ),
          child: Text(_calcDeficit(), style: TextStyle(fontSize: 13, color: AppTheme.textPrimaryColor(context), height: 1.4)),
        ),
        const SizedBox(height: 18),

        Text('Шоковая доза (кристаллоиды)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimaryColor(context))),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.errorRed.withOpacity(isDark ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: AppTheme.errorRed.withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Собаки: 20-30 мл/кг болюс, повторять до стабилизации', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryColor(context))),
              const SizedBox(height: 4),
              Text('Кошки: 10-15 мл/кг болюс', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryColor(context))),
              const SizedBox(height: 4),
              Text('Максимум: 60-90 мл/кг (собаки), 40-50 мл/кг (кошки)', style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor(context))),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(
        title: const Text('Инфузионная терапия'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.safeGreen,
          unselectedLabelColor: AppTheme.textTertiaryColor(context),
          indicatorColor: AppTheme.safeGreen,
          tabs: const [
            Tab(text: 'Калькулятор'),
            Tab(text: 'Растворы'),
            Tab(text: 'Протоколы'),
            Tab(text: 'Добавки'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCalcTab(),
          ListView.separated(
            padding: const EdgeInsets.all(AppTheme.paddingMedium),
            itemCount: widget.db.solutions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _buildSolutionCard(widget.db.solutions[i]),
          ),
          ListView.separated(
            padding: const EdgeInsets.all(AppTheme.paddingMedium),
            itemCount: widget.db.specialProtocols.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _buildProtocolCard(widget.db.specialProtocols[i]),
          ),
          ListView.separated(
            padding: const EdgeInsets.all(AppTheme.paddingMedium),
            itemCount: widget.db.additives.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final a = widget.db.additives[i];
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
                    Row(
                      children: [
                        const Icon(Icons.science_rounded, color: AppTheme.maleBlue, size: 20),
                        const SizedBox(width: 8),
                        Text(a.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimaryColor(context))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Показание: ${a.indication}', style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor(context))),
                    if (a.concentration.isNotEmpty)
                      Text('Концентрация: ${a.concentration}', style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor(context))),
                    if (a.doses.isNotEmpty)
                      Text(a.doses.entries.map((e) => '${e.key}: ${e.value}').join(', '), style: const TextStyle(fontSize: 13, color: AppTheme.safeGreen, fontWeight: FontWeight.w600)),
                    if (a.notes.isNotEmpty)
                      Text(a.notes, style: const TextStyle(fontSize: 12, color: AppTheme.warningOrange, fontStyle: FontStyle.italic)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
