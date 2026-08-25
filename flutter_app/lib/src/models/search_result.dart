class SearchResult {
  const SearchResult({
    required this.id,
    required this.mediaType,
    required this.posterPath,
    required this.backdropPath,
    required this.overview,
    required this.voteAverage,
    required this.voteCount,
    required this.popularity,
    required this.genreIds,
    required this.originalLanguage,
    required this.adult,
    this.title,
    this.originalTitle,
    this.releaseDate,
    this.video,
    this.name,
    this.originalName,
    this.firstAirDate,
    this.originCountry = const <String>[],
    this.externalId,
    this.sourceName,
  });

  final int id;
  final String mediaType;
  final String? posterPath;
  final String? backdropPath;
  final String overview;
  final double voteAverage;
  final int voteCount;
  final double popularity;
  final List<int> genreIds;
  final String originalLanguage;
  final bool adult;
  final String? title;
  final String? originalTitle;
  final String? releaseDate;
  final bool? video;
  final String? name;
  final String? originalName;
  final String? firstAirDate;
  final List<String> originCountry;
  final String? externalId;
  final String? sourceName;

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      id: (json['id'] as num?)?.toInt() ?? 0,
      mediaType: (json['media_type'] as String?) ?? 'movie',
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      overview: (json['overview'] as String?) ?? '',
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0,
      voteCount: (json['vote_count'] as num?)?.toInt() ?? 0,
      popularity: (json['popularity'] as num?)?.toDouble() ?? 0,
      genreIds: ((json['genre_ids'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic value) => (value as num).toInt())
          .toList(growable: false),
      originalLanguage: (json['original_language'] as String?) ?? 'en',
      adult: json['adult'] as bool? ?? false,
      title: json['title'] as String?,
      originalTitle: json['original_title'] as String?,
      releaseDate: json['release_date'] as String?,
      video: json['video'] as bool?,
      name: json['name'] as String?,
      originalName: json['original_name'] as String?,
      firstAirDate: json['first_air_date'] as String?,
      originCountry:
          ((json['origin_country'] as List<dynamic>?) ?? const <dynamic>[])
              .map((dynamic value) => value as String)
              .toList(growable: false),
      externalId: json['external_id'] as String?,
      sourceName: json['source_name'] as String?,
    );
  }

  String get displayTitle {
    return title ?? name ?? 'Unknown';
  }
}
