import 'package:flutter/material.dart';

// 全局样式变量 - 现代牙科诊疗系统设计
class AppTheme {
  // 主要配色 - 医疗专业配色
  static const Color primaryColor = Color(0xFF2E7DB8); // 医疗蓝
  static const Color secondaryColor = Color(0xFF4CAF50); // 健康绿
  static const Color accentColor = Color(0xFF00BCD4); // 清新青色
  static const Color tertiaryColor = Color(0xFFFF5722); // 警示橙色

  // 中性色 - 更加精致
  static const Color backgroundColor = Color(0xFFF5F5F7); // 更明亮的背景
  static const Color cardBackground = Colors.white;
  static const Color darkBackground = Color(0xFF121214); // 更深的暗黑背景
  static const Color darkCardBackground = Color(0xFF2C2C2E);
  static const Color darkDividerColor = Color(0xFF3A3A3C); // 深色模式分隔线颜色

  // 灰色主题颜色
  static const Color greyBackground = Color(0xFFE5E5E5);
  static const Color greyCardBackground = Color(0xFFF0F0F0);
  static const Color greySecondaryBackground = Color(0xFFDDDDDD);
  static const Color greyPrimaryText = Color(0xFF333333);
  static const Color greySecondaryText = Color(0xFF666666);
  static const Color greyLightText = Color(0xFF999999);
  static const Color greyDividerColor = Color(0xFFCCCCCC);

  // 文本颜色
  static const Color primaryText = Color(0xFF111111); // 更深的黑色
  static const Color secondaryText = Color(0xFF666666); // 中等灰色
  static const Color lightText = Color(0xFF999999); // 浅灰色
  static const Color darkPrimaryText = Color(0xFFFFFFFF);
  static const Color darkSecondaryText = Color(0xFFAAAAAA);
  static const Color darkLightText = Color(0xFF777777);

  // 状态颜色
  static const Color successColor = Color(0xFF30D158); // 一致使用secondaryColor
  static const Color warningColor = Color(0xFFFF9F0A); // 一致使用accentColor
  static const Color errorColor = Color(0xFFFF375F); // 一致使用tertiaryColor
  static const Color infoColor = Color(0xFFFFA726);

  // 兼容性别名 - 用于支持旧代码
  static const Color textColor = primaryText;
  static const Color secondaryTextColor = secondaryText;
  static const Color dividerColor = Color(0xFFEEEEEE); // 更浅的分隔线

  // 边框和阴影 - 现代风格阴影，较小的圆角
  static const double borderRadius = 12.0;
  static const double smallBorderRadius = 8.0;
  static final List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  // 间距
  static const double padding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;

  // 文本样式 - 更现代的字体风格
  static const TextStyle headingStyle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: primaryText,
    letterSpacing: -0.5,
    height: 1.3,
  );

  static const TextStyle titleStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: primaryText,
    letterSpacing: -0.3,
    height: 1.3,
  );

  static const TextStyle subtitleStyle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w500,
    color: primaryText,
    height: 1.3,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontSize: 16,
    color: secondaryText,
    height: 1.5,
  );

  static const TextStyle captionStyle = TextStyle(
    fontSize: 13,
    color: lightText,
    height: 1.4,
  );

  // 按钮样式 - 现代按钮样式
  static final ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primaryColor,
    foregroundColor: Colors.white,
    elevation: 2,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
    ),
  );

  // 渐变定义
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryColor, secondaryColor],
  );

  static const LinearGradient dangerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [errorColor, Color(0xFFFF6B6B)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [successColor, Color(0xFF66BB6A)],
  );

  static const LinearGradient warningGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [warningColor, Color(0xFFFFB74D)],
  );

  static const LinearGradient infoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [infoColor, Color(0xFFFFCC80)],
  );

  static final ButtonStyle secondaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: secondaryColor,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
    ),
    elevation: 0,
  );

  static final ButtonStyle accentButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: accentColor,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
    ),
    elevation: 0,
  );

  // 输入框样式 - 现代输入框
  static InputDecoration inputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: backgroundColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(color: primaryColor, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  // 卡片装饰 - 更现代的卡片样式
  static BoxDecoration cardDecoration = BoxDecoration(
    color: cardBackground,
    borderRadius: BorderRadius.circular(borderRadius),
    boxShadow: cardShadow,
    border: Border.all(color: dividerColor, width: 1),
  );

  // Windows特定样式 - 更现代简洁
  static const double windowsTitleBarHeight = 32.0;
  static const double windowsNavRailWidth = 200.0;
  static const double windowsContentPadding = 24.0;

  // Windows窗口标题栏样式
  static BoxDecoration windowsTitleBarDecoration = BoxDecoration(
    color: cardBackground,
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
    ],
  );

  // 紫色主题颜色
  static const Color purpleColor = Color(0xFFB69BB0); // 中等紫色主色调
  static const Color purpleLightColor = Color(0xFFE0CCDA); // 浅紫色
  static const Color purpleDarkColor = Color(0xFF9D7F97); // 深紫色
  static const Color purpleBackground = Color(0xFFF5EEF2); // 非常浅的紫色背景
  static const Color purpleCardBackground = Color(0xFFF8F1FF); // 更明显但柔和的紫色卡片背景
  static const Color purplePrimaryText = Color(0xFF4A2C4D); // 深紫色文本
  static const Color purpleSecondaryText = Color(0xFF6E5A7D); // 中等紫色文本
  static const Color purpleLightText = Color(0xFF9182A0); // 浅紫色文本
  static const Color purpleDividerColor = Color(0xFFE9DFF8); // 浅紫色分隔线
  static const Color purpleSecondaryBackground = Color(0xFFF8F5FD); // 次级背景色
  static final List<BoxShadow> purpleCardShadow = [
    BoxShadow(
      color: purpleColor.withOpacity(0.08),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  // 应用主题 - 浅色主题
  static ThemeData lightTheme = ThemeData(
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundColor,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryColor,
      secondary: secondaryColor,
      tertiary: accentColor,
      error: tertiaryColor,
      background: backgroundColor,
      surface: cardBackground,
      brightness: Brightness.light,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: cardBackground,
      foregroundColor: primaryText,
      elevation: 0,
      titleTextStyle: titleStyle.copyWith(fontSize: 18),
      iconTheme: const IconThemeData(color: primaryText),
    ),
    cardTheme: CardThemeData(
      color: cardBackground,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButtonStyle),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: const BorderSide(color: primaryColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: backgroundColor.withOpacity(0.8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(color: primaryColor, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    textTheme: const TextTheme(
      displayLarge: headingStyle,
      displayMedium: titleStyle,
      bodyLarge: subtitleStyle,
      bodyMedium: bodyStyle,
      bodySmall: captionStyle,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: cardBackground,
      selectedIconTheme: const IconThemeData(color: primaryColor, size: 24),
      unselectedIconTheme: const IconThemeData(color: secondaryText, size: 24),
      selectedLabelTextStyle: const TextStyle(
        color: primaryColor,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      unselectedLabelTextStyle: const TextStyle(
        color: secondaryText,
        fontSize: 14,
      ),
      elevation: 2,
      labelType: NavigationRailLabelType.all,
      groupAlignment: -0.85,
      minWidth: windowsNavRailWidth,
    ),
  );

  // 应用主题 - 深色主题
  static ThemeData darkTheme = ThemeData(
    primaryColor: primaryColor,
    scaffoldBackgroundColor: darkBackground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryColor,
      secondary: secondaryColor,
      tertiary: accentColor,
      error: tertiaryColor,
      background: darkBackground,
      surface: darkCardBackground,
      brightness: Brightness.dark,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: darkCardBackground,
      foregroundColor: darkPrimaryText,
      elevation: 0,
      titleTextStyle: titleStyle.copyWith(
        fontSize: 18,
        color: darkPrimaryText,
      ),
      iconTheme: const IconThemeData(color: darkPrimaryText),
    ),
    cardTheme: CardThemeData(
      color: darkCardBackground,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: primaryButtonStyle.copyWith(
        backgroundColor: MaterialStateProperty.all(primaryColor),
        foregroundColor: MaterialStateProperty.all(darkPrimaryText),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: const BorderSide(color: primaryColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkBackground.withOpacity(0.8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(color: primaryColor, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    textTheme: TextTheme(
      displayLarge: headingStyle.copyWith(color: darkPrimaryText),
      displayMedium: titleStyle.copyWith(color: darkPrimaryText),
      bodyLarge: subtitleStyle.copyWith(color: darkPrimaryText),
      bodyMedium: bodyStyle.copyWith(color: darkSecondaryText),
      bodySmall: captionStyle.copyWith(color: darkLightText),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: darkCardBackground,
      selectedIconTheme: const IconThemeData(color: primaryColor, size: 24),
      unselectedIconTheme:
          const IconThemeData(color: darkSecondaryText, size: 24),
      selectedLabelTextStyle: const TextStyle(
        color: primaryColor,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      unselectedLabelTextStyle: const TextStyle(
        color: darkSecondaryText,
        fontSize: 14,
      ),
      elevation: 2,
      labelType: NavigationRailLabelType.all,
      groupAlignment: -0.85,
      minWidth: windowsNavRailWidth,
    ),
  );

  // 灰色主题
  static ThemeData greyTheme = ThemeData(
    primaryColor: primaryColor,
    scaffoldBackgroundColor: greyBackground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryColor,
      secondary: secondaryColor,
      tertiary: accentColor,
      error: tertiaryColor,
      background: greyBackground,
      surface: greyCardBackground,
      brightness: Brightness.light,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: greyCardBackground,
      foregroundColor: greyPrimaryText,
      elevation: 0,
      titleTextStyle: titleStyle.copyWith(
        fontSize: 18,
        color: greyPrimaryText,
      ),
      iconTheme: IconThemeData(color: greyPrimaryText),
    ),
    cardTheme: CardThemeData(
      color: greyCardBackground,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: primaryButtonStyle.copyWith(
        backgroundColor: MaterialStateProperty.all(primaryColor),
        foregroundColor: MaterialStateProperty.all(Colors.white),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: const BorderSide(color: primaryColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(color: primaryColor, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    textTheme: TextTheme(
      displayLarge: headingStyle.copyWith(color: greyPrimaryText),
      displayMedium: titleStyle.copyWith(color: greyPrimaryText),
      bodyLarge: subtitleStyle.copyWith(color: greyPrimaryText),
      bodyMedium: bodyStyle.copyWith(color: greySecondaryText),
      bodySmall: captionStyle.copyWith(color: greyLightText),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: greyCardBackground,
      selectedIconTheme: const IconThemeData(color: primaryColor, size: 24),
      unselectedIconTheme: IconThemeData(color: greySecondaryText, size: 24),
      selectedLabelTextStyle: const TextStyle(
        color: primaryColor,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: greySecondaryText,
        fontSize: 14,
      ),
      elevation: 2,
      labelType: NavigationRailLabelType.all,
      groupAlignment: -0.85,
      minWidth: windowsNavRailWidth,
    ),
    dividerColor: greyDividerColor,
  );

  // 紫色主题
  static ThemeData purpleTheme = ThemeData(
    scaffoldBackgroundColor: purpleBackground,
    primaryColor: purpleColor,
    colorScheme: ColorScheme.light(
      primary: purpleColor,
      secondary: purpleLightColor,
      surface: purpleCardBackground,
      background: purpleBackground,
      onBackground: purplePrimaryText,
      onSurface: purplePrimaryText,
    ),
    cardColor: purpleCardBackground,
    canvasColor: purpleBackground,
    dividerColor: purpleDividerColor,
    textTheme: TextTheme(
      displayLarge: headingStyle.copyWith(color: purplePrimaryText),
      displayMedium: titleStyle.copyWith(color: purplePrimaryText),
      bodyLarge: subtitleStyle.copyWith(color: purplePrimaryText),
      bodyMedium: bodyStyle.copyWith(color: purpleSecondaryText),
      bodySmall: captionStyle.copyWith(color: purpleLightText),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: purpleCardBackground,
      foregroundColor: purplePrimaryText,
      elevation: 0,
      titleTextStyle: titleStyle.copyWith(color: purplePrimaryText),
      iconTheme: IconThemeData(color: purplePrimaryText),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: purpleCardBackground,
      titleTextStyle: TextStyle(
        color: purplePrimaryText,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      contentTextStyle: TextStyle(
        color: purpleSecondaryText,
        fontSize: 16,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: purpleColor,
        foregroundColor: Colors.white,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: purpleColor,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      fillColor: purpleSecondaryBackground,
      filled: true,
      labelStyle: TextStyle(color: purplePrimaryText),
      hintStyle: TextStyle(color: purpleLightText),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: purpleColor),
      ),
    ),
    iconTheme: IconThemeData(
      color: purplePrimaryText,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: purpleCardBackground,
      selectedIconTheme: IconThemeData(color: purpleColor, size: 24),
      unselectedIconTheme: IconThemeData(color: purpleSecondaryText, size: 24),
      selectedLabelTextStyle: TextStyle(
        color: purpleColor,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: purpleSecondaryText,
        fontSize: 14,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return purpleColor;
        }
        return null;
      }),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return purpleColor;
        }
        return null;
      }),
      trackColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return purpleColor.withOpacity(0.5);
        }
        return null;
      }),
    ),
  );
}
