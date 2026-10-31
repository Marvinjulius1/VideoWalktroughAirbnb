import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/widgets/lumen_button.dart';
import '../../core/widgets/lumen_card.dart';
import '../../core/widgets/thin_progress.dart';
import '../sources/domain/source_profile.dart';
import 'error_text.dart';
import 'source_sync.dart';
import 'sync_controller.dart';

String syncStageText(AppLocalizations t, SyncStage s) => switch (s) {
      SyncStage.connecting => t.syncConnecting,
      SyncStage.categories => t.syncCategories,
      SyncStage.live => t.syncLive,
      SyncStage.vod => t.syncVod,
      SyncStage.series => t.syncSeries,
      SyncStage.epg => t.syncEpg,
      SyncStage.saving || SyncStage.done => t.syncSaving,
    };

String lastSyncText(BuildContext context, DateTime? at, {DateTime? now}) {
  final t = AppLocalizations.of(context);
  if (at == null) return t.neverSynced;
  final n = now ?? DateTime.now();
  if (n.difference(at).inMinutes < 1) return t.lastSynced(t.justNow);
  final locale = Localizations.localeOf(context).toLanguageTag();
  return t.lastSynced(DateFormat.yMMMd(locale).add_Hm().format(at.toLocal()));
}

/// Zeigt, was die aktive Quelle gerade tut: lädt (mit Fortschritt), ist
/// fehlgeschlagen (mit Erklärung und „Erneut versuchen“) oder ist bereit
/// (Anzahl Inhalte und Zeitpunkt der letzten Aktualisierung).
class SyncStatusCard extends ConsumerWidget {
  const SyncStatusCard({super.key, required this.profile});

  final SourceProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final l = context.lumen;
    final p = l.palette;
    final sync = ref.watch(syncControllerProvider);
    final mine = sync.profileId == profile.id;
    final counts = ref.watch(activeCountsProvider).value;
    void refresh() => ref.read(syncControllerProvider.notifier).syncNow(profile);

    if (mine && sync.running) {
      final progress = sync.progress!;
      return LumenCard(
        key: const Key('sync-running'),
        padding: const EdgeInsets.all(LumenSpace.xl),
        child: Semantics(
          liveRegion: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(syncStageText(t, progress.stage),
                  style: l.text.headline.copyWith(color: p.textPrimary)),
              const SizedBox(height: LumenSpace.md),
              ThinProgress(value: progress.fraction),
            ],
          ),
        ),
      );
    }

    if (mine && sync.error != null) {
      final (title, hint) = sourceErrorText(t, sync.error!);
      return LumenCard(
        key: const Key('sync-error'),
        padding: const EdgeInsets.all(LumenSpace.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.circleAlert, color: p.error, size: l.isTv ? 32 : 22),
                const SizedBox(width: LumenSpace.sm),
                Expanded(
                  child: Text(t.syncFailedTitle,
                      style: l.text.headline.copyWith(color: p.textPrimary)),
                ),
              ],
            ),
            const SizedBox(height: LumenSpace.xs),
            Text(title, style: l.text.callout.copyWith(color: p.textPrimary)),
            Text(hint, style: l.text.footnote.copyWith(color: p.textSecondary)),
            const SizedBox(height: LumenSpace.lg),
            LumenButton.secondary(
              label: t.retry,
              icon: LucideIcons.rotateCw,
              expand: false,
              autofocus: true,
              onPressed: refresh,
            ),
          ],
        ),
      );
    }

    final hasContent = (counts?.total ?? 0) > 0;
    return LumenCard(
      key: const Key('sync-ready'),
      padding: const EdgeInsets.all(LumenSpace.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(hasContent ? LucideIcons.circleCheck : LucideIcons.sparkles,
              color: hasContent ? p.success : l.accent, size: l.isTv ? 40 : 28),
          const SizedBox(width: LumenSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasContent
                      ? t.countsLine(counts!.live, counts.vod, counts.series)
                      : t.homeNotSyncedTitle,
                  style: l.text.headline.copyWith(
                    color: p.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: LumenSpace.xxs),
                Text(
                  hasContent ? lastSyncText(context, profile.lastSyncAt) : t.homeNotSyncedBody,
                  style: l.text.callout.copyWith(color: p.textSecondary),
                ),
                const SizedBox(height: LumenSpace.sm),
                LumenButton.text(
                  key: const Key('refresh-now'),
                  label: t.refreshNow,
                  icon: LucideIcons.rotateCw,
                  onPressed: refresh,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
