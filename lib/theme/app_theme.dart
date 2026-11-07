import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppTheme {
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
    final scheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF36C9A0),
          brightness: brightness,
          surface: dark ? const Color(0xFF0C1014) : const Color(0xFFF7FAF8),
        ).copyWith(
          primary: dark ? const Color(0xFF62D6B2) : const Color(0xFF13765E),
          onPrimary: dark ? const Color(0xFF07251B) : Colors.white,
          primaryContainer: dark
              ? const Color(0xFF15382E)
              : const Color(0xFFDDEFE8),
          onPrimaryContainer: dark
              ? const Color(0xFFB1F0D9)
              : const Color(0xFF124736),
          secondary: dark ? const Color(0xFF9BBFAF) : null,
          onSecondary: dark ? const Color(0xFF142C23) : null,
          secondaryContainer: dark ? const Color(0xFF20352E) : null,
          onSecondaryContainer: dark ? const Color(0xFFB8D9CA) : null,
          onSurface: dark ? const Color(0xFFF0F4F3) : const Color(0xFF152332),
          onSurfaceVariant: dark
              ? const Color(0xFFA5B3B0)
              : const Color(0xFF596B77),
          surfaceContainerLowest: dark ? const Color(0xFF141B20) : Colors.white,
          surfaceContainerLow: dark
              ? const Color(0xFF182126)
              : const Color(0xFFF3F6F5),
          surfaceContainer: dark
              ? const Color(0xFF1D282D)
              : const Color(0xFFEDF2EF),
          surfaceContainerHigh: dark
              ? const Color(0xFF243137)
              : const Color(0xFFE6ECE8),
          surfaceContainerHighest: dark
              ? const Color(0xFF2C3B41)
              : const Color(0xFFDFE7E2),
          outline: dark ? const Color(0xFF657773) : const Color(0xFF7B8C87),
          outlineVariant: dark
              ? const Color(0xFF2A373B)
              : const Color(0xFFDCE5E0),
          surfaceTint: dark ? Colors.transparent : null,
          error: dark ? const Color(0xFFFF9EAA) : null,
          onError: dark ? const Color(0xFF4B1421) : null,
          errorContainer: dark ? const Color(0xFF3A2028) : null,
          onErrorContainer: dark ? const Color(0xFFFFD9DE) : null,
        );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,
      splashFactory: InkRipple.splashFactory,
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 22),
      disabledColor: scheme.onSurface.withValues(alpha: .38),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        selectedColor: scheme.primaryContainer,
        checkmarkColor: scheme.primary,
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        secondaryLabelStyle: TextStyle(color: scheme.onPrimaryContainer),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: .25),
        selectionHandleColor: scheme.primary,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: scheme.onSurface, fontSize: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      searchBarTheme: SearchBarThemeData(
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerLowest),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
        textStyle: WidgetStatePropertyAll(TextStyle(color: scheme.onSurface)),
        hintStyle: WidgetStatePropertyAll(
          TextStyle(color: scheme.onSurfaceVariant),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
          letterSpacing: -1,
        ),
        titleLarge: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
          letterSpacing: -.4,
        ),
        bodyLarge: TextStyle(color: scheme.onSurface, height: 1.45),
        bodyMedium: TextStyle(color: scheme.onSurface, height: 1.4),
        bodySmall: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
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
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .5)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      scaffoldBackgroundColor: dark
          ? const Color(0xFF0C1014)
          : const Color(0xFFF7FAF8),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 21,
          fontWeight: FontWeight.w700,
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
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        constraints: const BoxConstraints(maxWidth: 640),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        elevation: 0,
        backgroundColor: dark ? scheme.surface : scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
            size: 23,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// Adapts legacy custom surfaces to the shared midnight palette.
extension AppThemeColors on BuildContext {
  List<Color> get appPanelColors {
    final scheme = Theme.of(this).colorScheme;
    return [
      scheme.surfaceContainerLowest,
      scheme.surfaceContainerLow,
      scheme.surfaceContainer,
    ];
  }

  Color appColor(Color light, {bool surface = false}) {
    if (light.a == 0) {
      return light;
    }
    final opaque = light.withValues(alpha: 1);
    final hsl = HSLColor.fromColor(opaque);
    final luminance = opaque.computeLuminance();
    if (Theme.of(this).brightness == Brightness.light) {
      if (!surface && luminance > .80 && hsl.saturation < .15) {
        return light.a < 1
            ? Theme.of(this).colorScheme.onSurfaceVariant
            : Theme.of(this).colorScheme.onSurface;
      }
      if (!surface && hsl.saturation > .45 && hsl.hue > 65 && hsl.hue < 175) {
        return Theme.of(this).colorScheme.primary;
      }
      if (!surface &&
          ((luminance > .18 && hsl.saturation < .5) || luminance > .55)) {
        return Theme.of(this).colorScheme.onSurfaceVariant;
      }
      return light;
    }
    final scheme = Theme.of(this).colorScheme;
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
      } else if (hsl.hue > 65 && hsl.hue < 175) {
        result = luminance > .35 ? scheme.primaryContainer : scheme.primary;
      } else if (luminance < .12 && hsl.hue > 175 && hsl.hue < 270) {
        result = scheme.surfaceContainerLowest;
      }
    } else if (hsl.saturation > .45 && (hsl.hue > 340 || hsl.hue < 12)) {
      result = scheme.error;
    } else if (hsl.saturation > .45 && hsl.hue > 65 && hsl.hue < 175) {
      result = scheme.primary;
    } else if (luminance < .18) {
      result = hsl.saturation > .55 && hsl.hue > 65 && hsl.hue < 175
          ? Theme.of(this).colorScheme.primary
          : Theme.of(this).colorScheme.onSurface;
    } else if (luminance < .60 && hsl.saturation < .35) {
      result = Theme.of(this).colorScheme.onSurfaceVariant;
    }
    return result.withValues(alpha: light.a);
  }
}
