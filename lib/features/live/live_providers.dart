import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/db/database.dart';
import '../player/media_kit_engine.dart';
import '../player/playable.dart';
import '../player/player_engine.dart';
import '../settings/settings.dart';
import 'data/live_repository.dart';

final liveRepositoryProvider = Provider((ref) => LiveRepository(ref.watch(databaseProvider)));

final liveCategoriesProvider = StreamProvider<List<CategoryRow>>((ref) {
  final p = ref.watch(activeSourceProvider);
  if (p == null) return Stream.value(const []);
  return ref.watch(liveRepositoryProvider).watchCategories(p.id);
});

final liveChannelCountProvider = StreamProvider<int>((ref) {
  final p = ref.watch(activeSourceProvider);
  if (p == null) return Stream.value(0);
  return ref.watch(liveRepositoryProvider).watchChannelCount(p.id);
});

final favoriteKeysProvider = StreamProvider.family<Set<String>, ContentKind>((ref, kind) {
  final p = ref.watch(activeSourceProvider);
  if (p == null) return Stream.value(const {});
  return ref.watch(liveRepositoryProvider).watchFavoriteKeys(p.id, kind);
});

/// Vom Nutzer gewählter Filter (`null` = noch nichts gewählt → Standard).
final selectedLiveFilterProvider =
    NotifierProvider<SelectedLiveFilter, LiveFilter?>(SelectedLiveFilter.new);

class SelectedLiveFilter extends Notifier<LiveFilter?> {
  @override
  LiveFilter? build() {
    ref.watch(activeSourceProvider.select((p) => p?.id)); // Quelle gewechselt → zurücksetzen
    return null;
  }

  void select(LiveFilter f) => state = f;
}

/// Tatsächlich angezeigter Filter: Favoriten, wenn es welche gibt, sonst
/// die erste Kategorie – bei sehr großen Listen nie „Alle“ als Start.
final effectiveLiveFilterProvider = Provider<LiveFilter>((ref) {
  final chosen = ref.watch(selectedLiveFilterProvider);
  if (chosen != null) return chosen;
  final favs = ref.watch(favoriteKeysProvider(ContentKind.live)).value ?? const {};
  if (favs.isNotEmpty) return const FavoriteChannels();
  final cats = ref.watch(liveCategoriesProvider).value ?? const [];
  if (cats.isNotEmpty) return CategoryChannels(cats.first.remoteId);
  return const AllChannels();
});

final liveChannelsProvider = StreamProvider<List<ChannelRow>>((ref) {
  final p = ref.watch(activeSourceProvider);
  if (p == null) return Stream.value(const []);
  final filter = ref.watch(effectiveLiveFilterProvider);
  return ref.watch(liveRepositoryProvider).watchChannels(p.id, filter);
});

/// Baut Stream-Adressen für die aktive Quelle (lädt dazu die Zugangsdaten
/// aus dem Schlüsselbund).
final activeResolverProvider = FutureProvider<StreamResolver?>((ref) async {
  final p = ref.watch(activeSourceProvider);
  if (p == null) return null;
  final creds = await ref.watch(sourcesRepositoryProvider).credentials(p.id);
  final format = ref.watch(settingsProvider.select((s) => s.liveFormat));
  return StreamResolver(profile: p, credentials: creds, liveFormat: format);
});

/// Erzeugt den Video-Motor. In Tests durch einen Fake ersetzt.
final playerEngineFactoryProvider = Provider<PlayerEngine Function()>((ref) => MediaKitEngine.new);
