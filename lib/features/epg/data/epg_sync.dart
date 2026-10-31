import 'dart:io';
import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;

import '../../../core/db/database.dart';
import '../../../core/network/source_error.dart';
import '../../sources/data/xtream/xtream_client.dart';
import '../../sources/domain/source_profile.dart';
import 'epg_store.dart';
import 'xmltv_parser.dart';

/// Lädt XMLTV-Programmdaten und speichert sie.
///
/// Quelle: bei Xtream `xmltv.php`, bei M3U die EPG-Adresse aus dem Formular
/// oder – falls leer – die Adresse aus der Kopfzeile der Playlist.
class EpgSync {
  EpgSync({required this.dio, required this.store, Future<Directory> Function()? tempDir, DateTime Function()? now})
      : _tempDir = tempDir ?? (() async => Directory.systemTemp),
        _now = now ?? DateTime.now;

  final Dio dio;
  final EpgStore store;
  final Future<Directory> Function() _tempDir;
  final DateTime Function() _now;

  static const keepPast = Duration(days: 1);
  static const keepFuture = Duration(days: 7);

  static Uri? sourceUrl(SourceProfile p, SourceCredentials c, {String? playlistHint}) {
    switch (p.type) {
      case SourceType.xtream:
        if (p.serverUrl == null) return null;
        return XtreamUrls(p.serverUrl!, c.username ?? '', c.password ?? '').xmltv();
      case SourceType.m3uUrl:
      case SourceType.m3uFile:
        final url = c.epgUrl ?? playlistHint;
        return url == null ? null : Uri.tryParse(url);
    }
  }

  /// Gibt die Anzahl gespeicherter Sendungen zurück, oder `null`, wenn es
  /// keine EPG-Quelle gibt. Wirft [SourceException].
  Future<int?> run(SourceProfile profile, SourceCredentials creds, {String? playlistHint}) async {
    final url = sourceUrl(profile, creds, playlistHint: playlistHint);
    if (url == null) return null;

    final dir = await _tempDir();
    final file = File(p.join(dir.path, 'lumen-epg-${DateTime.now().microsecondsSinceEpoch}.xml'));
    try {
      await dio.downloadUri(url, file.path);
      final now = _now().toUtc();
      final from = now.subtract(keepPast);
      final to = now.add(keepFuture);
      // Sind alle Sender schon über tvg-id zugeordnet, reichen deren
      // Programme – das spart bei großen XMLTV-Dateien viel Speicher.
      final needNames = await store.hasChannelsWithoutEpgId(profile.id);
      final ids = needNames ? null : await store.epgChannelIds(profile.id);
      final (rows, names) = await _parseInIsolate(file.path, profile.id, from, to, ids);
      if (needNames) await store.matchChannelsByName(profile.id, names);
      await store.replace(profile.id, rows);
      return rows.length;
    } on DioException catch (e) {
      throw SourceException.fromDio(e);
    } on FormatException {
      throw const SourceException(SourceErrorKind.invalidResponse, 'xmltv');
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  // Statisch, damit die Closure nur einfache Werte einfängt.
  static Future<(List<EpgProgramsCompanion>, Map<String, String>)> _parseInIsolate(
    String path,
    String profileId,
    DateTime from,
    DateTime to,
    Set<String>? ids,
  ) =>
      Isolate.run(() async {
        final r = await XmltvParser.parseFile(path, from: from, to: to, channels: ids);
        final rows = [
          for (final x in r.programmes)
            EpgProgramsCompanion.insert(
              profileId: profileId,
              channelId: x.channelId,
              startUtc: x.start,
              endUtc: x.end,
              title: x.title,
              description: Value(x.description),
              category: Value(x.category),
            ),
        ];
        return (rows, r.channelNames);
      });
}
