/// Prüft und vereinheitlicht Adressen, die der Nutzer eintippt.
///
/// Reine Funktionen ohne Flutter-Abhängigkeit → einfach zu testen.
library;

enum UrlProblem { empty, invalid, scheme, port }

/// Ergebnis einer Prüfung: entweder [url] (normalisiert) oder [problem].
class UrlCheck {
  const UrlCheck.ok(this.url) : problem = null;
  const UrlCheck.fail(this.problem) : url = null;

  final String? url;
  final UrlProblem? problem;

  bool get isValid => problem == null;
}

final _schemeLike = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*://');
final _portPart = RegExp(r'^\[?[^/\]]*\]?:(\d*)$');

/// Server-Adresse für Xtream Codes.
///
/// - Ergänzt `http://`, wenn kein Schema angegeben ist (die meisten Server
///   laufen auf http mit Port, z. B. `server:8080`).
/// - Entfernt Schrägstriche am Ende und versehentlich mitkopierte Pfade wie
///   `/player_api.php` oder `/get.php?...`.
/// - Erlaubt nur http und https.
UrlCheck normalizeServerUrl(String input) {
  var s = input.trim();
  if (s.isEmpty) return const UrlCheck.fail(UrlProblem.empty);
  if (!_schemeLike.hasMatch(s)) s = 'http://$s';

  final uri = Uri.tryParse(s);
  if (uri == null || uri.host.isEmpty) {
    return const UrlCheck.fail(UrlProblem.invalid);
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return const UrlCheck.fail(UrlProblem.scheme);
  }
  final portProblem = _checkPort(s, uri);
  if (portProblem != null) return UrlCheck.fail(portProblem);
  if (!_plausibleHost(uri.host)) return const UrlCheck.fail(UrlProblem.invalid);

  var path = uri.path;
  for (final tail in const [
    '/player_api.php',
    '/get.php',
    '/xmltv.php',
    '/panel_api.php',
    '/c/',
  ]) {
    final i = path.indexOf(tail);
    if (i >= 0) path = path.substring(0, i);
  }
  while (path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }

  final normalized = Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: path,
  ).toString();
  return UrlCheck.ok(normalized);
}

/// Vollständige Adresse (M3U-Playlist oder EPG). Pfad und Parameter bleiben
/// unverändert, nur Leerzeichen am Rand werden entfernt.
UrlCheck validateResourceUrl(String input, {bool optional = false}) {
  final s = input.trim();
  if (s.isEmpty) {
    return optional
        ? const UrlCheck.ok('')
        : const UrlCheck.fail(UrlProblem.empty);
  }
  if (!_schemeLike.hasMatch(s)) return const UrlCheck.fail(UrlProblem.scheme);
  final uri = Uri.tryParse(s);
  if (uri == null || uri.host.isEmpty) {
    return const UrlCheck.fail(UrlProblem.invalid);
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return const UrlCheck.fail(UrlProblem.scheme);
  }
  final portProblem = _checkPort(s, uri);
  if (portProblem != null) return UrlCheck.fail(portProblem);
  if (!_plausibleHost(uri.host)) return const UrlCheck.fail(UrlProblem.invalid);
  return UrlCheck.ok(s);
}

UrlProblem? _checkPort(String raw, Uri uri) {
  // Uri.parse wirft bei Ports > 65535 nicht immer, daher selbst prüfen.
  final authority = raw.split('://').last.split(RegExp(r'[/?#]')).first;
  final hostPort = authority.contains('@') ? authority.split('@').last : authority;
  final m = _portPart.firstMatch(hostPort);
  if (m == null) return null;
  final p = int.tryParse(m.group(1)!);
  if (p == null || p < 1 || p > 65535) return UrlProblem.port;
  return null;
}

bool _plausibleHost(String host) {
  if (host.contains(' ')) return false;
  // IPv6, IPv4, „localhost“ oder ein Name mit mindestens einem Punkt bzw.
  // ein einzelner Name im Heimnetz (z. B. „nas“) – alles erlaubt, solange
  // nur gültige Zeichen enthalten sind.
  return RegExp(r'^[a-zA-Z0-9.\-_:\[\]]+$').hasMatch(host);
}
