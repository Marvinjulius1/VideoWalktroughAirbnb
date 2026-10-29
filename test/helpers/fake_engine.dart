import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:lumen/features/player/playable.dart';
import 'package:lumen/features/player/player_engine.dart';

/// Video-Motor für Tests: spielt nichts ab, merkt sich aber alles und
/// lässt sich von außen in jeden Zustand versetzen.
class FakeEngine implements PlayerEngine {
  final opened = <PlayableStream>[];
  final _phase = StreamController<PlaybackPhase>.broadcast(sync: true);
  final _audio = StreamController<List<TrackInfo>>.broadcast();
  final _subs = StreamController<List<TrackInfo>>.broadcast();
  PlaybackPhase _current = PlaybackPhase.idle;
  bool disposed = false;
  String? audioId;
  String? subtitleId;

  /// Automatisch nach `open` in diesen Zustand wechseln.
  PlaybackPhase afterOpen = PlaybackPhase.playing;

  void emit(PlaybackPhase p) {
    _current = p;
    _phase.add(p);
  }

  void emitTracks(List<TrackInfo> audio, List<TrackInfo> subs) {
    _audio.add(audio);
    _subs.add(subs);
  }

  @override
  Stream<PlaybackPhase> get phase => _phase.stream;
  @override
  PlaybackPhase get currentPhase => _current;
  @override
  Stream<String> get errors => const Stream.empty();
  @override
  Stream<List<TrackInfo>> get audioTracks => _audio.stream;
  @override
  Stream<List<TrackInfo>> get subtitleTracks => _subs.stream;
  @override
  String? get selectedAudioId => audioId;
  @override
  String? get selectedSubtitleId => subtitleId;

  @override
  Future<void> open(PlayableStream stream) async {
    opened.add(stream);
    emit(PlaybackPhase.loading);
    emit(afterOpen);
  }

  @override
  Future<void> playOrPause() async =>
      emit(_current == PlaybackPhase.playing ? PlaybackPhase.paused : PlaybackPhase.playing);

  @override
  Future<void> stop() async => emit(PlaybackPhase.idle);

  @override
  Future<void> setAudioTrack(String id) async => audioId = id;

  @override
  Future<void> setSubtitleTrack(String? id) async => subtitleId = id;

  @override
  Widget buildView(VideoFit fit) => ColoredBox(
        key: ValueKey('fake-video-${fit.name}'),
        color: const Color(0xFF101010),
      );

  @override
  Future<void> dispose() async => disposed = true;
}
