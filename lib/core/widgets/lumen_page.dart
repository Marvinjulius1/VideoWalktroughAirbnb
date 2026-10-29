import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';

/// Standard-Seite mit großem Titel (wie iOS „Large Title“) und
/// scrollbarem Inhalt. Berücksichtigt Tab-Leiste, Notch und TV-Overscan.
class LumenPage extends StatelessWidget {
  const LumenPage({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.slivers,
    this.fill,
    this.leading,
  }) : assert(slivers != null || fill != null);

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;

  /// Scrollbarer Inhalt.
  final List<Widget>? slivers;

  /// Alternativ: ein Widget, das den restlichen Platz füllt (z. B. ein
  /// leerer Zustand).
  final Widget? fill;

  @override
  Widget build(BuildContext context) {
    final l = context.lumen;
    final p = l.palette;
    final horizontal = l.pagePadding.horizontal / 2;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return CustomScrollView(
      slivers: [
        SliverSafeArea(
          bottom: false,
          sliver: SliverPadding(
            padding: EdgeInsets.fromLTRB(
              horizontal,
              l.isTv ? LumenSpace.x3 : LumenSpace.sm,
              horizontal,
              LumenSpace.xl,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(height: LumenSpace.xs),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(title,
                              style: l.text.largeTitle
                                  .copyWith(color: p.textPrimary)),
                        ),
                      ),
                      ?trailing,
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: LumenSpace.xxs),
                    Text(subtitle!,
                        style: l.text.callout.copyWith(color: p.textSecondary)),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (slivers != null)
          for (final s in slivers!)
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: horizontal),
              sliver: s,
            ),
        if (fill != null)
          SliverFillRemaining(hasScrollBody: false, child: fill),
        SliverToBoxAdapter(child: SizedBox(height: bottom + LumenSpace.xl)),
      ],
    );
  }
}
