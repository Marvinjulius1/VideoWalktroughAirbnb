import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:lucide_icons_flutter/lucide_icons_600.dart';

import '../../app/providers.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/widgets/lumen_card.dart';
import '../../core/widgets/lumen_page.dart';
import '../sources/presentation/manage_sources_screen.dart';

/// Profil: aktive Quelle, Quellen verwalten, Einstellungen.
/// Favoriten, Verlauf und Weiterschauen kommen in Phase 3 dazu.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final active = ref.watch(activeSourceProvider);
    final all = ref.watch(sourcesProvider).value ?? const [];

    return LumenPage(
      title: t.tabProfile,
      slivers: [
        if (active != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: LumenSpace.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: LumenSpace.md, bottom: LumenSpace.xs),
                    child: Text(t.activeSource.toUpperCase(),
                        style: context.lumen.text.caption.copyWith(
                            color: context.lumen.palette.textSecondary, letterSpacing: 0.6)),
                  ),
                  SourceCard(
                    profile: active,
                    autofocus: true,
                    onPressed: all.length > 1 ? () => _switchSource(context, ref) : null,
                    trailing: all.length > 1
                        ? Icon(LucideIcons.chevronsUpDown,
                            color: context.lumen.palette.textSecondary)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: LumenGroup(
            children: [
              LumenListTile(
                key: const Key('profile-sources'),
                title: t.profileSources,
                leading: LucideIcons.plug,
                trailing: const _Chevron(),
                autofocus: active == null,
                onPressed: () => context.push('/profile/sources'),
              ),
              LumenListTile(
                key: const Key('profile-settings'),
                title: t.settings,
                leading: LucideIcons.settings,
                trailing: const _Chevron(),
                onPressed: () => context.push('/profile/settings'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _switchSource(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context);
    final all = ref.read(sourcesProvider).value ?? const [];
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(LumenSpace.md, 0, LumenSpace.md, LumenSpace.md),
          child: LumenGroup(
            title: t.switchSource,
            children: [
              for (final s in all)
                LumenListTile(
                  title: s.name,
                  autofocus: s.isDefault,
                  trailing: s.isDefault
                      ? Icon(LucideIcons600.check, color: context.lumen.accent)
                      : null,
                  onPressed: () {
                    Navigator.pop(sheet);
                    ref.read(sourcesRepositoryProvider).setDefault(s.id);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) => Icon(LucideIcons.chevronRight,
      size: 18, color: context.lumen.palette.textSecondary);
}
