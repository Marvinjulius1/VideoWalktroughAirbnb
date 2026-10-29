import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/core/network/http.dart';
import 'package:lumen/core/network/source_error.dart';
import 'package:lumen/features/sources/data/xtream/json_tolerant.dart';
import 'package:lumen/features/sources/data/xtream/xtream_client.dart';
import 'package:lumen/features/sources/data/xtream/xtream_models.dart';

import '../mock_server/mock_server.dart';

void main() {
  group('tolerantes JSON', () {
    test('Zahlen als Text, leere Werte, Unsinn', () {
      expect(jInt('42'), 42);
      expect(jInt(' 7.6 '), 8);
      expect(jInt(''), isNull);
      expect(jInt([1]), isNull);
      expect(jStr(5), '5');
      expect(jStr('  '), isNull);
      expect(jDouble('7,5'), 7.5);
      expect(jBool('1'), isTrue);
      expect(jBool(0), isFalse);
      expect(jUnix('0'), isNull);
      expect(jUnix('1700000000')!.year, 2023);
      expect(jYear('Film (2019)'), 2019);
      expect(jList({'0': 'a', '1': 'b'}), ['a', 'b']);
    });

    test('Base64 nur dekodieren, wenn es wirklich Base64 ist', () {
      expect(decodeMaybeBase64(base64.encode(utf8.encode('Hallo Welt'))), 'Hallo Welt');
      expect(decodeMaybeBase64('Klartext mit Leerzeichen'), 'Klartext mit Leerzeichen');
      expect(decodeMaybeBase64('News'), 'News');
    });

    test('Kontoinfo: Ablauf und Status', () {
      final a = XtreamAccount.fromJson({
        'user_info': {'auth': 1, 'status': 'Active', 'exp_date': '1000', 'max_connections': '3'},
      });
      expect(a.authenticated, isTrue);
      expect(a.maxConnections, 3);
      expect(a.isExpiredAt(DateTime.utc(2026)), isTrue);

      final unlimited = XtreamAccount.fromJson({
        'user_info': {'auth': '1', 'status': 'Active', 'exp_date': null},
      });
      expect(unlimited.expiresAt, isNull);
      expect(unlimited.isExpiredAt(DateTime.utc(2026)), isFalse);
    });

    test('Liste dekodieren: kaputte Einträge überspringen, {} = leer', () {
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode([
        {'stream_id': '1', 'name': 'A'},
        {'name': 'ohne id'},
        'quatsch',
      ])));
      expect(XtreamClient.decodeList(bytes, XtreamLiveStream.fromJson).map((s) => s.name), ['A']);
      expect(XtreamClient.decodeList(Uint8List.fromList(utf8.encode('{}')), XtreamLiveStream.fromJson),
          isEmpty);
    });
  });

  group('XtreamUrls', () {
    const urls = XtreamUrls('http://srv.example:8080', 'nutzer', 'pa/ss#1');

    test('API-Adresse mit kodierten Parametern', () {
      final u = urls.api({'action': 'get_live_streams'});
      expect(u.path, '/player_api.php');
      expect(u.queryParameters['password'], 'pa/ss#1');
      expect(u.queryParameters['action'], 'get_live_streams');
    });

    test('Stream-Adressen kodieren Sonderzeichen im Pfad', () {
      expect(urls.live('12', StreamFormat.ts).toString(),
          'http://srv.example:8080/live/nutzer/pa%2Fss%231/12.ts');
      expect(urls.live('12', StreamFormat.m3u8).path.endsWith('/12.m3u8'), isTrue);
      expect(urls.movie('5', 'mkv').path.endsWith('/movie/nutzer/pa%2Fss%231/5.mkv'), isTrue);
      expect(urls.episode('9', null).path.endsWith('/9.mp4'), isTrue);
    });

    test('Timeshift-Format', () {
      final u = urls.timeshift('12', DateTime(2026, 3, 4, 5, 6), const Duration(minutes: 90));
      expect(u.path, '/timeshift/nutzer/pa%2Fss%231/90/2026-03-04:05-06/12.ts');
    });
  });

  group('XtreamClient gegen Mock-Server', () {
    late MockServer server;
    setUp(() async => server = await MockServer.start());
    tearDown(() => server.close());

    XtreamClient client({String? user, String? pass}) => XtreamClient(
          createSourceDio(retryBaseDelay: const Duration(milliseconds: 5)),
          XtreamUrls(server.base, user ?? server.username, pass ?? server.password),
        );

    test('Kontoinfo', () async {
      final a = await client().account();
      expect(a.status, 'Active');
      expect(a.maxConnections, 2);
      expect(a.activeConnections, 1);
      expect(a.allowedFormats, ['m3u8', 'ts']);
      expect(a.serverTimezone, 'Europe/Berlin');
      expect(a.createdAt!.year, 2023);
    });

    Future<SourceErrorKind> kindOf(Future<Object?> f) async {
      try {
        await f;
      } on SourceException catch (e) {
        return e.kind;
      }
      fail('kein Fehler');
    }

    test('falsches Passwort (auth=0 und HTTP 401)', () async {
      expect(await kindOf(client(pass: 'falsch').account()), SourceErrorKind.invalidCredentials);
      server.unauthorizedAs401 = true;
      expect(await kindOf(client(pass: 'falsch').account()), SourceErrorKind.invalidCredentials);
    });

    test('abgelaufen und gesperrt', () async {
      server.expUnix = 1000;
      expect(await kindOf(client().account()), SourceErrorKind.accountExpired);
      server
        ..expUnix = null
        ..status = 'Banned';
      expect(await kindOf(client().account()), SourceErrorKind.accountDisabled);
    });

    test('HTML statt JSON → ungültige Antwort', () async {
      server.htmlInsteadOfJson = true;
      expect(await kindOf(client().account()), SourceErrorKind.invalidResponse);
    });

    test('Server nicht erreichbar', () async {
      final c = XtreamClient(
        createSourceDio(retries: 0, connectTimeout: const Duration(seconds: 2)),
        const XtreamUrls('http://127.0.0.1:1', 'a', 'b'),
      );
      expect(await kindOf(c.account()), SourceErrorKind.serverUnreachable);
    });

    test('wiederholt bei 503 automatisch', () async {
      server.failFirst = 2;
      final a = await client().account();
      expect(a.authenticated, isTrue);
      expect(server.requests, hasLength(3));
    });

    test('gibt nach zu vielen Fehlern auf', () async {
      server.failFirst = 10;
      expect(await kindOf(client().account()), SourceErrorKind.serverUnreachable);
    });

    test('Listen mit gemischten Typen', () async {
      final c = client();
      final cats = await c.liveCategories();
      expect(cats.map((c) => c.name), ['Nachrichten', 'Sport', 'Doppelt']);
      final live = await c.liveStreams();
      expect(live, hasLength(25)); // Eintrag ohne ID wird übersprungen
      expect(live.first.streamId, '1001');
      expect(live.first.tvArchive, isTrue);
      expect(live.first.archiveDays, 7);
      expect(live[1].categoryId, '2');
      expect(live[2].icon, isNull);
      final vod = await c.vodStreams();
      expect(vod.first.year, 2011);
      expect(vod[1].rating, 8.2); // aus rating_5based
      final series = await c.series();
      expect(series.first.categoryId, '20');
      expect(series.first.year, 2019);
      server.seriesCount = 0;
      expect(await c.seriesCategories(), isEmpty);
    });

    test('Film- und Seriendetails', () async {
      final c = client();
      final vod = await c.vodInfo('2001');
      expect(vod.duration, const Duration(minutes: 90));
      expect(vod.year, 2021);
      expect(vod.backdrop, 'http://127.0.0.1/bd/1.jpg');
      expect(vod.containerExt, 'mkv');

      final s = await c.seriesInfo('3001');
      expect(s.seasons, [1, 2]);
      expect(s.episodes.map((e) => e.id), ['401', '402', '502']);
      expect(s.episodes[1].duration, const Duration(minutes: 45));
      expect(s.episodes[2].duration, const Duration(minutes: 45));
    });

    test('Kurz-EPG mit Base64 und Klartext', () async {
      final epg = await client().shortEpg('1001');
      expect(epg.map((e) => e.title), ['Testsendung', 'Klartext']);
      expect(epg.first.description, 'Beschreibung mit Ümlaut');
      expect(epg.first.end.difference(epg.first.start), const Duration(hours: 1));
    });

    test('Passwort taucht in Fehlermeldungen nicht auf', () async {
      server.failFirst = 10;
      try {
        await client().account();
      } on SourceException catch (e) {
        expect(e.toString(), isNot(contains(server.password)));
      }
    });
  });
}
