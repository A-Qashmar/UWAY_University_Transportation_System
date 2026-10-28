import 'package:flutter/material.dart';

/// UWAY visual identity: warm cream surfaces, deep purple actions and a gold
/// accent, with an optional purple mode that swaps the two (Passenger), and a
/// deep-green look matching the admin dashboard with an inverted mode (Driver).
class UwayColors {
  const UwayColors._();

  static const background = Color(0xFFFBF6EC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceHigh = Color(0xFFF4EEE0);
  static const outline = Color(0xFFE3D9C4);
  static const purple = Color(0xFF6B4FB5);
  static const purpleDark = Color(0xFF4F3A96);
  static const gold = Color(0xFFDDAE46);
  static const goldLight = Color(0xFFF3E6A8);
  static const onGold = Color(0xFF2A1B4D);
  static const text = Color(0xFF241A3F);
  static const textMuted = Color(0xFF6C6387);
  static const success = Color(0xFF1E8E6A);
  static const warning = Color(0xFFB4741A);
  static const danger = Color(0xFFC0392B);

  // Purple mode: purple becomes the dominant colour and cream takes the role
  // purple has in the default (cream) look.
  static const purpleModeBackground = Color(0xFF33215F);
  static const purpleModeSurface = Color(0xFF40306F);
  static const purpleModeSurfaceHigh = Color(0xFF4C3A82);
  static const purpleModeOutline = Color(0xFF6B5AA0);
  static const cream = Color(0xFFF4E9CF);
  static const creamText = Color(0xFFF7F0E0);
  static const creamMuted = Color(0xFFC8BCE0);

  // Driver look: the admin dashboard's deep green with soft mint surfaces.
  static const driverGreen = Color(0xFF176B66);
  static const driverGreenDeep = Color(0xFF123E42);
  static const driverBackground = Color(0xFFE4EFEC);
  static const driverSurfaceHigh = Color(0xFFD2E4DF);
  static const driverOutline = Color(0xFFB3CEC8);
  static const driverText = Color(0xFF123E42);
  static const driverMuted = Color(0xFF4A6D6A);
  // Inverted: dark green surfaces, cream as the main colour.
  static const driverInvBackground = Color(0xFF0E2F2C);
  static const driverInvSurface = Color(0xFF173F3B);
  static const driverInvSurfaceHigh = Color(0xFF1F4F4A);
  static const driverInvOutline = Color(0xFF2E6761);
  static const driverInvAppBar = Color(0xFF0A2523);
}

/// Whether Passenger screens use the purple look. Set from Account. It is kept
/// in memory only for now, so it resets when the app restarts.
final ValueNotifier<bool> uwayPurpleMode = ValueNotifier<bool>(false);

/// Whether Driver screens use the inverted (dark green and cream) look.
final ValueNotifier<bool> uwayDriverInverted = ValueNotifier<bool>(false);

/// Status colours that stay readable on both the cream and the purple look.
extension UwaySemanticColors on BuildContext {
  bool get _isDark => Theme.of(this).brightness == Brightness.dark;
  Color get uwaySuccess =>
      _isDark ? const Color(0xFF4FD1A5) : UwayColors.success;
  Color get uwayWarning =>
      _isDark ? const Color(0xFFF2B24C) : UwayColors.warning;
  Color get uwayDanger =>
      _isDark ? const Color(0xFFFF8A80) : UwayColors.danger;
}

class UwayTheme {
  const UwayTheme._();

  static ThemeData passenger({bool purpleMode = false}) => _themed(
        dark: purpleMode,
        background:
            purpleMode ? UwayColors.purpleModeBackground : UwayColors.background,
        surface: purpleMode ? UwayColors.purpleModeSurface : UwayColors.surface,
        surfaceHigh: purpleMode
            ? UwayColors.purpleModeSurfaceHigh
            : UwayColors.surfaceHigh,
        outline: purpleMode ? UwayColors.purpleModeOutline : UwayColors.outline,
        primary: purpleMode ? UwayColors.cream : UwayColors.purple,
        onPrimary: purpleMode ? UwayColors.purpleDark : Colors.white,
        text: purpleMode ? UwayColors.creamText : UwayColors.text,
        muted: purpleMode ? UwayColors.creamMuted : UwayColors.textMuted,
        appBarBackground: purpleMode
            ? UwayColors.purpleModeBackground
            : UwayColors.background,
        appBarForeground: purpleMode ? UwayColors.creamText : UwayColors.text,
        snackBackground:
            purpleMode ? UwayColors.purpleModeSurfaceHigh : UwayColors.purpleDark,
        snackText: purpleMode ? UwayColors.creamText : Colors.white,
      );

  static ThemeData driver({bool inverted = false}) => _themed(
        dark: inverted,
        background: inverted
            ? UwayColors.driverInvBackground
            : UwayColors.driverBackground,
        surface: inverted ? UwayColors.driverInvSurface : Colors.white,
        surfaceHigh: inverted
            ? UwayColors.driverInvSurfaceHigh
            : UwayColors.driverSurfaceHigh,
        outline:
            inverted ? UwayColors.driverInvOutline : UwayColors.driverOutline,
        primary: inverted ? UwayColors.cream : UwayColors.driverGreen,
        onPrimary: inverted ? UwayColors.driverGreenDeep : Colors.white,
        text: inverted ? UwayColors.creamText : UwayColors.driverText,
        muted: inverted ? const Color(0xFFA9CBC5) : UwayColors.driverMuted,
        // The dark bar carries the gold logo, like the admin sidebar.
        appBarBackground: inverted
            ? UwayColors.driverInvAppBar
            : UwayColors.driverGreenDeep,
        appBarForeground: UwayColors.creamText,
        snackBackground: UwayColors.driverGreenDeep,
        snackText: Colors.white,
      );

  static ThemeData _themed({
    required bool dark,
    required Color background,
    required Color surface,
    required Color surfaceHigh,
    required Color outline,
    required Color primary,
    required Color onPrimary,
    required Color text,
    required Color muted,
    required Color appBarBackground,
    required Color appBarForeground,
    required Color snackBackground,
    required Color snackText,
  }) {
    final scheme = ColorScheme(
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: primary,
      onPrimary: onPrimary,
      secondary: UwayColors.gold,
      onSecondary: UwayColors.onGold,
      error: dark ? const Color(0xFFFF8A80) : UwayColors.danger,
      onError: dark ? UwayColors.onGold : Colors.white,
      surface: surface,
      onSurface: text,
      onSurfaceVariant: muted,
      outline: outline,
      outlineVariant: outline,
      surfaceContainerHighest: surfaceHigh,
    );
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: background,
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: text, displayColor: text),
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBackground,
        foregroundColor: appBarForeground,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: UwayColors.gold.withValues(alpha: 0.26),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? primary : muted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? primary : muted,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(18)),
          side: BorderSide(color: outline),
        ),
      ),
      dividerTheme: DividerThemeData(color: outline),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size.fromHeight(50),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary),
          minimumSize: const Size.fromHeight(48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: outline),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: primary.withValues(alpha: 0.18),
        side: BorderSide(color: outline),
        labelStyle: TextStyle(color: text),
        checkmarkColor: primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primary
              : muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primary.withValues(alpha: 0.35)
              : outline,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: snackBackground,
        contentTextStyle: TextStyle(color: snackText),
      ),
    );
  }
}
