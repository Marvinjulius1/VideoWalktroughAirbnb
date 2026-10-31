import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';
import 'package:lucide_icons_flutter/lucide_icons_600.dart';

import '../../app/providers.dart';
import '../../core/db/database.dart';
import '../../core/design/haptics.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/lumen_chip.dart';
import '../../core/widgets/lumen_page.dart';
import '../../core/widgets/pressable.dart';
import '../player/live_player_screen.dart';
import '../epg/data/epg_store.dart';
import '../epg/epg_providers.dart';
import '../epg/epg_widgets.dart';
import 'data/live_repository.dart';
import 'live_providers.dart';
import 'widgets/channel_logo.dart';

/// Live-TV: Kategorien oben (mobil) bzw. links (TV), darunter/daneben die
/// Sender. Tippen startet den Player, der Stern merkt einen Favoriten.
class LiveScreen extends ConsumerWidget {
  const LiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final l = context.lumen;
    final hasSource = ref.watch(activeSourceProvider) != null;
    final count = ref.watch(liveChannelCountProvider).value ?? 0;

    if (!hasSource) {
      return LumenPage(
        title: t.tabLive,
        fill: EmptyState(
          icon: LucideIcons300.radio,
          title: t.emptyNoSourceTitle,
          message: t.emptyNoSourceBody,
          actionLabel: t.addSource,
          onAction: () => context.push('/sources/add'),
        ),
      );
    }
    if (count == 0) {
      return LumenPage(
        title: t.tabLive,
        fill: EmptyState(icon: LucideIcons300.radio, title: t.liveEmptyTitle, message: t.liveEmptyBody),
      );
    }
    return l.isTv ? const _TvLiveLayout() : const _PhoneLiveLayout();
  }
}

/// Einträge der Filterleiste: Favoriten, Zuletzt, Alle, dann Kategorien.
List<(LiveFilter, String, IconData?)> _filters(AppLocalizations t, List<CategoryRow> cats) => [
      (const FavoriteChannels(), t.liveFavorites, LucideIcons.star),
      (const RecentChannels(), t.liveRecent, LucideIcons.history),
      (const AllChannels(), t.liveAll, null),
      for (final c in cats) (CategoryChannels(c.remoteId), c.name, null),
    ];

class _PhoneLiveLayout extends ConsumerWidget {
  const _PhoneLiveLayout();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final l = context.lumen;
    final cats = ref.watch(liveCategoriesProvider).value ?? const [];
    final filter = ref.watch(effectiveLiveFilterProvider);
    final filters = _filters(t, cats);

    return LumenPage(
      title: t.tabLive,
      trailing: const _GuideButton(),
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(
            height: 40,
            child: ListView.separated(
              key: const Key('live-filters'),
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: LumenSpace.xs),
              itemBuilder: (_, i) {
                final (f, label, icon) = filters[i];
                return Center(
                  child: LumenChip(
                    label: label,
                    icon: icon,
                    selected: f == filter,
                    onPressed: () => ref.read(selectedLiveFilterProvider.notifier).select(f),
                  ),
                );
              },
            ),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: l.isTv ? LumenSpace.xl : LumenSpace.lg)),
        const _ChannelSliver(),
      ],
    );
  }
}

class _TvLiveLayout extends ConsumerWidget {
  const _TvLiveLayout();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final l = context.lumen;
    final p = l.palette;
    final cats = ref.watch(liveCategoriesProvider).value ?? const [];
    final filter = ref.watch(effectiveLiveFilterProvider);
    final filters = _filters(t, cats);

    return Padding(
      padding: l.pagePadding.copyWith(top: LumenSpace.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(t.tabLive, style: l.text.largeTitle.copyWith(color: p.textPrimary))),
              const _GuideButton(),
            ],
          ),
          const SizedBox(height: LumenSpace.xl),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 380,
                  child: ListView.builder(
                    key: const Key('live-filters'),
                    itemCount: filters.length,
                    itemBuilder: (_, i) {
                      final (f, label, icon) = filters[i];
                      final selected = f == filter;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: LumenSpace.xs, right: LumenSpace.lg),
                        child: Semantics(
                          selected: selected,
                          child: LumenPressable(
                            onPressed: () => ref.read(selectedLiveFilterProvider.notifier).select(f),
                            focusScale: 1.03,
                            haptic: false,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: LumenSpace.lg, vertical: LumenSpace.md),
                              decoration: BoxDecoration(
                                color: selected ? p.surface2 : Colors.transparent,
                                borderRadius: LumenRadius.mdAll,
                              ),
                              child: Row(
                                children: [
                                  if (icon != null) ...[
                                    Icon(icon, color: p.textSecondary),
                                    const SizedBox(width: LumenSpace.sm),
                                  ],
                                  Expanded(
                                    child: Text(label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: l.text.headline.copyWith(
                                            color: selected ? p.textPrimary : p.textSecondary)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Expanded(child: CustomScrollView(slivers: [_ChannelSliver()])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Senderliste als Sliver (lazy: nur sichtbare Zeilen werden gebaut).
class _ChannelSliver extends ConsumerWidget {
  const _ChannelSliver();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final channels = ref.watch(liveChannelsProvider).value;
    final filter = ref.watch(effectiveLiveFilterProvider);
    final favs = ref.watch(favoriteKeysProvider(ContentKind.live)).value ?? const {};
    final epg = ref.watch(liveNowNextProvider).value ?? const {};

    if (channels == null) return const SliverToBoxAdapter(child: SizedBox.shrink());
    if (channels.isEmpty) {
      final (title, body) = switch (filter) {
        FavoriteChannels() => (t.liveNoFavoritesTitle, t.liveNoFavoritesBody),
        RecentChannels() => (t.liveNoRecentTitle, t.liveNoRecentBody),
        _ => (t.liveEmptyTitle, t.liveEmptyCategory),
      };
      return SliverToBoxAdapter(
        child: EmptyState(
          key: const Key('live-filter-empty'),
          icon: filter is FavoriteChannels ? LucideIcons300.star : LucideIcons300.radio,
          title: title,
          message: body,
        ),
      );
    }
    return SliverList.builder(
      itemCount: channels.length,
      itemBuilder: (context, i) => ChannelTile(
        key: ValueKey('ch-${channels[i].id}'),
        channel: channels[i],
        favorite: favs.contains(channels[i].itemKey),
        nowNext: epg[channels[i].epgChannelId],
        onPlay: () => openLivePlayer(context, channels, i),
        onToggleFavorite: () {
          final p = ref.read(activeSourceProvider);
          if (p == null) return;
          LumenHaptics.light();
          ref.read(liveRepositoryProvider).toggleFavorite(p.id, ContentKind.live, channels[i].itemKey);
        },
      ),
    );
  }
}

class ChannelTile extends StatelessWidget {
  const ChannelTile({
    super.key,
    required this.channel,
    required this.favorite,
    required this.onPlay,
    required this.onToggleFavorite,
    this.nowNext,
  });

  final ChannelRow channel;
  final NowNext? nowNext;
  final bool favorite;
  final VoidCallback onPlay;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final l = context.lumen;
    final p = l.palette;
    final tv = l.isTv;
    return Padding(
      padding: const EdgeInsets.only(bottom: LumenSpace.xxs),
      child: Row(
        children: [
          Expanded(
            child: LumenPressable(
              onPressed: onPlay,
              focusScale: 1.02,
              semanticLabel: channel.num == null
                  ? channel.name
                  : '${t.channelNumber(channel.num!)}, ${channel.name}',
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: LumenSpace.xs, horizontal: LumenSpace.xxs),
                child: Row(
                  children: [
                    ChannelLogo(
                      name: channel.name,
                      url: channel.logo,
                      width: tv ? 96 : 64,
                      height: tv ? 64 : 44,
                    ),
                    const SizedBox(width: LumenSpace.md),
                    if (channel.num != null)
                      SizedBox(
                        width: tv ? 64 : 40,
                        child: Text(
                          '${channel.num}',
                          style: l.text.subhead.copyWith(
                            color: p.textSecondary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(channel.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: l.text.body.copyWith(color: p.textPrimary)),
                          if (nowNext != null) ...[
                            const SizedBox(height: 2),
                            NowNextLine(info: nowNext, compact: !tv),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          LumenPressable(
            key: Key('fav-${channel.id}'),
            onPressed: onToggleFavorite,
            borderRadius: LumenRadius.pillAll,
            focusScale: 1.15,
            haptic: false,
            semanticLabel: favorite ? t.favoriteRemove : t.favoriteAdd,
            child: Padding(
              padding: const EdgeInsets.all(LumenSpace.sm),
              child: Icon(
                favorite ? LucideIcons600.star : LucideIcons.star,
                color: favorite ? l.accent : p.textTertiary,
                size: tv ? 30 : 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideButton extends StatelessWidget {
  const _GuideButton();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return LumenChip(
      key: const Key('open-guide'),
      label: t.epgGuide,
      icon: LucideIcons.calendarDays,
      selected: false,
      onPressed: () => context.push('/live/guide'),
    );
  }
}
