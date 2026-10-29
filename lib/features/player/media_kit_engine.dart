import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'playable.dart';
import 'player_engine.dart';

/// [PlayerEngine] auf Basis von media_kit (libmpv).
///
/// libmpv spielt praktisch alle IPTV-Formate (MPEG-TS, HLS, MKV, AC3 …)
/// und liefert mehrere Audiospuren und Untertitel.
class MediaKitEngine implements PlayerEngine {
  MediaKitEngine({int bufferMb = 32, bool hardwareDecoding = true})
      : _player = Player(
          configuration: PlayerConfiguration(
            bufferSize: bufferMb * 1024 * 1024,
            title: 'Lumen',
            // Kein Logging der Adresse: mpv-Logs bleiben aus.
            logLevel: MPVLogLevel.error,
          ),
        ) {
    _controller = VideoController(
      _player,
      configuration: VideoControllerConfiguration(
        enableHardwareAcceleration: hardwareDecoding,
      ),
    );
    _subs.addAll([
      _player.stream.buffering.listen((b) {
        if (b) {
          _setPhase(PlaybackPhase.loading);
        } else if (_player.state.playing) {
          _setPhase(PlaybackPhase.playing);
        }
      }),
      _player.stream.playing.listen((p) {
        if (_phase == PlaybackPhase.error) return;
        if (p && !_player.state.buffering) _setPhase(PlaybackPhase.playing);
        if (!p && _phase == PlaybackPhase.playing) _setPhase(PlaybackPhase.paused);
      }),
      _player.stream.error.listen((e) {
        _errors.add(e);
        _setPhase(PlaybackPhase.error);
      }),
      _player.stream.completed.listen((done) {
        // Bei Live-TV heißt „zu Ende“ fast immer: Verbindung abgebrochen.
        if (done) _setPhase(PlaybackPhase.error);
      }),
      _player.stream.tracks.listen((t) {
        _audio.add(_real(t.audio));
        _subtitles.add(_real(t.subtitle));
      }),
    ]);
  }

  final Player _player;
  late final VideoController _controller;
  final _subs = <StreamSubscription<Object?>>[];
  final _phaseCtrl = StreamController<PlaybackPhase>.broadcast();
  final _errors = StreamController<String>.broadcast();
  final _audio = StreamController<List<TrackInfo>>.broadcast();
  final _subtitles = StreamController<List<TrackInfo>>.broadcast();
  PlaybackPhase _phase = PlaybackPhase.idle;

  void _setPhase(PlaybackPhase p) {
    if (p == _phase) return;
    _phase = p;
    _phaseCtrl.add(p);
  }

  /// „auto“ und „no“ sind mpv-interne Pseudo-Spuren.
  static List<TrackInfo> _real(List<dynamic> tracks) => [
        for (final t in tracks)
          if (t.id != 'auto' && t.id != 'no')
            TrackInfo(id: t.id as String, title: t.title as String?, language: t.language as String?),
      ];

  @override
  Stream<PlaybackPhase> get phase => _phaseCtrl.stream;
  @override
  PlaybackPhase get currentPhase => _phase;
  @override
  Stream<String> get errors => _errors.stream;
  @override
  Stream<List<TrackInfo>> get audioTracks => _audio.stream;
  @override
  Stream<List<TrackInfo>> get subtitleTracks => _subtitles.stream;
  @override
  String? get selectedAudioId => _player.state.track.audio.id;
  @override
  String? get selectedSubtitleId {
    final id = _player.state.track.subtitle.id;
    return id == 'no' ? null : id;
  }

  @override
  Future<void> open(PlayableStream stream) async {
    _setPhase(PlaybackPhase.loading);
    await _player.open(Media(stream.uri.toString(), httpHeaders: stream.headers));
  }

  @override
  Future<void> playOrPause() => _player.playOrPause();

  @override
  Future<void> stop() async {
    await _player.stop();
    _setPhase(PlaybackPhase.idle);
  }

  @override
  Future<void> setAudioTrack(String id) async {
    final t = _player.state.tracks.audio.where((a) => a.id == id).firstOrNull;
    if (t != null) await _player.setAudioTrack(t);
  }

  @override
  Future<void> setSubtitleTrack(String? id) async {
    if (id == null) return _player.setSubtitleTrack(SubtitleTrack.no());
    final t = _player.state.tracks.subtitle.where((s) => s.id == id).firstOrNull;
    if (t != null) await _player.setSubtitleTrack(t);
  }

  @override
  Widget buildView(VideoFit fit) => Video(
        controller: _controller,
        controls: NoVideoControls,
        fit: switch (fit) {
          VideoFit.fill => BoxFit.fill,
          VideoFit.zoom => BoxFit.cover,
          _ => BoxFit.contain,
        },
        aspectRatio: switch (fit) {
          VideoFit.ratio16x9 => 16 / 9,
          VideoFit.ratio4x3 => 4 / 3,
          _ => null,
        },
      );

  @override
  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await _player.dispose();
    await _phaseCtrl.close();
    await _errors.close();
    await _audio.close();
    await _subtitles.close();
  }
}
