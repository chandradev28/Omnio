import '../models/search_result.dart';
import 'app_settings_repository.dart';
import 'tmdb_http_service.dart';

abstract class SearchService {
  Future<List<SearchResult>> searchMulti(String query);
}

class TmdbSearchService implements SearchService {
  TmdbSearchService({AppSettingsRepository? settingsRepository})
      : _settingsRepository = settingsRepository ?? AppSettingsRepository();

  final AppSettingsRepository _settingsRepository;

  @override
  Future<List<SearchResult>> searchMulti(String query) async {
    final Map<String, dynamic> payload = await TmdbHttpService(
      settingsRepository: _settingsRepository,
    ).getJson(
      '/search/multi',
      params: <String, String>{
        'query': query,
        'page': '1',
        'include_adult': 'false',
      },
    );
    final List<dynamic> results =
        payload['results'] as List<dynamic>? ?? const <dynamic>[];

    return results
        .where((dynamic item) {
          final String? mediaType =
              (item as Map<String, dynamic>)['media_type'] as String?;
          return mediaType == 'movie' || mediaType == 'tv';
        })
        .map(
          (dynamic item) => SearchResult.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false);
  }
}
