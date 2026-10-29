import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/lumen_page.dart';

/// Globale Suche. Der lokale Suchindex (FTS5) kommt in Phase 2.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final l = context.lumen;
    final p = l.palette;
    return LumenPage(
      title: t.tabSearch,
      slivers: [
        SliverToBoxAdapter(
          child: TextField(
            controller: _query,
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
        SliverToBoxAdapter(
          child: EmptyState(
            icon: LucideIcons300.search,
            title: t.searchEmptyTitle,
            message: t.searchEmptyBody,
          ),
        ),
      ],
    );
  }
}
