import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/torbox_models.dart';
import 'app_settings_repository.dart';

class RealDebridApiService {
  RealDebridApiService({
    AppSettingsRepository? settingsRepository,
  }) : _settingsRepository = settingsRepository ?? AppSettingsRepository();

  static const String _baseUrl = 'https://api.real-debrid.com/rest/1.0';
  static const int _maxAttempts = 2;

  final AppSettingsRepository _settingsRepository;

  static String normalizeApiKey(String value) {
    String key = value.trim();
    key = key.replaceAll(RegExp(r'^Bearer\s+', caseSensitive: false), '');
    key = key.replaceAll(RegExp("[\"'`]+"), '');
    key = key.replaceAll(RegExp(r'\s+'), '');
    return key;
  }

  Future<bool> isConfigured() async {
    final String? apiKey = await _settingsRepository.getRealDebridApiKey();
    return normalizeApiKey(apiKey ?? '').isNotEmpty;
  }

  Future<bool> verifyApiKey({String? apiKeyOverride}) async {
    try {
      await getUserInfo(apiKeyOverride: apiKeyOverride);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<RealDebridUser> getUserInfo({String? apiKeyOverride}) async {
    final Map<String, dynamic> payload = await _requestJson(
      'GET',
      Uri.parse('$_baseUrl/user'),
      apiKeyOverride: apiKeyOverride,
    );
    return RealDebridUser.fromJson(payload);
  }

  Future<RealDebridUser> connect(String apiKey) async {
    final String trimmed = normalizeApiKey(apiKey);
    if (trimmed.isEmpty) {
      throw const RealDebridApiException(
        detail: 'Enter a Real-Debrid API token first.',
      );
    }

    final RealDebridUser user = await getUserInfo(apiKeyOverride: trimmed);
    await _settingsRepository.saveRealDebridApiKey(trimmed);
    return user;
  }

  Future<List<RealDebridTorrentInfo>> getUserTorrents() async {
    final List<dynamic> payload = await _requestJsonList(
      'GET',
      Uri.parse('$_baseUrl/torrents'),
    );
    return payload
        .whereType<Map<String, dynamic>>()
        .map(RealDebridTorrentInfo.fromJson)
        .toList(growable: false);
  }

  Future<Map<String, bool>> checkCached(List<String> hashes) async {
    final List<String> normalizedHashes = hashes
        .map((String hash) => hash.trim().toLowerCase())
        .where((String hash) => RegExp(r'^[a-f0-9]{40}$').hasMatch(hash))
        .toSet()
        .toList(growable: false);
    if (normalizedHashes.isEmpty || !await isConfigured()) {
      return const <String, bool>{};
    }

    final Map<String, bool> results = <String, bool>{
      for (final String hash in normalizedHashes) hash: false,
    };

    for (int start = 0; start < normalizedHashes.length; start += 30) {
      final List<String> batch =
          normalizedHashes.skip(start).take(30).toList(growable: false);
      final Map<String, dynamic> payload = await _requestJson(
        'GET',
        Uri.parse(
          '$_baseUrl/torrents/instantAvailability/${batch.join('/')}',
        ),
      );
      for (final String hash in batch) {
        results[hash] = _isInstantlyAvailable(payload[hash] ??
            payload[hash.toUpperCase()] ??
            payload[hash.toLowerCase()]);
      }
    }

    return results;
  }

  Future<RealDebridResolvedLink?> resolveSource({
    required StreamSource source,
    int? seasonNumber,
    int? episodeNumber,
  }) async {
    final String? magnet = source.magnetUri ??
        _buildMagnetUri(source.infoHash, source.sourceTrackers);
    if (magnet == null || magnet.isEmpty) {
      return null;
    }

    final Map<String, dynamic> addPayload = await _requestForm(
      'POST',
      Uri.parse('$_baseUrl/torrents/addMagnet'),
      <String, String>{'magnet': magnet},
    );
    final String torrentId = addPayload['id']?.toString() ?? '';
    if (torrentId.isEmpty) {
      throw const RealDebridApiException(
        detail: 'Real-Debrid did not return a torrent id.',
      );
    }

    bool resolved = false;
    try {
      final RealDebridTorrentInfo infoBefore = await getTorrentInfo(torrentId);
      final RealDebridTorrentFile? file = _selectFile(
        infoBefore.files,
        source: source,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
      );
      if (file == null || file.id <= 0) {
        throw const RealDebridApiException(
          detail: 'Real-Debrid did not expose a playable video file.',
        );
      }

      await _requestForm(
        'POST',
        Uri.parse('$_baseUrl/torrents/selectFiles/$torrentId'),
        <String, String>{'files': file.id.toString()},
        allowEmptyResponse: true,
      );

      final RealDebridTorrentInfo infoAfter = await getTorrentInfo(torrentId);
      final String link = infoAfter.links.isNotEmpty
          ? infoAfter.links.first
          : throw const RealDebridApiException(
              detail: 'Real-Debrid did not return a selected file link.',
            );
      final RealDebridResolvedLink resolvedLink = await unrestrictLink(link);
      resolved = resolvedLink.url.isNotEmpty;
      return resolved ? resolvedLink : null;
    } finally {
      if (!resolved) {
        unawaited(deleteTorrent(torrentId));
      }
    }
  }

  Future<RealDebridTorrentInfo> getTorrentInfo(String torrentId) async {
    final Map<String, dynamic> payload = await _requestJson(
      'GET',
      Uri.parse('$_baseUrl/torrents/info/$torrentId'),
    );
    return RealDebridTorrentInfo.fromJson(payload);
  }

  Future<RealDebridResolvedLink> unrestrictLink(String link) async {
    final Map<String, dynamic> payload = await _requestForm(
      'POST',
      Uri.parse('$_baseUrl/unrestrict/link'),
      <String, String>{'link': link},
    );
    return RealDebridResolvedLink.fromJson(payload);
  }

  Future<bool> deleteTorrent(String torrentId) async {
    try {
      await _requestJson(
        'DELETE',
        Uri.parse('$_baseUrl/torrents/delete/$torrentId'),
        allowEmptyResponse: true,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _isInstantlyAvailable(dynamic value) {
    if (value == null || value == false) {
      return false;
    }
    if (value == true) {
      return true;
    }
    if (value is List<dynamic>) {
      return value.isNotEmpty;
    }
    if (value is Map<String, dynamic>) {
      final dynamic rd = value['rd'] ?? value['RD'];
      if (rd is List<dynamic> && rd.isNotEmpty) {
        return true;
      }
      return value.values.any(_isInstantlyAvailable);
    }
    return false;
  }

  RealDebridTorrentFile? _selectFile(
    List<RealDebridTorrentFile> files, {
    required StreamSource source,
    int? seasonNumber,
    int? episodeNumber,
  }) {
    final List<RealDebridTorrentFile> playable = files
        .where((RealDebridTorrentFile file) => _isPlayableVideo(file.path))
        .toList(growable: false);
    if (playable.isEmpty) {
      return null;
    }

    final String? fileName = source.fileName;
    if (fileName != null && fileName.trim().isNotEmpty) {
      final String normalizedTarget = _normalizeName(fileName);
      for (final RealDebridTorrentFile file in playable) {
        final String normalizedFile = _normalizeName(file.displayName);
        if (normalizedFile == normalizedTarget ||
            normalizedFile.contains(normalizedTarget) ||
            normalizedTarget.contains(normalizedFile)) {
          return file;
        }
      }
    }

    final int? sourceIndex = source.fileIndex;
    if (sourceIndex != null) {
      if (sourceIndex >= 0 && sourceIndex < files.length) {
        final RealDebridTorrentFile file = files[sourceIndex];
        if (_isPlayableVideo(file.path)) {
          return file;
        }
      }
      if (sourceIndex > 0 && sourceIndex - 1 < files.length) {
        final RealDebridTorrentFile file = files[sourceIndex - 1];
        if (_isPlayableVideo(file.path)) {
          return file;
        }
      }
      for (final RealDebridTorrentFile file in playable) {
        if (file.id == sourceIndex) {
          return file;
        }
      }
    }

    final List<String> episodePatterns =
        _episodePatterns(seasonNumber, episodeNumber);
    if (episodePatterns.isNotEmpty) {
      for (final RealDebridTorrentFile file in playable) {
        final String name = file.displayName.toLowerCase();
        if (episodePatterns.any(name.contains)) {
          return file;
        }
      }
    }

    final List<RealDebridTorrentFile> sorted = playable.toList(growable: false)
      ..sort(_comparePlaybackPreference);
    return sorted.first;
  }

  int _comparePlaybackPreference(
    RealDebridTorrentFile a,
    RealDebridTorrentFile b,
  ) {
    final int codecComparison =
        _codecPreferenceScore(a.path).compareTo(_codecPreferenceScore(b.path));
    if (codecComparison != 0) {
      return codecComparison;
    }
    return b.bytes.compareTo(a.bytes);
  }

  int _codecPreferenceScore(String value) {
    if (RegExp(r'(hevc|h\.?265|x265|10bit|10-bit|hi10|hvc1)',
            caseSensitive: false)
        .hasMatch(value)) {
      return 10;
    }
    if (RegExp(r'(h\.?264|x264|avc)', caseSensitive: false).hasMatch(value)) {
      return 0;
    }
    return 2;
  }

  bool _isPlayableVideo(String value) {
    final String lower = value.toLowerCase();
    return const <String>[
      '.mkv',
      '.mp4',
      '.avi',
      '.mov',
      '.wmv',
      '.flv',
      '.webm',
      '.m4v',
      '.ts',
      '.m2ts',
    ].any(lower.endsWith);
  }

  List<String> _episodePatterns(int? season, int? episode) {
    if (season == null || episode == null) {
      return const <String>[];
    }
    final String seasonTwo = season.toString().padLeft(2, '0');
    final String episodeTwo = episode.toString().padLeft(2, '0');
    return <String>[
      's${seasonTwo}e$episodeTwo',
      '${season}x$episodeTwo',
      '${season}x$episode',
    ];
  }

  String _normalizeName(String value) {
    return value
        .split(RegExp(r'[/\\]'))
        .last
        .replaceFirst(RegExp(r'\.[^.]+$'), '')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  String? _buildMagnetUri(String? hash, List<String> trackers) {
    if (hash == null || hash.trim().isEmpty) {
      return null;
    }
    final StringBuffer buffer =
        StringBuffer('magnet:?xt=urn:btih:${hash.trim()}');
    for (final String tracker in trackers.toSet()) {
      final String normalized =
          tracker.replaceFirst(RegExp(r'^tracker:', caseSensitive: false), '');
      if (normalized.trim().isEmpty || normalized.startsWith('dht:', 0)) {
        continue;
      }
      buffer.write('&tr=${Uri.encodeComponent(normalized.trim())}');
    }
    return buffer.toString();
  }

  Future<Map<String, dynamic>> _requestJson(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
    String? apiKeyOverride,
    bool allowEmptyResponse = false,
  }) async {
    final dynamic decoded = await _requestDecoded(
      method,
      uri,
      apiKeyOverride: apiKeyOverride,
      body: body == null ? null : jsonEncode(body),
      contentType: body == null ? null : 'application/json',
      allowEmptyResponse: allowEmptyResponse,
    );
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (allowEmptyResponse && decoded == null) {
      return const <String, dynamic>{};
    }
    throw const RealDebridApiException(
      detail: 'Real-Debrid returned invalid data.',
    );
  }

  Future<List<dynamic>> _requestJsonList(
    String method,
    Uri uri, {
    String? apiKeyOverride,
  }) async {
    final dynamic decoded = await _requestDecoded(
      method,
      uri,
      apiKeyOverride: apiKeyOverride,
    );
    if (decoded is List<dynamic>) {
      return decoded;
    }
    return const <dynamic>[];
  }

  Future<Map<String, dynamic>> _requestForm(
    String method,
    Uri uri,
    Map<String, String> fields, {
    bool allowEmptyResponse = false,
  }) async {
    final String body = fields.entries
        .map((MapEntry<String, String> entry) =>
            '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}')
        .join('&');
    final dynamic decoded = await _requestDecoded(
      method,
      uri,
      body: body,
      contentType: 'application/x-www-form-urlencoded',
      allowEmptyResponse: allowEmptyResponse,
    );
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (allowEmptyResponse && decoded == null) {
      return const <String, dynamic>{};
    }
    throw const RealDebridApiException(
      detail: 'Real-Debrid returned invalid data.',
    );
  }

  Future<dynamic> _requestDecoded(
    String method,
    Uri uri, {
    String? apiKeyOverride,
    String? body,
    String? contentType,
    bool allowEmptyResponse = false,
  }) async {
    final String? rawApiKey =
        apiKeyOverride ?? await _settingsRepository.getRealDebridApiKey();
    final String apiKey = normalizeApiKey(rawApiKey ?? '');
    if (apiKey.isEmpty) {
      throw const RealDebridApiException(
        detail: 'Real-Debrid API token not configured.',
      );
    }

    Object? lastError;
    for (int attempt = 1; attempt <= _maxAttempts; attempt += 1) {
      try {
        return await _requestDecodedOnce(
          method,
          uri,
          apiKey: apiKey,
          body: body,
          contentType: contentType,
          allowEmptyResponse: allowEmptyResponse,
        );
      } catch (error) {
        lastError = error;
        if (error is RealDebridApiException &&
            error.statusCode != null &&
            error.statusCode! >= 400 &&
            error.statusCode! < 500) {
          rethrow;
        }
        if (attempt == _maxAttempts) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
    }

    if (lastError is RealDebridApiException) {
      throw lastError;
    }
    throw RealDebridApiException(
      detail: 'Connection error: ${lastError.runtimeType} - $lastError',
    );
  }

  Future<dynamic> _requestDecodedOnce(
    String method,
    Uri uri, {
    required String apiKey,
    String? body,
    String? contentType,
    required bool allowEmptyResponse,
  }) async {
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final HttpClientRequest request = await client.openUrl(method, uri);
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Omnio/1.0 (Android; Flutter)',
      );
      if (body != null) {
        request.headers.set(HttpHeaders.contentTypeHeader, contentType ?? '');
        request.write(body);
      }

      final HttpClientResponse response =
          await request.close().timeout(const Duration(seconds: 30));
      final String raw = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw RealDebridApiException.fromHttpResponse(
          raw,
          statusCode: response.statusCode,
          fallbackDetail:
              'Real-Debrid request failed with status ${response.statusCode}.',
        );
      }
      if (raw.trim().isEmpty) {
        if (allowEmptyResponse) {
          return null;
        }
        return const <String, dynamic>{};
      }
      return jsonDecode(raw);
    } on RealDebridApiException {
      rethrow;
    } on SocketException catch (e) {
      throw RealDebridApiException(
        detail: 'Network error: ${e.message}. Check your internet connection.',
      );
    } on TimeoutException {
      throw const RealDebridApiException(
        detail: 'Request timed out. Real-Debrid API may be unreachable.',
      );
    } on FormatException catch (e) {
      throw RealDebridApiException(
        detail: 'Invalid response from Real-Debrid: ${e.message}',
      );
    } catch (e) {
      throw RealDebridApiException(
        detail: 'Connection error: ${e.runtimeType} - $e',
      );
    } finally {
      client.close(force: true);
    }
  }
}

class RealDebridApiException implements Exception {
  const RealDebridApiException({
    required this.detail,
    this.errorCode,
    this.statusCode,
  });

  final String detail;
  final String? errorCode;
  final int? statusCode;

  factory RealDebridApiException.fromHttpResponse(
    String raw, {
    required int statusCode,
    required String fallbackDetail,
  }) {
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return RealDebridApiException(
          detail: decoded['error']?.toString() ?? fallbackDetail,
          errorCode: decoded['error_code']?.toString(),
          statusCode: statusCode,
        );
      }
    } catch (_) {}

    return RealDebridApiException(
      detail: fallbackDetail,
      statusCode: statusCode,
    );
  }

  @override
  String toString() {
    if (errorCode == null || errorCode!.isEmpty) {
      return detail;
    }
    return '$errorCode: $detail';
  }
}
