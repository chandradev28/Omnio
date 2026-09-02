import 'dart:convert';
import 'dart:io';

import '../models/torbox_models.dart';
import 'app_settings_repository.dart';

/// Shared TMDB transport for metadata, search, and provider discovery.
///
/// WARP is a device-level route, so the app cannot turn it on itself. Requests
/// go directly to TMDB so a user's credential is never disclosed to a public
/// proxy. HTML block pages are rejected instead of being parsed.
class TmdbHttpService {
  TmdbHttpService({AppSettingsRepository? settingsRepository})
      : _settingsRepository = settingsRepository ?? AppSettingsRepository();

  static const String apiKey = 'cd45143a9ade518a4381e765c719e68b';
  static const String apiHost = 'api.themoviedb.org';
  static const String apiPath = '/3';

  final AppSettingsRepository _settingsRepository;

  /// Accepts either a TMDB v3 API key or a v4 API Read Access Token.
  ///
  /// Users commonly paste the value with surrounding quotes or the `Bearer`
  /// prefix copied from the TMDB documentation, so normalize those forms
  /// before storing or sending the credential.
  static String normalizeCredential(String raw) {
    String value = raw.trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1).trim();
    }
    if (value.toLowerCase().startsWith('bearer ')) {
      value = value.substring('bearer '.length).trim();
    }
    return value;
  }

  /// Verifies a user-supplied TMDB credential against the configuration API.
  /// The returned value is normalized and safe to persist in app settings.
  Future<String> validateCredential(String rawCredential) async {
    final String credential = normalizeCredential(rawCredential);
    if (credential.isEmpty) {
      throw const TmdbRequestException(
        statusCode: 0,
        message: 'Enter a TMDB v3 API key or v4 Read Access Token first.',
      );
    }

    await getJson(
      '/configuration',
      apiKeyOverride: credential,
    );
    return credential;
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String> params = const <String, String>{},
    AppSettings? settings,
    String? apiKeyOverride,
  }) async {
    final AppSettings effectiveSettings =
        settings ?? await _settingsRepository.loadSettings();
    final _TmdbCredential credential = _credentialFor(
      effectiveSettings,
      override: apiKeyOverride,
    );
    final Uri directUri = Uri.https(
      apiHost,
      '$apiPath$path'.replaceAll('//', '/'),
      <String, String>{
        if (!credential.isBearer) 'api_key': credential.value,
        ...params,
      },
    );

    return _fetchJson(
      directUri,
      credential: credential,
      timeout: const Duration(seconds: 12),
    );
  }

  _TmdbCredential _credentialFor(
    AppSettings settings, {
    String? override,
  }) {
    final String personal = normalizeCredential(override ?? '');
    if (personal.isNotEmpty) {
      return _TmdbCredential.fromValue(personal);
    }

    final String saved = normalizeCredential(settings.tmdbApiKey ?? '');
    return _TmdbCredential.fromValue(saved.isEmpty ? apiKey : saved);
  }

  static bool _isBearerToken(String value) {
    return value.split('.').length == 3 || value.startsWith('eyJ');
  }

  Future<Map<String, dynamic>> _fetchJson(
    Uri uri, {
    required _TmdbCredential credential,
    required Duration timeout,
  }) async {
    final HttpClient client = HttpClient()..connectionTimeout = timeout;

    try {
      final HttpClientRequest request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Omnio/1.0 (Android; TMDB metadata client)',
      );
      if (credential.isBearer && credential.value.isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer ${credential.value}',
        );
      }

      final HttpClientResponse response =
          await request.close().timeout(timeout);
      final String raw = await response.transform(utf8.decoder).join();
      if (response.statusCode != HttpStatus.ok) {
        String message =
            'TMDB request failed with status ${response.statusCode}.';
        try {
          final dynamic decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic> &&
              decoded['status_message'] is String) {
            message = decoded['status_message'] as String;
          }
        } catch (_) {
          // The route may have returned an HTML block page instead of JSON.
        }
        throw TmdbRequestException(
          statusCode: response.statusCode,
          message: message,
          uri: uri,
        );
      }

      final String contentType =
          response.headers.contentType?.mimeType.toLowerCase() ?? '';
      if (contentType.contains('html') || raw.trimLeft().startsWith('<')) {
        throw TmdbRequestException(
          statusCode: HttpStatus.badGateway,
          message: 'TMDB returned an HTML block page instead of JSON.',
          uri: uri,
        );
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

class _TmdbCredential {
  const _TmdbCredential.query(this.value) : isBearer = false;

  const _TmdbCredential.bearer(this.value) : isBearer = true;

  factory _TmdbCredential.fromValue(String value) {
    return TmdbHttpService._isBearerToken(value)
        ? _TmdbCredential.bearer(value)
        : _TmdbCredential.query(value);
  }

  final String value;
  final bool isBearer;
}

class TmdbRequestException implements Exception {
  const TmdbRequestException({
    required this.statusCode,
    required this.message,
    this.uri,
  });

  final int statusCode;
  final String message;
  final Uri? uri;

  @override
  String toString() => message;
}
