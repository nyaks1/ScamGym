import 'package:flutter/material.dart';

abstract final class AppColors {
  static const bg = Color(0xFF070B09);
  static const panel = Color(0xFF0E1511);
  static const panel2 = Color(0xFF131D17);
  static const panel3 = Color(0xFF18241C);
  static const line = Color(0xFF24352B);
  static const lineSoft = Color(0xFF1B2A21);
  static const text = Color(0xFFE9F2EB);
  static const muted = Color(0xFF96AB9E);
  static const muted2 = Color(0xFF6F8579);
  static const lime = Color(0xFFB7F36B);
  static const limeDim = Color(0xFF7FB84A);
  static const amber = Color(0xFFFFC266);
  static const orange = Color(0xFFFF9B5C);
  static const red = Color(0xFFFF7A7A);
  static const sky = Color(0xFF7BD4FF);
  static const violet = Color(0xFFC7A6FF);
  static const rose = Color(0xFFFF9AB5);
}

const kMono = TextStyle(fontFamily: 'ScamGymMono');
const kMonoSmall = TextStyle(
  fontFamily: 'ScamGymMono',
  fontSize: 10.5,
  letterSpacing: 1.1,
  fontWeight: FontWeight.w700,
);

ThemeData buildScamGymTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.lime,
      onPrimary: Color(0xFF071006),
      secondary: AppColors.amber,
      onSecondary: Color(0xFF1A1200),
      surface: AppColors.panel,
      onSurface: AppColors.text,
      error: AppColors.red,
      onError: Color(0xFF2A0808),
      outline: AppColors.line,
    ),
    scaffoldBackgroundColor: AppColors.bg,
    fontFamily: 'ScamGymSans',
  );

  final textTheme = base.textTheme
      .apply(bodyColor: AppColors.text, displayColor: AppColors.text)
      .copyWith(
        displaySmall: const TextStyle(
          fontSize: 40,
          height: 1.05,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.6,
        ),
        headlineMedium: const TextStyle(
          fontSize: 30,
          height: 1.1,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.1,
        ),
        headlineSmall: const TextStyle(
          fontSize: 23,
          height: 1.15,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.7,
        ),
        titleLarge: const TextStyle(
          fontSize: 19,
          height: 1.2,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleMedium: const TextStyle(
          fontSize: 15,
          height: 1.3,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: const TextStyle(fontSize: 16, height: 1.55, color: AppColors.text),
        bodyMedium: const TextStyle(fontSize: 14.5, height: 1.55, color: AppColors.text),
        bodySmall: const TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.muted),
        labelLarge: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        labelSmall: const TextStyle(
          fontFamily: 'ScamGymMono',
          fontSize: 10,
          letterSpacing: 1.3,
          fontWeight: FontWeight.w700,
          color: AppColors.muted,
        ),
      );

  return base.copyWith(
    textTheme: textTheme,
    dividerColor: AppColors.lineSoft,
    dividerTheme: const DividerThemeData(color: AppColors.lineSoft, thickness: 1, space: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.panel3,
      contentTextStyle: const TextStyle(color: AppColors.text, fontSize: 13.5),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.lime),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.panel3,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      textStyle: const TextStyle(color: AppColors.text, fontSize: 12),
    ),
  );
}

InputDecoration scamInput({
  String? hint,
  String? label,
  Widget? suffix,
  int? maxLines = 1,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: AppColors.line),
  );
  return InputDecoration(
    hintText: hint,
    labelText: label,
    suffixIcon: suffix,
    filled: true,
    fillColor: AppColors.bg,
    hintStyle: const TextStyle(color: AppColors.muted2, fontSize: 13.5),
    labelStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: const BorderSide(color: AppColors.lime, width: 1.4),
    ),
  );
}

ButtonStyle get primaryButtonStyle => FilledButton.styleFrom(
      backgroundColor: AppColors.lime,
      foregroundColor: const Color(0xFF071006),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      shape: const StadiumBorder(),
      textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
    );

ButtonStyle get secondaryButtonStyle => OutlinedButton.styleFrom(
      foregroundColor: AppColors.text,
      side: const BorderSide(color: AppColors.line),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: const StadiumBorder(),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    );

ButtonStyle get dangerButtonStyle => FilledButton.styleFrom(
      backgroundColor: AppColors.red.withValues(alpha: 0.14),
      foregroundColor: const Color(0xFFFFC0C0),
      side: BorderSide(color: AppColors.red.withValues(alpha: 0.45)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: const StadiumBorder(),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    );

Color scoreColor(int score) {
  if (score >= 80) return AppColors.lime;
  if (score >= 60) return AppColors.amber;
  if (score >= 40) return AppColors.orange;
  return AppColors.red;
}

Color verdictColor(String verdict) {
  switch (verdict) {
    case 'low':
      return AppColors.lime;
    case 'caution':
      return AppColors.amber;
    case 'high':
      return AppColors.orange;
    case 'critical':
      return AppColors.red;
    case 'demo':
      return AppColors.sky;
    default:
      return AppColors.muted;
  }
}

Color severityColor(String severity) {
  switch (severity) {
    case 'high':
      return AppColors.red;
    case 'medium':
      return AppColors.amber;
    default:
      return AppColors.muted2;
  }
}

Color accentColor(String key) {
  switch (key) {
    case 'amber':
      return AppColors.amber;
    case 'sky':
      return AppColors.sky;
    case 'rose':
      return AppColors.rose;
    case 'violet':
      return AppColors.violet;
    default:
      return AppColors.lime;
  }
}
