import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'tokens.dart';
import 'typography.dart';

/// Alles, was Widgets über das aktuelle Design wissen müssen.
///
/// Wird als [ThemeExtension] ins [ThemeData] gehängt und über
/// `context.lumen` gelesen.
@immutable
class LumenTheme extends ThemeExtension<LumenTheme> {
  const LumenTheme({
    required this.palette,
    required this.accentChoice,
    required this.text,
    required this.isTv,
  });

  final LumenPalette palette;
  final LumenAccent accentChoice;
  final LumenTypeScale text;

  /// `true` auf Android TV / Fire TV: größere Schrift, Fokus-Rahmen,
  /// Seitenleiste statt Tab-Leiste.
  final bool isTv;

  Brightness get brightness => palette.brightness;
  Color get accent => accentChoice.resolve(brightness);
  Color get onAccent => accentChoice.onAccent(brightness);

  EdgeInsets get pagePadding => isTv
      ? const EdgeInsets.symmetric(
          horizontal: LumenSpace.pageTvHorizontal,
          vertical: LumenSpace.pageTvVertical,
        )
      : const EdgeInsets.symmetric(horizontal: LumenSpace.pagePhone);

  @override
  LumenTheme copyWith({
    LumenPalette? palette,
    LumenAccent? accentChoice,
    LumenTypeScale? text,
    bool? isTv,
  }) =>
      LumenTheme(
        palette: palette ?? this.palette,
        accentChoice: accentChoice ?? this.accentChoice,
        text: text ?? this.text,
        isTv: isTv ?? this.isTv,
      );

  @override
  LumenTheme lerp(LumenTheme? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}

extension LumenThemeContext on BuildContext {
  LumenTheme get lumen => Theme.of(this).extension<LumenTheme>()!;

  /// `true`, wenn der Nutzer „Bewegung reduzieren“ aktiviert hat.
  bool get reduceMotion => MediaQuery.maybeDisableAnimationsOf(this) ?? false;

  /// Animationsdauer unter Berücksichtigung von „Bewegung reduzieren“.
  Duration motion(Duration d) => reduceMotion ? Duration.zero : d;
}

/// Baut das [ThemeData] für einen Modus.
ThemeData buildLumenTheme({
  required Brightness brightness,
  required LumenAccent accent,
  required bool isTv,
}) {
  final p =
      brightness == Brightness.dark ? LumenPalette.dark : LumenPalette.light;
  final type = isTv ? LumenTypeScale.tv : LumenTypeScale.mobile;
  final lumen =
      LumenTheme(palette: p, accentChoice: accent, text: type, isTv: isTv);
  final accentColor = accent.resolve(brightness);

  final scheme = ColorScheme(
    brightness: brightness,
    primary: accentColor,
    onPrimary: accent.onAccent(brightness),
    secondary: accentColor,
    onSecondary: accent.onAccent(brightness),
    error: p.error,
    onError: const Color(0xFFFFFFFF),
    surface: p.bg,
    onSurface: p.textPrimary,
    onSurfaceVariant: p.textSecondary,
    surfaceContainerLowest: p.bg,
    surfaceContainerLow: p.bgElevated,
    surfaceContainer: p.surface1,
    surfaceContainerHigh: p.surface2,
    surfaceContainerHighest: p.surface3,
    outline: p.separator,
    outlineVariant: p.separator,
  );

  TextStyle c(TextStyle s, [Color? color]) =>
      s.copyWith(color: color ?? p.textPrimary);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: LumenTypeScale.fontFamily,
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.bg,
    dividerColor: p.separator,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    focusColor: Colors.transparent,
    textTheme: TextTheme(
      displayLarge: c(type.largeTitle),
      headlineLarge: c(type.largeTitle),
      headlineMedium: c(type.title1),
      headlineSmall: c(type.title2),
      titleLarge: c(type.title2),
      titleMedium: c(type.headline),
      titleSmall: c(type.subhead),
      bodyLarge: c(type.body),
      bodyMedium: c(type.callout),
      bodySmall: c(type.footnote, p.textSecondary),
      labelLarge: c(type.headline),
      labelMedium: c(type.subhead),
      labelSmall: c(type.caption, p.textSecondary),
    ),
    iconTheme: IconThemeData(color: p.textPrimary, size: isTv ? 32 : 24),
    // Schlanker Zurück-Pfeil (Lucide) statt des Material-Pfeils.
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (_) => const Icon(LucideIcons.chevronLeft, size: 28),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: p.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: c(type.headline),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface2,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: LumenRadius.xlAll),
      titleTextStyle: c(type.headline),
      contentTextStyle: c(type.callout, p.textSecondary),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface2,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: p.textTertiary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(LumenRadius.xl)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.surface3,
      contentTextStyle: c(type.callout),
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: LumenRadius.mdAll),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: accentColor,
      selectionColor: accentColor.withValues(alpha: 0.35),
      selectionHandleColor: accentColor,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Color(0xFFFFFFFF)),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.success : p.surface3,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    extensions: [lumen],
  );
}
