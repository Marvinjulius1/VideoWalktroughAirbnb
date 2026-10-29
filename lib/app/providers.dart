import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/db/database.dart';
import '../core/platform/device_profile.dart';
import '../core/security/secret_store.dart';
import '../features/sources/data/sources_repository.dart';
import '../features/sources/domain/source_profile.dart';

/// Grundlegende Abhängigkeiten. Werden in `main` (bzw. in Tests) mit echten
/// Instanzen überschrieben – so kann jeder Test seine eigene In-Memory-
/// Datenbank und einen Fake-Speicher einsetzen.
final databaseProvider = Provider<LumenDatabase>(
  (ref) => throw UnimplementedError('databaseProvider muss überschrieben werden'),
);

final secretStoreProvider = Provider<SecretStore>((ref) => DeviceSecretStore());

final deviceProfileProvider =
    Provider<DeviceProfile>((ref) => const DeviceProfile());

final sourcesRepositoryProvider = Provider<SourcesRepository>(
  (ref) => SourcesRepository(
    ref.watch(databaseProvider),
    ref.watch(secretStoreProvider),
  ),
);

/// Alle Quellen, live aus der Datenbank.
final sourcesProvider = StreamProvider<List<SourceProfile>>(
  (ref) => ref.watch(sourcesRepositoryProvider).watchAll(),
);

/// Die aktive Quelle (= Standard), oder `null`, wenn es noch keine gibt.
final activeSourceProvider = Provider<SourceProfile?>((ref) {
  final list = ref.watch(sourcesProvider).value ?? const [];
  if (list.isEmpty) return null;
  return list.firstWhere((p) => p.isDefault, orElse: () => list.first);
});
