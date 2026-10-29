import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/app/app.dart';
import 'package:lumen/app/providers.dart';
import 'package:lumen/core/db/database.dart';
import 'package:lumen/core/platform/device_profile.dart';
import 'package:lumen/core/security/secret_store.dart';
import 'package:lumen/core/network/source_error.dart';
import 'package:lumen/features/settings/settings.dart';
import 'package:lumen/features/sources/data/xtream/xtream_models.dart';
import 'package:lumen/features/sources/domain/source_profile.dart';
import 'package:lumen/features/sync/sync_controller.dart';
import 'package:dio/dio.dart';

LumenDatabase memoryDb() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return LumenDatabase(NativeDatabase.memory());
}

/// Alles, was ein Widget-Test braucht: frische In-Memory-Datenbank,
/// Fake-Schlüsselbund und wählbare Startbedingungen.
class TestHarness {
  TestHarness({
    this.settings = const AppSettings(onboardingDone: true, localeCode: 'de', autoRefresh: false),
    this.device = const DeviceProfile(),
  });

  final AppSettings settings;
  final DeviceProfile device;

  /// Ergebnis des Verbindungstests im Formular (`null` = erfolgreich).
  SourceErrorKind? connectionError;
  final LumenDatabase db = memoryDb();
  final InMemorySecretStore secrets = InMemorySecretStore();

  late final ProviderContainer container = ProviderContainer(overrides: [
    databaseProvider.overrideWithValue(db),
    secretStoreProvider.overrideWithValue(secrets),
    deviceProfileProvider.overrideWithValue(device),
    initialSettingsProvider.overrideWithValue(settings),
    connectionTesterProvider.overrideWithValue(_FakeTester(this)),
    ...extraOverrides,
  ]);

  /// Für Tests, die z. B. einen echten Mock-Server einbinden.
  List<Override> extraOverrides = [];

  Future<void> pump(WidgetTester tester, {Size size = const Size(390, 844)}) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    addTearDown(dispose);
    device.applyFocusStrategy();
    addTearDown(const DeviceProfile().applyFocusStrategy);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const LumenApp()),
    );
    await tester.pumpAndSettle();
  }

  Future<void> dispose() async {
    container.dispose();
    await db.close();
  }
}

/// Wartet, bis Datenbank-Streams geliefert haben, und lässt Animationen
/// auslaufen.
Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  await tester.pumpAndSettle();
}

extension FindText on CommonFinders {
  Finder textContaining(String s) => find.byWidgetPredicate(
        (w) => w is Text && (w.data?.contains(s) ?? false),
      );
}

Widget wrap(Widget child) => MaterialApp(home: child);

class _FakeTester extends ConnectionTester {
  _FakeTester(this.h) : super(Dio());

  final TestHarness h;

  @override
  Future<XtreamAccount?> test(SourceType type, {String? server, required SourceCredentials creds}) async {
    if (h.connectionError != null) throw SourceException(h.connectionError!);
    return null;
  }
}
