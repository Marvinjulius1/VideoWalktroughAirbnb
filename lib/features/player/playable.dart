import 'package:flutter/foundation.dart';

import '../../core/db/database.dart';
import '../sources/data/xtream/xtream_client.dart';
import '../sources/domain/source_profile.dart';

/// Etwas, das der Player öffnen kann: Adresse plus optionale HTTP-Header
/// (manche M3U-Quellen verlangen einen bestimmten User-Agent).
@immutable
class PlayableStream {
  const PlayableStream(this.uri, {this.headers = const {}});

  final Uri uri;
  final Map<String, String> headers;

  /// Nie die vollständige Adresse ausgeben – sie enthält Zugangsdaten.
  @override
  String toString() => 'PlayableStream(${uri.scheme}://${uri.host}/…)';
}

/// Baut aus einem Sender die abspielbare Adresse.
class StreamResolver {
  const StreamResolver({
    required this.profile,
    required this.credentials,
    this.liveFormat = StreamFormat.ts,
  });

  final SourceProfile profile;
  final SourceCredentials credentials;
  final StreamFormat liveFormat;

  PlayableStream? live(ChannelRow c) {
    switch (profile.type) {
      case SourceType.xtream:
        final server = profile.serverUrl;
        if (server == null) return null;
        final urls = XtreamUrls(server, credentials.username ?? '', credentials.password ?? '');
        return PlayableStream(urls.live(c.itemKey, liveFormat));
      case SourceType.m3uUrl:
      case SourceType.m3uFile:
        final url = c.url;
        final uri = url == null ? null : Uri.tryParse(url);
        if (uri == null) return null;
        return PlayableStream(uri, headers: {
          if (c.userAgent != null) 'User-Agent': c.userAgent!,
        });
    }
  }
}
