import 'package:flutter/services.dart';

/// Leichte Haptik bei Auswahl (nur Mobilgeräte, abschaltbar).
///
/// Bewusst als einfacher globaler Schalter: Haptik wird in sehr vielen
/// kleinen Widgets ausgelöst, die sonst alle den Einstellungs-State kennen
/// müssten. Der Schalter wird von der App gesetzt, wenn sich die Einstellung
/// ändert.
abstract final class LumenHaptics {
  static bool enabled = true;

  static void selection() {
    if (enabled) HapticFeedback.selectionClick();
  }

  static void light() {
    if (enabled) HapticFeedback.lightImpact();
  }
}
