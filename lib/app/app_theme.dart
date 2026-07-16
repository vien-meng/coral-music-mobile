import 'package:flutter/material.dart';

abstract final class CoralPalette {
  static const mint = Color(0xff2ad4d7);
  static const cyan = Color(0xffa7e7e3);
  static const sky = Color(0xffc6f0ff);
  static const periwinkle = Color(0xffc1d6ff);
  static const lilac = Color(0xffd9c8ff);
  static const pink = Color(0xffffc3e6);
  static const peach = Color(0xffffdac7);
  static const ink = Color(0xff252746);
  static const muted = Color(0xff8e8fa4);
  static const surface = Color(0xfffbfbff);
  static const page = Color(0xfff4f8ff);
  static const player = Color(0xff8462e9);
}

const coralPageGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xffffffff), CoralPalette.page, Color(0xfffdfaff)],
);

ThemeData coralTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    brightness: brightness,
    seedColor: CoralPalette.mint,
  ).copyWith(
    primary: dark ? const Color(0xff7ee8e9) : CoralPalette.mint,
    secondary: dark ? const Color(0xffcbbdff) : CoralPalette.player,
    surface: dark ? const Color(0xff1f2030) : CoralPalette.surface,
    onSurface: dark ? const Color(0xfff1efff) : CoralPalette.ink,
    onSurfaceVariant: dark ? const Color(0xffc6c4d6) : CoralPalette.muted,
    outlineVariant: dark ? const Color(0xff3a3b50) : const Color(0xffe9eaf2),
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: dark ? const Color(0xff191a28) : CoralPalette.page,
    fontFamily: 'PingFang SC',
    textTheme: Typography.material2021().black.apply(
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
        ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color:
          dark ? const Color(0xff28293a) : Colors.white.withValues(alpha: .86),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor:
          dark ? const Color(0xff2a2b3d) : Colors.white.withValues(alpha: .78),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide:
            BorderSide(color: scheme.outlineVariant.withValues(alpha: .56)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: CoralPalette.mint, width: 1.5),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: dark
          ? const Color(0xff232435).withValues(alpha: .94)
          : Colors.white.withValues(alpha: .88),
      indicatorColor: dark
          ? CoralPalette.player.withValues(alpha: .42)
          : CoralPalette.lilac.withValues(alpha: .64),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? (dark ? CoralPalette.mint : CoralPalette.player)
              : scheme.onSurfaceVariant,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? (dark ? CoralPalette.mint : CoralPalette.player)
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    dividerTheme:
        DividerThemeData(color: scheme.outlineVariant.withValues(alpha: .72)),
  );
}
