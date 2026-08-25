import '../models/search_result.dart';
import 'app_settings_repository.dart';
import 'stremio_addons_service.dart';
import 'tmdb_search_service.dart';

/// Combines TMDB's broad metadata search with installed Stremio catalog
/// searches. This lets Cinemeta keep working when TMDB is blocked, while TMDB
/// still provides the best artwork and detail-page identifiers when available.
class CombinedSearchService implements SearchService {
  CombinedSearchService({
    AppSettingsRepository? settingsRepository,
    SearchService? tmdbService,
    StremioAddonsService? addonsService,
  })  : _tmdbService = tmdbService ??
            TmdbSearchService(settingsRepository: settingsRepository),
        _addonsService = addonsService ?? StremioAddonsService();

  final SearchService _tmdbService;
  final StremioAddonsService _addonsService;

  @override
  Future<List<SearchResult>> searchMulti(String query) async {
    final String trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const <SearchResult>[];
    }

    List<SearchResult> tmdbResults = const <SearchResult>[];
    List<SearchResult> addonResults = const <SearchResult>[];
    Object? tmdbError;

    try {
      tmdbResults = await _tmdbService.searchMulti(trimmed);
    } catch (error) {
      tmdbError = error;
    }

    try {
      addonResults = await _addonsService.searchCatalogs(trimmed);
    } catch (_) {}

    final List<SearchResult> merged = <SearchResult>[];
    final Set<String> seen = <String>{};
    for (final SearchResult item in <SearchResult>[
      ...tmdbResults,
      ...addonResults
    ]) {
      final String identity = _identity(item);
      if (seen.add(identity)) {
        merged.add(item);
      }
    }

    if (merged.isEmpty && tmdbError != null) {
      throw SearchRequestException(
        'Search services could not be reached. Verify the TMDB key in '
        'Settings > Integrations > TMDB Enrichment, and enable VPN/WARP if '
        'your network blocks TMDB.',
        cause: tmdbError,
      );
    }

    return merged.take(60).toList(growable: false);
  }

  String _identity(SearchResult item) {
    final String external = (item.externalId ?? '').trim().toLowerCase();
    if (external.isNotEmpty) {
      return '${item.mediaType}:$external';
    }
    if (item.id > 0) {
      return '${item.mediaType}:tmdb:${item.id}';
    }
    return '${item.mediaType}:${item.displayTitle.toLowerCase()}';
  }
}

class SearchRequestException implements Exception {
  const SearchRequestException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
