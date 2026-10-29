import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../app/providers.dart';
import '../../core/design/tokens.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/lumen_page.dart';
import '../../core/widgets/segmented_control.dart';

enum MediaKind { movies, series }

/// Filme & Serien in einem Bereich mit Segment-Umschalter.
/// Raster und Details folgen in Phase 3.
class MediaScreen extends ConsumerStatefulWidget {
  const MediaScreen({super.key});

  @override
  ConsumerState<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends ConsumerState<MediaScreen> {
  MediaKind _kind = MediaKind.movies;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final hasSource = ref.watch(activeSourceProvider) != null;
    return LumenPage(
      title: t.tabMedia,
      slivers: [
        SliverToBoxAdapter(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: LumenSegmentedControl<MediaKind>(
              segments: {MediaKind.movies: t.movies, MediaKind.series: t.series},
              selected: _kind,
              onChanged: (k) => setState(() => _kind = k),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: LumenSpace.x3)),
        SliverToBoxAdapter(
          child: hasSource
              ? EmptyState(
                  icon: _kind == MediaKind.movies
                      ? LucideIcons300.film
                      : LucideIcons300.monitorPlay,
                  title: _kind == MediaKind.movies ? t.moviesEmptyTitle : t.seriesEmptyTitle,
                  message: t.mediaEmptyBody,
                )
              : EmptyState(
                  icon: LucideIcons300.film,
                  title: t.emptyNoSourceTitle,
                  message: t.emptyNoSourceBody,
                  actionLabel: t.addSource,
                  onAction: () => context.push('/sources/add'),
                ),
        ),
      ],
    );
  }
}
