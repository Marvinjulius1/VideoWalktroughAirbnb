import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/epg/guide_screen.dart';
import '../features/home/home_screen.dart';
import '../features/live/live_screen.dart';
import '../features/media/media_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/player/live_player_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/settings.dart';
import '../features/settings/settings_screen.dart';
import '../features/sources/domain/source_profile.dart';
import '../features/sources/presentation/add_source_screen.dart';
import '../features/sources/presentation/manage_sources_screen.dart';
import '../features/sources/presentation/source_form_screen.dart';
import '../features/sources/presentation/source_type_ui.dart';
import 'providers.dart';
import 'shell.dart';

/// Alle Routen der App.
///
/// - `/onboarding` erscheint, bis das Onboarding abgeschlossen ist.
/// - Die fünf Hauptbereiche liegen in einer [StatefulShellRoute]: jeder Tab
///   behält beim Wechseln seinen Scroll- und Navigationszustand.
/// - Formulare liegen außerhalb der Shell (Vollbild, ohne Tab-Leiste).
final routerProvider = Provider<GoRouter>((ref) {
  final onboarded = ValueNotifier(ref.read(settingsProvider).onboardingDone);
  ref.listen(settingsProvider.select((s) => s.onboardingDone),
      (_, v) => onboarded.value = v);

  final router = GoRouter(
    initialLocation: '/home',
    refreshListenable: onboarded,
    redirect: (context, state) {
      final atOnboarding = state.matchedLocation == '/onboarding';
      if (!onboarded.value && !atOnboarding) return '/onboarding';
      if (onboarded.value && atOnboarding) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(
        path: '/sources/add',
        builder: (_, s) =>
            AddSourceScreen(firstRun: s.uri.queryParameters['first'] == '1'),
        routes: [
          GoRoute(
            path: ':type',
            redirect: (_, s) =>
                SourceTypeUi.fromSlug(s.pathParameters['type']) == null
                    ? '/sources/add'
                    : null,
            builder: (_, s) => SourceFormScreen(
              type: SourceTypeUi.fromSlug(s.pathParameters['type'])!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/player/live',
        redirect: (_, s) => s.extra is LivePlayerArgs ? null : '/live',
        pageBuilder: (_, s) => CustomTransitionPage(
          key: s.pageKey,
          child: LivePlayerScreen(args: s.extra! as LivePlayerArgs),
          transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
        ),
      ),
      GoRoute(
        path: '/sources/:id/edit',
        builder: (_, s) => _EditSource(id: s.pathParameters['id']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/live',
              builder: (_, _) => const LiveScreen(),
              routes: [GoRoute(path: 'guide', builder: (_, _) => const GuideScreen())],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/media', builder: (_, _) => const MediaScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/search', builder: (_, _) => const SearchScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (_, _) => const ProfileScreen(),
              routes: [
                GoRoute(path: 'sources', builder: (_, _) => const ManageSourcesScreen()),
                GoRoute(path: 'settings', builder: (_, _) => const SettingsScreen()),
              ],
            ),
          ]),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    onboarded.dispose();
  });
  return router;
});

/// Lädt die Quelle, um die Art zu kennen, und zeigt dann das Formular.
class _EditSource extends ConsumerWidget {
  const _EditSource({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = ref.watch(_sourceTypeProvider(id)).value;
    if (type == null) return const SizedBox.shrink();
    return SourceFormScreen(type: type, editId: id);
  }
}

final _sourceTypeProvider = FutureProvider.family<SourceType?, String>((ref, id) async {
  final profile = await ref.watch(sourcesRepositoryProvider).byId(id);
  return profile?.type;
});
