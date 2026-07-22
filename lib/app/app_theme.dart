import 'package:flutter/material.dart';

abstract final class CoralPalette {
  static const brand = Color(0xffff6b6b);
  static const mint = Color(0xffff928b);
  static const cyan = Color(0xffffe6e1);
  static const sky = Color(0xfffff1ed);
  static const periwinkle = Color(0xffffebe6);
  static const lilac = Color(0xfffff3ef);
  static const pink = Color(0xffffeeea);
  static const peach = Color(0xffffe5dc);
  static const ink = Color(0xff20242a);
  static const muted = Color(0xff929094);
  static const surface = Color(0xffffffff);
  static const page = Color(0xfffffbfa);
  // A low-saturation coral outline keeps every module tied to the brand
  // without turning the warm-white layout into a grid of heavy boxes.
  static const border = Color(0xffffd8d2);
  static const player = Color(0xffff6b6b);
}

LinearGradient coralPageGradientOf(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [scheme.surface, Theme.of(context).scaffoldBackgroundColor],
  );
}

ThemeData coralTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final surface = dark ? const Color(0xff1f2030) : CoralPalette.surface;
  final primary = dark ? const Color(0xffff9b93) : CoralPalette.brand;
  // Keep outlines attached to the active brand rather than a neutral gray.
  // This is deliberately subtle: it is a module separator, not a second CTA.
  final moduleOutline = Color.alphaBlend(
    primary.withValues(alpha: dark ? .38 : .25),
    surface,
  );
  final scheme = ColorScheme.fromSeed(
    brightness: brightness,
    seedColor: CoralPalette.mint,
  ).copyWith(
    primary: primary,
    onPrimary: Colors.white,
    primaryContainer: dark ? const Color(0xff3b2929) : CoralPalette.sky,
    onPrimaryContainer: dark ? const Color(0xfff1f1f1) : CoralPalette.ink,
    secondary: dark ? const Color(0xffffcbc5) : CoralPalette.player,
    surface: surface,
    onSurface: dark ? const Color(0xfff1efff) : CoralPalette.ink,
    onSurfaceVariant: dark ? const Color(0xffc6c4d6) : CoralPalette.muted,
    outlineVariant: moduleOutline,
  );
  final textTheme = Typography.material2021().black.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: dark ? const Color(0xff191a28) : CoralPalette.page,
    fontFamily: 'PingFang SC',
    // The reference uses one-pixel-ish line icons. Material Symbols exposes
    // variable weight, so keep the app chrome light and only fill the play CTA.
    iconTheme: IconThemeData(
      color: scheme.onSurfaceVariant,
      weight: 250,
      fill: 0,
    ),
    textTheme: textTheme.copyWith(
      titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 52,
      titleTextStyle: textTheme.titleMedium?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? const Color(0xff28293a) : Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xff2a2b3d) : const Color(0xfffff6f3),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        backgroundColor: scheme.surface.withValues(alpha: .72),
        foregroundColor: scheme.onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 36),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      minVerticalPadding: 8,
      minLeadingWidth: 40,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      backgroundColor: dark ? const Color(0xff232435) : Colors.white,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 10,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide(color: scheme.outlineVariant),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      backgroundColor: Colors.transparent,
      selectedColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xff323347) : const Color(0xff2d2f3b),
      contentTextStyle:
          TextStyle(color: dark ? scheme.onSurface : Colors.white),
      actionTextColor: scheme.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant),
  );
}
