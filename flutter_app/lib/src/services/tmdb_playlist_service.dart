import '../models/playlist_movie.dart';
import 'app_settings_repository.dart';
import 'tmdb_http_service.dart';

abstract class PlaylistService {
  Future<List<PlaylistMovie>> getMoviesByProvider(int providerId);
}

class TmdbPlaylistService implements PlaylistService {
  TmdbPlaylistService({AppSettingsRepository? settingsRepository})
      : _settingsRepository = settingsRepository ?? AppSettingsRepository();

  final AppSettingsRepository _settingsRepository;

  @override
  Future<List<PlaylistMovie>> getMoviesByProvider(int providerId) async {
    final Map<String, dynamic> payload = await TmdbHttpService(
      settingsRepository: _settingsRepository,
    ).getJson(
      '/discover/movie',
      params: <String, String>{
        'with_watch_providers': providerId.toString(),
        'watch_region': 'US',
        'sort_by': 'popularity.desc',
        'include_adult': 'false',
        'language': 'en-US',
        'page': '1',
      },
    );
    final List<dynamic> results =
        payload['results'] as List<dynamic>? ?? const <dynamic>[];

    return results
        .take(10)
        .map(
          (dynamic item) =>
              PlaylistMovie.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false);
  }
}
