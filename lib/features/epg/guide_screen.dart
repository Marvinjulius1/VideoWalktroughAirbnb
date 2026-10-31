import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../app/providers.dart';
import '../../core/db/database.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/lumen_chip.dart';
import '../../core/widgets/pressable.dart';
import '../live/live_providers.dart';
import '../live/widgets/channel_logo.dart';
import '../player/live_player_screen.dart';
import '../settings/settings.dart';
import '../sync/sync_controller.dart';
import 'epg_providers.dart';
import 'epg_widgets.dart';

/// Tag im Programmführer: 0 = heute, 1 = morgen, …
final guideDayProvider = NotifierProvider<GuideDay, int>(GuideDay.new);

class GuideDay extends Notifier<int> {
  @override
  int build() => 0;
  void select(int d) => state = d.clamp(0, 6);
}

@immutable
class GuideWindow {
  const GuideWindow(this.fromUtc, this.toUtc);
  final DateTime fromUtc;
  final DateTime toUtc;
  Duration get length => toUtc.difference(fromUtc);
}

/// Angezeigtes Fenster: lokaler Tag 00:00 bis 24:00 (bzw. ab jetzt − 1 h,
/// damit „heute“ nicht mit vergangenen Sendungen beginnt).
final guideWindowProvider = Provider<GuideWindow>((ref) {
  final day = ref.watch(guideDayProvider);
  final now = ref.watch(clockProvider)().toLocal();
  final dayStart = DateTime(now.year, now.month, now.day + day);
  final start = day == 0 ? DateTime(now.year, now.month, now.day, now.hour).subtract(const Duration(hours: 1)) : dayStart;
  final end = DateTime(dayStart.year, dayStart.month, dayStart.day + 1, 2); // bis 02:00 nachts
  return GuideWindow(start.toUtc(), end.toUtc());
});

final guideDataProvider = FutureProvider<Map<String, List<EpgRow>>>((ref) async {
  final p = ref.watch(activeSourceProvider);
  final channels = ref.watch(liveChannelsProvider).value ?? const <ChannelRow>[];
  if (p == null || channels.isEmpty) return const {};
  final w = ref.watch(guideWindowProvider);
  final offset = ref.watch(settingsProvider.select((s) => s.epgOffset));
  ref.watch(syncControllerProvider.select((s) => s.progress?.stage));
  return ref.watch(epgStoreProvider).window(
        p.id,
        channels.map((c) => c.epgChannelId).whereType<String>(),
        w.fromUtc.subtract(offset),
        w.toUtc.subtract(offset),
      );
});

/// Programmführer als Raster: Zeit waagerecht, Sender senkrecht.
class GuideScreen extends ConsumerStatefulWidget {
  const GuideScreen({super.key});

  @override
  ConsumerState<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends ConsumerState<GuideScreen> {
  final _channelsV = ScrollController();
  final _gridV = ScrollController();
  final _gridH = ScrollController();
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    // Senderspalte und Raster scrollen senkrecht gemeinsam.
    void link(ScrollController from, ScrollController to) => from.addListener(() {
          if (_syncing || !to.hasClients) return;
          _syncing = true;
          to.jumpTo(from.offset.clamp(0, to.position.maxScrollExtent));
          _syncing = false;
        });
    link(_channelsV, _gridV);
    link(_gridV, _channelsV);
  }

  @override
  void dispose() {
    _channelsV.dispose();
    _gridV.dispose();
    _gridH.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final l = context.lumen;
    final p = l.palette;
    final tv = l.isTv;
    final channels = ref.watch(liveChannelsProvider).value ?? const <ChannelRow>[];
    final epgCount = ref.watch(epgCountProvider).value ?? 0;
    final day = ref.watch(guideDayProvider);
    final window = ref.watch(guideWindowProvider);
    final data = ref.watch(guideDataProvider).value ?? const {};
    final offset = ref.watch(settingsProvider.select((s) => s.epgOffset));
    final now = ref.watch(minuteTickProvider).value ?? ref.watch(clockProvider)();

    final pxPerMin = tv ? 6.0 : 4.0;
    final rowH = tv ? 96.0 : 68.0;
    final colW = tv ? 240.0 : 112.0;
    const headerH = 32.0;
    final width = window.length.inMinutes * pxPerMin;
    double x(DateTime utc) => utc.difference(window.fromUtc).inSeconds / 60 * pxPerMin;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dayNames = [
      t.epgToday,
      t.epgTomorrow,
      for (var i = 2; i < 7; i++) DateFormat.EEEE(locale).format(DateTime.now().add(Duration(days: i))),
    ];

    final header = Padding(
      padding: tv ? l.pagePadding.copyWith(bottom: 0) : const EdgeInsets.fromLTRB(LumenSpace.pagePhone, 0, LumenSpace.pagePhone, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.epgGuideTitle, style: l.text.largeTitle.copyWith(color: p.textPrimary)),
          const SizedBox(height: LumenSpace.md),
          SizedBox(
            height: tv ? 56 : 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: dayNames.length,
              separatorBuilder: (_, _) => const SizedBox(width: LumenSpace.xs),
              itemBuilder: (_, i) => Center(
                child: LumenChip(
                  label: dayNames[i],
                  selected: i == day,
                  onPressed: () {
                    ref.read(guideDayProvider.notifier).select(i);
                    if (_gridH.hasClients) _gridH.jumpTo(0);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: LumenSpace.md),
        ],
      ),
    );

    Widget body;
    if (epgCount == 0 || channels.isEmpty) {
      body = EmptyState(
        key: const Key('guide-empty'),
        icon: LucideIcons300.calendarDays,
        title: t.epgEmptyTitle,
        message: t.epgEmptyBody,
      );
    } else {
      // Halbstunden-Marken für die Zeitleiste.
      final marks = <DateTime>[];
      var m = window.fromUtc.toLocal();
      m = DateTime(m.year, m.month, m.day, m.hour, m.minute < 30 ? 30 : 60);
      while (m.toUtc().isBefore(window.toUtc)) {
        marks.add(m);
        m = m.add(const Duration(minutes: 30));
      }
      final hm = DateFormat.Hm(locale);
      final nowX = x(now.toUtc());

      body = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Senderspalte
          SizedBox(
            width: colW,
            child: Column(
              children: [
                const SizedBox(height: headerH),
                Expanded(
                  child: ListView.builder(
                    controller: _channelsV,
                    itemExtent: rowH,
                    itemCount: channels.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: LumenSpace.xs, vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: ChannelLogo(
                              name: channels[i].name,
                              url: channels[i].logo,
                              width: colW - 16,
                              height: rowH - 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Raster
          Expanded(
            child: SingleChildScrollView(
              key: const Key('guide-grid'),
              controller: _gridH,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                child: Stack(
                  children: [
                    Column(
                      children: [
                        SizedBox(
                          height: headerH,
                          child: Stack(
                            children: [
                              for (final mark in marks)
                                Positioned(
                                  left: x(mark.toUtc()) + 4,
                                  top: 6,
                                  child: Text(hm.format(mark),
                                      style: l.text.caption.copyWith(
                                          color: p.textSecondary, fontFeatures: const [FontFeature.tabularFigures()])),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            controller: _gridV,
                            itemExtent: rowH,
                            itemCount: channels.length,
                            itemBuilder: (_, i) => _GuideRow(
                              channel: channels[i],
                              programmes: data[channels[i].epgChannelId] ?? const [],
                              x: (utc) => x(utc.add(offset)),
                              width: width,
                              nowUtc: now.toUtc().subtract(offset),
                              time: EpgTime(context, offset),
                              onWatch: () => openLivePlayer(context, channels, i),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (nowX > 0 && nowX < width)
                      Positioned(
                        left: nowX,
                        top: 0,
                        bottom: 0,
                        child: IgnorePointer(
                          child: Container(key: const Key('guide-now-line'), width: 2, color: p.live),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );

      // Beim Öffnen von „heute“ zur aktuellen Uhrzeit springen.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (day == 0 && _gridH.hasClients && _gridH.offset == 0 && nowX > 0) {
          _gridH.jumpTo((nowX - 60 * pxPerMin).clamp(0, _gridH.position.maxScrollExtent));
        }
      });
    }

    return Scaffold(
      appBar: AppBar(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideRow extends StatelessWidget {
  const _GuideRow({
    required this.channel,
    required this.programmes,
    required this.x,
    required this.width,
    required this.nowUtc,
    required this.onWatch,
    required this.time,
  });

  final EpgTime time;

  final ChannelRow channel;
  final List<EpgRow> programmes;
  final double Function(DateTime utc) x;
  final double width;
  final DateTime nowUtc;
  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final l = context.lumen;
    final p = l.palette;
    return Stack(
      children: [
        if (programmes.isEmpty)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: LumenSpace.sm),
                decoration: BoxDecoration(color: p.bgElevated, borderRadius: LumenRadius.smAll),
                child: Text(t.epgNoInfo, style: l.text.footnote.copyWith(color: p.textSecondary)),
              ),
            ),
          ),
        for (final pr in programmes)
          () {
            final left = x(pr.startUtc).clamp(0.0, width);
            final right = x(pr.endUtc).clamp(0.0, width);
            final w = right - left;
            if (w < 2) return const SizedBox.shrink();
            final running = !pr.startUtc.isAfter(nowUtc) && pr.endUtc.isAfter(nowUtc);
            return Positioned(
              left: left,
              width: w,
              top: 0,
              bottom: 0,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: LumenPressable(
                  key: ValueKey('guide-${channel.id}-${pr.id}'),
                  onPressed: () => showProgrammeSheet(
                    context,
                    channel: channel,
                    programme: pr,
                    onWatch: onWatch,
                  ),
                  focusScale: 1.0,
                  borderRadius: LumenRadius.smAll,
                  semanticLabel: '${channel.name}: ${pr.title}',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: LumenSpace.sm, vertical: 6),
                    decoration: BoxDecoration(
                      color: running ? p.surface2 : p.surface1,
                      borderRadius: LumenRadius.smAll,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(pr.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: l.text.subhead.copyWith(color: p.textPrimary)),
                        if (w > 90)
                          Text(time.time(pr.startUtc),
                              maxLines: 1,
                              style: l.text.caption.copyWith(color: p.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }(),
      ],
    );
  }
}
