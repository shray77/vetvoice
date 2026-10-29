import 'package:flutter/material.dart';
import '../providers/vet_provider.dart';
import '../utils/app_theme.dart';
import '../theme/ds.dart';
import 'interaction_warning.dart';
import '../services/favorites_service.dart';  // 🆕
import '../services/history_service.dart';    // 🆕
import 'vaccine_card.dart';  // 🆕

/// Карточка результата с возможностью корректировки дозы
class ResultCard extends StatefulWidget {
  final DoseResult result;
  final VoidCallback? onSpeak;
  final Function(double)? onDoseChanged;
  final String? animalName;       // 🆕 для истории
  final double? weightKg;         // 🆕 для истории

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
  final FavoritesService _favService = FavoritesService();  // 🆕
  final HistoryService _histService = HistoryService();     // 🆕
  bool _savedToHistory = false;  // 🆕

  @override
  void initState() {
    super.initState();
    _selectedDose = widget.result.dosePerKg;
    _favService.init();   // 🆕
    _histService.init();  // 🆕
  }

  @override
  void didUpdateWidget(ResultCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result.dosePerKg != widget.result.dosePerKg) {
      _selectedDose = widget.result.dosePerKg;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.result.hasError) return _buildError();
    if (!widget.result.hasResult) return _buildPlaceholder();

    // 🆕 Если препарат — вакцина, показываем VaccineCard
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
            drugName: drug.name,
            drugInn: drug.inn,
            vaccine: drug.vaccineSpecific!,
            category: drug.category,
          ),
        ],
      );
    }

    if (widget.result.hasDosage) return _buildCalculated();
    return _buildInfo();
  }

  /// 🆕 Кнопка избранного — ⭐ над карточкой
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
              isFav ? Icons.star : Icons.star_border,
              color: isFav ? AppTheme.warningOrange : AppTheme.textSecondary,
              size: 20,
            ),
            label: Text(
              isFav ? 'В избранном' : 'В избранное',
              style: TextStyle(
                fontSize: 13,
                color: isFav ? AppTheme.warningOrange : AppTheme.textSecondary,
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
      padding: const EdgeInsets.all(AppTheme.paddingLarge),
      decoration: BoxDecoration(
        // v1.16: theme-aware — белый остров в тёмной теме
        color: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkSurfaceLight
            : AppTheme.backgroundGray,
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
      ),
      child: Column(
        children: [
          Icon(Icons.medication_outlined, size: 48, color: AppTheme.textTertiary),
          const SizedBox(height: 12),
          Text(
            'Выберите препарат для расчёта',
            style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    // Task 194: тёмная тема — errorRed (светлый токен DS) на графите
    // давал ~2:1; баннер переводится на тёмную семантику DsDark.red.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final redFg = isDark ? DsDark.red : DsLight.red;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.paddingLarge),
      decoration: BoxDecoration(
        color: redFg.withOpacity(isDark ? 0.14 : 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        border: Border.all(color: redFg.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: redFg, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.result.error,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: redFg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculated() {
    final hasRiskWarnings = widget.result.hasRiskWarnings;
    final hasWarnings = widget.result.hasContraindications;
    final hasInteractions = widget.result.hasInteractions;
    final hasSideEffects = widget.result.hasSideEffects;
    final hasDoseRange = widget.result.hasDoseRange;
    // Task 194: тёмная тема основной карточки — рамка safeGreen и доза
    // (светлые токены, ~2.5:1 на графите) переводятся на DsDark.accent;
    // каренция и подписи — на тёплую семантику DS.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? DsDark.accent : DsLight.accent;
    final faint = isDark ? DsDark.faint : Colors.grey.shade600;
    final orangeFg = isDark ? DsDark.orange : DsLight.orange;
    final redFg = isDark ? DsDark.red : DsLight.red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // === НОВОЕ: Взаимодействия (самое важное!) ===
        if (hasInteractions)
          InteractionWarning(interactions: widget.result.interactions),

        // Основная карточка
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppTheme.paddingLarge),
          decoration: BoxDecoration(
            color: hasRiskWarnings
                ? redFg.withOpacity(isDark ? 0.12 : 0.05)
                : Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkSurface
                    : AppTheme.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
            border: Border.all(
              color: hasRiskWarnings
                  ? redFg.withOpacity(0.3)
                  : accent.withOpacity(isDark ? 0.35 : 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок с названием + кнопка избранного
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.result.drugName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // 🆕 Кнопка избранного
                  if (widget.result.calcDrug != null)
                    AnimatedBuilder(
                      animation: _favService,
                      builder: (context, _) {
                        final isFav = _favService.isFavorite(widget.result.calcDrug!.id);
                        return IconButton(
                          icon: Icon(
                            isFav ? Icons.star : Icons.star_border,
                            color: isFav ? AppTheme.warningOrange : AppTheme.textTertiary,
                            size: 24,
                          ),
                          onPressed: () async {
                            await _favService.toggleFavorite(widget.result.calcDrug!.id);
                          },
                          tooltip: isFav ? 'Убрать из избранного' : 'Добавить в избранное',
                          visualDensity: VisualDensity.compact,
                        );
                      },
                    ),
                  if (widget.result.withdrawalDays > 0 || widget.result.hasWithdrawalText)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        // Task 194: тёмная тема — оранжевый чип каренции
                        color: isDark
                            ? DsDark.orange.withOpacity(0.18)
                            : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.result.hasWithdrawalText
                            ? '⏱ Каренция'
                            : '⏱ ${widget.result.withdrawalDays} дн.',
                        style: TextStyle(
                          fontSize: 12,
                          color: orangeFg,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              
              // Форма выпуска
              if (widget.result.drugForm.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  widget.result.drugForm,
                  style: TextStyle(
                    fontSize: 14,
                    color: faint,
                  ),
                ),
              ],
              
              const SizedBox(height: 16),
              
              // Дозировка (главное!)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: accent.withOpacity(isDark ? 0.12 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (widget.result.isFixedDose && widget.result.fixedDoseText.isNotEmpty)
                          Flexible(
                            child: Text(
                              widget.result.fixedDoseText,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: accent,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          Text(
                            widget.result.formattedVolume,
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: accent,
                            ),
                          ),
                      ],
                    ),
                    if (widget.result.note.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.result.note,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              
              // Метод и частота
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.gps_fixed, size: 16, color: faint),
                  const SizedBox(width: 4),
                  Text(
                    widget.result.method,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              if (widget.result.frequency.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: faint),
                    const SizedBox(width: 4),
                    Text(
                      widget.result.frequency,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ],
              if (widget.result.courseDays.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: faint),
                    const SizedBox(width: 4),
                    Text(
                      'Курс: ${widget.result.courseDays}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ],

              // Детальная каренция (мясо/молоко/яйца по видам)
              if (widget.result.hasWithdrawalText) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    // Task 194: тёмная тема — оранжевый остров shade50/200
                    // оставался светлым пятном на графите.
                    color: isDark
                        ? DsDark.orange.withOpacity(0.14)
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? DsDark.orange.withOpacity(0.35)
                          : Colors.orange.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 16, color: orangeFg),
                          const SizedBox(width: 6),
                          Text(
                            'Сроки ожидания (каренция)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: orangeFg,
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
                            color: isDark ? DsDark.text : Colors.grey.shade800,
                          ),
                        ),
                      )),
                    ],
                  ),
                ),
              ],

              // Слайдер дозы (если есть диапазон)
              if (hasDoseRange && widget.onDoseChanged != null) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Корректировка дозы:',
                  style: TextStyle(
                    fontSize: 12,
                    color: faint,
                  ),
                ),
                Slider(
                  value: _selectedDose,
                  min: widget.result.doseMin,
                  max: widget.result.doseMax,
                  divisions: 20,
                  label: '${_selectedDose.toStringAsFixed(1)} ${widget.result.doseUnit}',
                  onChanged: (v) {
                    setState(() => _selectedDose = v);
                    widget.onDoseChanged?.call(v);
                  },
                ),
                Text(
                  '${widget.result.doseMin}-${widget.result.doseMax} ${widget.result.doseUnit}',
                  style: TextStyle(fontSize: 12, color: faint),
                  textAlign: TextAlign.center,
                ),
              ],

              // === НОВОЕ: Побочные эффекты ===
              if (hasSideEffects) ...[
                const SizedBox(height: 16),
                // Task 194: побочные эффекты — тёмная тема. Раньше
                // amber.shade50-остров оставался светлым в графите,
                // буллеты без цвета наследовали светлый текст темы
                // (свет-на-свете), заголовок жил с дефолтными 14/w500
                // мимо DS-типографики.
                Builder(builder: (context) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  final amberFg = isDark ? DsDark.amber : DsLight.amber;
                  final amberBg =
                      isDark ? DsDark.amber.withOpacity(0.14) : Colors.amber.shade50;
                  return InkWell(
                  onTap: () => setState(() => _showSideEffects = !_showSideEffects),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: amberBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber, size: 16, color: amberFg),
                        const SizedBox(width: 8),
                        Text(
                          'Побочные эффекты (${widget.result.sideEffects.length})',
                          style: TextStyle(
                            color: amberFg,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          _showSideEffects ? Icons.expand_less : Icons.expand_more,
                          color: amberFg,
                        ),
                      ],
                    ),
                  ),
                );
                }),
                if (_showSideEffects) ...[
                  const SizedBox(height: 8),
                  Builder(builder: (context) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    final amberFg = isDark ? DsDark.amber : DsLight.amber;
                    final amberBg =
                        isDark ? DsDark.amber.withOpacity(0.14) : Colors.amber.shade50;
                    final bulletColor = isDark ? DsDark.text : DsLight.muted;
                    return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: amberBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: widget.result.sideEffects.take(5).map((se) => 
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('• $se',
                              style: TextStyle(fontSize: 12, color: bulletColor)),
                        ),
                      ).toList(),
                    ),
                  );
                  }),
                ],
              ],

              // КРИТИЧЕСКИЕ предупреждения
              // Task 194: тёмная тема — красный errorRed на графите
              // давал ~2:1; буллеты без цвета — свет-на-свете.
              if (hasRiskWarnings) ...[
                const SizedBox(height: 16),
                Builder(builder: (context) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  final redFg = isDark ? DsDark.red : DsLight.red;
                  final redBg = isDark
                      ? DsDark.red.withOpacity(0.16)
                      : DsLight.red.withOpacity(0.1);
                  final bulletColor = isDark ? DsDark.text : DsLight.muted;
                  return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: redBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: redFg.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.dangerous, color: redFg),
                          const SizedBox(width: 8),
                          Text(
                            'ЗАПРЕЩЕНО!',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: redFg,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...widget.result.riskWarnings.map((w) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $w',
                            style: TextStyle(fontSize: 13, color: bulletColor)),
                      )),
                    ],
                  ),
                );
                }),
              ],

              // Обычные предупреждения
              // Task 194: меры предосторожности — тёмная тема (симметрично
              // побочным эффектам): раньше orange.shade50-остров + буллеты
              // без цвета (свет-на-свете в графите).
              if (hasWarnings && !hasRiskWarnings) ...[
                const SizedBox(height: 12),
                Builder(builder: (context) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  final orangeFg = isDark ? DsDark.orange : DsLight.orange;
                  final orangeBg = isDark
                      ? DsDark.orange.withOpacity(0.14)
                      : Colors.orange.shade50;
                  final bulletColor = isDark ? DsDark.text : DsLight.muted;
                  return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: orangeBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: orangeFg),
                          const SizedBox(width: 4),
                          Text(
                            'Меры предосторожности',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: orangeFg,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ...widget.result.contraindications.take(3).map((c) => 
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text('• $c',
                              style: TextStyle(fontSize: 12, color: bulletColor)),
                        ),
                      ),
                    ],
                  ),
                );
                }),
              ],
            ],
          ),
        ),

        // Кнопка озвучивания
        if (widget.onSpeak != null) ...[
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: widget.onSpeak,
              icon: const Icon(Icons.volume_up),
              label: const Text('Озвучить результат'),
            ),
          ),
        ],

        // v1.16.3: кнопка «Сохранить в историю» вынесена ИЗ onSpeak-блока —
        // показывается всегда при наличии препарата/животного, независимо
        // от того, передан ли колбэк озвучки.
        if (widget.result.calcDrug != null && widget.animalName != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
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
                        setState(() {
                          _savedToHistory = true;
                        });
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
                  _savedToHistory ? Icons.check : Icons.history_edu,
                  size: 18,
                  color: _savedToHistory
                      ? accent
                      : AppTheme.textSecondary,
                ),
                label: Text(
                  _savedToHistory ? 'Сохранено' : 'В историю',
                  style: TextStyle(
                    fontSize: 13,
                    color: _savedToHistory
                        ? accent
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildInfo() {
    // Task 194: тёмная тема инфо-блока — рамка safeGreen (светлый токен,
    // ~2:1 на графите) и синий shade50-остров переводятся на DS-семантику.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? DsDark.accent : DsLight.accent;
    final blueFg = isDark ? DsDark.blue : DsLight.blue;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.paddingLarge),
      decoration: BoxDecoration(
        // v1.16: theme-aware
        color: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkSurface
            : AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        border: Border.all(color: accent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.result.drugName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (widget.result.drugForm.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              widget.result.drugForm,
              style: TextStyle(color: isDark ? DsDark.faint : Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? DsDark.blue.withOpacity(0.14) : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: blueFg),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Перепроверьте дозу и объём вручную по официальной инструкции препарата',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          if (widget.result.note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              widget.result.note,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
