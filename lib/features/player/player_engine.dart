import 'dart:async';

import 'package:flutter/widgets.dart';

import 'playable.dart';

/// Was der Player gerade tut.
enum PlaybackPhase { idle, loading, playing, paused, error }

@immutable
class TrackInfo {
  const TrackInfo({required this.id, this.title, this.language});

  final String id;
  final String? title;
  final String? language;

  String label(int index) =>
      [title, language?.toUpperCase()].whereType<String>().where((s) => s.isNotEmpty).join(' · ')
          .ifEmpty('${index + 1}');
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

/// Seitenverhältnis bzw. Bildanpassung.
enum VideoFit { auto, fill, zoom, ratio16x9, ratio4x3 }

/// Schnittstelle zum eigentlichen Video-Motor.
///
/// **Warum eine eigene Schnittstelle?** Die Oberfläche kennt nur diese
/// Klasse. Sollte media_kit auf einem Gerät (z. B. schwacher Fire-TV-Stick)
/// Probleme machen, können wir einen anderen Motor (ExoPlayer, AVPlayer)
/// einsetzen, ohne die UI anzufassen. Und in Tests nutzen wir einen
/// Fake-Motor ohne echtes Video.
abstract class PlayerEngine {
  Stream<PlaybackPhase> get phase;
  PlaybackPhase get currentPhase;

  /// Technischer Fehlertext des Motors (nur für Diagnose, nie anzeigen).
  Stream<String> get errors;

  Stream<List<TrackInfo>> get audioTracks;
  Stream<List<TrackInfo>> get subtitleTracks;
  String? get selectedAudioId;
  String? get selectedSubtitleId;

  Future<void> open(PlayableStream stream);
  Future<void> playOrPause();
  Future<void> stop();
  Future<void> setAudioTrack(String id);

  /// `null` = Untertitel aus.
  Future<void> setSubtitleTrack(String? id);

  Widget buildView(VideoFit fit);

  Future<void> dispose();
}
