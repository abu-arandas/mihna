import 'package:material_ui/material_ui.dart';

import 'brand.dart';

/// Light and dark themes, both made from [Brand.seedColor], with [Brand.accentColor] as the secondary colour.
///
/// The Zirr house style sits on top of the colours: headings set semibold and a touch tight, corners that flow into
/// the sides ([AppTheme.shape]), fields that show their edge under the pointer and turn white with a ring when in
/// use, buttons that rise a little on hover, and calm motion. A rebrand changes [Brand] and keeps all of this.
class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  /// A rectangle whose corners flow into its sides (a superellipse) rather than a quarter circle stuck on.
  static RoundedSuperellipseBorder shape(double radius, {BorderSide side = BorderSide.none}) =>
      RoundedSuperellipseBorder(borderRadius: BorderRadius.all(Radius.circular(radius)), side: side);

  /// For a change in place: quick to answer, then a long, quiet settle.
  static const curve = Cubic(0.2, 0, 0, 1);
  static const fast = Duration(milliseconds: 160);

  // The motion tokens (lib/widgets/motion.dart reads them; no widget keeps its own numbers). Mihna is a work
  // tool, so motion is calm and quick: things settle in once, a press answers, and one small celebration when a list
  // is all done. With reduce motion on, everything simply shows.

  /// An entrance: a page's heading, a new row.
  static const slow = Duration(milliseconds: 420);

  /// The ornament sewing itself in.
  static const sew = Duration(milliseconds: 700);

  /// The step between items that come in one after another.
  static const stagger = Duration(milliseconds: 50);

  /// How far an entrance rises, in points.
  static const rise = 10.0;

  /// For something arriving: fast at first, then a long settle.
  static const enter = Cubic(0.05, 0.7, 0.1, 1);

  /// For a pop: a little past its size and back. Only for small, happy moments.
  static const pop = Cubic(0.34, 1.56, 0.64, 1);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    // Fidelity keeps the primary colour on the seed itself instead of a nearby tone of it.
    final scheme = ColorScheme.fromSeed(
      seedColor: Brand.seedColor,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    ).copyWith(secondary: dark ? Brand.accentColorDark : Brand.accentColor, onSecondary: const Color(0xFF18202E));

    final base = ThemeData(colorScheme: scheme, fontFamily: Brand.fontFamily);
    TextStyle title(TextStyle s) => s.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.2);
    final text = base.textTheme.copyWith(
      headlineLarge: title(base.textTheme.headlineLarge!),
      headlineMedium: title(base.textTheme.headlineMedium!),
      headlineSmall: title(base.textTheme.headlineSmall!),
      titleLarge: title(base.textTheme.titleLarge!),
      titleMedium: base.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: base.textTheme.bodyLarge!.copyWith(height: 1.5),
      bodyMedium: base.textTheme.bodyMedium!.copyWith(height: 1.45),
      labelLarge: base.textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w600),
    );

    OutlineInputBorder edge(Color color, [double width = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );

    const buttonStyle = ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(44, 46)), shape: WidgetStatePropertyAll(StadiumBorder()), animationDuration: fast);

    return base.copyWith(
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        // Flat on the page until something scrolls under it, then a soft shadow, not a grey tint.
        scrolledUnderElevation: 2,
        shadowColor: scheme.shadow.withValues(alpha: 0.25),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: WidgetStateColor.resolveWith((s) => s.contains(WidgetState.focused) ? scheme.surface : scheme.surfaceContainerHigh),
        hoverColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: WidgetStateInputBorder.resolveWith((s) {
          final focused = s.contains(WidgetState.focused);
          if (s.contains(WidgetState.error)) return edge(scheme.error, focused ? 1.6 : 1);
          if (focused) return edge(scheme.primary, 1.6);
          if (s.contains(WidgetState.hovered) && !s.contains(WidgetState.disabled)) return edge(scheme.outlineVariant);
          return edge(Colors.transparent);
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: buttonStyle.copyWith(
          shadowColor: WidgetStatePropertyAll(scheme.primary.withValues(alpha: 0.5)),
          elevation: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.hovered) && !s.contains(WidgetState.pressed) && !s.contains(WidgetState.disabled) ? 3 : 0,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: buttonStyle.copyWith(
          side: WidgetStateProperty.resolveWith(
            (s) => BorderSide(color: s.contains(WidgetState.hovered) || s.contains(WidgetState.focused) ? scheme.outline : scheme.outlineVariant),
          ),
        ),
      ),
      textButtonTheme: const TextButtonThemeData(style: buttonStyle),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: shape(16, side: BorderSide(color: scheme.outlineVariant)),
      ),
      listTileTheme: ListTileThemeData(shape: shape(12)),
      dialogTheme: DialogThemeData(surfaceTintColor: Colors.transparent, shape: shape(22)),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: shape(12)),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: scheme.inverseSurface, borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        textStyle: TextStyle(color: scheme.onInverseSurface, fontSize: 12.5),
        waitDuration: const Duration(milliseconds: 350),
      ),
      // Thin, and only as dark as it needs to be.
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => scheme.onSurfaceVariant.withValues(alpha: s.contains(WidgetState.hovered) || s.contains(WidgetState.dragged) ? 0.55 : 0.3),
        ),
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(8),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1, thickness: 1),
    );
  }
}
