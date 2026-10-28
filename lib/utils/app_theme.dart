import 'package:flutter/material.dart';

import '../theme/ds.dart';

/// VetVoice AI — v1.21.0: дизайн-система экосистемы vet-ds v2.4.1,
/// голос A «Научная периодика» (A-light «бумага» / A-dark «Вечерний номер»),
/// зелёный характер бренда поверх ядра — см. lib/theme/ds.dart (DsLight/DsDark).
/// Сырые константы ниже — алиасы токенов DS: экраны сидят на прежних именах
/// (AppTheme.white, safeGreen, ...), значения едут из ядра одной правкой.
/// Шрифты (бандл, оффлайн): Inter — текст и цифры данных (tabular-nums,
/// конвенция .ds-body ядра), Prata — дисплей-заголовки (serif периодики).
///
/// Принципы:
///  • кард-поверхности без теней: surface + 1px outlineVariant;
///  • тени только для оверлеев (dropdown, микрофон, sticky);
///  • touch-цели ≥ 48dp, чипы ≥ 40dp высотой;
///  • единая severity-лестница (SeverityColors) для всех уровней опасности;
///  • текст на светлом фоне ≥ 4.5:1 (WCAG AA) — для мелкого акцентного
///    текста использовать accentText, а не safeGreen.
///
/// API-совместимость: все прежние константы AppTheme сохранены
/// (white, backgroundGray, safeGreen, errorRed, ...), значения пере-точены
/// на бренд-палитру. Экраны переводятся на токены поэтапно (Фаза 2).
class AppTheme {
  AppTheme._();

  // ===== Шрифты (бандл, см. pubspec.yaml) =====
  static const String fontBody = 'Inter'; // текст, UI, цифры данных (tnum)
  static const String fontDisplay = Ds.display; // Prata — дисплей-заголовки

  // ===== Палитра: светлая (СЫРЫЕ константы) =====
  // v1.16.2: прежние имена (white, background, textPrimary, ...) стали
  // theme-aware геттерами (см. ниже) — они читают AppTheme.isDarkNow,
  // который выставляется в VetVoiceApp.build. Внутри lightTheme/darkTheme
  // используются ТОЛЬКО сырые константы (_xxxLight / darkXxx), чтобы
  // ThemeData не зависел от текущего флага.
  static const Color _whiteLight = DsLight.surface; // = #FFFFFF (карточки DS)
  /// Фон приложения и AppBar — бумага DS A-light.
  static const Color _backgroundLight = DsLight.bg;
  /// Заливка полей ввода и вторичных контейнеров — surface2 DS.
  static const Color _fieldFillLight = DsLight.surface2;

  static const Color _textPrimaryLight = DsLight.text;
  static const Color _textSecondaryLight = DsLight.muted;
  static const Color _textTertiaryLight = DsLight.faint;

  // Акцент «Safe Green» (бренд).
  /// Основной акцент: кнопки, иконки, selected-состояния.
  /// Для МЕЛКОГО акцентного текста на светлом использовать accentText.
  static const Color safeGreen = DsLight.accent; // характер: AA на бумаге
  /// Яркий характер для тёмного фона (= DsDark.accent).
  static const Color safeGreenLight = DsDark.accent;
  /// Тёмно-зелёный: акцентный текст/иконки с контрастом ≥ 4.5:1 на светлом.
  static const Color safeGreenDark = DsLight.accent;
  /// Синоним для читаемого акцентного текста на светлом фоне.
  static const Color accentText = DsLight.accent;
  /// Вторичный акцент: прогресс, лёгкие заливки — семантика green DS.
  static const Color brandLime = DsLight.green;

  static const Color primaryContainer = Color(0xFFE3F0E8);
  static const Color onPrimaryContainer = Color(0xFF0A3A20);
  static const Color secondaryContainer = Color(0xFFEAF0DC);
  static const Color onSecondaryContainer = Color(0xFF33431F);

  // Семантика (светлая) — значения DS.
  static const Color errorRed = DsLight.red;
  static const Color errorContainer = Color(0xFFFBE3E1);
  static const Color onErrorContainer = Color(0xFF690005);
  /// Янтарь, безопасный для мелкого текста на светлом (≥ 4.5:1).
  static const Color warningOrange = DsLight.orange;
  /// Насыщенный оранжевый — только крупные иконки/заливки, не текст.
  static const Color warningFill = Color(0xFFFF9500);
  static const Color warningContainer = Color(0xFFFCEBD5);
  static const Color success = DsLight.green;
  static const Color successContainer = Color(0xFFDCF5E3);
  static const Color info = DsLight.blue;
  static const Color infoContainer = Color(0xFFE1EEF8);

  // Пол (только в animal_params_selector) — категорийный код, ДС не подчиняется.
  static const Color maleBlue = DsLight.blue;
  static const Color femalePink = Color(0xFFA8457F);

  // Линии — волосяные DS.
  static const Color _dividerGrayLight = DsLight.border;
  static const Color _outlineVariantLight = DsLight.border;

  // ===== Палитра: тёмная (A-dark «Вечерний номер» — тёплый графит DS) =====
  static const Color darkBackground = DsDark.bg;
  static const Color darkSurface = DsDark.surface;
  static const Color darkSurfaceLight = DsDark.surface2;
  static const Color darkFieldFill = DsDark.surface;
  static const Color darkTextPrimary = DsDark.text;
  static const Color darkTextSecondary = DsDark.muted;
  static const Color darkTextTertiary = DsDark.faint;
  static const Color darkDivider = DsDark.border;
  static const Color darkPrimary = DsDark.accent;
  static const Color darkPrimaryContainer = Color(0xFF0F3D26);
  static const Color darkOnPrimaryContainer = Color(0xFFA9EFC4);
  static const Color darkSecondary = DsDark.green;
  static const Color darkError = DsDark.red;
  static const Color darkErrorContainer = Color(0xFF46211C);
  static const Color darkOnErrorContainer = Color(0xFFF2D9D4);
  static const Color darkWarning = DsDark.amber;
  static const Color darkSuccess = DsDark.green;
  static const Color darkInfo = DsDark.blue;

  // ===== Theme-aware геттеры (v1.16.2 — фикс «тёмная тема красит только тогглы») =====
  //
  // Экраны держат старый хардкод `AppTheme.textPrimary` / `AppTheme.white` /
  // `AppTheme.background` — после Фазы 0 они продолжали рисовать светлые
  // константы поверх тёмного MaterialApp-фона, поэтому тёмная тема
  // «красила только тогглы». Теперь эти имена — ГЕТТЕРЫ, возвращающие
  // светлые или тёмные значения в зависимости от AppTheme.isDarkNow.
  // Флаг выставляется в VetVoiceApp.build (AnimatedBuilder на ThemeService),
  // поэтому смена темы перестраивает всё дерево и геттеры перечитываются.
  //
  // Светлая палитра при этом НЕ изменилась ни на один пиксель:
  // геттеры возвращают те же значения, что прежние const.
  static bool _darkNow = false;
  static bool get isDarkNow => _darkNow;

  /// Вызывается из VetVoiceApp.build до MaterialApp; [dark] = реально
  /// действующая яркость (учитывает ThemeMode.system).
  static void applyBrightness(bool dark) => _darkNow = dark;

  /// Поверхность карточек/дропдаунов (в dark — тёмная поверхность).
  /// «Белый текст на зелёной кнопке» в dark тоже станет darkSurface —
  /// такие места переведены на Colors.white явно.
  static Color get white => _darkNow ? darkSurface : _whiteLight;
  /// Поверхность карточек.
  static Color get surface => white;
  /// Фон приложения и AppBar.
  static Color get background => _darkNow ? darkBackground : _backgroundLight;
  /// Legacy-имя фона.
  static Color get backgroundGray => background;
  /// Заливка полей ввода и вторичных контейнеров.
  static Color get fieldFill => _darkNow ? darkFieldFill : _fieldFillLight;
  /// Линии.
  static Color get dividerGray => _darkNow ? darkDivider : _dividerGrayLight;
  static Color get outlineVariant =>
      _darkNow ? const Color(0xFF2A3B2F) : _outlineVariantLight;
  static Color get textPrimary => _darkNow ? darkTextPrimary : _textPrimaryLight;
  static Color get textSecondary =>
      _darkNow ? darkTextSecondary : _textSecondaryLight;
  static Color get textTertiary => _darkNow ? darkTextTertiary : _textTertiaryLight;

  // ===== Цвета категорий препаратов (бренд-совместимые, приглушённые) =====
  // Соответствует category из drugs_calc.json. В Фазе 2 заменяются
  // на theme-aware вариант (CategoryBadge), пока — статичные дескатырки.
  static const Map<String, Color> categoryColors = {
    'Антибактериальные': Color(0xFFB3261E),      // красный — осторожно с АБ
    'Иммунобиологические': Color(0xFF1F6FB2),    // синий — вакцины
    'Вакцины': Color(0xFF1F6FB2),
    'Витамины / Минералы': Color(0xFF1B7A3D),    // зелёный — безопасные
    'Витамины': Color(0xFF1B7A3D),
    'НПВС / Анальгетики': Color(0xFFB45309),     // янтарь
    'Противопаразитарные': Color(0xFF7A4FB0),    // деспу́рпурный
    'Инсектоакарицидные': Color(0xFF2E7FA3),     // петроль
    'Антисептики / Дезинфекторы': Color(0xFF0E8A8A), // бирюзовый
    'Противогрибковые': Color(0xFF8E5BC0),       // лаванда
    'Гормональные': Color(0xFFB98900),           // охра
    'Сердечно-сосудистые': Color(0xFFC2384F),    // кармин
    'Нейротропные / Седативные': Color(0xFF5F7065), // грифельный
    'Иммуномодуляторы': Color(0xFF2E9E52),       // травяной
    'Пробиотики / Пребиотики': Color(0xFF3B8EA5),// пыльно-синий
    'Наружные / Дерматологические': Color(0xFFC0653A), // терракота
    'Гастроэнтерологические': Color(0xFFA67C00), // тёмная охра
    'Диагностические': Color(0xFF5F7065),
    'Прочие': Color(0xFF5F7065),                 // серо-зелёный по умолчанию
  };

  /// Получить цвет категории (с fallback на нейтральный серо-зелёный).
  static Color getCategoryColor(String? category) {
    if (category == null) return const Color(0xFF5F7065);
    // Точное совпадение
    if (categoryColors.containsKey(category)) {
      return categoryColors[category]!;
    }
    // Частичное совпадение
    for (final key in categoryColors.keys) {
      if (category.toLowerCase().contains(key.toLowerCase().split(' ')[0])) {
        return categoryColors[key]!;
      }
    }
    return const Color(0xFF5F7065);
  }

  /// Глиф категории — Material-иконка (правило DS: эмодзи в UI запрещены;
  /// монохром, тинт категориальным цветом — см. getCategoryColor).
  static IconData getCategoryIcon(String? category) {
    if (category == null) return Icons.medication;
    final lower = category.toLowerCase();
    if (lower.contains('антибак')) return Icons.coronavirus;
    if (lower.contains('иммунобиол') || lower.contains('вакцин')) return Icons.vaccines;
    if (lower.contains('витамин')) return Icons.spa;
    if (lower.contains('нпвс') || lower.contains('анальг')) return Icons.medication;
    if (lower.contains('противопаразит')) return Icons.pest_control;
    if (lower.contains('инсектоакар')) return Icons.bug_report;
    if (lower.contains('антисепт') || lower.contains('дезинф')) return Icons.sanitizer;
    if (lower.contains('противогриб')) return Icons.grain;
    if (lower.contains('гормон')) return Icons.science;
    if (lower.contains('сердеч') || lower.contains('сосуд')) return Icons.favorite;
    if (lower.contains('нейротроп') || lower.contains('седатив')) return Icons.psychology;
    if (lower.contains('иммуномод')) return Icons.security;
    if (lower.contains('пробиот') || lower.contains('пребиот')) return Icons.bubble_chart;
    if (lower.contains('наруж') || lower.contains('дермат')) return Icons.healing;
    if (lower.contains('гастро')) return Icons.medical_services;
    if (lower.contains('диагност')) return Icons.biotech;
    return Icons.medication;
  }

  // Скругления — DS «периодика»: 4 — кнопки/чипы/инпуты, 8 — карточки/панели
  // (радиус больше 10px — бан-лист DS; пилюли — легитимны).
  static const double radiusMicro = Ds.radiusS; // бейджи, тултипы
  static const double radiusSmall = Ds.radiusS; // инпуты, кнопки, снекбары
  static const double radiusMedium = Ds.radius; // карточки, панели, снекбары DS
  static const double radiusLarge = Ds.radius;  // модалки, hero-блоки, bottom sheets
  static const double radiusXLarge = Ds.radius; // legacy-имя
  static const double radiusPill = 999.0;  // «таблетки», круглые кнопки

  // Отступы (шкала 4 / 8 / 12 / 16 / 24 / 32).
  static const double paddingXS = 4.0;
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;
  /// Между секциями.
  static const double paddingSection = paddingLarge;

  // Legacy-размеры текста (постепенно заменяются на textTheme).
  static const double fontSizeTitle = 28.0;
  static const double fontSizeSubtitle = 18.0;
  static const double fontSizeBody = 16.0;
  static const double fontSizeCaption = 14.0;
  static const double fontSizeSmall = 12.0;

  // Тени (только оверлеи; карточки — outline без elevation).
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get greenGlow => [
    BoxShadow(
      color: safeGreen.withOpacity(0.3),
      blurRadius: 20,
      spreadRadius: 2,
    ),
  ];
  /// Полная шкала типографики. Inter — body/title/label и display
  /// (крупные цифры дозы, tabular figures), Prata — headline
  /// (заголовки-витрины периодики; Manrope снят в v1.21.0 — см. pubspec).
  static TextTheme _textTheme({
    required Color headline,
    required Color body,
    required Color secondary,
    required Color tertiary,
  }) {
    return TextTheme(
      // Display — Inter ExtraBold + tabular (цифры данных: .ds-body ядра
      // держит font-variant-numeric: tabular-nums — «цифры данных не пляшут»;
      // serif-дисплей на динамических числах = дрожание ширины).
      displayLarge: TextStyle(
        fontFamily: fontBody,
        fontSize: 34,
        height: 1.18,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: headline,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      displayMedium: TextStyle(
        fontFamily: fontBody,
        fontSize: 32,
        height: 1.19,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: headline,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      displaySmall: TextStyle(
        fontFamily: fontBody,
        fontSize: 28,
        height: 1.21,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: headline,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      // Headline — Prata w400 (заголовки-витрины периодики, serif-дисплей DS).
      headlineLarge: TextStyle(
        fontFamily: fontDisplay,
        fontSize: 26,
        height: 1.23,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.2,
        color: headline,
      ),
      headlineMedium: TextStyle(
        fontFamily: fontDisplay,
        fontSize: 22,
        height: 1.27,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.2,
        color: headline,
      ),
      headlineSmall: TextStyle(
        fontFamily: fontBody,
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: headline,
      ),
      // Title — Inter SemiBold (заголовки карточек, лист-тайлов).
      titleLarge: TextStyle(
        fontFamily: fontBody,
        fontSize: 17,
        height: 1.41,
        fontWeight: FontWeight.w600,
        color: headline,
      ),
      titleMedium: TextStyle(
        fontFamily: fontBody,
        fontSize: 15,
        height: 1.47,
        fontWeight: FontWeight.w600,
        color: headline,
      ),
      titleSmall: TextStyle(
        fontFamily: fontBody,
        fontSize: 13,
        height: 1.38,
        fontWeight: FontWeight.w600,
        color: headline,
      ),
      // Body — Inter Regular.
      bodyLarge: TextStyle(
        fontFamily: fontBody,
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: body,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontBody,
        fontSize: 14,
        height: 1.43,
        fontWeight: FontWeight.w400,
        color: secondary,
      ),
      bodySmall: TextStyle(
        fontFamily: fontBody,
        fontSize: 12,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: tertiary,
      ),
      // Label — Inter SemiBold (кнопки, чипы, бейджи).
      labelLarge: TextStyle(
        fontFamily: fontBody,
        fontSize: 13,
        height: 1.23,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: headline,
      ),
      labelMedium: TextStyle(
        fontFamily: fontBody,
        fontSize: 12,
        height: 1.33,
        fontWeight: FontWeight.w600,
        color: headline,
      ),
      labelSmall: TextStyle(
        fontFamily: fontBody,
        fontSize: 11,
        height: 1.27,
        fontWeight: FontWeight.w600,
        color: secondary,
      ),
    );
  }

  /// Светлая тема.
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: fontBody,
      primaryColor: safeGreen,
      scaffoldBackgroundColor: _backgroundLight,
      highlightColor: Colors.transparent,
      splashColor: safeGreen.withOpacity(0.08),
      visualDensity: VisualDensity.comfortable,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      dialogBackgroundColor: _whiteLight,
      colorScheme: const ColorScheme.light(
        primary: safeGreen,
        onPrimary: _whiteLight,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: brandLime,
        onSecondary: _textPrimaryLight,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: onSecondaryContainer,
        tertiary: info,
        onTertiary: _whiteLight,
        tertiaryContainer: infoContainer,
        onTertiaryContainer: Color(0xFF0D3D63),
        error: errorRed,
        onError: _whiteLight,
        errorContainer: errorContainer,
        onErrorContainer: onErrorContainer,
        surface: _whiteLight,
        onSurface: _textPrimaryLight,
        surfaceContainerLowest: _whiteLight,
        surfaceContainerLow: DsLight.surface2,
        surfaceContainer: _fieldFillLight,
        surfaceContainerHigh: Color(0xFFE9E6DC),
        surfaceContainerHighest: _fieldFillLight,
        onSurfaceVariant: _textSecondaryLight,
        outline: _dividerGrayLight,
        outlineVariant: _outlineVariantLight,
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: _textPrimaryLight,
        onInverseSurface: DsLight.bg,
        inversePrimary: darkPrimary,
        surfaceTint: Colors.transparent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _whiteLight,
        foregroundColor: _textPrimaryLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: _textPrimaryLight, size: 24),
        titleTextStyle: TextStyle(
          fontFamily: fontDisplay,
          fontSize: 17,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          color: _textPrimaryLight,
        ),
      ),
      textTheme: _textTheme(
        headline: _textPrimaryLight,
        body: _textPrimaryLight,
        secondary: _textSecondaryLight,
        tertiary: _textTertiaryLight,
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: _fieldFillLight,
        selectedColor: primaryContainer,
        checkmarkColor: onPrimaryContainer,
        disabledColor: DsLight.surface2,
        labelStyle: TextStyle(
          fontFamily: fontBody,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _textPrimaryLight,
        ),
        labelPadding: EdgeInsets.symmetric(horizontal: 10),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        shape: StadiumBorder(),
        side: BorderSide(color: Colors.transparent),
      ),
      cardTheme: const CardThemeData(
        color: _whiteLight,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusMedium)),
          side: BorderSide(color: _outlineVariantLight),
        ),
      ),
      dividerTheme: const DividerThemeData(color: _dividerGrayLight, thickness: 1),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: _fieldFillLight,
        hintStyle: TextStyle(
          fontFamily: fontBody,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: _textTertiaryLight,
        ),
        labelStyle: TextStyle(
          fontFamily: fontBody,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: _textSecondaryLight,
        ),
        prefixIconColor: _textSecondaryLight,
        suffixIconColor: _textSecondaryLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusSmall)),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusSmall)),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusSmall)),
          borderSide: BorderSide(color: safeGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusSmall)),
          borderSide: BorderSide(color: errorRed, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusSmall)),
          borderSide: BorderSide(color: errorRed, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: const ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(safeGreen),
          foregroundColor: WidgetStatePropertyAll(_whiteLight),
          overlayColor: WidgetStatePropertyAll(Color(0x14FFFFFF)),
          elevation: WidgetStatePropertyAll(0),
          minimumSize: WidgetStatePropertyAll(Size(0, 52)),
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(radiusSmall)),
            ),
          ),
          textStyle: WidgetStatePropertyAll(
            TextStyle(
              fontFamily: fontBody,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      outlinedButtonTheme: const OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(accentText),
          overlayColor: WidgetStatePropertyAll(Color(0x0D097A38)),
          minimumSize: WidgetStatePropertyAll(Size(0, 52)),
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(radiusSmall)),
            ),
          ),
          side: WidgetStatePropertyAll(
            BorderSide(color: _dividerGrayLight, width: 1.2),
          ),
          textStyle: WidgetStatePropertyAll(
            TextStyle(
              fontFamily: fontBody,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      textButtonTheme: const TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(accentText),
          minimumSize: WidgetStatePropertyAll(Size(0, 44)),
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          textStyle: WidgetStatePropertyAll(
            TextStyle(
              fontFamily: fontBody,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(_textSecondaryLight),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: DsLight.surface2,
        contentTextStyle: TextStyle(
          fontFamily: fontBody,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: DsLight.text,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusMedium)),
          side: BorderSide(color: DsLight.borderStrong),
        ),
        elevation: 0,
        actionTextColor: DsLight.accent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _whiteLight,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLarge)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: _textSecondaryLight,
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 10,
        titleTextStyle: TextStyle(
          fontFamily: fontBody,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: _textPrimaryLight,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: fontBody,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: _textSecondaryLight,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? _whiteLight : _fieldFillLight,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? safeGreen
              : _dividerGrayLight,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: safeGreen,
        inactiveTrackColor: Color(0xFFE9E6DC),
        thumbColor: safeGreen,
        overlayColor: Color(0x14097A38),
        valueIndicatorColor: _textPrimaryLight,
        valueIndicatorTextStyle: TextStyle(
          fontFamily: fontBody,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _whiteLight,
        ),
        trackHeight: 4,
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? safeGreen
              : _textTertiaryLight,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: safeGreen,
        linearTrackColor: Color(0xFFE0E8DC),
        circularTrackColor: Color(0xFFE0E8DC),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        iconColor: _textSecondaryLight,
        collapsedIconColor: _textSecondaryLight,
        textColor: _textPrimaryLight,
        collapsedTextColor: _textPrimaryLight,
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
      ),
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(
          color: _textPrimaryLight,
          borderRadius: BorderRadius.all(Radius.circular(radiusMicro)),
        ),
        textStyle: TextStyle(
          fontFamily: fontBody,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: _whiteLight,
        ),
        waitDuration: Duration(milliseconds: 400),
      ),
    );
  }

  /// Тёмная тема (OLED-фон, паритет контейнеров, яркий primary).
  /// v1.16.3: мемоизирована — ThemeData строится один раз (см. lightTheme).
  static ThemeData? _darkThemeCache;

  /// Тёмная тема.
  static ThemeData get darkTheme => _darkThemeCache ??= _buildDarkTheme();

  static ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: fontBody,
      primaryColor: darkPrimary,
      scaffoldBackgroundColor: darkBackground,
      highlightColor: Colors.transparent,
      splashColor: darkPrimary.withOpacity(0.10),
      visualDensity: VisualDensity.comfortable,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      dialogBackgroundColor: darkSurface,
      colorScheme: const ColorScheme.dark(
        primary: darkPrimary,
        onPrimary: DsDark.accentInk,
        primaryContainer: darkPrimaryContainer,
        onPrimaryContainer: darkOnPrimaryContainer,
        secondary: darkSecondary,
        onSecondary: DsDark.accentInk,
        secondaryContainer: Color(0xFF2C4224),
        onSecondaryContainer: Color(0xFFD2E8C6),
        tertiary: darkInfo,
        onTertiary: DsDark.accentInk,
        tertiaryContainer: Color(0xFF1C3346),
        onTertiaryContainer: Color(0xFFBFD8EA),
        error: darkError,
        onError: Color(0xFF5C1A14),
        errorContainer: darkErrorContainer,
        onErrorContainer: darkOnErrorContainer,
        surface: darkSurface,
        onSurface: darkTextPrimary,
        surfaceContainerLowest: darkBackground,
        surfaceContainerLow: darkFieldFill,
        surfaceContainer: darkSurfaceLight,
        surfaceContainerHigh: Color(0xFF3A362E),
        surfaceContainerHighest: darkSurfaceLight,
        onSurfaceVariant: darkTextSecondary,
        outline: darkDivider,
        outlineVariant: DsDark.border,
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: darkTextPrimary,
        onInverseSurface: _textPrimaryLight,
        inversePrimary: safeGreen,
        surfaceTint: Colors.transparent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: darkTextPrimary, size: 24),
        titleTextStyle: TextStyle(
          fontFamily: fontDisplay,
          fontSize: 17,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          color: darkTextPrimary,
        ),
      ),
      textTheme: _textTheme(
        headline: darkTextPrimary,
        body: darkTextPrimary,
        secondary: darkTextSecondary,
        tertiary: darkTextTertiary,
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: darkSurfaceLight,
        selectedColor: darkPrimaryContainer,
        checkmarkColor: darkOnPrimaryContainer,
        disabledColor: Color(0xFF26221D),
        labelStyle: TextStyle(
          fontFamily: fontBody,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
        ),
        labelPadding: EdgeInsets.symmetric(horizontal: 10),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        shape: StadiumBorder(),
        side: BorderSide(color: Colors.transparent),
      ),
      cardTheme: const CardThemeData(
        color: darkSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusMedium)),
          side: BorderSide(color: DsDark.border),
        ),
      ),
      dividerTheme: const DividerThemeData(color: darkDivider, thickness: 1),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: darkFieldFill,
        hintStyle: TextStyle(
          fontFamily: fontBody,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: darkTextTertiary,
        ),
        labelStyle: TextStyle(
          fontFamily: fontBody,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: darkTextSecondary,
        ),
        prefixIconColor: darkTextSecondary,
        suffixIconColor: darkTextSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusSmall)),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusSmall)),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusSmall)),
          borderSide: BorderSide(color: darkPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusSmall)),
          borderSide: BorderSide(color: darkError, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusSmall)),
          borderSide: BorderSide(color: darkError, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: const ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(darkPrimary),
          foregroundColor: WidgetStatePropertyAll(DsDark.accentInk),
          overlayColor: WidgetStatePropertyAll(Color(0x14FFFFFF)),
          elevation: WidgetStatePropertyAll(0),
          minimumSize: WidgetStatePropertyAll(Size(0, 52)),
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(radiusSmall)),
            ),
          ),
          textStyle: WidgetStatePropertyAll(
            TextStyle(
              fontFamily: fontBody,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      outlinedButtonTheme: const OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(darkPrimary),
          overlayColor: WidgetStatePropertyAll(Color(0x143DDC7B)),
          minimumSize: WidgetStatePropertyAll(Size(0, 52)),
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(radiusSmall)),
            ),
          ),
          side: WidgetStatePropertyAll(
            BorderSide(color: darkDivider, width: 1.2),
          ),
          textStyle: WidgetStatePropertyAll(
            TextStyle(
              fontFamily: fontBody,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      textButtonTheme: const TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(darkPrimary),
          minimumSize: WidgetStatePropertyAll(Size(0, 44)),
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          textStyle: WidgetStatePropertyAll(
            TextStyle(
              fontFamily: fontBody,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(darkTextSecondary),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: DsDark.surface2,
        contentTextStyle: TextStyle(
          fontFamily: fontBody,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: DsDark.text,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusMedium)),
          side: BorderSide(color: DsDark.borderStrong),
        ),
        elevation: 0,
        actionTextColor: DsDark.accent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLarge)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: darkTextSecondary,
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 10,
        titleTextStyle: TextStyle(
          fontFamily: fontBody,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: darkTextPrimary,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: fontBody,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: darkTextSecondary,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? DsDark.accentInk
              : darkSurfaceLight,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? darkPrimary
              : darkDivider,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: darkPrimary,
        inactiveTrackColor: DsDark.surface2,
        thumbColor: darkPrimary,
        overlayColor: Color(0x143DDC7B),
        valueIndicatorColor: darkTextPrimary,
        valueIndicatorTextStyle: TextStyle(
          fontFamily: fontBody,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _textPrimaryLight,
        ),
        trackHeight: 4,
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? darkPrimary
              : darkTextTertiary,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: darkPrimary,
        linearTrackColor: DsDark.surface2,
        circularTrackColor: DsDark.surface2,
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        iconColor: darkTextSecondary,
        collapsedIconColor: darkTextSecondary,
        textColor: darkTextPrimary,
        collapsedTextColor: darkTextPrimary,
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
      ),
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(
          color: darkTextPrimary,
          borderRadius: BorderRadius.all(Radius.circular(radiusMicro)),
        ),
        textStyle: TextStyle(
          fontFamily: fontBody,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: _textPrimaryLight,
        ),
        waitDuration: Duration(milliseconds: 400),
      ),
    );
  }

  /// Получить тему по имени (legacy API).
  static ThemeData getTheme(String name) {
    switch (name) {
      case 'dark':
        return darkTheme;
      case 'light':
      default:
        return lightTheme;
    }
  }
}

/// Единая семантика уровней опасности — заменяет 3 разнобойные
/// реализации severity (interactions_checker / compatibility_checker /
/// interaction_warning). Использовать во всех Severity-UI.
enum SeverityLevel { critical, major, moderate, minor }

class SeverityColors {
  SeverityColors._();

  // Светлая тема: текст (≥ 4.5:1 на бумаге DS) / контейнер / текст на контейнере.
  static const Color criticalLight = DsLight.red;
  static const Color criticalLightBg = Color(0xFFFBE3E1);
  static const Color onCriticalLightBg = Color(0xFF690005);
  static const Color majorLight = DsLight.orange;
  static const Color majorLightBg = Color(0xFFF5E7DC);
  static const Color onMajorLightBg = Color(0xFF6B2E10);
  static const Color moderateLight = DsLight.amber;
  static const Color moderateLightBg = Color(0xFFF1E9D2);
  static const Color onModerateLightBg = Color(0xFF5A4514);
  static const Color minorLight = DsLight.blue;
  static const Color minorLightBg = Color(0xFFE1EAF2);
  static const Color onMinorLightBg = Color(0xFF1A3348);

  // Тёмная тема: текст на тёплом графите / контейнер.
  static const Color criticalDark = DsDark.red;
  static const Color criticalDarkBg = Color(0xFF40211C);
  static const Color majorDark = DsDark.orange;
  static const Color majorDarkBg = Color(0xFF3E2A1D);
  static const Color moderateDark = DsDark.amber;
  static const Color moderateDarkBg = Color(0xFF34301F);
  static const Color minorDark = DsDark.blue;
  static const Color minorDarkBg = Color(0xFF243747);

  static Color text(SeverityLevel level, Brightness brightness) {
    switch (level) {
      case SeverityLevel.critical:
        return brightness == Brightness.dark ? criticalDark : criticalLight;
      case SeverityLevel.major:
        return brightness == Brightness.dark ? majorDark : majorLight;
      case SeverityLevel.moderate:
        return brightness == Brightness.dark ? moderateDark : moderateLight;
      case SeverityLevel.minor:
        return brightness == Brightness.dark ? minorDark : minorLight;
    }
  }

  static Color bg(SeverityLevel level, Brightness brightness) {
    switch (level) {
      case SeverityLevel.critical:
        return brightness == Brightness.dark ? criticalDarkBg : criticalLightBg;
      case SeverityLevel.major:
        return brightness == Brightness.dark ? majorDarkBg : majorLightBg;
      case SeverityLevel.moderate:
        return brightness == Brightness.dark ? moderateDarkBg : moderateLightBg;
      case SeverityLevel.minor:
        return brightness == Brightness.dark ? minorDarkBg : minorLightBg;
    }
  }

  /// Цвет текста поверх bg() (для светлой темы; в тёмной используется text()).
  static Color onBg(SeverityLevel level, Brightness brightness) {
    if (brightness == Brightness.dark) return text(level, brightness);
    switch (level) {
      case SeverityLevel.critical:
        return onCriticalLightBg;
      case SeverityLevel.major:
        return onMajorLightBg;
      case SeverityLevel.moderate:
        return onModerateLightBg;
      case SeverityLevel.minor:
        return onMinorLightBg;
    }
  }
}

/// Шорткаты темы в build-контексте (Фаза 2: замена AppTheme.*-хардкода).
extension VetThemeX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get text => Theme.of(this).textTheme;
  ColorScheme get colors => Theme.of(this).colorScheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
