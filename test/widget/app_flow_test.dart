import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/app/providers.dart';
import 'package:lumen/core/network/source_error.dart';
import 'package:lumen/core/platform/device_profile.dart';
import 'package:lumen/features/settings/settings.dart';
import 'package:lumen/features/sources/data/sources_repository.dart';
import 'package:lumen/features/sources/domain/source_profile.dart';

import '../helpers/test_app.dart';

void main() {
  const contentNotice =
      'Diese App enthält keine Inhalte. Du bist selbst dafür verantwortlich, '
      'nur Quellen zu verwenden, zu deren Nutzung du berechtigt bist.';

  testWidgets('Erster Start: Onboarding mit Pflicht-Hinweis, dann „Quelle hinzufügen“',
      (tester) async {
    final h = TestHarness(settings: const AppSettings(localeCode: 'de'));
    await h.pump(tester);

    expect(find.text('Willkommen bei Lumen'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('Alles an einem Ort'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();

    // Letzter Screen: Hinweis sichtbar, Button erst nach Bestätigung aktiv.
    expect(find.text(contentNotice), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('Deine Daten bleiben bei dir'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-confirm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await settle(tester);

    expect(find.text('Wie möchtest du dich verbinden?'), findsOneWidget);
    expect(find.text('Xtream Codes'), findsOneWidget);
    expect(find.text('M3U-Link'), findsOneWidget);
    expect(find.text('M3U-Datei'), findsOneWidget);
    expect(h.container.read(settingsProvider).onboardingDone, isTrue);
  });

  testWidgets('Ohne Quelle: leerer Startbildschirm, keine Inhalte vorinstalliert',
      (tester) async {
    final h = TestHarness();
    await h.pump(tester);
    await settle(tester);

    expect(find.byKey(const Key('home-empty')), findsOneWidget);
    expect(find.text('Noch keine Quelle'), findsOneWidget);
    expect(find.text('Quelle hinzufügen'), findsOneWidget);
    expect(await h.db.select(h.db.profiles).get(), isEmpty);
  });

  testWidgets('Xtream-Formular: Inline-Validierung und sicheres Speichern',
      (tester) async {
    final h = TestHarness();
    await h.pump(tester);
    await settle(tester);

    await tester.tap(find.text('Quelle hinzufügen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-xtream')));
    await tester.pumpAndSettle();

    // Leeres Formular → Fehlermeldungen statt Absturz.
    await tester.tap(find.byKey(const Key('save-source')));
    await tester.pumpAndSettle();
    expect(find.text('Bitte ausfüllen.'), findsWidgets);

    await tester.enterText(find.descendant(
        of: find.byKey(const Key('field-server')), matching: find.byType(TextFormField)),
        'ftp://falsch');
    await tester.pumpAndSettle();
    expect(find.text('Die Adresse muss mit http:// oder https:// beginnen.'), findsOneWidget);

    Future<void> enter(String key, String value) => tester.enterText(
        find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextFormField)),
        value);
    await enter('field-name', 'Wohnzimmer');
    await enter('field-server', 'server.example:8080/player_api.php');
    await enter('field-username', 'nutzer');
    await enter('field-password', 'geheim');
    await tester.pumpAndSettle();

    // Passwort ist verdeckt.
    final pw = tester.widget<EditableText>(find.descendant(
        of: find.byKey(const Key('field-password')), matching: find.byType(EditableText)));
    expect(pw.obscureText, isTrue);

    await tester.ensureVisible(find.byKey(const Key('save-source')));
    await tester.tap(find.byKey(const Key('save-source')));
    await settle(tester);

    final rows = await h.db.select(h.db.profiles).get();
    expect(rows, hasLength(1));
    expect(rows.single.name, 'Wohnzimmer');
    expect(rows.single.serverUrl, 'http://server.example:8080');
    expect(rows.single.type, SourceType.xtream);
    expect(h.secrets.values[SourcesRepository.secretKey(rows.single.id)], contains('geheim'));

    // Zurück auf Start mit aktiver Quelle. (Das automatische Laden schlägt
    // im Test fehl, weil Flutter-Tests echte HTTP-Anfragen blockieren.)
    expect(find.text('Wohnzimmer'), findsOneWidget);
    expect(find.byKey(const Key('sync-error')).evaluate().isNotEmpty ||
        find.byKey(const Key('sync-running')).evaluate().isNotEmpty, isTrue);
  });

  testWidgets('Fehlgeschlagener Verbindungstest: Meldung, nichts gespeichert, „Trotzdem speichern“',
      (tester) async {
    final h = TestHarness()..connectionError = SourceErrorKind.invalidCredentials;
    await h.pump(tester);
    await settle(tester);
    await tester.tap(find.text('Quelle hinzufügen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-xtream')));
    await tester.pumpAndSettle();

    Future<void> enter(String key, String value) => tester.enterText(
        find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextFormField)), value);
    await enter('field-name', 'Küche');
    await enter('field-server', 'server.example');
    await enter('field-username', 'nutzer');
    await enter('field-password', 'falsch');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('save-source')));
    await tester.tap(find.byKey(const Key('save-source')));
    await settle(tester);

    expect(find.byKey(const Key('connection-error')), findsOneWidget);
    expect(find.text('Benutzername oder Passwort stimmen nicht.'), findsOneWidget);
    expect(await h.db.select(h.db.profiles).get(), isEmpty);

    await tester.dragUntilVisible(find.byKey(const Key('save-anyway')),
        find.byType(CustomScrollView), const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-anyway')));
    await settle(tester);
    expect((await h.db.select(h.db.profiles).get()).single.name, 'Küche');
  });

  testWidgets('Einstellungen enthalten den Inhaltshinweis', (tester) async {
    final h = TestHarness();
    await h.pump(tester);
    await settle(tester);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-settings')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(contentNotice), 200,
        scrollable: find.byType(Scrollable).last);
    expect(find.text(contentNotice), findsOneWidget);
  });

  testWidgets('Akzentfarbe und Modus lassen sich umstellen', (tester) async {
    final h = TestHarness();
    await h.pump(tester);
    await settle(tester);
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-settings')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hell'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Grün'));
    await settle(tester);

    final s = h.container.read(settingsProvider);
    expect(s.themeMode, ThemeMode.light);
    expect(s.accent.name, 'green');
    expect((await SettingsRepository(h.db).load()).accent.name, 'green');
  });

  testWidgets('TV: Seitenleiste statt Tab-Leiste, Bedienung per D-Pad', (tester) async {
    final h = TestHarness(device: const DeviceProfile(isTv: true));
    await h.pump(tester, size: const Size(1920, 1080));
    await settle(tester);

    expect(find.byType(BackdropFilter), findsNothing); // keine Glas-Tab-Leiste
    // Fokus startet im Inhalt („Quelle hinzufügen“), Leiste ist eingeklappt.
    expect(find.text('Filme & Serien'), findsNothing);

    // Links → Seitenleiste bekommt Fokus und klappt mit Beschriftung aus.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text('Filme & Serien'), findsOneWidget);

    // Runter + OK → „Live“.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await settle(tester);
    expect(find.text('Live'), findsWidgets);
    expect(find.text('Noch keine Quelle'), findsOneWidget);

    // Rechts → zurück in den Inhalt, Leiste klappt wieder ein.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('Filme & Serien'), findsNothing);
  });

  testWidgets('TV: Seite ohne Buttons → Fokus landet in der Seitenleiste', (tester) async {
    final h = TestHarness(device: const DeviceProfile(isTv: true));
    await h.container.read(sourcesRepositoryProvider).add(
          name: 'Test',
          type: SourceType.m3uUrl,
          credentials: const SourceCredentials(playlistUrl: 'http://localhost/x.m3u'),
        );
    await h.pump(tester, size: const Size(1920, 1080));
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await settle(tester);
    expect(find.text('Noch keine Sender'), findsOneWidget);
  });
}
