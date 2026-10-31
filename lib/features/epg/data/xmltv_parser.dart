import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:xml/xml_events.dart';

/// Eine Sendung aus XMLTV. Zeiten immer in UTC.
class EpgProgramme {
  const EpgProgramme({
    required this.channelId,
    required this.start,
    required this.end,
    required this.title,
    this.description,
    this.category,
  });

  final String channelId;
  final DateTime start;
  final DateTime end;
  final String title;
  final String? description;
  final String? category;
}

class XmltvResult {
  const XmltvResult({required this.programmes, required this.channelNames});

  final List<EpgProgramme> programmes;

  /// XMLTV-Kanal-ID → Anzeigename (für Zuordnung ohne `tvg-id`).
  final Map<String, String> channelNames;
}

/// Liest XMLTV als Ereignis-Strom (SAX-artig): Die Datei muss nie komplett
/// im Speicher liegen. Sendungen außerhalb von [from]…[to] werden direkt
/// verworfen.
class XmltvParser {
  XmltvParser({required this.from, required this.to, this.channels});

  final DateTime from;
  final DateTime to;

  /// Wenn gesetzt: nur Sendungen dieser Kanal-IDs behalten (spart viel
  /// Speicher, wenn die XMLTV-Datei tausende fremde Kanäle enthält).
  final Set<String>? channels;

  final _programmes = <EpgProgramme>[];
  final _names = <String, String>{};

  // Zustand des gerade gelesenen Elements.
  String? _pChannel;
  DateTime? _pStart;
  DateTime? _pEnd;
  String? _title;
  String? _desc;
  String? _category;
  String? _channelId;
  String? _field; // title | desc | category | display-name
  final _text = StringBuffer();

  void add(XmlEvent e) {
    switch (e) {
      case XmlStartElementEvent(:final name, :final attributes, :final isSelfClosing):
        if (name == 'programme') {
          String? attr(String n) => attributes.where((a) => a.name == n).firstOrNull?.value;
          _pChannel = attr('channel');
          _pStart = parseXmltvTime(attr('start'));
          _pEnd = parseXmltvTime(attr('stop'));
          _title = _desc = _category = null;
        } else if (name == 'channel') {
          _channelId = attributes.where((a) => a.name == 'id').firstOrNull?.value;
        } else if (!isSelfClosing &&
            (name == 'title' || name == 'desc' || name == 'category' || name == 'display-name')) {
          _field = name;
          _text.clear();
        }
      case XmlTextEvent(:final value) || XmlCDATAEvent(:final value):
        if (_field != null) _text.write(value);
      case XmlEndElementEvent(:final name):
        if (name == _field) {
          final v = _text.toString().trim();
          // Bei mehreren Sprachen gewinnt die erste Angabe.
          if (v.isNotEmpty) {
            switch (name) {
              case 'title':
                _title ??= v;
              case 'desc':
                _desc ??= v;
              case 'category':
                _category ??= v;
              case 'display-name':
                if (_channelId != null) _names.putIfAbsent(_channelId!, () => v);
            }
          }
          _field = null;
        } else if (name == 'programme') {
          _finishProgramme();
        } else if (name == 'channel') {
          _channelId = null;
        }
      default:
        break;
    }
  }

  void _finishProgramme() {
    final ch = _pChannel, s = _pStart, end = _pEnd;
    _pChannel = null;
    if (ch == null || s == null || end == null || !end.isAfter(s)) return;
    if (end.isBefore(from) || s.isAfter(to)) return;
    if (channels != null && !channels!.contains(ch)) return;
    _programmes.add(EpgProgramme(
      channelId: ch,
      start: s,
      end: end,
      title: _title ?? '',
      description: _desc,
      category: _category,
    ));
  }

  XmltvResult finish() => XmltvResult(programmes: _programmes, channelNames: _names);

  /// Liest eine Datei – auch gzip-komprimiert (`.xml.gz` ist sehr üblich).
  /// Gedacht für den Aufruf in einem Isolate.
  static Future<XmltvResult> parseFile(
    String path, {
    required DateTime from,
    required DateTime to,
    Set<String>? channels,
  }) async {
    final file = File(path);
    final head = await file.openRead(0, 2).fold<List<int>>([], (a, b) => a..addAll(b));
    final gz = head.length == 2 && head[0] == 0x1f && head[1] == 0x8b;
    Stream<List<int>> bytes = file.openRead();
    if (gz) bytes = bytes.transform(gzip.decoder);
    return parseStream(bytes, from: from, to: to, channels: channels);
  }

  static Future<XmltvResult> parseStream(
    Stream<List<int>> bytes, {
    required DateTime from,
    required DateTime to,
    Set<String>? channels,
  }) async {
    final p = XmltvParser(from: from, to: to, channels: channels);
    await for (final events in bytes
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(XmlEventDecoder())
        .transform(const XmlNormalizeEvents())) {
      events.forEach(p.add);
    }
    return p.finish();
  }

  static XmltvResult parseString(String xml, {required DateTime from, required DateTime to}) {
    final p = XmltvParser(from: from, to: to);
    parseEvents(xml).forEach(p.add);
    return p.finish();
  }
}

final _timeRe = RegExp(r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})?\s*([+-]\d{2}:?\d{2})?');

/// XMLTV-Zeit wie `20260101203000 +0100` → UTC. Ohne Zeitzonenangabe gilt
/// UTC (so schreibt es der Standard vor).
DateTime? parseXmltvTime(String? s) {
  if (s == null) return null;
  final m = _timeRe.firstMatch(s.trim());
  if (m == null) return null;
  int g(int i) => int.parse(m.group(i)!);
  final utc = DateTime.utc(g(1), g(2), g(3), g(4), g(5), m.group(6) == null ? 0 : g(6));
  final tz = m.group(7);
  if (tz == null) return utc;
  final digits = tz.replaceAll(':', '');
  final sign = digits.startsWith('-') ? -1 : 1;
  final offset = Duration(
    hours: int.parse(digits.substring(1, 3)),
    minutes: int.parse(digits.substring(3, 5)),
  );
  return utc.subtract(offset * sign);
}
