class MediaSummary {
  const MediaSummary({
    required this.id,
    required this.mediaType,
    required this.title,
    required this.posterPath,
    required this.backdropPath,
    required this.releaseDate,
  });

  final int id;
  final String mediaType;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final String releaseDate;

  factory MediaSummary.fromJson(Map<String, dynamic> json) {
    final String inferredType = (json['media_type'] as String?) ??
        (json.containsKey('title') ? 'movie' : 'tv');

    return MediaSummary(
      id: json['id'] as int,
      mediaType: inferredType,
      title:
          (json['title'] as String?) ?? (json['name'] as String?) ?? 'Unknown',
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      releaseDate: (json['release_date'] as String?) ??
          (json['first_air_date'] as String?) ??
          '',
    );
  }
}

class GenreItem {
  const GenreItem({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory GenreItem.fromJson(Map<String, dynamic> json) {
    return GenreItem(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}

class CastItem {
  const CastItem({
    required this.id,
    required this.name,
    required this.character,
    required this.profilePath,
  });

  final int id;
  final String name;
  final String character;
  final String? profilePath;

  factory CastItem.fromJson(Map<String, dynamic> json) {
    return CastItem(
      id: json['id'] as int,
      name: (json['name'] as String?) ?? '',
      character: (json['character'] as String?) ?? '',
      profilePath: json['profile_path'] as String?,
    );
  }
}

class SeasonSummary {
  const SeasonSummary({
    required this.id,
    required this.name,
    required this.posterPath,
    required this.seasonNumber,
    required this.episodeCount,
  });

  final int id;
  final String name;
  final String? posterPath;
  final int seasonNumber;
  final int episodeCount;

  factory SeasonSummary.fromJson(Map<String, dynamic> json) {
    return SeasonSummary(
      id: json['id'] as int,
      name: (json['name'] as String?) ?? '',
      posterPath: json['poster_path'] as String?,
      seasonNumber: (json['season_number'] as num?)?.toInt() ?? 0,
      episodeCount: (json['episode_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class NetworkItem {
  const NetworkItem({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory NetworkItem.fromJson(Map<String, dynamic> json) {
    return NetworkItem(
      id: json['id'] as int,
      name: (json['name'] as String?) ?? '',
    );
  }
}

class ProductionCompanyItem {
  const ProductionCompanyItem({
    required this.id,
    required this.name,
    required this.logoPath,
  });

  final int id;
  final String name;
  final String? logoPath;

  factory ProductionCompanyItem.fromJson(Map<String, dynamic> json) {
    return ProductionCompanyItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      logoPath: json['logo_path'] as String?,
    );
  }
}

class MediaTrailer {
  const MediaTrailer({
    required this.name,
    required this.key,
    required this.site,
    required this.type,
  });

  final String name;
  final String key;
  final String site;
  final String type;

  Uri? get url {
    if (site.toLowerCase() == 'youtube' && key.isNotEmpty) {
      return Uri.parse('https://www.youtube.com/watch?v=$key');
    }
    return null;
  }

  String? get thumbnailUrl {
    if (site.toLowerCase() == 'youtube' && key.isNotEmpty) {
      return 'https://i.ytimg.com/vi/$key/maxresdefault.jpg';
    }
    return null;
  }

  factory MediaTrailer.fromJson(Map<String, dynamic> json) {
    return MediaTrailer(
      name: (json['name'] as String?) ?? 'Trailer',
      key: (json['key'] as String?) ?? '',
      site: (json['site'] as String?) ?? '',
      type: (json['type'] as String?) ?? '',
    );
  }
}

class ExternalRating {
  const ExternalRating({
    required this.source,
    required this.label,
    required this.score,
    this.votes,
    this.normalizedScore,
  });

  final String source;
  final String label;
  final String score;
  final int? votes;
  final double? normalizedScore;
}

class EpisodeItem {
  const EpisodeItem({
    required this.id,
    required this.name,
    required this.overview,
    required this.episodeNumber,
    required this.seasonNumber,
    required this.airDate,
    required this.voteAverage,
    required this.runtime,
    this.stillPath,
  });

  final int id;
  final String name;
  final String overview;
  final int episodeNumber;
  final int seasonNumber;
  final String airDate;
  final double voteAverage;
  final int runtime;
  final String? stillPath;

  factory EpisodeItem.fromJson(Map<String, dynamic> json) {
    return EpisodeItem(
      id: json['id'] as int,
      name: (json['name'] as String?) ?? '',
      overview: (json['overview'] as String?) ?? '',
      episodeNumber: (json['episode_number'] as num?)?.toInt() ?? 0,
      seasonNumber: (json['season_number'] as num?)?.toInt() ?? 0,
      airDate: (json['air_date'] as String?) ?? '',
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0,
      runtime: (json['runtime'] as num?)?.toInt() ?? 0,
      stillPath: json['still_path'] as String?,
    );
  }
}

class MediaDetail {
  const MediaDetail({
    required this.id,
    required this.mediaType,
    required this.title,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    this.logoPath,
    required this.voteAverage,
    required this.voteCount,
    required this.releaseDate,
    required this.runtimeMinutes,
    required this.genres,
    required this.seasons,
    required this.numberOfSeasons,
    required this.networks,
    required this.imdbId,
    required this.cast,
    required this.similarItems,
    this.productionCompanies = const <ProductionCompanyItem>[],
    this.trailers = const <MediaTrailer>[],
    this.director,
    this.originalLanguage,
    this.status,
    this.country,
  });

  final int id;
  final String mediaType;
  final String title;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final String? logoPath;
  final double voteAverage;
  final int voteCount;
  final String releaseDate;
  final int runtimeMinutes;
  final List<GenreItem> genres;
  final List<SeasonSummary> seasons;
  final int numberOfSeasons;
  final List<NetworkItem> networks;
  final List<ProductionCompanyItem> productionCompanies;
  final String? imdbId;
  final List<CastItem> cast;
  final List<MediaSummary> similarItems;
  final List<MediaTrailer> trailers;
  final String? director;
  final String? originalLanguage;
  final String? status;
  final String? country;

  factory MediaDetail.fromJson(
    Map<String, dynamic> json, {
    required String mediaType,
    List<CastItem> cast = const <CastItem>[],
    List<MediaSummary> similarItems = const <MediaSummary>[],
    List<MediaTrailer> trailers = const <MediaTrailer>[],
    String? director,
  }) {
    final int runtime = mediaType == 'movie'
        ? (json['runtime'] as num?)?.toInt() ?? 0
        : (((json['episode_run_time'] as List<dynamic>?) ?? const <dynamic>[])
                .isNotEmpty
            ? (((json['episode_run_time'] as List<dynamic>).first as num)
                .toInt())
            : 45);

    return MediaDetail(
      id: json['id'] as int,
      mediaType: mediaType,
      title: (json['title'] as String?) ?? (json['name'] as String?) ?? '',
      overview: (json['overview'] as String?) ?? '',
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      logoPath: _readLogoPath(json['images']),
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0,
      voteCount: (json['vote_count'] as num?)?.toInt() ?? 0,
      releaseDate: (json['release_date'] as String?) ??
          (json['first_air_date'] as String?) ??
          '',
      runtimeMinutes: runtime,
      genres: ((json['genres'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic item) =>
              GenreItem.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      seasons: ((json['seasons'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic item) =>
              SeasonSummary.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      numberOfSeasons: (json['number_of_seasons'] as num?)?.toInt() ?? 0,
      networks: ((json['networks'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic item) =>
              NetworkItem.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      productionCompanies: ((json['production_companies'] as List<dynamic>?) ??
              const <dynamic>[])
          .map((dynamic item) => ProductionCompanyItem.fromJson(
                item as Map<String, dynamic>,
              ))
          .toList(growable: false),
      imdbId: json['imdb_id'] as String?,
      cast: cast,
      similarItems: similarItems,
      trailers: trailers,
      director: director,
      originalLanguage: json['original_language'] as String?,
      status: json['status'] as String?,
      country: (((json['production_countries'] as List<dynamic>?) ??
                  const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map((Map<String, dynamic> item) => item['name']?.toString())
              .whereType<String>()
              .where((String item) => item.trim().isNotEmpty)
              .toList(growable: false)
              .join(', '))
          .trim(),
    );
  }
}

String? _readLogoPath(dynamic images) {
  if (images is! Map<String, dynamic>) {
    return null;
  }
  final List<Map<String, dynamic>> logos =
      ((images['logos'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
  if (logos.isEmpty) {
    return null;
  }

  Map<String, dynamic>? preferred;
  for (final Map<String, dynamic> logo in logos) {
    if (logo['iso_639_1']?.toString() == 'en') {
      preferred = logo;
      break;
    }
  }
  if (preferred == null) {
    for (final Map<String, dynamic> logo in logos) {
      if (logo['iso_639_1'] == null) {
        preferred = logo;
        break;
      }
    }
  }

  final Map<String, dynamic> selected = preferred ?? logos.first;
  final String path = selected['file_path']?.toString().trim() ?? '';
  return path.isEmpty ? null : path;
}
