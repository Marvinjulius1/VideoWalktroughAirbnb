import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/network/source_error.dart';
import 'xtream_models.dart';

/// Welche Endung Live-Streams bekommen.
enum StreamFormat { ts, m3u8 }

/// Baut Stream-URLs nach dem Xtream-Schema.
///
/// Benutzername und Passwort stehen im Pfad. Sie werden kodiert, damit
/// Sonderzeichen (z. B. `/`, `#`, `?`) die Adresse nicht zerstören.
class XtreamUrls {
  const XtreamUrls(this.server, this.username, this.password);

  /// Normalisierte Basis-Adresse ohne Schrägstrich am Ende.
  final String server;
  final String username;
  final String password;

  String get _u => Uri.encodeComponent(username);
  String get _p => Uri.encodeComponent(password);

  Uri api([Map<String, String> extra = const {}]) =>
      Uri.parse('$server/player_api.php').replace(queryParameters: {
        'username': username,
        'password': password,
        ...extra,
      });

  Uri xmltv() => Uri.parse('$server/xmltv.php')
      .replace(queryParameters: {'username': username, 'password': password});

  Uri live(String streamId, StreamFormat f) =>
      Uri.parse('$server/live/$_u/$_p/$streamId.${f.name}');

  Uri movie(String streamId, String? ext) =>
      Uri.parse('$server/movie/$_u/$_p/$streamId.${ext ?? 'mp4'}');

  Uri episode(String episodeId, String? ext) =>
      Uri.parse('$server/series/$_u/$_p/$episodeId.${ext ?? 'mp4'}');

  /// Catch-up/Timeshift. Format der Startzeit: `YYYY-MM-DD:HH-MM` in der
  /// Zeitzone des Servers; Dauer in Minuten.
  Uri timeshift(String streamId, DateTime startServerTime, Duration duration) {
    String two(int v) => v.toString().padLeft(2, '0');
    final t = startServerTime;
    final start = '${t.year}-${two(t.month)}-${two(t.day)}:${two(t.hour)}-${two(t.minute)}';
    return Uri.parse(
        '$server/timeshift/$_u/$_p/${duration.inMinutes}/$start/$streamId.ts');
  }
}

/// Client für die Xtream-Codes-API (`player_api.php`).
///
/// Große Listen (zehntausende Einträge) werden als Bytes geladen und in einem
/// eigenen Isolate dekodiert, damit die Oberfläche flüssig bleibt.
class XtreamClient {
  XtreamClient(this._dio, this.urls, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final Dio _dio;
  final XtreamUrls urls;
  final DateTime Function() _now;

  /// Verbindungstest + Kontoinfo. Wirft [SourceException] mit passender Art.
  Future<XtreamAccount> account() async {
    final json = await _getJson(urls.api(), small: true);
    if (json is! Map) {
      throw const SourceException(SourceErrorKind.invalidResponse, 'account not an object');
    }
    final account = XtreamAccount.fromJson(json.cast<String, dynamic>());
    if (!account.authenticated) {
      throw const SourceException(SourceErrorKind.invalidCredentials);
    }
    if (account.isDisabled) throw const SourceException(SourceErrorKind.accountDisabled);
    if (account.isExpiredAt(_now())) throw const SourceException(SourceErrorKind.accountExpired);
    return account;
  }

  Future<List<XtreamCategory>> liveCategories() =>
      _list('get_live_categories', XtreamCategory.fromJson);
  Future<List<XtreamCategory>> vodCategories() =>
      _list('get_vod_categories', XtreamCategory.fromJson);
  Future<List<XtreamCategory>> seriesCategories() =>
      _list('get_series_categories', XtreamCategory.fromJson);

  Future<List<XtreamLiveStream>> liveStreams() =>
      _list('get_live_streams', XtreamLiveStream.fromJson);
  Future<List<XtreamVodStream>> vodStreams() =>
      _list('get_vod_streams', XtreamVodStream.fromJson);
  Future<List<XtreamSeries>> series() => _list('get_series', XtreamSeries.fromJson);

  Future<XtreamVodInfo> vodInfo(String vodId) async {
    final json = await _getJson(urls.api({'action': 'get_vod_info', 'vod_id': vodId}), small: true);
    return XtreamVodInfo.fromJson(_asMap(json), vodId);
  }

  Future<XtreamSeriesInfo> seriesInfo(String seriesId) async {
    final json = await _getJson(
        urls.api({'action': 'get_series_info', 'series_id': seriesId}));
    return XtreamSeriesInfo.fromJson(_asMap(json));
  }

  Future<List<XtreamEpgEntry>> shortEpg(String streamId, {int limit = 4}) async {
    final json = await _getJson(
      urls.api({'action': 'get_short_epg', 'stream_id': streamId, 'limit': '$limit'}),
      small: true,
    );
    return [
      for (final e in (_asMap(json)['epg_listings'] as List? ?? const []))
        if (XtreamEpgEntry.fromJson(e) case final XtreamEpgEntry x) x,
    ];
  }

  // ---------------------------------------------------------------------

  Future<List<T>> _list<T>(String action, T? Function(Object?) parse) =>
      fetchMapped<T, T>(action, parse, _identity);

  static T _identity<T>(T v, int _) => v;

  /// Lädt eine Liste und wandelt jeden Eintrag direkt im Isolate in das
  /// Zielformat um (z. B. Datenbankzeilen). Das Ergebnis wird ohne Kopie
  /// zurückgegeben – so bleibt der Hauptthread frei.
  ///
  /// [parse] und [map] müssen statische/Top-Level-Funktionen sein oder nur
  /// einfache Werte einfangen, weil sie an ein anderes Isolate gehen.
  Future<List<R>> fetchMapped<D, R>(
    String action,
    D? Function(Object?) parse,
    R Function(D item, int index) map,
  ) async {
    final bytes = await _getBytes(urls.api({'action': action}));
    try {
      return await _decodeInIsolate(bytes, parse, map);
    } on FormatException {
      throw const SourceException(SourceErrorKind.invalidResponse, 'list not json');
    }
  }

  // Bewusst statisch und nicht `async`: Die Closure für Isolate.run darf
  // nur die Parameter einfangen – nicht `this` (Dio ist nicht übertragbar).
  static Future<List<R>> _decodeInIsolate<D, R>(
    Uint8List bytes,
    D? Function(Object?) parse,
    R Function(D, int) map,
  ) =>
      Isolate.run(() {
        final items = decodeList(bytes, parse);
        return [for (var i = 0; i < items.length; i++) map(items[i], i)];
      });

  static Future<Object?> _jsonInIsolate(String text) => Isolate.run(() => jsonDecode(text));

  /// Dekodiert eine JSON-Liste und überspringt unbrauchbare Einträge.
  /// Öffentlich, damit Tests und Benchmarks sie direkt aufrufen können.
  static List<T> decodeList<T>(Uint8List bytes, T? Function(Object?) parse) {
    if (bytes.isEmpty) return const [];
    final raw = jsonDecode(utf8.decode(bytes, allowMalformed: true));
    // Leere Antworten kommen je nach Server als [], {} oder null.
    final items = raw is List ? raw : (raw is Map ? raw.values.toList() : const []);
    final out = <T>[];
    for (final item in items) {
      final v = parse(item);
      if (v != null) out.add(v);
    }
    return out;
  }

  Future<Object?> _getJson(Uri uri, {bool small = false}) async {
    final bytes = await _getBytes(uri);
    try {
      final text = utf8.decode(bytes, allowMalformed: true).trim();
      if (text.isEmpty) return null;
      return small ? jsonDecode(text) : await _jsonInIsolate(text);
    } on FormatException {
      // Häufig: HTML-Fehlerseite statt JSON (falsche Adresse oder Proxy).
      throw const SourceException(SourceErrorKind.invalidResponse, 'not json');
    }
  }

  Future<Uint8List> _getBytes(Uri uri) async {
    try {
      final r = await _dio.getUri<List<int>>(
        uri,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = r.data;
      return data is Uint8List ? data : Uint8List.fromList(data ?? const []);
    } on DioException catch (e) {
      throw SourceException.fromDio(e);
    }
  }

  static Map<String, dynamic> _asMap(Object? v) =>
      v is Map ? v.cast<String, dynamic>() : const {};
}
