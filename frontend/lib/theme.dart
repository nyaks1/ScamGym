import 'package:flutter/material.dart';

/// Carbon Design System tokens, Gray 100 (dark) theme.
///
/// Values follow the Carbon v11 color tokens:
/// https://carbondesignsystem.com/elements/color/tokens/
abstract final class AppColors {
  // Background and layers
  static const background = Color(0xFF161616);
  static const layer = Color(0xFF262626);
  static const layerHover = Color(0xFF333333);
  static const layerActive = Color(0xFF393939);
  static const layer2 = Color(0xFF393939);
  static const layer3 = Color(0xFF525252);
  static const field = Color(0xFF262626);

  // Borders
  static const borderSubtle = Color(0xFF393939);
  static const borderStrong = Color(0xFF8D8D8D);
  static const borderDisabled = Color(0xFF525252);

  // Type
  static const textPrimary = Color(0xFFF4F4F4);
  static const textSecondary = Color(0xFFC6C6C6);
  static const textHelper = Color(0xFF8D8D8D);
  static const textPlaceholder = Color(0xFF6F6F6F);
  static const textDisabled = Color(0xFF6F6F6F);

  // Interactive
  static const interactive = Color(0xFF4589FF);
  static const interactiveHover = Color(0xFF78A9FF);
  static const buttonPrimary = Color(0xFF0F62FE);
  static const buttonPrimaryHover = Color(0xFF0050E6);
  static const buttonPrimaryActive = Color(0xFF002D9C);
  static const link = Color(0xFF78A9FF);
  static const focus = Color(0xFFFFFFFF);

  // Support
  static const supportError = Color(0xFFFA4D56);
  static const supportWarning = Color(0xFFF1C21B);
  static const supportCaution = Color(0xFFFF832B);
  static const supportSuccess = Color(0xFF42BE65);
  static const supportInfo = Color(0xFF4589FF);
  static const danger = Color(0xFFDA1E28);
  static const dangerHover = Color(0xFFBA1B23);
  static const purple = Color(0xFFBE95FF);
  static const magenta = Color(0xFFFF7EB6);

  // Legacy aliases kept so existing widgets read naturally.
  static const bg = background;
  static const panel = layer;
  static const panel2 = layer2;
  static const panel3 = layer3;
  static const line = borderSubtle;
  static const lineSoft = borderSubtle;
  static const text = textPrimary;
  static const muted = textSecondary;
  static const muted2 = textHelper;
  static const lime = supportSuccess;
  static const limeDim = supportSuccess;
  static const amber = supportWarning;
  static const orange = supportCaution;
  static const red = supportError;
  static const sky = supportInfo;
  static const violet = purple;
  static const rose = magenta;
}

const kMono = TextStyle(
  fontFamily: 'IBMPlexMono',
  fontSize: 12,
  height: 1.34,
  letterSpacing: 0.32,
);

const kMonoSmall = TextStyle(
  fontFamily: 'IBMPlexMono',
  fontSize: 12,
  height: 1.34,
  letterSpacing: 0.32,
  fontWeight: FontWeight.w600,
);

TextStyle _sans({
  double size = 14,
  double height = 1.43,
  FontWeight weight = FontWeight.w400,
  double spacing = 0,
  Color color = AppColors.textPrimary,
}) {
  return TextStyle(
    fontFamily: 'IBMPlexSans',
    fontSize: size,
    height: height,
    fontWeight: weight,
    letterSpacing: spacing,
    color: color,
  );
}

ThemeData buildScamGymTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.buttonPrimary,
      onPrimary: Colors.white,
      secondary: AppColors.interactive,
      onSecondary: Colors.white,
      surface: AppColors.layer,
      onSurface: AppColors.textPrimary,
      error: AppColors.supportError,
      onError: Colors.white,
      outline: AppColors.borderSubtle,
      outlineVariant: AppColors.borderSubtle,
      surfaceContainerHighest: AppColors.layer2,
    ),
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    cardColor: AppColors.layer,
    fontFamily: 'IBMPlexSans',
    splashFactory: NoSplash.splashFactory,
  );

  final textTheme = base.textTheme
      .apply(
        fontFamily: 'IBMPlexSans',
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      )
      .copyWith(
        displaySmall: _sans(size: 42, height: 1.19, weight: FontWeight.w300),
        headlineMedium: _sans(size: 28, height: 1.29, weight: FontWeight.w400),
        headlineSmall: _sans(size: 20, height: 1.4, weight: FontWeight.w400),
        titleLarge: _sans(size: 16, height: 1.375, weight: FontWeight.w600),
        titleMedium: _sans(size: 14, height: 1.43, weight: FontWeight.w600),
        titleSmall: _sans(
          size: 14,
          height: 1.43,
          weight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
        bodyLarge: _sans(size: 16, height: 1.5),
        bodyMedium: _sans(size: 14, height: 1.43),
        bodySmall: _sans(size: 12, height: 1.34, color: AppColors.textHelper),
        labelLarge: _sans(size: 14, height: 1.29),
        labelMedium: _sans(size: 12, height: 1.34, color: AppColors.textHelper),
        labelSmall: _sans(
          size: 12,
          height: 1.34,
          spacing: 0.32,
          color: AppColors.textHelper,
        ),
      );

  return base.copyWith(
    textTheme: textTheme,
    dividerColor: AppColors.borderSubtle,
    dividerTheme: const DividerThemeData(
      color: AppColors.borderSubtle,
      thickness: 1,
      space: 1,
    ),
    iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 20),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.layer,
      actionTextColor: AppColors.interactiveHover,
      contentTextStyle: _sans(size: 14, color: AppColors.textPrimary),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      insetPadding: const EdgeInsets.all(16),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.interactive,
      linearTrackColor: AppColors.borderSubtle,
      circularTrackColor: AppColors.borderSubtle,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: const BoxDecoration(
        color: AppColors.layer,
        border: Border.fromBorderSide(
          BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      textStyle: _sans(size: 12, color: AppColors.textPrimary),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      waitDuration: const Duration(milliseconds: 300),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.layer,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      titleTextStyle: _sans(size: 20, height: 1.4),
      contentTextStyle: _sans(size: 14, color: AppColors.textSecondary),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      insetPadding: const EdgeInsets.all(24),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.focus,
      selectionColor: Color(0x664589FF),
      selectionHandleColor: AppColors.interactive,
    ),
    scrollbarTheme: const ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(AppColors.layer3),
      thickness: WidgetStatePropertyAll(6),
      radius: Radius.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.field,
      isDense: true,
      hintStyle: _sans(size: 14, color: AppColors.textHelper),
      labelStyle: _sans(size: 12, color: AppColors.textSecondary),
      helperStyle: _sans(size: 12, color: AppColors.textHelper),
      errorStyle: _sans(size: 12, color: AppColors.supportError),
      contentPadding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
      border: _underline(AppColors.borderStrong),
      enabledBorder: _underline(AppColors.borderStrong),
      focusedBorder: _underline(AppColors.focus, width: 2),
      errorBorder: _underline(AppColors.supportError),
      focusedErrorBorder: _underline(AppColors.supportError, width: 2),
      disabledBorder: _underline(AppColors.borderDisabled),
    ),
    filledButtonTheme: FilledButtonThemeData(style: primaryButtonStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(style: secondaryButtonStyle),
    textButtonTheme: TextButtonThemeData(style: ghostButtonStyle),
  );
}

UnderlineInputBorder _underline(Color color, {double width = 1}) {
  return UnderlineInputBorder(
    borderSide: BorderSide(color: color, width: width),
    borderRadius: BorderRadius.zero,
  );
}

InputDecoration scamInput({
  String? hint,
  String? label,
  Widget? suffix,
  int? maxLines = 1,
}) {
  return InputDecoration(
    hintText: hint,
    labelText: label,
    suffixIcon: suffix,
    filled: true,
    fillColor: AppColors.field,
    hintStyle: _sans(size: 14, color: AppColors.textHelper),
    labelStyle: _sans(size: 12, color: AppColors.textSecondary),
    floatingLabelBehavior: FloatingLabelBehavior.never,
    contentPadding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
    border: _underline(AppColors.borderStrong),
    enabledBorder: _underline(AppColors.borderStrong),
    focusedBorder: _underline(AppColors.focus, width: 2),
    errorBorder: _underline(AppColors.supportError),
    focusedErrorBorder: _underline(AppColors.supportError, width: 2),
    disabledBorder: _underline(AppColors.borderDisabled),
  );
}

ButtonStyle get primaryButtonStyle => ButtonStyle(
  backgroundColor: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) return AppColors.layer2;
    if (states.contains(WidgetState.pressed)) {
      return AppColors.buttonPrimaryActive;
    }
    if (states.contains(WidgetState.hovered)) {
      return AppColors.buttonPrimaryHover;
    }
    return AppColors.buttonPrimary;
  }),
  side: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.focused)) {
      return const BorderSide(color: AppColors.focus, width: 2);
    }
    return BorderSide.none;
  }),
  foregroundColor: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) return AppColors.textDisabled;
    return Colors.white;
  }),
  overlayColor: const WidgetStatePropertyAll(Colors.transparent),
  padding: const WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: 16, vertical: 0),
  ),
  minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  shape: const WidgetStatePropertyAll(
    RoundedRectangleBorder(borderRadius: BorderRadius.zero),
  ),
  elevation: const WidgetStatePropertyAll(0),
  animationDuration: const Duration(milliseconds: 110),
  textStyle: const WidgetStatePropertyAll(
    TextStyle(
      fontFamily: 'IBMPlexSans',
      fontSize: 14,
      height: 1.29,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.16,
    ),
  ),
);

ButtonStyle get secondaryButtonStyle => ButtonStyle(
  backgroundColor: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.pressed)) return AppColors.layerActive;
    if (states.contains(WidgetState.hovered)) return AppColors.layerHover;
    return Colors.transparent;
  }),
  foregroundColor: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) return AppColors.textDisabled;
    return AppColors.textPrimary;
  }),
  overlayColor: const WidgetStatePropertyAll(Colors.transparent),
  side: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.focused)) {
      return const BorderSide(color: AppColors.focus, width: 2);
    }
    final color = states.contains(WidgetState.disabled)
        ? AppColors.borderDisabled
        : AppColors.textPrimary;
    return BorderSide(color: color, width: 1);
  }),
  padding: const WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: 16, vertical: 0),
  ),
  minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  shape: const WidgetStatePropertyAll(
    RoundedRectangleBorder(borderRadius: BorderRadius.zero),
  ),
  elevation: const WidgetStatePropertyAll(0),
  animationDuration: const Duration(milliseconds: 110),
  textStyle: const WidgetStatePropertyAll(
    TextStyle(
      fontFamily: 'IBMPlexSans',
      fontSize: 14,
      height: 1.29,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.16,
    ),
  ),
);

ButtonStyle get ghostButtonStyle => ButtonStyle(
  backgroundColor: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.pressed)) return AppColors.layerActive;
    if (states.contains(WidgetState.hovered)) return AppColors.layerHover;
    return Colors.transparent;
  }),
  foregroundColor: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) return AppColors.textDisabled;
    return AppColors.link;
  }),
  side: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.focused)) {
      return const BorderSide(color: AppColors.focus, width: 2);
    }
    return BorderSide.none;
  }),
  overlayColor: const WidgetStatePropertyAll(Colors.transparent),
  padding: const WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: 16, vertical: 0),
  ),
  minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  shape: const WidgetStatePropertyAll(
    RoundedRectangleBorder(borderRadius: BorderRadius.zero),
  ),
  elevation: const WidgetStatePropertyAll(0),
  animationDuration: const Duration(milliseconds: 110),
  textStyle: const WidgetStatePropertyAll(
    TextStyle(
      fontFamily: 'IBMPlexSans',
      fontSize: 14,
      height: 1.29,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.16,
    ),
  ),
);

ButtonStyle get dangerButtonStyle => ButtonStyle(
  backgroundColor: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) return AppColors.layer2;
    if (states.contains(WidgetState.hovered)) return AppColors.dangerHover;
    return AppColors.danger;
  }),
  side: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.focused)) {
      return const BorderSide(color: AppColors.focus, width: 2);
    }
    return BorderSide.none;
  }),
  foregroundColor: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) return AppColors.textDisabled;
    return Colors.white;
  }),
  overlayColor: const WidgetStatePropertyAll(Colors.transparent),
  padding: const WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: 16, vertical: 0),
  ),
  minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  shape: const WidgetStatePropertyAll(
    RoundedRectangleBorder(borderRadius: BorderRadius.zero),
  ),
  elevation: const WidgetStatePropertyAll(0),
  animationDuration: const Duration(milliseconds: 110),
  textStyle: const WidgetStatePropertyAll(
    TextStyle(
      fontFamily: 'IBMPlexSans',
      fontSize: 14,
      height: 1.29,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.16,
    ),
  ),
);

/// Returns 0 when disabled, otherwise the Carbon icon-button hover layer.
Color iconButtonOverlay(Set<WidgetState> states) {
  if (states.contains(WidgetState.pressed)) return AppColors.layerActive;
  if (states.contains(WidgetState.hovered)) return AppColors.layerHover;
  return Colors.transparent;
}

Color scoreColor(int score) {
  if (score >= 80) return AppColors.supportSuccess;
  if (score >= 60) return AppColors.supportWarning;
  if (score >= 40) return AppColors.supportCaution;
  return AppColors.supportError;
}

Color verdictColor(String verdict) {
  switch (verdict) {
    case 'low':
      return AppColors.supportSuccess;
    case 'caution':
      return AppColors.supportWarning;
    case 'high':
      return AppColors.supportCaution;
    case 'critical':
      return AppColors.supportError;
    case 'demo':
      return AppColors.supportInfo;
    default:
      return AppColors.textHelper;
  }
}

Color severityColor(String severity) {
  switch (severity) {
    case 'high':
      return AppColors.supportError;
    case 'medium':
      return AppColors.supportWarning;
    default:
      return AppColors.textHelper;
  }
}

Color accentColor(String key) {
  switch (key) {
    case 'amber':
      return AppColors.supportWarning;
    case 'sky':
      return AppColors.supportInfo;
    case 'rose':
      return AppColors.magenta;
    case 'violet':
      return AppColors.purple;
    case 'lime':
      return AppColors.supportSuccess;
    default:
      return AppColors.interactive;
  }
}
