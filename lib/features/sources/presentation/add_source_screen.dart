import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/widgets/lumen_button.dart';
import '../../../core/widgets/lumen_card.dart';
import '../../../core/widgets/lumen_page.dart';
import '../domain/source_profile.dart';
import 'source_type_ui.dart';

/// Auswahl der Anmeldeart: Xtream / M3U-Link / M3U-Datei.
class AddSourceScreen extends StatelessWidget {
  const AddSourceScreen({super.key, this.firstRun = false});

  /// Direkt nach dem Onboarding: statt „Zurück“ gibt es „Später“.
  final bool firstRun;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final l = context.lumen;
    final p = l.palette;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !firstRun,
        actions: [
          if (firstRun)
            Padding(
              padding: const EdgeInsets.only(right: LumenSpace.xs),
              child: LumenButton.text(
                label: t.later,
                onPressed: () => context.go('/home'),
              ),
            ),
        ],
      ),
      body: LumenPage(
        title: t.addSourceTitle,
        subtitle: t.addSourceSubtitle,
        slivers: [
          SliverList.separated(
            itemCount: SourceType.values.length,
            separatorBuilder: (_, _) => const SizedBox(height: LumenSpace.sm),
            itemBuilder: (context, i) {
              final type = SourceType.values[i];
              return LumenCard(
                key: Key('add-${type.slug}'),
                autofocus: i == 0,
                semanticLabel: type.label(t),
                padding: const EdgeInsets.all(LumenSpace.lg),
                onPressed: () => context.push('/sources/add/${type.slug}'),
                child: Row(
                  children: [
                    Container(
                      width: l.isTv ? 64 : 48,
                      height: l.isTv ? 64 : 48,
                      decoration: BoxDecoration(
                        color: l.accent.withValues(alpha: 0.14),
                        borderRadius: LumenRadius.mdAll,
                      ),
                      child: Icon(type.icon, color: l.accent),
                    ),
                    const SizedBox(width: LumenSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(type.label(t),
                              style: l.text.headline.copyWith(color: p.textPrimary)),
                          const SizedBox(height: 2),
                          Text(type.description(t),
                              style: l.text.footnote.copyWith(color: p.textSecondary)),
                        ],
                      ),
                    ),
                    Icon(LucideIcons.chevronRight, color: p.textSecondary, size: 20),
                  ],
                ),
              );
            },
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: LumenSpace.xxl),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.info, size: 18, color: p.textSecondary),
                  const SizedBox(width: LumenSpace.xs),
                  Expanded(
                    child: Text(t.contentNotice,
                        style: l.text.footnote.copyWith(color: p.textSecondary)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
