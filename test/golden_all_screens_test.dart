// Golden-рендер ключевых экранов VetVoice (голос A + зелёный характер)
// для визуального аудита тем DS. По прецеденту ветэко (Task 176: 21 PNG).
// Обновление базы (создание/обновление PNG):
//   flutter test --update-goldens test/golden_all_screens_test.dart
// PNG складываются в test/golden/.
//
// ПРЕЦЕДЕНТНЫЕ ГРАБЛИ (уроки ветэко, соблюдаются здесь):
//  - кириллица рисуется тофу без реальных шрифтов → FontLoader с ttf;
//  - платформенный канал 'flutter/assets' не отвечает в widget-тестах →
//    мок отдаёт файлы напрямую с диска;
//  - базы грузятся ВНЕ testWidgets fake-async зоны → VetProvider
//    прогревается в setUpAll (синглтон — экраны получают тот же);
//  - speech/wake-word сервисы трогают MethodChannel → их init обёрнут
//    try/catch в самих сервисах (MissingPluginException глотается,
//    STT/TTS просто «не готовы» — как на устройстве без разрешения).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vetvoice_ai/providers/vet_provider.dart';
import 'package:vetvoice_ai/screens/disclaimer_screen.dart';
import 'package:vetvoice_ai/screens/diseases_screen.dart';
import 'package:vetvoice_ai/screens/favorites_screen.dart';
import 'package:vetvoice_ai/screens/fluid_therapy_screen.dart';
import 'package:vetvoice_ai/screens/history_screen.dart';
import 'package:vetvoice_ai/screens/home_grid_screen.dart';
import 'package:vetvoice_ai/screens/home_screen.dart';
import 'package:vetvoice_ai/screens/infusion_calculator_screen.dart';
import 'package:vetvoice_ai/screens/interactions_checker_screen.dart';
import 'package:vetvoice_ai/screens/main_shell.dart';
import 'package:vetvoice_ai/screens/more_screen.dart';
import 'package:vetvoice_ai/screens/settings_screen.dart';
import 'package:vetvoice_ai/screens/symptom_search_screen.dart';
import 'package:vetvoice_ai/screens/terms_screen.dart';
import 'package:vetvoice_ai/screens/treatment_protocols_screen.dart';
import 'package:vetvoice_ai/screens/withdrawal_calculator_screen.dart';
import 'package:vetvoice_ai/utils/app_theme.dart';

Widget _wrap(Widget screen, {required bool dark}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: screen,
  );
}

Future<void> _render(WidgetTester tester, Widget screen, String name,
    {required bool dark, Size? logical}) async {
  final dpr = 2.0;
  logical ??= const Size(390, 844);
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = Size(logical.width * dpr, logical.height * dpr);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_wrap(screen, dark: dark));
  // Ждём баз/анимаций входа: IndexedStack-экраны строятся целиком,
  // вторичные базы дорисовываются по extendedReady.
  for (int i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  await tester.pump(const Duration(milliseconds: 300));
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('golden/$name.png'),
  );
}

Future<void> _loadRealFonts() async {
  // Реальные шрифты вместо Ahem — иначе кириллица рисуется тофу-квадратами.
  // Inter (5 весов) + Prata — бандл-шрифты приложения (pubspec fonts:);
  // Roboto/MaterialIcons — из кеша Flutter SDK; NotoColorEmoji — системный
  // (✓⚠-подобные знаки в статусах рендерятся как в приложении).
  // ГРАБЛЯ CI (Task 176): жёсткий путь песочницы не существует у раннера —
  // шрифты молча не грузились, текст рендерился тофу. Кандидаты путей:
  // FLUTTER_ROOT (ставит subosito/flutter-action) + песочница разработки.
  final fr = Platform.environment['FLUTTER_ROOT'] ?? '';
  final sdkFonts = <String>[
    if (fr.isNotEmpty) '$fr/bin/cache/artifacts/material_fonts',
    '/home/z/flutter/bin/cache/artifacts/material_fonts',
  ];
  String? resolve(String name) {
    for (final d in sdkFonts) {
      final f = File('$d/$name');
      if (f.existsSync()) return f.path;
    }
    return null;
  }

  final families = <String, List<String?>>{
    'Inter': [
      'assets/fonts/Inter-Regular.ttf',
      'assets/fonts/Inter-Medium.ttf',
      'assets/fonts/Inter-SemiBold.ttf',
      'assets/fonts/Inter-Bold.ttf',
      'assets/fonts/Inter-ExtraBold.ttf',
    ],
    'Prata': ['assets/fonts/Prata-Regular.ttf'],
    'Roboto': [
      resolve('Roboto-Regular.ttf'),
      resolve('Roboto-Medium.ttf'),
      resolve('Roboto-Bold.ttf'),
      '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf',
    ],
    'MaterialIcons': [resolve('MaterialIcons-Regular.otf')],
  };
  for (final e in families.entries) {
    final loader = FontLoader(e.key);
    for (final path in e.value) {
      if (path == null) {
        // ignore: avoid_print
        print('FONT MISSING: ${e.key}');
        continue;
      }
      final f = File(path);
      if (f.existsSync()) {
        loader.addFont(
            Future.value(ByteData.view(f.readAsBytesSync().buffer)));
      } else {
        // ignore: avoid_print
        print('FONT MISSING: $path');
      }
    }
    await loader.load();
  }
}

Future<void> _mockAssetsChannel() async {
  // rootBundle.loadString виснет без мока канала 'flutter/assets' —
  // отдаём assets/data/*.json напрямую с диска (как ветэко).
  TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (ByteData? message) async {
    if (message == null) return null;
    final key = utf8.decode(message.buffer.asUint8List());
    final rel = key.startsWith('/') ? key.substring(1) : key;
    final f = File(rel.startsWith('assets/') ? rel : 'assets/$rel');
    if (f.existsSync()) {
      return ByteData.view(f.readAsBytesSync().buffer);
    }
    // ignore: avoid_print
    print('MISSING ASSET MOCK: $key');
    return null;
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({'disclaimer_accepted': true});
    await _mockAssetsChannel();
    await _loadRealFonts();
    // Базы — ВНЕ fake-async зоны (канальные ответы в testWidgets не
    // доставляются). Синглтон VetProvider прогреется здесь — все экраны
    // получают его же (factory → _instance).
    final vp = VetProvider();
    await vp.initialize();
    await vp.extendedReady;
    // ignore: avoid_print
    print('PRELOADED: drugs=${vp.allDrugs.length} '
        'diseases=${vp.diseaseDatabase != null} '
        'fluid=${vp.fluidTherapyDatabase != null}');
  });

  final vp = VetProvider();

  final screens = <String, Widget Function()>{
    '01_disclaimer_light': () => const DisclaimerScreen(),
    '02_home_grid_light': () => const HomeGridScreen(),
    '03_home_grid_dark': () => const HomeGridScreen(),
    '04_home_light': () => const HomeScreen(),
    '05_home_dark': () => const HomeScreen(),
    '06_shell_light': () => const MainShell(),
    '07_diseases_light': () => DiseasesScreen(
          database: vp.diseaseDatabase!,
          treatmentDatabase: vp.treatmentProtocolDatabase,
          selectedAnimal: null,
        ),
    '08_withdrawal_light': () => WithdrawalCalculatorScreen(
          vetProvider: vp,
          // Task 179: детерминизм — дата снятия золотой базы (26.10.2026).
          // Без инъекции экран рендерит DateTime.now() текстом — голден
          // краснеет каждый день после снятия базы (молча, пока Test
          // был под continue-on-error).
          initialDate: DateTime(2026, 10, 26),
        ),
    '09_withdrawal_dark': () => WithdrawalCalculatorScreen(
          vetProvider: vp,
          initialDate: DateTime(2026, 10, 26),
        ),
    '10_fluid_light': () => FluidTherapyScreen(
          db: vp.fluidTherapyDatabase!,
        ),
    '11_infusion_light': () => const InfusionCalculatorScreen(),
    '12_protocols_light': () => TreatmentProtocolsScreen(vetProvider: vp),
    '13_interactions_light': () =>
        InteractionsCheckerScreen(vetProvider: vp),
    '14_symptom_light': () => const SymptomSearchScreen(),
    '15_history_light': () => const HistoryScreen(),
    '16_favorites_light': () => const FavoritesScreen(),
    '17_settings_light': () => const SettingsScreen(),
    '18_settings_dark': () => const SettingsScreen(),
    '19_more_light': () => const MoreScreen(),
    '20_terms_light': () => const TermsScreen(),
  };

  for (final e in screens.entries) {
    final name = e.key;
    final dark = name.endsWith('_dark');
    testWidgets('golden: $name', (tester) async {
      await _render(tester, e.value(), name, dark: dark);
    });
  }

  testWidgets('golden: 21_home_small', (tester) async {
    // Компактный вьюпорт (iPhone SE класс) — сетка главной не должна
    // расползаться: шахматка плиток держит 2 колонки.
    await _render(tester, const HomeGridScreen(), '21_home_small',
        dark: false, logical: const Size(320, 568));
  });
}
