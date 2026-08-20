import 'dart:convert';
import 'dart:io';

import '../models/torbox_models.dart';
import 'app_settings_repository.dart';

/// Shared TMDB transport for metadata, search, and provider discovery.
///
/// WARP is a device-level route, so the app cannot turn it on itself. When a
/// network still blocks TMDB, the direct request is followed by the same
/// public proxy fallbacks used by the original app. A successful JSON response
/// always wins; HTML block pages are rejected instead of being parsed.
class TmdbHttpService {
  TmdbHttpService({AppSettingsRepository? settingsRepository})
      : _settingsRepository = settingsRepository ?? AppSettingsRepository();

  static const String apiKey = 'cd45143a9ade518a4381e765c719e68b';
  static const String apiHost = 'api.themoviedb.org';
  static const String apiPath = '/3';

  // Keep direct/WARP first. Proxies are only used when the route itself fails.
  static const List<String> _proxyPrefixes = <String>[
    'https://api.allorigins.win/raw?url=',
    'https://corsproxy.io/?url=',
    'https://api.codetabs.com/v1/proxy?quest=',
  ];

  final AppSettingsRepository _settingsRepository;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String> params = const <String, String>{},
    AppSettings? settings,
  }) async {
    final AppSettings effectiveSettings =
        settings ?? await _settingsRepository.loadSettings();
    final Uri directUri = Uri.https(
      apiHost,
      '$apiPath$path'.replaceAll('//', '/'),
      <String, String>{
        'api_key': _effectiveApiKey(effectiveSettings),
        ...params,
      },
    );

    Object? lastError;
    try {
      return await _fetchJson(directUri, timeout: const Duration(seconds: 12));
    } catch (error) {
      lastError = error;
      if (!_shouldTryProxy(error)) {
        rethrow;
      }
    }

    for (final String prefix in _proxyPrefixes) {
      try {
        final Uri proxyUri = Uri.parse(
          '$prefix${Uri.encodeComponent(directUri.toString())}',
        );
        return await _fetchJson(
          proxyUri,
          timeout: const Duration(seconds: 10),
        );
      } catch (error) {
        lastError = error;
      }
    }

    throw lastError ?? HttpException('TMDB request failed.', uri: directUri);
  }

  String _effectiveApiKey(AppSettings settings) {
    final String personal = (settings.tmdbApiKey ?? '').trim();
    return personal.isEmpty ? apiKey : personal;
  }

  bool _shouldTryProxy(Object error) {
    if (error is _TmdbHttpException) {
      return error.statusCode == HttpStatus.forbidden ||
          error.statusCode == HttpStatus.tooManyRequests ||
          error.statusCode >= 500;
    }
    return true;
  }

  Future<Map<String, dynamic>> _fetchJson(
    Uri uri, {
    required Duration timeout,
  }) async {
    final HttpClient client = HttpClient()
      ..connectionTimeout = timeout
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;

    try {
      final HttpClientRequest request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Streamed/1.0 (Android; TMDB metadata client)',
      );

      final HttpClientResponse response =
          await request.close().timeout(timeout);
      final String raw = await response.transform(utf8.decoder).join();
      if (response.statusCode != HttpStatus.ok) {
        throw _TmdbHttpException(response.statusCode, uri);
      }

      final String contentType =
          response.headers.contentType?.mimeType.toLowerCase() ?? '';
      if (contentType.contains('html') || raw.trimLeft().startsWith('<')) {
        throw _TmdbHttpException(HttpStatus.badGateway, uri);
      }

      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('TMDB returned an invalid JSON object.');
      }
      return decoded;
    } finally {
      client.close(force: true);
    }
  }
}

class _TmdbHttpException implements Exception {
  const _TmdbHttpException(this.statusCode, this.uri);

  final int statusCode;
  final Uri uri;

  @override
  String toString() =>
      'TMDB request failed with status $statusCode (route: ${uri.host})';
}
