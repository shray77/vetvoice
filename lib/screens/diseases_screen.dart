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
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(
        title: const Text('Справочник болезней'),
        actions: [
          IconButton(
            icon: Icon(
              _showOnlyDangerous ? Icons.warning_rounded : Icons.warning_amber_rounded,
              color: _showOnlyDangerous ? AppTheme.errorRed : AppTheme.textSecondaryColor(context),
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              style: TextStyle(fontSize: 14, color: AppTheme.textPrimaryColor(context), fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Поиск болезни, кода МКБ...',
                prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textSecondaryColor(context)),
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
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor(context), fontWeight: FontWeight.w600),
                ),
                if (_showOnlyDangerous)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '⚠️ Особо опасные',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.errorRed),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Список болезней
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: filteredDiseases.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
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
    final isDark = AppTheme.isDark(context);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _filterAnimal = category),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.safeGreen.withOpacity(isDark ? 0.25 : 0.12)
                : AppTheme.cardColor(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            border: Border.all(
              color: isSelected ? AppTheme.safeGreen : AppTheme.borderColor(context),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? AppTheme.safeGreen : AppTheme.textPrimaryColor(context),
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiseaseCard(Disease disease, TreatmentProtocol? protocol) {
    final hasProtocol = protocol != null && (protocol.hasPrimaryDrugs || protocol.hasSupportiveTherapy);
    final hasMu = disease.mu.isNotEmpty;
    final isDark = AppTheme.isDark(context);

    final borderColor = disease.isParticularlyDangerous
        ? AppTheme.errorRed.withOpacity(0.4)
        : hasProtocol
            ? AppTheme.safeGreen.withOpacity(0.35)
            : AppTheme.borderColor(context);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: borderColor),
        boxShadow: AppTheme.cardShadow(context),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              if (disease.isParticularlyDangerous) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withOpacity(isDark ? 0.25 : 0.12),
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
                    fontWeight: FontWeight.w700,
                    color: disease.isParticularlyDangerous ? AppTheme.errorRed : AppTheme.textPrimaryColor(context),
                  ),
                ),
              ),
              if (hasProtocol)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.safeGreen.withOpacity(isDark ? 0.25 : 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('💊', style: TextStyle(fontSize: 12)),
                ),
              if (hasMu) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.maleBlue.withOpacity(isDark ? 0.25 : 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('📋', style: TextStyle(fontSize: 12)),
                ),
              ],
            ],
          ),
          subtitle: Text(
            '${disease.code} ${hasProtocol ? "• Протокол" : ""} ${hasMu ? "• ${disease.mu.length} МУ" : ""}',
            style: TextStyle(
              fontSize: 12,
              color: hasProtocol ? AppTheme.safeGreen : (hasMu ? AppTheme.maleBlue : AppTheme.textTertiaryColor(context)),
            ),
          ),
          children: [
            Divider(color: AppTheme.dividerColor(context), height: 1),
            const SizedBox(height: 10),

            _buildInfoRow('Категория', _getCategoryName(disease.category)),
            _buildInfoRow('Код МКБ', disease.code),
            if (disease.animals.isNotEmpty)
              _buildInfoRow('Животные', disease.animals.join(', ')),

            if (disease.methods.isNotEmpty) ...[
              const SizedBox(height: 4),
              _buildInfoRow('Методы', disease.methods.join(', ')),
            ],

            if (hasMu) ...[
              const SizedBox(height: 12),
              _buildMuSection(disease),
            ],

            if (hasProtocol) ...[
              const SizedBox(height: 12),
              _buildProtocolSection(protocol!),
            ] else ...[
              const SizedBox(height: 4),
              Text(
                'Протокол лечения не зарегистрирован в базе',
                style: TextStyle(fontSize: 12, color: AppTheme.textTertiaryColor(context)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMuSection(Disease disease) {
    final isDark = AppTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.maleBlue.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.maleBlue.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book_rounded, size: 18, color: AppTheme.maleBlue),
              const SizedBox(width: 8),
              Text(
                'МЕТОДИЧЕСКИЕ УКАЗАНИЯ (${disease.mu.length})',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.maleBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mu.code,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimaryColor(context)),
          ),
          if (mu.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                mu.description,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor(context)),
              ),
            ),
          if (mu.note != null && mu.note!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '📝 ${mu.note!}',
                style: TextStyle(fontSize: 11, color: AppTheme.textTertiaryColor(context), fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProtocolSection(TreatmentProtocol protocol) {
    final isDark = AppTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.safeGreen.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.safeGreen.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.medication_rounded, size: 18, color: AppTheme.safeGreen),
              const SizedBox(width: 8),
              const Text(
                'ПРОТОКОЛ ЛЕЧЕНИЯ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.safeGreen,
                ),
              ),
            ],
          ),
          if (protocol.pathogenType.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(protocol.pathogenType, style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor(context))),
            ),

          const SizedBox(height: 10),

          if (protocol.hasPrimaryDrugs) ...[
            Text(
              'Специфическая терапия',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimaryColor(context)),
            ),
            const SizedBox(height: 8),
            ...protocol.primaryDrugs.take(6).map((drug) => _buildDrugCard(drug)),
          ],

          if (protocol.hasSupportiveTherapy) ...[
            const SizedBox(height: 12),
            Text(
              'Симптоматическая терапия',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimaryColor(context)),
            ),
            const SizedBox(height: 8),
            ...protocol.supportiveTherapy.take(4).map((drug) => _buildSupportDrugCard(drug)),
          ],
        ],
      ),
    );
  }

  Widget _buildDrugCard(TreatmentDrug drug) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            drug.name,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimaryColor(context)),
          ),
          if (drug.inn.isNotEmpty && drug.inn.toLowerCase() != drug.name.toLowerCase())
            Text(
              drug.inn,
              style: TextStyle(fontSize: 11, color: AppTheme.textTertiaryColor(context), fontStyle: FontStyle.italic),
            ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (drug.dose.isNotEmpty && drug.dose != 'по инструкции')
                _buildParamChip('Доза', drug.dose),
              if (drug.route.isNotEmpty && drug.route != 'по инструкции')
                _buildParamChip('Путь', drug.route),
              if (drug.frequency.isNotEmpty && drug.frequency != 'по инструкции')
                _buildParamChip('Кратность', drug.frequency),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSupportDrugCard(SupportiveTherapy drug) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.isDark(context) ? AppTheme.darkSurfaceLight : AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  drug.name,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryColor(context)),
                ),
                if (drug.dose.isNotEmpty)
                  Text('💊 ${drug.dose}', style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParamChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.safeGreen.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.safeGreen),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text('$label:', style: TextStyle(fontSize: 12, color: AppTheme.textTertiaryColor(context))),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryColor(context))),
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
