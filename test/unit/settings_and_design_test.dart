import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/core/design/tokens.dart';
import 'package:lumen/features/home/home_screen.dart';
import 'package:lumen/core/l10n/app_localizations_de.dart';
import 'package:lumen/features/settings/settings.dart';
import 'package:lumen/features/sources/data/playlist_file_store.dart';

import '../helpers/test_app.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('Einstellungen', () {
    test('Standard: Dunkel, Blau, Systemsprache, Onboarding offen', () {
      const s = AppSettings();
      expect(s.themeMode, ThemeMode.dark);
      expect(s.accent, LumenAccent.blue);
      expect(s.locale, isNull);
      expect(s.onboardingDone, isFalse);
    });

    test('werden in der Datenbank gespeichert und wieder geladen', () async {
      final db = memoryDb();
      addTearDown(db.close);
      final repo = SettingsRepository(db);
      const s = AppSettings(
        themeMode: ThemeMode.light,
        accent: LumenAccent.purple,
        localeCode: 'en',
        haptics: false,
        onboardingDone: true,
      );
      await repo.save(s);
      final loaded = await repo.load();
      expect(loaded.themeMode, ThemeMode.light);
      expect(loaded.accent, LumenAccent.purple);
      expect(loaded.localeCode, 'en');
      expect(loaded.haptics, isFalse);
      expect(loaded.onboardingDone, isTrue);

      await repo.save(loaded.copyWith(localeCode: () => null));
      expect((await repo.load()).localeCode, isNull);
    });

    test('unbekannte Werte fallen auf Standard zurück', () {
      final s = AppSettings.fromEntries({'theme_mode': 'quatsch', 'accent': 'pink'});
      expect(s.themeMode, ThemeMode.dark);
      expect(s.accent, LumenAccent.blue);
    });
  });

  group('Kontrast (WCAG AA ≥ 4,5 : 1)', () {
    for (final p in [LumenPalette.dark, LumenPalette.light]) {
      final mode = p.brightness.name;
      for (final (name, surface) in [
        ('bg', p.bg),
        ('surface1', p.surface1),
        ('surface2', p.surface2),
        ('surface3', p.surface3),
      ]) {
        test('$mode: Primär- und Sekundärtext auf $name', () {
          expect(contrast(p.textPrimary, surface), greaterThanOrEqualTo(4.5));
          expect(contrast(p.textSecondary, surface), greaterThanOrEqualTo(4.5));
        });
      }
      test('$mode: Fehler-/Live-Rot auf Hintergrund (≥ 3 : 1 für große Schrift/Grafik)', () {
        expect(contrast(p.error, p.bg), greaterThanOrEqualTo(3.0));
      });
    }

    for (final a in LumenAccent.values) {
      for (final b in Brightness.values) {
        test('Akzent ${a.name} (${b.name}): Buttontext lesbar', () {
          expect(contrast(a.onAccent(b), a.resolve(b)), greaterThanOrEqualTo(3.0));
        });
      }
    }
  });

  group('Begrüßung', () {
    final t = AppLocalizationsDe();
    test('nach Tageszeit', () {
      expect(greetingFor(DateTime(2026, 1, 1, 7), t), 'Guten Morgen');
      expect(greetingFor(DateTime(2026, 1, 1, 14), t), 'Guten Tag');
      expect(greetingFor(DateTime(2026, 1, 1, 20), t), 'Guten Abend');
      expect(greetingFor(DateTime(2026, 1, 1, 2), t), 'Gute Nacht');
    });
  });

  group('PlaylistFileStore', () {
    late Directory dir;
    late PlaylistFileStore store;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('lumen');
      store = PlaylistFileStore(baseDir: () async => dir);
    });
    tearDown(() => dir.delete(recursive: true));

    test('kopiert gültige M3U-Dateien (auch mit BOM)', () async {
      final src = File('${dir.path}/in.m3u')
        ..writeAsStringSync('﻿#EXTM3U\n#EXTINF:-1,Testkanal\nhttp://localhost/1.ts\n');
      final copied = await store.import(src.path);
      expect(File(copied).readAsStringSync(), contains('Testkanal'));
      expect(copied, contains('playlists'));
    });

    test('lehnt Nicht-M3U-Dateien ab', () async {
      final src = File('${dir.path}/x.txt')..writeAsStringSync('hallo welt');
      expect(
        () => store.import(src.path),
        throwsA(isA<PlaylistImportException>()
            .having((e) => e.error, 'error', PlaylistImportError.notM3u)),
      );
    });

    test('meldet unlesbare Dateien', () async {
      expect(
        () => store.import('${dir.path}/fehlt.m3u'),
        throwsA(isA<PlaylistImportException>()
            .having((e) => e.error, 'error', PlaylistImportError.unreadable)),
      );
    });
  });
}
