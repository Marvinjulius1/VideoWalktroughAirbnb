import 'dart:convert';
import 'dart:io';

/// Art eines Playlist-Eintrags. M3U kennt das nicht direkt – wir erkennen
/// es an typischen Pfaden (`/movie/`, `/series/`) oder Dateiendungen.
enum M3uKind { live, movie, series }

/// Ein Eintrag aus einer M3U-Playlist.
class M3uEntry {
  const M3uEntry({
    required this.name,
    required this.url,
    required this.kind,
    this.tvgId,
    this.tvgName,
    this.logo,
    this.group,
    this.channelNumber,
    this.catchupDays,
    this.catchupMode,
    this.catchupSource,
    this.userAgent,
    this.referrer,
  });

  final String name;
  final String url;
  final M3uKind kind;
  final String? tvgId;
  final String? tvgName;
  final String? logo;
  final String? group;
  final int? channelNumber;
  final int? catchupDays;
  final String? catchupMode;
  final String? catchupSource;
  final String? userAgent;
  final String? referrer;

  /// Stabiler Schlüssel (überlebt Aktualisierungen), damit Favoriten und
  /// Verlauf erhalten bleiben, auch wenn sich die Reihenfolge ändert.
  String get key => '${tvgId ?? ''}|$name|$url';
}

/// Ergebnis: Einträge plus Infos aus der Kopfzeile.
class M3uPlaylist {
  const M3uPlaylist({required this.entries, this.epgUrl, this.skippedLines = 0});

  final List<M3uEntry> entries;

  /// `url-tvg` / `x-tvg-url` aus `#EXTM3U` – Vorschlag für die EPG-Adresse.
  final String? epgUrl;

  /// Zeilen, die nicht verstanden wurden (zur Diagnose).
  final int skippedLines;
}

/// Zeilenweiser M3U-Parser.
///
/// Verarbeitet die Datei als Strom von Zeilen, damit auch Playlists mit
/// 100.000+ Einträgen nicht komplett als ein riesiger String im Speicher
/// liegen müssen.
class M3uParser {
  final _entries = <M3uEntry>[];
  String? _epgUrl;
  int _skipped = 0;

  // Zustand des aktuellen Eintrags (zwischen #EXTINF und URL-Zeile).
  Map<String, String>? _attrs;
  String? _title;
  String? _extGroup;
  String? _userAgent;
  String? _referrer;
  bool _first = true;

  static final _attrRe = RegExp(r'''([A-Za-z0-9_\-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s,]+))''');

  void addLine(String raw) {
    var line = raw;
    if (_first) {
      line = line.replaceFirst('﻿', '');
      _first = false;
    }
    line = line.trim();
    if (line.isEmpty) return;

    if (line.startsWith('#')) {
      final upper = line.length >= 8 ? line.substring(0, 8).toUpperCase() : line.toUpperCase();
      if (upper.startsWith('#EXTM3U')) {
        final a = _parseAttrs(line.substring(7));
        _epgUrl ??= a['url-tvg'] ?? a['x-tvg-url'] ?? a['tvg-url'];
        // Manche Header enthalten mehrere, kommagetrennte EPG-Adressen.
        if (_epgUrl != null && _epgUrl!.contains(',')) _epgUrl = _epgUrl!.split(',').first.trim();
      } else if (upper.startsWith('#EXTINF')) {
        _startEntry(line);
      } else if (upper.startsWith('#EXTGRP')) {
        final i = line.indexOf(':');
        if (i >= 0) _extGroup = line.substring(i + 1).trim();
      } else if (upper.startsWith('#EXTVLC')) {
        final i = line.indexOf(':');
        final opt = i >= 0 ? line.substring(i + 1) : '';
        final eq = opt.indexOf('=');
        if (eq > 0) {
          final k = opt.substring(0, eq).trim().toLowerCase();
          final v = opt.substring(eq + 1).trim();
          if (k == 'http-user-agent') _userAgent = v;
          if (k == 'http-referrer' || k == 'http-referer') _referrer = v;
        }
      }
      // Andere Kommentare (#KODIPROP, #EXT-X-…) werden ignoriert.
      return;
    }

    _finishEntry(line);
  }

  void _startEntry(String line) {
    // Ein #EXTINF ohne URL davor wird verworfen.
    if (_attrs != null) _skipped++;
    final colon = line.indexOf(':');
    final body = colon >= 0 ? line.substring(colon + 1) : '';
    final comma = _titleComma(body);
    final head = comma >= 0 ? body.substring(0, comma) : body;
    _title = comma >= 0 ? body.substring(comma + 1).trim() : null;
    _attrs = _parseAttrs(head);
  }

  void _finishEntry(String url) {
    if (!_looksLikeUrl(url)) {
      _skipped++;
      _reset();
      return;
    }
    final a = _attrs ?? const <String, String>{};
    final name = _firstNonEmpty([_title, a['tvg-name'], _nameFromUrl(url)])!;
    _entries.add(M3uEntry(
      name: name,
      url: url,
      kind: classify(url, a['group-title'] ?? _extGroup),
      tvgId: _nonEmpty(a['tvg-id']),
      tvgName: _nonEmpty(a['tvg-name']),
      logo: _nonEmpty(a['tvg-logo']) ?? _nonEmpty(a['logo']),
      group: _nonEmpty(a['group-title']) ?? _nonEmpty(_extGroup),
      channelNumber: int.tryParse(a['tvg-chno'] ?? a['channel-number'] ?? ''),
      catchupDays: int.tryParse(a['catchup-days'] ?? a['timeshift'] ?? ''),
      catchupMode: _nonEmpty(a['catchup']),
      catchupSource: _nonEmpty(a['catchup-source']),
      userAgent: _userAgent ?? _nonEmpty(a['user-agent']),
      referrer: _referrer,
    ));
    _reset();
  }

  void _reset() {
    _attrs = null;
    _title = null;
    _extGroup = null;
    _userAgent = null;
    _referrer = null;
  }

  M3uPlaylist finish() {
    if (_attrs != null) _skipped++;
    return M3uPlaylist(entries: List.unmodifiable(_entries), epgUrl: _epgUrl, skippedLines: _skipped);
  }

  /// Komma, das den Titel abtrennt: das erste Komma außerhalb von
  /// Anführungszeichen (Attributwerte dürfen Kommas enthalten).
  static int _titleComma(String s) {
    String? quote;
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (quote != null) {
        if (c == quote) quote = null;
      } else if (c == '"' || c == "'") {
        quote = c;
      } else if (c == ',') {
        return i;
      }
    }
    return -1;
  }

  static Map<String, String> _parseAttrs(String s) {
    final out = <String, String>{};
    for (final m in _attrRe.allMatches(s)) {
      out[m.group(1)!.toLowerCase()] = (m.group(2) ?? m.group(3) ?? m.group(4) ?? '').trim();
    }
    return out;
  }

  static bool _looksLikeUrl(String s) =>
      RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*://').hasMatch(s) && !s.contains(' ');

  static String? _nonEmpty(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();

  static String? _firstNonEmpty(List<String?> xs) {
    for (final x in xs) {
      final v = _nonEmpty(x);
      if (v != null) return v;
    }
    return null;
  }

  static String _nameFromUrl(String url) {
    final path = Uri.tryParse(url)?.pathSegments.where((s) => s.isNotEmpty).lastOrNull;
    return (path == null || path.isEmpty) ? url : Uri.decodeComponent(path);
  }

  static const _vodExt = {'mp4', 'mkv', 'avi', 'mov', 'm4v', 'wmv', 'webm', 'mpg', 'mpeg'};

  /// Erkennt Filme und Serien an Xtream-typischen Pfaden oder Video-Endungen.
  /// Alles andere (`.ts`, `.m3u8`, ohne Endung) gilt als Live.
  static M3uKind classify(String url, String? group) {
    final lower = url.toLowerCase();
    if (lower.contains('/series/')) return M3uKind.series;
    if (lower.contains('/movie/') || lower.contains('/movies/')) return M3uKind.movie;
    final path = Uri.tryParse(lower)?.path ?? lower;
    final dot = path.lastIndexOf('.');
    if (dot > 0 && _vodExt.contains(path.substring(dot + 1))) return M3uKind.movie;
    return M3uKind.live;
  }

  // --- Bequeme Einstiegspunkte -------------------------------------------

  static M3uPlaylist parseString(String content) {
    final p = M3uParser();
    for (final line in const LineSplitter().convert(content)) {
      p.addLine(line);
    }
    return p.finish();
  }

  /// Liest eine Datei zeilenweise. Gedacht für den Aufruf in einem Isolate:
  /// `Isolate.run(() => M3uParser.parseFile(path))`.
  static Future<M3uPlaylist> parseFile(String path) async {
    final p = M3uParser();
    final lines = File(path)
        .openRead()
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter());
    await for (final line in lines) {
      p.addLine(line);
    }
    return p.finish();
  }
}
