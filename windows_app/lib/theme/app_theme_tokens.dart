import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  const AppThemeTokens({
    required this.pageBackground,
    required this.shellBackground,
    required this.panelBackground,
    required this.cardBackground,
    required this.elevatedCardBackground,
    required this.mutedBackground,
    required this.inputBackground,
    required this.border,
    required this.divider,
    required this.shadow,
    required this.focusRing,
    required this.primaryAccent,
    required this.secondaryAccent,
    required this.dangerAccent,
    required this.warningAccent,
    required this.iconMuted,
    required this.textMuted,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.successContainer,
    required this.warningContainer,
    required this.errorContainer,
    required this.infoContainer,
    required this.hoverBackground,
    required this.selectedBackground,
    required this.disabledBackground,
    required this.disabledText,
    required this.tableHeaderBackground,
    required this.listItemHoverBackground,
    required this.overlayScrim,
    required this.primaryHeaderGradient,
    required this.subtleHeaderGradient,
    required this.chartPalette,
    required this.cardShadow,
    required this.elevatedShadow,
    required this.borderRadius,
    required this.smallBorderRadius,
    required this.cardElevation,
  });

  final Color pageBackground;
  final Color shellBackground;
  final Color panelBackground;
  final Color cardBackground;
  final Color elevatedCardBackground;
  final Color mutedBackground;
  final Color inputBackground;
  final Color border;
  final Color divider;
  final Color shadow;
  final Color focusRing;
  final Color primaryAccent;
  final Color secondaryAccent;
  final Color dangerAccent;
  final Color warningAccent;
  final Color iconMuted;
  final Color textMuted;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color successContainer;
  final Color warningContainer;
  final Color errorContainer;
  final Color infoContainer;
  final Color hoverBackground;
  final Color selectedBackground;
  final Color disabledBackground;
  final Color disabledText;
  final Color tableHeaderBackground;
  final Color listItemHoverBackground;
  final Color overlayScrim;
  final LinearGradient primaryHeaderGradient;
  final LinearGradient subtleHeaderGradient;
  final List<Color> chartPalette;
  final List<BoxShadow> cardShadow;
  final List<BoxShadow> elevatedShadow;
  final double borderRadius;
  final double smallBorderRadius;
  final double cardElevation;

  factory AppThemeTokens.standard() => AppThemeTokens.medicalBlue();

  factory AppThemeTokens.medicalBlue() {
    const primary = Color(0xFF2E7DB8);
    const secondary = Color(0xFF5BA8D6);
    const success = Color(0xFF36B37E);
    const warning = Color(0xFFF5A623);
    const error = Color(0xFFE85D75);
    const info = Color(0xFF5B8DEF);

    return AppThemeTokens(
      pageBackground: const Color(0xFFF4F7FA),
      shellBackground: const Color(0xFFF8FAFC),
      panelBackground: const Color(0xFFFEFEFE),
      cardBackground: const Color(0xFFFEFEFE),
      elevatedCardBackground: const Color(0xFFFFFFFF),
      mutedBackground: const Color(0xFFEEF4F8),
      inputBackground: const Color(0xFFF6F9FC),
      border: const Color(0xFFE1EAF5),
      divider: const Color(0xFFEEF3F8),
      shadow: primary.withValues(alpha: 0.08),
      focusRing: primary.withValues(alpha: 0.20),
      primaryAccent: primary,
      secondaryAccent: secondary,
      dangerAccent: error,
      warningAccent: warning,
      iconMuted: const Color(0xFF667085),
      textMuted: const Color(0xFF7A8796),
      success: success,
      warning: warning,
      error: error,
      info: info,
      successContainer: const Color(0xFFEAF7F1),
      warningContainer: const Color(0xFFFFF4E0),
      errorContainer: const Color(0xFFFDECEF),
      infoContainer: const Color(0xFFEAF2FF),
      hoverBackground: const Color(0xFFEAF4FB),
      selectedBackground: const Color(0xFFDCECF8),
      disabledBackground: const Color(0xFFE8ECF1),
      disabledText: const Color(0xFF98A2B3),
      tableHeaderBackground: const Color(0xFFF0F5FA),
      listItemHoverBackground: const Color(0xFFF7FBFF),
      overlayScrim: const Color(0x59000000),
      primaryHeaderGradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2E7DB8), Color(0xFF5BA8D6)],
      ),
      subtleHeaderGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          primary.withValues(alpha: 0.08),
          secondary.withValues(alpha: 0.04),
        ],
      ),
      chartPalette: const [
        Color(0xFF2E7DB8),
        Color(0xFF5BA8D6),
        Color(0xFF7DA7C7),
        Color(0xFFF5A623),
        Color(0xFFE85D75),
      ],
      cardShadow: [
        BoxShadow(
          color: primary.withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
      elevatedShadow: [
        BoxShadow(
          color: primary.withValues(alpha: 0.10),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      ],
      borderRadius: 12,
      smallBorderRadius: 8,
      cardElevation: 0,
    );
  }

  factory AppThemeTokens.slateBlue() {
    const primary = Color(0xFF4F7CAC);
    const secondary = Color(0xFF6A9A8B);
    const success = Color(0xFF36B37E);
    const warning = Color(0xFFF5A623);
    const error = Color(0xFFE85D75);
    const info = Color(0xFF5B8DEF);

    return AppThemeTokens(
      pageBackground: const Color(0xFFF3F5F7),
      shellBackground: const Color(0xFFF6F8FA),
      panelBackground: const Color(0xFFFEFEFE),
      cardBackground: const Color(0xFFFEFEFE),
      elevatedCardBackground: const Color(0xFFFFFFFF),
      mutedBackground: const Color(0xFFEEF2F6),
      inputBackground: const Color(0xFFF8FAFC),
      border: const Color(0xFFDFE7EF),
      divider: const Color(0xFFE9EEF3),
      shadow: const Color(0xFF263238).withValues(alpha: 0.07),
      focusRing: primary.withValues(alpha: 0.20),
      primaryAccent: primary,
      secondaryAccent: secondary,
      dangerAccent: error,
      warningAccent: warning,
      iconMuted: const Color(0xFF657484),
      textMuted: const Color(0xFF6B7A88),
      success: success,
      warning: warning,
      error: error,
      info: info,
      successContainer: const Color(0xFFEAF7F1),
      warningContainer: const Color(0xFFFFF4E0),
      errorContainer: const Color(0xFFFDECEF),
      infoContainer: const Color(0xFFEAF2FF),
      hoverBackground: const Color(0xFFEEF5FB),
      selectedBackground: const Color(0xFFE1EEF8),
      disabledBackground: const Color(0xFFE6EAEE),
      disabledText: const Color(0xFF9AA6B2),
      tableHeaderBackground: const Color(0xFFEEF2F6),
      listItemHoverBackground: const Color(0xFFF7FAFC),
      overlayScrim: const Color(0x59000000),
      primaryHeaderGradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF4F7CAC), Color(0xFF7DA7C7)],
      ),
      subtleHeaderGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          primary.withValues(alpha: 0.08),
          secondary.withValues(alpha: 0.04),
        ],
      ),
      chartPalette: const [
        Color(0xFF4F7CAC),
        Color(0xFF6A9A8B),
        Color(0xFF7DA7C7),
        Color(0xFFF5A623),
        Color(0xFFE85D75),
      ],
      cardShadow: [
        BoxShadow(
          color: const Color(0xFF263238).withValues(alpha: 0.07),
          blurRadius: 22,
          offset: const Offset(0, 8),
        ),
      ],
      elevatedShadow: [
        BoxShadow(
          color: const Color(0xFF263238).withValues(alpha: 0.10),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      ],
      borderRadius: 12,
      smallBorderRadius: 8,
      cardElevation: 0,
    );
  }

  factory AppThemeTokens.purplePinkGray() {
    const primary = Color(0xFF9A78A8);
    const secondary = Color(0xFFC99AAD);
    const success = Color(0xFF36B37E);
    const warning = Color(0xFFF5A623);
    const error = Color(0xFFE85D75);
    const info = Color(0xFF5B8DEF);

    return AppThemeTokens(
      pageBackground: const Color(0xFFF8F5F9),
      shellBackground: const Color(0xFFFBF9FC),
      panelBackground: const Color(0xFFFEFDFE),
      cardBackground: const Color(0xFFFEFDFE),
      elevatedCardBackground: const Color(0xFFFFFFFF),
      mutedBackground: const Color(0xFFF6F0F6),
      inputBackground: const Color(0xFFFBF9FC),
      border: const Color(0xFFE9DFEA),
      divider: const Color(0xFFF0E8F1),
      shadow: const Color(0xFF332B38).withValues(alpha: 0.08),
      focusRing: primary.withValues(alpha: 0.20),
      primaryAccent: primary,
      secondaryAccent: secondary,
      dangerAccent: error,
      warningAccent: warning,
      iconMuted: const Color(0xFF7D7185),
      textMuted: const Color(0xFF7D7185),
      success: success,
      warning: warning,
      error: error,
      info: info,
      successContainer: const Color(0xFFEAF7F1),
      warningContainer: const Color(0xFFFFF4E0),
      errorContainer: const Color(0xFFFDECEF),
      infoContainer: const Color(0xFFEAF2FF),
      hoverBackground: const Color(0xFFF5EEF7),
      selectedBackground: const Color(0xFFEFE3F3),
      disabledBackground: const Color(0xFFEDE7EE),
      disabledText: const Color(0xFFA69BAA),
      tableHeaderBackground: const Color(0xFFF3EDF4),
      listItemHoverBackground: const Color(0xFFFCF8FC),
      overlayScrim: const Color(0x59000000),
      primaryHeaderGradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF8F76A3), Color(0xFFB48AA8), Color(0xFFC9B6CF)],
      ),
      subtleHeaderGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          primary.withValues(alpha: 0.08),
          secondary.withValues(alpha: 0.04),
        ],
      ),
      chartPalette: const [
        Color(0xFF9A78A8),
        Color(0xFFC99AAD),
        Color(0xFF7DA7C7),
        Color(0xFFF5A623),
        Color(0xFFE85D75),
      ],
      cardShadow: [
        BoxShadow(
          color: const Color(0xFF332B38).withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
      elevatedShadow: [
        BoxShadow(
          color: const Color(0xFF332B38).withValues(alpha: 0.10),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      ],
      borderRadius: 12,
      smallBorderRadius: 8,
      cardElevation: 0,
    );
  }

  factory AppThemeTokens.freshGreen() {
    const primary = Color(0xFF2F8F72);
    const secondary = Color(0xFF2E7DB8);
    const success = Color(0xFF36B37E);
    const warning = Color(0xFFF5A623);
    const error = Color(0xFFE85D75);
    const info = Color(0xFF5B8DEF);

    return AppThemeTokens(
      pageBackground: const Color(0xFFF5F8F6),
      shellBackground: const Color(0xFFFAFBFA),
      panelBackground: const Color(0xFFFEFEFD),
      cardBackground: const Color(0xFFFEFEFD),
      elevatedCardBackground: const Color(0xFFFFFFFF),
      mutedBackground: const Color(0xFFEEF6F2),
      inputBackground: const Color(0xFFF8FAF8),
      border: const Color(0xFFDDECE4),
      divider: const Color(0xFFEAF1ED),
      shadow: primary.withValues(alpha: 0.08),
      focusRing: primary.withValues(alpha: 0.20),
      primaryAccent: primary,
      secondaryAccent: secondary,
      dangerAccent: error,
      warningAccent: warning,
      iconMuted: const Color(0xFF6D7F73),
      textMuted: const Color(0xFF6D7F73),
      success: success,
      warning: warning,
      error: error,
      info: info,
      successContainer: const Color(0xFFEAF7F1),
      warningContainer: const Color(0xFFFFF4E0),
      errorContainer: const Color(0xFFFDECEF),
      infoContainer: const Color(0xFFEAF2FF),
      hoverBackground: const Color(0xFFE7F4EF),
      selectedBackground: const Color(0xFFD9EEE6),
      disabledBackground: const Color(0xFFE5ECE8),
      disabledText: const Color(0xFF9EABA3),
      tableHeaderBackground: const Color(0xFFEFF6F2),
      listItemHoverBackground: const Color(0xFFF7FBF8),
      overlayScrim: const Color(0x59000000),
      primaryHeaderGradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2E7DB8), Color(0xFF2F8F72)],
      ),
      subtleHeaderGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          primary.withValues(alpha: 0.08),
          secondary.withValues(alpha: 0.04),
        ],
      ),
      chartPalette: const [
        Color(0xFF2F8F72),
        Color(0xFF2E7DB8),
        Color(0xFF76A66F),
        Color(0xFFF5A623),
        Color(0xFFE85D75),
      ],
      cardShadow: [
        BoxShadow(
          color: primary.withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
      elevatedShadow: [
        BoxShadow(
          color: primary.withValues(alpha: 0.10),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      ],
      borderRadius: 12,
      smallBorderRadius: 8,
      cardElevation: 0,
    );
  }

  factory AppThemeTokens.peachPink() {
    const primary = Color(0xFFC97888);
    const secondary = Color(0xFF8FA7A0);
    const success = Color(0xFF36B37E);
    const warning = Color(0xFFF5A623);
    const error = Color(0xFFE85D75);
    const info = Color(0xFF5B8DEF);

    return AppThemeTokens(
      pageBackground: const Color(0xFFF9F6F4),
      shellBackground: const Color(0xFFFCFAF9),
      panelBackground: const Color(0xFFFEFDFC),
      cardBackground: const Color(0xFFFEFDFC),
      elevatedCardBackground: const Color(0xFFFFFFFF),
      mutedBackground: const Color(0xFFF6EFEC),
      inputBackground: const Color(0xFFFCFAF8),
      border: const Color(0xFFEADDE0),
      divider: const Color(0xFFF0E6E8),
      shadow: const Color(0xFF3A2F33).withValues(alpha: 0.07),
      focusRing: primary.withValues(alpha: 0.20),
      primaryAccent: primary,
      secondaryAccent: secondary,
      dangerAccent: error,
      warningAccent: warning,
      iconMuted: const Color(0xFF7D6F73),
      textMuted: const Color(0xFF7D6F73),
      success: success,
      warning: warning,
      error: error,
      info: info,
      successContainer: const Color(0xFFEAF7F1),
      warningContainer: const Color(0xFFFFF4E0),
      errorContainer: const Color(0xFFFDECEF),
      infoContainer: const Color(0xFFEAF2FF),
      hoverBackground: const Color(0xFFFBECEF),
      selectedBackground: const Color(0xFFF7DDE3),
      disabledBackground: const Color(0xFFEEE7E5),
      disabledText: const Color(0xFFA99EA1),
      tableHeaderBackground: const Color(0xFFF6EEF0),
      listItemHoverBackground: const Color(0xFFFFF8F9),
      overlayScrim: const Color(0x59000000),
      primaryHeaderGradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFC97888), Color(0xFFDDA0AA), Color(0xFFE8C4C0)],
      ),
      subtleHeaderGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          primary.withValues(alpha: 0.08),
          secondary.withValues(alpha: 0.04),
        ],
      ),
      chartPalette: const [
        Color(0xFFC97888),
        Color(0xFF8FA7A0),
        Color(0xFF7DA7C7),
        Color(0xFFF5A623),
        Color(0xFFE85D75),
      ],
      cardShadow: [
        BoxShadow(
          color: const Color(0xFF3A2F33).withValues(alpha: 0.07),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
      elevatedShadow: [
        BoxShadow(
          color: const Color(0xFF3A2F33).withValues(alpha: 0.10),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      ],
      borderRadius: 12,
      smallBorderRadius: 8,
      cardElevation: 0,
    );
  }

  @override
  AppThemeTokens copyWith({
    Color? pageBackground,
    Color? shellBackground,
    Color? panelBackground,
    Color? cardBackground,
    Color? elevatedCardBackground,
    Color? mutedBackground,
    Color? inputBackground,
    Color? border,
    Color? divider,
    Color? shadow,
    Color? focusRing,
    Color? primaryAccent,
    Color? secondaryAccent,
    Color? dangerAccent,
    Color? warningAccent,
    Color? iconMuted,
    Color? textMuted,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? successContainer,
    Color? warningContainer,
    Color? errorContainer,
    Color? infoContainer,
    Color? hoverBackground,
    Color? selectedBackground,
    Color? disabledBackground,
    Color? disabledText,
    Color? tableHeaderBackground,
    Color? listItemHoverBackground,
    Color? overlayScrim,
    LinearGradient? primaryHeaderGradient,
    LinearGradient? subtleHeaderGradient,
    List<Color>? chartPalette,
    List<BoxShadow>? cardShadow,
    List<BoxShadow>? elevatedShadow,
    double? borderRadius,
    double? smallBorderRadius,
    double? cardElevation,
  }) {
    return AppThemeTokens(
      pageBackground: pageBackground ?? this.pageBackground,
      shellBackground: shellBackground ?? this.shellBackground,
      panelBackground: panelBackground ?? this.panelBackground,
      cardBackground: cardBackground ?? this.cardBackground,
      elevatedCardBackground:
          elevatedCardBackground ?? this.elevatedCardBackground,
      mutedBackground: mutedBackground ?? this.mutedBackground,
      inputBackground: inputBackground ?? this.inputBackground,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      shadow: shadow ?? this.shadow,
      focusRing: focusRing ?? this.focusRing,
      primaryAccent: primaryAccent ?? this.primaryAccent,
      secondaryAccent: secondaryAccent ?? this.secondaryAccent,
      dangerAccent: dangerAccent ?? this.dangerAccent,
      warningAccent: warningAccent ?? this.warningAccent,
      iconMuted: iconMuted ?? this.iconMuted,
      textMuted: textMuted ?? this.textMuted,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      successContainer: successContainer ?? this.successContainer,
      warningContainer: warningContainer ?? this.warningContainer,
      errorContainer: errorContainer ?? this.errorContainer,
      infoContainer: infoContainer ?? this.infoContainer,
      hoverBackground: hoverBackground ?? this.hoverBackground,
      selectedBackground: selectedBackground ?? this.selectedBackground,
      disabledBackground: disabledBackground ?? this.disabledBackground,
      disabledText: disabledText ?? this.disabledText,
      tableHeaderBackground:
          tableHeaderBackground ?? this.tableHeaderBackground,
      listItemHoverBackground:
          listItemHoverBackground ?? this.listItemHoverBackground,
      overlayScrim: overlayScrim ?? this.overlayScrim,
      primaryHeaderGradient:
          primaryHeaderGradient ?? this.primaryHeaderGradient,
      subtleHeaderGradient: subtleHeaderGradient ?? this.subtleHeaderGradient,
      chartPalette: chartPalette ?? this.chartPalette,
      cardShadow: cardShadow ?? this.cardShadow,
      elevatedShadow: elevatedShadow ?? this.elevatedShadow,
      borderRadius: borderRadius ?? this.borderRadius,
      smallBorderRadius: smallBorderRadius ?? this.smallBorderRadius,
      cardElevation: cardElevation ?? this.cardElevation,
    );
  }

  @override
  AppThemeTokens lerp(ThemeExtension<AppThemeTokens>? other, double t) {
    if (other is! AppThemeTokens) {
      return this;
    }

    return AppThemeTokens(
      pageBackground: Color.lerp(pageBackground, other.pageBackground, t)!,
      shellBackground: Color.lerp(shellBackground, other.shellBackground, t)!,
      panelBackground: Color.lerp(panelBackground, other.panelBackground, t)!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      elevatedCardBackground: Color.lerp(
        elevatedCardBackground,
        other.elevatedCardBackground,
        t,
      )!,
      mutedBackground: Color.lerp(mutedBackground, other.mutedBackground, t)!,
      inputBackground: Color.lerp(inputBackground, other.inputBackground, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
      primaryAccent: Color.lerp(primaryAccent, other.primaryAccent, t)!,
      secondaryAccent:
          Color.lerp(secondaryAccent, other.secondaryAccent, t)!,
      dangerAccent: Color.lerp(dangerAccent, other.dangerAccent, t)!,
      warningAccent: Color.lerp(warningAccent, other.warningAccent, t)!,
      iconMuted: Color.lerp(iconMuted, other.iconMuted, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      successContainer:
          Color.lerp(successContainer, other.successContainer, t)!,
      warningContainer:
          Color.lerp(warningContainer, other.warningContainer, t)!,
      errorContainer: Color.lerp(errorContainer, other.errorContainer, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      hoverBackground:
          Color.lerp(hoverBackground, other.hoverBackground, t)!,
      selectedBackground:
          Color.lerp(selectedBackground, other.selectedBackground, t)!,
      disabledBackground:
          Color.lerp(disabledBackground, other.disabledBackground, t)!,
      disabledText: Color.lerp(disabledText, other.disabledText, t)!,
      tableHeaderBackground:
          Color.lerp(tableHeaderBackground, other.tableHeaderBackground, t)!,
      listItemHoverBackground: Color.lerp(
        listItemHoverBackground,
        other.listItemHoverBackground,
        t,
      )!,
      overlayScrim: Color.lerp(overlayScrim, other.overlayScrim, t)!,
      primaryHeaderGradient: LinearGradient.lerp(
        primaryHeaderGradient,
        other.primaryHeaderGradient,
        t,
      )!,
      subtleHeaderGradient: LinearGradient.lerp(
        subtleHeaderGradient,
        other.subtleHeaderGradient,
        t,
      )!,
      chartPalette: _lerpColorList(chartPalette, other.chartPalette, t),
      cardShadow: _lerpShadowList(cardShadow, other.cardShadow, t),
      elevatedShadow: _lerpShadowList(elevatedShadow, other.elevatedShadow, t),
      borderRadius: lerpDouble(borderRadius, other.borderRadius, t)!,
      smallBorderRadius:
          lerpDouble(smallBorderRadius, other.smallBorderRadius, t)!,
      cardElevation: lerpDouble(cardElevation, other.cardElevation, t)!,
    );
  }

  static List<Color> _lerpColorList(List<Color> a, List<Color> b, double t) {
    final length = a.length > b.length ? a.length : b.length;
    return List<Color>.generate(length, (index) {
      final from = index < a.length ? a[index] : a.last;
      final to = index < b.length ? b[index] : b.last;
      return Color.lerp(from, to, t)!;
    });
  }

  static List<BoxShadow> _lerpShadowList(
    List<BoxShadow> a,
    List<BoxShadow> b,
    double t,
  ) {
    final length = a.length > b.length ? a.length : b.length;
    return List<BoxShadow>.generate(length, (index) {
      final from = index < a.length ? a[index] : a.last;
      final to = index < b.length ? b[index] : b.last;
      return BoxShadow.lerp(from, to, t)!;
    });
  }
}
