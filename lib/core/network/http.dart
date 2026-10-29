import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';

/// Erzeugt den HTTP-Client für Quellen.
///
/// - Kurzer Verbindungs-Timeout (Server tot → schnell Bescheid geben),
///   langer Empfangs-Timeout (große Senderlisten brauchen Zeit).
/// - Automatische Wiederholung bei Netzwerkfehlern und 5xx – nicht bei 4xx,
///   denn falsche Zugangsdaten werden durch Wiederholen nicht richtig.
/// - **Kein Logging-Interceptor**: Xtream-URLs enthalten Benutzername und
///   Passwort und dürfen nie in Logs landen.
Dio createSourceDio({
  Duration connectTimeout = const Duration(seconds: 12),
  Duration receiveTimeout = const Duration(seconds: 90),
  int retries = 2,
  Duration retryBaseDelay = const Duration(milliseconds: 600),
}) {
  final dio = Dio(BaseOptions(
    connectTimeout: connectTimeout,
    receiveTimeout: receiveTimeout,
    sendTimeout: const Duration(seconds: 15),
    followRedirects: true,
    maxRedirects: 5,
    headers: {'User-Agent': 'Lumen/0.1 (Flutter)', 'Accept': '*/*'},
  ));
  dio.interceptors.add(RetryInterceptor(dio, retries: retries, baseDelay: retryBaseDelay));
  return dio;
}

class RetryInterceptor extends Interceptor {
  RetryInterceptor(this._dio, {required this.retries, required this.baseDelay});

  final Dio _dio;
  final int retries;
  final Duration baseDelay;

  static const _attemptKey = 'lumen_retry_attempt';

  static bool shouldRetry(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.transformTimeout:
        return true;
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode ?? 0;
        return code >= 500 || code == 429;
      case DioExceptionType.unknown:
        return e.error is! FormatException;
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
        return false;
    }
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final attempt = (err.requestOptions.extra[_attemptKey] as int?) ?? 0;
    // Streams (Downloads) lassen sich nicht sicher wiederholen.
    final isStream = err.requestOptions.responseType == ResponseType.stream;
    if (attempt >= retries || isStream || !shouldRetry(err)) {
      return handler.next(err);
    }
    // Exponentielles Backoff: 0,6 s, 1,2 s, 2,4 s …
    final delay = baseDelay * math.pow(2, attempt).toInt();
    await Future<void>.delayed(delay);
    final options = err.requestOptions..extra[_attemptKey] = attempt + 1;
    try {
      final response = await _dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
