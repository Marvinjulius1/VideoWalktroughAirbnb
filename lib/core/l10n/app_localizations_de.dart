// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appName => 'Lumen';

  @override
  String get contentNotice =>
      'Diese App enthält keine Inhalte. Du bist selbst dafür verantwortlich, nur Quellen zu verwenden, zu deren Nutzung du berechtigt bist.';

  @override
  String get contentNoticeTitle => 'Hinweis zu Inhalten';

  @override
  String get onb1Title => 'Willkommen bei Lumen';

  @override
  String get onb1Body => 'Dein Fernsehen – ruhig, klar und schön.';

  @override
  String get onb2Title => 'Alles an einem Ort';

  @override
  String get onb2Body =>
      'Live-TV, Filme und Serien aus deinen eigenen Quellen. Mit Programmführer und Weiterschauen.';

  @override
  String get onb3Title => 'Deine Daten bleiben bei dir';

  @override
  String get onb3Body =>
      'Zugangsdaten werden verschlüsselt nur auf diesem Gerät gespeichert. Kein Tracking, keine Werbung.';

  @override
  String get onbConfirm => 'Verstanden';

  @override
  String get next => 'Weiter';

  @override
  String get getStarted => 'Los geht’s';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get save => 'Speichern';

  @override
  String get delete => 'Löschen';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get done => 'Fertig';

  @override
  String get showPassword => 'Passwort anzeigen';

  @override
  String get hidePassword => 'Passwort ausblenden';

  @override
  String get tabHome => 'Start';

  @override
  String get tabLive => 'Live';

  @override
  String get tabMedia => 'Filme & Serien';

  @override
  String get tabSearch => 'Suche';

  @override
  String get tabProfile => 'Profil';

  @override
  String get greetingMorning => 'Guten Morgen';

  @override
  String get greetingDay => 'Guten Tag';

  @override
  String get greetingEvening => 'Guten Abend';

  @override
  String get greetingNight => 'Gute Nacht';

  @override
  String get emptyNoSourceTitle => 'Noch keine Quelle';

  @override
  String get emptyNoSourceBody =>
      'Füge deinen eigenen Zugang hinzu, um Live-TV, Filme und Serien zu sehen.';

  @override
  String get addSource => 'Quelle hinzufügen';

  @override
  String get homeNotSyncedTitle => 'Bereit für deine Inhalte';

  @override
  String get homeNotSyncedBody =>
      'Sobald deine Quelle aktualisiert ist, erscheinen hier Weiterschauen, Jetzt live, Favoriten und Neuzugänge.';

  @override
  String get activeSource => 'Aktive Quelle';

  @override
  String get liveEmptyTitle => 'Noch keine Sender';

  @override
  String get liveEmptyBody =>
      'Die Sender deiner Quelle erscheinen hier, sobald sie geladen sind.';

  @override
  String get movies => 'Filme';

  @override
  String get series => 'Serien';

  @override
  String get moviesEmptyTitle => 'Noch keine Filme';

  @override
  String get seriesEmptyTitle => 'Noch keine Serien';

  @override
  String get mediaEmptyBody =>
      'Sobald deine Quelle geladen ist, findest du hier alles übersichtlich sortiert.';

  @override
  String get searchHint => 'Sender, Filme, Serien';

  @override
  String get searchEmptyTitle => 'Alles durchsuchen';

  @override
  String get searchEmptyBody =>
      'Finde Sender, Filme und Serien aus all deinen Quellen.';

  @override
  String get profileSources => 'Quellen verwalten';

  @override
  String get settings => 'Einstellungen';

  @override
  String get switchSource => 'Quelle wechseln';

  @override
  String get addSourceTitle => 'Quelle hinzufügen';

  @override
  String get addSourceSubtitle => 'Wie möchtest du dich verbinden?';

  @override
  String get typeXtream => 'Xtream Codes';

  @override
  String get typeXtreamDesc => 'Server, Benutzername und Passwort';

  @override
  String get typeM3uUrl => 'M3U-Link';

  @override
  String get typeM3uUrlDesc => 'Playlist-Adresse, optional mit EPG';

  @override
  String get typeM3uFile => 'M3U-Datei';

  @override
  String get typeM3uFileDesc => 'Playlist-Datei von diesem Gerät';

  @override
  String get fieldName => 'Name';

  @override
  String get fieldNameHint => 'z. B. Wohnzimmer';

  @override
  String get fieldServer => 'Server-Adresse';

  @override
  String get fieldServerHint => 'http://server.beispiel:8080';

  @override
  String get fieldUsername => 'Benutzername';

  @override
  String get fieldPassword => 'Passwort';

  @override
  String get fieldPlaylistUrl => 'Playlist-Adresse';

  @override
  String get fieldPlaylistUrlHint => 'https://…/playlist.m3u';

  @override
  String get fieldEpgUrl => 'EPG-Adresse (optional)';

  @override
  String get fieldEpgUrlHelper => 'XMLTV-Programmdaten für den Programmführer.';

  @override
  String get fieldFile => 'Playlist-Datei';

  @override
  String get chooseFile => 'Datei auswählen';

  @override
  String get changeFile => 'Andere Datei wählen';

  @override
  String get errRequired => 'Bitte ausfüllen.';

  @override
  String get errUrlInvalid =>
      'Das sieht nicht nach einer gültigen Adresse aus. Beispiel: http://server:8080';

  @override
  String get errUrlScheme =>
      'Die Adresse muss mit http:// oder https:// beginnen.';

  @override
  String get errPort => 'Der Port muss zwischen 1 und 65535 liegen.';

  @override
  String get errFileRequired => 'Bitte wähle eine Playlist-Datei aus.';

  @override
  String get errFileRead => 'Die Datei konnte nicht gelesen werden.';

  @override
  String get sourceSaved => 'Quelle gespeichert';

  @override
  String get sourceSaveFailed =>
      'Die Quelle konnte nicht gespeichert werden. Bitte versuche es erneut.';

  @override
  String get editSourceTitle => 'Quelle bearbeiten';

  @override
  String get sourcesTitle => 'Quellen';

  @override
  String get sourceDefault => 'Standard';

  @override
  String get setAsDefault => 'Als Standard festlegen';

  @override
  String get deleteSourceTitle => 'Quelle löschen?';

  @override
  String deleteSourceBody(String name) {
    return '„$name“ und alle zugehörigen Favoriten und Verläufe werden von diesem Gerät entfernt.';
  }

  @override
  String get sourceDeleted => 'Quelle gelöscht';

  @override
  String get settingsGeneral => 'Allgemein';

  @override
  String get settingsLanguage => 'Sprache';

  @override
  String get languageSystem => 'Systemsprache';

  @override
  String get settingsHaptics => 'Haptisches Feedback';

  @override
  String get settingsAppearance => 'Aussehen';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get settingsAccent => 'Akzentfarbe';

  @override
  String get accentBlue => 'Blau';

  @override
  String get accentGreen => 'Grün';

  @override
  String get accentMint => 'Mint';

  @override
  String get accentOrange => 'Orange';

  @override
  String get accentPurple => 'Lila';

  @override
  String get accentGraphite => 'Graphit';

  @override
  String get settingsInfo => 'Info';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsPrivacy => 'Datenschutz';

  @override
  String get settingsLicenses => 'Open-Source-Lizenzen';

  @override
  String get privacySummary =>
      'Lumen speichert alle Daten ausschließlich auf diesem Gerät. Zugangsdaten werden verschlüsselt im Schlüsselbund (iOS) bzw. Android Keystore abgelegt. Es gibt keine Analyse, kein Tracking, keine Werbung und keine Server des Entwicklers. Die App verbindet sich nur mit den Adressen, die du selbst einträgst.';

  @override
  String get errNotM3u =>
      'Diese Datei sieht nicht nach einer M3U-Playlist aus.';

  @override
  String get later => 'Später';

  @override
  String onbStep(int current, int total) {
    return 'Schritt $current von $total';
  }

  @override
  String get contentNoticeShort => 'Lumen enthält keine Inhalte';

  @override
  String get close => 'Schließen';

  @override
  String get errInvalidCredentials =>
      'Benutzername oder Passwort stimmen nicht.';

  @override
  String get errInvalidCredentialsHint => 'Prüfe Groß- und Kleinschreibung.';

  @override
  String get errAccountExpired => 'Dieser Zugang ist abgelaufen.';

  @override
  String get errAccountExpiredHint =>
      'Wende dich an deinen Anbieter, um ihn zu verlängern.';

  @override
  String get errAccountDisabled =>
      'Dieser Zugang ist gesperrt oder deaktiviert.';

  @override
  String get errAccountDisabledHint => 'Wende dich an deinen Anbieter.';

  @override
  String get errServerUnreachable => 'Der Server ist nicht erreichbar.';

  @override
  String get errServerUnreachableHint =>
      'Prüfe die Adresse inklusive Port und deine Internetverbindung.';

  @override
  String get errTimeout => 'Der Server antwortet nicht rechtzeitig.';

  @override
  String get errTimeoutHint => 'Versuche es gleich noch einmal.';

  @override
  String get errTls => 'Die sichere Verbindung ist fehlgeschlagen.';

  @override
  String get errTlsHint => 'Versuche die Adresse mit http:// statt https://.';

  @override
  String get errNotFound => 'Unter dieser Adresse wurde nichts gefunden.';

  @override
  String get errNotFoundHint => 'Prüfe die Adresse auf Tippfehler.';

  @override
  String get errInvalidResponse => 'Der Server hat unerwartet geantwortet.';

  @override
  String get errInvalidResponseHint =>
      'Ist das wirklich die Adresse eines Xtream-Servers?';

  @override
  String get errInvalidPlaylist => 'Das ist keine gültige M3U-Playlist.';

  @override
  String get errInvalidPlaylistHint => 'Prüfe die Adresse oder die Datei.';

  @override
  String get errUnknown => 'Etwas ist schiefgelaufen.';

  @override
  String get errUnknownHint => 'Versuche es noch einmal.';

  @override
  String get testAndSave => 'Verbindung testen & speichern';

  @override
  String get testing => 'Verbindung wird geprüft …';

  @override
  String get saveAnyway => 'Trotzdem speichern';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get syncConnecting => 'Verbinde …';

  @override
  String get syncCategories => 'Kategorien werden geladen …';

  @override
  String get syncLive => 'Sender werden geladen …';

  @override
  String get syncVod => 'Filme werden geladen …';

  @override
  String get syncSeries => 'Serien werden geladen …';

  @override
  String get syncSaving => 'Wird gespeichert …';

  @override
  String get syncFailedTitle => 'Aktualisieren fehlgeschlagen';

  @override
  String countsLine(int live, int vod, int series) {
    final intl.NumberFormat liveNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String liveString = liveNumberFormat.format(live);
    final intl.NumberFormat vodNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String vodString = vodNumberFormat.format(vod);
    final intl.NumberFormat seriesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String seriesString = seriesNumberFormat.format(series);

    return '$liveString Sender · $vodString Filme · $seriesString Serien';
  }

  @override
  String lastSynced(String when) {
    return 'Aktualisiert $when';
  }

  @override
  String get neverSynced => 'Noch nicht aktualisiert';

  @override
  String get refreshNow => 'Jetzt aktualisieren';

  @override
  String get settingsAutoRefresh => 'Beim Start aktualisieren';

  @override
  String get settingsAutoRefreshFooter =>
      'Lädt die Inhalte der aktiven Quelle neu, wenn sie älter als 12 Stunden sind.';

  @override
  String get accountTitle => 'Konto';

  @override
  String get accountStatus => 'Status';

  @override
  String get accountExpires => 'Läuft ab';

  @override
  String get accountUnlimited => 'Unbegrenzt';

  @override
  String get accountConnections => 'Verbindungen';

  @override
  String get accountCreated => 'Erstellt';

  @override
  String get accountActive => 'Aktiv';

  @override
  String get accountTrial => 'Testzugang';

  @override
  String searchNoResults(String query) {
    return 'Nichts gefunden für „$query“';
  }

  @override
  String get searchNoResultsBody =>
      'Versuche einen kürzeren oder anderen Begriff.';

  @override
  String get justNow => 'gerade eben';

  @override
  String get liveFavorites => 'Favoriten';

  @override
  String get liveRecent => 'Zuletzt gesehen';

  @override
  String get liveAll => 'Alle Sender';

  @override
  String get liveNoFavoritesTitle => 'Noch keine Favoriten';

  @override
  String get liveNoFavoritesBody =>
      'Tippe auf den Stern neben einem Sender, um ihn hier zu sammeln.';

  @override
  String get liveNoRecentTitle => 'Noch nichts gesehen';

  @override
  String get liveNoRecentBody => 'Sender, die du ansiehst, erscheinen hier.';

  @override
  String get liveEmptyCategory => 'In dieser Kategorie gibt es keine Sender.';

  @override
  String get favoriteAdd => 'Zu Favoriten hinzufügen';

  @override
  String get favoriteRemove => 'Aus Favoriten entfernen';

  @override
  String channelNumber(int number) {
    return 'Sender $number';
  }

  @override
  String get liveBadge => 'LIVE';

  @override
  String get playerReconnecting => 'Verbindung wird wiederhergestellt …';

  @override
  String get playerFailedTitle => 'Wiedergabe nicht möglich';

  @override
  String get playerFailedBody =>
      'Der Sender ist gerade nicht erreichbar. Vielleicht hilft ein anderes Streamformat in den Einstellungen.';

  @override
  String get playerClose => 'Schließen';

  @override
  String get playerPlay => 'Abspielen';

  @override
  String get playerPause => 'Pause';

  @override
  String get playerPrevChannel => 'Vorheriger Sender';

  @override
  String get playerNextChannel => 'Nächster Sender';

  @override
  String get playerOptions => 'Ton, Untertitel & Bild';

  @override
  String get playerAudio => 'Ton';

  @override
  String get playerSubtitles => 'Untertitel';

  @override
  String get playerSubtitlesOff => 'Aus';

  @override
  String get playerPicture => 'Bild';

  @override
  String get fitAuto => 'Automatisch';

  @override
  String get fitFill => 'Füllen';

  @override
  String get fitZoom => 'Zoom';

  @override
  String get fit16x9 => '16:9';

  @override
  String get fit4x3 => '4:3';

  @override
  String get playerNoTracks => 'Keine Auswahl verfügbar';

  @override
  String channelPosition(int current, int total) {
    return '$current von $total';
  }

  @override
  String get settingsPlayer => 'Player';

  @override
  String get settingsLiveFormat => 'Streamformat (Xtream)';

  @override
  String get settingsLiveFormatFooter =>
      'MPEG-TS funktioniert meist am besten. Wenn Sender ruckeln oder nicht starten, probiere HLS.';

  @override
  String get syncEpg => 'Programmführer wird geladen …';

  @override
  String get epgGuide => 'Programm';

  @override
  String get epgGuideTitle => 'Programmführer';

  @override
  String get epgNow => 'Jetzt';

  @override
  String get epgNext => 'Danach';

  @override
  String get epgNoInfo => 'Keine Programminfos';

  @override
  String get epgToday => 'Heute';

  @override
  String get epgTomorrow => 'Morgen';

  @override
  String get epgEmptyTitle => 'Kein Programmführer';

  @override
  String get epgEmptyBody =>
      'Deine Quelle liefert keine Programmdaten oder sie wurden noch nicht geladen. Bei M3U kannst du eine EPG-Adresse in der Quelle eintragen.';

  @override
  String get epgWatch => 'Ansehen';

  @override
  String get epgRemind => 'Erinnern';

  @override
  String get epgReminderSet => 'Erinnerung aktiv';

  @override
  String get epgReminderRemoved => 'Erinnerung entfernt';

  @override
  String get epgReminderDenied =>
      'Benachrichtigungen sind für Lumen ausgeschaltet. Du kannst sie in den Systemeinstellungen erlauben.';

  @override
  String epgReminderBody(String channel) {
    return 'Beginnt jetzt auf $channel';
  }

  @override
  String epgMinutesLeft(int minutes) {
    return 'noch $minutes Min.';
  }

  @override
  String epgStartsIn(int minutes) {
    return 'in $minutes Min.';
  }

  @override
  String get epgFailedNote => 'Der Programmführer konnte nicht geladen werden.';

  @override
  String get settingsEpg => 'Programmführer';

  @override
  String get settingsEpgOffset => 'Zeitverschiebung';

  @override
  String get settingsEpgOffsetFooter =>
      'Wenn die Sendezeiten deiner Quelle verschoben sind, gleiche sie hier aus.';

  @override
  String get offsetNone => 'Keine';

  @override
  String get remindersChannel => 'Erinnerungen';
}
