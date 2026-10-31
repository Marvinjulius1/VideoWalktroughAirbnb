import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/db/database.dart';
import '../../core/network/http.dart';
import '../../core/network/source_error.dart';
import '../settings/settings.dart';
import '../sources/data/m3u/m3u_source.dart';
import '../sources/data/xtream/xtream_client.dart';
import '../sources/data/xtream/xtream_models.dart';
import '../sources/domain/source_profile.dart';
import '../epg/data/epg_store.dart';
import '../epg/data/epg_sync.dart';
import 'content_store.dart';
import 'source_sync.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = createSourceDio();
  ref.onDispose(dio.close);
  return dio;
});

final contentStoreProvider = Provider((ref) => ContentStore(ref.watch(databaseProvider)));

final epgStoreProvider = Provider((ref) => EpgStore(ref.watch(databaseProvider)));

final sourceSyncProvider = Provider(
  (ref) => SourceSync(
    dio: ref.watch(dioProvider),
    store: ref.watch(contentStoreProvider),
    epg: EpgSync(dio: ref.watch(dioProvider), store: ref.watch(epgStoreProvider)),
  ),
);

/// Prüft Zugangsdaten, bevor eine Quelle gespeichert wird.
class ConnectionTester {
  ConnectionTester(this._dio);

  final Dio _dio;

  /// Liefert bei Xtream die Kontoinfo zurück; wirft [SourceException].
  Future<XtreamAccount?> test(SourceType type, {String? server, required SourceCredentials creds}) async {
    switch (type) {
      case SourceType.xtream:
        return XtreamClient(_dio, XtreamUrls(server!, creds.username ?? '', creds.password ?? ''))
            .account();
      case SourceType.m3uUrl:
        await M3uSource(_dio).test(creds.playlistUrl!);
        return null;
      case SourceType.m3uFile:
        return null; // Datei wird schon beim Import geprüft.
    }
  }
}

final connectionTesterProvider = Provider((ref) => ConnectionTester(ref.watch(dioProvider)));

/// Zustand der Aktualisierung der aktiven Quelle.
@immutable
class SyncState {
  const SyncState({this.profileId, this.progress, this.error});

  final String? profileId;
  final SyncProgress? progress;
  final SourceErrorKind? error;

  bool get running =>
      progress != null && progress!.stage != SyncStage.done && error == null;
}

final syncControllerProvider =
    NotifierProvider<SyncController, SyncState>(SyncController.new);

class SyncController extends Notifier<SyncState> {
  static const staleAfter = Duration(hours: 12);

  bool _autoChecked = false;
  int _run = 0;

  @override
  SyncState build() {
    // Beim Start einmalig: aktive Quelle automatisch aktualisieren, wenn
    // sie noch nie oder vor mehr als 12 Stunden geladen wurde.
    ref.listen<SourceProfile?>(activeSourceProvider, (_, next) {
      if (_autoChecked || next == null) return;
      _autoChecked = true;
      final auto = ref.read(settingsProvider).autoRefresh;
      final last = next.lastSyncAt;
      if (auto && (last == null || DateTime.now().difference(last) > staleAfter)) {
        Future.microtask(() => syncNow(next));
      }
    }, fireImmediately: true);
    return const SyncState();
  }

  /// Lädt [profile] neu. Läuft schon eine Aktualisierung für dieses Profil,
  /// passiert nichts.
  Future<void> syncNow(SourceProfile profile) async {
    if (state.running && state.profileId == profile.id) return;
    final run = ++_run;
    state = SyncState(profileId: profile.id, progress: const SyncProgress(SyncStage.connecting));
    try {
      final creds = await ref.read(sourcesRepositoryProvider).credentials(profile.id);
      await for (final p in ref.read(sourceSyncProvider).run(profile, creds)) {
        if (run != _run) return; // überholt von einer neueren Aktualisierung
        state = SyncState(profileId: profile.id, progress: p);
      }
    } on SourceException catch (e) {
      if (run == _run) {
        state = SyncState(profileId: profile.id, progress: state.progress, error: e.kind);
      }
    }
  }
}

/// Anzahl Sender/Filme/Serien der aktiven Quelle (live aus der DB).
final activeCountsProvider = StreamProvider<ContentCounts>((ref) {
  final p = ref.watch(activeSourceProvider);
  if (p == null) return Stream.value(const ContentCounts());
  return ref.watch(contentStoreProvider).watchCounts(p.id);
});

final accountInfoProvider = StreamProvider.family<AccountInfoRow?, String>(
  (ref, profileId) => ref.watch(contentStoreProvider).watchAccount(profileId),
);
