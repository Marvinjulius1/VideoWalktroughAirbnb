// Erzeugt Vorschau-Bilder der App mit erfundenen Daten.
//
// Aufruf:  flutter test tool/screenshots/screenshots_test.dart --update-goldens
// Ergebnis: docs/screenshots/*.png
//
// Liegt bewusst nicht unter test/: Schriften werden je nach Betriebssystem
// minimal anders gerendert, das würde normale Testläufe rot machen.

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/app/app.dart';
import 'package:lumen/app/providers.dart';
import 'package:lumen/core/db/database.dart';
import 'package:lumen/core/network/source_error.dart';
import 'package:lumen/core/platform/device_profile.dart';
import 'package:lumen/features/settings/settings.dart';
import 'package:lumen/features/sources/domain/source_profile.dart';

import '../../test/helpers/test_app.dart';

Future<void> loadFonts() async {
  Future<void> load(String family, List<String> assets) async {
    final loader = FontLoader(family);
    for (final a in assets) {
      loader.addFont(rootBundle.load(a));
    }
    await loader.load();
  }

  await load('Inter', [
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) 'assets/fonts/inter/Inter-$w.ttf',
  ]);
  await load('MaterialIcons', ['fonts/MaterialIcons-Regular.otf']);
  for (final (fam, file) in [
    ('Lucide', 'assets/lucide.ttf'),
    ('Lucide300', 'assets/build_font/LucideVariable-w300.ttf'),
    ('Lucide600', 'assets/build_font/LucideVariable-w600.ttf'),
  ]) {
    await load('packages/lucide_icons_flutter/$fam', ['packages/lucide_icons_flutter/$file']);
  }
}

const _channelNames = [
  'Lumen Nachrichten', 'Testkanal Eins', 'Sport Arena', 'Natur & Welt', 'Kino Klassik',
  'Kinderzeit', 'Musik Live', 'Doku Plus', 'Regional Nord', 'Wetter 24',
];
const _shows = [
  'Abendnachrichten', 'Natur im Fokus', 'Das große Quiz', 'Fußball: Testliga', 'Klassiker am Abend',
  'Planet Ozean', 'Konzertabend', 'Reise durch Island', 'Kochen mit Zeit', 'Wetter & Wissen',
  'Spätausgabe', 'Krimi: Der Fall Muster', 'Dokumentation: Städte', 'Talk um Zehn',
];

/// Legt eine erfundene Quelle mit Sendern und Programm an.
Future<void> seedDemo(WidgetTester tester, TestHarness h) async {
  await tester.runAsync(() async {
    final p = await h.container.read(sourcesRepositoryProvider).add(
          name: 'Wohnzimmer',
          type: SourceType.xtream,
          serverUrl: 'http://media.example:8080',
          credentials: const SourceCredentials(username: 'demo', password: 'demo'),
        );
    final db = h.db;
    final now = h.now.toUtc();
    final base = DateTime.utc(now.year, now.month, now.day, now.hour).subtract(const Duration(hours: 2));
    await db.batch((b) {
      b.insertAll(db.categories, [
        for (final (i, c) in ['Nachrichten', 'Sport', 'Dokumentation', 'Kinder', 'Musik'].indexed)
          CategoriesCompanion.insert(profileId: p.id, kind: ContentKind.live, remoteId: 'c$i', name: c, sortIndex: i),
      ]);
      b.insertAll(db.channels, [
        for (final (i, n) in _channelNames.indexed)
          ChannelsCompanion.insert(
            profileId: p.id,
            itemKey: '${100 + i}',
            num: Value(i + 1),
            name: n,
            categoryId: const Value('c0'),
            epgChannelId: Value('ch$i'),
            sortIndex: i,
          ),
        for (var i = 0; i < 2390; i++)
          ChannelsCompanion.insert(profileId: p.id, itemKey: 'x$i', name: 'Kanal $i', categoryId: const Value('c1'), sortIndex: 100 + i),
      ]);
      b.insertAll(db.vodItems, [
        for (var i = 0; i < 1240; i++)
          VodItemsCompanion.insert(profileId: p.id, itemKey: 'v$i', name: 'Film $i', sortIndex: i),
      ]);
      b.insertAll(db.seriesItems, [
        for (var i = 0; i < 318; i++)
          SeriesItemsCompanion.insert(profileId: p.id, itemKey: 's$i', name: 'Serie $i', sortIndex: i),
      ]);
      // Programm: je Sender Sendungen von 30–90 Minuten.
      for (var c = 0; c < _channelNames.length; c++) {
        var t = base.subtract(Duration(minutes: c * 13));
        var k = c;
        while (t.isBefore(base.add(const Duration(hours: 30)))) {
          final len = Duration(minutes: [30, 45, 60, 90, 75][k % 5]);
          b.insert(
            db.epgPrograms,
            EpgProgramsCompanion.insert(
              profileId: p.id,
              channelId: 'ch$c',
              startUtc: t,
              endUtc: t.add(len),
              title: _shows[k % _shows.length],
              description: const Value('Eine erfundene Sendung für die Vorschau. Alle Namen und Inhalte sind Beispiele.'),
              category: const Value('Unterhaltung'),
            ),
          );
          t = t.add(len);
          k++;
        }
      }
    });
    await (db.update(db.profiles)).write(ProfilesCompanion(lastSyncAt: Value(h.now.subtract(const Duration(minutes: 8)))));
    await db.into(db.accountInfos).insert(AccountInfosCompanion.insert(
          profileId: p.id,
          status: const Value('Active'),
          expiresAt: Value(DateTime(2027, 6, 30)),
          createdAt: Value(DateTime(2025, 1, 12)),
          activeConnections: const Value(1),
          maxConnections: const Value(2),
          fetchedAt: h.now,
        ));
    for (final k in ['100', '102', '104']) {
      await db.into(db.favorites).insert(FavoritesCompanion.insert(
          profileId: p.id, kind: ContentKind.live, itemKey: k, sortIndex: int.parse(k), addedAt: h.now));
    }
  });
}

Future<void> shot(WidgetTester tester, String name) async {
  await tester.pump(const Duration(milliseconds: 400));
  await expectLater(find.byType(LumenApp), matchesGoldenFile('../../docs/screenshots/$name.png'));
}

Future<void> go(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await settle(tester);
}

void main() {
  setUpAll(loadFonts);
  final evening = DateTime(2026, 10, 31, 20, 40);
  const phone = Size(390, 844);

  testWidgets('01 Onboarding', (tester) async {
    final h = TestHarness(settings: const AppSettings(localeCode: 'de'), now: evening);
    await h.pump(tester, size: phone);
    await shot(tester, '01-onboarding');
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-confirm')));
    await tester.pumpAndSettle();
    await shot(tester, '02-onboarding-hinweis');
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await settle(tester);
    await shot(tester, '03-quelle-hinzufuegen');
  });

  testWidgets('04 Formular mit Fehler', (tester) async {
    final h = TestHarness(now: evening)..connectionError = SourceErrorKind.invalidCredentials;
    await h.pump(tester, size: phone);
    await settle(tester);
    await go(tester, 'Quelle hinzufügen');
    await tester.tap(find.byKey(const Key('add-xtream')));
    await tester.pumpAndSettle();
    Future<void> enter(String key, String v) => tester.enterText(
        find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextFormField)), v);
    await enter('field-name', 'Wohnzimmer');
    await enter('field-server', 'http://media.example:8080');
    await enter('field-username', 'demo');
    await enter('field-password', 'falsch');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('save-source')));
    await tester.tap(find.byKey(const Key('save-source')));
    await settle(tester);
    await tester.dragUntilVisible(find.byKey(const Key('save-anyway')), find.byType(CustomScrollView), const Offset(0, -200));
    await tester.pumpAndSettle();
    await shot(tester, '04-formular-fehler');
  });

  testWidgets('05 Start, Live, Programm, Player, Profil, Einstellungen', (tester) async {
    final h = TestHarness(now: evening);
    await seedDemo(tester, h);
    await h.pump(tester, size: phone);
    await settle(tester);
    await shot(tester, '05-start');

    await go(tester, 'Live');
    await shot(tester, '06-live-favoriten');

    await tester.tap(find.byKey(const Key('open-guide')));
    await settle(tester);
    await shot(tester, '07-programmfuehrer');
    await tester.tap(find.text('Fußball: Testliga').first);
    await tester.pumpAndSettle();
    await shot(tester, '08-sendung');
    await tester.tapAt(const Offset(20, 60));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await settle(tester);

    await tester.tap(find.text('Lumen Nachrichten'));
    await settle(tester);
    await shot(tester, '09-player');
    await tester.tap(find.byTooltip('Schließen'));
    await settle(tester);

    await go(tester, 'Profil');
    await shot(tester, '10-profil');
    await tester.tap(find.byKey(const Key('profile-settings')));
    await settle(tester);
    await shot(tester, '11-einstellungen');
    await tester.pump(const Duration(seconds: 10)); // offene Timer auslaufen lassen
  });

  testWidgets('12 Hell', (tester) async {
    final h = TestHarness(
      now: evening,
      settings: const AppSettings(onboardingDone: true, localeCode: 'de', autoRefresh: false, themeMode: ThemeMode.light),
    );
    await seedDemo(tester, h);
    await h.pump(tester, size: phone);
    await settle(tester);
    await go(tester, 'Live');
    await shot(tester, '12-live-hell');
  });

  testWidgets('13 TV', (tester) async {
    final h = TestHarness(now: evening, device: const DeviceProfile(isTv: true));
    await seedDemo(tester, h);
    await h.pump(tester, size: const Size(1920, 1080));
    await settle(tester);
    await shot(tester, '13-tv-start');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await shot(tester, '14-tv-seitenleiste');
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await shot(tester, '15-tv-live');
  });
}
