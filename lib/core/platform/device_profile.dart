import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

/// Welche Art Gerät ist das? Entscheidet über TV-Layout (Seitenleiste,
/// große Schrift, Fokus) oder Mobil-Layout (Tab-Leiste, Touch, Haptik).
@immutable
class DeviceProfile {
  const DeviceProfile({this.isTv = false, this.isFireTv = false});

  final bool isTv;
  final bool isFireTv;

  /// Auf TV gibt es keinen Touch: der Fokusrahmen muss von Anfang an
  /// sichtbar sein, nicht erst nach dem ersten Tastendruck.
  void applyFocusStrategy() {
    FocusManager.instance.highlightStrategy = isTv
        ? FocusHighlightStrategy.alwaysTraditional
        : FocusHighlightStrategy.automatic;
  }

  static const _channel = MethodChannel('app.lumen/platform');

  /// Fragt Android, ob es ein Fernseher ist (Leanback / Fire TV).
  /// Für Tests am Rechner lässt sich das TV-Layout mit
  /// `--dart-define=LUMEN_FORCE_TV=true` erzwingen.
  static Future<DeviceProfile> detect() async {
    const forceTv = bool.fromEnvironment('LUMEN_FORCE_TV');
    if (forceTv) return const DeviceProfile(isTv: true);
    if (kIsWeb || !Platform.isAndroid) return const DeviceProfile();
    try {
      final r = await _channel.invokeMapMethod<String, bool>('deviceProfile');
      return DeviceProfile(
        isTv: r?['isTv'] ?? false,
        isFireTv: r?['isFireTv'] ?? false,
      );
    } on PlatformException {
      return const DeviceProfile();
    } on MissingPluginException {
      return const DeviceProfile();
    }
  }
}
