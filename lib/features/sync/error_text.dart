import '../../core/l10n/app_localizations.dart';
import '../../core/network/source_error.dart';

/// Freundliche Fehlermeldung (Titel + Lösungsvorschlag) für eine Fehlerart.
(String, String) sourceErrorText(AppLocalizations t, SourceErrorKind kind) => switch (kind) {
      SourceErrorKind.invalidCredentials => (t.errInvalidCredentials, t.errInvalidCredentialsHint),
      SourceErrorKind.accountExpired => (t.errAccountExpired, t.errAccountExpiredHint),
      SourceErrorKind.accountDisabled => (t.errAccountDisabled, t.errAccountDisabledHint),
      SourceErrorKind.serverUnreachable => (t.errServerUnreachable, t.errServerUnreachableHint),
      SourceErrorKind.timeout => (t.errTimeout, t.errTimeoutHint),
      SourceErrorKind.tls => (t.errTls, t.errTlsHint),
      SourceErrorKind.notFound => (t.errNotFound, t.errNotFoundHint),
      SourceErrorKind.invalidResponse => (t.errInvalidResponse, t.errInvalidResponseHint),
      SourceErrorKind.invalidPlaylist => (t.errInvalidPlaylist, t.errInvalidPlaylistHint),
      SourceErrorKind.cancelled || SourceErrorKind.unknown => (t.errUnknown, t.errUnknownHint),
    };
