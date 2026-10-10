import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_theme.dart';
import 'home_screen.dart';
import 'terms_screen.dart';

/// DisclaimerScreen — юридический гейт при первом запуске.
///
/// Показывается до любого функционала, пока пользователь не примет условия
/// (флаг `disclaimer_accepted` в SharedPreferences ставится в main.dart и тут).
/// Полный текст условий — TermsScreen (кнопка под карточкой).
class DisclaimerScreen extends StatelessWidget {
  const DisclaimerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBackground : AppTheme.backgroundGray;
    final card = isDark ? AppTheme.darkSurface : AppTheme.white;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
    final borderColor = AppTheme.warningOrange.withOpacity(isDark ? 0.45 : 0.35);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.warningOrange.withOpacity(isDark ? 0.25 : 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.medical_information_rounded,
                    color: AppTheme.warningOrange,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Внимание ветеринарного специалиста',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(AppTheme.paddingMedium),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    border: Border.all(color: borderColor),
                  ),
                  child: Text(
                    'Приложение — информационно-справочный сервис, предоставляется '
                    '«как есть», без гарантий полноты, точности и актуальности.\n\n'
                    'Материалы приложения не являются ветеринарной консультацией, '
                    'диагнозом или назначением. Консультируйтесь с ветеринарным врачом, '
                    'даже если вы сами ветеринарный врач.\n\n'
                    'Любые автоматические расчёты, математические модели и калькуляторы '
                    'дозировок предоставлены исключительно для ознакомления и проверки '
                    'гипотез: ошибка возможна и в самом калькуляторе — из-за опечатки '
                    'в формуле или данных. Перепроверяйте все результаты вычислений '
                    'вручную по официальным инструкциям к препаратам перед любым '
                    'клиническим применением.\n\n'
                    'Разработчик не несёт ответственности за вред животным, людям или '
                    'имуществу, возникший в результате использования или неиспользования '
                    'приложения, — в максимальной степени, допускаемой применимым правом.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TermsScreen()),
                    );
                  },
                  icon: const Icon(Icons.gavel_outlined, size: 18),
                  label: const Text(
                    'Полные условия использования и дисклеймер',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('disclaimer_accepted', true);
                    if (context.mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                      );
                    }
                  },
                  child: const Text('Понятно, приступить к работе'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
