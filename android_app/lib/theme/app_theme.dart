import 'package:flutter/material.dart';

// 全局样式变量
class AppTheme {
  // 主要配色
  static const Color primaryColor = Color(0xFF1A73E8); // 蓝色系主色调
  static const Color secondaryColor = Color(0xFF00BFA5); // 绿松石辅助色
  static const Color accentColor = Color(0xFFFF5722); // 橙色强调色

  // 中性色
  static const Color backgroundColor = Color(0xFFF8F9FA);
  static const Color cardBackground = Colors.white;
  static const Color darkBackground = Color(0xFF202124);
  static const Color darkCardBackground = Color(0xFF2D2F31);

  // 文本颜色
  static const Color primaryText = Color(0xFF202124);
  static const Color secondaryText = Color(0xFF5F6368);
  static const Color lightText = Color(0xFF9AA0A6);
  static const Color darkPrimaryText = Color(0xFFE8EAED);
  static const Color darkSecondaryText = Color(0xFFAAAAAA);
  static const Color darkLightText = Color(0xFF80868B);

  // 状态颜色
  static const Color successColor = Color(0xFF34A853);
  static const Color warningColor = Color(0xFFFBBC05);
  static const Color errorColor = Color(0xFFEA4335);
  static const Color infoColor = Color(0xFF4285F4);

  static const Color navigationBusiness = Color(0xFF9C27B0);
  static const Color navigationSettings = Color(0xFF607D8B);

  // 仪表盘欢迎卡片语义色
  static const Color dashboardWelcomeBorder = Color(0xFF8FB6F3);
  static const Color dashboardWelcomeShadow = Color(0xFF526FB5);
  static const Color dashboardWelcomeSurfaceBlue = Color(0xFFE9F3FF);
  static const Color dashboardWelcomeSurfacePurple = Color(0xFFEDE5FF);
  static const Color dashboardWelcomePrimaryText = Color(0xFF183B68);
  static const Color dashboardWelcomeSecondaryText = Color(0xFF557196);
  static const Color dashboardWelcomeAccent = Color(0xFF376FC7);
  static const Color dashboardWelcomeAccentPurple = Color(0xFF766FE6);

  // 编辑模式语义色（用于 MySQL 配置等可编辑卡片的浅蓝高亮）
  static const Color editModeSurface = Color(0xFFE3F2FD); // 浅蓝表面色
  static const Color editModeBanner = Color(0xFFBBDEFB); // 顶部提示横幅色

  // 兼容性别名 - 用于支持旧代码
  static const Color textColor = primaryText;
  static const Color secondaryTextColor = secondaryText;
  static const Color dividerColor = lightText;

  // 边框和阴影
  static const double borderRadius = 12.0;
  static const double smallBorderRadius = 8.0;
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  // 间距
  static const double padding = 16.0;

  // 文本样式
  static const TextStyle titleStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: primaryText,
  );

  static const TextStyle subtitleStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: primaryText,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontSize: 14,
    color: secondaryText,
  );

  static const TextStyle captionStyle = TextStyle(
    fontSize: 12,
    color: lightText,
  );

  // 按钮样式
  static final ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primaryColor,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(smallBorderRadius),
    ),
    elevation: 0,
  );

  static final ButtonStyle secondaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: secondaryColor,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(smallBorderRadius),
    ),
    elevation: 0,
  );

  static final ButtonStyle accentButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: accentColor,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(smallBorderRadius),
    ),
    elevation: 0,
  );

  // 卡片装饰
  static BoxDecoration cardDecoration = BoxDecoration(
    color: cardBackground,
    borderRadius: BorderRadius.circular(borderRadius),
    boxShadow: cardShadow,
  );

  // 应用主题
  static ThemeData lightTheme = ThemeData(
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundColor,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryColor,
      secondary: secondaryColor,
      tertiary: accentColor,
      surface: backgroundColor,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: cardBackground,
      foregroundColor: primaryText,
      elevation: 0,
      centerTitle: true,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: accentColor,
      unselectedLabelColor: secondaryText,
      indicatorColor: accentColor,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: cardBackground,
      selectedItemColor: accentColor,
      unselectedItemColor: secondaryText,
      elevation: 8,
    ),
    textTheme: const TextTheme(
      headlineMedium: titleStyle,
      titleMedium: subtitleStyle,
      bodyMedium: bodyStyle,
      bodySmall: captionStyle,
    ),
    dividerTheme: const DividerThemeData(color: lightText, thickness: 1),
    elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButtonStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(style: secondaryButtonStyle),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: backgroundColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(smallBorderRadius),
        borderSide: BorderSide(color: lightText.withValues(alpha: 0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(smallBorderRadius),
        borderSide: BorderSide(color: lightText.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(smallBorderRadius),
        borderSide: const BorderSide(color: primaryColor),
      ),
    ),
    cardTheme: CardThemeData(
      color: cardBackground,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    ),
  );

  // 深色主题
  static ThemeData darkTheme = ThemeData(
    primaryColor: primaryColor,
    scaffoldBackgroundColor: darkBackground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryColor,
      secondary: secondaryColor,
      tertiary: accentColor,
      surface: darkBackground,
      brightness: Brightness.dark,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: darkCardBackground,
      foregroundColor: darkPrimaryText,
      elevation: 0,
      centerTitle: true,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: primaryColor,
      unselectedLabelColor: darkSecondaryText,
      indicatorColor: primaryColor,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: darkCardBackground,
      selectedItemColor: primaryColor,
      unselectedItemColor: darkSecondaryText,
      elevation: 8,
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: darkPrimaryText,
        letterSpacing: -0.5,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: darkPrimaryText,
      ),
      bodyMedium: TextStyle(fontSize: 14, color: darkSecondaryText),
      bodySmall: TextStyle(fontSize: 12, color: darkLightText),
    ),
    dividerTheme: const DividerThemeData(color: darkLightText, thickness: 1),
    elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButtonStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(style: secondaryButtonStyle),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkCardBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(smallBorderRadius),
        borderSide: BorderSide(color: darkLightText.withValues(alpha: 0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(smallBorderRadius),
        borderSide: BorderSide(color: darkLightText.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(smallBorderRadius),
        borderSide: const BorderSide(color: primaryColor),
      ),
    ),
    cardTheme: CardThemeData(
      color: darkCardBackground,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    ),
    brightness: Brightness.dark,
  );
}
