import 'package:flutter/material.dart';
import '../providers/vet_provider.dart';
import '../utils/app_theme.dart';
import 'interaction_warning.dart';
import '../services/favorites_service.dart';
import '../services/history_service.dart';
import 'vaccine_card.dart';

/// Карточка результата с возможностью корректировки дозы
class ResultCard extends StatefulWidget {
  final DoseResult result;
  final VoidCallback? onSpeak;
  final Function(double)? onDoseChanged;
  final String? animalName;
  final double? weightKg;

  const ResultCard({
    super.key,
    required this.result,
    this.onSpeak,
    this.onDoseChanged,
    this.animalName,
    this.weightKg,
  });

  @override
  State<ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<ResultCard> {
  late double _selectedDose;
  bool _showSideEffects = false;
  final FavoritesService _favService = FavoritesService();
  final HistoryService _histService = HistoryService();
  bool _savedToHistory = false;

  @override
  void initState() {
    super.initState();
    _selectedDose = widget.result.dosePerKg;
    _favService.init();
    _histService.init();
  }

  @override
  void didUpdateWidget(ResultCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result.dosePerKg != widget.result.dosePerKg) {
      _selectedDose = widget.result.dosePerKg;
      _savedToHistory = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.result.hasError) return _buildError();
    if (!widget.result.hasResult) return _buildPlaceholder();

    final drug = widget.result.calcDrug;
    if (drug != null &&
        drug.isVaccine &&
        drug.vaccineSpecific != null &&
        drug.vaccineSpecific!.hasData) {
      return Column(
        children: [
          _buildFavoriteButton(drug.id),
          const SizedBox(height: 8),
          VaccineCard(
            drug: drug,
            drugName: drug.name,
            drugInn: drug.inn,
            vaccine: drug.vaccineSpecific,
            category: drug.category,
            onSpeak: widget.onSpeak,
          ),
        ],
      );
    }

    if (widget.result.hasDosage) return _buildCalculated();
    return _buildInfo();
  }

  Widget _buildFavoriteButton(int drugId) {
    return AnimatedBuilder(
      animation: _favService,
      builder: (context, _) {
        final isFav = _favService.isFavorite(drugId);
        return Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () async {
              await _favService.toggleFavorite(drugId);
              if (mounted) setState(() {});
            },
            icon: Icon(
              isFav ? Icons.star_rounded : Icons.star_border_rounded,
              color: isFav ? AppTheme.warningOrange : AppTheme.textSecondaryColor(context),
              size: 20,
            ),
            label: Text(
              isFav ? 'В избранном' : 'В избранное',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isFav ? AppTheme.warningOrange : AppTheme.textSecondaryColor(context),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderColor(context)),
        boxShadow: AppTheme.cardShadow(context),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.safeGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.medication_liquid_rounded, size: 36, color: AppTheme.safeGreen),
          ),
          const SizedBox(height: 14),
          Text(
            'Выберите животное и препарат',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'или произнесите голосовую команду',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textTertiaryColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.errorRed.withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.errorRed, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.result.error,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.errorRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculated() {
    final isDark = AppTheme.isDark(context);
    final hasRiskWarnings = widget.result.hasRiskWarnings;
    final hasWarnings = widget.result.hasContraindications;
    final hasInteractions = widget.result.hasInteractions;
    final hasSideEffects = widget.result.hasSideEffects;
    final hasDoseRange = widget.result.hasDoseRange;

    final String category = widget.result.calcDrug?.category ?? '';
    final catColor = AppTheme.getCategoryColor(category);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Предупреждения о взаимодействиях
        if (hasInteractions)
          InteractionWarning(interactions: widget.result.interactions),

        // Главная карточка
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: hasRiskWarnings
                ? AppTheme.errorRed.withOpacity(isDark ? 0.15 : 0.05)
                : AppTheme.cardColor(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(
              color: hasRiskWarnings
                  ? AppTheme.errorRed.withOpacity(0.5)
                  : AppTheme.safeGreen.withOpacity(0.3),
              width: hasRiskWarnings ? 1.5 : 1.0,
            ),
            boxShadow: AppTheme.cardShadow(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Верхний хедер карточки
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 12, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (category.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: catColor.withOpacity(isDark ? 0.25 : 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    category,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: catColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              if (widget.result.withdrawalDays > 0 || widget.result.hasWithdrawalText)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.warningOrange.withOpacity(isDark ? 0.25 : 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    widget.result.hasWithdrawalText
                                        ? '⏱ Каренция'
                                        : '⏱ ${widget.result.withdrawalDays} дн.',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.warningOrange,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.result.drugName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimaryColor(context),
                            ),
                          ),
                          if (widget.result.drugForm.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                widget.result.drugForm,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondaryColor(context),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (widget.result.calcDrug != null)
                      AnimatedBuilder(
                        animation: _favService,
                        builder: (context, _) {
                          final isFav = _favService.isFavorite(widget.result.calcDrug!.id);
                          return IconButton(
                            icon: Icon(
                              isFav ? Icons.star_rounded : Icons.star_border_rounded,
                              color: isFav ? AppTheme.warningOrange : AppTheme.textTertiaryColor(context),
                              size: 24,
                            ),
                            onPressed: () async {
                              await _favService.toggleFavorite(widget.result.calcDrug!.id);
                            },
                            tooltip: isFav ? 'Убрать из избранного' : 'В избранное',
                          );
                        },
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Hero блок дозировки
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 14),
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.safeGreen.withOpacity(0.14) : AppTheme.safeGreenSoft,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(color: AppTheme.safeGreen.withOpacity(0.25)),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Text(
                        'РЕКОМЕНДУЕМАЯ ДОЗА',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: isDark ? AppTheme.safeGreenLight : AppTheme.safeGreenDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (widget.result.isFixedDose && widget.result.fixedDoseText.isNotEmpty)
                        Text(
                          widget.result.fixedDoseText,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppTheme.safeGreenLight : AppTheme.safeGreenDark,
                          ),
                          textAlign: TextAlign.center,
                        )
                      else
                        Text(
                          widget.result.formattedVolume,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppTheme.safeGreenLight : AppTheme.safeGreenDark,
                            letterSpacing: -0.5,
                          ),
                        ),
                      if (widget.result.note.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          widget.result.note,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryColor(context),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Параметры применения (Метод, Частота, Курс)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildParamChip(Icons.vaccines_rounded, widget.result.method),
                    if (widget.result.frequency.isNotEmpty)
                      _buildParamChip(Icons.update_rounded, widget.result.frequency),
                    if (widget.result.courseDays.isNotEmpty)
                      _buildParamChip(Icons.calendar_today_rounded, 'Курс: ${widget.result.courseDays}'),
                  ],
                ),
              ),

              // Детальная каренция
              if (widget.result.hasWithdrawalText) ...[
                Container(
                  margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.warningOrange.withOpacity(isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    border: Border.all(color: AppTheme.warningOrange.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.schedule_rounded, size: 16, color: AppTheme.warningOrange),
                          SizedBox(width: 6),
                          Text(
                            'Сроки ожидания (каренция)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.warningOrange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ...widget.result.withdrawalText.split(' | ').map((part) => Padding(
                        padding: const EdgeInsets.only(left: 22, top: 2),
                        child: Text(
                          part,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textPrimaryColor(context),
                          ),
                        ),
                      )),
                    ],
                  ),
                ),
              ],

              // Слайдер дозы
              if (hasDoseRange && widget.onDoseChanged != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Divider(color: AppTheme.dividerColor(context), height: 1),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Корректировка дозы:',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor(context)),
                          ),
                          Text(
                            '${_selectedDose.toStringAsFixed(1)} ${widget.result.doseUnit}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.safeGreen),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: AppTheme.safeGreen,
                          inactiveTrackColor: AppTheme.safeGreen.withOpacity(0.2),
                          thumbColor: AppTheme.safeGreen,
                          overlayColor: AppTheme.safeGreen.withOpacity(0.15),
                        ),
                        child: Slider(
                          value: _selectedDose.clamp(widget.result.doseMin, widget.result.doseMax),
                          min: widget.result.doseMin,
                          max: widget.result.doseMax,
                          divisions: 20,
                          onChanged: (v) {
                            setState(() => _selectedDose = v);
                            widget.onDoseChanged?.call(v);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Побочные эффекты (Аккордеон)
              if (hasSideEffects) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: InkWell(
                    onTap: () => setState(() => _showSideEffects = !_showSideEffects),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurfaceLight : AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 16, color: AppTheme.warningOrange),
                              const SizedBox(width: 8),
                              Text(
                                'Побочные эффекты (${widget.result.sideEffects.length})',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimaryColor(context),
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                _showSideEffects ? Icons.expand_less : Icons.expand_more,
                                size: 20,
                                color: AppTheme.textSecondaryColor(context),
                              ),
                            ],
                          ),
                          if (_showSideEffects) ...[
                            const SizedBox(height: 8),
                            ...widget.result.sideEffects.take(5).map((se) => Padding(
                              padding: const EdgeInsets.only(bottom: 4, left: 4),
                              child: Text(
                                '• $se',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondaryColor(context),
                                ),
                              ),
                            )),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              // Критические предупреждения
              if (hasRiskWarnings) ...[
                Container(
                  margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    border: Border.all(color: AppTheme.errorRed.withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.dangerous_rounded, color: AppTheme.errorRed, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'ПРОТИВОПОКАЗАНО!',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: AppTheme.errorRed,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...widget.result.riskWarnings.map((w) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          '• $w',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFFFFA4A4) : AppTheme.errorRed,
                          ),
                        ),
                      )),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Кнопки действий под карточкой
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (widget.onSpeak != null)
              TextButton.icon(
                onPressed: widget.onSpeak,
                icon: const Icon(Icons.volume_up_rounded, size: 20, color: AppTheme.safeGreen),
                label: const Text(
                  'Озвучить',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.safeGreen),
                ),
              ),
            if (widget.result.calcDrug != null && widget.animalName != null)
              TextButton.icon(
                onPressed: _savedToHistory
                    ? null
                    : () async {
                        await _histService.addCalculation(
                          drugId: widget.result.calcDrug!.id,
                          drugName: widget.result.drugName,
                          inn: widget.result.calcDrug!.inn,
                          animal: widget.animalName!,
                          weightKg: widget.weightKg ?? 0,
                          dosePerKg: widget.result.dosePerKg,
                          volumeMl: widget.result.volume,
                          method: widget.result.selectedMethodName.isNotEmpty
                              ? widget.result.selectedMethodName
                              : widget.result.method,
                          frequency: widget.result.frequency,
                        );
                        setState(() => _savedToHistory = true);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✓ Сохранено в историю'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                icon: Icon(
                  _savedToHistory ? Icons.check_rounded : Icons.bookmark_add_outlined,
                  size: 18,
                  color: _savedToHistory ? AppTheme.safeGreen : AppTheme.textSecondaryColor(context),
                ),
                label: Text(
                  _savedToHistory ? 'Сохранено' : 'В историю',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _savedToHistory ? AppTheme.safeGreen : AppTheme.textSecondaryColor(context),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildParamChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.isDark(context) ? AppTheme.darkSurfaceLight : AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondaryColor(context)),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfo() {
    return Container(
      width: double.infinity,
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
            widget.result.drugName,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          if (widget.result.drugForm.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              widget.result.drugForm,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor(context)),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.infoBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppTheme.infoBlue, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Расчёт дозировки производится по инструкции препарата',
                    style: TextStyle(fontSize: 13, color: AppTheme.textPrimaryColor(context)),
                  ),
                ),
              ],
            ),
          ),
          if (widget.result.note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              widget.result.note,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor(context)),
            ),
          ],
        ],
      ),
    );
  }
}
