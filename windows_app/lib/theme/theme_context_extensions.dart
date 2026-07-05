import 'package:flutter/material.dart';

import 'app_theme_tokens.dart';

export 'app_theme_tokens.dart';

extension ThemeContextExtensions on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => theme.colorScheme;
  AppThemeTokens get tokens {
    final tokens = theme.extension<AppThemeTokens>();
    assert(tokens != null, 'AppThemeTokens is not registered on ThemeData');
    return tokens!;
  }
}
