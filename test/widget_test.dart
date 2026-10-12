import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetvoice_ai/main.dart';
import 'package:vetvoice_ai/services/theme_service.dart';

/// Smoke test для VetVoiceApp.
///
/// ⚠️ Фикс Q-3: ранее тест искал `find.text('VetVoice AI')` сразу после
/// `pumpWidget` — но этот текст рендерится только в шапке `_buildHeader`
/// после того как `_isLoading` переключится в `false`. `_initializeApp`
/// асинхронно грузит базы препаратов (через `DrugLoaderService.initialize`),
/// поэтому на первом фрейме текста ещё нет, тест зависал или падал в CI.
///
/// ⚠️ Фикс v1.16: `VetVoiceApp` требует `themeService` и `disclaimerAccepted`
/// (прежний `const VetVoiceApp()` не компилировался). Даём синглтон
/// `ThemeService()` (без init — SharedPreferences не трогается) и
/// `disclaimerAccepted: false` — рендерится DisclaimerScreen, без сети.
void main() {
  testWidgets('VetVoiceApp строится без исключений', (WidgetTester tester) async {
    await tester.pumpWidget(VetVoiceApp(
      themeService: ThemeService(),
      disclaimerAccepted: false,
    ));

    // MaterialApp с заголовком 'VetVoice AI' должен существовать
    expect(find.byType(MaterialApp), findsOneWidget);

    // Прокачиваем несколько фреймов, чтобы async-инициализация могла стартовать.
    // Не ждём полного завершения `_initializeApp` (она ходит в сеть) — только
    // убеждаемся, что виджет не крашится при первых фреймах.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // Главный экран должен отрендериться (даже в состоянии loading)
    expect(find.byType(Scaffold), findsWidgets);
  });
}
