import 'package:flutter/material.dart';

/// Zentrale Design-Tokens von Lumen.
///
/// Widgets verwenden nie Rohwerte (Farben, Abstände, Radien, Dauern),
/// sondern immer diese Tokens. So bleibt das Design einheitlich und kann an
/// einer Stelle angepasst werden.

/// Farbpalette für einen Modus (hell oder dunkel).
class LumenPalette {
  const LumenPalette({
    required this.brightness,
    required this.bg,
    required this.bgElevated,
    required this.surface1,
    required this.surface2,
    required this.surface3,
    required this.separator,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.live,
    required this.success,
    required this.scrim,
    required this.glass,
  });

  final Brightness brightness;
  final Color bg;
  final Color bgElevated;
  final Color surface1;
  final Color surface2;
  final Color surface3;
  final Color separator;
  final Color textPrimary;

  /// Sekundärtext. Erfüllt WCAG AA (≥ 4,5 : 1) auf allen Flächen.
  final Color textSecondary;

  /// Nur für Dekoration (Platzhalter, Icons in leeren Zuständen),
  /// nie für Pflichtinformationen.
  final Color textTertiary;

  /// Rot – ausschließlich für Live-Markierungen und Fehler.
  final Color live;
  final Color success;
  final Color scrim;

  /// Hintergrund für Glas-Flächen (zusammen mit [LumenBlur.glass]).
  final Color glass;

  Color get error => live;

  static const dark = LumenPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF000000),
    bgElevated: Color(0xFF0A0A0A),
    surface1: Color(0xFF141414),
    surface2: Color(0xFF1C1C1E),
    surface3: Color(0xFF2C2C2E),
    separator: Color(0x14FFFFFF),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFA3A3A8),
    textTertiary: Color(0x66FFFFFF),
    live: Color(0xFFFF453A),
    success: Color(0xFF30D158),
    scrim: Color(0x8C000000),
    glass: Color(0xB81C1C1E),
  );

  static const light = LumenPalette(
    brightness: Brightness.light,
    bg: Color(0xFFFFFFFF),
    bgElevated: Color(0xFFF5F5F7),
    surface1: Color(0xFFFFFFFF),
    surface2: Color(0xFFF2F2F7),
    surface3: Color(0xFFE5E5EA),
    separator: Color(0x14000000),
    textPrimary: Color(0xFF000000),
    textSecondary: Color(0xFF5E5E63),
    textTertiary: Color(0x663C3C43),
    live: Color(0xFFD70015),
    success: Color(0xFF248A3D),
    scrim: Color(0x66000000),
    glass: Color(0xB8F5F5F7),
  );
}

/// Akzentfarben, aus denen der Nutzer wählen kann. Standard ist [blue].
enum LumenAccent {
  blue(Color(0xFF0A84FF), Color(0xFF007AFF)),
  green(Color(0xFF30D158), Color(0xFF248A3D)),
  mint(Color(0xFF63E6BE), Color(0xFF0C8A6A)),
  orange(Color(0xFFFF9F0A), Color(0xFFC93400)),
  purple(Color(0xFFBF5AF2), Color(0xFF8944AB)),
  graphite(Color(0xFF8E8E93), Color(0xFF636366));

  const LumenAccent(this.dark, this.light);

  final Color dark;
  final Color light;

  Color resolve(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// Textfarbe auf einer Fläche in Akzentfarbe (z. B. primärer Button).
  Color onAccent(Brightness brightness) {
    final c = resolve(brightness);
    return c.computeLuminance() > 0.4
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);
  }

  static LumenAccent fromName(String? name) => LumenAccent.values.firstWhere(
        (a) => a.name == name,
        orElse: () => LumenAccent.blue,
      );
}

/// Abstände im 4er-Raster.
abstract final class LumenSpace {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double x3 = 40;
  static const double x4 = 56;
  static const double x5 = 72;

  /// Seitenränder je Formfaktor. TV: overscan-sicher (≈ 5 %).
  static const double pagePhone = 20;
  static const double pageTablet = 32;
  static const double pageTvHorizontal = 48;
  static const double pageTvVertical = 27;
}

/// Eckenradien.
abstract final class LumenRadius {
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

/// Unschärfe für Glas-Effekte (Backdrop-Blur).
abstract final class LumenBlur {
  static const double glass = 24;
}

/// Bewegung: kurz, federnd, ruhig.
abstract final class LumenMotion {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 350);
  static const Duration focus = Duration(milliseconds: 150);
  static const Duration overlayHide = Duration(seconds: 4);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubic;

  /// Feder für Übergänge (Masse 1, Steifigkeit 380, Dämpfung 30).
  static const SpringDescription spring =
      SpringDescription(mass: 1, stiffness: 380, damping: 30);

  /// Fokus-Skalierung auf TV.
  static const double focusScale = 1.06;

  /// Skalierung beim Drücken auf Touch-Geräten.
  static const double pressScale = 0.97;
}
