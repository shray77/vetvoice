import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'screens/disclaimer_screen.dart';
import 'utils/app_theme.dart';
import 'services/theme_service.dart';
import 'services/favorites_service.dart';
import 'services/history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🆕 Инициализация сервисов
  final themeService = ThemeService();
  await themeService.init();
  final favoritesService = FavoritesService();
  await favoritesService.init();
  final historyService = HistoryService();
  await historyService.init();

  // Блокируем ориентацию (только портрет)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 🆕 Проверяем первый запуск
  final prefs = await SharedPreferences.getInstance();
  final disclaimerAccepted = prefs.getBool('disclaimer_accepted') ?? false;

  runApp(VetVoiceApp(
    themeService: themeService,
    showDisclaimer: !disclaimerAccepted,
  ));
}

class VetVoiceApp extends StatelessWidget {
  final ThemeService themeService;
  final bool showDisclaimer;

  const VetVoiceApp({
    super.key,
    required this.themeService,
    this.showDisclaimer = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeService,
      builder: (context, _) {
        final isDark = themeService.themeMode == ThemeMode.dark ||
            (themeService.themeMode == ThemeMode.system &&
                MediaQuery.platformBrightnessOf(context) == Brightness.dark);

        return MaterialApp(
          title: 'VetVoice AI',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeService.themeMode,
          // 🆕 Статус-бар адаптивный
          builder: (context, child) {
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
              ),
              child: child!,
            );
          },
          home: showDisclaimer ? const DisclaimerScreen() : const HomeScreen(),
        );
      },
    );
  }
}
