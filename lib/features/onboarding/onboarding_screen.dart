import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';
import 'package:lucide_icons_flutter/lucide_icons_600.dart';

import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/widgets/lumen_button.dart';
import '../../core/widgets/lumen_logo.dart';
import '../../core/widgets/pressable.dart';
import '../settings/settings.dart';

/// Drei kurze Screens. Der letzte enthält den Inhaltshinweis, der bestätigt
/// werden muss. Danach geht es direkt zu „Quelle hinzufügen“.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _pages = 3;
  final _controller = PageController();
  int _index = 0;
  bool _confirmed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_index < _pages - 1) {
      await _controller.nextPage(
        duration: context.motion(LumenMotion.slow),
        curve: LumenMotion.emphasized,
      );
      return;
    }
    await ref.read(settingsProvider.notifier).completeOnboarding();
    if (mounted) context.go('/sources/add?first=1');
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final l = context.lumen;
    final p = l.palette;
    final last = _index == _pages - 1;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: l.pagePadding,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  Expanded(
                    child: PageView(
                      controller: _controller,
                      onPageChanged: (i) => setState(() => _index = i),
                      children: [
                        _Page(
                          visual: LumenLogo(size: l.isTv ? 140 : 104),
                          title: t.onb1Title,
                          body: t.onb1Body,
                        ),
                        _Page(
                          visual: _IconVisual(LucideIcons300.layoutGrid),
                          title: t.onb2Title,
                          body: t.onb2Body,
                        ),
                        _Page(
                          visual: _IconVisual(LucideIcons300.lock),
                          title: t.onb3Title,
                          body: t.onb3Body,
                          extra: _NoticeConfirm(
                            confirmed: _confirmed,
                            onChanged: (v) => setState(() => _confirmed = v),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Semantics(
                    label: t.onbStep(_index + 1, _pages),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _pages; i++)
                          AnimatedContainer(
                            duration: context.motion(LumenMotion.normal),
                            curve: LumenMotion.standard,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _index ? 22 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: i == _index ? p.textPrimary : p.surface3,
                              borderRadius: LumenRadius.pillAll,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: LumenSpace.xl),
                  LumenButton(
                    key: const Key('onboarding-next'),
                    label: last ? t.getStarted : t.next,
                    autofocus: true,
                    onPressed: last && !_confirmed ? null : _next,
                  ),
                  const SizedBox(height: LumenSpace.md),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.visual, required this.title, required this.body, this.extra});

  final Widget visual;
  final String title;
  final String body;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final l = context.lumen;
    final p = l.palette;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: LumenSpace.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: l.isTv ? 40 : 72),
          visual,
          const SizedBox(height: LumenSpace.x3),
          Semantics(
            header: true,
            child: Text(title, style: l.text.largeTitle.copyWith(color: p.textPrimary)),
          ),
          const SizedBox(height: LumenSpace.sm),
          Text(body, style: l.text.body.copyWith(color: p.textSecondary)),
          if (extra != null) ...[const SizedBox(height: LumenSpace.xxl), extra!],
        ],
      ),
    );
  }
}

class _IconVisual extends StatelessWidget {
  const _IconVisual(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final l = context.lumen;
    final size = l.isTv ? 140.0 : 104.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: l.palette.surface1,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(icon, size: size * 0.5, color: l.accent),
    );
  }
}

/// Inhaltshinweis mit Bestätigung („Verstanden“).
class _NoticeConfirm extends StatelessWidget {
  const _NoticeConfirm({required this.confirmed, required this.onChanged});

  final bool confirmed;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final l = context.lumen;
    final p = l.palette;
    return Semantics(
      checked: confirmed,
      child: LumenPressable(
        key: const Key('onboarding-confirm'),
        onPressed: () => onChanged(!confirmed),
        borderRadius: LumenRadius.lgAll,
        focusScale: 1.02,
        child: Container(
          padding: const EdgeInsets.all(LumenSpace.md),
          decoration: BoxDecoration(color: p.surface1, borderRadius: LumenRadius.lgAll),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: context.motion(LumenMotion.fast),
                width: 26,
                height: 26,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: confirmed ? l.accent : Colors.transparent,
                  border: Border.all(
                    color: confirmed ? l.accent : p.textSecondary,
                    width: 2,
                  ),
                ),
                child: confirmed
                    ? Icon(LucideIcons600.check, size: 15, color: l.onAccent)
                    : null,
              ),
              const SizedBox(width: LumenSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.onbConfirm, style: l.text.headline.copyWith(color: p.textPrimary)),
                    const SizedBox(height: LumenSpace.xxs),
                    Text(t.contentNotice,
                        style: l.text.footnote.copyWith(color: p.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
