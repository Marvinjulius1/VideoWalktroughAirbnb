import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../../../core/network/source_error.dart';
import '../playlist_file_store.dart';
import 'm3u_parser.dart';

/// Lädt und parst M3U-Playlists (Link oder lokale Datei).
class M3uSource {
  M3uSource(this._dio, {Future<Directory> Function()? tempDir})
      : _tempDir = tempDir ?? (() async => Directory.systemTemp);

  final Dio _dio;
  final Future<Directory> Function() _tempDir;

  /// Verbindungstest: lädt nur den Anfang und prüft, ob es eine M3U ist.
  Future<void> test(String url) async {
    final cancel = CancelToken();
    try {
      final r = await _dio.get<ResponseBody>(
        url,
        cancelToken: cancel,
        options: Options(responseType: ResponseType.stream),
      );
      final bytes = <int>[];
      await for (final chunk in r.data!.stream) {
        bytes.addAll(chunk);
        if (bytes.length >= 16 * 1024) break;
      }
      cancel.cancel();
      final head = utf8.decode(bytes, allowMalformed: true);
      if (!PlaylistFileStore.looksLikeM3u(head)) {
        throw const SourceException(SourceErrorKind.invalidPlaylist);
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return;
      throw SourceException.fromDio(e);
    }
  }

  /// Lädt die Playlist in eine temporäre Datei (kein riesiger String im
  /// Speicher) und parst sie in einem eigenen Isolate.
  Future<M3uPlaylist> loadUrl(String url) => loadUrlMapped(url, _identity);

  Future<M3uPlaylist> loadFile(String path) => loadFileMapped(path, _identity);

  static M3uPlaylist _identity(M3uPlaylist p) => p;

  /// Wie [loadUrl], aber [map] läuft noch im Parser-Isolate (z. B. Umwandeln
  /// in Datenbankzeilen). [map] darf nur einfache Werte einfangen.
  Future<R> loadUrlMapped<R>(String url, R Function(M3uPlaylist) map) async {
    final dir = await _tempDir();
    final file = File(p.join(dir.path, 'lumen-${DateTime.now().microsecondsSinceEpoch}.m3u'));
    try {
      await _dio.download(url, file.path);
      return await loadFileMapped(file.path, map);
    } on DioException catch (e) {
      throw SourceException.fromDio(e);
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  Future<R> loadFileMapped<R>(String path, R Function(M3uPlaylist) map) async {
    try {
      return await _parseInIsolate(path, map);
    } on FileSystemException {
      throw const SourceException(SourceErrorKind.invalidPlaylist, 'unreadable');
    }
  }

  // Statisch, damit die Closure nicht `this` (mit Dio) einfängt.
  static Future<R> _parseInIsolate<R>(String path, R Function(M3uPlaylist) map) =>
      Isolate.run(() async {
        final playlist = await M3uParser.parseFile(path);
        if (playlist.entries.isEmpty) {
          throw const SourceException(SourceErrorKind.invalidPlaylist, 'empty');
        }
        return map(playlist);
      });
}
