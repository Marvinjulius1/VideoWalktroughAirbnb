import 'package:flutter/foundation.dart';

/// Art der Quelle.
enum SourceType { xtream, m3uUrl, m3uFile }

/// Eine vom Nutzer eingetragene Quelle (= Profil/Playlist).
///
/// Enthält nur unkritische Daten. Zugangsdaten stehen in [SourceCredentials].
@immutable
class SourceProfile {
  const SourceProfile({
    required this.id,
    required this.name,
    required this.type,
    required this.createdAt,
    this.serverUrl,
    this.localPath,
    this.localFileName,
    this.isDefault = false,
    this.sortOrder = 0,
    this.lastSyncAt,
  });

  final String id;
  final String name;
  final SourceType type;
  final String? serverUrl;
  final String? localPath;
  final String? localFileName;
  final bool isDefault;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime? lastSyncAt;

  SourceProfile copyWith({
    String? name,
    String? serverUrl,
    String? localPath,
    String? localFileName,
    bool? isDefault,
    int? sortOrder,
  }) =>
      SourceProfile(
        id: id,
        name: name ?? this.name,
        type: type,
        createdAt: createdAt,
        serverUrl: serverUrl ?? this.serverUrl,
        localPath: localPath ?? this.localPath,
        localFileName: localFileName ?? this.localFileName,
        isDefault: isDefault ?? this.isDefault,
        sortOrder: sortOrder ?? this.sortOrder,
        lastSyncAt: lastSyncAt,
      );
}

/// Geheime Daten einer Quelle. Werden nur im verschlüsselten Speicher
/// abgelegt und nie geloggt.
@immutable
class SourceCredentials {
  const SourceCredentials({
    this.username,
    this.password,
    this.playlistUrl,
    this.epgUrl,
  });

  final String? username;
  final String? password;

  /// M3U-Adresse (enthält häufig Benutzer/Passwort als Parameter).
  final String? playlistUrl;

  /// EPG-Adresse (kann ebenfalls Zugangsdaten enthalten).
  final String? epgUrl;

  Map<String, String> toJson() => {
        'u': ?username,
        'p': ?password,
        'm3u': ?playlistUrl,
        'epg': ?epgUrl,
      };

  factory SourceCredentials.fromJson(Map<String, dynamic> j) =>
      SourceCredentials(
        username: j['u'] as String?,
        password: j['p'] as String?,
        playlistUrl: j['m3u'] as String?,
        epgUrl: j['epg'] as String?,
      );

  /// Absichtlich ohne Inhalte, damit Zugangsdaten nie in Logs landen.
  @override
  String toString() => 'SourceCredentials(***)';

  @override
  bool operator ==(Object other) =>
      other is SourceCredentials &&
      other.username == username &&
      other.password == password &&
      other.playlistUrl == playlistUrl &&
      other.epgUrl == epgUrl;

  @override
  int get hashCode => Object.hash(username, password, playlistUrl, epgUrl);
}
