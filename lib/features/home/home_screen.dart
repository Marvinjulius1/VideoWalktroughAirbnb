import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../app/providers.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/lumen_card.dart';
import '../../core/widgets/lumen_page.dart';

/// Begrüßung je nach Tageszeit.
String greetingFor(DateTime now, AppLocalizations t) {
  final h = now.hour;
  if (h >= 5 && h < 11) return t.greetingMorning;
  if (h >= 11 && h < 18) return t.greetingDay;
  if (h >= 18 && h < 23) return t.greetingEvening;
  return t.greetingNight;
}

/// Ruhige Startseite. Reihen (Weiterschauen, Jetzt live, Favoriten,
/// Neuzugänge) werden ab Phase 2/3 mit echten Daten gefüllt.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, this.clock = DateTime.now});

  final DateTime Function() clock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final l = context.lumen;
    final active = ref.watch(activeSourceProvider);
    final greeting = greetingFor(clock(), t);

    if (active == null) {
      return LumenPage(
        title: greeting,
        fill: EmptyState(
          key: const Key('home-empty'),
          icon: LucideIcons300.tv,
          title: t.emptyNoSourceTitle,
          message: t.emptyNoSourceBody,
          actionLabel: t.addSource,
          autofocusAction: true,
          onAction: () => context.push('/sources/add'),
        ),
      );
    }

    return LumenPage(
      title: greeting,
      subtitle: active.name,
      slivers: [
        SliverToBoxAdapter(
          child: LumenCard(
            padding: const EdgeInsets.all(LumenSpace.xl),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.sparkles, color: l.accent, size: l.isTv ? 40 : 28),
                const SizedBox(width: LumenSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.homeNotSyncedTitle,
                          style: l.text.headline.copyWith(color: l.palette.textPrimary)),
                      const SizedBox(height: LumenSpace.xxs),
                      Text(t.homeNotSyncedBody,
                          style: l.text.callout.copyWith(color: l.palette.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
