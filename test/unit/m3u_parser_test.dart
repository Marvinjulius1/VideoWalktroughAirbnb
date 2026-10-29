import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/features/sources/data/m3u/m3u_parser.dart';

import '../mock_server/mock_server.dart';

void main() {
  group('M3uParser', () {
    test('liest Attribute, Titel, Gruppe und EPG-Kopfzeile', () {
      final p = M3uParser.parseString(sampleM3u(2));
      expect(p.epgUrl, 'http://127.0.0.1/epg.xml');
      final first = p.entries.first;
      expect(first.name, 'Testkanal 1');
      expect(first.tvgId, 'test1.de');
      expect(first.tvgName, 'Testkanal 1');
      expect(first.logo, 'http://127.0.0.1/logo/1.png');
      expect(first.group, 'Nachrichten');
      expect(first.channelNumber, 1);
      expect(first.url, 'http://127.0.0.1/live/1.ts');
      expect(first.kind, M3uKind.live);
    });

    test('erkennt Filme und Serien an Pfad und Endung', () {
      final p = M3uParser.parseString(sampleM3u(1));
      final kinds = {for (final e in p.entries) e.name: e.kind};
      expect(kinds['Testfilm A'], M3uKind.movie);
      expect(kinds['Testfilm B'], M3uKind.movie);
      expect(kinds['Testserie S01 E01'], M3uKind.series);
    });

    test('Komma im Attributwert trennt den Titel nicht ab', () {
      final p = M3uParser.parseString(
          '#EXTM3U\n#EXTINF:-1 group-title="Nachrichten, regional",Kanal A\nhttp://x/1.ts\n');
      expect(p.entries.single.group, 'Nachrichten, regional');
      expect(p.entries.single.name, 'Kanal A');
    });

    test('Titel mit Komma bleibt vollständig', () {
      final p = M3uParser.parseString('#EXTINF:-1,Hallo, Welt\nhttp://x/1.ts');
      expect(p.entries.single.name, 'Hallo, Welt');
    });

    test('BOM, CRLF, Leerzeilen und einfache Anführungszeichen', () {
      final p = M3uParser.parseString(
          "﻿#EXTM3U\r\n\r\n#EXTINF:-1 tvg-id='a.b' group-title=Ohne,Kanal\r\nhttp://x/a.ts\r\n");
      final e = p.entries.single;
      expect(e.tvgId, 'a.b');
      expect(e.group, 'Ohne');
      expect(e.url, 'http://x/a.ts');
    });

    test('#EXTGRP und #EXTVLCOPT werden übernommen', () {
      final p = M3uParser.parseString('#EXTM3U\n'
          '#EXTINF:-1,Kanal\n#EXTGRP:Gruppe X\n'
          '#EXTVLCOPT:http-user-agent=TestAgent/1.0\n'
          '#EXTVLCOPT:http-referrer=http://ref\n'
          '#KODIPROP:inputstream=x\n'
          'http://x/k.m3u8\n');
      final e = p.entries.single;
      expect(e.group, 'Gruppe X');
      expect(e.userAgent, 'TestAgent/1.0');
      expect(e.referrer, 'http://ref');
      expect(e.kind, M3uKind.live);
    });

    test('Catch-up-Attribute', () {
      final p = M3uParser.parseString(
          '#EXTINF:-1 catchup="default" catchup-days="3" catchup-source="?utc={utc}",K\nhttp://x/1.ts');
      final e = p.entries.single;
      expect(e.catchupDays, 3);
      expect(e.catchupMode, 'default');
      expect(e.catchupSource, '?utc={utc}');
    });

    test('URL ohne #EXTINF bekommt den Dateinamen als Namen', () {
      final p = M3uParser.parseString('#EXTM3U\nhttp://x/pfad/Mein%20Kanal.ts\n');
      expect(p.entries.single.name, 'Mein Kanal.ts');
    });

    test('Müll wird übersprungen statt abzustürzen', () {
      final p = M3uParser.parseString('#EXTM3U\n#EXTINF:-1,Ohne URL\n#EXTINF:-1,Mit\n'
          'das ist keine url\n#EXTINF:-1,Gut\nhttp://x/g.ts\n');
      expect(p.entries.map((e) => e.name), ['Gut']);
      expect(p.skippedLines, greaterThan(0));
    });

    test('stabiler Schlüssel', () {
      final a = M3uParser.parseString(sampleM3u(3)).entries;
      final b = M3uParser.parseString(sampleM3u(3)).entries;
      expect(a.map((e) => e.key), b.map((e) => e.key));
      expect(a.map((e) => e.key).toSet(), hasLength(a.length));
    });

    test('100.000 Einträge in vertretbarer Zeit', () {
      final content = sampleM3u(100000);
      final sw = Stopwatch()..start();
      final p = M3uParser.parseString(content);
      sw.stop();
      expect(p.entries.length, 100003);
      // Großzügige Grenze für langsame CI-Rechner; lokal ~1 s.
      expect(sw.elapsed, lessThan(const Duration(seconds: 8)));
      // ignore: avoid_print
      print('M3U 100k: ${sw.elapsedMilliseconds} ms');
    });
  });
}
