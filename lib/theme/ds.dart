import 'package:flutter/material.dart';

/// Перевод vet-ds v2.3.2 в Material-слой VetVoice: голос A «Научная
/// периодика» — A-light «бумага» (дефолт) + A-dark «Вечерний номер».
///
/// Источник токенов — vet-ds/vet-ds.css, блоки :root и [data-theme="dark"].
/// VetVoice — полевой справочник («читаешь»: дозы, препараты, болезни),
/// поэтому из пяти тем DS выбран голос A, а не прибор C (VetOS) и не
/// формуляр B (справочник не «действуешь»-стол).
///
/// Характер — зелёный бренда VetVoice поверх ядра (5-е применение паттерна
/// «характер поверх ядра»: ветрадар оливковый → VetOS бирюза → обещатор
/// оранжевый → ин-силико бирюза → VetVoice зелёный). Бренд-палитра
/// (#009A44) пере-точена до AA-значений: #0A7F3C на бумаге (≥ 4.5:1),
/// #3DDC7B на тёплом графите (тёмный primary прежнего бренда — сохранён).
///
/// Правила экосистемы (шапка vet-ds.css) действуют и здесь:
///  - эмодзи в UI запрещены — иконки Material, монохром с тинтом
///    (категориальные цвета препаратов — датавиз, ДС не подчиняются);
///  - текст ≥ AA (4.5:1) — значения DS проверены контраст-гейтом
///    scripts/ds_gate.py (аналог contrast_v2.py ядра);
///  - радиусы сдержанные: 4 — кнопки/чипы/инпуты, 8 — карточки/панели
///    (радиус больше 10px — бан-лист DS);
///  - движение: 160 мс, кривая cubic-bezier(.2, 0, 0, 1);
///  - цифры данных — Inter + tabular-nums (конвенция .ds-body ядра:
///    «цифры данных не пляшут»), дисплей-заголовки — Prata
///    (serif-дисплей периодики, 99 КБ ttf, прецедент Task 166/VetOS).
abstract final class DsLight {
  // -- Поверхности (бумага) ---------------------------------------------
  static const Color bg = Color(0xFFFAF9F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surface2 = Color(0xFFF1EEE6);
  static const Color border = Color(0xFFE3E0D5);
  static const Color borderStrong = Color(0xFFC8C4B6);
  static const Color rule = Color(0xFF1C1B1A);

  // -- Текст --------------------------------------------------------------
  static const Color text = Color(0xFF1C1B1A);
  static const Color muted = Color(0xFF5B564C);
  static const Color faint = Color(0xFF6E695C);

  // -- Семантика статусов (светлые значения DS) ---------------------------
  static const Color red = Color(0xFFB3261E);
  static const Color green = Color(0xFF47753A);
  static const Color amber = Color(0xFF8A5A14);
  static const Color orange = Color(0xFFAC4E18);
  static const Color blue = Color(0xFF33608C);
  static const Color violet = Color(0xFF6D4FC4);

  // -- Характер: зелёный VetVoice (AA на бумаге) ---------------------------
  static const Color accent = Color(0xFF097A38);
  static const Color accentStrong = Color(0xFF087534);
  static const Color accentInk = Color(0xFFF2FBF5);
}

abstract final class DsDark {
  // -- Поверхности (тёплый графит) ---------------------------------------
  static const Color bg = Color(0xFF211E19);
  static const Color surface = Color(0xFF2A2620);
  static const Color surface2 = Color(0xFF34302A);
  static const Color border = Color(0xFF3F3A32);
  static const Color borderStrong = Color(0xFF554E44);
  static const Color rule = Color(0xFF6E685C);

  // -- Текст ---------------------------------------------------------------
  static const Color text = Color(0xFFEDE9E0);
  static const Color muted = Color(0xFFB8B1A3);
  static const Color faint = Color(0xFF9E9789);

  // -- Семантика статусов (тёмные значения DS) ------------------------------
  static const Color red = Color(0xFFE87963);
  static const Color green = Color(0xFF8DB96F);
  static const Color amber = Color(0xFFD9A24A);
  static const Color orange = Color(0xFFE08A4F);
  static const Color blue = Color(0xFF82A9CC);
  static const Color violet = Color(0xFFB9A5E3);

  // -- Характер: зелёный бренда на графите (прежний darkPrimary) -----------
  static const Color accent = Color(0xFF3DDC7B);
  static const Color accentStrong = Color(0xFF5CE68F);
  static const Color accentInk = Color(0xFF0A120C);
}

abstract final class Ds {
  // -- Семейства шкалы: текст Inter, дисплей Prata (serif периодики) ------
  static const String sans = 'Inter';
  static const String display = 'Prata';

  // -- Радиусы (периодика: сдержанные) -------------------------------------
  static const double radiusS = 4;
  static const double radius = 8;

  // -- Движение: 160 мс, cubic-bezier(.2, 0, 0, 1) ---------------------------
  static const Duration dur = Duration(milliseconds: 160);
  static const Curve ease = Curves.fastOutSlowIn;

  // -- Шрифтовая шкала DS (vet-ds.css --ds-text-*) ---------------------------
  static const double textXs = 11; // подписи, футеры карточек, оверлайны
  static const double textS = 12.5; // вторичные строки
  static const double textM = 14; // основной текст, инпуты, заголовки списков
  static const double textL = 17; // вердикты, тайлы, шапки экранов
  static const double textXl = 24; // большие секции

  /// Тост DS: панель surface2 на волоске borderStrong, без тени,
  /// действие — характер приложения. Отступ снизу — с учётом gesture-бара
  /// (флоатинг-снек сам safe area не уважает; прецедент VLM-ревью Task 171).
  static void snack(
    BuildContext context,
    String text, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(milliseconds: 3200),
          margin: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
          backgroundColor: isDark ? DsDark.surface2 : DsLight.surface2,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: BorderSide(
              color: isDark ? DsDark.borderStrong : DsLight.borderStrong,
            ),
          ),
          action: (actionLabel != null)
              ? SnackBarAction(
                  label: actionLabel,
                  textColor: isDark ? DsDark.accent : DsLight.accent,
                  onPressed: onAction ?? () {},
                )
              : null,
        ),
      );
  }

  /// Общие форма и рамка DS: панель на surface2 с волоском borderStrong.
  static RoundedRectangleBorder panelShape(bool isDark) =>
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(
          color: isDark ? DsDark.borderStrong : DsLight.borderStrong,
        ),
      );
}

/// Переход экрана — аналог платформенной View Transition DS (блок 26):
/// кроссфейд 160 мс с лёгким зумом 0.98 -> 1.0 на кривой DS.
/// Отключённые анимации системы (prefers-reduced-motion) -> мгновенно.
class DsRoute<T> extends PageRouteBuilder<T> {
  DsRoute({required WidgetBuilder builder})
      : super(
          pageBuilder: (context, _, __) => builder(context),
          transitionDuration: Ds.dur,
          reverseTransitionDuration: Ds.dur,
          transitionsBuilder: (context, animation, _, child) {
            if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
              return child;
            }
            final curved = CurvedAnimation(
              parent: animation,
              curve: Ds.ease,
              reverseCurve: Ds.ease.flipped,
            );
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: _zoom.animate(curved),
                child: child,
              ),
            );
          },
        );

  static final Tween<double> _zoom = Tween<double>(begin: 0.98, end: 1.0);
}
