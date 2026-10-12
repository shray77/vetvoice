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
import '../services/wake_word_service.dart';
import 'terms_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ThemeService _themeService = ThemeService();
  final WakeWordService _wakeWordService = WakeWordService.instance;

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    // v1.16.1: живой статус модели Vosk (скачана / качается / ошибка)
    _wakeWordService.onDownloadProgress.listen((_) {
      if (mounted) setState(() {});
    });
    _wakeWordService.onListeningStateChanged.listen((_) {
      if (mounted) setState(() {});
    });
    _wakeWordService.onError.listen((_) {
      if (mounted) setState(() {});
    });
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
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        children: [
          // === Тема ===
          _SectionHeader(title: '🎨 Внешний вид'),
          _ThemeSelector(themeService: _themeService),
          const Divider(),

          // === Голос и распознавание ===
          _SectionHeader(title: '🎤 Голос и распознавание'),
          ListTile(
            leading: Icon(
              _voskIcon,
              color: _voskIconColor,
            ),
            title: const Text('Офлайн-модель Vosk (wake word «ВетВойс»)'),
            subtitle: Text(_voskStatusText),
            isThreeLine: _voskStatusText.length > 60,
            trailing: _wakeWordService.isInitialized
                ? const Icon(Icons.check_circle, color: AppTheme.safeGreen)
                : TextButton(
                    onPressed: () async {
                      setState(() {});
                      await _wakeWordService.initialize();
                      if (mounted) setState(() {});
                    },
                    child: _wakeWordService.isModelLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Загрузить')),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Модель нужна для wake word: скажите «ВетВойс» на главном '
              'экране и голосовой ввод включится без интернета. '
              'Качается один раз (~50 МБ), дальше работает оффлайн.',
              style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
            ),
          ),
          const SizedBox(height: 8),
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
                applicationVersion: '1.16.0',
                applicationLegalese: '© 2026 VetVoice · информационный сервис «как есть», не ветеринарная консультация',
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
            leading: const Icon(Icons.storage_outlined),
            title: const Text('Версия базы'),
            subtitle: Text(_themeService.databaseInfo ?? 'Загрузка...'),
          ),
          ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: const Text('Условия использования и дисклеймер'),
            subtitle: const Text('«Как есть» · не ветеринарная консультация · перепроверяйте расчёты'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TermsScreen()),
              );
            },
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
  /// Статусная строка модели Vosk (v1.16.1)
  String get _voskStatusText {
    switch (_wakeWordService.state) {
      case 'LISTENING':
        return 'Скачана и активна: слушает «ВетВойс» (офлайн)';
      case 'READY':
        return 'Скачана и готова — включите wake word кнопкой микрофона с волной';
      case 'LOADING':
        if (_wakeWordService.isExtracting) return 'Распаковка модели...';
        if (_wakeWordService.totalMB > 0) {
          return 'Скачивание: ${_wakeWordService.downloadedMB.toStringAsFixed(1)} из '
              '${_wakeWordService.totalMB.toStringAsFixed(0)} МБ';
        }
        return _wakeWordService.loadingMessage.isNotEmpty
            ? _wakeWordService.loadingMessage
            : 'Загрузка модели...';
      case 'ERROR':
        return _wakeWordService.errorMessage ?? 'Ошибка загрузки модели';
      default:
        return 'Модель не загружена (нужна только для wake word)';
    }
  }

  IconData get _voskIcon {
    switch (_wakeWordService.state) {
      case 'LISTENING':
      case 'READY':
        return Icons.mic_outlined;
      case 'LOADING':
        return Icons.downloading;
      case 'ERROR':
        return Icons.error_outline;
      default:
        return Icons.mic_none;
    }
  }

  Color get _voskIconColor {
    switch (_wakeWordService.state) {
      case 'LISTENING':
      case 'READY':
        return AppTheme.safeGreen;
      case 'LOADING':
        return AppTheme.maleBlue;
      case 'ERROR':
        return AppTheme.errorRed;
      default:
        return AppTheme.textTertiary;
    }
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
