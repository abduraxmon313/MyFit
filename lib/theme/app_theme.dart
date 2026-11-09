import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Design tokens shared by every screen. Neutral surfaces, deep navy text and
/// a single blue accent; semantic colors are used only where they carry meaning.
abstract final class AppPalette {
  // Brand / accent
  static const navy = Color(0xFF0B1324);
  static const navySoft = Color(0xFF1E293B);
  static const blue = Color(0xFF2F5BEA);
  static const blueSoft = Color(0xFFEEF3FF);
  static const blueDark = Color(0xFF7FA2FF);

  // Neutrals (light)
  static const background = Color(0xFFF7F8FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF3F4F6);
  static const surfaceSunken = Color(0xFFEDEFF3);
  static const border = Color(0xFFE5E7EB);
  static const borderStrong = Color(0xFFD1D5DB);
  static const text = Color(0xFF0B1324);
  static const textSecondary = Color(0xFF5B6475);
  static const textTertiary = Color(0xFF8A93A3);

  // Neutrals (dark)
  static const darkBackground = Color(0xFF0A0D14);
  static const darkSurface = Color(0xFF11151E);
  static const darkSurfaceMuted = Color(0xFF171C27);
  static const darkSurfaceSunken = Color(0xFF1D2330);
  static const darkBorder = Color(0xFF242B38);
  static const darkText = Color(0xFFEEF1F6);
  static const darkTextSecondary = Color(0xFF9AA3B2);

  // Data visualisation (muted, enterprise-friendly)
  static const protein = Color(0xFF3B6FE0);
  static const carbs = Color(0xFFC9892B);
  static const fat = Color(0xFFC2556B);
  static const fiber = Color(0xFF3E8F7A);
  static const success = Color(0xFF16804B);
  static const warning = Color(0xFFB7791F);
  static const danger = Color(0xFFD14343);
}

/// Corner radii. Kept small and consistent across the product.
abstract final class AppRadius {
  static const xs = 6.0;
  static const sm = 8.0;
  static const md = 10.0;
  static const lg = 12.0;
  static const xl = 16.0;
}

abstract final class AppShadows {
  static const card = [
    BoxShadow(color: Color(0x080B1324), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x050B1324), blurRadius: 8, offset: Offset(0, 2)),
  ];
  static const raised = [
    BoxShadow(color: Color(0x0F0B1324), blurRadius: 4, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x140B1324), blurRadius: 24, offset: Offset(0, 10)),
  ];
}

abstract final class AppTheme {
  static const fontFamily = 'Inter';

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static SystemUiOverlayStyle systemOverlay(ThemeData theme) {
    final dark = theme.brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: theme.scaffoldBackgroundColor,
      systemNavigationBarIconBrightness: dark
          ? Brightness.light
          : Brightness.dark,
    );
  }

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final background = dark ? AppPalette.darkBackground : AppPalette.background;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppPalette.blue,
          brightness: brightness,
          surface: dark ? AppPalette.darkBackground : AppPalette.background,
        ).copyWith(
          primary: dark ? AppPalette.blueDark : AppPalette.blue,
          onPrimary: dark ? AppPalette.navy : Colors.white,
          primaryContainer: dark
              ? const Color(0xFF1A2440)
              : AppPalette.blueSoft,
          onPrimaryContainer: dark
              ? const Color(0xFFC9D7FF)
              : const Color(0xFF1B3A9A),
          secondary: dark ? const Color(0xFFB4BDCC) : AppPalette.navySoft,
          onSecondary: dark ? AppPalette.navy : Colors.white,
          secondaryContainer: dark
              ? AppPalette.darkSurfaceSunken
              : AppPalette.surfaceMuted,
          onSecondaryContainer: dark ? AppPalette.darkText : AppPalette.text,
          tertiary: dark ? const Color(0xFF7CC4A8) : AppPalette.success,
          onSurface: dark ? AppPalette.darkText : AppPalette.text,
          onSurfaceVariant: dark
              ? AppPalette.darkTextSecondary
              : AppPalette.textSecondary,
          surfaceContainerLowest: dark
              ? AppPalette.darkSurface
              : AppPalette.surface,
          surfaceContainerLow: dark
              ? AppPalette.darkSurfaceMuted
              : AppPalette.surfaceMuted,
          surfaceContainer: dark
              ? AppPalette.darkSurfaceMuted
              : AppPalette.surfaceMuted,
          surfaceContainerHigh: dark
              ? AppPalette.darkSurfaceSunken
              : AppPalette.surfaceSunken,
          surfaceContainerHighest: dark
              ? const Color(0xFF252C3B)
              : const Color(0xFFE6E9EE),
          outline: dark ? const Color(0xFF3A4253) : AppPalette.borderStrong,
          outlineVariant: dark ? AppPalette.darkBorder : AppPalette.border,
          surfaceTint: Colors.transparent,
          error: dark ? const Color(0xFFF08A8A) : AppPalette.danger,
          onError: dark ? const Color(0xFF3A0D0D) : Colors.white,
          errorContainer: dark
              ? const Color(0xFF3A1A1E)
              : const Color(0xFFFDECEC),
          onErrorContainer: dark
              ? const Color(0xFFFFD7D7)
              : const Color(0xFF8A1F1F),
          inverseSurface: dark ? AppPalette.darkText : AppPalette.navy,
          onInverseSurface: dark ? AppPalette.navy : Colors.white,
        );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
    );
    final text = base.textTheme.apply(
      fontFamily: fontFamily,
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );
    final hover = scheme.onSurface.withValues(alpha: dark ? .06 : .04);

    return base.copyWith(
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      hoverColor: hover,
      highlightColor: scheme.onSurface.withValues(alpha: .04),
      splashColor: scheme.primary.withValues(alpha: .08),
      focusColor: scheme.primary.withValues(alpha: .12),
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerColor: scheme.outlineVariant,
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 20),
      disabledColor: scheme.onSurface.withValues(alpha: .38),
      textTheme: text.copyWith(
        displaySmall: text.displaySmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -1,
        ),
        headlineLarge: text.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -.8,
        ),
        headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -.6,
        ),
        headlineSmall: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -.4,
        ),
        titleLarge: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -.3,
        ),
        titleMedium: text.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -.1,
        ),
        titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        bodyLarge: text.bodyLarge?.copyWith(height: 1.45),
        bodyMedium: text.bodyMedium?.copyWith(height: 1.45),
        bodySmall: text.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
          height: 1.4,
        ),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        labelMedium: text.labelMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: scheme.onSurfaceVariant,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        selectedColor: scheme.primaryContainer,
        checkmarkColor: scheme.primary,
        labelStyle: TextStyle(
          color: scheme.onSurface,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        secondaryLabelStyle: TextStyle(
          color: scheme.onPrimaryContainer,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide(color: scheme.outlineVariant),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: .22),
        selectionHandleColor: scheme.primary,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: scheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -.2,
        ),
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: scheme.onSurfaceVariant,
          fontSize: 14,
          height: 1.5,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: const Color(0x330B1324),
        textStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 14,
          fontFamily: fontFamily,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      searchBarTheme: SearchBarThemeData(
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerLowest),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        side: WidgetStateProperty.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.focused)
                ? scheme.primary
                : scheme.outlineVariant,
          ),
        ),
        textStyle: WidgetStatePropertyAll(
          TextStyle(color: scheme.onSurface, fontFamily: fontFamily),
        ),
        hintStyle: WidgetStatePropertyAll(
          TextStyle(color: scheme.onSurfaceVariant, fontFamily: fontFamily),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: scheme.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: scheme.onSurfaceVariant,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: .08),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          elevation: 0,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -.1,
          ),
          shape: buttonShape,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.surfaceContainerLowest,
          foregroundColor: scheme.onSurface,
          elevation: 0,
          minimumSize: const Size(48, 44),
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          shape: buttonShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(48, 44),
          side: BorderSide(color: scheme.outline),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          shape: buttonShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          shape: buttonShape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          shape: buttonShape,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: scheme.surfaceContainerLowest,
          selectedBackgroundColor: scheme.primaryContainer,
          selectedForegroundColor: scheme.onPrimaryContainer,
          foregroundColor: scheme.onSurfaceVariant,
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          shape: buttonShape,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? Colors.white : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? scheme.primary : null,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHigh,
        circularTrackColor: scheme.surfaceContainerHigh,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHigh,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: .1),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: dark ? AppPalette.darkSurfaceSunken : AppPalette.navy,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          color: Colors.white,
          fontSize: 12,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(
          color: scheme.onInverseSurface,
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(
          bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0)),
        ),
        iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: scheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -.3,
        ),
        systemOverlayStyle: dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        modalBackgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: scheme.outline,
        dragHandleSize: const Size(36, 4),
        showDragHandle: true,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        constraints: const BoxConstraints(maxWidth: 640),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        labelStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontFamily: fontFamily,
        ),
        floatingLabelStyle: TextStyle(
          color: scheme.primary,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: dark ? AppPalette.darkTextSecondary : AppPalette.textTertiary,
          fontFamily: fontFamily,
        ),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
            size: 21,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: fontFamily,
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
            fontSize: 11.5,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        selectedIconTheme: IconThemeData(color: scheme.primary, size: 21),
        unselectedIconTheme: IconThemeData(
          color: scheme.onSurfaceVariant,
          size: 21,
        ),
        selectedLabelTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: scheme.onSurface,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: scheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: scheme.surfaceContainerLowest,
        headerForegroundColor: scheme.onSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: scheme.primary,
        textColor: scheme.onPrimary,
      ),
    );
  }
}

/// Adapts legacy hard-coded colors (originally a green/pastel palette) to the
/// shared neutral + blue palette, so older widgets follow the design system.
extension AppThemeColors on BuildContext {
  List<Color> get appPanelColors {
    final scheme = Theme.of(this).colorScheme;
    return [
      scheme.surfaceContainerLowest,
      scheme.surfaceContainerLowest,
      scheme.surfaceContainerLowest,
    ];
  }

  Color appColor(Color light, {bool surface = false}) {
    if (light.a == 0) {
      return light;
    }
    final scheme = Theme.of(this).colorScheme;
    final opaque = light.withValues(alpha: 1);
    final hsl = HSLColor.fromColor(opaque);
    final luminance = opaque.computeLuminance();
    final greenish = hsl.hue > 65 && hsl.hue < 175;
    if (Theme.of(this).brightness == Brightness.light) {
      if (surface) {
        // Pastel tints become neutral surfaces; saturated brand greens
        // become the blue accent.
        if (luminance > .62) {
          if (hsl.saturation < .1 && luminance > .95) return light;
          return (luminance > .9
                  ? scheme.surfaceContainerLowest
                  : scheme.surfaceContainerLow)
              .withValues(alpha: light.a);
        }
        if (greenish && hsl.saturation > .35) {
          return scheme.primary.withValues(alpha: light.a);
        }
        return light;
      }
      if (luminance > .80 && hsl.saturation < .15) {
        return light.a < 1 ? scheme.onSurfaceVariant : scheme.onSurface;
      }
      if (hsl.saturation > .35 && greenish) {
        return scheme.primary.withValues(alpha: light.a);
      }
      if (luminance < .06) {
        return scheme.onSurface.withValues(alpha: light.a);
      }
      if ((luminance > .18 && hsl.saturation < .5) || luminance > .55) {
        return scheme.onSurfaceVariant.withValues(alpha: light.a);
      }
      return light;
    }
    Color result = opaque;
    if (surface) {
      // Do not reinterpret colors that have already been adapted by a caller.
      if ([
        scheme.surface,
        scheme.surfaceContainerLowest,
        scheme.surfaceContainerLow,
        scheme.surfaceContainer,
        scheme.surfaceContainerHigh,
        scheme.surfaceContainerHighest,
        scheme.primaryContainer,
        scheme.primary,
      ].contains(opaque)) {
        return light;
      }
      if (luminance > .90 && light.a < 1) return light;
      if (luminance > .60) {
        result = scheme.surfaceContainerLowest;
      } else if (hsl.saturation < .35) {
        result = luminance > .18
            ? scheme.surfaceContainerHigh
            : scheme.surfaceContainerLow;
      } else if (greenish) {
        result = luminance > .35 ? scheme.primaryContainer : scheme.primary;
      } else if (luminance < .12 && hsl.hue > 175 && hsl.hue < 270) {
        result = scheme.surfaceContainerLowest;
      }
    } else if (hsl.saturation > .45 && (hsl.hue > 340 || hsl.hue < 12)) {
      result = scheme.error;
    } else if (hsl.saturation > .35 && greenish) {
      result = scheme.primary;
    } else if (luminance < .18) {
      result = scheme.onSurface;
    } else if (luminance < .60 && hsl.saturation < .35) {
      result = scheme.onSurfaceVariant;
    }
    return result.withValues(alpha: light.a);
  }
}
