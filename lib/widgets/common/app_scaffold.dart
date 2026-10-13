// AppScaffold — единый каркас экрана (Фаза 1 рефактора, v1.17.0).
//
// ЗАЧЕМ: каждый экран собирал Scaffold по-своему — кто-то забывал
// backgroundColor (в тёмной теме вспыхивало белым), у кого-то AppBar
// со своим стилем заголовка. AppScaffold фиксирует:
//   - фон = AppTheme.background (theme-aware, тёмная тема работает из коробки);
//   - AppBar с типографикой токенов;
//   - единый отступ контента (static screenPadding).
//
// АДДИТИВНО: существующие экраны продолжают работать со своими Scaffold —
// они переходят на AppScaffold постепенно в Фазе 2 (по одному экрану,
// со смоук-тестом). Новые экраны — сразу AppScaffold.
import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  // v1.18.0: PreferredSizeWidget (не Widget) — AppBar.bottom требует его;
  // поймано Release APK #43, когда fluid_therapy впервые передал сюда TabBar.
  final PreferredSizeWidget? bottom; // TabBar, и т.п.
  final bool centerTitle;
  final bool automaticallyImplyLeading;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.bottom,
    this.centerTitle = false,
    this.automaticallyImplyLeading = true,
  });

  /// Единый отступ контента экрана от краёв.
  static const EdgeInsets screenPadding = EdgeInsets.all(AppTheme.paddingMedium);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // theme-aware: тёмная тема красит фон автоматически
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            fontSize: AppTheme.fontSizeSubtitle,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: centerTitle,
        actions: actions,
        bottom: bottom,
        automaticallyImplyLeading: automaticallyImplyLeading,
      ),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}
