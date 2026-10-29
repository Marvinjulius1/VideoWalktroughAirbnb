import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:lucide_icons_flutter/lucide_icons_600.dart';

import '../core/design/theme.dart';
import '../core/design/tokens.dart';
import '../core/l10n/app_localizations.dart';
import '../core/widgets/pressable.dart';
import 'providers.dart';

/// Ein Ziel der Hauptnavigation.
class _Destination {
  const _Destination(this.icon, this.selectedIcon, this.label);
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

List<_Destination> _destinations(AppLocalizations t) => [
      _Destination(LucideIcons.house, LucideIcons600.house, t.tabHome),
      _Destination(LucideIcons.tv, LucideIcons600.tv, t.tabLive),
      _Destination(LucideIcons.clapperboard, LucideIcons600.clapperboard, t.tabMedia),
      _Destination(LucideIcons.search, LucideIcons600.search, t.tabSearch),
      _Destination(LucideIcons.circleUser, LucideIcons600.circleUser, t.tabProfile),
    ];

/// Rahmen um die Hauptbereiche: Tab-Leiste unten (mobil) oder
/// Seitenleiste links (TV). Jeder Tab behält seinen eigenen Zustand.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _go(int i) => shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTv = ref.watch(deviceProfileProvider).isTv;
    final items = _destinations(AppLocalizations.of(context));

    if (isTv) {
      return _TvLayout(items: items, selected: shell.currentIndex, onSelect: _go, child: shell);
    }
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar:
          _GlassTabBar(items: items, selected: shell.currentIndex, onSelect: _go),
    );
  }
}

class _GlassTabBar extends StatelessWidget {
  const _GlassTabBar({required this.items, required this.selected, required this.onSelect});

  final List<_Destination> items;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final l = context.lumen;
    final p = l.palette;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: LumenBlur.glass, sigmaY: LumenBlur.glass),
        child: Container(
          decoration: BoxDecoration(
            color: p.glass,
            border: Border(top: BorderSide(color: p.separator, width: 0.5)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: Semantics(
                        selected: i == selected,
                        child: LumenPressable(
                          onPressed: () => onSelect(i),
                          focusScale: 1,
                          semanticLabel: items[i].label,
                          child: _TabItem(item: items[i], selected: i == selected),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.item, required this.selected});

  final _Destination item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l = context.lumen;
    final color = selected ? l.palette.textPrimary : l.palette.textSecondary;
    return ExcludeSemantics(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: context.motion(LumenMotion.fast),
            child: Icon(
              selected ? item.selectedIcon : item.icon,
              key: ValueKey(selected),
              size: 24,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: l.text.caption.copyWith(
              color: color,
              fontSize: 10.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// TV-Layout: schmale Icon-Leiste links, die sich ausklappt, sobald sie
/// Fokus hat, daneben der Inhalt.
///
/// Warum eigene Tastenlogik? Jeder Tab hat einen eigenen Navigator und damit
/// einen eigenen Fokusbereich. Flutters D-Pad-Navigation bleibt innerhalb
/// eines Bereichs. Deshalb leiten wir „Links am Rand“ in die Leiste und
/// „Rechts aus der Leiste“ zurück in den Inhalt.
class _TvLayout extends StatefulWidget {
  const _TvLayout({
    required this.items,
    required this.selected,
    required this.onSelect,
    required this.child,
  });

  final List<_Destination> items;
  final int selected;
  final ValueChanged<int> onSelect;
  final Widget child;

  @override
  State<_TvLayout> createState() => _TvLayoutState();
}

class _TvLayoutState extends State<_TvLayout> {
  bool _expanded = false;
  final _content = FocusScopeNode(debugLabel: 'tv-content');
  late final List<FocusNode> _nodes =
      List.generate(widget.items.length, (i) => FocusNode(debugLabel: 'rail-$i'));

  @override
  void initState() {
    super.initState();
    // Hat nach dem ersten Bild nichts im Inhalt den Fokus (z. B. eine Seite
    // ohne Buttons), landet er in der Leiste – sonst wäre die Fernbedienung
    // „tot“.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _visibleContentNodes().isEmpty) _focusRail();
    });
    FocusManager.instance.addListener(_onGlobalFocusChange);
  }

  /// Verschwindet das fokussierte Element (z. B. weil Daten geladen wurden
  /// und ein Button wegfällt), geht der Fokus zurück in die Leiste.
  void _onGlobalFocusChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final primary = FocusManager.instance.primaryFocus;
      final lost = primary == null ||
          (primary is FocusScopeNode &&
              primary.focusedChild == null &&
              (identical(primary, _content) ||
                  primary.ancestors.contains(_content) ||
                  identical(primary, FocusScope.of(context))));
      if (lost) _focusRail();
    });
  }

  @override
  void didUpdateWidget(_TvLayout old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      // Neuer Tab: wenn er nichts Fokussierbares hat, bleibt der Fokus in
      // der Leiste auf dem neuen Eintrag.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_content.hasFocus && _railHasFocus) _focusRail();
      });
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onGlobalFocusChange);
    _content.dispose();
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  bool get _railHasFocus => _nodes.any((n) => n.hasFocus);

  void _focusRail() => _nodes[widget.selected].requestFocus();

  /// Fokussierbare Elemente des sichtbaren Tabs (unsichtbare Tabs liegen
  /// „offstage“ im Baum und werden ignoriert).
  List<FocusNode> _visibleContentNodes() => _content.traversalDescendants
      .where((n) =>
          n is! FocusScopeNode &&
          n.context != null &&
          n.context!.findAncestorWidgetOfExactType<Offstage>()?.offstage != true)
      .toList();

  void _focusContent() {
    final nodes = _visibleContentNodes();
    if (nodes.isEmpty) return;
    // Zuletzt fokussiertes Element bevorzugen, sonst das oberste/linkeste.
    final last = nodes.where((n) => n.hasPrimaryFocus || _wasFocused(n));
    if (last.isNotEmpty) {
      last.first.requestFocus();
      return;
    }
    nodes.sort((a, b) {
      final ra = a.rect, rb = b.rect;
      final dy = ra.top.compareTo(rb.top);
      return dy != 0 ? dy : ra.left.compareTo(rb.left);
    });
    nodes.first.requestFocus();
  }

  FocusNode? _lastContentFocus;
  bool _wasFocused(FocusNode n) => identical(n, _lastContentFocus);

  KeyEventResult _onContentKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.arrowLeft) {
      return KeyEventResult.ignored;
    }
    final before = FocusManager.instance.primaryFocus;
    if (before == null) return KeyEventResult.ignored;
    final beforeX = before.rect.center.dx;
    final moved = before.focusInDirection(TraversalDirection.left);
    final after = FocusManager.instance.primaryFocus;
    // Kein Element weiter links (oder Sprung ans andere Ende) → Leiste.
    if (!moved || after == null || identical(after, before) || after.rect.center.dx >= beforeX) {
      _lastContentFocus = before;
      _focusRail();
    }
    return KeyEventResult.handled;
  }

  KeyEventResult _onRailKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _focusContent();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.lumen;
    final p = l.palette;
    return Scaffold(
      body: Row(
        children: [
          Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: _onRailKey,
            onFocusChange: (f) => setState(() => _expanded = f),
            child: FocusTraversalGroup(
              policy: OrderedTraversalPolicy(),
              child: AnimatedContainer(
                duration: context.motion(LumenMotion.normal),
                curve: LumenMotion.standard,
                width: _expanded ? 300 : 112,
                decoration: BoxDecoration(
                  color: _expanded ? p.surface1 : p.bg,
                  border: Border(right: BorderSide(color: p.separator)),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: LumenSpace.lg,
                  vertical: LumenSpace.pageTvVertical + LumenSpace.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < widget.items.length; i++) ...[
                      _RailItem(
                        item: widget.items[i],
                        selected: i == widget.selected,
                        expanded: _expanded,
                        focusNode: _nodes[i],
                        onPressed: () => widget.onSelect(i),
                      ),
                      const SizedBox(height: LumenSpace.xs),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: FocusScope(
              node: _content,
              onKeyEvent: _onContentKey,
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.item,
    required this.selected,
    required this.expanded,
    required this.onPressed,
    required this.focusNode,
  });

  final _Destination item;
  final bool selected;
  final bool expanded;
  final FocusNode focusNode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l = context.lumen;
    final p = l.palette;
    final color = selected ? p.textPrimary : p.textSecondary;
    return Semantics(
      selected: selected,
      child: LumenPressable(
        onPressed: onPressed,
        focusNode: focusNode,
        focusScale: 1.04,
        semanticLabel: item.label,
        haptic: false,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: LumenSpace.md),
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: selected ? p.surface2 : Colors.transparent,
            borderRadius: LumenRadius.mdAll,
          ),
          child: Row(
            children: [
              Icon(selected ? item.selectedIcon : item.icon, color: color, size: 30),
              // Die Beschriftung bekommt nur den Platz, der beim Ausklappen
              // gerade frei ist – so läuft während der Animation nichts über.
              if (expanded)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: LumenSpace.md),
                    child: Text(item.label,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: l.text.headline.copyWith(color: color)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
