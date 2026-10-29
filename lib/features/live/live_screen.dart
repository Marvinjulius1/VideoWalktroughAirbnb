import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../app/providers.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/lumen_page.dart';

/// Live-TV. Kategorien und Kanäle folgen in Phase 3.
class LiveScreen extends ConsumerWidget {
  const LiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final hasSource = ref.watch(activeSourceProvider) != null;
    return LumenPage(
      title: t.tabLive,
      fill: hasSource
          ? EmptyState(
              icon: LucideIcons300.radio,
              title: t.liveEmptyTitle,
              message: t.liveEmptyBody,
            )
          : EmptyState(
              icon: LucideIcons300.radio,
              title: t.emptyNoSourceTitle,
              message: t.emptyNoSourceBody,
              actionLabel: t.addSource,
              onAction: () => context.push('/sources/add'),
            ),
    );
  }
}
