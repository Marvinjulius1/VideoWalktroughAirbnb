import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/db/database.dart';
import 'core/platform/device_profile.dart';
import 'features/settings/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // Lizenz der gebündelten Schrift auf der Lizenzseite anzeigen.
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/inter/LICENSE.txt');
    yield LicenseEntryWithLineBreaks(['Inter'], text);
  });

  // Vor dem ersten Frame laden, damit Theme und Startseite sofort stimmen.
  final db = LumenDatabase.open();
  final device = await DeviceProfile.detect()..applyFocusStrategy();
  final settings = await SettingsRepository(db).load();

  runApp(ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      deviceProfileProvider.overrideWithValue(device),
      initialSettingsProvider.overrideWithValue(settings),
    ],
    child: const LumenApp(),
  ));
}
