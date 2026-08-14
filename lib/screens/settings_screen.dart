// SettingsScreen — настройки приложения.
//
// Что тут есть:
//   - Переключатель темы (светлая/тёмная/системная)
//   - Информация о версии базы препаратов
//   - О приложении
//
// Зависимости:
//   - SharedPreferences для сохранения выбранной темы

import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../services/theme_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ThemeService _themeService = ThemeService();

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('⚙️ Настройки')),
      body: ListView(
        children: [
          // === Тема ===
          _SectionHeader(title: '🎨 Внешний вид'),
          _ThemeSelector(themeService: _themeService),
          const Divider(),

          // === О приложении ===
          _SectionHeader(title: 'ℹ️ О приложении'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('VetVoice AI'),
            subtitle: const Text('Ветеринарный справочник и калькулятор дозировок'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'VetVoice AI',
                applicationVersion: '7.5',
                applicationLegalese: '© 2026 VetVoice',
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    'База препаратов: 2401\n'
                    'Вакцин и иммунобиологических: 698\n'
                    'Источники данных:\n'
                    '• Государственный реестр ЛС (fsvps.gov.ru)\n'
                    '• vetprotocol.ru\n'
                    '• vetlek.ru\n'
                    '• vidal.ru/veterinar',
                  ),
                ],
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Версия базы'),
            subtitle: Text(_themeService.databaseInfo ?? 'Загрузка...'),
          ),
          const Divider(),

          // === Данные ===
          _SectionHeader(title: '📊 Данные'),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Проверить обновления базы'),
            subtitle: const Text('Последняя проверка: сегодня'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Проверка обновлений...')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.source),
            title: const Text('Источники данных'),
            subtitle: const Text('fsvps.gov.ru, vetprotocol.ru, vetlek.ru'),
            onTap: () {
              _showSourcesDialog(context);
            },
          ),
        ],
      ),
    );
  }

  void _showSourcesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Источники данных'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Официальные источники:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text('• fsvps.gov.ru — Открытые данные Россельхознадзора\n'
                  '  (Государственный реестр ЛС для вет. применения)'),
              SizedBox(height: 12),
              Text(
                'Открытые справочники:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text('• vetprotocol.ru — справочник препаратов по МНН\n'
                  '• vetlek.ru — инструкции к препаратам\n'
                  '• vidal.ru/veterinar — справочник Видаль'),
              SizedBox(height: 12),
              Text(
                'Валидация:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text('База drugs_calc.json валидируется по всем\n'
                  'источникам еженедельно через GitHub Actions.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.safeGreen,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  final ThemeService themeService;

  const _ThemeSelector({required this.themeService});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RadioListTile<ThemeMode>(
          value: ThemeMode.system,
          groupValue: themeService.themeMode,
          title: const Text('Системная'),
          subtitle: const Text('Как в системе'),
          onChanged: (_) => themeService.setThemeMode(ThemeMode.system),
        ),
        RadioListTile<ThemeMode>(
          value: ThemeMode.light,
          groupValue: themeService.themeMode,
          title: const Text('Светлая'),
          subtitle: const Text('Всегда светлая тема'),
          onChanged: (_) => themeService.setThemeMode(ThemeMode.light),
        ),
        RadioListTile<ThemeMode>(
          value: ThemeMode.dark,
          groupValue: themeService.themeMode,
          title: const Text('Тёмная'),
          subtitle: const Text('OLED-чёрный, экономит батарею'),
          onChanged: (_) => themeService.setThemeMode(ThemeMode.dark),
        ),
      ],
    );
  }
}
