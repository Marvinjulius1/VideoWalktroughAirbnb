import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/db/database.dart';
import '../../core/design/haptics.dart';
import '../../core/design/tokens.dart';
import '../sources/data/xtream/xtream_client.dart' show StreamFormat;

/// Alle App-Einstellungen in einem unveränderlichen Objekt.
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.dark,
    this.accent = LumenAccent.blue,
    this.localeCode,
    this.haptics = true,
    this.onboardingDone = false,
    this.autoRefresh = true,
    this.liveFormat = StreamFormat.ts,
    this.epgOffsetMinutes = 0,
  });

  /// Standard ist Dunkel (Design-Vorgabe), nicht System.
  final ThemeMode themeMode;
  final LumenAccent accent;

  /// `null` = Systemsprache.
  final String? localeCode;
  final bool haptics;
  final bool onboardingDone;

  /// Aktive Quelle beim Start automatisch neu laden, wenn sie veraltet ist.
  final bool autoRefresh;

  /// Bevorzugtes Format für Live-Streams bei Xtream (`.ts` oder `.m3u8`).
  final StreamFormat liveFormat;

  /// Korrektur für falsch verschobene EPG-Zeiten (in Minuten).
  final int epgOffsetMinutes;

  Duration get epgOffset => Duration(minutes: epgOffsetMinutes);

  Locale? get locale => localeCode == null ? null : Locale(localeCode!);

  AppSettings copyWith({
    ThemeMode? themeMode,
    LumenAccent? accent,
    String? Function()? localeCode,
    bool? haptics,
    bool? onboardingDone,
    bool? autoRefresh,
    StreamFormat? liveFormat,
    int? epgOffsetMinutes,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        accent: accent ?? this.accent,
        localeCode: localeCode != null ? localeCode() : this.localeCode,
        haptics: haptics ?? this.haptics,
        onboardingDone: onboardingDone ?? this.onboardingDone,
        autoRefresh: autoRefresh ?? this.autoRefresh,
        liveFormat: liveFormat ?? this.liveFormat,
        epgOffsetMinutes: epgOffsetMinutes ?? this.epgOffsetMinutes,
      );

  Map<String, String> toEntries() => {
        'theme_mode': themeMode.name,
        'accent': accent.name,
        'locale': localeCode ?? '',
        'haptics': '$haptics',
        'onboarding_done': '$onboardingDone',
        'auto_refresh': '$autoRefresh',
        'live_format': liveFormat.name,
        'epg_offset': '$epgOffsetMinutes',
      };

  factory AppSettings.fromEntries(Map<String, String> e) => AppSettings(
        themeMode: ThemeMode.values.firstWhere(
          (m) => m.name == e['theme_mode'],
          orElse: () => ThemeMode.dark,
        ),
        accent: LumenAccent.fromName(e['accent']),
        localeCode: (e['locale']?.isEmpty ?? true) ? null : e['locale'],
        haptics: e['haptics'] != 'false',
        onboardingDone: e['onboarding_done'] == 'true',
        autoRefresh: e['auto_refresh'] != 'false',
        liveFormat: e['live_format'] == 'm3u8' ? StreamFormat.m3u8 : StreamFormat.ts,
        epgOffsetMinutes: int.tryParse(e['epg_offset'] ?? '')?.clamp(-720, 720) ?? 0,
      );
}

class SettingsRepository {
  SettingsRepository(this._db);

  final LumenDatabase _db;

  Future<AppSettings> load() async {
    final rows = await _db.select(_db.settings).get();
    return AppSettings.fromEntries({for (final r in rows) r.key: r.value});
  }

  Future<void> save(AppSettings s) => _db.batch((b) {
        b.insertAllOnConflictUpdate(
          _db.settings,
          [
            for (final e in s.toEntries().entries)
              SettingsCompanion.insert(key: e.key, value: e.value),
          ],
        );
      });
}

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);

/// Beim Start geladene Einstellungen (in `main` überschrieben), damit die
/// App ohne Flackern direkt im richtigen Modus startet.
final initialSettingsProvider =
    Provider<AppSettings>((ref) => const AppSettings());

final settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final s = ref.watch(initialSettingsProvider);
    LumenHaptics.enabled = s.haptics;
    return s;
  }

  Future<void> _set(AppSettings s) async {
    state = s;
    LumenHaptics.enabled = s.haptics;
    await ref.read(settingsRepositoryProvider).save(s);
  }

  Future<void> setThemeMode(ThemeMode m) => _set(state.copyWith(themeMode: m));
  Future<void> setAccent(LumenAccent a) => _set(state.copyWith(accent: a));
  Future<void> setLocale(String? code) =>
      _set(state.copyWith(localeCode: () => code));
  Future<void> setHaptics(bool v) => _set(state.copyWith(haptics: v));
  Future<void> setEpgOffset(int minutes) =>
      _set(state.copyWith(epgOffsetMinutes: minutes.clamp(-720, 720)));
  Future<void> setLiveFormat(StreamFormat f) => _set(state.copyWith(liveFormat: f));
  Future<void> setAutoRefresh(bool v) => _set(state.copyWith(autoRefresh: v));
  Future<void> completeOnboarding() =>
      _set(state.copyWith(onboardingDone: true));
}
