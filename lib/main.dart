import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/main_shell.dart';   // 🆕 Фаза 2: shell нижней навигации
import 'screens/disclaimer_screen.dart';
import 'utils/app_theme.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🆕 Инициализируем ThemeService (загружает выбор темы из SharedPreferences)
  final themeService = ThemeService();
  await themeService.init();

  // ⚖️ Юр-гейт: при первом запуске показываем дисклеймер до любого функционала.
  // Флаг ставится кнопкой «Понятно, приступить к работе» на DisclaimerScreen.
  final prefs = await SharedPreferences.getInstance();
  final disclaimerAccepted = prefs.getBool('disclaimer_accepted') ?? false;

  // Устанавливаем статус-бар
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  // Блокируем ориентацию (только портрет)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(VetVoiceApp(
    themeService: themeService,
    disclaimerAccepted: disclaimerAccepted,
  ));
}

class VetVoiceApp extends StatefulWidget {
  final ThemeService themeService;
  final bool disclaimerAccepted;

  const VetVoiceApp({
    super.key,
    required this.themeService,
    required this.disclaimerAccepted,
  });

  @override
  State<VetVoiceApp> createState() => _VetVoiceAppState();
}

class _VetVoiceAppState extends State<VetVoiceApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // v1.16.2: следим за системной яркостью — при ThemeMode.system смена
    // тёмного режима в системе должна перестроить дерево (иначе
    // AppTheme-геттеры продолжат возвращать старую палитру).
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    widget.themeService.notifyPlatformBrightness();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.themeService,
      builder: (context, _) {
        // Статус-бар под текущую тему (иконки читаемы и в dark).
        final mode = widget.themeService.themeMode;
        final darkNow = mode == ThemeMode.dark ||
            (mode == ThemeMode.system &&
                WidgetsBinding
                    .instance.platformDispatcher.platformBrightness ==
                    Brightness.dark);
        // v1.16.2: глобальный флаг для theme-aware геттеров AppTheme —
        // ДО построения MaterialApp, чтобы всё дерево этого кадра
        // рисовалось уже новой палитрой.
        AppTheme.applyBrightness(darkNow);
        SystemChrome.setSystemUIOverlayStyle(
          darkNow
              ? const SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.light,
                  statusBarBrightness: Brightness.dark,
                )
              : const SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.dark,
                  statusBarBrightness: Brightness.light,
                ),
        );
        return MaterialApp(
          title: 'VetVoice AI',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: widget.themeService.themeMode,
          // v1.16.3: мгновенная смена темы. Дефолтные 200мс анимируют ЛЕРП
          // всех цветов по всему дереву — на больших экранах это выглядело
          // как подвисание при переключении. Кэши ThemeData (app_theme)
          // + нулевая анимация = переключение в один кадр.
          themeAnimationDuration: Duration.zero,
          home: widget.disclaimerAccepted
              ? const MainShell()
              : const DisclaimerScreen(),
        );
      },
    );
  }
}
