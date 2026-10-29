import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In de, this message translates to:
  /// **'Lumen'**
  String get appName;

  /// No description provided for @contentNotice.
  ///
  /// In de, this message translates to:
  /// **'Diese App enthält keine Inhalte. Du bist selbst dafür verantwortlich, nur Quellen zu verwenden, zu deren Nutzung du berechtigt bist.'**
  String get contentNotice;

  /// No description provided for @contentNoticeTitle.
  ///
  /// In de, this message translates to:
  /// **'Hinweis zu Inhalten'**
  String get contentNoticeTitle;

  /// No description provided for @onb1Title.
  ///
  /// In de, this message translates to:
  /// **'Willkommen bei Lumen'**
  String get onb1Title;

  /// No description provided for @onb1Body.
  ///
  /// In de, this message translates to:
  /// **'Dein Fernsehen – ruhig, klar und schön.'**
  String get onb1Body;

  /// No description provided for @onb2Title.
  ///
  /// In de, this message translates to:
  /// **'Alles an einem Ort'**
  String get onb2Title;

  /// No description provided for @onb2Body.
  ///
  /// In de, this message translates to:
  /// **'Live-TV, Filme und Serien aus deinen eigenen Quellen. Mit Programmführer und Weiterschauen.'**
  String get onb2Body;

  /// No description provided for @onb3Title.
  ///
  /// In de, this message translates to:
  /// **'Deine Daten bleiben bei dir'**
  String get onb3Title;

  /// No description provided for @onb3Body.
  ///
  /// In de, this message translates to:
  /// **'Zugangsdaten werden verschlüsselt nur auf diesem Gerät gespeichert. Kein Tracking, keine Werbung.'**
  String get onb3Body;

  /// No description provided for @onbConfirm.
  ///
  /// In de, this message translates to:
  /// **'Verstanden'**
  String get onbConfirm;

  /// No description provided for @next.
  ///
  /// In de, this message translates to:
  /// **'Weiter'**
  String get next;

  /// No description provided for @getStarted.
  ///
  /// In de, this message translates to:
  /// **'Los geht’s'**
  String get getStarted;

  /// No description provided for @cancel.
  ///
  /// In de, this message translates to:
  /// **'Abbrechen'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In de, this message translates to:
  /// **'Speichern'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In de, this message translates to:
  /// **'Löschen'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In de, this message translates to:
  /// **'Bearbeiten'**
  String get edit;

  /// No description provided for @done.
  ///
  /// In de, this message translates to:
  /// **'Fertig'**
  String get done;

  /// No description provided for @showPassword.
  ///
  /// In de, this message translates to:
  /// **'Passwort anzeigen'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In de, this message translates to:
  /// **'Passwort ausblenden'**
  String get hidePassword;

  /// No description provided for @tabHome.
  ///
  /// In de, this message translates to:
  /// **'Start'**
  String get tabHome;

  /// No description provided for @tabLive.
  ///
  /// In de, this message translates to:
  /// **'Live'**
  String get tabLive;

  /// No description provided for @tabMedia.
  ///
  /// In de, this message translates to:
  /// **'Filme & Serien'**
  String get tabMedia;

  /// No description provided for @tabSearch.
  ///
  /// In de, this message translates to:
  /// **'Suche'**
  String get tabSearch;

  /// No description provided for @tabProfile.
  ///
  /// In de, this message translates to:
  /// **'Profil'**
  String get tabProfile;

  /// No description provided for @greetingMorning.
  ///
  /// In de, this message translates to:
  /// **'Guten Morgen'**
  String get greetingMorning;

  /// No description provided for @greetingDay.
  ///
  /// In de, this message translates to:
  /// **'Guten Tag'**
  String get greetingDay;

  /// No description provided for @greetingEvening.
  ///
  /// In de, this message translates to:
  /// **'Guten Abend'**
  String get greetingEvening;

  /// No description provided for @greetingNight.
  ///
  /// In de, this message translates to:
  /// **'Gute Nacht'**
  String get greetingNight;

  /// No description provided for @emptyNoSourceTitle.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Quelle'**
  String get emptyNoSourceTitle;

  /// No description provided for @emptyNoSourceBody.
  ///
  /// In de, this message translates to:
  /// **'Füge deinen eigenen Zugang hinzu, um Live-TV, Filme und Serien zu sehen.'**
  String get emptyNoSourceBody;

  /// No description provided for @addSource.
  ///
  /// In de, this message translates to:
  /// **'Quelle hinzufügen'**
  String get addSource;

  /// No description provided for @homeNotSyncedTitle.
  ///
  /// In de, this message translates to:
  /// **'Bereit für deine Inhalte'**
  String get homeNotSyncedTitle;

  /// No description provided for @homeNotSyncedBody.
  ///
  /// In de, this message translates to:
  /// **'Sobald deine Quelle aktualisiert ist, erscheinen hier Weiterschauen, Jetzt live, Favoriten und Neuzugänge.'**
  String get homeNotSyncedBody;

  /// No description provided for @activeSource.
  ///
  /// In de, this message translates to:
  /// **'Aktive Quelle'**
  String get activeSource;

  /// No description provided for @liveEmptyTitle.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Sender'**
  String get liveEmptyTitle;

  /// No description provided for @liveEmptyBody.
  ///
  /// In de, this message translates to:
  /// **'Die Sender deiner Quelle erscheinen hier, sobald sie geladen sind.'**
  String get liveEmptyBody;

  /// No description provided for @movies.
  ///
  /// In de, this message translates to:
  /// **'Filme'**
  String get movies;

  /// No description provided for @series.
  ///
  /// In de, this message translates to:
  /// **'Serien'**
  String get series;

  /// No description provided for @moviesEmptyTitle.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Filme'**
  String get moviesEmptyTitle;

  /// No description provided for @seriesEmptyTitle.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Serien'**
  String get seriesEmptyTitle;

  /// No description provided for @mediaEmptyBody.
  ///
  /// In de, this message translates to:
  /// **'Sobald deine Quelle geladen ist, findest du hier alles übersichtlich sortiert.'**
  String get mediaEmptyBody;

  /// No description provided for @searchHint.
  ///
  /// In de, this message translates to:
  /// **'Sender, Filme, Serien'**
  String get searchHint;

  /// No description provided for @searchEmptyTitle.
  ///
  /// In de, this message translates to:
  /// **'Alles durchsuchen'**
  String get searchEmptyTitle;

  /// No description provided for @searchEmptyBody.
  ///
  /// In de, this message translates to:
  /// **'Finde Sender, Filme und Serien aus all deinen Quellen.'**
  String get searchEmptyBody;

  /// No description provided for @profileSources.
  ///
  /// In de, this message translates to:
  /// **'Quellen verwalten'**
  String get profileSources;

  /// No description provided for @settings.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen'**
  String get settings;

  /// No description provided for @switchSource.
  ///
  /// In de, this message translates to:
  /// **'Quelle wechseln'**
  String get switchSource;

  /// No description provided for @addSourceTitle.
  ///
  /// In de, this message translates to:
  /// **'Quelle hinzufügen'**
  String get addSourceTitle;

  /// No description provided for @addSourceSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Wie möchtest du dich verbinden?'**
  String get addSourceSubtitle;

  /// No description provided for @typeXtream.
  ///
  /// In de, this message translates to:
  /// **'Xtream Codes'**
  String get typeXtream;

  /// No description provided for @typeXtreamDesc.
  ///
  /// In de, this message translates to:
  /// **'Server, Benutzername und Passwort'**
  String get typeXtreamDesc;

  /// No description provided for @typeM3uUrl.
  ///
  /// In de, this message translates to:
  /// **'M3U-Link'**
  String get typeM3uUrl;

  /// No description provided for @typeM3uUrlDesc.
  ///
  /// In de, this message translates to:
  /// **'Playlist-Adresse, optional mit EPG'**
  String get typeM3uUrlDesc;

  /// No description provided for @typeM3uFile.
  ///
  /// In de, this message translates to:
  /// **'M3U-Datei'**
  String get typeM3uFile;

  /// No description provided for @typeM3uFileDesc.
  ///
  /// In de, this message translates to:
  /// **'Playlist-Datei von diesem Gerät'**
  String get typeM3uFileDesc;

  /// No description provided for @fieldName.
  ///
  /// In de, this message translates to:
  /// **'Name'**
  String get fieldName;

  /// No description provided for @fieldNameHint.
  ///
  /// In de, this message translates to:
  /// **'z. B. Wohnzimmer'**
  String get fieldNameHint;

  /// No description provided for @fieldServer.
  ///
  /// In de, this message translates to:
  /// **'Server-Adresse'**
  String get fieldServer;

  /// No description provided for @fieldServerHint.
  ///
  /// In de, this message translates to:
  /// **'http://server.beispiel:8080'**
  String get fieldServerHint;

  /// No description provided for @fieldUsername.
  ///
  /// In de, this message translates to:
  /// **'Benutzername'**
  String get fieldUsername;

  /// No description provided for @fieldPassword.
  ///
  /// In de, this message translates to:
  /// **'Passwort'**
  String get fieldPassword;

  /// No description provided for @fieldPlaylistUrl.
  ///
  /// In de, this message translates to:
  /// **'Playlist-Adresse'**
  String get fieldPlaylistUrl;

  /// No description provided for @fieldPlaylistUrlHint.
  ///
  /// In de, this message translates to:
  /// **'https://…/playlist.m3u'**
  String get fieldPlaylistUrlHint;

  /// No description provided for @fieldEpgUrl.
  ///
  /// In de, this message translates to:
  /// **'EPG-Adresse (optional)'**
  String get fieldEpgUrl;

  /// No description provided for @fieldEpgUrlHelper.
  ///
  /// In de, this message translates to:
  /// **'XMLTV-Programmdaten für den Programmführer.'**
  String get fieldEpgUrlHelper;

  /// No description provided for @fieldFile.
  ///
  /// In de, this message translates to:
  /// **'Playlist-Datei'**
  String get fieldFile;

  /// No description provided for @chooseFile.
  ///
  /// In de, this message translates to:
  /// **'Datei auswählen'**
  String get chooseFile;

  /// No description provided for @changeFile.
  ///
  /// In de, this message translates to:
  /// **'Andere Datei wählen'**
  String get changeFile;

  /// No description provided for @errRequired.
  ///
  /// In de, this message translates to:
  /// **'Bitte ausfüllen.'**
  String get errRequired;

  /// No description provided for @errUrlInvalid.
  ///
  /// In de, this message translates to:
  /// **'Das sieht nicht nach einer gültigen Adresse aus. Beispiel: http://server:8080'**
  String get errUrlInvalid;

  /// No description provided for @errUrlScheme.
  ///
  /// In de, this message translates to:
  /// **'Die Adresse muss mit http:// oder https:// beginnen.'**
  String get errUrlScheme;

  /// No description provided for @errPort.
  ///
  /// In de, this message translates to:
  /// **'Der Port muss zwischen 1 und 65535 liegen.'**
  String get errPort;

  /// No description provided for @errFileRequired.
  ///
  /// In de, this message translates to:
  /// **'Bitte wähle eine Playlist-Datei aus.'**
  String get errFileRequired;

  /// No description provided for @errFileRead.
  ///
  /// In de, this message translates to:
  /// **'Die Datei konnte nicht gelesen werden.'**
  String get errFileRead;

  /// No description provided for @sourceSaved.
  ///
  /// In de, this message translates to:
  /// **'Quelle gespeichert'**
  String get sourceSaved;

  /// No description provided for @sourceSaveFailed.
  ///
  /// In de, this message translates to:
  /// **'Die Quelle konnte nicht gespeichert werden. Bitte versuche es erneut.'**
  String get sourceSaveFailed;

  /// No description provided for @editSourceTitle.
  ///
  /// In de, this message translates to:
  /// **'Quelle bearbeiten'**
  String get editSourceTitle;

  /// No description provided for @sourcesTitle.
  ///
  /// In de, this message translates to:
  /// **'Quellen'**
  String get sourcesTitle;

  /// No description provided for @sourceDefault.
  ///
  /// In de, this message translates to:
  /// **'Standard'**
  String get sourceDefault;

  /// No description provided for @setAsDefault.
  ///
  /// In de, this message translates to:
  /// **'Als Standard festlegen'**
  String get setAsDefault;

  /// No description provided for @deleteSourceTitle.
  ///
  /// In de, this message translates to:
  /// **'Quelle löschen?'**
  String get deleteSourceTitle;

  /// No description provided for @deleteSourceBody.
  ///
  /// In de, this message translates to:
  /// **'„{name}“ und alle zugehörigen Favoriten und Verläufe werden von diesem Gerät entfernt.'**
  String deleteSourceBody(String name);

  /// No description provided for @sourceDeleted.
  ///
  /// In de, this message translates to:
  /// **'Quelle gelöscht'**
  String get sourceDeleted;

  /// No description provided for @settingsGeneral.
  ///
  /// In de, this message translates to:
  /// **'Allgemein'**
  String get settingsGeneral;

  /// No description provided for @settingsLanguage.
  ///
  /// In de, this message translates to:
  /// **'Sprache'**
  String get settingsLanguage;

  /// No description provided for @languageSystem.
  ///
  /// In de, this message translates to:
  /// **'Systemsprache'**
  String get languageSystem;

  /// No description provided for @settingsHaptics.
  ///
  /// In de, this message translates to:
  /// **'Haptisches Feedback'**
  String get settingsHaptics;

  /// No description provided for @settingsAppearance.
  ///
  /// In de, this message translates to:
  /// **'Aussehen'**
  String get settingsAppearance;

  /// No description provided for @themeSystem.
  ///
  /// In de, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In de, this message translates to:
  /// **'Hell'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In de, this message translates to:
  /// **'Dunkel'**
  String get themeDark;

  /// No description provided for @settingsAccent.
  ///
  /// In de, this message translates to:
  /// **'Akzentfarbe'**
  String get settingsAccent;

  /// No description provided for @accentBlue.
  ///
  /// In de, this message translates to:
  /// **'Blau'**
  String get accentBlue;

  /// No description provided for @accentGreen.
  ///
  /// In de, this message translates to:
  /// **'Grün'**
  String get accentGreen;

  /// No description provided for @accentMint.
  ///
  /// In de, this message translates to:
  /// **'Mint'**
  String get accentMint;

  /// No description provided for @accentOrange.
  ///
  /// In de, this message translates to:
  /// **'Orange'**
  String get accentOrange;

  /// No description provided for @accentPurple.
  ///
  /// In de, this message translates to:
  /// **'Lila'**
  String get accentPurple;

  /// No description provided for @accentGraphite.
  ///
  /// In de, this message translates to:
  /// **'Graphit'**
  String get accentGraphite;

  /// No description provided for @settingsInfo.
  ///
  /// In de, this message translates to:
  /// **'Info'**
  String get settingsInfo;

  /// No description provided for @settingsVersion.
  ///
  /// In de, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// No description provided for @settingsPrivacy.
  ///
  /// In de, this message translates to:
  /// **'Datenschutz'**
  String get settingsPrivacy;

  /// No description provided for @settingsLicenses.
  ///
  /// In de, this message translates to:
  /// **'Open-Source-Lizenzen'**
  String get settingsLicenses;

  /// No description provided for @privacySummary.
  ///
  /// In de, this message translates to:
  /// **'Lumen speichert alle Daten ausschließlich auf diesem Gerät. Zugangsdaten werden verschlüsselt im Schlüsselbund (iOS) bzw. Android Keystore abgelegt. Es gibt keine Analyse, kein Tracking, keine Werbung und keine Server des Entwicklers. Die App verbindet sich nur mit den Adressen, die du selbst einträgst.'**
  String get privacySummary;

  /// No description provided for @errNotM3u.
  ///
  /// In de, this message translates to:
  /// **'Diese Datei sieht nicht nach einer M3U-Playlist aus.'**
  String get errNotM3u;

  /// No description provided for @later.
  ///
  /// In de, this message translates to:
  /// **'Später'**
  String get later;

  /// No description provided for @onbStep.
  ///
  /// In de, this message translates to:
  /// **'Schritt {current} von {total}'**
  String onbStep(int current, int total);

  /// No description provided for @contentNoticeShort.
  ///
  /// In de, this message translates to:
  /// **'Lumen enthält keine Inhalte'**
  String get contentNoticeShort;

  /// No description provided for @close.
  ///
  /// In de, this message translates to:
  /// **'Schließen'**
  String get close;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
