import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:lucide_icons_flutter/lucide_icons_600.dart';

import '../../app/providers.dart';
import '../../core/db/database.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/widgets/lumen_button.dart';
import '../../core/widgets/thin_progress.dart';
import '../settings/settings.dart';
import 'data/epg_store.dart';
import 'data/reminders.dart';
import 'epg_providers.dart';

/// Formatiert EPG-Zeiten (UTC + Zeitverschiebung) als lokale Uhrzeit.
class EpgTime {
  EpgTime(BuildContext context, this.offset)
      : _fmt = DateFormat.Hm(Localizations.localeOf(context).toLanguageTag());

  final Duration offset;
  final DateFormat _fmt;

  /// Korrigierter Zeitpunkt (UTC).
  DateTime shift(DateTime utc) => utc.toUtc().add(offset);

  String time(DateTime utc) => _fmt.format(shift(utc).toLocal());

  String range(EpgRow r) => '${time(r.startUtc)} – ${time(r.endUtc)}';
}

const _tabular = [FontFeature.tabularFigures()];

/// Kleine Zeile unter dem Sendernamen: „20:15 Tatort“, Fortschritt, „Danach …“.
class NowNextLine extends ConsumerWidget {
  const NowNextLine({super.key, required this.info, this.compact = false});

  final NowNext? info;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final l = context.lumen;
    final p = l.palette;
    final now = info?.now;
    final next = info?.next;
    if (now == null && next == null) return const SizedBox.shrink();
    final et = EpgTime(context, ref.watch(settingsProvider.select((s) => s.epgOffset)));
    final epgNow = ref.watch(epgNowProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (now != null) ...[
          Text(
            now.title.isEmpty ? t.epgNoInfo : now.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: l.text.footnote.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: 4),
          SizedBox(width: compact ? 120 : 160, child: ThinProgress(value: info!.progressAt(epgNow), height: 3)),
        ],
        if (next != null && !compact)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${t.epgNext}: ${et.time(next.startUtc)} ${next.title}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: l.text.footnote.copyWith(color: p.textSecondary, fontFeatures: _tabular),
            ),
          ),
      ],
    );
  }
}

/// Detailblatt einer Sendung mit „Ansehen“ (läuft gerade) bzw.
/// „Erinnern“ (in der Zukunft).
Future<void> showProgrammeSheet(
  BuildContext context, {
  required ChannelRow channel,
  required EpgRow programme,
  VoidCallback? onWatch,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProgrammeSheet(channel: channel, programme: programme, onWatch: onWatch),
    );

class _ProgrammeSheet extends ConsumerWidget {
  const _ProgrammeSheet({required this.channel, required this.programme, this.onWatch});

  final ChannelRow channel;
  final EpgRow programme;
  final VoidCallback? onWatch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final l = context.lumen;
    final p = l.palette;
    final offset = ref.watch(settingsProvider.select((s) => s.epgOffset));
    final et = EpgTime(context, offset);
    final now = ref.watch(epgNowProvider);
    final running = !programme.startUtc.isAfter(now) && programme.endUtc.isAfter(now);
    final future = programme.startUtc.isAfter(now);
    final reminded = (ref.watch(reminderKeysProvider).value ?? const {})
        .contains(ReminderRepository.keyOf(programme.channelId, programme.startUtc));
    final date = DateFormat.MMMEd(Localizations.localeOf(context).toLanguageTag())
        .format(et.shift(programme.startUtc).toLocal());

    Future<void> remind() async {
      final profile = ref.read(activeSourceProvider);
      if (profile == null) return;
      final res = await ref.read(reminderRepositoryProvider).toggle(
            profileId: profile.id,
            channel: channel,
            programme: programme,
            displayStartUtc: et.shift(programme.startUtc),
            body: t.epgReminderBody(channel.name),
          );
      if (!context.mounted) return;
      final msg = switch (res) {
        ReminderResult.added => t.epgReminderSet,
        ReminderResult.removed => t.epgReminderRemoved,
        ReminderResult.denied => t.epgReminderDenied,
        ReminderResult.tooLate => null,
      };
      if (msg != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(LumenSpace.xl, 0, LumenSpace.xl, LumenSpace.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${channel.name} · $date · ${et.range(programme)}',
              key: const Key('programme-meta'),
              style: l.text.subhead.copyWith(color: p.textSecondary, fontFeatures: _tabular),
            ),
            const SizedBox(height: LumenSpace.xs),
            Text(programme.title.isEmpty ? t.epgNoInfo : programme.title,
                style: l.text.title1.copyWith(color: p.textPrimary)),
            if (running) ...[
              const SizedBox(height: LumenSpace.md),
              ThinProgress(value: NowNext(now: programme).progressAt(now)),
              const SizedBox(height: LumenSpace.xxs),
              Text(t.epgMinutesLeft(programme.endUtc.difference(now).inMinutes),
                  style: l.text.footnote.copyWith(color: p.textSecondary)),
            ],
            if (programme.category != null) ...[
              const SizedBox(height: LumenSpace.sm),
              Text(programme.category!, style: l.text.footnote.copyWith(color: p.textSecondary)),
            ],
            if (programme.description != null) ...[
              const SizedBox(height: LumenSpace.lg),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Text(programme.description!, style: l.text.body.copyWith(color: p.textPrimary)),
              ),
            ],
            const SizedBox(height: LumenSpace.xl),
            Row(
              children: [
                if (running && onWatch != null)
                  LumenButton(
                    key: const Key('programme-watch'),
                    label: t.epgWatch,
                    icon: LucideIcons600.play,
                    expand: false,
                    autofocus: true,
                    onPressed: () {
                      Navigator.pop(context);
                      onWatch!();
                    },
                  ),
                if (future)
                  LumenButton.secondary(
                    key: const Key('programme-remind'),
                    label: reminded ? t.epgReminderSet : t.epgRemind,
                    icon: reminded ? LucideIcons600.bellRing : LucideIcons.bell,
                    expand: false,
                    autofocus: true,
                    onPressed: remind,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
