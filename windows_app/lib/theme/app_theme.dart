import 'package:flutter/material.dart';

import 'app_theme_tokens.dart';

/// Windows 端主题变体枚举
enum WindowsThemeVariant {
  medicalBlue,
  slateBlue,
  purplePinkGray,
  freshGreen,
  peachPink,
}

/// Windows 主题变体解析扩展
extension WindowsThemeVariantParsing on WindowsThemeVariant {
  String get storageValue {
    switch (this) {
      case WindowsThemeVariant.medicalBlue:
        return 'medicalBlue';
      case WindowsThemeVariant.slateBlue:
        return 'slateBlue';
      case WindowsThemeVariant.purplePinkGray:
        return 'purplePinkGray';
      case WindowsThemeVariant.freshGreen:
        return 'freshGreen';
      case WindowsThemeVariant.peachPink:
        return 'peachPink';
    }
  }

  AppThemeTokens get tokens {
    switch (this) {
      case WindowsThemeVariant.medicalBlue:
        return AppThemeTokens.medicalBlue();
      case WindowsThemeVariant.slateBlue:
        return AppThemeTokens.slateBlue();
      case WindowsThemeVariant.purplePinkGray:
        return AppThemeTokens.purplePinkGray();
      case WindowsThemeVariant.freshGreen:
        return AppThemeTokens.freshGreen();
      case WindowsThemeVariant.peachPink:
        return AppThemeTokens.peachPink();
    }
  }

  static WindowsThemeVariant fromStorageValue(String? value) {
    switch (value) {
      case 'medicalBlue':
      case 'standard':
      case 'light':
      case 'grey':
      case 'gray':
      case null:
      case '':
        return WindowsThemeVariant.medicalBlue;
      case 'slateBlue':
        return WindowsThemeVariant.slateBlue;
      case 'purplePinkGray':
        return WindowsThemeVariant.purplePinkGray;
      case 'freshGreen':
        return WindowsThemeVariant.freshGreen;
      case 'peachPink':
        return WindowsThemeVariant.peachPink;
      default:
        return WindowsThemeVariant.medicalBlue;
    }
  }
}

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
      color: Colors.black.withValues(alpha: 0.05),
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
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
    ],
  );

  // 应用主题 - 浅色主题（通过 token 构建）
  static ThemeData lightTheme = standardTheme();

  // ==================== 统一主题构建入口 ====================

  /// 由 token 构建 ColorScheme
  static ColorScheme _buildColorScheme(AppThemeTokens tokens) {
    return ColorScheme(
      primary: tokens.primaryAccent,
      secondary: tokens.secondaryAccent,
      surface: tokens.cardBackground,
      error: tokens.error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: const Color(0xFF111111),
      onError: Colors.white,
      brightness: Brightness.light,
    );
  }

  /// 由 token 集中构建 ThemeData 覆盖清单
  static ThemeData _buildTheme(AppThemeTokens tokens) {
    return ThemeData(
      primaryColor: tokens.primaryAccent,
      scaffoldBackgroundColor: tokens.pageBackground,
      colorScheme: _buildColorScheme(tokens),
      extensions: [tokens],
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.shellBackground,
        foregroundColor: const Color(0xFF111111),
        elevation: 0,
        titleTextStyle: titleStyle.copyWith(fontSize: 18),
        iconTheme: IconThemeData(color: tokens.primaryAccent),
      ),
      cardTheme: CardThemeData(
        color: tokens.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.borderRadius),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: tokens.divider,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.panelBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.borderRadius),
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        // Flutter 3.44+ 桌面端默认 adaptiveClickable 解析为箭头，这里强制菜单项显示小手
        mouseCursor: WidgetStateMouseCursor.clickable,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.primaryAccent,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.borderRadius),
          ),
        ).copyWith(
          // Flutter 3.44+ 桌面端默认 adaptiveClickable 解析为箭头，这里强制启用时显示小手
          mouseCursor: WidgetStateMouseCursor.clickable,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.primaryAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.borderRadius),
          ),
        ).copyWith(
          mouseCursor: WidgetStateMouseCursor.clickable,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.primaryAccent,
          side: BorderSide(color: tokens.primaryAccent),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.borderRadius),
          ),
        ).copyWith(
          mouseCursor: WidgetStateMouseCursor.clickable,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom().copyWith(
          mouseCursor: WidgetStateMouseCursor.clickable,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom().copyWith(
          mouseCursor: WidgetStateMouseCursor.clickable,
        ),
      ),
      checkboxTheme: const CheckboxThemeData(
        mouseCursor: WidgetStateMouseCursor.clickable,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.inputBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.borderRadius),
          borderSide: BorderSide(color: tokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.borderRadius),
          borderSide: BorderSide(color: tokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.borderRadius),
          borderSide: BorderSide(color: tokens.primaryAccent, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      textTheme: const TextTheme(
        displayLarge: headingStyle,
        displayMedium: titleStyle,
        bodyLarge: subtitleStyle,
        bodyMedium: bodyStyle,
        bodySmall: captionStyle,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: tokens.shellBackground,
        selectedIconTheme: IconThemeData(color: tokens.primaryAccent, size: 24),
        unselectedIconTheme: IconThemeData(color: tokens.iconMuted, size: 24),
        selectedLabelTextStyle: TextStyle(
          color: tokens.primaryAccent,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: tokens.textMuted,
          fontSize: 14,
        ),
        elevation: 2,
        labelType: NavigationRailLabelType.all,
        groupAlignment: -0.85,
        minWidth: windowsNavRailWidth,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tokens.panelBackground,
        contentTextStyle: const TextStyle(color: Color(0xFF111111)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.smallBorderRadius),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(tokens.tableHeaderBackground),
        dividerThickness: 1,
      ),
    );
  }

  /// 标准主题入口
  static ThemeData standardTheme() => resolve(WindowsThemeVariant.medicalBlue);

  /// 根据 Windows 主题变体解析主题
  static ThemeData resolve(WindowsThemeVariant variant) {
    return _buildTheme(variant.tokens);
  }
}
