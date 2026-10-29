import 'package:drift/drift.dart' show Value;
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/core/db/database.dart';
import 'package:lumen/core/security/secret_store.dart';
import 'package:lumen/features/live/data/live_repository.dart';
import 'package:lumen/features/player/channel_zapper.dart';
import 'package:lumen/features/player/live_player_controller.dart';
import 'package:lumen/features/player/playable.dart';
import 'package:lumen/features/player/player_engine.dart';
import 'package:lumen/features/sources/data/sources_repository.dart';
import 'package:lumen/features/sources/data/xtream/xtream_client.dart';
import 'package:lumen/features/sources/domain/source_profile.dart';

import '../helpers/fake_engine.dart';
import '../helpers/test_app.dart';

ChannelRow channel(int i, {int? num, String? url}) => ChannelRow(
      id: i,
      profileId: 'p',
      itemKey: '${1000 + i}',
      num: num,
      name: 'Testkanal $i',
      tvArchive: false,
      archiveDays: 0,
      url: url,
      sortIndex: i,
    );

void main() {
  group('ChannelZapper', () {
    test('Hoch/Runter mit Umlauf', () {
      final z = ChannelZapper(numbers: [1, 2, 3], start: 0);
      expect(z.prev(), 2);
      expect(z.next(), 0);
      expect(z.next(), 1);
    });

    test('letzter Sender springt hin und her', () {
      final z = ChannelZapper(numbers: [1, 2, 3, 4], start: 0);
      expect(z.lastChannel(), 0); // noch kein vorheriger
      z.select(3);
      expect(z.lastChannel(), 0);
      expect(z.lastChannel(), 3);
    });

    test('Zifferneingabe nach Kanalnummer', () {
      final z = ChannelZapper(numbers: [5, 12, 101], start: 0);
      z
        ..addDigit(1)
        ..addDigit(2);
      expect(z.pendingDigits, '12');
      expect(z.commitDigits(), 1);
      expect(z.pendingDigits, '');
      z
        ..addDigit(9)
        ..addDigit(9);
      expect(z.commitDigits(), isNull); // gibt es nicht
      expect(z.index, 1);
    });

    test('ohne Kanalnummern zählt die Position', () {
      final z = ChannelZapper(numbers: [null, null, null], start: 0);
      z.addDigit(3);
      expect(z.commitDigits(), 2);
    });

    test('höchstens fünf Ziffern', () {
      final z = ChannelZapper(numbers: [1], start: 0);
      for (var i = 0; i < 8; i++) {
        z.addDigit(1);
      }
      expect(z.pendingDigits, '11111');
    });
  });

  group('StreamResolver', () {
    final created = DateTime(2026);
    test('Xtream baut Live-Adresse im gewählten Format', () {
      final r = StreamResolver(
        profile: SourceProfile(
            id: 'p', name: 'X', type: SourceType.xtream, createdAt: created, serverUrl: 'http://srv:8080'),
        credentials: const SourceCredentials(username: 'u', password: 'p w'),
        liveFormat: StreamFormat.m3u8,
      );
      expect(r.live(channel(1))!.uri.toString(), 'http://srv:8080/live/u/p%20w/1001.m3u8');
    });

    test('M3U nimmt die direkte Adresse und den User-Agent', () {
      final r = StreamResolver(
        profile: SourceProfile(id: 'p', name: 'M', type: SourceType.m3uUrl, createdAt: created),
        credentials: const SourceCredentials(),
      );
      final row = channel(1, url: 'http://x/1.ts').copyWith(userAgent: const Value('Agent/1'));
      final s = r.live(row)!;
      expect(s.uri.toString(), 'http://x/1.ts');
      expect(s.headers['User-Agent'], 'Agent/1');
      expect(r.live(channel(2)), isNull);
    });

    test('toString verrät keine Zugangsdaten', () {
      final s = PlayableStream(Uri.parse('http://srv/live/nutzer/geheim/1.ts'));
      expect(s.toString(), isNot(contains('geheim')));
    });
  });

  group('LiveRepository', () {
    late LumenDatabase db;
    late LiveRepository repo;
    late String pid;

    setUp(() async {
      db = memoryDb();
      repo = LiveRepository(db);
      final p = await SourcesRepository(db, InMemorySecretStore()).add(
          name: 'T', type: SourceType.m3uUrl, credentials: const SourceCredentials());
      pid = p.id;
      await db.batch((b) {
        b.insertAll(db.categories, [
          CategoriesCompanion.insert(profileId: pid, kind: ContentKind.live, remoteId: 'a', name: 'A', sortIndex: 0),
          CategoriesCompanion.insert(profileId: pid, kind: ContentKind.live, remoteId: 'b', name: 'B', sortIndex: 1),
          CategoriesCompanion.insert(profileId: pid, kind: ContentKind.vod, remoteId: 'v', name: 'V', sortIndex: 0),
        ]);
        b.insertAll(db.channels, [
          for (var i = 0; i < 6; i++)
            ChannelsCompanion.insert(
              profileId: pid,
              itemKey: 'k$i',
              name: 'Kanal $i',
              categoryId: Value(i.isEven ? 'a' : 'b'),
              sortIndex: i,
            ),
        ]);
      });
    });
    tearDown(() => db.close());

    test('Kategorien nur für Live, sortiert', () async {
      final cats = await repo.watchCategories(pid).first;
      expect(cats.map((c) => c.name), ['A', 'B']);
    });

    test('Filter nach Kategorie und alle', () async {
      expect((await repo.watchChannels(pid, const CategoryChannels('b')).first).map((c) => c.name),
          ['Kanal 1', 'Kanal 3', 'Kanal 5']);
      expect(await repo.watchChannels(pid, const AllChannels()).first, hasLength(6));
      expect(await repo.watchChannelCount(pid).first, 6);
    });

    test('Favoriten umschalten und eigene Reihenfolge', () async {
      expect(await repo.toggleFavorite(pid, ContentKind.live, 'k2'), isTrue);
      expect(await repo.toggleFavorite(pid, ContentKind.live, 'k4'), isTrue);
      expect(await repo.toggleFavorite(pid, ContentKind.live, 'k0'), isTrue);
      expect((await repo.watchChannels(pid, const FavoriteChannels()).first).map((c) => c.itemKey),
          ['k2', 'k4', 'k0']);
      await repo.reorderFavorites(pid, ContentKind.live, ['k0', 'k2', 'k4']);
      expect((await repo.watchChannels(pid, const FavoriteChannels()).first).map((c) => c.itemKey),
          ['k0', 'k2', 'k4']);
      expect(await repo.toggleFavorite(pid, ContentKind.live, 'k2'), isFalse);
      expect(await repo.watchFavoriteKeys(pid, ContentKind.live).first, {'k0', 'k4'});
    });

    test('Favoriten überleben ein erneutes Laden der Quelle', () async {
      await repo.toggleFavorite(pid, ContentKind.live, 'k3');
      await (db.delete(db.channels)).go();
      await db.into(db.channels).insert(
          ChannelsCompanion.insert(profileId: pid, itemKey: 'k3', name: 'Kanal 3 neu', sortIndex: 0));
      expect((await repo.watchChannels(pid, const FavoriteChannels()).first).single.name, 'Kanal 3 neu');
    });

    test('Zuletzt gesehen: neueste zuerst, ohne Doppelte', () async {
      var clock = DateTime(2026, 1, 1, 10);
      final r = LiveRepository(db, now: () => clock);
      await r.recordWatched(pid, ContentKind.live, 'k1');
      clock = clock.add(const Duration(minutes: 1));
      await r.recordWatched(pid, ContentKind.live, 'k5');
      clock = clock.add(const Duration(minutes: 1));
      await r.recordWatched(pid, ContentKind.live, 'k1');
      expect((await r.watchChannels(pid, const RecentChannels()).first).map((c) => c.itemKey), ['k1', 'k5']);
    });
  });

  group('LivePlayerController', () {
    final channels = [channel(1, num: 1), channel(2, num: 2), channel(3, num: 3)];
    PlayableStream resolve(ChannelRow c) => PlayableStream(Uri.parse('http://x/${c.itemKey}.ts'));

    test('startet, merkt sich gesehene Sender, schaltet verzögert um', () {
      fakeAsync((async) {
        final engine = FakeEngine();
        final watched = <String>[];
        final c = LivePlayerController(
          engine: engine,
          channels: channels,
          startIndex: 0,
          resolve: resolve,
          onWatched: (ch) => watched.add(ch.itemKey),
        );
        c.start();
        async.flushMicrotasks();
        expect(engine.opened.single.uri.path, '/1001.ts');
        expect(c.phase, PlaybackPhase.playing);

        // Schnell zweimal weiter: nur der letzte Sender wird geöffnet.
        c.next();
        c.next();
        expect(c.current.itemKey, '1003');
        async.elapse(const Duration(milliseconds: 300));
        expect(engine.opened.map((s) => s.uri.path), ['/1001.ts', '/1003.ts']);
        expect(watched, ['1001', '1003']);
        c.dispose();
      });
    });

    test('Ziffern: nach kurzer Pause zum Sender springen', () {
      fakeAsync((async) {
        final engine = FakeEngine();
        final c = LivePlayerController(engine: engine, channels: channels, startIndex: 0, resolve: resolve);
        c.start();
        async.flushMicrotasks();
        c.digit(3);
        expect(c.pendingDigits, '3');
        async.elapse(const Duration(seconds: 2));
        expect(c.pendingDigits, '');
        expect(c.current.num, 3);
        expect(engine.opened.last.uri.path, '/1003.ts');
        c.dispose();
      });
    });

    test('verbindet bei Abbruch automatisch neu und gibt dann auf', () {
      fakeAsync((async) {
        final engine = FakeEngine();
        final c = LivePlayerController(
          engine: engine,
          channels: channels,
          startIndex: 0,
          resolve: resolve,
          retryDelays: const [Duration(seconds: 1), Duration(seconds: 2)],
        );
        c.start();
        async.flushMicrotasks();
        engine.afterOpen = PlaybackPhase.error;

        engine.emit(PlaybackPhase.error); // Stream bricht ab
        expect(c.reconnectAttempt, 1);
        async.elapse(const Duration(seconds: 1)); // 1. Versuch → wieder Fehler
        expect(engine.opened, hasLength(2));
        expect(c.reconnectAttempt, 2);
        async.elapse(const Duration(seconds: 2)); // 2. Versuch → Fehler → aufgeben
        expect(engine.opened, hasLength(3));
        expect(c.failed, isTrue);
        async.elapse(const Duration(seconds: 30));
        expect(engine.opened, hasLength(3)); // keine weiteren Versuche

        engine.afterOpen = PlaybackPhase.playing;
        c.retry();
        async.flushMicrotasks();
        expect(c.failed, isFalse);
        expect(c.phase, PlaybackPhase.playing);
        expect(c.reconnectAttempt, 0);
        c.dispose();
      });
    });

    test('nicht abspielbarer Sender → sofort Fehlerzustand', () {
      fakeAsync((async) {
        final c = LivePlayerController(
          engine: FakeEngine(),
          channels: channels,
          startIndex: 0,
          resolve: (_) => null,
        );
        c.start();
        async.flushMicrotasks();
        expect(c.failed, isTrue);
        c.dispose();
      });
    });
  });
}
