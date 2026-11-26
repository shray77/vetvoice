// MoreScreen — вкладка «Ещё» (Фаза 2, v1.18.0).
//
// Второстепенные направления, которым не место в 2×3 сетке «Главной»:
// избранное, история расчётов, неофициальные протоколы, настройки.
// Ряды — в стиле _buildNavButton из home (иконка в тонированном квадрате,
// подпись + подзаголовок, шеврон), высота ≥48dp.
//
// «Неофициальные протоколы» ранее не были доступны из UI вовсе (экран
// UnofficialRecordsScreen существовал, но не пушился ниоткуда) — здесь
// появляется легальный вход с guard'ом на неготовую базу.
import 'dart:async'; // unawaited

import 'package:flutter/material.dart';
import '../models/unofficial_protocol.dart';
import '../providers/vet_provider.dart';
import '../services/drug_loader_service.dart';
import '../utils/app_theme.dart';
import '../widgets/common/app_scaffold.dart';
import '../widgets/common/haptics.dart';
import '../widgets/common/skeleton.dart';
import 'favorites_screen.dart';
import 'history_screen.dart';
import 'interactions_checker_screen.dart';
import 'settings_screen.dart';
import 'unofficial_protocols_screen.dart';
import '../theme/ds.dart';

class MoreScreen extends StatefulWidget {
  /// VV-027 (ревью 26.11.2026): колбэк шелла — после выбора препарата
  /// в «Избранном» открыть вкладку «Калькулятор».
  final VoidCallback? onOpenCalculator;

  const MoreScreen({super.key, this.onOpenCalculator});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  final VetProvider _vetProvider = VetProvider();

  /// v1.18.1: фоновая загрузка secondary-баз завершена. Если после этого
  /// базы нет — показываем «Не удалось загрузить», а не вечную «Загрузка…».
  bool _extendedDone = false;

  /// B6 (аудит 26.11.2026): локальная копия базы неофициальных протоколов —
  /// «Повторить» перечитывает её тем же путём, которым грузит провайдер
  /// (DrugLoaderService.parseExtended в _loadExtendedDatabases), и ряд
  /// оживает без перезапуска приложения.
  UnofficialProtocolDatabase? _unofficialDb;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    // Неофициальные протоколы парсятся фоном — включить ряд, когда готовы.
    unawaited(_vetProvider.extendedReady.then((_) {
      if (mounted) {
        setState(() {
          _extendedDone = true;
          _unofficialDb = _vetProvider.unofficialDatabase;
        });
      }
    }));
  }

  UnofficialProtocolDatabase? get _unofficial =>
      _unofficialDb ?? _vetProvider.unofficialDatabase;

  /// B6: «Повторить» для неготовой базы — тот же путь, которым экраны
  /// стартуют загрузку (provider.initialize()), плюс повторный парсинг
  /// extended-баз: у синглтона провайдера СТАДИЯ 2 выполняется один раз,
  /// поэтому результат перепарса держим локально.
  Future<void> _retryUnofficialLoad() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await _vetProvider.initialize();
      final ext = await DrugLoaderService.parseExtended();
      if (ext?.unofficialDatabase != null) {
        _unofficialDb = ext!.unofficialDatabase;
      }
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  void _push(Widget page) {
    Navigator.push(context, DsRoute(builder: (_) => page));
  }

  Widget _row({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool loading = false,
    VoidCallback? onRetry,
  }) {
    final disabled = onTap == null;
    final effectiveColor = disabled ? AppTheme.textTertiary : color;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.paddingSmall),
      child: Opacity(
        opacity: disabled ? 0.5 : 1.0,
        child: Material(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: InkWell(
            // Фаза 3: хаптик на рядах меню (единая точка входа AppHaptics).
            onTap: onTap == null ? null : () { AppHaptics.tap(); onTap!(); },
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            child: Container(
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.paddingSmall + 6,
                vertical: AppTheme.paddingSmall + 2,
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        loading
                            ? const SkeletonBox(width: 150, height: 11)
                            : Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                      ],
                    ),
                  ),
                  // B6: у недоступного ряда шеврон не рисуем (он врал,
                  // будто ряд кликабелен); если есть что повторять —
                  // кнопка «Повторить».
                  _rowTrailing(disabled, onRetry),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rowTrailing(bool disabled, VoidCallback? onRetry) {
    if (!disabled) {
      return Icon(Icons.chevron_right_rounded,
          size: 22, color: AppTheme.textTertiary);
    }
    if (onRetry == null) return const SizedBox.shrink();
    return TextButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh, size: 18),
      label: const Text('Повторить'),
    );
  }

  @override
  Widget build(BuildContext context) {
    // v1.18.1: зависимость от Theme — при смене темы вкладка «Ещё»
    // перестраивается (контент на статических AppTheme-геттерах, см. MainShell).
    Theme.of(context);

    return AppScaffold(
      title: 'Ещё',
      automaticallyImplyLeading: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.paddingMedium,
          AppTheme.paddingSmall,
          AppTheme.paddingMedium,
          AppTheme.paddingMedium,
        ),
        children: [
          _row(
            icon: Icons.star_rounded,
            color: AppTheme.warningOrange,
            title: 'Избранное',
            subtitle: 'Отмеченные препараты',
            // VV-027 (ревью 26.11.2026): выбор в «Избранном» раньше терялся —
            // Navigator.pop(context, drug) никто не слушал. Теперь препарат
            // подставляется в калькулятор (provider.selectDrug) и шелл
            // открывает вкладку «Калькулятор».
            onTap: () async {
              final drug = await Navigator.of(context).push<FavoritesScreen>(
                MaterialPageRoute<FavoritesScreen>(
                  builder: (_) => const FavoritesScreen(),
                ),
              );
              if (drug != null) {
                _vetProvider.selectDrug(drug);
                widget.onOpenCalculator?.call();
              }
            },
          ),
          _row(
            icon: Icons.history_rounded,
            color: AppTheme.textSecondary,
            title: 'История расчётов',
            subtitle: 'Последние подборы доз',
            onTap: () => _push(const HistoryScreen()),
          ),
          _row(
            icon: Icons.medical_services_outlined,
            color: AppTheme.maleBlue,
            title: 'Неофициальные протоколы',
            // v1.18.1: различаем «ещё грузится» и «не загрузилось» —
            // вечная «Загрузка…» выглядела как зависание (полевой отчёт).
            // Фаза 3: на «ещё грузится» — скелетон-полоска вместо текста.
            // B6: при ошибке — «Повторить» тем же путём, что и старт
            // загрузки; ряд больше не мёртвый.
            loading: _unofficial == null && (!_extendedDone || _retrying),
            subtitle: _unofficial != null
                ? 'Опыт практикующих врачей'
                : (_extendedDone ? 'Не удалось загрузить' : 'Загрузка…'),
            onTap: _unofficial != null
                ? () => _push(UnofficialRecordsScreen(db: _unofficial!))
                : null,
            onRetry: _extendedDone ? _retryUnofficialLoad : null,
          ),
          // VV-028 (ревью 26.11.2026): экран проверок 2+ препаратов был
          // доступен только из golden-тестов — добавляем легальный вход.
          _row(
            icon: Icons.compare_arrows_rounded,
            color: AppTheme.warningOrange,
            title: 'Проверка 2+ препаратов',
            subtitle: 'Взаимодействия в комбинациях',
            onTap: () =>
                _push(InteractionsCheckerScreen(vetProvider: _vetProvider)),
          ),
          _row(
            icon: Icons.settings_outlined,
            color: AppTheme.textSecondary,
            title: 'Настройки',
            subtitle: 'Тема, голос, данные',
            onTap: () => _push(const SettingsScreen()),
          ),
        ],
      ),
    );
  }
}
