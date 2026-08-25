import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/torbox_models.dart';
import 'app_settings_repository.dart';

class TorBoxApiService {
  TorBoxApiService({
    AppSettingsRepository? settingsRepository,
  }) : _settingsRepository = settingsRepository ?? AppSettingsRepository();

  static const String _baseUrl = 'https://api.torbox.app/v1/api';
  static const int _maxAttempts = 2;

  final AppSettingsRepository _settingsRepository;

  static String normalizeApiKey(String value) {
    String key = value.trim();
    key = key.replaceAll(RegExp(r'^Bearer\s+', caseSensitive: false), '');
    key = key.replaceAll(RegExp(r'^Token\s+', caseSensitive: false), '');
    key = key.replaceAll(RegExp("[\"'`]+"), '');
    key = key.replaceAll(RegExp(r'\s+'), '');
    return key;
  }

  Future<bool> isConfigured() async {
    final String? apiKey = await _settingsRepository.getTorBoxApiKey();
    return normalizeApiKey(apiKey ?? '').isNotEmpty;
  }

  Future<bool> verifyApiKey({String? apiKeyOverride}) async {
    try {
      await _requestJson(
        'GET',
        Uri.parse('$_baseUrl/user/me').replace(
          queryParameters: const <String, String>{'settings': 'false'},
        ),
        apiKeyOverride: apiKeyOverride,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<TorBoxUser> getUserInfo({String? apiKeyOverride}) async {
    final Map<String, dynamic> payload = await _requestJson(
      'GET',
      Uri.parse('$_baseUrl/user/me').replace(
        queryParameters: const <String, String>{'settings': 'false'},
      ),
      apiKeyOverride: apiKeyOverride,
    );
    final dynamic data = payload['data'];
    if (payload['success'] == true) {
      if (data is Map<String, dynamic>) {
        try {
          return TorBoxUser.fromJson(data);
        } catch (_) {
          return _fallbackUser();
        }
      }
      return _fallbackUser();
    }

    throw TorBoxApiException(
      detail:
          payload['detail'] as String? ?? 'TorBox returned invalid user data.',
      errorCode: payload['error'] as String?,
    );
  }

  TorBoxUser _fallbackUser() {
    return const TorBoxUser(
      email: 'TorBox account',
      plan: 'Connected',
      createdAt: null,
      totalSlots: 0,
      usedSlots: 0,
    );
  }

  Future<List<TorBoxTorrent>> getUserTorrents({
    int? torrentId,
    String? apiKeyOverride,
  }) async {
    final Map<String, String> query = <String, String>{
      'bypass_cache': 'true',
      'format': 'list',
    };
    if (torrentId != null) {
      query['id'] = torrentId.toString();
    }

    final Map<String, dynamic> payload = await _requestJson(
      'GET',
      Uri.parse('$_baseUrl/torrents/mylist').replace(queryParameters: query),
      apiKeyOverride: apiKeyOverride,
    );
    if (payload['success'] != true) {
      return const <TorBoxTorrent>[];
    }

    return _readTorrentRows(payload['data'])
        .map(TorBoxTorrent.fromJson)
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _readTorrentRows(dynamic data) {
    if (data is List<dynamic>) {
      return data.whereType<Map<String, dynamic>>().toList(growable: false);
    }
    if (data is Map<String, dynamic>) {
      if (data.containsKey('id') || data.containsKey('hash')) {
        return <Map<String, dynamic>>[data];
      }
      return data.values
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  Future<TorBoxAccountSnapshot> connectAndLoad(String apiKey) async {
    final String trimmed = normalizeApiKey(apiKey);
    if (trimmed.isEmpty) {
      throw const TorBoxApiException(detail: 'Enter a TorBox API key first.');
    }

    final TorBoxUser user = await getUserInfo(apiKeyOverride: trimmed);
    await _settingsRepository.saveTorBoxApiKey(trimmed);
    final List<TorBoxTorrent> torrents =
        await _loadTorrentsWithoutBreakingConnection(apiKeyOverride: trimmed);
    return TorBoxAccountSnapshot(
      user: user,
      torrents: torrents,
    );
  }

  Future<TorBoxAccountSnapshot> loadAccountSnapshot() async {
    final TorBoxUser user = await getUserInfo();
    final List<TorBoxTorrent> torrents =
        await _loadTorrentsWithoutBreakingConnection();
    return TorBoxAccountSnapshot(
      user: user,
      torrents: torrents,
    );
  }

  Future<List<TorBoxTorrent>> _loadTorrentsWithoutBreakingConnection({
    String? apiKeyOverride,
  }) async {
    try {
      return await getUserTorrents(apiKeyOverride: apiKeyOverride);
    } catch (_) {
      return const <TorBoxTorrent>[];
    }
  }

  Future<TorBoxTorrent?> getTorrentByHash(String hash) async {
    try {
      final List<TorBoxTorrent> torrents = await getUserTorrents();
      final String normalized = hash.toLowerCase();
      for (final TorBoxTorrent torrent in torrents) {
        if (torrent.hash.toLowerCase() == normalized) {
          return torrent;
        }
      }
    } catch (_) {}

    return null;
  }

  Future<TorBoxTorrent?> addTorrent(String magnetOrHash) async {
    final String magnet = magnetOrHash.startsWith('magnet:')
        ? magnetOrHash
        : 'magnet:?xt=urn:btih:$magnetOrHash';

    try {
      final Map<String, dynamic> payload = await _requestMultipart(
        Uri.parse('$_baseUrl/torrents/createtorrent'),
        <String, String>{'magnet': magnet},
      );
      if (payload['success'] == true) {
        final dynamic data = payload['data'];
        final Map<String, dynamic>? dataMap =
            data is Map<String, dynamic> ? data : null;
        final int? torrentId = (dataMap?['torrent_id'] as num?)?.toInt();
        if (torrentId != null) {
          final List<TorBoxTorrent> torrents =
              await getUserTorrents(torrentId: torrentId);
          if (torrents.isNotEmpty) {
            return torrents.first;
          }
        }
      }

      return await getTorrentByHash(
        _extractInfoHash(magnetOrHash) ?? magnetOrHash,
      );
    } catch (_) {
      try {
        return await getTorrentByHash(
          _extractInfoHash(magnetOrHash) ?? magnetOrHash,
        );
      } catch (_) {
        return null;
      }
    }
  }

  Future<bool> deleteTorrent(int torrentId) async {
    try {
      final Map<String, dynamic> payload = await _requestJson(
        'POST',
        Uri.parse('$_baseUrl/torrents/controltorrent'),
        body: <String, dynamic>{
          'torrent_id': torrentId,
          'operation': 'delete',
        },
      );
      return payload['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<TorBoxTorrentFile>> getTorrentFiles(int torrentId) async {
    try {
      final List<TorBoxTorrent> torrents =
          await getUserTorrents(torrentId: torrentId);
      if (torrents.isEmpty) {
        return const <TorBoxTorrentFile>[];
      }

      return torrents.first.files;
    } catch (_) {
      return const <TorBoxTorrentFile>[];
    }
  }

  Future<String?> getQuickStreamUrl(int torrentId, [int? fileId]) async {
    try {
      final String? apiKey = await _settingsRepository.getTorBoxApiKey();
      final String trimmedApiKey = normalizeApiKey(apiKey ?? '');
      if (trimmedApiKey.isEmpty) {
        return null;
      }

      final Uri uri = Uri.parse('$_baseUrl/torrents/requestdl').replace(
        queryParameters: <String, String>{
          'token': trimmedApiKey,
          'torrent_id': torrentId.toString(),
          if (fileId != null) 'file_id': fileId.toString(),
        },
      );

      final HttpClient client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 30);
      try {
        final HttpClientRequest request = await client.getUrl(uri);
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');
        request.headers.set(
          HttpHeaders.userAgentHeader,
          'Omnio/1.0 (Android; Flutter)',
        );
        final HttpClientResponse response =
            await request.close().timeout(const Duration(seconds: 30));
        final String raw = await response
            .transform(utf8.decoder)
            .join()
            .timeout(const Duration(seconds: 15));
        if (response.statusCode != HttpStatus.ok) {
          return null;
        }

        final dynamic decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          final dynamic data = decoded['data'];
          if (data is String && data.isNotEmpty) {
            return data;
          }
        }

        return null;
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, bool>> checkCached(List<String> hashes) async {
    final List<String> normalizedHashes = hashes
        .map((String hash) => hash.trim().toLowerCase())
        .where((String hash) => RegExp(r'^[a-f0-9]{40}$').hasMatch(hash))
        .toSet()
        .toList(growable: false);
    if (normalizedHashes.isEmpty) {
      return const <String, bool>{};
    }

    final Map<String, bool> results = <String, bool>{
      for (final String hash in normalizedHashes) hash: false,
    };

    const int batchSize = 50;
    for (int start = 0; start < normalizedHashes.length; start += batchSize) {
      final List<String> batch =
          normalizedHashes.skip(start).take(batchSize).toList(growable: false);
      final Map<String, dynamic> payload =
          await _requestCheckCachedBatch(batch);
      final dynamic data = payload['data'];
      if (data is Map<String, dynamic>) {
        for (final String hash in batch) {
          results[hash] =
              _isCachedValue(data[hash] ?? data[hash.toUpperCase()]);
        }
      } else if (data is List<dynamic>) {
        final Set<String> cachedHashes = data
            .map((dynamic item) {
              if (item is Map<String, dynamic>) {
                return item['hash']?.toString().toLowerCase();
              }
              return item?.toString().toLowerCase();
            })
            .whereType<String>()
            .toSet();
        for (final String hash in batch) {
          results[hash] = cachedHashes.contains(hash);
        }
      }
    }

    return results;
  }

  Future<Map<String, dynamic>> _requestCheckCachedBatch(
    List<String> hashes,
  ) async {
    try {
      return await _requestJson(
        'GET',
        Uri.parse('$_baseUrl/torrents/checkcached').replace(
          queryParameters: <String, String>{
            'hash': hashes.join(','),
            'format': 'object',
            'list_files': 'false',
          },
        ),
      );
    } on TorBoxApiException {
      return _requestJson(
        'POST',
        Uri.parse('$_baseUrl/torrents/checkcached'),
        body: <String, dynamic>{
          'hashes': hashes,
          'format': 'object',
          'list_files': false,
        },
      );
    }
  }

  bool _isCachedValue(dynamic value) {
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
      if (value['cached'] == true || value['is_cached'] == true) {
        return true;
      }
      if (value['files'] is List<dynamic>) {
        return (value['files'] as List<dynamic>).isNotEmpty;
      }
      return value.isNotEmpty;
    }
    return false;
  }

  Future<Map<String, dynamic>> _requestJson(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
    String? apiKeyOverride,
  }) async {
    final String? rawApiKey =
        apiKeyOverride ?? await _settingsRepository.getTorBoxApiKey();
    final String apiKey = normalizeApiKey(rawApiKey ?? '');
    if (apiKey.isEmpty) {
      throw const TorBoxApiException(detail: 'TorBox API key not configured.');
    }

    Object? lastError;
    for (int attempt = 1; attempt <= _maxAttempts; attempt += 1) {
      try {
        return await _requestJsonOnce(
          method,
          uri,
          apiKey: apiKey,
          body: body,
        );
      } catch (error) {
        lastError = error;
        if (error is TorBoxApiException &&
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

    if (lastError is TorBoxApiException) {
      throw lastError;
    }
    throw TorBoxApiException(
      detail: 'Connection error: ${lastError.runtimeType} - $lastError',
    );
  }

  Future<Map<String, dynamic>> _requestJsonOnce(
    String method,
    Uri uri, {
    required String apiKey,
    Map<String, dynamic>? body,
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
        request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
        request.write(jsonEncode(body));
      }

      final HttpClientResponse response =
          await request.close().timeout(const Duration(seconds: 30));
      final String raw = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw TorBoxApiException.fromHttpResponse(
          raw,
          statusCode: response.statusCode,
          fallbackDetail:
              'TorBox request failed with status ${response.statusCode}.',
        );
      }

      return jsonDecode(raw) as Map<String, dynamic>;
    } on TorBoxApiException {
      rethrow;
    } on SocketException catch (e) {
      throw TorBoxApiException(
        detail: 'Network error: ${e.message}. Check your internet connection.',
      );
    } on HandshakeException catch (e) {
      throw TorBoxApiException(
        detail:
            'TLS handshake failed: ${e.message}. Try a different DNS provider.',
      );
    } on TimeoutException {
      throw const TorBoxApiException(
        detail: 'Request timed out. TorBox API may be unreachable.',
      );
    } on FormatException catch (e) {
      throw TorBoxApiException(
        detail: 'Invalid response from TorBox: ${e.message}',
      );
    } catch (e) {
      throw TorBoxApiException(
        detail: 'Connection error: ${e.runtimeType} - $e',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _requestMultipart(
    Uri uri,
    Map<String, String> fields,
  ) async {
    final String? rawApiKey = await _settingsRepository.getTorBoxApiKey();
    final String apiKey = normalizeApiKey(rawApiKey ?? '');
    if (apiKey.isEmpty) {
      throw const TorBoxApiException(detail: 'TorBox API key not configured.');
    }

    final String boundary =
        '----streamedflutter${DateTime.now().millisecondsSinceEpoch}';
    final StringBuffer buffer = StringBuffer();
    fields.forEach((String key, String value) {
      buffer
        ..write('--$boundary\r\n')
        ..write('Content-Disposition: form-data; name="$key"\r\n\r\n')
        ..write(value)
        ..write('\r\n');
    });
    buffer.write('--$boundary--\r\n');

    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final HttpClientRequest request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'multipart/form-data; boundary=$boundary',
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Omnio/1.0 (Android; Flutter)',
      );
      request.write(buffer.toString());
      final HttpClientResponse response =
          await request.close().timeout(const Duration(seconds: 30));
      final String raw = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw TorBoxApiException.fromHttpResponse(
          raw,
          statusCode: response.statusCode,
          fallbackDetail:
              'TorBox multipart request failed with status ${response.statusCode}.',
        );
      }
      return jsonDecode(raw) as Map<String, dynamic>;
    } on TorBoxApiException {
      rethrow;
    } on SocketException catch (e) {
      throw TorBoxApiException(
        detail: 'Network error: ${e.message}. Check your internet connection.',
      );
    } on HandshakeException catch (e) {
      throw TorBoxApiException(
        detail:
            'TLS handshake failed: ${e.message}. Try a different DNS provider.',
      );
    } on TimeoutException {
      throw const TorBoxApiException(
        detail: 'Request timed out. TorBox API may be unreachable.',
      );
    } catch (e) {
      throw TorBoxApiException(
        detail: 'Connection error: ${e.runtimeType} - $e',
      );
    } finally {
      client.close(force: true);
    }
  }

  String? _extractInfoHash(String value) {
    final RegExp matchExpression =
        RegExp(r'btih:([A-Za-z0-9]+)', caseSensitive: false);
    final RegExpMatch? match = matchExpression.firstMatch(value);
    return match?.group(1)?.toLowerCase();
  }
}

class TorBoxAccountSnapshot {
  const TorBoxAccountSnapshot({
    required this.user,
    required this.torrents,
  });

  final TorBoxUser user;
  final List<TorBoxTorrent> torrents;
}

class TorBoxApiException implements Exception {
  const TorBoxApiException({
    required this.detail,
    this.errorCode,
    this.statusCode,
  });

  final String detail;
  final String? errorCode;
  final int? statusCode;

  factory TorBoxApiException.fromHttpResponse(
    String raw, {
    required int statusCode,
    required String fallbackDetail,
  }) {
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return TorBoxApiException(
          detail: decoded['detail'] as String? ?? fallbackDetail,
          errorCode: decoded['error'] as String?,
          statusCode: statusCode,
        );
      }
    } catch (_) {}

    return TorBoxApiException(
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
