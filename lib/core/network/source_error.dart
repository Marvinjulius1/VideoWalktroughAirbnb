import 'dart:io';

import 'package:dio/dio.dart';

/// Was beim Verbinden mit einer Quelle schiefgehen kann – so unterteilt,
/// dass jede Art eine verständliche Meldung mit Lösungsvorschlag bekommt.
enum SourceErrorKind {
  invalidCredentials,
  accountExpired,
  accountDisabled,
  serverUnreachable,
  timeout,
  tls,
  notFound,
  invalidResponse,
  invalidPlaylist,
  cancelled,
  unknown,
}

class SourceException implements Exception {
  const SourceException(this.kind, [this.detail]);

  final SourceErrorKind kind;

  /// Technisches Detail für Entwickler. **Enthält nie Zugangsdaten oder
  /// URLs**, weil es in Fehlerdialogen landen kann.
  final String? detail;

  @override
  String toString() => 'SourceException($kind${detail == null ? '' : ': $detail'})';

  /// Übersetzt Netzwerkfehler von dio in unsere Fehlerarten.
  factory SourceException.fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const SourceException(SourceErrorKind.timeout);
      case DioExceptionType.badCertificate:
        return const SourceException(SourceErrorKind.tls);
      case DioExceptionType.cancel:
        return const SourceException(SourceErrorKind.cancelled);
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode ?? 0;
        if (code == 401 || code == 403) {
          return SourceException(SourceErrorKind.invalidCredentials, 'HTTP $code');
        }
        if (code == 404) return SourceException(SourceErrorKind.notFound, 'HTTP $code');
        return SourceException(SourceErrorKind.serverUnreachable, 'HTTP $code');
      case DioExceptionType.connectionError:
        final inner = e.error;
        if (inner is HandshakeException || inner is TlsException) {
          return const SourceException(SourceErrorKind.tls);
        }
        return SourceException(SourceErrorKind.serverUnreachable, inner?.runtimeType.toString());
      case DioExceptionType.unknown:
        final inner = e.error;
        if (inner is SocketException) {
          return const SourceException(SourceErrorKind.serverUnreachable, 'socket');
        }
        if (inner is HandshakeException || inner is TlsException) {
          return const SourceException(SourceErrorKind.tls);
        }
        if (inner is FormatException) {
          return const SourceException(SourceErrorKind.invalidResponse, 'format');
        }
        return SourceException(SourceErrorKind.unknown, inner?.runtimeType.toString());
    }
  }

  static SourceException wrap(Object e) => switch (e) {
        SourceException() => e,
        DioException() => SourceException.fromDio(e),
        FormatException() => const SourceException(SourceErrorKind.invalidResponse, 'format'),
        _ => SourceException(SourceErrorKind.unknown, e.runtimeType.toString()),
      };
}
