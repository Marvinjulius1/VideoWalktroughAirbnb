import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/db/database.dart';
import '../live/live_providers.dart';
import '../settings/settings.dart';
import '../sync/sync_controller.dart';
import 'data/epg_store.dart';
import 'data/reminders.dart';

/// Aktuelle Uhrzeit (in Tests überschreibbar).
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Tickt jede Minute, damit Fortschrittsbalken und „Jetzt“ aktuell bleiben.
final minuteTickProvider = StreamProvider<DateTime>((ref) async* {
  final clock = ref.watch(clockProvider);
  yield clock();
  yield* Stream.periodic(const Duration(minutes: 1), (_) => clock());
});

/// „Jetzt“ in der Zeitrechnung der EPG-Daten (also abzüglich der
/// eingestellten Zeitverschiebung).
final epgNowProvider = Provider<DateTime>((ref) {
  final now = ref.watch(minuteTickProvider).value ?? ref.watch(clockProvider)();
  final offset = ref.watch(settingsProvider.select((s) => s.epgOffset));
  return now.toUtc().subtract(offset);
});

/// Jetzt/Danach für alle Sender der aktuell angezeigten Liste.
final liveNowNextProvider = FutureProvider<Map<String, NowNext>>((ref) async {
  final p = ref.watch(activeSourceProvider);
  final channels = ref.watch(liveChannelsProvider).value ?? const <ChannelRow>[];
  if (p == null || channels.isEmpty) return const {};
  final now = ref.watch(epgNowProvider);
  ref.watch(syncControllerProvider.select((s) => s.progress?.stage)); // nach Sync neu laden
  return ref.watch(epgStoreProvider).nowNext(p.id, channels.map((c) => c.epgChannelId).whereType<String>(), now);
});

/// Jetzt/Danach für einen einzelnen Kanal (Player-Overlay).
final channelNowNextProvider = FutureProvider.family<NowNext?, String?>((ref, epgId) async {
  final p = ref.watch(activeSourceProvider);
  if (p == null || epgId == null) return null;
  final now = ref.watch(epgNowProvider);
  final map = await ref.watch(epgStoreProvider).nowNext(p.id, [epgId], now);
  return map[epgId];
});

final epgCountProvider = StreamProvider<int>((ref) {
  final p = ref.watch(activeSourceProvider);
  if (p == null) return Stream.value(0);
  return ref.watch(epgStoreProvider).watchCount(p.id);
});

final notificationSchedulerProvider =
    Provider<NotificationScheduler>((ref) => LocalNotificationScheduler());

final reminderRepositoryProvider = Provider(
  (ref) => ReminderRepository(
    ref.watch(databaseProvider),
    ref.watch(notificationSchedulerProvider),
    now: ref.watch(clockProvider),
  ),
);

final reminderKeysProvider = StreamProvider<Set<String>>((ref) {
  final p = ref.watch(activeSourceProvider);
  if (p == null) return Stream.value(const {});
  return ref.watch(reminderRepositoryProvider).watchKeys(p.id);
});
