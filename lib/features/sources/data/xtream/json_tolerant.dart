/// Tolerante Leser für JSON von Xtream-Servern.
///
/// Xtream-Server (und ihre vielen Nachbauten) liefern dieselben Felder mal
/// als Zahl, mal als Text, mal als `null`, `""` oder sogar als Liste. Statt
/// abzustürzen, liefern diese Helfer einfach `null`, wenn ein Wert nicht
/// passt.
library;

String? jStr(Object? v) {
  if (v == null) return null;
  if (v is String) {
    final s = v.trim();
    return s.isEmpty ? null : s;
  }
  if (v is num || v is bool) return '$v';
  return null;
}

int? jInt(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.isFinite ? v.round() : null;
  if (v is bool) return v ? 1 : 0;
  if (v is String) {
    final s = v.trim();
    return int.tryParse(s) ?? double.tryParse(s.replaceAll(',', '.'))?.round();
  }
  return null;
}

double? jDouble(Object? v) {
  if (v == null) return null;
  if (v is num) return v.isFinite ? v.toDouble() : null;
  if (v is String) return double.tryParse(v.trim().replaceAll(',', '.'));
  return null;
}

bool jBool(Object? v) {
  final i = jInt(v);
  if (i != null) return i != 0;
  if (v is String) return v.toLowerCase() == 'true';
  return false;
}

/// Unix-Zeitstempel (Sekunden) als Text oder Zahl → UTC-Zeit.
DateTime? jUnix(Object? v) {
  final i = jInt(v);
  if (i == null || i <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(i * 1000, isUtc: true);
}

/// Datum wie „2024-05-01“, „2024“ oder „01.05.2024“ → Jahr.
int? jYear(Object? v) {
  final s = jStr(v);
  if (s == null) return null;
  final m = RegExp(r'(19|20)\d{2}').firstMatch(s);
  return m == null ? null : int.parse(m.group(0)!);
}

Map<String, dynamic> jMap(Object? v) =>
    v is Map ? v.map((k, val) => MapEntry('$k', val)) : const {};

List<dynamic> jList(Object? v) {
  if (v is List) return v;
  // Manche Server liefern Listen als Map {"0": …, "1": …}.
  if (v is Map) return v.values.toList();
  return const [];
}

/// Erstes nicht-leeres Element einer Liste oder der Wert selbst als Text.
String? jFirstStr(Object? v) {
  if (v is List) {
    for (final e in v) {
      final s = jStr(e);
      if (s != null) return s;
    }
    return null;
  }
  return jStr(v);
}
