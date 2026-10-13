// MainShell — хост нижней навигации (Фаза 2 рефактора, v1.18.0).
//
// ЗАЧЕМ: раньше всё навигационное меню жило в чипах шапки HomeScreen
// (8 безымянных иконок → v1.16.3 подписанные чипы в скролле). Меню выросло —
// переезжает в постоянную нижнюю панель из 3 вкладок:
//   1. Главная     — HomeGridScreen: 2×3 сетка инструментов + safety-кластер;
//   2. Калькулятор — прежний HomeScreen (голосовой расчёт доз);
//   3. Ещё         — избранное / история / неофициальные протоколы / настройки.
//
// ПОЧЕМУ IndexedStack, а не Navigator-замена: HomeScreen держит подписки
// STT/Vosk и состояние микрофона. IndexedStack сохраняет стейт всех детей
// живым при переключении вкладок → wake word «ВетВойс» продолжает слушать
// на любой вкладке, введённые животное/вес/препарат не сбрасываются.
// Вторичные экраны по-прежнему открываются Navigator.push поверх shell —
// контракты навигации не изменились.
//
// НЕ ТРОГАЕТСЯ: voice-пайплайн (STT/Vosk), контракты VetProvider.
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../widgets/common/haptics.dart';
import '../widgets/common/wake_word_indicator.dart';
import 'home_grid_screen.dart';
import 'home_screen.dart';
import 'more_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  void _goTo(int i) {
    if (_index == i) return;
    // Фаза 3: тактильное подтверждение смены вкладки (аудит Фазы 0:
    // «ни одного HapticFeedback» — теперь хаптик на каждом значимом касании).
    AppHaptics.select();
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    // v1.18.1: сознательная зависимость от унаследованной Theme. Весь UI
    // вкладок построен на статических AppTheme-геттерах, которые НЕ создают
    // InheritedWidget-зависимостей — при смене темы IndexedStack-дети
    // оставались в старой палитре до перезапуска приложения (полевой отчёт
    // v1.18.0: «вкладка остаётся светлой до вылета»). Theme.of здесь
    // подписывает shell на смену темы: зависимый элемент помечается грязным
    // и перестраивается, даже если его child-виджеты — const.
    Theme.of(context);
    return PopScope(
      // Системный «назад» на вкладке ≠ главной возвращает на главную,
      // а не закрывает приложение — привычное поведение таб-приложений.
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goTo(0);
      },
      child: Scaffold(
        // theme-aware: тёмная тема красит панель и фон из токенов
        backgroundColor: AppTheme.background,
        body: IndexedStack(
          index: _index,
          children: [
            HomeGridScreen(onOpenCalculator: () => _goTo(1)),
            const HomeScreen(),
            const MoreScreen(),
          ],
        ),
        // Фаза 3: индикатор wake word над панелью — виден на ЛЮБОЙ вкладке
        // (пульс жил только в кнопке калькулятора; на «Главной»/«Ещё»
        // активности микрофона не было видно). SizedBox растягивает панель
        // на всю ширину — Column по умолчанию центрирует детей.
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const WakeWordIndicator(),
            SizedBox(
              width: double.infinity,
              child: NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: _goTo,
                destinations: const [
                  NavigationDestination(
                    selectedIcon: Icon(Icons.home_rounded),
                    icon: Icon(Icons.home_outlined),
                    label: 'Главная',
                  ),
                  NavigationDestination(
                    selectedIcon: Icon(Icons.calculate_rounded),
                    icon: Icon(Icons.calculate_outlined),
                    label: 'Калькулятор',
                  ),
                  NavigationDestination(
                    selectedIcon: Icon(Icons.widgets_rounded),
                    icon: Icon(Icons.widgets_outlined),
                    label: 'Ещё',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
