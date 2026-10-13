// HomeGridScreen — вкладка «Главная»: сетка инструментов 2×3 (Фаза 2, v1.18.0).
//
// Структура (сверху вниз):
//   - Шапка: бренд + статус-чипы (версия базы, сеть) — StatusChip из Фазы 1;
//   - «Безопасность» — safety-кластер: Совместимость + Каренция. Самое
//     критичное на приёме (не убить животное несовместимой смесью / не
//     продать молоко с антибиотиком) вынесено первой секцией;
//   - «Инструменты» — Поиск / Протоколы / Инфузии / Болезни (второй ряд 2×2);
//   - Подсказка голосового сценария.
//
// Инфузии и Болезни зависят от вторичных баз (extendedReady): пока грузятся —
// плитки в disabled-состоянии с подписью «Загрузка…» (как раньше чипы
// просто не появлялись — теперь пользователь видит, что функционал есть).
//
// КОНТРАКТЫ: VetProvider не трогается — только чтение готовых геттеров.
// Выбор препарата из протокола/поиска подставляет животное и препарат в
// калькулятор и переключает вкладку (onOpenCalculator), повторяя логику
// home v1.16.4 (selectAnimalFromSpecies ДО selectDrug).
import 'dart:async'; // unawaited

import 'package:flutter/material.dart';
import '../providers/vet_provider.dart';
import '../services/drug_loader_service.dart';
import '../services/theme_service.dart';
import '../utils/app_theme.dart';
import '../widgets/common/haptics.dart';
import '../widgets/common/skeleton.dart';
import '../widgets/common/status_chip.dart';
import '../widgets/compatibility_checker.dart';
import 'diseases_screen.dart';
import 'fluid_therapy_screen.dart';
import 'symptom_search_screen.dart';
import 'treatment_protocols_screen.dart';
import 'withdrawal_calculator_screen.dart';

class HomeGridScreen extends StatefulWidget {
  /// Переключить shell на вкладку «Калькулятор» (после выбора препарата).
  final VoidCallback? onOpenCalculator;

  const HomeGridScreen({super.key, this.onOpenCalculator});

  @override
  State<HomeGridScreen> createState() => _HomeGridScreenState();
}

class _HomeGridScreenState extends State<HomeGridScreen> {
  final VetProvider _vetProvider = VetProvider();
  final ThemeService _themeService = ThemeService();

  /// Честный статус сети (DNS-lookup), а не источник загрузки баз.
  /// null = проверка ещё идёт.
  bool? _online;

  @override
  void initState() {
    super.initState();
    // Вторичные базы (инфузии/болезни) парсятся фоном — дорисовать плитки.
    unawaited(_vetProvider.extendedReady.then((_) {
      if (mounted) setState(() {});
    }));
    // v1.18.1: чип сети больше не привязан к «откуда загружены базы».
    // Старт из дискового кеша — норма офлайн-first (мгновенный старт),
    // а не «приложение считает, что оно оффлайн» (полевой отчёт v1.18.0:
    // пользователь с работающим Wi-Fi видел «Оффлайн» и подозревал багу).
    unawaited(DrugLoaderService.isNetworkAvailable().then((v) {
      if (mounted) setState(() => _online = v);
    }));
  }

  // -------------------------------------------------------------------
  // Переходы (дублируют проверенные маршруты из home v1.16.x)
  // -------------------------------------------------------------------

  void _openCompatibility() {
    final db = _vetProvider.interactionDatabase;
    if (db == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.dividerGray,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              CompatibilityChecker(
                interactionDb: db,
                allDrugs: _vetProvider.allDrugs,
                onClose: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openProtocols() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TreatmentProtocolsScreen(
          vetProvider: _vetProvider,
          // v1.16.4-контракт: вид подставляем ДО препарата
          // (selectAnimalFromSpecies не сбрасывает препарат, selectAnimal —
          // сбрасывает). После выбора — pop протоколов и вкладка калькулятора.
          onDrugSelected: (drug, species) {
            _vetProvider.selectAnimalFromSpecies(species);
            _vetProvider.selectDrug(drug);
            // v1.18.1: БЕЗ pop здесь — протоколы делают свой единственный pop
            // ПОСЛЕ колбэка (см. комментарий в _ProtocolCard). Второй pop
            // отсюда выталкивал MainShell (единственный маршрут под
            // протоколами) → пустой стек → чёрный экран. Тот же класс бага,
            // что v1.16.1, только через колбэк (полевой отчёт v1.18.0).
            widget.onOpenCalculator?.call();
          },
        ),
      ),
    );
  }

  void _openSymptomSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SymptomSearchScreen(
          onDrugSelected: (drug) {
            _vetProvider.selectDrug(drug);
            // v1.18.1: pop делает сам SymptomSearchScreen после колбэка
            // (onTap → onDrugSelected → Navigator.pop). Второй pop отсюда
            // выталкивал MainShell → чёрный экран (полевой отчёт v1.18.0).
            widget.onOpenCalculator?.call();
          },
        ),
      ),
    );
  }

  void _openDiseases() {
    final db = _vetProvider.diseaseDatabase;
    if (db == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DiseasesScreen(
          database: db,
          treatmentDatabase: _vetProvider.treatmentProtocolDatabase,
          selectedAnimal: _vetProvider.selectedAnimal?.name,
        ),
      ),
    );
  }

  void _openWithdrawal() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            WithdrawalCalculatorScreen(vetProvider: _vetProvider),
      ),
    );
  }

  void _openFluidTherapy() {
    final db = _vetProvider.fluidTherapyDatabase;
    if (db == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FluidTherapyScreen(db: db)),
    );
  }

  // -------------------------------------------------------------------
  // UI
  // -------------------------------------------------------------------

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 4,
        top: AppTheme.paddingMedium,
        bottom: AppTheme.paddingSmall,
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppTheme.textTertiary,
        ),
      ),
    );
  }

  /// Плитка инструмента. [outlined] — safety-вариант с контуром цвета риска.
  /// [loading] — база ещё парсится: вместо подписи — скелетон-полоска
  /// (Фаза 3: disabled-плитка с «Загрузка…» не показывала форму будущего
  /// контента; скелетон читается как «здесь скоро будет живое»).
  Widget _tile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool enabled = true,
    bool outlined = false,
    bool loading = false,
  }) {
    final disabled = !enabled || onTap == null;
    final effectiveColor = disabled ? AppTheme.textTertiary : color;

    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: Material(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: InkWell(
          // Фаза 3: хаптик на плитках (одна точка входа — AppHaptics).
          onTap: disabled ? null : () { AppHaptics.tap(); onTap!(); },
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: Container(
            height: 76,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.paddingSmall + 4,
              vertical: AppTheme.paddingSmall,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: outlined
                  ? Border.all(color: effectiveColor.withAlpha(90), width: 1.2)
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: effectiveColor.withAlpha(28),
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Icon(icon, size: 22, color: effectiveColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      loading
                          ? const SkeletonBox(width: 92, height: 11)
                          : Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textTertiary,
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // v1.18.1: зависимость от Theme — при смене темы вкладка перестраивается
    // (весь контент на статических AppTheme-геттерах, см. MainShell).
    Theme.of(context);
    final dbInfo = _themeService.databaseInfo;
    final infusionsReady = _vetProvider.fluidTherapyDatabase != null;
    final diseasesReady = _vetProvider.diseasesCount > 0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.paddingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Шапка ---
              Text(
                'VetVoice',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeTitle,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Инструменты ветврача на приёме',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeSmall,
                  color: AppTheme.textTertiary,
                ),
              ),
              const SizedBox(height: AppTheme.paddingSmall),
              Row(
                children: [
                  Expanded(
                    child: StatusChip(
                      label: dbInfo ?? 'База загружается…',
                      icon: Icons.storage_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Оффлайн — neutral, а не warning: офлайн-first по дизайну,
                  // базы всегда под рукой из кеша/assets.
                  StatusChip(
                    label: _online == null
                        ? 'Сеть…'
                        : (_online! ? 'Онлайн' : 'Оффлайн'),
                    severity: _online == true
                        ? StatusSeverity.success
                        : StatusSeverity.neutral,
                    icon: _online == false
                        ? Icons.wifi_off_rounded
                        : Icons.wifi_rounded,
                  ),
                ],
              ),

              // --- Safety-кластер ---
              _sectionLabel('Безопасность'),
              Row(
                children: [
                  Expanded(
                    child: _tile(
                      icon: Icons.compare_arrows_rounded,
                      color: AppTheme.warningOrange,
                      title: 'Совместимость',
                      subtitle: 'Проверка сочетаний',
                      onTap: _openCompatibility,
                      outlined: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _tile(
                      icon: Icons.schedule_rounded,
                      color: AppTheme.errorRed,
                      title: 'Каренция',
                      subtitle: 'Молоко / мясо / яйца',
                      onTap: _openWithdrawal,
                      outlined: true,
                    ),
                  ),
                ],
              ),

              // --- Инструменты (2×2) ---
              _sectionLabel('Инструменты'),
              Row(
                children: [
                  Expanded(
                    child: _tile(
                      icon: Icons.search_rounded,
                      color: AppTheme.safeGreen,
                      title: 'Поиск',
                      subtitle: 'Симптомы → препараты',
                      onTap: _openSymptomSearch,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _tile(
                      icon: Icons.medical_information_outlined,
                      color: AppTheme.maleBlue,
                      title: 'Протоколы',
                      subtitle: '124 схемы лечения',
                      onTap: _openProtocols,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _tile(
                      icon: Icons.water_drop_rounded,
                      color: AppTheme.maleBlue,
                      title: 'Инфузии',
                      subtitle: 'Растворы и скорости',
                      loading: !infusionsReady,
                      onTap: infusionsReady ? _openFluidTherapy : null,
                      enabled: infusionsReady,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _tile(
                      icon: Icons.coronavirus_rounded,
                      color: AppTheme.safeGreen,
                      title: 'Болезни',
                      subtitle: '${_vetProvider.diseasesCount} в справочнике',
                      loading: !diseasesReady,
                      onTap: diseasesReady ? _openDiseases : null,
                      enabled: diseasesReady,
                    ),
                  ),
                ],
              ),

              // --- Голосовая подсказка ---
              const SizedBox(height: AppTheme.paddingMedium),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.paddingSmall + 6),
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusMedium),
                  border:
                      Border.all(color: AppTheme.safeGreen.withAlpha(60)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.mic_rounded,
                        size: 20, color: AppTheme.safeGreen),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Голосом на калькуляторе: «собака 15 килограмм энрофлоксацин»',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
