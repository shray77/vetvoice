import 'package:flutter/material.dart';
import '../models/disease.dart';
import '../models/treatment_protocol.dart';
import '../utils/app_theme.dart';

/// Экран справочника болезней с протоколами лечения и МУ
class DiseasesScreen extends StatefulWidget {
  final DiseaseDatabase database;
  final TreatmentProtocolDatabase? treatmentDatabase;
  final String? selectedAnimal;

  const DiseasesScreen({
    super.key,
    required this.database,
    this.treatmentDatabase,
    this.selectedAnimal,
  });

  @override
  State<DiseasesScreen> createState() => _DiseasesScreenState();
}

class _DiseasesScreenState extends State<DiseasesScreen> {
  String _searchQuery = '';
  String? _filterAnimal;
  bool _showOnlyDangerous = false;

  @override
  void initState() {
    super.initState();
    _filterAnimal = widget.selectedAnimal;
  }

  /// Получить протокол для болезни
  TreatmentProtocol? _getProtocol(Disease disease) {
    return widget.treatmentDatabase?.findByDiseaseName(disease.name);
  }

  List<Disease> get filteredDiseases {
    var diseases = widget.database.diseases;

    if (_filterAnimal != null && _filterAnimal!.isNotEmpty) {
      diseases = diseases.where((d) => d.isForAnimal(_filterAnimal!)).toList();
    }

    if (_showOnlyDangerous) {
      diseases = diseases.where((d) => d.isParticularlyDangerous).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      diseases = diseases.where((d) =>
          d.name.toLowerCase().contains(query) ||
          d.code.toLowerCase().contains(query)).toList();
    }

    return diseases;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Справочник болезней'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          Text(
            '${widget.treatmentDatabase?.protocols.length ?? 0} протоколов',
            style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              _showOnlyDangerous ? Icons.warning : Icons.warning_outlined,
              color: _showOnlyDangerous ? AppTheme.errorRed : AppTheme.textSecondary,
            ),
            onPressed: () => setState(() => _showOnlyDangerous = !_showOnlyDangerous),
            tooltip: 'Только особо опасные',
          ),
        ],
      ),
      body: Column(
        children: [
          // Поиск
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                hintText: 'Поиск болезни...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: const BorderSide(color: AppTheme.dividerGray),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: const BorderSide(color: AppTheme.dividerGray),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: const BorderSide(color: AppTheme.safeGreen, width: 2),
                ),
              ),
            ),
          ),

          // Фильтр по животным
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildAnimalChip('Все', null),
                _buildAnimalChip('КРС', 'КРС'),
                _buildAnimalChip('МРС', 'МРС'),
                _buildAnimalChip('Свиньи', 'Свиньи'),
                _buildAnimalChip('Птица', 'Птица'),
                _buildAnimalChip('Лошади', 'Лошади'),
                _buildAnimalChip('Собаки', 'Собаки'),
                _buildAnimalChip('Кошки', 'Кошки'),
                _buildAnimalChip('Пчёлы', 'Пчелы'),
                _buildAnimalChip('Рыбы', 'Рыбы'),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Счётчик
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Найдено: ${filteredDiseases.length}',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                if (_showOnlyDangerous)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '⚠️ Особо опасные',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.errorRed),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Список болезней
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filteredDiseases.length,
              itemBuilder: (context, index) {
                final disease = filteredDiseases[index];
                final protocol = _getProtocol(disease);
                return _buildDiseaseCard(disease, protocol);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimalChip(String label, String? category) {
    final isSelected = _filterAnimal == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _filterAnimal = category),
        selectedColor: AppTheme.safeGreen.withOpacity(0.2),
        checkmarkColor: AppTheme.safeGreen,
        backgroundColor: AppTheme.backgroundFor(context),
        labelStyle: TextStyle(
          fontSize: 13,
          color: isSelected ? AppTheme.safeGreen : AppTheme.textSecondary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildDiseaseCard(Disease disease, TreatmentProtocol? protocol) {
    final hasProtocol = protocol != null && (protocol.hasPrimaryDrugs || protocol.hasSupportiveTherapy);
    final hasMu = disease.mu.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        side: BorderSide(
          color: disease.isParticularlyDangerous
              ? AppTheme.errorRed.withOpacity(0.3)
              : hasProtocol
                  ? AppTheme.safeGreen.withOpacity(0.3)
                  : AppTheme.dividerGray,
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            if (disease.isParticularlyDangerous) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('⚠️', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                disease.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: disease.isParticularlyDangerous ? AppTheme.errorRed : AppTheme.textPrimary,
                ),
              ),
            ),
            if (hasProtocol)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.safeGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '💊',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            if (hasMu)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.maleBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '📋',
                  style: TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '${disease.code} ${hasProtocol ? "• Протокол лечения" : ""} ${hasMu ? "• ${disease.mu.length} МУ" : ""}',
          style: TextStyle(
            fontSize: 12,
            color: hasProtocol ? AppTheme.safeGreen : hasMu ? AppTheme.maleBlue : AppTheme.textTertiary,
          ),
        ),
        children: [
          const Divider(),
          const SizedBox(height: 8),

          // Основная информация
          _buildInfoRow('Категория', _getCategoryName(disease.category)),
          _buildInfoRow('Код', disease.code),
          if (disease.animals.isNotEmpty)
            _buildInfoRow('Животные', disease.animals.join(', ')),

          // Методы диагностики
          if (disease.methods.isNotEmpty) ...[
            const SizedBox(height: 4),
            _buildInfoRow('Методы', disease.methods.join(', ')),
          ],

          // МУ (методические указания)
          if (hasMu) ...[
            const SizedBox(height: 12),
            _buildMuSection(disease),
          ],

          // Протокол лечения
          if (hasProtocol) ...[
            const SizedBox(height: 12),
            _buildProtocolSection(protocol!),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              'ℹ️ Протокол лечения не доступен для данной болезни',
              style: TextStyle(fontSize: 12, color: AppTheme.textTertiary.withOpacity(0.7)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMuSection(Disease disease) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.maleBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.maleBlue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок МУ
          Row(
            children: [
              const Icon(Icons.menu_book, size: 18, color: AppTheme.maleBlue),
              const SizedBox(width: 8),
              Text(
                'МЕТОДИЧЕСКИЕ УКАЗАНИЯ (${disease.mu.length})',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.maleBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Список МУ
          ...disease.mu.map((mu) => _buildMuCard(mu)),
        ],
      ),
    );
  }

  Widget _buildMuCard(dynamic mu) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.dividerGray.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Код МУ
          Text(
            mu.code,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
          ),
          if (mu.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                mu.description,
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
          if (mu.note != null && mu.note!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '📝 ${mu.note!}',
                style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProtocolSection(TreatmentProtocol protocol) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.safeGreen.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.safeGreen.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок протокола
          Row(
            children: [
              const Icon(Icons.medication, size: 18, color: AppTheme.safeGreen),
              const SizedBox(width: 8),
              const Text(
                'ПРОТОКОЛ ЛЕЧЕНИЯ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.safeGreen,
                ),
              ),
              const Spacer(),
              if (protocol.severity == 'severe')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('ОСОБО ОПАСНАЯ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.errorRed)),
                ),
            ],
          ),
          if (protocol.pathogenType.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(protocol.pathogenType, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ),
          if (protocol.source.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(protocol.source, style: const TextStyle(fontSize: 10, color: AppTheme.textTertiary, fontStyle: FontStyle.italic)),
            ),

          const Divider(height: 24),

          // Специфическая терапия
          if (protocol.hasPrimaryDrugs) ...[
            const Text(
              'Специфическая терапия',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            ...protocol.primaryDrugs.take(10).map((drug) => _buildDrugCard(drug)),
            if (protocol.primaryDrugs.length > 10)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '...и ещё ${protocol.primaryDrugs.length - 10} препаратов',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                ),
              ),
          ],

          // Симптоматическая терапия
          if (protocol.hasSupportiveTherapy) ...[
            const SizedBox(height: 16),
            const Text(
              'Симптоматическая терапия',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            ...protocol.supportiveTherapy.take(5).map((drug) => _buildSupportDrugCard(drug)),
          ],

          // Предупреждения
          if (protocol.warnings.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...protocol.warnings.map((w) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '⚠️ $w',
                style: const TextStyle(fontSize: 11, color: AppTheme.errorRed),
              ),
            )),
          ],

          // Примечания
          if (protocol.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...protocol.notes.map((n) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $n',
                style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildDrugCard(TreatmentDrug drug) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.dividerGray.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Название и МНН
          Text(
            drug.name,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
          ),
          if (drug.inn.isNotEmpty && drug.inn.toLowerCase() != drug.name.toLowerCase())
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                drug.inn,
                style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary, fontStyle: FontStyle.italic),
              ),
            ),
          const SizedBox(height: 6),
          // Параметры
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (drug.dose.isNotEmpty && drug.dose != 'по инструкции')
                _buildParamChip('Дозировка', drug.dose),
              if (drug.route.isNotEmpty && drug.route != 'по инструкции')
                _buildParamChip('Путь', drug.route),
              if (drug.frequency.isNotEmpty && drug.frequency != 'по инструкции')
                _buildParamChip('Кратность', drug.frequency),
              if (drug.duration.isNotEmpty && drug.duration != 'по инструкции')
                _buildParamChip('Курс', drug.duration),
            ],
          ),
          if (drug.waitingPeriod.isNotEmpty && drug.waitingPeriod != '')
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '🕐 Срок ожидания: ${drug.waitingPeriod}',
                style: const TextStyle(fontSize: 10, color: AppTheme.textTertiary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSupportDrugCard(SupportiveTherapy drug) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.backgroundFor(context).withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            drug.name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
          ),
          if (drug.inn.isNotEmpty)
            Text(drug.inn, style: const TextStyle(fontSize: 10, color: AppTheme.textTertiary, fontStyle: FontStyle.italic)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 2,
            children: [
              if (drug.dose.isNotEmpty && drug.dose != 'по инструкции')
                Text('💊 ${drug.dose}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              if (drug.route.isNotEmpty && drug.route != 'по инструкции')
                Text('📍 ${drug.route}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              if (drug.frequency.isNotEmpty && drug.frequency != 'по инструкции')
                Text('🔄 ${drug.frequency}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParamChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.safeGreen.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text('$label:', style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }

  String _getCategoryName(String category) {
    switch (category) {
      case 'particularly_dangerous':
        return '🚨 Особо опасная';
      case 'infectious':
        return '🦠 Инфекционная';
      case 'invasive':
        return '🪱 Инвазионная';
      case 'fish_diseases':
        return '🐟 Болезнь рыб';
      case 'bee_diseases':
        return '🐝 Болезнь пчёл';
      case 'non_contagious':
        return '📋 Незаразная';
      default:
        return category;
    }
  }
}
