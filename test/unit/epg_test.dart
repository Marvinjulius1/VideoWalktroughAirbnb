import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/core/db/database.dart';
import 'package:lumen/core/network/http.dart';
import 'package:lumen/core/network/source_error.dart';
import 'package:lumen/core/security/secret_store.dart';
import 'package:lumen/features/epg/data/epg_store.dart';
import 'package:lumen/features/epg/data/epg_sync.dart';
import 'package:lumen/features/epg/data/reminders.dart';
import 'package:lumen/features/epg/data/xmltv_parser.dart';
import 'package:lumen/features/sources/data/sources_repository.dart';
import 'package:lumen/features/sources/domain/source_profile.dart';
import 'package:lumen/features/sync/content_store.dart';
import 'package:lumen/features/sync/source_sync.dart';

import '../helpers/test_app.dart';
import '../mock_server/mock_server.dart';

void main() {
  group('XMLTV-Zeiten', () {
    test('mit Zeitzone', () {
      expect(parseXmltvTime('20260101203000 +0100'), DateTime.utc(2026, 1, 1, 19, 30));
      expect(parseXmltvTime('20260101203000 -0500'), DateTime.utc(2026, 1, 2, 1, 30));
      expect(parseXmltvTime('20260101203000+01:00'), DateTime.utc(2026, 1, 1, 19, 30));
    });
    test('ohne Zeitzone = UTC, ohne Sekunden', () {
      expect(parseXmltvTime('202601012030'), DateTime.utc(2026, 1, 1, 20, 30));
    });
    test('Unsinn', () {
      expect(parseXmltvTime('gestern'), isNull);
      expect(parseXmltvTime(null), isNull);
    });
  });

  group('XmltvParser', () {
    final now = DateTime.utc(2026, 5, 1, 12);
    final from = now.subtract(const Duration(days: 1));
    final to = now.add(const Duration(days: 7));

    test('Sendungen, Namen, Entities', () {
      final r = XmltvParser.parseString(sampleXmltv(now, 2), from: from, to: to);
      expect(r.programmes, hasLength(16));
      expect(r.channelNames['test1.de'], 'Testkanal 1');
      final p = r.programmes.first;
      expect(p.title, 'Sendung 0 auf Kanal 1');
      expect(p.description, 'Erfundene Beschreibung & mehr.');
      expect(p.category, 'Test');
      expect(p.end.difference(p.start), const Duration(hours: 1));
    });

    test('mehrsprachig: erster Titel gewinnt; CDATA; kaputte Einträge', () {
      const xml = '''<tv>
<programme start="20260501120000 +0000" stop="20260501130000 +0000" channel="a">
  <title lang="de">Deutsch</title><title lang="en">English</title>
  <desc><![CDATA[Mit <b>CDATA</b>]]></desc>
</programme>
<programme start="kaputt" stop="20260501130000 +0000" channel="a"><title>X</title></programme>
<programme start="20260501130000 +0000" stop="20260501120000 +0000" channel="a"><title>Rückwärts</title></programme>
</tv>''';
      final r = XmltvParser.parseString(xml, from: from, to: to);
      expect(r.programmes.single.title, 'Deutsch');
      expect(r.programmes.single.description, 'Mit <b>CDATA</b>');
    });

    test('Zeitfenster filtert alte und ferne Sendungen', () {
      const xml = '''<tv>
<programme start="20200101120000" stop="20200101130000" channel="a"><title>Alt</title></programme>
<programme start="20260501120000" stop="20260501130000" channel="a"><title>Jetzt</title></programme>
<programme start="20300101120000" stop="20300101130000" channel="a"><title>Fern</title></programme>
</tv>''';
      expect(XmltvParser.parseString(xml, from: from, to: to).programmes.map((p) => p.title), ['Jetzt']);
    });

    test('gzip-Datei und Kanalfilter', () async {
      final dir = await Directory.systemTemp.createTemp('lumen');
      addTearDown(() => dir.delete(recursive: true));
      final f = File('${dir.path}/epg.xml.gz')..writeAsBytesSync(gzip.encode(utf8.encode(sampleXmltv(now, 5))));
      final r = await XmltvParser.parseFile(f.path, from: from, to: to, channels: {'test2.de'});
      expect(r.programmes, hasLength(8));
      expect(r.programmes.every((p) => p.channelId == 'test2.de'), isTrue);
    });

    test('große Datei (1.000 Kanäle × 8 Sendungen)', () async {
      final sw = Stopwatch()..start();
      final r = await XmltvParser.parseStream(Stream.value(utf8.encode(sampleXmltv(now, 1000))),
          from: from, to: to);
      sw.stop();
      expect(r.programmes, hasLength(8000));
      // ignore: avoid_print
      print('XMLTV 8.000 Sendungen: ${sw.elapsedMilliseconds} ms');
    });
  });

  group('EpgStore / EpgSync / Erinnerungen', () {
    late MockServer server;
    late LumenDatabase db;
    late SourcesRepository repo;
    late EpgStore epg;
    final now = DateTime.now().toUtc();

    setUp(() async {
      server = await MockServer.start()
        ..epgNow = now;
      db = memoryDb();
      repo = SourcesRepository(db, InMemorySecretStore());
      epg = EpgStore(db);
    });
    tearDown(() async {
      await server.close();
      await db.close();
    });

    SourceSync syncer() => SourceSync(
          dio: createSourceDio(retryBaseDelay: const Duration(milliseconds: 5)),
          store: ContentStore(db),
          epg: EpgSync(dio: createSourceDio(retries: 0), store: epg, now: () => now),
        );

    test('Xtream: Inhalte + xmltv.php, Jetzt/Danach stimmt', () async {
      const c = SourceCredentials(username: 'demo', password: 'geheim');
      final p = await repo.add(name: 'X', type: SourceType.xtream, serverUrl: server.base, credentials: c);
      final last = await syncer().run(p, c).last;
      expect(last.stage, SyncStage.done);
      expect(last.epgCount, 25 * 8);
      expect(last.epgError, isNull);

      final nn = await epg.nowNext(p.id, ['test1.de', 'test2.de'], now);
      expect(nn['test1.de']!.now!.title, 'Sendung 3 auf Kanal 1');
      expect(nn['test1.de']!.next!.title, 'Sendung 4 auf Kanal 1');
      final progress = nn['test1.de']!.progressAt(now);
      expect(progress, inInclusiveRange(0, 1));
    });

    test('M3U: EPG-Adresse aus url-tvg der Playlist, gzip', () async {
      server.m3u = sampleM3u(10, host: server.base).replaceFirst('/epg.xml', '/epg.xml.gz');
      final c = SourceCredentials(playlistUrl: '${server.base}/playlist.m3u');
      final p = await repo.add(name: 'M', type: SourceType.m3uUrl, credentials: c);
      final last = await syncer().run(p, c).last;
      expect(last.epgCount, 80);
    });

    test('M3U ohne tvg-id: Zuordnung über den Namen', () async {
      server.m3u = '#EXTM3U\n#EXTINF:-1,Testkanal 3\nhttp://x/3.ts\n#EXTINF:-1,Unbekannt\nhttp://x/9.ts\n';
      final c = SourceCredentials(playlistUrl: '${server.base}/playlist.m3u', epgUrl: '${server.base}/epg.xml');
      final p = await repo.add(name: 'M', type: SourceType.m3uUrl, credentials: c);
      await syncer().run(p, c).drain<void>();
      final ch = await db.select(db.channels).get();
      expect(ch.firstWhere((x) => x.name == 'Testkanal 3').epgChannelId, 'test3.de');
      expect(ch.firstWhere((x) => x.name == 'Unbekannt').epgChannelId, isNull);
    });

    test('EPG-Fehler ist nicht fatal: Inhalte bleiben, Fehler wird gemeldet', () async {
      final c = SourceCredentials(playlistUrl: '${server.base}/playlist.m3u', epgUrl: '${server.base}/fehlt.xml');
      final p = await repo.add(name: 'M', type: SourceType.m3uUrl, credentials: c);
      final last = await syncer().run(p, c).last;
      expect(last.stage, SyncStage.done);
      expect(last.epgError, SourceErrorKind.notFound);
      expect((await ContentStore(db).watchCounts(p.id).first).live, 10);
    });

    test('Fenster-Abfrage fürs Raster', () async {
      const c = SourceCredentials(username: 'demo', password: 'geheim');
      final p = await repo.add(name: 'X', type: SourceType.xtream, serverUrl: server.base, credentials: c);
      await syncer().run(p, c).drain<void>();
      final w = await epg.window(p.id, ['test1.de'], now, now.add(const Duration(hours: 2)));
      expect(w['test1.de']!.length, inInclusiveRange(2, 3));
    });

    test('Erinnerungen: setzen, entfernen, abgelehnt, zu spät', () async {
      final p = await repo.add(name: 'X', type: SourceType.m3uUrl, credentials: const SourceCredentials());
      await db.into(db.channels).insert(ChannelsCompanion.insert(
          profileId: p.id, itemKey: 'k1', name: 'Testkanal 1', epgChannelId: const Value('test1.de'), sortIndex: 0));
      final channel = (await db.select(db.channels).get()).single;
      final future = EpgRow(
          id: 1, profileId: p.id, channelId: 'test1.de', title: 'Später',
          startUtc: now.add(const Duration(hours: 2)), endUtc: now.add(const Duration(hours: 3)));
      final past = EpgRow(
          id: 2, profileId: p.id, channelId: 'test1.de', title: 'Vorbei',
          startUtc: now.subtract(const Duration(hours: 2)), endUtc: now.subtract(const Duration(hours: 1)));
      final sched = FakeScheduler();
      final r = ReminderRepository(db, sched, now: () => now);

      Future<ReminderResult> toggle(EpgRow pr) => r.toggle(
          profileId: p.id, channel: channel, programme: pr, displayStartUtc: pr.startUtc, body: 'Beginnt jetzt');

      expect(await toggle(future), ReminderResult.added);
      expect(sched.scheduled.values.single, future.startUtc);
      expect(await r.watchKeys(p.id).first, {ReminderRepository.keyOf('test1.de', future.startUtc)});
      expect(await toggle(future), ReminderResult.removed);
      expect(sched.scheduled, isEmpty);
      expect(await toggle(past), ReminderResult.tooLate);
      sched.allow = false;
      expect(await toggle(future), ReminderResult.denied);
      expect(await db.select(db.reminders).get(), isEmpty);
    });
  });
}
