import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../services/theme_service.dart';

/// SettingsScreen — настройки приложения и внешний вид
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
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Внешний вид
          _SectionHeader(title: 'ВНЕШНИЙ ВИД'),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor(context),
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              border: Border.all(color: AppTheme.borderColor(context)),
              boxShadow: AppTheme.cardShadow(context),
            ),
            child: _ThemeSelector(themeService: _themeService),
          ),
          const SizedBox(height: 20),

          // О приложении
          _SectionHeader(title: 'О ПРИЛОЖЕНИИ'),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor(context),
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              border: Border.all(color: AppTheme.borderColor(context)),
              boxShadow: AppTheme.cardShadow(context),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded, color: AppTheme.safeGreen),
                  title: Text('VetVoice AI', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimaryColor(context))),
                  subtitle: Text('Ветеринарный справочник и калькулятор дозировок', style: TextStyle(color: AppTheme.textSecondaryColor(context), fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'VetVoice AI',
                      applicationVersion: '1.15.0',
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
                Divider(color: AppTheme.dividerColor(context), height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.storage_rounded, color: AppTheme.maleBlue),
                  title: Text('Версия базы', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimaryColor(context))),
                  subtitle: Text(_themeService.databaseInfo ?? '2401 препарат (актуально)', style: TextStyle(color: AppTheme.textSecondaryColor(context), fontSize: 12)),
                ),
                Divider(color: AppTheme.dividerColor(context), height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.source_rounded, color: AppTheme.warningOrange),
                  title: Text('Источники данных', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimaryColor(context))),
                  subtitle: Text('fsvps.gov.ru, vetprotocol.ru, vetlek.ru', style: TextStyle(color: AppTheme.textSecondaryColor(context), fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showSourcesDialog(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showSourcesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor(ctx),
        title: const Text('Источники данных'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Официальные реестры:',
                style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimaryColor(ctx)),
              ),
              const SizedBox(height: 4),
              Text(
                '• fsvps.gov.ru — Государственный реестр ЛС Россельхознадзора',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor(ctx)),
              ),
              const SizedBox(height: 12),
              Text(
                'Справочники:',
                style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimaryColor(ctx)),
              ),
              const SizedBox(height: 4),
              Text(
                '• vetprotocol.ru — справочник по МНН\n'
                '• vetlek.ru — инструкции к препаратам\n'
                '• vidal.ru/veterinar — справочник Видаль',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor(ctx)),
              ),
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
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppTheme.safeGreen,
          letterSpacing: 0.8,
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
          activeColor: AppTheme.safeGreen,
          title: Text('Системная тема', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimaryColor(context))),
          subtitle: Text('Автоматически переключается с системой', style: TextStyle(color: AppTheme.textSecondaryColor(context), fontSize: 12)),
          onChanged: (_) => themeService.setThemeMode(ThemeMode.system),
        ),
        Divider(color: AppTheme.dividerColor(context), height: 1, indent: 56),
        RadioListTile<ThemeMode>(
          value: ThemeMode.light,
          groupValue: themeService.themeMode,
          activeColor: AppTheme.safeGreen,
          title: Text('Светлая тема', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimaryColor(context))),
          subtitle: Text('Чистый светлый фон', style: TextStyle(color: AppTheme.textSecondaryColor(context), fontSize: 12)),
          onChanged: (_) => themeService.setThemeMode(ThemeMode.light),
        ),
        Divider(color: AppTheme.dividerColor(context), height: 1, indent: 56),
        RadioListTile<ThemeMode>(
          value: ThemeMode.dark,
          groupValue: themeService.themeMode,
          activeColor: AppTheme.safeGreen,
          title: Text('Тёмная тема (OLED)', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimaryColor(context))),
          subtitle: Text('Глубокий чёрный цвет, экономит батарею', style: TextStyle(color: AppTheme.textSecondaryColor(context), fontSize: 12)),
          onChanged: (_) => themeService.setThemeMode(ThemeMode.dark),
        ),
      ],
    );
  }
}
