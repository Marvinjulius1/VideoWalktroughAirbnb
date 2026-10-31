import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:lucide_icons_flutter/lucide_icons_600.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/providers.dart';
import '../../core/db/database.dart';
import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/widgets/lumen_button.dart';
import '../../core/widgets/lumen_card.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/thin_progress.dart';
import '../epg/epg_providers.dart';
import '../epg/epg_widgets.dart';
import '../live/live_providers.dart';
import '../settings/settings.dart';
import '../live/widgets/channel_logo.dart';
import 'live_player_controller.dart';
import 'player_engine.dart';

/// Was der Live-Player braucht: die Senderliste (zum Umschalten) und den
/// Start-Sender.
class LivePlayerArgs {
  const LivePlayerArgs(this.channels, this.startIndex);
  final List<ChannelRow> channels;
  final int startIndex;
}

void openLivePlayer(
  BuildContext context,
  List<ChannelRow> channels,
  int index,
) => context.push(
  '/player/live',
  extra: LivePlayerArgs(List.unmodifiable(channels), index),
);

class LivePlayerScreen extends ConsumerStatefulWidget {
  const LivePlayerScreen({super.key, required this.args});

  final LivePlayerArgs args;

  @override
  ConsumerState<LivePlayerScreen> createState() => _LivePlayerScreenState();
}

class _LivePlayerScreenState extends ConsumerState<LivePlayerScreen> {
  late final PlayerEngine _engine = ref.read(playerEngineFactoryProvider)();
  LivePlayerController? _ctrl;
  bool _overlay = true;
  Timer? _hideTimer;
  VideoFit _fit = VideoFit.auto;
  List<TrackInfo> _audio = const [];
  List<TrackInfo> _subs = const [];
  final _subscriptions = <StreamSubscription<Object?>>[];
  final _focus = FocusNode(debugLabel: 'player');

  bool get _isTv => ref.read(deviceProfileProvider).isTv;

  @override
  void initState() {
    super.initState();
    _subscriptions
      ..add(_engine.audioTracks.listen((t) => setState(() => _audio = t)))
      ..add(_engine.subtitleTracks.listen((t) => setState(() => _subs = t)));
    _enterFullscreen();
    _init();
  }

  Future<void> _init() async {
    final resolver = await ref.read(activeResolverProvider.future);
    final profile = ref.read(activeSourceProvider);
    if (!mounted || resolver == null || profile == null) return;
    final repo = ref.read(liveRepositoryProvider);
    final ctrl = LivePlayerController(
      engine: _engine,
      channels: widget.args.channels,
      startIndex: widget.args.startIndex,
      resolve: resolver.live,
      onWatched: (c) =>
          repo.recordWatched(profile.id, ContentKind.live, c.itemKey),
    )..addListener(_onCtrl);
    setState(() => _ctrl = ctrl);
    _scheduleHide();
    await ctrl.start();
  }

  void _onCtrl() {
    if (!mounted) return;
    setState(() {});
    // Bei Pause oder Fehler bleibt das Overlay sichtbar.
    final c = _ctrl!;
    if (c.failed || c.phase == PlaybackPhase.paused) {
      _showOverlay(autoHide: false);
    }
  }

  Future<void> _enterFullscreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (!_isTv) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    try {
      await WakelockPlus.enable(); // Bildschirm bleibt an
    } catch (_) {
      // In Tests/auf Plattformen ohne Plugin ignorieren.
    }
  }

  Future<void> _leaveFullscreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(const []);
    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    for (final s in _subscriptions) {
      s.cancel();
    }
    _ctrl?.removeListener(_onCtrl);
    _ctrl?.dispose();
    _engine.dispose();
    _focus.dispose();
    _leaveFullscreen();
    super.dispose();
  }

  void _showOverlay({bool autoHide = true}) {
    if (!_overlay) setState(() => _overlay = true);
    _hideTimer?.cancel();
    if (autoHide) _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(LumenMotion.overlayHide, () {
      final c = _ctrl;
      if (!mounted || c == null || c.failed || c.phase == PlaybackPhase.paused) {
        return;
      }
      setState(() => _overlay = false);
      _focus.requestFocus();
    });
  }

  void _hideOverlay() {
    _hideTimer?.cancel();
    setState(() => _overlay = false);
    _focus.requestFocus();
  }

  void _toggleOverlay() => _overlay ? _hideOverlay() : _showOverlay();

  void _zap(void Function() action) {
    action();
    _showOverlay();
  }

  static final _digitKeys = {
    LogicalKeyboardKey.digit0: 0,
    LogicalKeyboardKey.digit1: 1,
    LogicalKeyboardKey.digit2: 2,
    LogicalKeyboardKey.digit3: 3,
    LogicalKeyboardKey.digit4: 4,
    LogicalKeyboardKey.digit5: 5,
    LogicalKeyboardKey.digit6: 6,
    LogicalKeyboardKey.digit7: 7,
    LogicalKeyboardKey.digit8: 8,
    LogicalKeyboardKey.digit9: 9,
    LogicalKeyboardKey.numpad0: 0,
    LogicalKeyboardKey.numpad1: 1,
    LogicalKeyboardKey.numpad2: 2,
    LogicalKeyboardKey.numpad3: 3,
    LogicalKeyboardKey.numpad4: 4,
    LogicalKeyboardKey.numpad5: 5,
    LogicalKeyboardKey.numpad6: 6,
    LogicalKeyboardKey.numpad7: 7,
    LogicalKeyboardKey.numpad8: 8,
    LogicalKeyboardKey.numpad9: 9,
  };

  /// Fernbedienung / Tastatur.
  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final c = _ctrl;
    if (c == null) return KeyEventResult.ignored;
    final k = e.logicalKey;

    // Diese Tasten wirken immer.
    if (k == LogicalKeyboardKey.channelUp || k == LogicalKeyboardKey.pageUp) {
      _zap(c.prev);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.channelDown ||
        k == LogicalKeyboardKey.pageDown) {
      _zap(c.next);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.mediaPlayPause ||
        k == LogicalKeyboardKey.space ||
        k == LogicalKeyboardKey.mediaPlay ||
        k == LogicalKeyboardKey.mediaPause) {
      c.playOrPause();
      _showOverlay();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.contextMenu || k == LogicalKeyboardKey.info) {
      _openOptions();
      return KeyEventResult.handled;
    }
    final digit = _digitKeys[k];
    if (digit != null && e is KeyDownEvent) {
      c.digit(digit);
      return KeyEventResult.handled;
    }

    // Bei ausgeblendetem Overlay: Hoch/Runter schaltet um, OK zeigt es an.
    if (!_overlay) {
      if (k == LogicalKeyboardKey.arrowUp) {
        _zap(c.prev);
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.arrowDown) {
        _zap(c.next);
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.select ||
          k == LogicalKeyboardKey.enter ||
          k == LogicalKeyboardKey.arrowLeft ||
          k == LogicalKeyboardKey.arrowRight) {
        _showOverlay();
        return KeyEventResult.handled;
      }
    } else if (k == LogicalKeyboardKey.escape ||
        k == LogicalKeyboardKey.goBack) {
      _hideOverlay();
      return KeyEventResult.handled;
    }
    // Sonst: normale Fokus-Navigation zwischen den Overlay-Knöpfen.
    if (_overlay) _showOverlay();
    return KeyEventResult.ignored;
  }

  Future<void> _openOptions() async {
    _showOverlay(autoHide: false);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _OptionsSheet(
        engine: _engine,
        audio: _audio,
        subtitles: _subs,
        fit: _fit,
        onFit: (f) => setState(() => _fit = f),
      ),
    );
    if (mounted) _showOverlay();
  }

  @override
  Widget build(BuildContext context) {
    final c = _ctrl;
    final t = AppLocalizations.of(context);
    return PopScope(
      // TV: „Zurück“ blendet zuerst das Overlay aus, beim zweiten Mal raus.
      canPop: !(_isTv && _overlay && c != null && !c.failed),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _hideOverlay();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: _onKey,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleOverlay,
            onVerticalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (c == null || !c.canZap || v.abs() < 300) return;
              _zap(v < 0 ? c.next : c.prev); // Wischen nach oben = nächster
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(child: _engine.buildView(_fit)),
                if (c != null) ...[
                  if (!c.failed && c.phase == PlaybackPhase.loading ||
                      c.reconnectAttempt > 0)
                    _Loading(reconnecting: c.reconnectAttempt > 0 && !c.failed),
                  if (c.pendingDigits.isNotEmpty)
                    _DigitDisplay(digits: c.pendingDigits),
                  _Overlay(
                    visible: _overlay,
                    controller: c,
                    onClose: () => context.pop(),
                    onOptions: _openOptions,
                    onInteract: _showOverlay,
                    onPrev: () => _zap(c.prev),
                    onNext: () => _zap(c.next),
                  ),
                  // Über dem Overlay, damit nichts die Knöpfe verdeckt.
                  if (c.failed)
                    _FailedCard(onRetry: c.retry, onClose: () => context.pop()),
                ] else
                  Center(
                    child: Semantics(
                      label: t.syncConnecting,
                      child: const _Spinner(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 40,
    child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
  );
}

class _Loading extends StatelessWidget {
  const _Loading({required this.reconnecting});
  final bool reconnecting;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final l = context.lumen;
    return IgnorePointer(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Spinner(),
            if (reconnecting) ...[
              const SizedBox(height: LumenSpace.md),
              Text(
                t.playerReconnecting,
                key: const Key('player-reconnecting'),
                style: l.text.callout.copyWith(color: Colors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FailedCard extends StatelessWidget {
  const _FailedCard({required this.onRetry, required this.onClose});
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final l = context.lumen;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: LumenCard(
          key: const Key('player-failed'),
          color: const Color(0xE61C1C1E),
          padding: const EdgeInsets.all(LumenSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.tvMinimal,
                color: Colors.white,
                size: l.isTv ? 48 : 36,
              ),
              const SizedBox(height: LumenSpace.md),
              Text(
                t.playerFailedTitle,
                textAlign: TextAlign.center,
                style: l.text.title2.copyWith(color: Colors.white),
              ),
              const SizedBox(height: LumenSpace.xs),
              Text(
                t.playerFailedBody,
                textAlign: TextAlign.center,
                style: l.text.callout.copyWith(color: const Color(0xFFB0B0B5)),
              ),
              const SizedBox(height: LumenSpace.xl),
              LumenButton(
                label: t.retry,
                icon: LucideIcons.rotateCw,
                onPressed: onRetry,
                autofocus: true,
              ),
              const SizedBox(height: LumenSpace.xs),
              LumenButton.text(label: t.playerClose, onPressed: onClose),
            ],
          ),
        ),
      ),
    );
  }
}

class _DigitDisplay extends StatelessWidget {
  const _DigitDisplay({required this.digits});
  final String digits;

  @override
  Widget build(BuildContext context) {
    final l = context.lumen;
    return Positioned(
      top: LumenSpace.x3,
      right: LumenSpace.x3,
      child: Container(
        key: const Key('player-digits'),
        padding: const EdgeInsets.symmetric(
          horizontal: LumenSpace.xl,
          vertical: LumenSpace.sm,
        ),
        decoration: BoxDecoration(
          color: const Color(0xB81C1C1E),
          borderRadius: LumenRadius.mdAll,
        ),
        child: Text(
          digits,
          style: l.text.largeTitle.copyWith(
            color: Colors.white,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// Minimales Glas-Overlay: oben Sender, Mitte Play/Pause, unten Umschalten.
class _Overlay extends StatelessWidget {
  const _Overlay({
    required this.visible,
    required this.controller,
    required this.onClose,
    required this.onOptions,
    required this.onInteract,
    required this.onPrev,
    required this.onNext,
  });

  final bool visible;
  final LivePlayerController controller;
  final VoidCallback onClose;
  final VoidCallback onOptions;
  final VoidCallback onInteract;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final l = context.lumen;
    final ch = controller.current;
    final paused = controller.phase == PlaybackPhase.paused;
    final pad = l.isTv ? l.pagePadding : const EdgeInsets.all(LumenSpace.lg);

    return IgnorePointer(
      ignoring: !visible,
      child: ExcludeFocus(
        excluding: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: context.motion(const Duration(milliseconds: 250)),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x99000000),
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0xB3000000),
                ],
                stops: [0, 0.3, 0.6, 1],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: pad,
                child: Column(
                  children: [
                    Row(
                      children: [
                        _GlassButton(
                          icon: LucideIcons.x,
                          label: t.playerClose,
                          onPressed: onClose,
                        ),
                        const SizedBox(width: LumenSpace.md),
                        ChannelLogo(
                          name: ch.name,
                          url: ch.logo,
                          width: l.isTv ? 96 : 56,
                          height: l.isTv ? 64 : 38,
                        ),
                        const SizedBox(width: LumenSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const _LiveBadge(),
                                  if (ch.num != null) ...[
                                    const SizedBox(width: LumenSpace.xs),
                                    Text(
                                      '${ch.num}',
                                      style: l.text.subhead.copyWith(
                                        color: const Color(0xFFD0D0D5),
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                ch.name,
                                key: const Key('player-channel-name'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: l.text.title2.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _GlassButton(
                          key: const Key('player-options'),
                          icon: LucideIcons.slidersHorizontal,
                          label: t.playerOptions,
                          onPressed: onOptions,
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Bei einem Fehler zeigt die Fehlerkarte die Aktionen.
                    if (!controller.failed)
                      _GlassButton(
                        key: const Key('player-playpause'),
                        icon: paused
                            ? LucideIcons600.play
                            : LucideIcons600.pause,
                        label: paused ? t.playerPlay : t.playerPause,
                        size: l.isTv ? 96 : 72,
                        autofocus: true,
                        onPressed: () {
                          controller.playOrPause();
                          onInteract();
                        },
                      ),
                    const Spacer(),
                    // Laufende und nächste Sendung (falls EPG vorhanden).
                    _OverlayEpg(epgChannelId: ch.epgChannelId),
                    if (controller.canZap)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _GlassButton(
                            key: const Key('player-prev'),
                            icon: LucideIcons.chevronUp,
                            label: t.playerPrevChannel,
                            onPressed: onPrev,
                          ),
                          const SizedBox(width: LumenSpace.lg),
                          Text(
                            t.channelPosition(
                              controller.zapper.index + 1,
                              controller.channels.length,
                            ),
                            style: l.text.subhead.copyWith(
                              color: const Color(0xFFD0D0D5),
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const SizedBox(width: LumenSpace.lg),
                          _GlassButton(
                            key: const Key('player-next'),
                            icon: LucideIcons.chevronDown,
                            label: t.playerNextChannel,
                            onPressed: onNext,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    final l = context.lumen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: l.palette.live,
        borderRadius: LumenRadius.smAll,
      ),
      child: Text(
        AppLocalizations.of(context).liveBadge,
        style: l.text.caption.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Runder Knopf mit Glas-Effekt für das Player-Overlay.
class _GlassButton extends StatelessWidget {
  const _GlassButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size,
    this.autofocus = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final double? size;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final l = context.lumen;
    final s = size ?? (l.isTv ? 64.0 : 48.0);
    return Tooltip(
      message: label,
      child: LumenPressable(
        onPressed: onPressed,
        autofocus: autofocus && l.isTv,
        borderRadius: LumenRadius.pillAll,
        focusScale: 1.1,
        semanticLabel: label,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: s,
              height: s,
              color: const Color(0x4D3A3A3C),
              child: Icon(icon, color: Colors.white, size: s * 0.45),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ton, Untertitel und Bildanpassung.
class _OptionsSheet extends StatefulWidget {
  const _OptionsSheet({
    required this.engine,
    required this.audio,
    required this.subtitles,
    required this.fit,
    required this.onFit,
  });

  final PlayerEngine engine;
  final List<TrackInfo> audio;
  final List<TrackInfo> subtitles;
  final VideoFit fit;
  final ValueChanged<VideoFit> onFit;

  @override
  State<_OptionsSheet> createState() => _OptionsSheetState();
}

class _OptionsSheetState extends State<_OptionsSheet> {
  late VideoFit _fit = widget.fit;
  late String? _audio = widget.engine.selectedAudioId;
  late String? _sub = widget.engine.selectedSubtitleId;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final l = context.lumen;
    Widget check(bool on) => on
        ? Icon(LucideIcons600.check, color: l.accent)
        : const SizedBox(width: 24);

    String fitName(VideoFit f) => switch (f) {
      VideoFit.auto => t.fitAuto,
      VideoFit.fill => t.fitFill,
      VideoFit.zoom => t.fitZoom,
      VideoFit.ratio16x9 => t.fit16x9,
      VideoFit.ratio4x3 => t.fit4x3,
    };

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            LumenSpace.md,
            0,
            LumenSpace.md,
            LumenSpace.md,
          ),
          children: [
            LumenGroup(
              title: t.playerAudio,
              children: widget.audio.isEmpty
                  ? [LumenListTile(title: t.playerNoTracks)]
                  : [
                      for (final (i, a) in widget.audio.indexed)
                        LumenListTile(
                          title: a.label(i),
                          autofocus: i == 0,
                          trailing: check(a.id == _audio),
                          onPressed: () {
                            setState(() => _audio = a.id);
                            widget.engine.setAudioTrack(a.id);
                          },
                        ),
                    ],
            ),
            const SizedBox(height: LumenSpace.lg),
            LumenGroup(
              title: t.playerSubtitles,
              children: [
                LumenListTile(
                  title: t.playerSubtitlesOff,
                  trailing: check(_sub == null),
                  onPressed: () {
                    setState(() => _sub = null);
                    widget.engine.setSubtitleTrack(null);
                  },
                ),
                for (final (i, s) in widget.subtitles.indexed)
                  LumenListTile(
                    title: s.label(i),
                    trailing: check(s.id == _sub),
                    onPressed: () {
                      setState(() => _sub = s.id);
                      widget.engine.setSubtitleTrack(s.id);
                    },
                  ),
              ],
            ),
            const SizedBox(height: LumenSpace.lg),
            LumenGroup(
              title: t.playerPicture,
              children: [
                for (final f in VideoFit.values)
                  LumenListTile(
                    key: Key('fit-${f.name}'),
                    title: fitName(f),
                    trailing: check(f == _fit),
                    onPressed: () {
                      setState(() => _fit = f);
                      widget.onFit(f);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlayEpg extends ConsumerWidget {
  const _OverlayEpg({required this.epgChannelId});

  final String? epgChannelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(channelNowNextProvider(epgChannelId)).value;
    final now = info?.now;
    if (now == null) return const SizedBox.shrink();
    final t = AppLocalizations.of(context);
    final l = context.lumen;
    final et = EpgTime(context, ref.watch(settingsProvider.select((s) => s.epgOffset)));
    final epgNow = ref.watch(epgNowProvider);
    const dim = Color(0xFFD0D0D5);
    return Padding(
      padding: const EdgeInsets.only(bottom: LumenSpace.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          key: const Key('player-epg'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(now.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: l.text.headline.copyWith(color: Colors.white)),
            const SizedBox(height: LumenSpace.xs),
            Row(
              children: [
                Text(et.time(now.startUtc),
                    style: l.text.caption.copyWith(color: dim, fontFeatures: const [FontFeature.tabularFigures()])),
                const SizedBox(width: LumenSpace.sm),
                Expanded(child: ThinProgress(value: info!.progressAt(epgNow), color: Colors.white, height: 3)),
                const SizedBox(width: LumenSpace.sm),
                Text(et.time(now.endUtc),
                    style: l.text.caption.copyWith(color: dim, fontFeatures: const [FontFeature.tabularFigures()])),
              ],
            ),
            if (info.next != null) ...[
              const SizedBox(height: LumenSpace.xs),
              Text('${t.epgNext}: ${et.time(info.next!.startUtc)} ${info.next!.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: l.text.footnote.copyWith(color: dim)),
            ],
          ],
        ),
      ),
    );
  }
}
