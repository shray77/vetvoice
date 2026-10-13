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
import '../providers/vet_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/common/app_scaffold.dart';
import 'favorites_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'unofficial_protocols_screen.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  final VetProvider _vetProvider = VetProvider();

  /// v1.18.1: фоновая загрузка secondary-баз завершена. Если после этого
  /// базы нет — показываем «Не удалось загрузить», а не вечную «Загрузка…».
  bool _extendedDone = false;

  @override
  void initState() {
    super.initState();
    // Неофициальные протоколы парсятся фоном — включить ряд, когда готовы.
    unawaited(_vetProvider.extendedReady.then((_) {
      if (mounted) {
        setState(() => _extendedDone = true);
      }
    }));
  }

  void _push(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Widget _row({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
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
            onTap: onTap,
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
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      size: 22, color: AppTheme.textTertiary),
                ],
              ),
            ),
          ),
        ),
      ),
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
            onTap: () => _push(const FavoritesScreen()),
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
            subtitle: _vetProvider.unofficialDatabase != null
                ? 'Опыт практикующих врачей'
                : (_extendedDone ? 'Не удалось загрузить' : 'Загрузка…'),
            onTap: _vetProvider.unofficialDatabase != null
                ? () => _push(UnofficialRecordsScreen(
                      db: _vetProvider.unofficialDatabase!,
                    ))
                : null,
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
