import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

/// Lokaler Test-Server, der sich wie ein Xtream-Server bzw. eine
/// M3U-Quelle verhält. **Alle Daten sind erfunden** (Fantasiesender wie
/// „Testkanal 1“), es gibt keinen Bezug zu echten Anbietern.
///
/// Absichtlich „unordentlich“: Zahlen kommen teils als Text, Felder fehlen
/// oder sind leer – so wie bei echten Servern.
class MockServer {
  MockServer._(this._server);

  final HttpServer _server;

  String username = 'demo';
  String password = 'geheim';
  String status = 'Active';

  /// Unix-Sekunden oder `null` (= unbegrenzt).
  int? expUnix = 4102444800; // 2100-01-01
  int liveCount = 25;
  int vodCount = 12;
  int seriesCount = 5;

  /// So viele Anfragen schlagen zuerst mit 503 fehl (Retry-Test).
  int failFirst = 0;

  /// Antwortet auf player_api.php mit HTML statt JSON.
  bool htmlInsteadOfJson = false;

  /// Bei falschem Login: true = HTTP 401, false = 200 mit auth=0
  /// (beides kommt in der Praxis vor).
  bool unauthorizedAs401 = false;

  String m3u = sampleM3u(10);

  final requests = <Uri>[];

  String get base => 'http://127.0.0.1:${_server.port}';

  static Future<MockServer> start() async {
    late MockServer mock;
    final server = await io.serve((Request r) => mock._handle(r), InternetAddress.loopbackIPv4, 0);
    mock = MockServer._(server);
    return mock;
  }

  Future<void> close() => _server.close(force: true);

  Future<Response> _handle(Request r) async {
    requests.add(r.requestedUri);
    if (failFirst > 0) {
      failFirst--;
      return Response(503, body: 'busy');
    }
    final path = r.url.path;
    if (path == 'player_api.php') return _api(r.url.queryParameters);
    if (path == 'playlist.m3u') {
      return Response.ok(m3u, headers: {'content-type': 'audio/x-mpegurl'});
    }
    if (path == 'not-a-playlist') return Response.ok('<html>Hallo</html>');
    if (path == 'missing.m3u') return Response.notFound('nope');
    return Response.notFound('');
  }

  Response _json(Object o) =>
      Response.ok(jsonEncode(o), headers: {'content-type': 'application/json'});

  Response _api(Map<String, String> q) {
    if (htmlInsteadOfJson) return Response.ok('<html><body>Login</body></html>');
    final ok = q['username'] == username && q['password'] == password;
    if (!ok) {
      if (unauthorizedAs401) return Response(401, body: '');
      return _json({
        'user_info': {'auth': 0},
      });
    }
    switch (q['action']) {
      case null:
        return _json({
          'user_info': {
            'username': username,
            'password': password,
            'auth': 1,
            'status': status,
            'exp_date': expUnix?.toString(),
            'is_trial': '0',
            'active_cons': '1',
            'created_at': '1700000000',
            'max_connections': '2',
            'allowed_output_formats': ['m3u8', 'ts'],
          },
          'server_info': {'timezone': 'Europe/Berlin', 'url': '127.0.0.1', 'port': '80'},
        });
      case 'get_live_categories':
        return _json([
          {'category_id': '1', 'category_name': 'Nachrichten', 'parent_id': 0},
          {'category_id': 2, 'category_name': 'Sport', 'parent_id': '0'},
          {'category_id': '1', 'category_name': 'Doppelt', 'parent_id': 0},
        ]);
      case 'get_vod_categories':
        return _json([
          {'category_id': '10', 'category_name': 'Dokumentationen'},
        ]);
      case 'get_series_categories':
        // Manche Server liefern bei „leer“ ein Objekt statt einer Liste.
        return _json(seriesCount == 0 ? {} : [
          {'category_id': '20', 'category_name': 'Krimi'},
        ]);
      case 'get_live_streams':
        return _json([
          for (var i = 1; i <= liveCount; i++)
            {
              'num': i.isEven ? i : '$i',
              'name': 'Testkanal $i',
              'stream_type': 'live',
              'stream_id': i.isEven ? 1000 + i : '${1000 + i}',
              'stream_icon': i == 3 ? '' : 'http://127.0.0.1/logo/$i.png',
              'epg_channel_id': 'test$i.de',
              'added': '1700000000',
              'category_id': i.isEven ? '2' : 1,
              'tv_archive': i == 1 ? 1 : 0,
              'tv_archive_duration': i == 1 ? '7' : 0,
            },
          {'name': 'Kaputt ohne ID'},
        ]);
      case 'get_vod_streams':
        return _json([
          for (var i = 1; i <= vodCount; i++)
            {
              'name': 'Testfilm $i (20${10 + i})',
              'stream_id': 2000 + i,
              'stream_icon': 'http://127.0.0.1/poster/$i.jpg',
              'rating': i == 2 ? '' : '7.${i % 10}',
              'rating_5based': 4.1,
              'added': '${1700000000 + i}',
              'category_id': '10',
              'container_ext': i.isOdd ? 'mkv' : 'mp4',
            },
        ]);
      case 'get_series':
        return _json([
          for (var i = 1; i <= seriesCount; i++)
            {
              'name': 'Testserie $i',
              'series_id': 3000 + i,
              'cover': 'http://127.0.0.1/cover/$i.jpg',
              'plot': 'Eine erfundene Serie.',
              'genre': 'Krimi',
              'releaseDate': '2019-03-0$i',
              'last_modified': '1700000000',
              'rating': '8',
              'category_ids': [20],
            },
        ]);
      case 'get_vod_info':
        return _json({
          'info': {
            'movie_image': 'http://127.0.0.1/poster/1.jpg',
            'plot': 'Ein erfundener Film über Testdaten.',
            'genre': 'Doku',
            'cast': 'Erika Muster, Max Muster',
            'director': 'Niemand',
            'releasedate': '2021-05-01',
            'duration_secs': 5400,
            'duration': '01:30:00',
            'rating': '7.4',
            'youtube_trailer': 'abc123',
            'backdrop_path': ['http://127.0.0.1/bd/1.jpg'],
          },
          'movie_data': {'stream_id': q['vod_id'], 'name': 'Testfilm 1', 'container_ext': 'mkv'},
        });
      case 'get_series_info':
        return _json({
          'info': {'name': 'Testserie 1', 'plot': 'Erfunden.', 'releaseDate': '2019'},
          'episodes': {
            '2': [
              {'id': '502', 'episode_num': '1', 'title': 'S2 E1', 'container_ext': 'mp4', 'season': 2,
                'info': {'duration': '00:45:00'}},
            ],
            '1': [
              {'id': '402', 'episode_num': 2, 'title': 'S1 E2', 'container_ext': 'mkv',
                'info': {'duration_secs': '2700', 'movie_image': 'http://127.0.0.1/ep/2.jpg'}},
              {'id': '401', 'episode_num': 1, 'title': 'S1 E1', 'container_ext': 'mkv', 'info': []},
            ],
          },
        });
      case 'get_short_epg':
        return _json({
          'epg_listings': [
            {
              'title': base64.encode(utf8.encode('Testsendung')),
              'description': base64.encode(utf8.encode('Beschreibung mit Ümlaut')),
              'start_timestamp': '1700000000',
              'stop_timestamp': '1700003600',
            },
            {'title': 'Klartext', 'start_timestamp': 1700003600, 'stop_timestamp': 1700007200},
          ],
        });
    }
    return _json([]);
  }
}

/// Erzeugt eine M3U mit [live] Sendern plus zwei Filmen und einer Serie.
String sampleM3u(int live, {String host = 'http://127.0.0.1'}) {
  final b = StringBuffer('#EXTM3U url-tvg="$host/epg.xml"\n');
  for (var i = 1; i <= live; i++) {
    final group = i.isEven ? 'Sport' : 'Nachrichten';
    b.writeln('#EXTINF:-1 tvg-id="test$i.de" tvg-name="Testkanal $i" '
        'tvg-logo="$host/logo/$i.png" group-title="$group" tvg-chno="$i",Testkanal $i');
    b.writeln('$host/live/$i.ts');
  }
  b.writeln('#EXTINF:-1 tvg-logo="$host/p/1.jpg" group-title="Filme",Testfilm A');
  b.writeln('$host/movie/u/p/1.mkv');
  b.writeln('#EXTINF:-1 group-title="Filme",Testfilm B');
  b.writeln('$host/videos/b.mp4');
  b.writeln('#EXTINF:-1 group-title="Serien",Testserie S01 E01');
  b.writeln('$host/series/u/p/9.mp4');
  return b.toString();
}
