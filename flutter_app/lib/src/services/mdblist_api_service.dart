import 'dart:convert';
import 'dart:io';

import '../models/tmdb_media_models.dart';
import '../models/torbox_models.dart';
import 'app_settings_repository.dart';

class MdbListApiService {
  MdbListApiService({
    AppSettingsRepository? settingsRepository,
  }) : _settingsRepository = settingsRepository ?? AppSettingsRepository();

  static const String _baseHost = 'api.mdblist.com';
  static const int _maxAttempts = 2;

  final AppSettingsRepository _settingsRepository;

  Future<List<ExternalRating>> getRatings(MediaDetail detail) async {
    final AppSettings settings = await _settingsRepository.loadSettings();
    final String apiKey = (settings.mdbListApiKey ?? '').trim();
    final String? imdbId = detail.imdbId;
    if (!settings.mdbListRatingsEnabled ||
        apiKey.isEmpty ||
        imdbId == null ||
        imdbId.isEmpty) {
      return const <ExternalRating>[];
    }

    final String type = detail.mediaType == 'tv' ? 'show' : 'movie';
    final Map<String, dynamic> payload = await _fetch(
      '/imdb/$type/$imdbId',
      <String, String>{'apikey': apiKey},
    );

    return _readRatings(payload, settings);
  }

  Future<bool> verifyApiKey(String apiKey) async {
    final String key = apiKey.trim();
    if (key.isEmpty) {
      return false;
    }
    try {
      await _fetch('/user', <String, String>{'apikey': key});
      return true;
    } catch (_) {
      try {
        await _fetch(
          '/imdb/movie/tt0133093',
          <String, String>{'apikey': key},
        );
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  List<ExternalRating> _readRatings(
    Map<String, dynamic> payload,
    AppSettings settings,
  ) {
    final List<dynamic> rawRatings =
        payload['ratings'] as List<dynamic>? ?? const <dynamic>[];
    final List<ExternalRating> ratings = <ExternalRating>[];

    for (final dynamic item in rawRatings) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      final String source = (item['source'] ?? item['name'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if (!_providerEnabled(source, settings)) {
        continue;
      }

      final dynamic rawValue =
          item['value'] ?? item['rating'] ?? item['score'] ?? item['average'];
      final String score = _formatScore(source, rawValue);
      if (score.isEmpty) {
        continue;
      }

      ratings.add(
        ExternalRating(
          source: source,
          label: _sourceLabel(source),
          score: score,
          votes: _readInt(item['votes'] ?? item['vote_count']),
          normalizedScore: _normalizeScore(source, rawValue),
        ),
      );
    }

    return ratings;
  }

  bool _providerEnabled(String source, AppSettings settings) {
    if (source.contains('imdb')) {
      return settings.mdbListImdbEnabled;
    }
    if (source.contains('tmdb')) {
      return settings.mdbListTmdbEnabled;
    }
    if (source.contains('tomato') || source.contains('rotten')) {
      return settings.mdbListRottenTomatoesEnabled;
    }
    if (source.contains('metacritic')) {
      return settings.mdbListMetacriticEnabled;
    }
    if (source.contains('trakt')) {
      return settings.mdbListTraktEnabled;
    }
    if (source.contains('letterboxd')) {
      return settings.mdbListLetterboxdEnabled;
    }
    if (source.contains('audience') || source.contains('popcorn')) {
      return settings.mdbListAudienceScoreEnabled;
    }
    return true;
  }

  String _sourceLabel(String source) {
    if (source.contains('imdb')) {
      return 'IMDb';
    }
    if (source.contains('tmdb')) {
      return 'TMDB';
    }
    if (source.contains('metacritic')) {
      return 'Metacritic';
    }
    if (source.contains('trakt')) {
      return 'Trakt';
    }
    if (source.contains('letterboxd')) {
      return 'Letterboxd';
    }
    if (source.contains('audience') || source.contains('popcorn')) {
      return 'Audience';
    }
    if (source.contains('tomato') || source.contains('rotten')) {
      return 'Rotten Tomatoes';
    }
    return source.isEmpty ? 'Rating' : source;
  }

  String _formatScore(String source, dynamic value) {
    final double? number = _readDouble(value);
    if (number == null) {
      return value?.toString() ?? '';
    }
    if (source.contains('tomato') ||
        source.contains('metacritic') ||
        source.contains('audience') ||
        source.contains('popcorn')) {
      return '${number.round()}%';
    }
    if (source.contains('letterboxd') && number <= 5) {
      return number.toStringAsFixed(1);
    }
    if (number <= 10) {
      return number.toStringAsFixed(1);
    }
    return '${number.round()}%';
  }

  double? _normalizeScore(String source, dynamic value) {
    final double? number = _readDouble(value);
    if (number == null) {
      return null;
    }
    if (source.contains('letterboxd') && number <= 5) {
      return number * 20;
    }
    if (number <= 10) {
      return number * 10;
    }
    return number.clamp(0, 100);
  }

  Future<Map<String, dynamic>> _fetch(
    String path,
    Map<String, String> params,
  ) async {
    final Uri uri = Uri.https(_baseHost, path, params);
    Object? lastError;
    for (int attempt = 1; attempt <= _maxAttempts; attempt += 1) {
      try {
        return await _fetchOnce(uri);
      } catch (error) {
        lastError = error;
        if (attempt == _maxAttempts) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
    }
    throw lastError ?? HttpException('MDBList request failed.', uri: uri);
  }

  Future<Map<String, dynamic>> _fetchOnce(Uri uri) async {
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final HttpClientRequest request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Omnio/1.0 (Android; Flutter)',
      );
      final HttpClientResponse response =
          await request.close().timeout(const Duration(seconds: 15));
      final String raw = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'MDBList request failed with status ${response.statusCode}',
          uri: uri,
        );
      }
      final dynamic decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic>
          ? decoded
          : const <String, dynamic>{};
    } finally {
      client.close(force: true);
    }
  }

  int? _readInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  double? _readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
  }
}
