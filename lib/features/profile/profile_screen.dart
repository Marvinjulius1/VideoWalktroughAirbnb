import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:lucide_icons_flutter/lucide_icons_600.dart';

import '../../app/providers.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/widgets/lumen_card.dart';
import '../../core/widgets/lumen_page.dart';
import '../sources/domain/source_profile.dart';
import '../sources/presentation/manage_sources_screen.dart';
import '../sync/sync_controller.dart';
import '../sync/sync_status_card.dart';

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
                  const SizedBox(height: LumenSpace.sm),
                  SyncStatusCard(profile: active),
                  if (active.type == SourceType.xtream) ...[
                    const SizedBox(height: LumenSpace.xl),
                    _AccountGroup(profileId: active.id),
                  ],
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

/// Kontoinfo bei Xtream: Status, Ablaufdatum, Verbindungen, Erstellt am.
class _AccountGroup extends ConsumerWidget {
  const _AccountGroup({required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(accountInfoProvider(profileId)).value;
    if (info == null) return const SizedBox.shrink();
    final t = AppLocalizations.of(context);
    final l = context.lumen;
    final p = l.palette;
    final date = DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag());
    final status = info.status ?? '–';
    final active = status.toLowerCase() == 'active';
    final valueStyle = l.text.callout.copyWith(
      color: p.textSecondary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    Widget value(String s, {Color? color}) =>
        Text(s, style: color == null ? valueStyle : valueStyle.copyWith(color: color));

    return LumenGroup(
      title: t.accountTitle,
      children: [
        LumenListTile(
          title: t.accountStatus,
          trailing: value(
            [active ? t.accountActive : status, if (info.isTrial) t.accountTrial].join(' · '),
            color: active ? p.success : p.error,
          ),
        ),
        LumenListTile(
          title: t.accountExpires,
          trailing: value(info.expiresAt == null
              ? t.accountUnlimited
              : date.format(info.expiresAt!.toLocal())),
        ),
        if (info.maxConnections != null)
          LumenListTile(
            title: t.accountConnections,
            trailing: value('${info.activeConnections ?? 0} / ${info.maxConnections}'),
          ),
        if (info.createdAt != null)
          LumenListTile(
            title: t.accountCreated,
            trailing: value(date.format(info.createdAt!.toLocal())),
          ),
      ],
    );
  }
}
