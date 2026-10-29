import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';

/// Dünner, abgerundeter Fortschrittsbalken. Ohne [value] läuft er
/// unbestimmt (bei „Bewegung reduzieren“ als ruhiger, halber Balken).
class ThinProgress extends StatelessWidget {
  const ThinProgress({super.key, this.value, this.color, this.height = 4});

  final double? value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final l = context.lumen;
    final c = color ?? l.accent;
    final v = value ?? (context.reduceMotion ? 0.5 : null);
    return ClipRRect(
      borderRadius: LumenRadius.pillAll,
      child: SizedBox(
        height: height,
        child: LinearProgressIndicator(
          value: v,
          color: c,
          backgroundColor: l.palette.surface3,
          minHeight: height,
        ),
      ),
    );
  }
}
