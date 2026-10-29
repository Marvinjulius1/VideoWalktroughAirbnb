import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:lucide_icons_flutter/lucide_icons_600.dart';

import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/widgets/lumen_card.dart';
import '../../core/widgets/lumen_page.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/segmented_control.dart';
import 'settings.dart';

final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});

/// Einstellungen. Player, EPG und Jugendschutz kommen in späteren Phasen dazu.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final l = context.lumen;
    const gap = SliverToBoxAdapter(child: SizedBox(height: LumenSpace.xl));

    String languageName(String? code) => switch (code) {
          'de' => 'Deutsch',
          'en' => 'English',
          _ => t.languageSystem,
        };

    return Scaffold(
      appBar: AppBar(),
      body: LumenPage(
        title: t.settings,
        slivers: [
          SliverToBoxAdapter(
            child: LumenGroup(
              title: t.settingsAppearance,
              children: [
                Padding(
                  padding: const EdgeInsets.all(LumenSpace.md),
                  child: LumenSegmentedControl<ThemeMode>(
                    segments: {
                      ThemeMode.system: t.themeSystem,
                      ThemeMode.light: t.themeLight,
                      ThemeMode.dark: t.themeDark,
                    },
                    selected: s.themeMode,
                    onChanged: ctrl.setThemeMode,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(LumenSpace.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.settingsAccent, style: l.text.body.copyWith(color: l.palette.textPrimary)),
                      const SizedBox(height: LumenSpace.sm),
                      Wrap(
                        spacing: LumenSpace.sm,
                        runSpacing: LumenSpace.sm,
                        children: [
                          for (final a in LumenAccent.values)
                            _AccentSwatch(
                              accent: a,
                              label: _accentName(t, a),
                              selected: a == s.accent,
                              onPressed: () => ctrl.setAccent(a),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          gap,
          SliverToBoxAdapter(
            child: LumenGroup(
              title: t.settingsGeneral,
              footer: t.settingsAutoRefreshFooter,
              children: [
                LumenListTile(
                  title: t.settingsLanguage,
                  leading: LucideIcons.globe,
                  trailing: Text(languageName(s.localeCode),
                      style: l.text.callout.copyWith(color: l.palette.textSecondary)),
                  onPressed: () => _pickLanguage(context, ref, languageName),
                ),
                LumenListTile(
                  key: const Key('auto-refresh'),
                  title: t.settingsAutoRefresh,
                  leading: LucideIcons.rotateCw,
                  trailing: Switch(value: s.autoRefresh, onChanged: ctrl.setAutoRefresh),
                ),
                if (!l.isTv)
                  LumenListTile(
                    title: t.settingsHaptics,
                    leading: LucideIcons.vibrate,
                    trailing: Switch(value: s.haptics, onChanged: ctrl.setHaptics),
                  ),
              ],
            ),
          ),
          gap,
          SliverToBoxAdapter(
            child: LumenGroup(
              title: t.settingsInfo,
              footer: t.contentNotice,
              children: [
                LumenListTile(
                  title: t.settingsVersion,
                  leading: LucideIcons.info,
                  trailing: Text(ref.watch(appVersionProvider).value ?? '–',
                      style: l.text.callout.copyWith(
                          color: l.palette.textSecondary,
                          fontFeatures: const [FontFeature.tabularFigures()])),
                ),
                LumenListTile(
                  title: t.contentNoticeTitle,
                  leading: LucideIcons.circleAlert,
                  onPressed: () => _showText(context, t.contentNoticeTitle, t.contentNotice),
                ),
                LumenListTile(
                  title: t.settingsPrivacy,
                  leading: LucideIcons.shieldCheck,
                  onPressed: () => _showText(context, t.settingsPrivacy, t.privacySummary),
                ),
                LumenListTile(
                  title: t.settingsLicenses,
                  leading: LucideIcons.scrollText,
                  onPressed: () => showLicensePage(
                    context: context,
                    applicationName: t.appName,
                    applicationVersion: ref.read(appVersionProvider).value,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _accentName(AppLocalizations t, LumenAccent a) => switch (a) {
        LumenAccent.blue => t.accentBlue,
        LumenAccent.green => t.accentGreen,
        LumenAccent.mint => t.accentMint,
        LumenAccent.orange => t.accentOrange,
        LumenAccent.purple => t.accentPurple,
        LumenAccent.graphite => t.accentGraphite,
      };

  Future<void> _pickLanguage(
      BuildContext context, WidgetRef ref, String Function(String?) name) async {
    final current = ref.read(settingsProvider).localeCode;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(LumenSpace.md, 0, LumenSpace.md, LumenSpace.md),
          child: LumenGroup(
            children: [
              for (final code in const [null, 'de', 'en'])
                LumenListTile(
                  title: name(code),
                  autofocus: code == current,
                  trailing: code == current
                      ? Icon(LucideIcons600.check, color: context.lumen.accent)
                      : null,
                  onPressed: () {
                    Navigator.pop(sheet);
                    ref.read(settingsProvider.notifier).setLocale(code);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showText(BuildContext context, String title, String body) {
    final t = AppLocalizations.of(context);
    return showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(autofocus: true, onPressed: () => Navigator.pop(d), child: Text(t.close)),
        ],
      ),
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.accent,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final LumenAccent accent;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l = context.lumen;
    final color = accent.resolve(l.brightness);
    final size = l.isTv ? 56.0 : 40.0;
    return Semantics(
      selected: selected,
      child: LumenPressable(
        onPressed: onPressed,
        semanticLabel: label,
        borderRadius: LumenRadius.pillAll,
        focusScale: 1.12,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: selected
              ? Icon(LucideIcons600.check,
                  size: size * 0.45, color: accent.onAccent(l.brightness))
              : null,
        ),
      ),
    );
  }
}
