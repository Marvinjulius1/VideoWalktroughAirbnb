import 'dart:convert';

import 'json_tolerant.dart';

/// Kontoinformationen aus `player_api.php` (ohne `action`).
class XtreamAccount {
  const XtreamAccount({
    required this.authenticated,
    this.status,
    this.expiresAt,
    this.createdAt,
    this.isTrial = false,
    this.activeConnections,
    this.maxConnections,
    this.allowedFormats = const [],
    this.serverTimezone,
    this.message,
  });

  final bool authenticated;

  /// z. B. „Active“, „Expired“, „Banned“, „Disabled“.
  final String? status;

  /// `null` = unbegrenzt.
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final bool isTrial;
  final int? activeConnections;
  final int? maxConnections;
  final List<String> allowedFormats;
  final String? serverTimezone;
  final String? message;

  bool get isActive => (status ?? 'active').toLowerCase() == 'active';

  bool isExpiredAt(DateTime now) =>
      (status?.toLowerCase() == 'expired') ||
      (expiresAt != null && expiresAt!.isBefore(now));

  bool get isDisabled {
    final s = status?.toLowerCase();
    return s == 'banned' || s == 'disabled';
  }

  factory XtreamAccount.fromJson(Map<String, dynamic> json) {
    final u = jMap(json['user_info']);
    final s = jMap(json['server_info']);
    return XtreamAccount(
      authenticated: jBool(u['auth']),
      status: jStr(u['status']),
      expiresAt: jUnix(u['exp_date']),
      createdAt: jUnix(u['created_at']),
      isTrial: jBool(u['is_trial']),
      activeConnections: jInt(u['active_cons']),
      maxConnections: jInt(u['max_connections']),
      allowedFormats: [
        for (final f in jList(u['allowed_output_formats']))
          if (jStr(f) case final String s) s,
      ],
      serverTimezone: jStr(s['timezone']),
      message: jStr(u['message']),
    );
  }
}

class XtreamCategory {
  const XtreamCategory({required this.id, required this.name, this.parentId});

  final String id;
  final String name;
  final String? parentId;

  static XtreamCategory? fromJson(Object? raw) {
    final j = jMap(raw);
    final id = jStr(j['category_id']);
    if (id == null) return null;
    return XtreamCategory(
      id: id,
      name: jStr(j['category_name']) ?? id,
      parentId: jStr(j['parent_id']),
    );
  }
}

/// Kategorie-ID: entweder `category_id` oder das erste Element von
/// `category_ids` (neuere Server).
String? _categoryOf(Map<String, dynamic> j) =>
    jStr(j['category_id']) ?? jFirstStr(j['category_ids']);

class XtreamLiveStream {
  const XtreamLiveStream({
    required this.streamId,
    required this.name,
    this.num,
    this.icon,
    this.epgChannelId,
    this.categoryId,
    this.tvArchive = false,
    this.archiveDays = 0,
    this.added,
    this.directSource,
  });

  final String streamId;
  final String name;
  final int? num;
  final String? icon;
  final String? epgChannelId;
  final String? categoryId;
  final bool tvArchive;
  final int archiveDays;
  final DateTime? added;
  final String? directSource;

  static XtreamLiveStream? fromJson(Object? raw) {
    final j = jMap(raw);
    final id = jStr(j['stream_id']);
    if (id == null) return null;
    return XtreamLiveStream(
      streamId: id,
      name: jStr(j['name']) ?? id,
      num: jInt(j['num']),
      icon: jStr(j['stream_icon']),
      epgChannelId: jStr(j['epg_channel_id']),
      categoryId: _categoryOf(j),
      tvArchive: jBool(j['tv_archive']),
      archiveDays: jInt(j['tv_archive_duration']) ?? 0,
      added: jUnix(j['added']),
      directSource: jStr(j['direct_source']),
    );
  }
}

class XtreamVodStream {
  const XtreamVodStream({
    required this.streamId,
    required this.name,
    this.icon,
    this.categoryId,
    this.rating,
    this.added,
    this.containerExt,
    this.year,
  });

  final String streamId;
  final String name;
  final String? icon;
  final String? categoryId;

  /// Bewertung auf einer 10er-Skala.
  final double? rating;
  final DateTime? added;
  final String? containerExt;
  final int? year;

  static XtreamVodStream? fromJson(Object? raw) {
    final j = jMap(raw);
    final id = jStr(j['stream_id']);
    if (id == null) return null;
    return XtreamVodStream(
      streamId: id,
      name: jStr(j['name']) ?? id,
      icon: jStr(j['stream_icon']),
      categoryId: _categoryOf(j),
      rating: _rating10(j),
      added: jUnix(j['added']),
      containerExt: jStr(j['container_ext']),
      year: jYear(j['year']) ?? jYear(j['releaseDate']) ?? _yearFromName(jStr(j['name'])),
    );
  }
}

class XtreamSeries {
  const XtreamSeries({
    required this.seriesId,
    required this.name,
    this.cover,
    this.categoryId,
    this.rating,
    this.plot,
    this.genre,
    this.year,
    this.lastModified,
  });

  final String seriesId;
  final String name;
  final String? cover;
  final String? categoryId;
  final double? rating;
  final String? plot;
  final String? genre;
  final int? year;
  final DateTime? lastModified;

  static XtreamSeries? fromJson(Object? raw) {
    final j = jMap(raw);
    final id = jStr(j['series_id']);
    if (id == null) return null;
    return XtreamSeries(
      seriesId: id,
      name: jStr(j['name']) ?? id,
      cover: jStr(j['cover']),
      categoryId: _categoryOf(j),
      rating: _rating10(j),
      plot: jStr(j['plot']),
      genre: jStr(j['genre']),
      year: jYear(j['releaseDate']) ?? jYear(j['release_date']) ?? jYear(j['year']),
      lastModified: jUnix(j['last_modified']),
    );
  }
}

double? _rating10(Map<String, dynamic> j) {
  final r = jDouble(j['rating']);
  if (r != null && r > 0) return r.clamp(0, 10).toDouble();
  final r5 = jDouble(j['rating_5based']);
  if (r5 != null && r5 > 0) return (r5 * 2).clamp(0, 10).toDouble();
  return null;
}

int? _yearFromName(String? name) {
  if (name == null) return null;
  final m = RegExp(r'\((19|20)\d{2}\)').firstMatch(name);
  return m == null ? null : int.parse(m.group(0)!.substring(1, 5));
}

/// Detailinformationen zu einem Film (`get_vod_info`).
class XtreamVodInfo {
  const XtreamVodInfo({
    required this.streamId,
    required this.name,
    this.poster,
    this.backdrop,
    this.plot,
    this.genre,
    this.cast,
    this.director,
    this.year,
    this.duration,
    this.rating,
    this.trailerYoutubeId,
    this.containerExt,
  });

  final String streamId;
  final String name;
  final String? poster;
  final String? backdrop;
  final String? plot;
  final String? genre;
  final String? cast;
  final String? director;
  final int? year;
  final Duration? duration;
  final double? rating;
  final String? trailerYoutubeId;
  final String? containerExt;

  factory XtreamVodInfo.fromJson(Map<String, dynamic> json, String fallbackId) {
    // `info` ist bei leeren Einträgen manchmal eine leere Liste.
    final info = jMap(json['info']);
    final data = jMap(json['movie_data']);
    final secs = jInt(info['duration_secs']) ?? _parseHms(jStr(info['duration']));
    return XtreamVodInfo(
      streamId: jStr(data['stream_id']) ?? fallbackId,
      name: jStr(data['name']) ?? jStr(info['name']) ?? jStr(info['o_name']) ?? fallbackId,
      poster: jStr(info['movie_image']) ?? jStr(info['cover_big']),
      backdrop: jFirstStr(info['backdrop_path']),
      plot: jStr(info['plot']) ?? jStr(info['description']),
      genre: jStr(info['genre']),
      cast: jStr(info['cast']) ?? jStr(info['actors']),
      director: jStr(info['director']),
      year: jYear(info['releasedate']) ?? jYear(info['release_date']) ?? jYear(info['year']),
      duration: secs == null || secs <= 0 ? null : Duration(seconds: secs),
      rating: _rating10(info),
      trailerYoutubeId: jStr(info['youtube_trailer']),
      containerExt: jStr(data['container_ext']),
    );
  }
}

class XtreamEpisode {
  const XtreamEpisode({
    required this.id,
    required this.season,
    required this.episodeNum,
    required this.title,
    this.containerExt,
    this.image,
    this.plot,
    this.duration,
    this.rating,
  });

  final String id;
  final int season;
  final int episodeNum;
  final String title;
  final String? containerExt;
  final String? image;
  final String? plot;
  final Duration? duration;
  final double? rating;

  static XtreamEpisode? fromJson(Object? raw, int fallbackSeason) {
    final j = jMap(raw);
    final id = jStr(j['id']);
    if (id == null) return null;
    final info = jMap(j['info']);
    final secs = jInt(info['duration_secs']) ?? _parseHms(jStr(info['duration']));
    final num = jInt(j['episode_num']) ?? 0;
    return XtreamEpisode(
      id: id,
      season: jInt(j['season']) ?? fallbackSeason,
      episodeNum: num,
      title: jStr(j['title']) ?? 'Episode $num',
      containerExt: jStr(j['container_ext']),
      image: jStr(info['movie_image']) ?? jStr(info['cover_big']),
      plot: jStr(info['plot']),
      duration: secs == null || secs <= 0 ? null : Duration(seconds: secs),
      rating: _rating10(info),
    );
  }
}

/// Detailinformationen zu einer Serie (`get_series_info`).
class XtreamSeriesInfo {
  const XtreamSeriesInfo({
    required this.name,
    required this.episodes,
    this.cover,
    this.backdrop,
    this.plot,
    this.genre,
    this.cast,
    this.year,
    this.rating,
    this.trailerYoutubeId,
  });

  final String name;
  final String? cover;
  final String? backdrop;
  final String? plot;
  final String? genre;
  final String? cast;
  final int? year;
  final double? rating;
  final String? trailerYoutubeId;

  /// Alle Episoden, sortiert nach Staffel und Folge.
  final List<XtreamEpisode> episodes;

  List<int> get seasons => {for (final e in episodes) e.season}.toList()..sort();

  factory XtreamSeriesInfo.fromJson(Map<String, dynamic> json) {
    final info = jMap(json['info']);
    final eps = <XtreamEpisode>[];
    final raw = json['episodes'];
    if (raw is Map) {
      // Üblich: {"1": [...], "2": [...]} – Schlüssel = Staffel.
      raw.forEach((k, v) {
        final season = int.tryParse('$k') ?? 0;
        for (final e in jList(v)) {
          if (XtreamEpisode.fromJson(e, season) case final XtreamEpisode ep) eps.add(ep);
        }
      });
    } else if (raw is List) {
      // Manche Server: Liste von Listen oder flache Liste.
      for (final item in raw) {
        if (item is List) {
          for (final e in item) {
            if (XtreamEpisode.fromJson(e, 0) case final XtreamEpisode ep) eps.add(ep);
          }
        } else if (XtreamEpisode.fromJson(item, 0) case final XtreamEpisode ep) {
          eps.add(ep);
        }
      }
    }
    eps.sort((a, b) =>
        a.season != b.season ? a.season.compareTo(b.season) : a.episodeNum.compareTo(b.episodeNum));
    return XtreamSeriesInfo(
      name: jStr(info['name']) ?? '',
      cover: jStr(info['cover']),
      backdrop: jFirstStr(info['backdrop_path']),
      plot: jStr(info['plot']),
      genre: jStr(info['genre']),
      cast: jStr(info['cast']),
      year: jYear(info['releaseDate']) ?? jYear(info['release_date']),
      rating: _rating10(info),
      trailerYoutubeId: jStr(info['youtube_trailer']),
      episodes: eps,
    );
  }
}

/// Eine Sendung aus `get_short_epg`.
class XtreamEpgEntry {
  const XtreamEpgEntry({
    required this.title,
    required this.start,
    required this.end,
    this.description,
    this.hasArchive = false,
  });

  final String title;
  final DateTime start;
  final DateTime end;
  final String? description;
  final bool hasArchive;

  static XtreamEpgEntry? fromJson(Object? raw) {
    final j = jMap(raw);
    final start = jUnix(j['start_timestamp']);
    final end = jUnix(j['stop_timestamp']) ?? jUnix(j['end_timestamp']);
    if (start == null || end == null) return null;
    return XtreamEpgEntry(
      title: decodeMaybeBase64(jStr(j['title'])) ?? '',
      description: decodeMaybeBase64(jStr(j['description'])),
      start: start,
      end: end,
      hasArchive: jBool(j['has_archive']),
    );
  }
}

/// Xtream liefert EPG-Titel/Beschreibungen meist Base64-kodiert, manche
/// Server aber im Klartext. Nur wenn es sauber dekodiert, wird dekodiert.
String? decodeMaybeBase64(String? s) {
  if (s == null) return null;
  final looksB64 = s.length % 4 == 0 && RegExp(r'^[A-Za-z0-9+/]+={0,2}$').hasMatch(s);
  if (!looksB64) return s;
  try {
    final decoded = utf8.decode(base64.decode(s));
    // Ergibt nur Steuerzeichen-Salat → war wohl doch Klartext.
    if (RegExp(r'[\x00-\x08\x0E-\x1F]').hasMatch(decoded)) return s;
    return decoded;
  } on FormatException {
    return s;
  }
}

int? _parseHms(String? s) {
  if (s == null) return null;
  final parts = s.split(':').map(int.tryParse).toList();
  if (parts.any((p) => p == null)) return null;
  var total = 0;
  for (final p in parts) {
    total = total * 60 + p!;
  }
  return total;
}
