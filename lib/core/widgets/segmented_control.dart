import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import 'pressable.dart';

/// Segment-Umschalter im iOS-Stil (z. B. Filme / Serien, Hell / Dunkel).
class LumenSegmentedControl<T> extends StatelessWidget {
  const LumenSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final Map<T, String> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.lumen;
    final p = l.palette;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.surface2,
        borderRadius: LumenRadius.smAll,
      ),
      child: Row(
        children: [
          for (final e in segments.entries)
            Expanded(
              child: LumenPressable(
                onPressed: e.key == selected ? () {} : () => onChanged(e.key),
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                focusScale: 1.0,
                semanticLabel: e.value,
                child: AnimatedContainer(
                  duration: context.motion(LumenMotion.fast),
                  curve: LumenMotion.standard,
                  height: l.isTv ? 52 : 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: e.key == selected ? p.surface3 : Colors.transparent,
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                  ),
                  child: Semantics(
                    selected: e.key == selected,
                    child: Text(
                      e.value,
                      style: l.text.subhead.copyWith(
                        color: e.key == selected
                            ? p.textPrimary
                            : p.textSecondary,
                        fontWeight: e.key == selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
