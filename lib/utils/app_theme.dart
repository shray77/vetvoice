import 'package:flutter/material.dart';

/// Apple-Style минималистичная тема для VetVoice AI
class AppTheme {
  // Основные цвета (light)
  static const Color white = Color(0xFFFFFFFF);
  static const Color backgroundGray = Color(0xFFF5F5F7);
  static const Color textPrimary = Color(0xFF1D1D1F);
  static const Color textSecondary = Color(0xFF86868B);
  static const Color textTertiary = Color(0xFFAEAEB2);

  // Акцентный цвет "Safe Green"
  static const Color safeGreen = Color(0xFF28CD41);
  static const Color safeGreenLight = Color(0xFF34C759);
  static const Color safeGreenDark = Color(0xFF1DB954);

  // Цвета ошибок и предупреждений
  static const Color errorRed = Color(0xFFFF3B30);
  static const Color warningOrange = Color(0xFFFF9500);

  // Цвета пола
  static const Color maleBlue = Color(0xFF007AFF);
  static const Color femalePink = Color(0xFFFF2D92);

  // Дополнительные цвета
  static const Color dividerGray = Color(0xFFE5E5EA);

  // === Тёмная тема ===
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF1C1C1E);
  static const Color darkSurfaceLight = Color(0xFF2C2C2E);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF8E8E93);
  static const Color darkTextTertiary = Color(0xFF48484A);
  static const Color darkDivider = Color(0xFF38383A);

  // === Цвета категорий препаратов (для цветового кодирования в UI) ===
  // Соответствует category из drugs_calc.json
  static const Map<String, Color> categoryColors = {
    'Антибактериальные': Color(0xFFFF3B30),       // красный — осторожно с АБ
    'Иммунобиологические': Color(0xFF007AFF),     // синий — вакцины
    'Вакцины': Color(0xFF007AFF),
    'Витамины / Минералы': Color(0xFF28CD41),     // зелёный — безопасные
    'Витамины': Color(0xFF28CD41),
    'НПВС / Анальгетики': Color(0xFFFF9500),      // оранжевый — обезболивающие
    'Противопаразитарные': Color(0xFFAF52DE),     // фиолетовый
    'Инсектоакарицидные': Color(0xFF5AC8FA),      // голубой
    'Антисептики / Дезинфекторы': Color(0xFF64D2FF),
    'Противогрибковые': Color(0xFFBF5AF2),
    'Гормональные': Color(0xFFFFD60A),            // жёлтый
    'Сердечно-сосудистые': Color(0xFFFF2D55),
    'Нейротропные / Седативные': Color(0xFF8E8E93),
    'Иммуномодуляторы': Color(0xFF30D158),
    'Пробиотики / Пребиотики': Color(0xFF32ADE6),
    'Наружные / Дерматологические': Color(0xFFFF9F0A),
    'Гастроэнтерологические': Color(0xFFFFD60A),
    'Диагностические': Color(0xFF8E8E93),
    'Прочие': Color(0xFF8E8E93),                  // серый — по умолчанию
  };

  /// Получить цвет категории (с fallback на серый)
  static Color getCategoryColor(String? category) {
    if (category == null) return const Color(0xFF8E8E93);
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
    return const Color(0xFF8E8E93);
  }

  /// Получить иконку категории (для UI)
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

  // Скругление (Squircle)
  static const double radiusSmall = 12.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 20.0;
  static const double radiusXLarge = 24.0;

  // Тени
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
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

  // Размеры текста
  static const double fontSizeTitle = 28.0;
  static const double fontSizeSubtitle = 18.0;
  static const double fontSizeBody = 16.0;
  static const double fontSizeCaption = 14.0;
  static const double fontSizeSmall = 12.0;

  // Отступы
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;

  /// Светлая тема
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: white,
      colorScheme: ColorScheme.light(
        primary: safeGreen,
        onPrimary: white,
        surface: white,
        onSurface: textPrimary,
        error: errorRed,
        onError: white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: white,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: fontSizeTitle,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: fontSizeSubtitle,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: fontSizeBody,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: fontSizeCaption,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        bodySmall: TextStyle(
          fontSize: fontSizeSmall,
          fontWeight: FontWeight.w400,
          color: textTertiary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: backgroundGray,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          borderSide: const BorderSide(color: safeGreen, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: paddingLarge,
          vertical: paddingMedium,
        ),
        hintStyle: const TextStyle(
          color: textTertiary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: safeGreen,
          foregroundColor: white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLarge),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: paddingXLarge,
            vertical: paddingMedium,
          ),
          textStyle: const TextStyle(
            fontSize: fontSizeBody,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// 🆕 Тёмная тема (OLED-чёрный фон, как в iOS)
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: ColorScheme.dark(
        primary: safeGreen,
        onPrimary: white,
        surface: darkSurface,
        onSurface: darkTextPrimary,
        error: errorRed,
        onError: white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: fontSizeTitle,
          fontWeight: FontWeight.w700,
          color: darkTextPrimary,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: fontSizeSubtitle,
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: fontSizeBody,
          fontWeight: FontWeight.w400,
          color: darkTextPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: fontSizeCaption,
          fontWeight: FontWeight.w400,
          color: darkTextSecondary,
        ),
        bodySmall: TextStyle(
          fontSize: fontSizeSmall,
          fontWeight: FontWeight.w400,
          color: darkTextTertiary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          borderSide: const BorderSide(color: safeGreen, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: paddingLarge,
          vertical: paddingMedium,
        ),
        hintStyle: const TextStyle(
          color: darkTextTertiary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: safeGreen,
          foregroundColor: white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLarge),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: paddingXLarge,
            vertical: paddingMedium,
          ),
          textStyle: const TextStyle(
            fontSize: fontSizeBody,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: darkDivider,
        thickness: 1,
      ),
    );
  }

  /// 🆕 Получить тему по имени
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
