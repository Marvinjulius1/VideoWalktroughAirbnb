import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/app/providers.dart';
import 'package:lumen/core/db/database.dart';
import 'package:lumen/core/platform/device_profile.dart';
import 'package:lumen/features/player/player_engine.dart';
import 'package:lumen/features/sources/domain/source_profile.dart';

import '../helpers/test_app.dart';

/// Legt eine M3U-Quelle mit zwei Kategorien und fünf Sendern an.
Future<String> seed(WidgetTester tester, TestHarness h) async {
  return (await tester.runAsync(() async {
    final p = await h.container.read(sourcesRepositoryProvider).add(
          name: 'Testquelle',
          type: SourceType.m3uUrl,
          credentials: const SourceCredentials(playlistUrl: 'http://localhost/x.m3u'),
        );
    final db = h.db;
    await db.batch((b) {
      b.insertAll(db.categories, [
        CategoriesCompanion.insert(profileId: p.id, kind: ContentKind.live, remoteId: 'n', name: 'Nachrichten', sortIndex: 0),
        CategoriesCompanion.insert(profileId: p.id, kind: ContentKind.live, remoteId: 's', name: 'Sport', sortIndex: 1),
      ]);
      b.insertAll(db.channels, [
        for (var i = 1; i <= 5; i++)
          ChannelsCompanion.insert(
            profileId: p.id,
            itemKey: 'k$i',
            num: Value(i),
            name: 'Testkanal $i',
            categoryId: Value(i <= 3 ? 'n' : 's'),
            url: Value('http://localhost/live/$i.ts'),
            sortIndex: i,
          ),
      ]);
    });
    return p.id;
  }))!;
}

void main() {
  testWidgets('Live: Kategorien, Sender, Favorit setzen', (tester) async {
    final h = TestHarness();
    await seed(tester, h);
    await h.pump(tester);
    await settle(tester);
    await tester.tap(find.text('Live'));
    await settle(tester);

    // Ohne Favoriten startet die erste Kategorie.
    expect(find.text('Testkanal 1'), findsOneWidget);
    expect(find.text('Testkanal 4'), findsNothing);

    // „Sport“ liegt rechts außerhalb der Chip-Leiste.
    await tester.dragUntilVisible(
        find.text('Sport'), find.byKey(const Key('live-filters')), const Offset(-150, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sport'));
    await settle(tester);
    expect(find.text('Testkanal 4'), findsOneWidget);
    expect(find.text('Testkanal 1'), findsNothing);

    // Stern → Favorit; Favoriten-Filter zeigt ihn.
    final fav = find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('fav-'));
    await tester.tap(fav.first);
    await settle(tester);
    await tester.dragUntilVisible(
        find.text('Favoriten'), find.byKey(const Key('live-filters')), const Offset(150, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favoriten'));
    await settle(tester);
    expect(find.text('Testkanal 4'), findsOneWidget);
    expect(find.text('Testkanal 5'), findsNothing);

    await tester.tap(find.text('Zuletzt gesehen'));
    await settle(tester);
    expect(find.text('Noch nichts gesehen'), findsOneWidget);
  });

  testWidgets('Player: öffnet Sender, Overlay, Umschalten per Taste, Verlauf', (tester) async {
    final h = TestHarness();
    final pid = await seed(tester, h);
    await h.pump(tester);
    await settle(tester);
    await tester.tap(find.text('Live'));
    await settle(tester);

    await tester.tap(find.text('Testkanal 2'));
    await settle(tester);

    expect(find.byKey(const Key('player-channel-name')), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);
    expect(h.engine.opened.single.uri.toString(), 'http://localhost/live/2.ts');

    // Overlay blendet sich nach 4 s aus.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    final opacity = tester.widget<AnimatedOpacity>(find.ancestor(
        of: find.byKey(const Key('player-channel-name')), matching: find.byType(AnimatedOpacity)));
    expect(opacity.opacity, 0);

    // Runter = nächster Sender (nach kurzer Verzögerung geöffnet).
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 400));
    await settle(tester);
    expect(h.engine.opened.last.uri.toString(), 'http://localhost/live/3.ts');
    expect(find.text('Testkanal 3'), findsOneWidget);

    // Verlauf wurde geschrieben.
    final history = (await tester.runAsync(() => h.db.select(h.db.watchHistory).get()))!;
    expect(history.map((r) => r.itemKey).toSet(), {'k2', 'k3'});
    expect(history.first.profileId, pid);

    // Overlay ist nach dem Umschalten sichtbar → Pause antippen.
    await tester.tap(find.byKey(const Key('player-playpause')));
    await tester.pumpAndSettle();
    expect(h.engine.currentPhase, PlaybackPhase.paused);

    // Schließen.
    await tester.tap(find.byTooltip('Schließen'));
    await settle(tester);
    expect(find.byKey(const Key('player-channel-name')), findsNothing);
    expect(h.engine.disposed, isTrue);
  });

  testWidgets('Player: dauerhafter Fehler zeigt verständliche Meldung', (tester) async {
    final h = TestHarness();
    await seed(tester, h);
    h.engine.afterOpen = PlaybackPhase.error;
    await h.pump(tester);
    await settle(tester);
    await tester.tap(find.text('Live'));
    await settle(tester);
    await tester.tap(find.text('Testkanal 1'));
    // Kein pumpAndSettle: der Lade-Spinner dreht endlos.
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('player-reconnecting')), findsOneWidget);

    // Alle automatischen Versuche (1 s, 3 s, 6 s) laufen ab.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('player-failed')), findsOneWidget);
    expect(find.text('Wiedergabe nicht möglich'), findsOneWidget);
    expect(h.engine.opened, hasLength(4));

    h.engine.afterOpen = PlaybackPhase.playing;
    await tester.tap(find.text('Erneut versuchen'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('player-failed')), findsNothing);
    expect(h.engine.currentPhase, PlaybackPhase.playing);
  });

  testWidgets('Player: Ton, Untertitel und Bild', (tester) async {
    final h = TestHarness();
    await seed(tester, h);
    await h.pump(tester);
    await settle(tester);
    await tester.tap(find.text('Live'));
    await settle(tester);
    await tester.tap(find.text('Testkanal 1'));
    await settle(tester);
    h.engine.emitTracks(
      const [TrackInfo(id: '1', language: 'deu'), TrackInfo(id: '2', title: 'Original', language: 'eng')],
      const [TrackInfo(id: '5', language: 'deu')],
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('player-options')));
    await tester.pumpAndSettle();
    expect(find.text('DEU'), findsWidgets);
    await tester.tap(find.text('Original · ENG'));
    await tester.pump();
    expect(h.engine.audioId, '2');

    await tester.tap(find.byKey(const Key('fit-zoom')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10)); // Sheet schließen
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fake-video-zoom')), findsOneWidget);
  });

  testWidgets('TV: Zifferneingabe springt zum Sender', (tester) async {
    final h = TestHarness(device: const DeviceProfile(isTv: true));
    await seed(tester, h);
    await h.pump(tester, size: const Size(1920, 1080));
    await settle(tester);
    // Über die Seitenleiste zu „Live“.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await settle(tester);
    await tester.tap(find.text('Testkanal 1'));
    await settle(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.pump();
    expect(find.byKey(const Key('player-digits')), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);
    expect(h.engine.opened.last.uri.toString(), 'http://localhost/live/3.ts');
  });
}
