import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import 'pressable.dart';

enum LumenButtonVariant { primary, secondary, text }

/// Großer, ruhiger Button. Primär = Akzentfläche, sekundär = graue Fläche,
/// Text = nur Beschriftung.
class LumenButton extends StatelessWidget {
  const LumenButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = LumenButtonVariant.primary,
    this.expand = true,
    this.loading = false,
    this.autofocus = false,
  });

  const LumenButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.loading = false,
    this.autofocus = false,
  }) : variant = LumenButtonVariant.secondary;

  const LumenButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.loading = false,
    this.autofocus = false,
  }) : variant = LumenButtonVariant.text;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final LumenButtonVariant variant;
  final bool expand;
  final bool loading;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final l = context.lumen;
    final (bg, fg) = switch (variant) {
      LumenButtonVariant.primary => (l.accent, l.onAccent),
      LumenButtonVariant.secondary => (l.palette.surface2, l.palette.textPrimary),
      LumenButtonVariant.text => (Colors.transparent, l.accent),
    };
    final height = l.isTv ? 64.0 : 54.0;
    final style = l.text.headline.copyWith(color: fg);

    Widget content = loading
        ? SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: fg, size: l.isTv ? 28 : 20),
                const SizedBox(width: LumenSpace.xs),
              ],
              Flexible(
                child: Text(label,
                    style: style,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          );

    return LumenPressable(
      onPressed: loading ? null : onPressed,
      autofocus: autofocus,
      borderRadius: LumenRadius.mdAll,
      semanticLabel: label,
      child: Container(
        height: height,
        width: expand ? double.infinity : null,
        padding: EdgeInsets.symmetric(
            horizontal: variant == LumenButtonVariant.text ? LumenSpace.xs : LumenSpace.xl),
        // Nur volle Breite, wenn gewünscht – sonst so breit wie der Inhalt.
        alignment: expand ? Alignment.center : null,
        decoration: BoxDecoration(color: bg, borderRadius: LumenRadius.mdAll),
        child: ExcludeSemantics(child: expand ? content : Center(widthFactor: 1, child: content)),
      ),
    );
  }
}
