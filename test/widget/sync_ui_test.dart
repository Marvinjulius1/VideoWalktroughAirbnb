import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/app/providers.dart';
import 'package:lumen/core/network/http.dart';
import 'package:lumen/features/sources/domain/source_profile.dart';
import 'package:lumen/features/sync/sync_controller.dart';

import '../helpers/test_app.dart';
import '../mock_server/mock_server.dart';

/// Ende-zu-Ende ohne Gerät: echte App-Oberfläche + echter Sync gegen den
/// lokalen Mock-Server (erfundene Daten).
void main() {
  late MockServer server;

  Future<TestHarness> harnessWithSource(WidgetTester tester, {String password = 'geheim'}) async {
    server = (await tester.runAsync(MockServer.start))!;
    addTearDown(() => tester.runAsync(server.close));
    final h = TestHarness()
      ..extraOverrides = [
        dioProvider.overrideWithValue(createSourceDio(retryBaseDelay: const Duration(milliseconds: 5))),
      ];
    await tester.runAsync(() => h.container.read(sourcesRepositoryProvider).add(
          name: 'Testquelle',
          type: SourceType.xtream,
          serverUrl: server.base,
          credentials: SourceCredentials(username: 'demo', password: password),
        ));
    return h;
  }

  Future<void> syncAndWait(WidgetTester tester, TestHarness h) async {
    final profile = (await tester.runAsync(() => h.container.read(sourcesRepositoryProvider).all()))!.first;
    // flutter_test blockiert normalerweise alle HTTP-Anfragen (Antwort 400).
    // Für diesen Test erlauben wir echte Verbindungen – nur zum lokalen
    // Mock-Server.
    await tester.runAsync(() => HttpOverrides.runWithHttpOverrides(
          () => h.container.read(syncControllerProvider.notifier).syncNow(profile),
          _RealHttp(),
        ));
    await settle(tester);
  }

  testWidgets('Aktualisieren zeigt danach die Anzahl der Inhalte und die Kontoinfo', (tester) async {
    final h = await harnessWithSource(tester);
    await h.pump(tester);
    await settle(tester);
    await syncAndWait(tester, h);

    expect(find.text('25 Sender · 12 Filme · 5 Serien'), findsOneWidget);

    await tester.tap(find.text('Profil'));
    await settle(tester);
    expect(find.text('KONTO'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('Fehler beim Aktualisieren wird verständlich angezeigt', (tester) async {
    final h = await harnessWithSource(tester, password: 'falsch');
    await h.pump(tester);
    await settle(tester);
    await syncAndWait(tester, h);

    expect(find.byKey(const Key('sync-error')), findsOneWidget);
    expect(find.text('Benutzername oder Passwort stimmen nicht.'), findsOneWidget);
    expect(find.text('Erneut versuchen'), findsOneWidget);
  });

  testWidgets('Suche findet Sender, Filme und Serien gruppiert', (tester) async {
    final h = await harnessWithSource(tester);
    // Sehr hohes Fenster, damit alle Ergebnisgruppen gleichzeitig sichtbar sind.
    await h.pump(tester, size: const Size(390, 6000));
    await settle(tester);
    await syncAndWait(tester, h);

    await tester.tap(find.text('Suche'));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('search-field')), 'test');
    await tester.pump(const Duration(milliseconds: 250));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 50));
    await settle(tester);
    expect(find.textContaining('LIVE · 25'), findsOneWidget);
    expect(find.textContaining('FILME · 12'), findsOneWidget);
    expect(find.textContaining('SERIEN · 5'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('search-field')), 'gibtesnicht');
    await tester.pump(const Duration(milliseconds: 250));
    await settle(tester);
    await settle(tester);
    expect(find.byKey(const Key('search-no-results')), findsOneWidget);
  });
}

class _RealHttp extends HttpOverrides {}
