import 'package:flutter/material.dart';
import 'package:ruya/l10n/app_localizations.dart';

/// Look-and-feel packs. Each one sets colours, fonts and shapes together.
enum AppStyle {
  /// Chunky frames and a pixel display face, matching the companions.
  piksel,

  /// Lavender and indigo.
  ay,

  /// Cream and mint.
  bahce,

  /// Bright and playful.
  seker,

  /// Tulip red and turquoise.
  lale,

  /// The pre-1.4 look: one seed colour or the wallpaper's colours.
  klasik;

  static AppStyle byName(String? name) =>
      values.firstWhere((s) => s.name == name, orElse: () => AppStyle.piksel);

  String label(AppLocalizations l10n) => switch (this) {
        AppStyle.piksel => l10n.style_piksel,
        AppStyle.ay => l10n.style_ay,
        AppStyle.bahce => l10n.style_bahce,
        AppStyle.seker => l10n.style_seker,
        AppStyle.lale => l10n.style_lale,
        AppStyle.klasik => l10n.style_klasik,
      };

  String blurb(AppLocalizations l10n) => switch (this) {
        AppStyle.piksel => l10n.style_pikselAbout,
        AppStyle.ay => l10n.style_ayAbout,
        AppStyle.bahce => l10n.style_bahceAbout,
        AppStyle.seker => l10n.style_sekerAbout,
        AppStyle.lale => l10n.style_laleAbout,
        AppStyle.klasik => l10n.style_klasikAbout,
      };
}

const String kBodyFont = 'Nunito';
const String kPixelFont = 'PixelifySans';

/// Colours of one pack in one brightness.
class StylePalette {
  const StylePalette({
    required this.background,
    required this.card,
    required this.ink,
    required this.muted,
    required this.primary,
    required this.onPrimary,
    required this.soft,
    required this.line,
    required this.accent,
  });

  final Color background;
  final Color card;

  /// Text, and the outline colour of the pixel pack.
  final Color ink;
  final Color muted;
  final Color primary;
  final Color onPrimary;

  /// Tinted container (selected chips, highlighted cards).
  final Color soft;
  final Color line;

  /// Second accent for small highlights.
  final Color accent;
}

const _palettes = <AppStyle, (StylePalette light, StylePalette dark)>{
  AppStyle.piksel: (
    StylePalette(
      background: Color(0xFFF4ECFF), card: Color(0xFFFFFDF7), ink: Color(0xFF2B2150), muted: Color(0xFF6A5F8F),
      primary: Color(0xFF7C5CD6), onPrimary: Color(0xFFFFFFFF), soft: Color(0xFFE4DBFF), line: Color(0xFF2B2150),
      accent: Color(0xFFE0527F),
    ),
    StylePalette(
      background: Color(0xFF14122A), card: Color(0xFF211D40), ink: Color(0xFFECEBFF), muted: Color(0xFFA7A2C8),
      primary: Color(0xFFA89CFF), onPrimary: Color(0xFF17123A), soft: Color(0xFF2C2757), line: Color(0xFF6A5FB0),
      accent: Color(0xFFFF8FB3),
    ),
  ),
  AppStyle.ay: (
    StylePalette(
      background: Color(0xFFF5F3FF), card: Color(0xFFFFFFFF), ink: Color(0xFF221E3A), muted: Color(0xFF6F6A8C),
      primary: Color(0xFF5B4BD6), onPrimary: Color(0xFFFFFFFF), soft: Color(0xFFE6E1FF), line: Color(0xFFD8D2F2),
      accent: Color(0xFFC8385F),
    ),
    StylePalette(
      background: Color(0xFF14122A), card: Color(0xFF211D40), ink: Color(0xFFECEAFF), muted: Color(0xFFA7A2C8),
      primary: Color(0xFFA89CFF), onPrimary: Color(0xFF17123A), soft: Color(0xFF2C2757), line: Color(0xFF3A3470),
      accent: Color(0xFFFF6F96),
    ),
  ),
  AppStyle.bahce: (
    StylePalette(
      background: Color(0xFFFFF8F1), card: Color(0xFFFFFFFF), ink: Color(0xFF2E2541), muted: Color(0xFF7A6F8A),
      primary: Color(0xFF7C5CDB), onPrimary: Color(0xFFFFFFFF), soft: Color(0xFFEFE7FF), line: Color(0xFFEADFD2),
      accent: Color(0xFF2F9C7C),
    ),
    StylePalette(
      background: Color(0xFF1A1626), card: Color(0xFF272136), ink: Color(0xFFF3EEFF), muted: Color(0xFFB0A6C4),
      primary: Color(0xFFB9A6FF), onPrimary: Color(0xFF1F1640), soft: Color(0xFF342B4D), line: Color(0xFF41375C),
      accent: Color(0xFF9BE8C8),
    ),
  ),
  AppStyle.seker: (
    StylePalette(
      background: Color(0xFFFFFBEA), card: Color(0xFFFFFFFF), ink: Color(0xFF2D2A3E), muted: Color(0xFF77728C),
      primary: Color(0xFFD9480F), onPrimary: Color(0xFFFFFFFF), soft: Color(0xFFFFE6D6), line: Color(0xFFF3E6BD),
      accent: Color(0xFF4C5BD9),
    ),
    StylePalette(
      background: Color(0xFF1F1A14), card: Color(0xFF2B241C), ink: Color(0xFFFFF4E0), muted: Color(0xFFC4B8A4),
      primary: Color(0xFFFFA36F), onPrimary: Color(0xFF3A1600), soft: Color(0xFF45321F), line: Color(0xFF54402A),
      accent: Color(0xFFA9B4FF),
    ),
  ),
  AppStyle.lale: (
    StylePalette(
      background: Color(0xFFFDF3EE), card: Color(0xFFFFFFFF), ink: Color(0xFF3A1F2B), muted: Color(0xFF8A6A72),
      primary: Color(0xFFC8324A), onPrimary: Color(0xFFFFFFFF), soft: Color(0xFFFBDCD9), line: Color(0xFFF0D5CD),
      accent: Color(0xFF1F8A7E),
    ),
    StylePalette(
      background: Color(0xFF1E1416), card: Color(0xFF2B1D21), ink: Color(0xFFFFECEA), muted: Color(0xFFC9A9AE),
      primary: Color(0xFFFF8A9B), onPrimary: Color(0xFF4A0A18), soft: Color(0xFF45262D), line: Color(0xFF55323A),
      accent: Color(0xFF7FE0D2),
    ),
  ),
};

/// Neutral look forced in discrete mode, whatever pack is chosen.
const _ajanda = (
  StylePalette(
    background: Color(0xFFF6F6F3), card: Color(0xFFFFFFFF), ink: Color(0xFF24292E), muted: Color(0xFF6B7278),
    primary: Color(0xFF4A6572), onPrimary: Color(0xFFFFFFFF), soft: Color(0xFFE6EAEC), line: Color(0xFFDCDFE0),
    accent: Color(0xFF7A4E57),
  ),
  StylePalette(
    background: Color(0xFF16191B), card: Color(0xFF202427), ink: Color(0xFFE8ECEE), muted: Color(0xFFA3ABB0),
    primary: Color(0xFF9DB6C2), onPrimary: Color(0xFF10242C), soft: Color(0xFF2B3338), line: Color(0xFF394147),
    accent: Color(0xFFD8A9B3),
  ),
);

StylePalette paletteOf(AppStyle style, Brightness brightness) {
  final pair = _palettes[style] ?? _palettes[AppStyle.ay]!;
  return brightness == Brightness.dark ? pair.$2 : pair.$1;
}

/// What widgets need to know about the active pack beyond the ColorScheme.
@immutable
class RuyaStyle extends ThemeExtension<RuyaStyle> {
  const RuyaStyle({
    required this.style,
    required this.pixel,
    required this.ink,
    required this.accent,
    required this.displayFont,
    this.discrete = false,
  });

  final AppStyle style;

  /// Chunky bordered frames with a hard drop shadow.
  final bool pixel;
  final Color ink;
  final Color accent;

  /// Font for headings and big numbers (null = the theme's own).
  final String? displayFont;
  final bool discrete;

  static RuyaStyle of(BuildContext context) =>
      Theme.of(context).extension<RuyaStyle>() ??
      RuyaStyle(
        style: AppStyle.klasik,
        pixel: false,
        ink: Theme.of(context).colorScheme.onSurface,
        accent: Theme.of(context).colorScheme.tertiary,
        displayFont: null,
      );

  @override
  RuyaStyle copyWith() => this;

  @override
  RuyaStyle lerp(ThemeExtension<RuyaStyle>? other, double t) => other is RuyaStyle && t > 0.5 ? other : this;
}

ColorScheme _scheme(StylePalette p, Brightness b) {
  final base = ColorScheme.fromSeed(seedColor: p.primary, brightness: b);
  return base.copyWith(
    primary: p.primary,
    onPrimary: p.onPrimary,
    primaryContainer: p.soft,
    onPrimaryContainer: p.ink,
    secondaryContainer: p.soft,
    onSecondaryContainer: p.ink,
    tertiary: p.accent,
    surface: p.background,
    onSurface: p.ink,
    onSurfaceVariant: p.muted,
    surfaceContainerLowest: p.card,
    surfaceContainerLow: p.card,
    surfaceContainer: p.card,
    surfaceContainerHigh: Color.alphaBlend(p.soft.withValues(alpha: 0.55), p.card),
    surfaceContainerHighest: p.soft,
    outline: p.muted,
    outlineVariant: p.line,
    surfaceTint: Colors.transparent,
  );
}

/// Theme for a pack. [klasikScheme] is used as-is for [AppStyle.klasik].
ThemeData buildRuyaTheme({
  required AppStyle style,
  required Brightness brightness,
  required ColorScheme klasikScheme,
  bool discrete = false,
}) {
  if (discrete) {
    final p = brightness == Brightness.dark ? _ajanda.$2 : _ajanda.$1;
    final scheme = _scheme(p, brightness);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      extensions: [RuyaStyle(style: style, pixel: false, ink: p.ink, accent: p.accent, displayFont: null, discrete: true)],
    );
  }
  if (style == AppStyle.klasik) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: klasikScheme,
      extensions: [
        RuyaStyle(style: style, pixel: false, ink: klasikScheme.onSurface, accent: klasikScheme.tertiary, displayFont: null),
      ],
    );
  }

  final p = paletteOf(style, brightness);
  final scheme = _scheme(p, brightness);
  final pixel = style == AppStyle.piksel;
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: kBodyFont);
  final display = pixel ? kPixelFont : kBodyFont;
  TextStyle? head(TextStyle? s, {FontWeight w = FontWeight.w700}) =>
      s?.copyWith(fontFamily: display, fontWeight: pixel ? FontWeight.w700 : w, letterSpacing: pixel ? 0.2 : null);
  final t = base.textTheme;
  final textTheme = t.copyWith(
    displayLarge: head(t.displayLarge),
    displayMedium: head(t.displayMedium),
    displaySmall: head(t.displaySmall),
    headlineLarge: head(t.headlineLarge, w: FontWeight.w800),
    headlineMedium: head(t.headlineMedium, w: FontWeight.w800),
    headlineSmall: head(t.headlineSmall, w: FontWeight.w800),
    titleLarge: head(t.titleLarge, w: FontWeight.w800),
    titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w700),
  );

  final radius = pixel ? 8.0 : 18.0;
  final side = pixel ? BorderSide(color: p.line, width: 2) : BorderSide.none;
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius), side: side);
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(pixel ? 8 : 999),
    side: pixel ? BorderSide(color: p.line, width: 2) : BorderSide.none,
  );

  // The pixel pack's buttons have a darker lip along the bottom that collapses
  // when pressed. It is drawn inside the button, which is clipped to its shape.
  Widget lip(BuildContext context, Set<WidgetState> states, Widget? child) {
    final down = states.contains(WidgetState.pressed) || states.contains(WidgetState.disabled);
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.line.withValues(alpha: 0.38), width: down ? 0 : 4)),
      ),
      child: child,
    );
  }

  return base.copyWith(
    textTheme: textTheme,
    scaffoldBackgroundColor: p.background,
    extensions: [RuyaStyle(style: style, pixel: pixel, ink: p.line, accent: p.accent, displayFont: display)],
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      foregroundColor: p.ink,
      scrolledUnderElevation: 0,
      titleTextStyle: textTheme.titleLarge?.copyWith(color: p.ink, fontSize: pixel ? 24 : 22),
    ),
    cardTheme: CardThemeData(elevation: 0, color: p.card, shape: shape, margin: EdgeInsets.zero),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(buttonShape),
        backgroundBuilder: pixel ? lip : null,
        textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(shape: WidgetStatePropertyAll(buttonShape), elevation: const WidgetStatePropertyAll(0)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(buttonShape),
        side: WidgetStatePropertyAll(BorderSide(color: pixel ? p.line : p.primary, width: pixel ? 2 : 1.5)),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(pixel ? 6 : 999)),
      side: BorderSide(color: p.line, width: pixel ? 2 : 1),
      backgroundColor: p.card,
      selectedColor: p.soft,
      labelStyle: textTheme.labelLarge?.copyWith(color: p.ink),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.primary,
      foregroundColor: p.onPrimary,
      elevation: pixel ? 0 : 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(pixel ? 10 : 18), side: side),
    ),
    dialogTheme: DialogThemeData(backgroundColor: p.card, shape: shape, titleTextStyle: textTheme.titleLarge?.copyWith(color: p.ink)),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(pixel ? 14 : 28)),
        side: side,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.card,
      indicatorColor: p.soft,
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(pixel ? 8 : 999), side: side),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => textTheme.labelMedium?.copyWith(
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
          color: s.contains(WidgetState.selected) ? p.ink : p.muted,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(pixel ? 8 : 14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(pixel ? 8 : 14),
        borderSide: BorderSide(color: p.line, width: pixel ? 2 : 1),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        side: WidgetStatePropertyAll(BorderSide(color: p.line, width: pixel ? 2 : 1)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(pixel ? 8 : 999))),
      ),
    ),
    dividerTheme: DividerThemeData(color: pixel ? p.line.withValues(alpha: 0.25) : p.line),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: shape),
  );
}
