import 'dart:math';

import '../models/torbox_models.dart';
import 'tmdb_artwork_selector.dart';
import 'tmdb_http_service.dart';
import 'tmdb_image.dart';

/// Resolves high-resolution TMDB artwork for addon catalog items without
/// delaying the initial home render. Addon artwork remains the fallback when
/// a title cannot be matched or TMDB is unavailable.
class TmdbArtworkService {
  TmdbArtworkService({TmdbHttpService? httpService, Random? random})
      : _httpService = httpService ?? TmdbHttpService(),
        _random = random ?? Random();

  final TmdbHttpService _httpService;
  final Random _random;
  final Map<String, _Artwork> _artworkCache = <String, _Artwork>{};

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
    final Map<String, String> mediaTypeById = <String, String>{};
    final Set<String> heroIds = rows.isEmpty
        ? <String>{}
        : rows.first.items
            .take(8)
            .map((AddonCatalogItem item) => item.id.trim())
            .where((String id) => id.startsWith('tt'))
            .toSet();
    for (final AddonCatalogRow row in rows) {
      for (final AddonCatalogItem item in row.items) {
        final String id = item.id.trim();
        if (!id.startsWith('tt') || !seen.add(id)) {
          continue;
        }
        ids.add(id);
        mediaTypeById[id] = item.mediaType;
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
        batch.map(
          (String id) => _resolveArtwork(
            id,
            mediaTypeById[id] ?? 'movie',
            personalCredential,
            includeVariants: heroIds.contains(id),
          ),
        ),
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
      String imdbId, String mediaType, String? personalCredential,
      {required bool includeVariants}) async {
    final String cacheKey = '$imdbId:${includeVariants ? 'hero' : 'base'}';
    if (_artworkCache.containsKey(cacheKey)) {
      return _artworkCache[cacheKey];
    }

    try {
      final Map<String, dynamic> payload = await _httpService.getJson(
        '/find/${Uri.encodeComponent(imdbId)}',
        params: const <String, String>{'external_source': 'imdb_id'},
        apiKeyOverride: personalCredential,
      );
      final String resultKey =
          mediaType == 'tv' ? 'tv_results' : 'movie_results';
      final List<dynamic> expectedResults =
          payload[resultKey] as List<dynamic>? ?? const <dynamic>[];
      final Map<String, dynamic>? match = expectedResults
          .whereType<Map<String, dynamic>>()
          .cast<Map<String, dynamic>?>()
          .firstWhere((Map<String, dynamic>? item) {
        return item?['poster_path'] != null || item?['backdrop_path'] != null;
      }, orElse: () => null);
      if (match == null) {
        return null;
      }

      String? posterPath = match['poster_path'] as String?;
      String? backdropPath = match['backdrop_path'] as String?;
      if (includeVariants) {
        final int? tmdbId = (match['id'] as num?)?.toInt();
        if (tmdbId != null) {
          try {
            final String resource = mediaType == 'tv' ? 'tv' : 'movie';
            final Map<String, dynamic> images = await _httpService.getJson(
              '/$resource/$tmdbId/images',
              params: const <String, String>{
                'include_image_language': 'en,null',
              },
              apiKeyOverride: personalCredential,
            );
            final int variantSeed = _random.nextInt(1 << 31);
            posterPath = selectTmdbArtworkPath(
                  images,
                  collection: 'posters',
                  targetAspectRatio: 2 / 3,
                  variantSeed: variantSeed,
                ) ??
                posterPath;
            backdropPath = selectTmdbArtworkPath(
                  images,
                  collection: 'backdrops',
                  targetAspectRatio: 16 / 9,
                  variantSeed: variantSeed,
                ) ??
                backdropPath;
          } catch (_) {
            // The default /find artwork is still a valid high-quality fallback.
          }
        }
      }
      final _Artwork artwork = _Artwork(
        posterUrl: posterPath == null
            ? null
            : getImageUrl(posterPath, includeVariants ? 'original' : 'w780'),
        backdropUrl: backdropPath == null
            ? null
            : getImageUrl(
                backdropPath,
                includeVariants ? 'original' : 'w1280',
              ),
      );
      _artworkCache[cacheKey] = artwork;
      return artwork;
    } catch (_) {
      // Do not cache network failures. TMDB may become reachable after the
      // user connects VPN/WARP, and the next refresh should retry enrichment.
      return null;
    }
  }
}

class _Artwork {
  const _Artwork({this.posterUrl, this.backdropUrl});

  final String? posterUrl;
  final String? backdropUrl;
}
