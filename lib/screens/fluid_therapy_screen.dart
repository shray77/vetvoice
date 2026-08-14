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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
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
                  color: AppTheme.safeGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(s.type, style: const TextStyle(
                  fontSize: 11, color: AppTheme.safeGreen, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(s.name, style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
            ],
          ),
          const SizedBox(height: 8),
          Text(s.composition, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6, runSpacing: 4,
            children: s.indications.map((ind) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.backgroundFor(context),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(ind, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            )).toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.speed, size: 14, color: AppTheme.textTertiary),
              const SizedBox(width: 4),
              Expanded(child: Text('Скорость: ${s.rate}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProtocolCard(FluidSpecialProtocol p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
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
          Text(p.protocol, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4)),
          if (p.additives.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 4,
              children: p.additives.map((a) => Text('$a ', style: const TextStyle(fontSize: 12, color: AppTheme.safeGreen))).toList()),
          ],
          if (p.monitoring.isNotEmpty) ...[
            const Divider(height: 24),
            const Text('Мониторинг:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 4,
              children: p.monitoring.map((m) => Text('$m ', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))).toList()),
          ],
        ],
      ),
    );
  }

  Widget _buildCalcTab() {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      children: [
        TextField(
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            hintText: 'Вес животного (кг)',
            prefixIcon: Icon(Icons.scale, color: AppTheme.textTertiary),
          ),
          onChanged: (v) => setState(() => _weightInput = double.tryParse(v)),
        ),
        const SizedBox(height: 24),
        const Text('Поддерживающая доза', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('50 мл/кг/сут', style: TextStyle(fontSize: 13, color: AppTheme.textTertiary)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppTheme.safeGreen.withOpacity(0.08), borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
          child: Text(_calcMaintenance(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.safeGreen)),
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
          decoration: BoxDecoration(color: AppTheme.warningOrange.withOpacity(0.08), borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
          child: Text(_calcDeficit(), style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary, height: 1.5)),
        ),
        const SizedBox(height: 24),
        const Text('Шоковая доза (кристаллоиды)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppTheme.errorRed.withOpacity(0.08), borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
          child: const Column(
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
    return Scaffold(
      backgroundColor: AppTheme.backgroundFor(context),
      appBar: AppBar(
        title: const Text('Инфузионная терапия'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.safeGreen,
          unselectedLabelColor: AppTheme.textTertiary,
          indicatorColor: AppTheme.safeGreen,
          tabs: const [Tab(text: 'Калькулятор'), Tab(text: 'Растворы'), Tab(text: 'Протоколы'), Tab(text: 'Добавки')],
        ),
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
            itemBuilder: (_, i) {
              final a = widget.db.additives[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(AppTheme.radiusMedium), boxShadow: AppTheme.softShadow),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.science, color: AppTheme.maleBlue, size: 20),
                      const SizedBox(width: 8),
                      Text(a.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 6),
                    Text('Показание: \${a.indication}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    if (a.concentration.isNotEmpty) Text('Концентрация: \${a.concentration}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    if (a.doses.isNotEmpty) Text(a.doses.entries.map((e) => '${e.key}: ${e.value}').join(', '), style: const TextStyle(fontSize: 13, color: AppTheme.safeGreen, fontWeight: FontWeight.w500)),
                    if (a.notes.isNotEmpty) Text(a.notes, style: const TextStyle(fontSize: 12, color: AppTheme.warningOrange, fontStyle: FontStyle.italic)),
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
