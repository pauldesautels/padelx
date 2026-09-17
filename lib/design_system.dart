import 'package:flutter/material.dart';

/// PadelX's dark-first visual language. Bright brand green is deliberately an
/// accent; large surfaces and routine actions use deeper athletic greens.
abstract final class PadelXColors {
  static const background = Color(0xFF06110E);
  static const surface = Color(0xFF0D1B17);
  static const surfaceStrong = Color(0xFF142720);
  static const surfaceRaised = Color(0xFF193027);
  static const border = Color(0xFF29453A);
  static const textPrimary = Color(0xFFF2F7F4);
  static const textSecondary = Color(0xFFA8B8B1);
  static const accent = Color(0xFF72F58B);
  static const primaryAction = Color(0xFF238A57);
  static const primaryActionPressed = Color(0xFF1B7047);
  static const success = Color(0xFF62D993);
  static const warning = Color(0xFFF0B35C);
  static const destructive = Color(0xFFE47772);
  static const teamOne = Color(0xFF5CC8FF);
  static const teamTwo = Color(0xFFE7A6FF);
}

abstract final class PadelXSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class PadelXRadii {
  static const input = 12.0;
  static const card = 16.0;
  static const feature = 22.0;
  static const chip = 10.0;
}

ThemeData buildPadelXTheme() {
  const scheme = ColorScheme.dark(
    primary: PadelXColors.accent,
    onPrimary: Color(0xFF05200F),
    primaryContainer: PadelXColors.primaryAction,
    onPrimaryContainer: Colors.white,
    secondary: PadelXColors.teamOne,
    onSecondary: Color(0xFF06141B),
    secondaryContainer: Color(0xFF183D48),
    onSecondaryContainer: PadelXColors.textPrimary,
    tertiary: PadelXColors.teamTwo,
    onTertiary: Color(0xFF211025),
    error: PadelXColors.destructive,
    onError: Color(0xFF2C0706),
    surface: PadelXColors.surface,
    onSurface: PadelXColors.textPrimary,
    onSurfaceVariant: PadelXColors.textSecondary,
    outline: PadelXColors.border,
  );
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
  final text = base.textTheme
      .copyWith(
        displaySmall: const TextStyle(
          fontSize: 34,
          height: 1.05,
          fontWeight: FontWeight.w800,
        ),
        headlineMedium: const TextStyle(
          fontSize: 26,
          height: 1.12,
          fontWeight: FontWeight.w800,
        ),
        headlineSmall: const TextStyle(
          fontSize: 22,
          height: 1.15,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: const TextStyle(
          fontSize: 20,
          height: 1.2,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: const TextStyle(
          fontSize: 16,
          height: 1.25,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: const TextStyle(fontSize: 16, height: 1.4),
        bodyMedium: const TextStyle(fontSize: 14, height: 1.4),
        bodySmall: const TextStyle(
          fontSize: 12,
          height: 1.35,
          color: PadelXColors.textSecondary,
        ),
        labelLarge: const TextStyle(
          fontSize: 15,
          height: 1.1,
          fontWeight: FontWeight.w700,
        ),
        labelMedium: const TextStyle(
          fontSize: 12,
          height: 1.1,
          fontWeight: FontWeight.w600,
        ),
      )
      .apply(
        bodyColor: PadelXColors.textPrimary,
        displayColor: PadelXColors.textPrimary,
      );
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: PadelXColors.background,
    textTheme: text,
    appBarTheme: const AppBarTheme(
      backgroundColor: PadelXColors.background,
      foregroundColor: PadelXColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: PadelXColors.textPrimary,
      ),
    ),
    cardTheme: CardThemeData(
      color: PadelXColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PadelXRadii.card),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: PadelXColors.border,
      thickness: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: PadelXColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PadelXRadii.input),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PadelXRadii.input),
        borderSide: const BorderSide(color: PadelXColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PadelXRadii.input),
        borderSide: const BorderSide(color: PadelXColors.accent, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: PadelXColors.primaryAction,
        foregroundColor: Colors.white,
        disabledBackgroundColor: PadelXColors.surfaceRaised,
        disabledForegroundColor: PadelXColors.textSecondary,
        minimumSize: const Size(48, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PadelXRadii.input),
        ),
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: PadelXColors.textPrimary,
        side: const BorderSide(color: PadelXColors.border),
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PadelXRadii.input),
        ),
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: PadelXColors.accent,
        textStyle: text.labelLarge,
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: PadelXColors.surfaceStrong,
      selectedColor: const Color(0xFF204B36),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PadelXRadii.chip),
      ),
      labelStyle: text.labelMedium,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: PadelXColors.surface,
      indicatorColor: const Color(0xFF204B36),
      elevation: 0,
      labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: PadelXColors.surfaceStrong,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PadelXRadii.feature),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: PadelXColors.surfaceStrong,
      modalBackgroundColor: PadelXColors.surfaceStrong,
      showDragHandle: true,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: PadelXColors.accent,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: PadelXColors.surfaceRaised,
      contentTextStyle: text.bodyMedium,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PadelXRadii.input),
      ),
    ),
  );
}

class PadelXSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accent;
  final bool strong;
  const PadelXSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.accent,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: strong ? PadelXColors.surfaceStrong : PadelXColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(PadelXRadii.card),
      side: accent == null
          ? BorderSide.none
          : BorderSide(color: accent!, width: 1.5),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding, child: child),
  );
}

class PadelXSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const PadelXSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      if (actionLabel != null && onAction != null)
        TextButton(onPressed: onAction, child: Text(actionLabel!)),
    ],
  );
}

class PadelXMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const PadelXMetric({
    super.key,
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: color ?? PadelXColors.textSecondary),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: PadelXColors.textSecondary),
        ),
      ),
    ],
  );
}
