import 'package:flutter/widgets.dart';

/// Typografie von Lumen auf Basis von Inter (SF-Pro-ähnlich, OFL-Lizenz).
///
/// Zwei Skalen: Mobil und TV (10-Foot-UI, Text mindestens 24 sp).
/// Farben werden nicht hier, sondern im Theme gesetzt.
class LumenTypeScale {
  const LumenTypeScale._({
    required this.largeTitle,
    required this.title1,
    required this.title2,
    required this.headline,
    required this.body,
    required this.callout,
    required this.subhead,
    required this.footnote,
    required this.caption,
  });

  static const fontFamily = 'Inter';

  /// Tabellarische Ziffern: Uhrzeiten und Nummern springen nicht in der Breite.
  static const tabular = [FontFeature.tabularFigures()];

  final TextStyle largeTitle;
  final TextStyle title1;
  final TextStyle title2;
  final TextStyle headline;
  final TextStyle body;
  final TextStyle callout;
  final TextStyle subhead;
  final TextStyle footnote;
  final TextStyle caption;

  static TextStyle _s(double size, double lineHeight, FontWeight weight,
          [double tracking = 0]) =>
      TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        height: lineHeight / size,
        fontWeight: weight,
        letterSpacing: size * tracking,
      );

  static final mobile = LumenTypeScale._(
    largeTitle: _s(34, 40, FontWeight.w700, -0.008),
    title1: _s(28, 34, FontWeight.w700, -0.007),
    title2: _s(22, 28, FontWeight.w600, -0.004),
    headline: _s(17, 22, FontWeight.w600),
    body: _s(17, 24, FontWeight.w400),
    callout: _s(16, 21, FontWeight.w400),
    subhead: _s(15, 20, FontWeight.w500),
    footnote: _s(13, 18, FontWeight.w400),
    caption: _s(12, 16, FontWeight.w500),
  );

  static final tv = LumenTypeScale._(
    largeTitle: _s(48, 56, FontWeight.w700, -0.008),
    title1: _s(40, 48, FontWeight.w700, -0.007),
    title2: _s(32, 40, FontWeight.w600, -0.004),
    headline: _s(28, 34, FontWeight.w600),
    body: _s(26, 34, FontWeight.w400),
    callout: _s(24, 30, FontWeight.w400),
    subhead: _s(24, 30, FontWeight.w500),
    footnote: _s(24, 28, FontWeight.w400),
    caption: _s(22, 26, FontWeight.w500),
  );
}
