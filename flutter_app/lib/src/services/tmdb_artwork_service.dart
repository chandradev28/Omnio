import '../models/torbox_models.dart';
import 'tmdb_http_service.dart';
import 'tmdb_image.dart';

/// Resolves high-resolution TMDB artwork for addon catalog items without
/// delaying the initial home render. Addon artwork remains the fallback when
/// a title cannot be matched or TMDB is unavailable.
class TmdbArtworkService {
  TmdbArtworkService({TmdbHttpService? httpService})
      : _httpService = httpService ?? TmdbHttpService();

  final TmdbHttpService _httpService;

  Future<List<AddonCatalogRow>> enrichCatalogRows(
    List<AddonCatalogRow> rows, {
    required String? personalCredential,
    required bool enabled,
  }) async {
    if (!enabled || (personalCredential ?? '').trim().isEmpty) {
      return rows;
    }

    final Map<String, _Artwork> artworkById = <String, _Artwork>{};
    final List<String> ids = <String>[];
    final Set<String> seen = <String>{};
    for (final AddonCatalogRow row in rows) {
      for (final AddonCatalogItem item in row.items) {
        final String id = item.id.trim();
        if (!id.startsWith('tt') || !seen.add(id)) {
          continue;
        }
        ids.add(id);
        if (ids.length >= 40) {
          break;
        }
      }
      if (ids.length >= 40) {
        break;
      }
    }

    for (int start = 0; start < ids.length; start += 6) {
      final List<String> batch =
          ids.skip(start).take(6).toList(growable: false);
      final List<_Artwork?> resolved = await Future.wait(
        batch.map((String id) => _resolveArtwork(id, personalCredential)),
      );
      for (int index = 0; index < batch.length; index += 1) {
        final _Artwork? artwork = resolved[index];
        if (artwork != null) {
          artworkById[batch[index]] = artwork;
        }
      }
    }

    if (artworkById.isEmpty) {
      return rows;
    }

    return rows
        .map(
          (AddonCatalogRow row) => AddonCatalogRow(
            addonName: row.addonName,
            catalogName: row.catalogName,
            catalog: row.catalog,
            addon: row.addon,
            items: row.items.map((AddonCatalogItem item) {
              final _Artwork? artwork = artworkById[item.id.trim()];
              if (artwork == null) {
                return item;
              }
              return item.copyWith(
                poster: artwork.posterUrl ?? item.poster,
                background: artwork.backdropUrl ?? item.background,
              );
            }).toList(growable: false),
          ),
        )
        .toList(growable: false);
  }

  Future<_Artwork?> _resolveArtwork(
    String imdbId,
    String? personalCredential,
  ) async {
    try {
      final Map<String, dynamic> payload = await _httpService.getJson(
        '/find/${Uri.encodeComponent(imdbId)}',
        params: const <String, String>{'external_source': 'imdb_id'},
        apiKeyOverride: personalCredential,
      );
      final List<dynamic> movies =
          payload['movie_results'] as List<dynamic>? ?? const <dynamic>[];
      final List<dynamic> series =
          payload['tv_results'] as List<dynamic>? ?? const <dynamic>[];
      final Map<String, dynamic>? match = <dynamic>[...movies, ...series]
          .whereType<Map<String, dynamic>>()
          .cast<Map<String, dynamic>?>()
          .firstWhere((Map<String, dynamic>? item) {
        return item?['poster_path'] != null || item?['backdrop_path'] != null;
      }, orElse: () => null);
      if (match == null) {
        return null;
      }

      final String? posterPath = match['poster_path'] as String?;
      final String? backdropPath = match['backdrop_path'] as String?;
      return _Artwork(
        posterUrl: posterPath == null ? null : getImageUrl(posterPath, 'w780'),
        backdropUrl:
            backdropPath == null ? null : getImageUrl(backdropPath, 'w1280'),
      );
    } catch (_) {
      return null;
    }
  }
}

class _Artwork {
  const _Artwork({this.posterUrl, this.backdropUrl});

  final String? posterUrl;
  final String? backdropUrl;
}
