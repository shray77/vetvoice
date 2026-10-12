import 'package:flutter/material.dart';

/// VetVoice AI — дизайн-система (Фаза 0 визуального рефакторинга, v1.16).
///
/// Палитра бренда VetVoice (синхронизирована с питч-деком):
/// фон #F6F9F3 · primary #009A44 · лайм #8CC63F · текст #0B2415.
/// Шрифты (бандл, оффлайн): Inter — текст, Manrope — заголовки и цифры.
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
  static const String fontBody = 'Inter'; // текст, UI
  static const String fontDisplay = 'Manrope'; // заголовки, крупные цифры

  // ===== Палитра: светлая =====
  static const Color white = Color(0xFFFFFFFF);
  /// Фон приложения и AppBar (тёплый молочно-зелёный из бренд-дека).
  static const Color background = Color(0xFFF6F9F3);
  /// Поверхность карточек.
  static const Color surface = white;
  /// Заливка полей ввода и вторичных контейнеров.
  static const Color fieldFill = Color(0xFFEDF2E8);
  /// Legacy-имя фона (было #F5F5F7) — теперь бренд-фон.
  static const Color backgroundGray = background;

  static const Color textPrimary = Color(0xFF0B2415);
  static const Color textSecondary = Color(0xFF45564B);
  static const Color textTertiary = Color(0xFF5F7065);

  // Акцент «Safe Green» (бренд).
  /// Основной акцент: кнопки, иконки, selected-состояния.
  /// Для МЕЛКОГО акцентного текста на светлом использовать accentText.
  static const Color safeGreen = Color(0xFF009A44);
  static const Color safeGreenLight = Color(0xFF2FB45C);
  /// Тёмно-зелёный: акцентный текст/иконки с контрастом ≥ 4.5:1 на светлом.
  static const Color safeGreenDark = Color(0xFF0A7F3C);
  /// Синоним для читаемого акцентного текста на светлом фоне.
  static const Color accentText = Color(0xFF0B6B33);
  /// Вторичный бренд-акцент (лайм): прогресс, лёгкие заливки.
  static const Color brandLime = Color(0xFF8CC63F);

  static const Color primaryContainer = Color(0xFFD3F2DF);
  static const Color onPrimaryContainer = Color(0xFF0B3D22);
  static const Color secondaryContainer = Color(0xFFE9F5D3);
  static const Color onSecondaryContainer = Color(0xFF2A4310);

  // Семантика (светлая).
  static const Color errorRed = Color(0xFFB3261E);
  static const Color errorContainer = Color(0xFFFBE3E1);
  static const Color onErrorContainer = Color(0xFF690005);
  /// Янтарь, безопасный для мелкого текста на светлом (≥ 4.5:1).
  static const Color warningOrange = Color(0xFFB45309);
  /// Насыщенный оранжевый — только крупные иконки/заливки, не текст.
  static const Color warningFill = Color(0xFFFF9500);
  static const Color warningContainer = Color(0xFFFCEBD5);
  static const Color success = Color(0xFF1B7A3D);
  static const Color successContainer = Color(0xFFDCF5E3);
  static const Color info = Color(0xFF1F6FB2);
  static const Color infoContainer = Color(0xFFE1EEF8);

  // Пол (только в animal_params_selector).
  static const Color maleBlue = Color(0xFF1F6FB2);
  static const Color femalePink = Color(0xFFA8457F);

  // Линии.
  static const Color dividerGray = Color(0xFFD8E2D4);
  static const Color outlineVariant = Color(0xFFE4ECE0);

  // ===== Палитра: тёмная (OLED) =====
  static const Color darkBackground = Color(0xFF0A120C);
  static const Color darkSurface = Color(0xFF121F16);
  static const Color darkSurfaceLight = Color(0xFF1B2B20);
  static const Color darkFieldFill = Color(0xFF16241B);
  static const Color darkTextPrimary = Color(0xFFE7F2E9);
  static const Color darkTextSecondary = Color(0xFFA9BBAD);
  static const Color darkTextTertiary = Color(0xFF7E9184);
  static const Color darkDivider = Color(0xFF324437);
  static const Color darkPrimary = Color(0xFF3DDC7B);
  static const Color darkPrimaryContainer = Color(0xFF0E5A31);
  static const Color darkOnPrimaryContainer = Color(0xFFB8F3CE);
  static const Color darkSecondary = Color(0xFFA5D96B);
  static const Color darkError = Color(0xFFFF8A80);
  static const Color darkErrorContainer = Color(0xFF5C1A14);
  static const Color darkOnErrorContainer = Color(0xFFFFDAD6);
  static const Color darkWarning = Color(0xFFFFB35C);
  static const Color darkSuccess = Color(0xFF7ED09A);
  static const Color darkInfo = Color(0xFF8FD3F4);

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

  /// Получить иконку категории (legacy, emoji; в Фазе 2 → Material-иконки).
  static String getCategoryIcon(String? category) {
    if (category == null) return '💊';
    final lower = category.toLowerCase();
    if (lower.contains('антибак')) return '🦠';
    if (lower.contains('иммунобиол') || lower.contains('вакцин')) return '💉';
    if (lower.contains('витамин')) return '🌱';
    if (lower.contains('нпвс') || lower.contains('анальг')) return '💊';
    if (lower.contains('противопаразит')) return '🐛';
    if (lower.contains('инсектоакар')) return '🕷️';
    if (lower.contains('антисепт') || lower.contains('дезинф')) return '🧴';
    if (lower.contains('противогриб')) return '🍄';
    if (lower.contains('гормон')) return '⚗️';
    if (lower.contains('сердеч') || lower.contains('сосуд')) return '❤️';
    if (lower.contains('нейротроп') || lower.contains('седатив')) return '🧠';
    if (lower.contains('иммуномод')) return '🛡️';
    if (lower.contains('пробиот') || lower.contains('пребиот')) return '🦠';
    if (lower.contains('наруж') || lower.contains('дермат')) return '🩹';
    if (lower.contains('гастро')) return '🫀';
    if (lower.contains('диагност')) return '🔬';
    return '💊';
  }

  // Скругления.
  static const double radiusMicro = 8.0;   // бейджи, тултипы
  static const double radiusSmall = 12.0;  // инпуты, кнопки, снекбары
  static const double radiusMedium = 16.0; // карточки
  static const double radiusLarge = 20.0;  // модалки, hero-блоки, bottom sheets
  static const double radiusXLarge = 24.0; // legacy
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
  /// Полная шкала типографики. Inter — body/title/label, Manrope —
  /// display/headline (заголовки и крупные цифры дозы, tabular figures).
  static TextTheme _textTheme({
    required Color headline,
    required Color body,
    required Color secondary,
    required Color tertiary,
  }) {
    return TextTheme(
      // Display — Manrope ExtraBold (крупные цифры: доза, вес).
      displayLarge: TextStyle(
        fontFamily: fontDisplay,
        fontSize: 34,
        height: 1.18,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: headline,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      displayMedium: TextStyle(
        fontFamily: fontDisplay,
        fontSize: 32,
        height: 1.19,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: headline,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      displaySmall: TextStyle(
        fontFamily: fontDisplay,
        fontSize: 28,
        height: 1.21,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: headline,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      // Headline — Manrope Bold (заголовки экранов).
      headlineLarge: TextStyle(
        fontFamily: fontDisplay,
        fontSize: 26,
        height: 1.23,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: headline,
      ),
      headlineMedium: TextStyle(
        fontFamily: fontDisplay,
        fontSize: 22,
        height: 1.27,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: headline,
      ),
      headlineSmall: TextStyle(
        fontFamily: fontDisplay,
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
      scaffoldBackgroundColor: background,
      highlightColor: Colors.transparent,
      splashColor: safeGreen.withOpacity(0.08),
      visualDensity: VisualDensity.comfortable,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      dialogBackgroundColor: surface,
      colorScheme: const ColorScheme.light(
        primary: safeGreen,
        onPrimary: white,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: brandLime,
        onSecondary: textPrimary,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: onSecondaryContainer,
        tertiary: info,
        onTertiary: white,
        tertiaryContainer: infoContainer,
        onTertiaryContainer: Color(0xFF0D3D63),
        error: errorRed,
        onError: white,
        errorContainer: errorContainer,
        onErrorContainer: onErrorContainer,
        surface: surface,
        onSurface: textPrimary,
        surfaceContainerLowest: white,
        surfaceContainerLow: Color(0xFFF0F4EC),
        surfaceContainer: fieldFill,
        surfaceContainerHigh: Color(0xFFE7EEE2),
        surfaceContainerHighest: fieldFill,
        onSurfaceVariant: textSecondary,
        outline: dividerGray,
        outlineVariant: outlineVariant,
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: textPrimary,
        onInverseSurface: Color(0xFFE7F2E9),
        inversePrimary: darkPrimary,
        surfaceTint: Colors.transparent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: textPrimary, size: 24),
        titleTextStyle: TextStyle(
          fontFamily: fontDisplay,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: textPrimary,
        ),
      ),
      textTheme: _textTheme(
        headline: textPrimary,
        body: textPrimary,
        secondary: textSecondary,
        tertiary: textTertiary,
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: fieldFill,
        selectedColor: primaryContainer,
        checkmarkColor: onPrimaryContainer,
        disabledColor: Color(0xFFEFF3EC),
        labelStyle: TextStyle(
          fontFamily: fontBody,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        labelPadding: EdgeInsets.symmetric(horizontal: 10),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        height: 40,
        shape: StadiumBorder(),
        side: BorderSide(color: Colors.transparent),
      ),
      cardTheme: const CardThemeData(
        color: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: BorderSide(color: outlineVariant),
        ),
      ),
      dividerTheme: const DividerThemeData(color: dividerGray, thickness: 1),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        hintStyle: TextStyle(
          fontFamily: fontBody,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: textTertiary,
        ),
        labelStyle: TextStyle(
          fontFamily: fontBody,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide(color: safeGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide(color: errorRed, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide(color: errorRed, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: const ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(safeGreen),
          foregroundColor: WidgetStatePropertyAll(white),
          overlayColor: WidgetStatePropertyAll(Color(0x14FFFFFF)),
          elevation: WidgetStatePropertyAll(0),
          minimumSize: WidgetStatePropertyAll(Size(0, 52)),
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusSmall),
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
          overlayColor: WidgetStatePropertyAll(Color(0x0D009A44)),
          minimumSize: WidgetStatePropertyAll(Size(0, 52)),
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusSmall),
            ),
          ),
          side: WidgetStatePropertyAll(
            BorderSide(color: dividerGray, width: 1.2),
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
          foregroundColor: WidgetStatePropertyAll(textSecondary),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: textPrimary,
        contentTextStyle: TextStyle(
          fontFamily: fontBody,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFFE7F2E9),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
        elevation: 3,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLarge)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: textSecondary,
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 10,
        titleTextStyle: TextStyle(
          fontFamily: fontBody,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: fontBody,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? white : fieldFill,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? safeGreen
              : dividerGray,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: safeGreen,
        inactiveTrackColor: Color(0xFFE0E8DC),
        thumbColor: safeGreen,
        overlayColor: Color(0x14009A44),
        valueIndicatorColor: textPrimary,
        valueIndicatorTextStyle: TextStyle(
          fontFamily: fontBody,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: white,
        ),
        trackHeight: 4,
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? safeGreen
              : textTertiary,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: safeGreen,
        linearTrackColor: Color(0xFFE0E8DC),
        circularTrackColor: Color(0xFFE0E8DC),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        iconColor: textSecondary,
        collapsedIconColor: textSecondary,
        textColor: textPrimary,
        collapsedTextColor: textPrimary,
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
      ),
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(
          color: textPrimary,
          borderRadius: BorderRadius.circular(radiusMicro),
        ),
        textStyle: TextStyle(
          fontFamily: fontBody,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: white,
        ),
        waitDuration: Duration(milliseconds: 400),
      ),
    );
  }

  /// Тёмная тема (OLED-фон, паритет контейнеров, яркий primary).
  static ThemeData get darkTheme {
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
        onPrimary: Color(0xFF06281A),
        primaryContainer: darkPrimaryContainer,
        onPrimaryContainer: darkOnPrimaryContainer,
        secondary: darkSecondary,
        onSecondary: Color(0xFF06281A),
        secondaryContainer: Color(0xFF2C4A16),
        onSecondaryContainer: Color(0xFFD9EFC0),
        tertiary: darkInfo,
        onTertiary: Color(0xFF06281A),
        tertiaryContainer: Color(0xFF123047),
        onTertiaryContainer: Color(0xFFBFE3F7),
        error: darkError,
        onError: Color(0xFF5C1A14),
        errorContainer: darkErrorContainer,
        onErrorContainer: darkOnErrorContainer,
        surface: darkSurface,
        onSurface: darkTextPrimary,
        surfaceContainerLowest: darkBackground,
        surfaceContainerLow: darkFieldFill,
        surfaceContainer: darkSurfaceLight,
        surfaceContainerHigh: Color(0xFF233527),
        surfaceContainerHighest: darkSurfaceLight,
        onSurfaceVariant: darkTextSecondary,
        outline: darkDivider,
        outlineVariant: Color(0xFF2A3B2F),
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: darkTextPrimary,
        onInverseSurface: textPrimary,
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
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
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
        disabledColor: Color(0xFF16241B),
        labelStyle: TextStyle(
          fontFamily: fontBody,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
        ),
        labelPadding: EdgeInsets.symmetric(horizontal: 10),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        height: 40,
        shape: StadiumBorder(),
        side: BorderSide(color: Colors.transparent),
      ),
      cardTheme: const CardThemeData(
        color: darkSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: BorderSide(color: Color(0xFF24352A)),
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
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide(color: darkPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide(color: darkError, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide(color: darkError, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: const ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(darkPrimary),
          foregroundColor: WidgetStatePropertyAll(Color(0xFF06281A)),
          overlayColor: WidgetStatePropertyAll(Color(0x14FFFFFF)),
          elevation: WidgetStatePropertyAll(0),
          minimumSize: WidgetStatePropertyAll(Size(0, 52)),
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusSmall),
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
              borderRadius: BorderRadius.circular(radiusSmall),
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
        backgroundColor: darkTextPrimary,
        contentTextStyle: TextStyle(
          fontFamily: fontBody,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
        elevation: 3,
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
              ? const Color(0xFF06281A)
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
        inactiveTrackColor: Color(0xFF2A3B2F),
        thumbColor: darkPrimary,
        overlayColor: Color(0x143DDC7B),
        valueIndicatorColor: darkTextPrimary,
        valueIndicatorTextStyle: TextStyle(
          fontFamily: fontBody,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textPrimary,
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
        linearTrackColor: Color(0xFF2A3B2F),
        circularTrackColor: Color(0xFF2A3B2F),
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
          borderRadius: BorderRadius.circular(radiusMicro),
        ),
        textStyle: TextStyle(
          fontFamily: fontBody,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textPrimary,
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

  // Светлая тема: текст (≥ 4.5:1 на белом) / контейнер / текст на контейнере.
  static const Color criticalLight = Color(0xFFB3261E);
  static const Color criticalLightBg = Color(0xFFFBE3E1);
  static const Color onCriticalLightBg = Color(0xFF690005);
  static const Color majorLight = Color(0xFFC2410C);
  static const Color majorLightBg = Color(0xFFFDEBD8);
  static const Color onMajorLightBg = Color(0xFF7A2E0A);
  static const Color moderateLight = Color(0xFF8A6A00);
  static const Color moderateLightBg = Color(0xFFF6EED2);
  static const Color onModerateLightBg = Color(0xFF5C4300);
  static const Color minorLight = Color(0xFF1F6FB2);
  static const Color minorLightBg = Color(0xFFE1EEF8);
  static const Color onMinorLightBg = Color(0xFF0D3D63);

  // Тёмная тема: текст на тёмном / контейнер.
  static const Color criticalDark = Color(0xFFFF8A80);
  static const Color criticalDarkBg = Color(0xFF44150F);
  static const Color majorDark = Color(0xFFFFB074);
  static const Color majorDarkBg = Color(0xFF3E2108);
  static const Color moderateDark = Color(0xFFE8C468);
  static const Color moderateDarkBg = Color(0xFF332A0B);
  static const Color minorDark = Color(0xFF8FD3F4);
  static const Color minorDarkBg = Color(0xFF123047);

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
