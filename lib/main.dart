import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
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

class VetVoiceApp extends StatelessWidget {
  final ThemeService themeService;
  final bool disclaimerAccepted;

  const VetVoiceApp({
    super.key,
    required this.themeService,
    required this.disclaimerAccepted,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeService,
      builder: (context, _) {
        return MaterialApp(
          title: 'VetVoice AI',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,  // 🆕
          themeMode: themeService.themeMode,  // 🆕 light / dark / system
          home: disclaimerAccepted
              ? const HomeScreen()
              : const DisclaimerScreen(),
        );
      },
    );
  }
}
