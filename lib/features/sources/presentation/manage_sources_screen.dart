import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../app/providers.dart';
import '../../../core/design/theme.dart';
import '../../../core/design/tokens.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/lumen_button.dart';
import '../../../core/widgets/lumen_card.dart';
import '../../../core/widgets/lumen_page.dart';
import '../domain/source_profile.dart';
import 'source_type_ui.dart';

/// Liste aller Quellen: Standard setzen, bearbeiten, löschen.
class ManageSourcesScreen extends ConsumerWidget {
  const ManageSourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final sources = ref.watch(sourcesProvider).value ?? const <SourceProfile>[];

    return Scaffold(
      appBar: AppBar(),
      body: sources.isEmpty
          ? EmptyState(
              icon: LucideIcons300.plug,
              title: t.emptyNoSourceTitle,
              message: t.emptyNoSourceBody,
              actionLabel: t.addSource,
              autofocusAction: true,
              onAction: () => context.push('/sources/add'),
            )
          : LumenPage(
              title: t.sourcesTitle,
              slivers: [
                SliverList.separated(
                  itemCount: sources.length,
                  separatorBuilder: (_, _) => const SizedBox(height: LumenSpace.sm),
                  itemBuilder: (context, i) => SourceCard(
                    profile: sources[i],
                    autofocus: i == 0,
                    onPressed: () => _showActions(context, ref, sources[i]),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: LumenSpace.xl),
                    child: LumenButton.secondary(
                      key: const Key('manage-add-source'),
                      label: t.addSource,
                      icon: LucideIcons.plus,
                      onPressed: () => context.push('/sources/add'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _showActions(BuildContext context, WidgetRef ref, SourceProfile s) async {
    final t = AppLocalizations.of(context);
    final repo = ref.read(sourcesRepositoryProvider);
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(LumenSpace.md, 0, LumenSpace.md, LumenSpace.md),
          child: LumenGroup(
            title: s.name,
            children: [
              if (!s.isDefault)
                LumenListTile(
                  title: t.setAsDefault,
                  leading: LucideIcons.star,
                  autofocus: true,
                  onPressed: () {
                    Navigator.pop(sheet);
                    repo.setDefault(s.id);
                  },
                ),
              LumenListTile(
                title: t.edit,
                leading: LucideIcons.pencil,
                autofocus: s.isDefault,
                onPressed: () {
                  Navigator.pop(sheet);
                  context.push('/sources/${s.id}/edit');
                },
              ),
              LumenListTile(
                key: const Key('source-delete'),
                title: t.delete,
                leading: LucideIcons.trash2,
                destructive: true,
                onPressed: () {
                  Navigator.pop(sheet);
                  _confirmDelete(context, ref, s);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, SourceProfile s) async {
    final t = AppLocalizations.of(context);
    final p = context.lumen.palette;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(t.deleteSourceTitle),
        content: Text(t.deleteSourceBody(s.name)),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(d, false),
            child: Text(t.cancel),
          ),
          TextButton(
            key: const Key('confirm-delete'),
            onPressed: () => Navigator.pop(d, true),
            child: Text(t.delete, style: TextStyle(color: p.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(sourcesRepositoryProvider).delete(s.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.sourceDeleted)));
    }
  }
}

/// Karte für eine Quelle (auch im Profil verwendet).
class SourceCard extends StatelessWidget {
  const SourceCard({
    super.key,
    required this.profile,
    this.onPressed,
    this.trailing,
    this.autofocus = false,
  });

  final SourceProfile profile;
  final VoidCallback? onPressed;
  final Widget? trailing;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final l = context.lumen;
    final p = l.palette;
    final detail = switch (profile.type) {
      SourceType.xtream => Uri.tryParse(profile.serverUrl ?? '')?.host,
      SourceType.m3uFile => profile.localFileName,
      SourceType.m3uUrl => null,
    };

    return LumenCard(
      onPressed: onPressed,
      autofocus: autofocus,
      semanticLabel: profile.name,
      child: Row(
        children: [
          Container(
            width: l.isTv ? 64 : 44,
            height: l.isTv ? 64 : 44,
            decoration: BoxDecoration(color: p.surface2, borderRadius: LumenRadius.mdAll),
            child: Icon(profile.type.icon, color: p.textPrimary),
          ),
          const SizedBox(width: LumenSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(profile.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: l.text.headline.copyWith(color: p.textPrimary)),
                    ),
                    if (profile.isDefault) ...[
                      const SizedBox(width: LumenSpace.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: l.accent.withValues(alpha: 0.16),
                          borderRadius: LumenRadius.pillAll,
                        ),
                        child: Text(t.sourceDefault,
                            style: l.text.caption.copyWith(color: l.accent)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [profile.type.label(t), ?detail].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: l.text.footnote.copyWith(color: p.textSecondary),
                ),
              ],
            ),
          ),
          trailing ??
              (onPressed != null
                  ? Icon(LucideIcons.ellipsis, color: p.textSecondary)
                  : const SizedBox.shrink()),
        ],
      ),
    );
  }
}
