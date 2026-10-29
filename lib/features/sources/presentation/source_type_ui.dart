import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/l10n/app_localizations.dart';
import '../domain/source_profile.dart';

/// Anzeige-Infos (Name, Beschreibung, Icon, Routen-Segment) je Quellenart.
extension SourceTypeUi on SourceType {
  String label(AppLocalizations t) => switch (this) {
        SourceType.xtream => t.typeXtream,
        SourceType.m3uUrl => t.typeM3uUrl,
        SourceType.m3uFile => t.typeM3uFile,
      };

  String description(AppLocalizations t) => switch (this) {
        SourceType.xtream => t.typeXtreamDesc,
        SourceType.m3uUrl => t.typeM3uUrlDesc,
        SourceType.m3uFile => t.typeM3uFileDesc,
      };

  IconData get icon => switch (this) {
        SourceType.xtream => LucideIcons.server,
        SourceType.m3uUrl => LucideIcons.link,
        SourceType.m3uFile => LucideIcons.fileText,
      };

  String get slug => switch (this) {
        SourceType.xtream => 'xtream',
        SourceType.m3uUrl => 'm3u-url',
        SourceType.m3uFile => 'm3u-file',
      };

  static SourceType? fromSlug(String? s) =>
      SourceType.values.where((t) => t.slug == s).firstOrNull;
}
