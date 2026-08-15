import 'package:flutter/material.dart';

/// Современная дизайн-система VetVoice AI (iOS / Apple Health Inspired)
class AppTheme {
  // === Базовые цвета (Light) ===
  static const Color white = Color(0xFFFFFFFF);
  static const Color backgroundGray = Color(0xFFF6F8FA);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF1F3F5);
  static const Color textPrimary = Color(0xFF191F28);
  static const Color textSecondary = Color(0xFF5F6E7C);
  static const Color textTertiary = Color(0xFF8B95A1);
  static const Color dividerGray = Color(0xFFE5E8EB);
  static const Color borderLight = Color(0xFFE2E6EA);

  // === Акцентный медицинский зелёный ===
  static const Color safeGreen = Color(0xFF10B981);
  static const Color safeGreenLight = Color(0xFF34D399);
  static const Color safeGreenDark = Color(0xFF059669);
  static const Color safeGreenSoft = Color(0xFFE6F8F2);

  // === Цвета статусов и предупреждений ===
  static const Color errorRed = Color(0xFFEF4444);
  static const Color errorRedSoft = Color(0xFFFEE2E2);
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color warningOrangeSoft = Color(0xFFFEF3C7);
  static const Color infoBlue = Color(0xFF3B82F6);
  static const Color infoBlueSoft = Color(0xFFEFF6FF);

  // === Цвета параметров (Пол) ===
  static const Color maleBlue = Color(0xFF2563EB);
  static const Color maleBlueSoft = Color(0xFFDBEAFE);
  static const Color femalePink = Color(0xFFEC4899);
  static const Color femalePinkSoft = Color(0xFFFCE7F3);

  // === Тёмная тема (Dark / OLED) ===
  static const Color darkBackground = Color(0xFF0D1117);
  static const Color darkSurface = Color(0xFF161B22);
  static const Color darkSurfaceLight = Color(0xFF21262D);
  static const Color darkCard = Color(0xFF161B22);
  static const Color darkTextPrimary = Color(0xFFF0F6FC);
  static const Color darkTextSecondary = Color(0xFF8B949E);
  static const Color darkTextTertiary = Color(0xFF6E7681);
  static const Color darkDivider = Color(0xFF30363D);
  static const Color darkBorder = Color(0xFF30363D);

  // === Цвета категорий препаратов (17 категорий) ===
  static const Map<String, Color> categoryColors = {
    'Антибактериальные': Color(0xFFEF4444),       // красный
    'Иммунобиологические': Color(0xFF3B82F6),     // синий
    'Вакцины': Color(0xFF3B82F6),
    'Витамины / Минералы': Color(0xFF10B981),     // изумрудный
    'Витамины': Color(0xFF10B981),
    'НПВС / Анальгетики': Color(0xFFF59E0B),      // янтарный
    'Противопаразитарные': Color(0xFF8B5CF6),     // фиолетовый
    'Инсектоакарицидные': Color(0xFF06B6D4),      // циан
    'Антисептики / Дезинфекторы': Color(0xFF0284C7),
    'Противогрибковые': Color(0xFFA855F7),
    'Гормональные': Color(0xFFEAB308),
    'Сердечно-сосудистые': Color(0xFFF43F5E),
    'Нейротропные / Седативные': Color(0xFF6366F1),
    'Иммуномодуляторы': Color(0xFF14B8A6),
    'Пробиотики / Пребиотики': Color(0xFF0EA5E9),
    'Наружные / Дерматологические': Color(0xFFD97706),
    'Гастроэнтерологические': Color(0xFFCA8A04),
    'Диагностические': Color(0xFF64748B),
    'Прочие': Color(0xFF64748B),
  };

  /// Получить цвет категории
  static Color getCategoryColor(String? category) {
    if (category == null) return const Color(0xFF64748B);
    if (categoryColors.containsKey(category)) {
      return categoryColors[category]!;
    }
    for (final key in categoryColors.keys) {
      if (category.toLowerCase().contains(key.toLowerCase().split(' ')[0])) {
        return categoryColors[key]!;
      }
    }
    return const Color(0xFF64748B);
  }

  /// Получить иконку категории
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
    if (lower.contains('пробиот') || lower.contains('пребиот')) return '🧬';
    if (lower.contains('наруж') || lower.contains('дермат')) return '🩹';
    if (lower.contains('гастро')) return '🫀';
    if (lower.contains('диагност')) return '🔬';
    return '💊';
  }

  // === Скругления ===
  static const double radiusXSmall = 8.0;
  static const double radiusSmall = 12.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 20.0;
  static const double radiusXLarge = 24.0;
  static const double radiusFull = 999.0;

  // === Размеры текста ===
  static const double fontSizeTitle = 24.0;
  static const double fontSizeSubtitle = 18.0;
  static const double fontSizeBody = 15.0;
  static const double fontSizeCaption = 13.0;
  static const double fontSizeSmall = 11.0;

  // === Отступы ===
  static const double paddingXSmall = 4.0;
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 20.0;
  static const double paddingXLarge = 28.0;

  // === Контекстные хелперы темы ===
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color backgroundColor(BuildContext context) =>
      isDark(context) ? darkBackground : backgroundGray;

  static Color cardColor(BuildContext context) =>
      isDark(context) ? darkCard : cardLight;

  static Color surfaceColor(BuildContext context) =>
      isDark(context) ? darkSurfaceLight : surfaceLight;

  static Color textPrimaryColor(BuildContext context) =>
      isDark(context) ? darkTextPrimary : textPrimary;

  static Color textSecondaryColor(BuildContext context) =>
      isDark(context) ? darkTextSecondary : textSecondary;

  static Color textTertiaryColor(BuildContext context) =>
      isDark(context) ? darkTextTertiary : textTertiary;

  static Color dividerColor(BuildContext context) =>
      isDark(context) ? darkDivider : dividerGray;

  static Color borderColor(BuildContext context) =>
      isDark(context) ? darkBorder : borderLight;

  static Color inputFillColor(BuildContext context) =>
      isDark(context) ? darkSurfaceLight : surfaceLight;

  // === Тени ===
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> cardShadow(BuildContext context) => [
    BoxShadow(
      color: isDark(context)
          ? Colors.black.withOpacity(0.3)
          : Colors.black.withOpacity(0.04),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
  ];

  static List<BoxShadow> greenGlow([double opacity = 0.25]) => [
    BoxShadow(
      color: safeGreen.withOpacity(opacity),
      blurRadius: 16,
      spreadRadius: 1,
    ),
  ];

  /// Светлая тема
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: backgroundGray,
      colorScheme: const ColorScheme.light(
        primary: safeGreen,
        onPrimary: white,
        surface: cardLight,
        onSurface: textPrimary,
        error: errorRed,
        onError: white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundGray,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: const BorderSide(color: borderLight, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: safeGreen, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: paddingMedium,
          vertical: 14,
        ),
        hintStyle: const TextStyle(
          color: textTertiary,
          fontSize: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: safeGreen,
          foregroundColor: white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: paddingLarge,
            vertical: 14,
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: dividerGray,
        thickness: 1,
        space: 1,
      ),
    );
  }

  /// Тёмная тема (OLED Dark)
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: safeGreen,
        onPrimary: white,
        surface: darkCard,
        onSurface: darkTextPrimary,
        error: errorRed,
        onError: white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: darkTextPrimary,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: safeGreen, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: paddingMedium,
          vertical: 14,
        ),
        hintStyle: const TextStyle(
          color: darkTextTertiary,
          fontSize: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: safeGreen,
          foregroundColor: white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: paddingLarge,
            vertical: 14,
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: darkDivider,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
