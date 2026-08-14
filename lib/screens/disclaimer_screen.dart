// DisclaimerScreen — модальный дисклеймер при первом запуске.
//
// Показывается один раз. После нажатия «Понятно» — сохраняет флаг
// в SharedPreferences и больше не появляется.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_theme.dart';
import 'home_screen.dart';

class DisclaimerScreen extends StatefulWidget {
  const DisclaimerScreen({super.key});

  @override
  State<DisclaimerScreen> createState() => _DisclaimerScreenState();
}

class _DisclaimerScreenState extends State<DisclaimerScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('⚠️', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 24),
              Text(
                'Внимание!',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.warningOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  border: Border.all(
                      color: AppTheme.warningOrange.withOpacity(0.3)),
                ),
                child: const Text(
                  'Приложение носит справочный характер.\n\n'
                  'Дозировки и противопоказания основаны на '
                  'общедоступных источниках (государственный реестр ЛС, '
                  'инструкции производителей).\n\n'
                  'Окончательное решение о применении препарата '
                  'и его дозировке принимает ветеринарный врач '
                  'на основании клинической картины.\n\n'
                  'Разработчик не несёт ответственности за '
                  'последствия неправильного применения препаратов.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 32),
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
                  child: const Text('Понятно, продолжить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
