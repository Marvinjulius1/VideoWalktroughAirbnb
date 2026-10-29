import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../app/providers.dart';
import '../../core/db/database.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/lumen_card.dart';
import '../../core/widgets/lumen_page.dart';
import '../sync/content_store.dart';
import '../sync/sync_controller.dart';

/// Globale Suche über Sender, Filme und Serien der aktiven Quelle.
///
/// Sucht lokal im FTS5-Index – schnell und ohne Netzwerk. Die Eingabe wird
/// kurz „entprellt“ (200 ms), damit nicht bei jedem Buchstaben gesucht wird.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<SearchHit> _hits = const [];
  String _searched = '';
  int _seq = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () => _run(q));
  }

  Future<void> _run(String q) async {
    final profile = ref.read(activeSourceProvider);
    final seq = ++_seq;
    final hits = profile == null || q.trim().isEmpty
        ? const <SearchHit>[]
        : await ref.read(contentStoreProvider).search(profile.id, q);
    if (!mounted || seq != _seq) return; // ältere Antwort verwerfen
    setState(() {
      _hits = hits;
      _searched = q.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final l = context.lumen;
    final p = l.palette;

    final groups = <ContentKind, List<SearchHit>>{};
    for (final h in _hits) {
      (groups[h.kind] ??= []).add(h);
    }
    String groupTitle(ContentKind k) => switch (k) {
          ContentKind.live => t.tabLive,
          ContentKind.vod => t.movies,
          ContentKind.series => t.series,
        };
    IconData groupIcon(ContentKind k) => switch (k) {
          ContentKind.live => LucideIcons.tv,
          ContentKind.vod => LucideIcons.film,
          ContentKind.series => LucideIcons.monitorPlay,
        };

    return LumenPage(
      title: t.tabSearch,
      slivers: [
        SliverToBoxAdapter(
          child: TextField(
            key: const Key('search-field'),
            controller: _query,
            onChanged: _onChanged,
            onSubmitted: _run,
            textInputAction: TextInputAction.search,
            autocorrect: false,
            style: l.text.body.copyWith(color: p.textPrimary),
            decoration: InputDecoration(
              hintText: t.searchHint,
              hintStyle: l.text.body.copyWith(color: p.textSecondary),
              prefixIcon: Icon(LucideIcons.search, color: p.textSecondary),
              filled: true,
              fillColor: p.surface2,
              contentPadding: const EdgeInsets.symmetric(vertical: LumenSpace.sm),
              border: const OutlineInputBorder(
                borderRadius: LumenRadius.mdAll,
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: LumenRadius.mdAll,
                borderSide: BorderSide(color: l.accent, width: 2),
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: LumenSpace.xl)),
        if (_searched.isEmpty)
          SliverToBoxAdapter(
            child: EmptyState(
              icon: LucideIcons300.search,
              title: t.searchEmptyTitle,
              message: t.searchEmptyBody,
            ),
          )
        else if (_hits.isEmpty)
          SliverToBoxAdapter(
            child: EmptyState(
              key: const Key('search-no-results'),
              icon: LucideIcons300.searchX,
              title: t.searchNoResults(_searched),
              message: t.searchNoResultsBody,
            ),
          )
        else
          for (final kind in ContentKind.values)
            if (groups[kind] case final List<SearchHit> hits)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: LumenSpace.xl),
                  child: LumenGroup(
                    title: '${groupTitle(kind)} · ${hits.length}',
                    children: [
                      for (final h in hits)
                        LumenListTile(
                          title: h.name,
                          leading: groupIcon(kind),
                          // Öffnen kommt mit Live-TV/Filmen/Serien in Phase 3.
                          onPressed: () {},
                        ),
                    ],
                  ),
                ),
              ),
      ],
    );
  }
}
