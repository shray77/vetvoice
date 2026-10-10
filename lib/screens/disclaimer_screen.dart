import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_theme.dart';
import 'home_screen.dart';

/// DisclaimerScreen — модальный дисклеймер при первом запуске
class DisclaimerScreen extends StatefulWidget {
  const DisclaimerScreen({super.key});

  @override
  State<DisclaimerScreen> createState() => _DisclaimerScreenState();
}

class _DisclaimerScreenState extends State<DisclaimerScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(AppTheme.paddingMedium),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor(context),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    border: Border.all(color: AppTheme.warningOrange.withOpacity(0.35)),
                    boxShadow: AppTheme.cardShadow(context),
                  ),
                  child: Text(
                    'Приложение носит вспомогательный справочный характер.\n\n'
                    'Дозировки, кратности и противопоказания основаны на '
                    'официальном Государственном реестре ЛС и инструкциях производителей.\n\n'
                    'Окончательное решение о схеме лечения, совместимости препаратов '
                    'и дозировке принимает ветеринарный врач на основании клинического статуса пациента.\n\n'
                    'Разработчик не несёт ответственности за нецелевое или ошибочное применение лекарственных средств.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('disclaimer_accepted', true);
                      if (mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const HomeScreen(),
                          ),
                        );
                      }
                    },
                    child: const Text('Понятно, приступить к работе'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
