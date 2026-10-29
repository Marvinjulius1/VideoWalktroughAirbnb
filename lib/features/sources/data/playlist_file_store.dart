import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Fehler beim Import einer Playlist-Datei.
enum PlaylistImportError { unreadable, notM3u }

class PlaylistImportException implements Exception {
  const PlaylistImportException(this.error);
  final PlaylistImportError error;
}

/// Kopiert vom Nutzer gewählte M3U-Dateien in den privaten App-Ordner.
///
/// Warum kopieren? Auf iOS und Android ist der Pfad aus der Dateiauswahl nur
/// vorübergehend gültig (Cache). Eine eigene Kopie bleibt erhalten.
class PlaylistFileStore {
  PlaylistFileStore({Future<Directory> Function()? baseDir})
      : _baseDir = baseDir ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _baseDir;

  /// Prüft kurz, ob es eine M3U-Datei ist (Kopfzeile `#EXTM3U` oder
  /// mindestens ein `#EXTINF`), und kopiert sie dann.
  Future<String> import(String sourcePath) async {
    final src = File(sourcePath);
    final String head;
    try {
      head = await _readHead(src);
    } on FileSystemException {
      throw const PlaylistImportException(PlaylistImportError.unreadable);
    }
    if (!looksLikeM3u(head)) {
      throw const PlaylistImportException(PlaylistImportError.notM3u);
    }
    final dir = Directory(p.join((await _baseDir()).path, 'playlists'));
    await dir.create(recursive: true);
    final target = p.join(dir.path, '${const Uuid().v4()}.m3u');
    await src.copy(target);
    return target;
  }

  Future<void> remove(String? path) async {
    if (path == null) return;
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  static Future<String> _readHead(File f) async {
    final bytes = <int>[];
    await for (final chunk in f.openRead(0, 4096)) {
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  static bool looksLikeM3u(String head) {
    final s = head.replaceFirst('﻿', '').trimLeft();
    return s.startsWith('#EXTM3U') || s.contains('#EXTINF');
  }
}
