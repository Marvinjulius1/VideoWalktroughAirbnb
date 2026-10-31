import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/app/providers.dart';
import 'package:lumen/core/db/database.dart';
import 'package:lumen/features/sources/domain/source_profile.dart';

import '../helpers/test_app.dart';

/// Quelle mit 3 Sendern und Programm: je Sender eine laufende und zwei
/// kommende Sendungen.
Future<void> seedWithEpg(WidgetTester tester, TestHarness h) async {
  await tester.runAsync(() async {
    final p = await h.container.read(sourcesRepositoryProvider).add(
          name: 'Testquelle',
          type: SourceType.m3uUrl,
          credentials: const SourceCredentials(playlistUrl: 'http://localhost/x.m3u'),
        );
    final db = h.db;
    final now = DateTime.now().toUtc();
    final start = now.subtract(const Duration(minutes: 30));
    await db.batch((b) {
      b.insert(db.categories,
          CategoriesCompanion.insert(profileId: p.id, kind: ContentKind.live, remoteId: 'n', name: 'Nachrichten', sortIndex: 0));
      for (var i = 1; i <= 3; i++) {
        b.insert(
          db.channels,
          ChannelsCompanion.insert(
            profileId: p.id,
            itemKey: 'k$i',
            num: Value(i),
            name: 'Testkanal $i',
            categoryId: const Value('n'),
            epgChannelId: Value('test$i.de'),
            url: Value('http://localhost/live/$i.ts'),
            sortIndex: i,
          ),
        );
        for (var s = 0; s < 3; s++) {
          b.insert(
            db.epgPrograms,
            EpgProgramsCompanion.insert(
              profileId: p.id,
              channelId: 'test$i.de',
              startUtc: start.add(Duration(hours: s)),
              endUtc: start.add(Duration(hours: s + 1)),
              title: s == 0 ? 'Läuft auf $i' : 'Später $s auf $i',
              description: const Value('Eine erfundene Sendung.'),
            ),
          );
        }
      }
    });
  });
}

void main() {
  testWidgets('Live-Liste zeigt die laufende Sendung', (tester) async {
    final h = TestHarness();
    await seedWithEpg(tester, h);
    await h.pump(tester);
    await settle(tester);
    await tester.tap(find.text('Live'));
    await settle(tester);
    await settle(tester);
    expect(find.text('Läuft auf 1'), findsOneWidget);
  });

  testWidgets('Programmführer: Raster, Details, Erinnerung', (tester) async {
    final h = TestHarness();
    await seedWithEpg(tester, h);
    await h.pump(tester, size: const Size(1024, 1366));
    await settle(tester);
    await tester.tap(find.text('Live'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('open-guide')));
    await settle(tester);
    await settle(tester);

    expect(find.text('Programmführer'), findsOneWidget);
    expect(find.byKey(const Key('guide-now-line')), findsOneWidget);
    expect(find.text('Läuft auf 2'), findsOneWidget);

    // Kommende Sendung → Erinnern.
    await tester.tap(find.text('Später 1 auf 1'));
    await settle(tester);
    expect(find.text('Eine erfundene Sendung.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('programme-remind')));
    await settle(tester);
    expect(h.scheduler.scheduled, hasLength(1));
    expect(find.text('Erinnerung aktiv'), findsWidgets);
    await tester.tapAt(const Offset(20, 20));
    // Hinweis-Meldung („Erinnerung aktiv“) ausblenden lassen.
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);

    // Laufende Sendung → Ansehen öffnet den Player.
    await tester.tap(find.text('Läuft auf 3'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('programme-watch')));
    await settle(tester);
    expect(h.engine.opened.single.uri.toString(), 'http://localhost/live/3.ts');
    expect(find.byKey(const Key('player-epg')), findsOneWidget);
  });

  testWidgets('Programmführer ohne Daten: leerer Zustand', (tester) async {
    final h = TestHarness();
    await tester.runAsync(() async {
      final p = await h.container.read(sourcesRepositoryProvider).add(
          name: 'Q', type: SourceType.m3uUrl, credentials: const SourceCredentials());
      await h.db.into(h.db.channels).insert(
          ChannelsCompanion.insert(profileId: p.id, itemKey: 'k', name: 'Ohne EPG', sortIndex: 0));
    });
    await h.pump(tester);
    await settle(tester);
    await tester.tap(find.text('Live'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('open-guide')));
    await settle(tester);
    expect(find.byKey(const Key('guide-empty')), findsOneWidget);
  });
}
