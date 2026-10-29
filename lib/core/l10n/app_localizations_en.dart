// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Lumen';

  @override
  String get contentNotice =>
      'This app contains no content. You are responsible for only using sources you are authorized to use.';

  @override
  String get contentNoticeTitle => 'About content';

  @override
  String get onb1Title => 'Welcome to Lumen';

  @override
  String get onb1Body => 'Your TV – calm, clear and beautiful.';

  @override
  String get onb2Title => 'Everything in one place';

  @override
  String get onb2Body =>
      'Live TV, movies and series from your own sources. With a programme guide and continue watching.';

  @override
  String get onb3Title => 'Your data stays with you';

  @override
  String get onb3Body =>
      'Credentials are stored encrypted on this device only. No tracking, no ads.';

  @override
  String get onbConfirm => 'I understand';

  @override
  String get next => 'Next';

  @override
  String get getStarted => 'Get started';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get done => 'Done';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get tabHome => 'Home';

  @override
  String get tabLive => 'Live';

  @override
  String get tabMedia => 'Movies & Series';

  @override
  String get tabSearch => 'Search';

  @override
  String get tabProfile => 'Profile';

  @override
  String get greetingMorning => 'Good morning';

  @override
  String get greetingDay => 'Good afternoon';

  @override
  String get greetingEvening => 'Good evening';

  @override
  String get greetingNight => 'Good night';

  @override
  String get emptyNoSourceTitle => 'No source yet';

  @override
  String get emptyNoSourceBody =>
      'Add your own access to watch live TV, movies and series.';

  @override
  String get addSource => 'Add source';

  @override
  String get homeNotSyncedTitle => 'Ready for your content';

  @override
  String get homeNotSyncedBody =>
      'Once your source is refreshed, continue watching, live now, favourites and new arrivals will appear here.';

  @override
  String get activeSource => 'Active source';

  @override
  String get liveEmptyTitle => 'No channels yet';

  @override
  String get liveEmptyBody =>
      'Your source’s channels will appear here once loaded.';

  @override
  String get movies => 'Movies';

  @override
  String get series => 'Series';

  @override
  String get moviesEmptyTitle => 'No movies yet';

  @override
  String get seriesEmptyTitle => 'No series yet';

  @override
  String get mediaEmptyBody =>
      'Once your source is loaded, you’ll find everything neatly sorted here.';

  @override
  String get searchHint => 'Channels, movies, series';

  @override
  String get searchEmptyTitle => 'Search everything';

  @override
  String get searchEmptyBody =>
      'Find channels, movies and series across all your sources.';

  @override
  String get profileSources => 'Manage sources';

  @override
  String get settings => 'Settings';

  @override
  String get switchSource => 'Switch source';

  @override
  String get addSourceTitle => 'Add source';

  @override
  String get addSourceSubtitle => 'How would you like to connect?';

  @override
  String get typeXtream => 'Xtream Codes';

  @override
  String get typeXtreamDesc => 'Server, username and password';

  @override
  String get typeM3uUrl => 'M3U link';

  @override
  String get typeM3uUrlDesc => 'Playlist address, optionally with EPG';

  @override
  String get typeM3uFile => 'M3U file';

  @override
  String get typeM3uFileDesc => 'Playlist file from this device';

  @override
  String get fieldName => 'Name';

  @override
  String get fieldNameHint => 'e.g. Living room';

  @override
  String get fieldServer => 'Server address';

  @override
  String get fieldServerHint => 'http://server.example:8080';

  @override
  String get fieldUsername => 'Username';

  @override
  String get fieldPassword => 'Password';

  @override
  String get fieldPlaylistUrl => 'Playlist address';

  @override
  String get fieldPlaylistUrlHint => 'https://…/playlist.m3u';

  @override
  String get fieldEpgUrl => 'EPG address (optional)';

  @override
  String get fieldEpgUrlHelper => 'XMLTV data for the programme guide.';

  @override
  String get fieldFile => 'Playlist file';

  @override
  String get chooseFile => 'Choose file';

  @override
  String get changeFile => 'Choose another file';

  @override
  String get errRequired => 'Please fill in.';

  @override
  String get errUrlInvalid =>
      'This doesn’t look like a valid address. Example: http://server:8080';

  @override
  String get errUrlScheme => 'The address must start with http:// or https://.';

  @override
  String get errPort => 'The port must be between 1 and 65535.';

  @override
  String get errFileRequired => 'Please choose a playlist file.';

  @override
  String get errFileRead => 'The file could not be read.';

  @override
  String get sourceSaved => 'Source saved';

  @override
  String get sourceSaveFailed =>
      'The source could not be saved. Please try again.';

  @override
  String get editSourceTitle => 'Edit source';

  @override
  String get sourcesTitle => 'Sources';

  @override
  String get sourceDefault => 'Default';

  @override
  String get setAsDefault => 'Set as default';

  @override
  String get deleteSourceTitle => 'Delete source?';

  @override
  String deleteSourceBody(String name) {
    return '“$name” and all related favourites and history will be removed from this device.';
  }

  @override
  String get sourceDeleted => 'Source deleted';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageSystem => 'System language';

  @override
  String get settingsHaptics => 'Haptic feedback';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsAccent => 'Accent colour';

  @override
  String get accentBlue => 'Blue';

  @override
  String get accentGreen => 'Green';

  @override
  String get accentMint => 'Mint';

  @override
  String get accentOrange => 'Orange';

  @override
  String get accentPurple => 'Purple';

  @override
  String get accentGraphite => 'Graphite';

  @override
  String get settingsInfo => 'About';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsLicenses => 'Open-source licences';

  @override
  String get privacySummary =>
      'Lumen stores all data on this device only. Credentials are stored encrypted in the Keychain (iOS) or Android Keystore. There is no analytics, no tracking, no advertising and no developer servers. The app only connects to the addresses you enter yourself.';

  @override
  String get errNotM3u => 'This file doesn’t look like an M3U playlist.';

  @override
  String get later => 'Later';

  @override
  String onbStep(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get contentNoticeShort => 'Lumen contains no content';

  @override
  String get close => 'Close';

  @override
  String get errInvalidCredentials => 'Username or password is incorrect.';

  @override
  String get errInvalidCredentialsHint => 'Check upper and lower case.';

  @override
  String get errAccountExpired => 'This access has expired.';

  @override
  String get errAccountExpiredHint => 'Contact your provider to renew it.';

  @override
  String get errAccountDisabled => 'This access is blocked or disabled.';

  @override
  String get errAccountDisabledHint => 'Contact your provider.';

  @override
  String get errServerUnreachable => 'The server can’t be reached.';

  @override
  String get errServerUnreachableHint =>
      'Check the address including the port, and your internet connection.';

  @override
  String get errTimeout => 'The server is taking too long to respond.';

  @override
  String get errTimeoutHint => 'Please try again in a moment.';

  @override
  String get errTls => 'The secure connection failed.';

  @override
  String get errTlsHint => 'Try the address with http:// instead of https://.';

  @override
  String get errNotFound => 'Nothing was found at this address.';

  @override
  String get errNotFoundHint => 'Check the address for typos.';

  @override
  String get errInvalidResponse => 'The server responded unexpectedly.';

  @override
  String get errInvalidResponseHint =>
      'Is this really the address of an Xtream server?';

  @override
  String get errInvalidPlaylist => 'This isn’t a valid M3U playlist.';

  @override
  String get errInvalidPlaylistHint => 'Check the address or the file.';

  @override
  String get errUnknown => 'Something went wrong.';

  @override
  String get errUnknownHint => 'Please try again.';

  @override
  String get testAndSave => 'Test connection & save';

  @override
  String get testing => 'Checking connection …';

  @override
  String get saveAnyway => 'Save anyway';

  @override
  String get retry => 'Try again';

  @override
  String get syncConnecting => 'Connecting …';

  @override
  String get syncCategories => 'Loading categories …';

  @override
  String get syncLive => 'Loading channels …';

  @override
  String get syncVod => 'Loading movies …';

  @override
  String get syncSeries => 'Loading series …';

  @override
  String get syncSaving => 'Saving …';

  @override
  String get syncFailedTitle => 'Refresh failed';

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

    return '$liveString channels · $vodString movies · $seriesString series';
  }

  @override
  String lastSynced(String when) {
    return 'Updated $when';
  }

  @override
  String get neverSynced => 'Not refreshed yet';

  @override
  String get refreshNow => 'Refresh now';

  @override
  String get settingsAutoRefresh => 'Refresh on launch';

  @override
  String get settingsAutoRefreshFooter =>
      'Reloads the active source’s content when it is older than 12 hours.';

  @override
  String get accountTitle => 'Account';

  @override
  String get accountStatus => 'Status';

  @override
  String get accountExpires => 'Expires';

  @override
  String get accountUnlimited => 'Unlimited';

  @override
  String get accountConnections => 'Connections';

  @override
  String get accountCreated => 'Created';

  @override
  String get accountActive => 'Active';

  @override
  String get accountTrial => 'Trial';

  @override
  String searchNoResults(String query) {
    return 'Nothing found for “$query”';
  }

  @override
  String get searchNoResultsBody => 'Try a shorter or different term.';

  @override
  String get justNow => 'just now';

  @override
  String get liveFavorites => 'Favourites';

  @override
  String get liveRecent => 'Recently watched';

  @override
  String get liveAll => 'All channels';

  @override
  String get liveNoFavoritesTitle => 'No favourites yet';

  @override
  String get liveNoFavoritesBody =>
      'Tap the star next to a channel to collect it here.';

  @override
  String get liveNoRecentTitle => 'Nothing watched yet';

  @override
  String get liveNoRecentBody => 'Channels you watch will appear here.';

  @override
  String get liveEmptyCategory => 'There are no channels in this category.';

  @override
  String get favoriteAdd => 'Add to favourites';

  @override
  String get favoriteRemove => 'Remove from favourites';

  @override
  String channelNumber(int number) {
    return 'Channel $number';
  }

  @override
  String get liveBadge => 'LIVE';

  @override
  String get playerReconnecting => 'Reconnecting …';

  @override
  String get playerFailedTitle => 'Playback not possible';

  @override
  String get playerFailedBody =>
      'This channel can’t be reached right now. A different stream format in the settings might help.';

  @override
  String get playerClose => 'Close';

  @override
  String get playerPlay => 'Play';

  @override
  String get playerPause => 'Pause';

  @override
  String get playerPrevChannel => 'Previous channel';

  @override
  String get playerNextChannel => 'Next channel';

  @override
  String get playerOptions => 'Audio, subtitles & picture';

  @override
  String get playerAudio => 'Audio';

  @override
  String get playerSubtitles => 'Subtitles';

  @override
  String get playerSubtitlesOff => 'Off';

  @override
  String get playerPicture => 'Picture';

  @override
  String get fitAuto => 'Automatic';

  @override
  String get fitFill => 'Fill';

  @override
  String get fitZoom => 'Zoom';

  @override
  String get fit16x9 => '16:9';

  @override
  String get fit4x3 => '4:3';

  @override
  String get playerNoTracks => 'Nothing to choose';

  @override
  String channelPosition(int current, int total) {
    return '$current of $total';
  }

  @override
  String get settingsPlayer => 'Player';

  @override
  String get settingsLiveFormat => 'Stream format (Xtream)';

  @override
  String get settingsLiveFormatFooter =>
      'MPEG-TS usually works best. If channels stutter or don’t start, try HLS.';
}
