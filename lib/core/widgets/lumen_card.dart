import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import 'pressable.dart';

/// Weiche Karte ohne harten Rahmen. Mit [onPressed] antippbar/fokussierbar.
class LumenCard extends StatelessWidget {
  const LumenCard({
    super.key,
    required this.child,
    this.onPressed,
    this.padding = const EdgeInsets.all(LumenSpace.md),
    this.color,
    this.radius = LumenRadius.lgAll,
    this.autofocus = false,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final BorderRadius radius;
  final bool autofocus;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? context.lumen.palette.surface1,
        borderRadius: radius,
      ),
      child: child,
    );
    if (onPressed == null) return card;
    return LumenPressable(
      onPressed: onPressed,
      borderRadius: radius,
      autofocus: autofocus,
      focusScale: 1.03,
      semanticLabel: semanticLabel,
      child: card,
    );
  }
}

/// Eine Zeile in einer gruppierten Liste (wie in den iOS-Einstellungen).
class LumenListTile extends StatelessWidget {
  const LumenListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onPressed,
    this.destructive = false,
    this.autofocus = false,
  });

  final String title;
  final String? subtitle;
  final IconData? leading;
  final Widget? trailing;
  final VoidCallback? onPressed;
  final bool destructive;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final l = context.lumen;
    final p = l.palette;
    final color = destructive ? p.error : p.textPrimary;
    final row = Container(
      constraints: BoxConstraints(minHeight: l.isTv ? 72 : 56),
      padding: const EdgeInsets.symmetric(
          horizontal: LumenSpace.md, vertical: LumenSpace.sm),
      child: Row(
        children: [
          if (leading != null) ...[
            Icon(leading, color: destructive ? p.error : p.textSecondary),
            const SizedBox(width: LumenSpace.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: l.text.body.copyWith(color: color)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: l.text.footnote.copyWith(color: p.textSecondary)),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: LumenSpace.sm),
            trailing!,
          ],
        ],
      ),
    );
    if (onPressed == null) return MergeSemantics(child: row);
    return LumenPressable(
      onPressed: onPressed,
      autofocus: autofocus,
      focusScale: 1.02,
      borderRadius: LumenRadius.mdAll,
      child: row,
    );
  }
}

/// Gruppe von [LumenListTile]s auf einer gemeinsamen Fläche mit feinen
/// Trennlinien und optionaler Überschrift.
class LumenGroup extends StatelessWidget {
  const LumenGroup({super.key, this.title, required this.children, this.footer});

  final String? title;
  final String? footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final l = context.lumen;
    final p = l.palette;
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        items.add(Divider(
            height: 1, thickness: 1, indent: LumenSpace.md, color: p.separator));
      }
      items.add(children[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(
                left: LumenSpace.md, bottom: LumenSpace.xs),
            child: Text(title!.toUpperCase(),
                style: l.text.caption.copyWith(
                    color: p.textSecondary, letterSpacing: 0.6)),
          ),
        Container(
          decoration:
              BoxDecoration(color: p.surface1, borderRadius: LumenRadius.lgAll),
          clipBehavior: Clip.antiAlias,
          child: Column(children: items),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                LumenSpace.md, LumenSpace.xs, LumenSpace.md, 0),
            child: Text(footer!,
                style: l.text.footnote.copyWith(color: p.textSecondary)),
          ),
      ],
    );
  }
}
