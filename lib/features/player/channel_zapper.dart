/// Logik fürs Umschalten zwischen Sendern – ohne Flutter, damit sie sich
/// leicht testen lässt.
///
/// - Hoch/Runter springt zum vorherigen/nächsten Sender (am Ende wieder
///   von vorn).
/// - „Letzter Sender“ springt zwischen den beiden zuletzt gesehenen hin und
///   her.
/// - Zifferneingabe: Ziffern sammeln, nach kurzer Pause zum Sender mit
///   dieser Nummer springen (oder, falls es keine Nummern gibt, zur
///   Position in der Liste).
class ChannelZapper {
  ChannelZapper({required this.numbers, required int start})
      : assert(numbers.isNotEmpty),
        _index = start.clamp(0, numbers.length - 1);

  /// Kanalnummer je Listenposition (`null`, wenn die Quelle keine hat).
  final List<int?> numbers;

  int _index;
  int? _previous;
  String _digits = '';

  int get index => _index;
  int? get previous => _previous;
  String get pendingDigits => _digits;
  int get length => numbers.length;

  int next() => _goTo((_index + 1) % length);
  int prev() => _goTo((_index - 1 + length) % length);

  /// Zurück zum vorher gesehenen Sender (falls es einen gibt).
  int lastChannel() => _previous == null ? _index : _goTo(_previous!);

  int select(int i) => _goTo(i.clamp(0, length - 1));

  /// Eine Ziffer hinzufügen (max. 5 Stellen).
  void addDigit(int d) {
    if (_digits.length >= 5) return;
    _digits += '$d';
  }

  /// Gesammelte Ziffern auswerten. Gibt den neuen Index zurück oder
  /// `null`, wenn es keinen passenden Sender gibt.
  int? commitDigits() {
    final n = int.tryParse(_digits);
    _digits = '';
    if (n == null) return null;
    final byNumber = numbers.indexOf(n);
    if (byNumber >= 0) return _goTo(byNumber);
    final hasNumbers = numbers.any((x) => x != null);
    if (!hasNumbers && n >= 1 && n <= length) return _goTo(n - 1);
    return null;
  }

  void clearDigits() => _digits = '';

  int _goTo(int i) {
    if (i != _index) {
      _previous = _index;
      _index = i;
    }
    return _index;
  }
}
