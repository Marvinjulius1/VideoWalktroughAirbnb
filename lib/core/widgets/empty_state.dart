import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import 'lumen_button.dart';

/// Liebevoll gestalteter leerer Zustand: großes Icon, ein Titel, ein Satz,
/// optional ein Button. Nie technische Fehlermeldungen.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.autofocusAction = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool autofocusAction;

  @override
  Widget build(BuildContext context) {
    final l = context.lumen;
    final p = l.palette;
    final circle = l.isTv ? 160.0 : 112.0;

    return Center(
      child: SingleChildScrollView(
        padding: l.pagePadding.add(const EdgeInsets.symmetric(vertical: LumenSpace.xxl)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: circle,
                height: circle,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [l.accent.withValues(alpha: 0.22), p.surface1],
                  ),
                ),
                child: Icon(icon, size: circle * 0.42, color: l.accent),
              ),
              const SizedBox(height: LumenSpace.xl),
              Text(title,
                  textAlign: TextAlign.center,
                  style: l.text.title2.copyWith(color: p.textPrimary)),
              const SizedBox(height: LumenSpace.xs),
              Text(message,
                  textAlign: TextAlign.center,
                  style: l.text.callout.copyWith(color: p.textSecondary)),
              if (actionLabel != null) ...[
                const SizedBox(height: LumenSpace.xxl),
                LumenButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  expand: false,
                  autofocus: autofocusAction,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
