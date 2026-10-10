import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'utils/app_theme.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🆕 Инициализируем ThemeService (загружает выбор темы из SharedPreferences)
  final themeService = ThemeService();
  await themeService.init();

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

  runApp(VetVoiceApp(themeService: themeService));
}

class VetVoiceApp extends StatelessWidget {
  final ThemeService themeService;

  const VetVoiceApp({super.key, required this.themeService});

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
          home: const HomeScreen(),
        );
      },
    );
  }
}
