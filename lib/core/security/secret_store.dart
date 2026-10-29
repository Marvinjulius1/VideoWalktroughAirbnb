import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Verschlüsselter Schlüssel/Wert-Speicher für Zugangsdaten.
///
/// Als Schnittstelle, damit Tests eine In-Memory-Variante nutzen können,
/// ohne Keychain/Keystore zu brauchen.
abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Echte Implementierung: iOS Keychain bzw. Android Keystore.
class DeviceSecretStore implements SecretStore {
  DeviceSecretStore()
      : _storage = const FlutterSecureStorage(
          // Nur auf diesem Gerät, nicht in iCloud-Backups/anderen Geräten.
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock_this_device,
          ),
        );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Für Tests.
class InMemorySecretStore implements SecretStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
