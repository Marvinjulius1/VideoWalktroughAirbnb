import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/db/database.dart';
import 'channel_zapper.dart';
import 'playable.dart';
import 'player_engine.dart';

/// Steuert die Live-Wiedergabe: welcher Sender läuft, Umschalten,
/// Zifferneingabe und automatische Wiederverbindung.
class LivePlayerController extends ChangeNotifier {
  LivePlayerController({
    required this.engine,
    required this.channels,
    required int startIndex,
    required this.resolve,
    this.onWatched,
    this.zapDelay = const Duration(milliseconds: 280),
    this.digitTimeout = const Duration(milliseconds: 1600),
    this.retryDelays = const [Duration(seconds: 1), Duration(seconds: 3), Duration(seconds: 6)],
  }) : zapper = ChannelZapper(numbers: [for (final c in channels) c.num], start: startIndex) {
    _phaseSub = engine.phase.listen(_onPhase);
  }

  final PlayerEngine engine;
  final List<ChannelRow> channels;
  final PlayableStream? Function(ChannelRow) resolve;
  final void Function(ChannelRow)? onWatched;

  /// Beim schnellen Durchschalten wird erst nach dieser Pause geöffnet –
  /// so lädt nicht jeder übersprungene Sender einen Stream.
  final Duration zapDelay;
  final Duration digitTimeout;
  final List<Duration> retryDelays;
  final ChannelZapper zapper;

  StreamSubscription<PlaybackPhase>? _phaseSub;
  Timer? _zapTimer;
  Timer? _digitTimer;
  Timer? _retryTimer;
  int _attempt = 0;
  bool _failed = false;
  bool _disposed = false;
  PlaybackPhase _phase = PlaybackPhase.idle;

  ChannelRow get current => channels[zapper.index];
  PlaybackPhase get phase => _phase;

  /// Wie oft gerade automatisch neu verbunden wird (0 = gar nicht).
  int get reconnectAttempt => _attempt;

  /// Alle automatischen Versuche sind gescheitert.
  bool get failed => _failed;
  String get pendingDigits => zapper.pendingDigits;
  bool get canZap => channels.length > 1;

  Future<void> start() => _open();

  void next() => _zapTo(zapper.next());
  void prev() => _zapTo(zapper.prev());
  void lastChannel() => _zapTo(zapper.lastChannel());
  void select(int i) => _zapTo(zapper.select(i));

  void digit(int d) {
    zapper.addDigit(d);
    _digitTimer?.cancel();
    _digitTimer = Timer(digitTimeout, commitDigits);
    notifyListeners();
  }

  void commitDigits() {
    _digitTimer?.cancel();
    final before = zapper.index;
    final i = zapper.commitDigits();
    if (i != null && i != before) {
      _zapTo(i);
    } else {
      notifyListeners();
    }
  }

  /// Nach endgültigem Fehler: noch einmal von vorn versuchen.
  Future<void> retry() {
    _attempt = 0;
    _failed = false;
    return _open();
  }

  Future<void> playOrPause() => engine.playOrPause();

  void _zapTo(int _) {
    _retryTimer?.cancel();
    _attempt = 0;
    _failed = false;
    notifyListeners();
    _zapTimer?.cancel();
    _zapTimer = Timer(zapDelay, _open);
  }

  Future<void> _open() async {
    if (_disposed) return;
    _retryTimer?.cancel();
    final channel = current;
    final stream = resolve(channel);
    if (stream == null) {
      _failed = true;
      notifyListeners();
      return;
    }
    _phase = PlaybackPhase.loading;
    notifyListeners();
    await engine.open(stream);
    onWatched?.call(channel);
  }

  void _onPhase(PlaybackPhase p) {
    if (_disposed) return;
    _phase = p;
    if (p == PlaybackPhase.playing) {
      _attempt = 0;
      _failed = false;
    } else if (p == PlaybackPhase.error && !_failed) {
      // Stream abgebrochen oder nicht ladbar → automatisch neu verbinden.
      if (_attempt < retryDelays.length) {
        final delay = retryDelays[_attempt];
        _attempt++;
        _retryTimer?.cancel();
        _retryTimer = Timer(delay, _open);
      } else {
        _failed = true;
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _zapTimer?.cancel();
    _digitTimer?.cancel();
    _retryTimer?.cancel();
    _phaseSub?.cancel();
    super.dispose();
  }
}
