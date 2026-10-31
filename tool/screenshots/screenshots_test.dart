// Erzeugt Vorschau-Bilder der echten App-Oberfläche mit erfundenen Daten.
//
//   flutter test tool/screenshots --update-goldens
//
// Die Bilder landen in tool/screenshots/out/. Alle Sender, Sendungen und
// Namen sind frei erfunden. Das „Videobild“ im Player ist ein Platzhalter.
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/app/providers.dart';
import 'package:lumen/core/db/database.dart';
import 'package:lumen/core/platform/device_profile.dart';
import 'package:lumen/features/live/data/live_repository.dart';
import 'package:lumen/features/live/live_providers.dart';
import 'package:lumen/features/player/player_engine.dart';
import 'package:lumen/features/settings/settings.dart';
import 'package:lumen/features/sources/domain/source_profile.dart';

import '../../test/helpers/fake_engine.dart';
import '../../test/helpers/test_app.dart';

Future<void> _loadFonts() async {
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
  // Material-Icons (für den gefüllten Favoriten-Stern) aus dem Flutter-SDK.
  final sdk = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter';
  final material = File('$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (material.existsSync()) {
    final l = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(material.readAsBytesSync())));
    await l.load();
  }
  const pkg = 'packages/lucide_icons_flutter';
  await load('$pkg/Lucide', ['$pkg/assets/lucide.ttf']);
  for (final w in [300, 600]) {
    await load('$pkg/Lucide$w', ['$pkg/assets/build_font/LucideVariable-w$w.ttf']);
  }
}

/// Motor, der statt Video einen ruhigen Farbverlauf zeigt.
class _PreviewEngine extends FakeEngine {
  @override
  Widget buildView(VideoFit fit) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B2A4A), Color(0xFF1B4F72), Color(0xFF0E3B2E)],
          ),
        ),
      );
}

const _channels = [
  ('Aurora Eins', 'nachrichten'),
  ('Kanal Nord', 'nachrichten'),
  ('Morgenrot', 'nachrichten'),
  ('Weitblick Doku', 'doku'),
  ('Spielfeld HD', 'sport'),
  ('Taktwerk Musik', 'musik'),
  ('Kleine Welt', 'kinder'),
  ('Lichtspiel', 'doku'),
  ('Ostwind TV', 'nachrichten'),
  ('Panorama Plus', 'doku'),
];

const _shows = [
  'Tagesrückblick',
  'Wetter am Abend',
  'Die Welt der Ozeane',
  'Gespräch am Kamin',
  'Sport kompakt',
  'Nachtkonzert',
  'Abenteuer im Garten',
  'Reise durch die Alpen',
  'Wissen um acht',
  'Kurzfilmnacht',
];

Future<void> _seed(WidgetTester tester, TestHarness h) async {
  await tester.runAsync(() async {
    final p = await h.container.read(sourcesRepositoryProvider).add(
          name: 'Wohnzimmer',
          type: SourceType.xtream,
          serverUrl: 'http://mein-server.example:8080',
          credentials: const SourceCredentials(username: 'demo', password: 'demo'),
        );
    final db = h.db;
    final now = DateTime.now().toUtc();
    final base = DateTime.utc(now.year, now.month, now.day, now.hour);
    await db.batch((b) {
      for (final (i, c) in const ['nachrichten', 'doku', 'sport', 'musik', 'kinder'].indexed) {
        b.insert(
            db.categories,
            CategoriesCompanion.insert(
                profileId: p.id,
                kind: ContentKind.live,
                remoteId: c,
                name: const ['Nachrichten', 'Dokumentation', 'Sport', 'Musik', 'Kinder'][i],
                sortIndex: i + 1));
      }
      for (final (i, (name, cat)) in _channels.indexed) {
        b.insert(
            db.channels,
            ChannelsCompanion.insert(
              profileId: p.id,
              itemKey: 'c$i',
              num: Value(i + 1),
              name: name,
              categoryId: Value(cat),
              epgChannelId: Value('ch$i'),
              sortIndex: i,
            ));
        for (var s = -2; s < 6; s++) {
          final start = base.add(Duration(minutes: s * 45 + i * 7));
          b.insert(
              db.epgPrograms,
              EpgProgramsCompanion.insert(
                profileId: p.id,
                channelId: 'ch$i',
                startUtc: start,
                endUtc: start.add(const Duration(minutes: 45)),
                title: _shows[(i + s + 10) % _shows.length],
                description: const Value(
                    'Eine ruhige, erfundene Sendung – nur als Beispiel für die Vorschau von Lumen.'),
                category: const Value('Magazin'),
              ));
        }
      }
      for (var i = 0; i < 120; i++) {
        b.insert(db.vodItems, VodItemsCompanion.insert(profileId: p.id, itemKey: 'v$i', name: 'Film $i', sortIndex: i));
      }
      for (var i = 0; i < 24; i++) {
        b.insert(db.seriesItems,
            SeriesItemsCompanion.insert(profileId: p.id, itemKey: 's$i', name: 'Serie $i', sortIndex: i));
      }
      b.insert(
          db.accountInfos,
          AccountInfosCompanion.insert(
            profileId: p.id,
            status: const Value('Active'),
            expiresAt: Value(DateTime.utc(2027, 6, 30)),
            createdAt: Value(DateTime.utc(2025, 2, 1)),
            activeConnections: const Value(1),
            maxConnections: const Value(2),
            fetchedAt: now,
          ));
    });
    await (db.update(db.profiles)).write(ProfilesCompanion(lastSyncAt: Value(DateTime.now())));
    for (final k in ['c1', 'c4', 'c0']) {
      await db.into(db.favorites).insert(FavoritesCompanion.insert(
          profileId: p.id, kind: ContentKind.live, itemKey: k, sortIndex: int.parse(k.substring(1)), addedAt: now));
    }
  });
}

Future<void> _shot(WidgetTester tester, String name) async {
  await settle(tester);
  await settle(tester);
  await expectLater(find.byType(MaterialApp).first, matchesGoldenFile('out/$name.png'));
}

Future<TestHarness> _start(WidgetTester tester, {
  AppSettings settings = const AppSettings(onboardingDone: true, localeCode: 'de', autoRefresh: false),
  DeviceProfile device = const DeviceProfile(),
  Size size = const Size(390, 844),
  bool seed = true,
}) async {
  final h = TestHarness(settings: settings, device: device);
  h.engines
    ..clear()
    ..add(_PreviewEngine());
  if (seed) await _seed(tester, h);
  await h.pump(tester, size: size);
  // pump() setzt devicePixelRatio 3; für kleinere Dateien auf 2 reduzieren.
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = size * 2;
  await settle(tester);
  return h;
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('01 Onboarding', (tester) async {
    await _start(tester, seed: false, settings: const AppSettings(localeCode: 'de'));
    await _shot(tester, '01-onboarding');
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-confirm')));
    await _shot(tester, '02-hinweis');
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await _shot(tester, '03-quelle-hinzufuegen');
    await tester.tap(find.byKey(const Key('add-xtream')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-source')));
    await _shot(tester, '04-formular');
  });

  testWidgets('05 Start', (tester) async {
    await _start(tester);
    await _shot(tester, '05-start');
  });

  testWidgets('06 Live + Programm', (tester) async {
    final h = await _start(tester);
    await tester.tap(find.text('Live'));
    await _shot(tester, '06-live-favoriten');
    h.container.read(selectedLiveFilterProvider.notifier).select(const CategoryChannels('nachrichten'));
    await _shot(tester, '07-live-kategorie');
    await tester.tap(find.byKey(const Key('open-guide')));
    await _shot(tester, '08-programmfuehrer');
    await tester.tap(find.textContaining('Sport kompakt').first);
    await _shot(tester, '09-sendung');
  });

  testWidgets('10 Player', (tester) async {
    await _start(tester, size: const Size(844, 390));
    await tester.tap(find.text('Live'));
    await settle(tester);
    await tester.tap(find.text('Kanal Nord'));
    await settle(tester);
    await settle(tester);
    await _shot(tester, '10-player');
  });

  testWidgets('11 Profil + Einstellungen', (tester) async {
    await _start(tester);
    await tester.tap(find.text('Profil'));
    await _shot(tester, '11-profil');
    await tester.tap(find.byKey(const Key('profile-settings')));
    await _shot(tester, '12-einstellungen');
  });

  testWidgets('13 Hell', (tester) async {
    await _start(tester,
        settings: const AppSettings(onboardingDone: true, localeCode: 'de', autoRefresh: false, themeMode: ThemeMode.light));
    await tester.tap(find.text('Live'));
    await _shot(tester, '13-hell');
  });

  testWidgets('14 TV', (tester) async {
    await _start(tester, device: const DeviceProfile(isTv: true), size: const Size(1280, 720));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await _shot(tester, '14-tv-live');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await _shot(tester, '15-tv-seitenleiste');
  });
}
