import 'package:drift/drift.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/db/database.dart';

/// Plant lokale Benachrichtigungen. Als Schnittstelle, damit Tests ohne
/// echtes Betriebssystem auskommen.
abstract interface class NotificationScheduler {
  /// Fragt beim ersten Mal nach der Erlaubnis. `false` = abgelehnt.
  Future<bool> ensurePermission();
  Future<void> schedule({required int id, required String title, required String body, required DateTime atUtc});
  Future<void> cancel(int id);
}

/// Echte Umsetzung mit `flutter_local_notifications`.
///
/// Alles bleibt auf dem Gerät – es gibt keinen Push-Server.
class LocalNotificationScheduler implements NotificationScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  @override
  Future<bool> ensurePermission() async {
    await _init();
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) return await ios.requestPermissions(alert: true, sound: true) ?? false;
    final android =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    return true;
  }

  @override
  Future<void> schedule({required int id, required String title, required String body, required DateTime atUtc}) async {
    await _init();
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      // Ein absoluter Zeitpunkt in UTC – unabhängig von Zeitzonen-Regeln.
      scheduledDate: tz.TZDateTime.from(atUtc.toUtc(), tz.UTC),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders',
          'Erinnerungen',
          channelDescription: 'Erinnerungen an Sendungen',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancel(int id) async {
    await _init();
    await _plugin.cancel(id: id);
  }
}

enum ReminderResult { added, removed, denied, tooLate }

/// Erinnerungen an Sendungen: Datenbank + Benachrichtigung.
class ReminderRepository {
  ReminderRepository(this._db, this._scheduler, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final LumenDatabase _db;
  final NotificationScheduler _scheduler;
  final DateTime Function() _now;

  /// Sekundengenau – so speichert die Datenbank Zeitpunkte.
  static String keyOf(String epgChannelId, DateTime startUtc) =>
      '$epgChannelId|${startUtc.millisecondsSinceEpoch ~/ 1000}';

  Stream<Set<String>> watchKeys(String profileId) =>
      (_db.select(_db.reminders)..where((r) => r.profileId.equals(profileId)))
          .watch()
          .map((rows) => {for (final r in rows) keyOf(r.epgChannelId, r.startUtc)});

  /// Schaltet die Erinnerung für eine Sendung um.
  /// [displayStartUtc] ist der (ggf. um die Zeitverschiebung korrigierte)
  /// Beginn, zu dem benachrichtigt wird.
  Future<ReminderResult> toggle({
    required String profileId,
    required ChannelRow channel,
    required EpgRow programme,
    required DateTime displayStartUtc,
    required String body,
  }) async {
    final existing = await (_db.select(_db.reminders)
          ..where((r) =>
              r.profileId.equals(profileId) &
              r.epgChannelId.equals(programme.channelId) &
              r.startUtc.equals(programme.startUtc)))
        .getSingleOrNull();
    if (existing != null) {
      await _scheduler.cancel(existing.id);
      await (_db.delete(_db.reminders)..where((r) => r.id.equals(existing.id))).go();
      return ReminderResult.removed;
    }
    if (!displayStartUtc.isAfter(_now().toUtc())) return ReminderResult.tooLate;
    if (!await _scheduler.ensurePermission()) return ReminderResult.denied;

    final id = await _db.into(_db.reminders).insert(RemindersCompanion.insert(
          profileId: profileId,
          channelKey: channel.itemKey,
          channelName: channel.name,
          epgChannelId: programme.channelId,
          title: programme.title,
          startUtc: programme.startUtc,
        ));
    await _scheduler.schedule(id: id, title: programme.title, body: body, atUtc: displayStartUtc);
    return ReminderResult.added;
  }

  /// Vergangene Erinnerungen aufräumen.
  Future<void> prune() => (_db.delete(_db.reminders)
        ..where((r) => r.startUtc.isSmallerThanValue(_now().toUtc().subtract(const Duration(hours: 1)))))
      .go();
}
