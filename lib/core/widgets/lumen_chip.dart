import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import 'pressable.dart';

/// Ruhige Auswahl-Pille (z. B. Kategorien). Ausgewählt: invertiert
/// (weiß auf schwarz bzw. schwarz auf weiß) – wie bei Trade Republic.
class LumenChip extends StatelessWidget {
  const LumenChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.icon,
    this.autofocus = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final l = context.lumen;
    final p = l.palette;
    final fg = selected ? p.bg : p.textPrimary;
    return Semantics(
      selected: selected,
      child: LumenPressable(
        onPressed: onPressed,
        autofocus: autofocus,
        borderRadius: LumenRadius.pillAll,
        semanticLabel: label,
        child: AnimatedContainer(
          duration: context.motion(LumenMotion.fast),
          padding: EdgeInsets.symmetric(
            horizontal: l.isTv ? LumenSpace.xl : LumenSpace.md,
            vertical: l.isTv ? LumenSpace.sm : LumenSpace.xs,
          ),
          decoration: BoxDecoration(
            color: selected ? p.textPrimary : p.surface2,
            borderRadius: LumenRadius.pillAll,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: l.isTv ? 24 : 16, color: fg),
                const SizedBox(width: 6),
              ],
              Text(label, style: l.text.subhead.copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}
