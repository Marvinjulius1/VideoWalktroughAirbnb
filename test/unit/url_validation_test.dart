import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/features/sources/domain/url_validation.dart';

void main() {
  group('normalizeServerUrl', () {
    String? ok(String s) => normalizeServerUrl(s).url;
    UrlProblem? fail(String s) => normalizeServerUrl(s).problem;

    test('ergänzt http:// und behält den Port', () {
      expect(ok('server.example:8080'), 'http://server.example:8080');
    });

    test('behält https', () {
      expect(ok('https://server.example'), 'https://server.example');
    });

    test('entfernt Leerzeichen und Schrägstriche am Ende', () {
      expect(ok('  http://server.example:80/  '), 'http://server.example');
    });

    test('entfernt mitkopierte API-Pfade und Parameter', () {
      expect(
        ok('http://server.example:8080/player_api.php?username=a&password=b'),
        'http://server.example:8080',
      );
      expect(ok('http://server.example/get.php?username=a'), 'http://server.example');
    });

    test('behält einen Unterpfad', () {
      expect(ok('http://server.example/iptv/'), 'http://server.example/iptv');
    });

    test('erlaubt IP-Adressen und Namen im Heimnetz', () {
      expect(ok('192.168.0.10:25461'), 'http://192.168.0.10:25461');
      expect(ok('nas:8000'), 'http://nas:8000');
    });

    test('lehnt leere Eingaben ab', () {
      expect(fail(''), UrlProblem.empty);
      expect(fail('   '), UrlProblem.empty);
    });

    test('lehnt andere Schemata ab', () {
      expect(fail('ftp://server.example'), UrlProblem.scheme);
      expect(fail('rtmp://server.example'), UrlProblem.scheme);
    });

    test('lehnt ungültige Ports ab', () {
      expect(fail('http://server.example:99999'), UrlProblem.port);
      expect(fail('http://server.example:0'), UrlProblem.port);
      expect(fail('http://server.example:'), UrlProblem.port);
    });

    test('lehnt Unsinn ab', () {
      expect(fail('http://'), UrlProblem.invalid);
      expect(fail('server mit leerzeichen'), UrlProblem.invalid);
    });
  });

  group('validateResourceUrl', () {
    test('lässt Pfad und Parameter unverändert', () {
      const url = 'https://example.org/list.m3u?token=abc&type=m3u_plus';
      expect(validateResourceUrl(url).url, url);
    });

    test('verlangt ein Schema', () {
      expect(validateResourceUrl('example.org/list.m3u').problem, UrlProblem.scheme);
    });

    test('optional: leer ist erlaubt', () {
      final r = validateResourceUrl('  ', optional: true);
      expect(r.isValid, isTrue);
      expect(r.url, '');
    });

    test('nicht optional: leer ist ein Fehler', () {
      expect(validateResourceUrl('').problem, UrlProblem.empty);
    });
  });
}
