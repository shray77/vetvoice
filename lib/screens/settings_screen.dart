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
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_theme.dart';
import '../providers/vet_provider.dart';
import '../services/theme_service.dart';
import '../widgets/common/haptics.dart';
import '../widgets/common/voice_status_bar.dart';
import '../widgets/common/gigaam_status_bar.dart';
import '../widgets/common/app_scaffold.dart';
// D12: общий хелпер плюрализации (2401 препарат / 2 протокола / 73 взаимодействия)
import 'history_screen.dart';
import 'terms_screen.dart';
import '../theme/ds.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ThemeService _themeService = ThemeService();

  /// B7 (аудит 26.11.2026): реальный timestamp последней локальной
  /// проверки базы в SharedPreferences (была константа «сегодня»).
  static const String _lastDbCheckKey = 'vetvoice_last_db_check';
  DateTime? _lastDbCheck;

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    // v1.17.0: живой статус Vosk переехал в VoiceStatusBar — компонент
    // сам подписан на все стримы (onStateChanged/onDownloadProgress/onError/
    // onListeningStateChanged) и сам перерисовывается.
    _loadLastDbCheck();
  }

  Future<void> _loadLastDbCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_lastDbCheckKey);
    if (ms == null || !mounted) return;
    setState(() =>
        _lastDbCheck = DateTime.fromMillisecondsSinceEpoch(ms));
  }

  String _formatDbCheckDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thatDay = DateTime(d.year, d.month, d.day);
    String two(int v) => v.toString().padLeft(2, '0');
    if (thatDay == today) {
      return 'сегодня, ${two(d.hour)}:${two(d.minute)}';
    }
    return '${two(d.day)}.${two(d.month)}.${d.year}';
  }

  /// B7: реальная ЛОКАЛЬНАЯ проверка — приложение офлайн, сетевой проверки
  /// нет (и не выдумываем). Считаем фактические базы из провайдера тем же
  /// путём, которым их стартуют экраны (provider.initialize()), показываем
  /// числа и запоминаем время проверки.
  Future<void> _checkDatabaseUpdate() async {
    final vetProvider = VetProvider();
    await vetProvider.initialize();
    final drugs = vetProvider.totalDrugs;
    final protocols = vetProvider.treatmentProtocolsCount;
    final interactions = vetProvider.interactionsCount;
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastDbCheckKey, now.millisecondsSinceEpoch);
    if (!mounted) return;
    setState(() => _lastDbCheck = now);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'База проверена (локально): $drugs '
          '${pluralizeRu(drugs, 'препарат', 'препарата', 'препаратов')}, '
          '$protocols '
          '${pluralizeRu(protocols, 'протокол', 'протокола', 'протоколов')}, '
          '$interactions '
          '${pluralizeRu(interactions, 'взаимодействие', 'взаимодействия', 'взаимодействий')}',
        ),
      ),
    );
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
    return AppScaffold(
      title: 'Настройки',
      body: ListView(
        children: [
          // === Тема ===
          _SectionHeader(title: 'Внешний вид'),
          _ThemeSelector(themeService: _themeService),
          const Divider(),

          // === Голос и распознавание ===
          _SectionHeader(title: 'Голос и распознавание'),
          // v1.17.0: ListTile со статусом заменён на общий компонент
          // VoiceStatusBar (статус + прогресс-бар скачивания + кнопки
          // «Загрузить»/«Стоп» из коробки, тёмная тема theme-aware).
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: VoiceStatusBar(),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Модель нужна для wake word: скажите «ВетВойс» на главном '
              'экране и голосовой ввод включится без интернета. '
              'Качается один раз (~44 МБ), дальше работает оффлайн. При обрыве связи докачивается с места обрыва.',
              style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(),

          // === 🆕 v1.25.0: офлайн-движок GigaAM (Сбер) ===
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: GigaAmStatusBar(),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Модель распознаёт команду целиком без интернета (точнее Vosk). '
              'Качается один раз (~216 МБ) — лучше по Wi-Fi. '
              'Vosk при этом продолжает будить приложение фразой «ВетВойс». При обрыве связи докачивается с места обрыва.',
              style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(),

          // === О приложении ===
          _SectionHeader(title: 'О приложении'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('VetVoice AI'),
            subtitle: const Text('Ветеринарный справочник и калькулятор дозировок'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'VetVoice AI',
                applicationVersion: '1.26.0',
                applicationLegalese: '© 2026 VetVoice · информационный сервис «как есть», не ветеринарная консультация',
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    // Task 260 (PR #1, реестр Галена): 2401 → 3838,
                    // МБА 698 → 734 (mia_drugs 722 → 734).
                    'База препаратов: 3838\n'
                    'Вакцин и иммунобиологических: 734\n'
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
                DsRoute(builder: (_) => const TermsScreen()),
              );
            },
          ),
          const Divider(),

          // === Данные ===
          _SectionHeader(title: 'Данные'),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Проверить обновления базы'),
            // B7: реальная дата последней проверки (SharedPreferences),
            // а не константа «сегодня».
            subtitle: Text(_lastDbCheck == null
                ? 'База в комплекте — обновления приходят с релизом'
                : 'Последняя проверка: ${_formatDbCheckDate(_lastDbCheck!)}'),
            onTap: _checkDatabaseUpdate,
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
          // Фаза 3: смена темы — выбор из вариантов (selectionClick).
          onChanged: (_) {
            AppHaptics.select();
            themeService.setThemeMode(ThemeMode.system);
          },
        ),
        RadioListTile<ThemeMode>(
          value: ThemeMode.light,
          groupValue: themeService.themeMode,
          title: const Text('Светлая'),
          subtitle: const Text('Всегда светлая тема'),
          onChanged: (_) {
            AppHaptics.select();
            themeService.setThemeMode(ThemeMode.light);
          },
        ),
        RadioListTile<ThemeMode>(
          value: ThemeMode.dark,
          groupValue: themeService.themeMode,
          title: const Text('Тёмная'),
          subtitle: const Text('OLED-чёрный, экономит батарею'),
          onChanged: (_) {
            AppHaptics.select();
            themeService.setThemeMode(ThemeMode.dark);
          },
        ),
      ],
    );
  }
}
