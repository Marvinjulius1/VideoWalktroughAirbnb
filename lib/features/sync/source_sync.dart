import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../core/db/database.dart';
import '../../core/network/source_error.dart';
import '../sources/data/m3u/m3u_parser.dart';
import '../sources/data/m3u/m3u_source.dart';
import '../sources/data/xtream/xtream_client.dart';
import '../sources/data/xtream/xtream_models.dart';
import '../sources/domain/source_profile.dart';
import '../epg/data/epg_sync.dart';
import 'content_store.dart';

/// Schritte einer Aktualisierung (für die Fortschrittsanzeige).
enum SyncStage { connecting, categories, live, vod, series, saving, epg, done }

class SyncProgress {
  const SyncProgress(this.stage, {this.fraction, this.counts, this.epgCount, this.epgError});

  final SyncStage stage;

  /// 0…1 beim Speichern, sonst `null` (unbestimmt).
  final double? fraction;

  /// Am Ende: wie viel geladen wurde.
  final ContentCounts? counts;

  /// Am Ende: Anzahl Sendungen im Programmführer (`null` = keine EPG-Quelle).
  final int? epgCount;

  /// Der Programmführer konnte nicht geladen werden (Inhalte schon).
  final SourceErrorKind? epgError;
}

/// Lädt eine Quelle komplett neu und schreibt sie in die Datenbank.
///
/// Ablauf: Netzwerk → Parsen + Umwandeln im Isolate → paketweises
/// Schreiben in einer Transaktion. Wirft [SourceException].
class SourceSync {
  SourceSync({required this.dio, required this.store, this.epg, M3uSource? m3u})
      : m3u = m3u ?? M3uSource(dio);

  final Dio dio;
  final ContentStore store;

  /// Optional: Programmführer nach den Inhalten laden.
  final EpgSync? epg;
  final M3uSource m3u;

  Stream<SyncProgress> run(SourceProfile profile, SourceCredentials creds) async* {
    yield const SyncProgress(SyncStage.connecting);
    try {
      final data = switch (profile.type) {
        SourceType.xtream => _xtream(profile, creds),
        SourceType.m3uUrl || SourceType.m3uFile => _m3u(profile, creds),
      };
      late _Loaded loaded;
      await for (final step in data) {
        if (step is SyncProgress) yield step;
        if (step is _Loaded) loaded = step;
      }

      yield const SyncProgress(SyncStage.saving, fraction: 0);
      final progress = StreamController<SyncProgress>();
      final write = store
          .replaceAll(
            profileId: profile.id,
            categories: loaded.categories,
            channels: loaded.channels,
            vod: loaded.vod,
            series: loaded.series,
            onProgress: (w, t) => progress.add(
                SyncProgress(SyncStage.saving, fraction: t == 0 ? 1 : w / t)),
          )
          .whenComplete(progress.close);
      yield* progress.stream;
      await write;

      // Programmführer: Fehler hier sind nicht schlimm – die Sender sind
      // schon gespeichert und funktionieren auch ohne EPG.
      int? epgCount;
      SourceErrorKind? epgError;
      if (epg != null) {
        yield const SyncProgress(SyncStage.epg);
        try {
          epgCount = await epg!.run(profile, creds, playlistHint: loaded.epgHint);
        } on SourceException catch (e) {
          epgError = e.kind;
        }
      }

      yield SyncProgress(
        SyncStage.done,
        epgCount: epgCount,
        epgError: epgError,
        counts: ContentCounts(
          live: loaded.channels.length,
          vod: loaded.vod.length,
          series: loaded.series.length,
        ),
      );
    } catch (e) {
      throw SourceException.wrap(e);
    }
  }

  // --- Xtream ----------------------------------------------------------

  Stream<Object> _xtream(SourceProfile p, SourceCredentials c) async* {
    final client = XtreamClient(dio, XtreamUrls(p.serverUrl!, c.username ?? '', c.password ?? ''));
    final account = await client.account();
    await store.saveAccount(p.id, account);

    yield const SyncProgress(SyncStage.categories);
    final cats = await Future.wait([
      client.liveCategories(),
      client.vodCategories(),
      client.seriesCategories(),
    ]);
    final id = p.id;
    final categories = <CategoriesCompanion>[
      for (final (kind, list) in [
        (ContentKind.live, cats[0]),
        (ContentKind.vod, cats[1]),
        (ContentKind.series, cats[2]),
      ])
        for (final (i, c) in _dedupeCats(list).indexed)
          CategoriesCompanion.insert(
              profileId: id, kind: kind, remoteId: c.id, name: c.name, sortIndex: i),
    ];

    yield const SyncProgress(SyncStage.live);
    final channels = await client.fetchMapped(
      'get_live_streams',
      XtreamLiveStream.fromJson,
      _liveMapper(id),
    );

    yield const SyncProgress(SyncStage.vod);
    final vod = await client.fetchMapped(
      'get_vod_streams',
      XtreamVodStream.fromJson,
      _vodMapper(id),
    );

    yield const SyncProgress(SyncStage.series);
    final series = await client.fetchMapped(
      'get_series',
      XtreamSeries.fromJson,
      _seriesMapper(id),
    );

    yield _Loaded(categories, channels, vod, series);
  }

  // Statische Fabriken: die Closures fangen nur die Profil-ID ein und
  // lassen sich so an das Parser-Isolate übergeben.
  static ChannelsCompanion Function(XtreamLiveStream, int) _liveMapper(String id) =>
      (s, i) => ChannelsCompanion.insert(
        profileId: id,
        itemKey: s.streamId,
        num: Value(s.num),
        name: s.name,
        logo: Value(s.icon),
        categoryId: Value(s.categoryId),
        epgChannelId: Value(s.epgChannelId),
        tvArchive: Value(s.tvArchive),
        archiveDays: Value(s.archiveDays),
        addedAt: Value(s.added),
        sortIndex: i,
      );

  static VodItemsCompanion Function(XtreamVodStream, int) _vodMapper(String id) =>
      (s, i) => VodItemsCompanion.insert(
        profileId: id,
        itemKey: s.streamId,
        name: s.name,
        poster: Value(s.icon),
        categoryId: Value(s.categoryId),
        rating: Value(s.rating),
        year: Value(s.year),
        containerExt: Value(s.containerExt),
        addedAt: Value(s.added),
        sortIndex: i,
      );

  static SeriesItemsCompanion Function(XtreamSeries, int) _seriesMapper(String id) =>
      (s, i) => SeriesItemsCompanion.insert(
        profileId: id,
        itemKey: s.seriesId,
        name: s.name,
        cover: Value(s.cover),
        categoryId: Value(s.categoryId),
        rating: Value(s.rating),
        year: Value(s.year),
        plot: Value(s.plot),
        genre: Value(s.genre),
        lastModified: Value(s.lastModified),
        sortIndex: i,
      );

  static List<XtreamCategory> _dedupeCats(List<XtreamCategory> list) {
    final seen = <String>{};
    return [for (final c in list) if (seen.add(c.id)) c];
  }

  // --- M3U -------------------------------------------------------------

  Stream<Object> _m3u(SourceProfile p, SourceCredentials c) async* {
    final id = p.id;
    yield const SyncProgress(SyncStage.live);
    // Parsen und Umwandeln in Datenbankzeilen passieren im selben Isolate.
    final mapper = _m3uMapper(id);
    yield p.type == SourceType.m3uFile
        ? await m3u.loadFileMapped(p.localPath!, mapper)
        : await m3u.loadUrlMapped(c.playlistUrl!, mapper);
  }

  /// Statisch: die Closure fängt nur die Profil-ID ein und lässt sich daher
  /// an ein Isolate übergeben.
  static _Loaded Function(M3uPlaylist) _m3uMapper(String id) =>
      (playlist) => _mapM3u(id, playlist);

  static _Loaded _mapM3u(String id, M3uPlaylist playlist) {
    final categories = <CategoriesCompanion>[];
    final seen = <(ContentKind, String)>{};
    final channels = <ChannelsCompanion>[];
    final vod = <VodItemsCompanion>[];
    final series = <SeriesItemsCompanion>[];

    for (final e in playlist.entries) {
      final kind = switch (e.kind) {
        M3uKind.live => ContentKind.live,
        M3uKind.movie => ContentKind.vod,
        M3uKind.series => ContentKind.series,
      };
      final group = e.group;
      if (group != null && seen.add((kind, group))) {
        categories.add(CategoriesCompanion.insert(
          profileId: id,
          kind: kind,
          remoteId: group,
          name: group,
          sortIndex: categories.where((c) => c.kind.value == kind).length,
        ));
      }
      switch (kind) {
        case ContentKind.live:
          channels.add(ChannelsCompanion.insert(
            profileId: id,
            itemKey: e.key,
            num: Value(e.channelNumber),
            name: e.name,
            logo: Value(e.logo),
            categoryId: Value(group),
            epgChannelId: Value(e.tvgId),
            tvArchive: Value((e.catchupDays ?? 0) > 0 || e.catchupMode != null),
            archiveDays: Value(e.catchupDays ?? 0),
            url: Value(e.url),
            userAgent: Value(e.userAgent),
            sortIndex: channels.length,
          ));
        case ContentKind.vod:
          vod.add(VodItemsCompanion.insert(
            profileId: id,
            itemKey: e.key,
            name: e.name,
            poster: Value(e.logo),
            categoryId: Value(group),
            url: Value(e.url),
            sortIndex: vod.length,
          ));
        case ContentKind.series:
          series.add(SeriesItemsCompanion.insert(
            profileId: id,
            itemKey: e.key,
            name: e.name,
            cover: Value(e.logo),
            categoryId: Value(group),
            url: Value(e.url),
            sortIndex: series.length,
          ));
      }
    }
    return _Loaded(categories, channels, vod, series, epgHint: playlist.epgUrl);
  }
}

class _Loaded {
  const _Loaded(this.categories, this.channels, this.vod, this.series, {this.epgHint});

  /// EPG-Adresse aus der Kopfzeile einer M3U (`url-tvg`).
  final String? epgHint;

  final List<CategoriesCompanion> categories;
  final List<ChannelsCompanion> channels;
  final List<VodItemsCompanion> vod;
  final List<SeriesItemsCompanion> series;
}
