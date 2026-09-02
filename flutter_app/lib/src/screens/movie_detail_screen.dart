import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/favorite_item.dart';
import '../models/tmdb_media_models.dart';
import '../models/torbox_models.dart';
import '../services/favorites_repository.dart';
import '../services/mdblist_api_service.dart';
import '../services/stremio_addons_service.dart';
import '../services/tmdb_image.dart';
import '../services/tmdb_media_service.dart';
import '../theme/app_colors.dart';
import '../widgets/optimized_network_image.dart';
import '../widgets/title_logo.dart';
import 'episode_screen.dart';
import 'magnet_screen.dart';
import 'streamed_sources_screen.dart';

class MovieDetailScreen extends StatefulWidget {
  MovieDetailScreen({
    super.key,
    required this.id,
    required this.mediaType,
    this.externalId,
    this.fallbackTitle,
    this.fallbackPosterPath,
    this.fallbackBackdropPath,
    this.fallbackOverview,
    this.fallbackReleaseInfo,
    this.fallbackSourceName,
    MediaCatalogService? mediaService,
    StremioAddonsService? addonsService,
    MdbListApiService? mdbListApiService,
    FavoritesRepository? favoritesRepository,
  })  : mediaService = mediaService ?? TmdbMediaService(),
        addonsService = addonsService ?? StremioAddonsService(),
        mdbListApiService = mdbListApiService ?? MdbListApiService(),
        favoritesRepository = favoritesRepository ?? FavoritesRepository();

  final int id;
  final String mediaType;
  final String? externalId;
  final String? fallbackTitle;
  final String? fallbackPosterPath;
  final String? fallbackBackdropPath;
  final String? fallbackOverview;
  final String? fallbackReleaseInfo;
  final String? fallbackSourceName;
  final MediaCatalogService mediaService;
  final StremioAddonsService addonsService;
  final MdbListApiService mdbListApiService;
  final FavoritesRepository favoritesRepository;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  static const int _initialRetryCount = 3;

  final ScrollController _scrollController = ScrollController();

  MediaDetail? _detail;
  List<ExternalRating> _externalRatings = const <ExternalRating>[];
  bool _loading = true;
  bool _showFullDescription = false;
  bool _isFavorited = false;
  bool _showPinnedTitle = false;
  int? _selectedSeasonNumber;
  List<EpisodeItem> _episodes = const <EpisodeItem>[];
  bool _loadingEpisodes = false;
  int _episodeRequest = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadDetail();
    _loadFavoriteState();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final bool shouldShow = _scrollController.hasClients &&
        _scrollController.offset > MediaQuery.of(context).size.height * 0.34;
    if (shouldShow == _showPinnedTitle) {
      return;
    }
    setState(() {
      _showPinnedTitle = shouldShow;
    });
  }

  Future<void> _loadDetail({int retryCount = _initialRetryCount}) async {
    if (!_loading) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final MediaDetail detail = await _fetchDetail();
      if (!mounted) {
        return;
      }

      setState(() {
        _detail = detail;
        _loading = false;
      });
      _loadExternalRatings(detail);
      if (detail.mediaType == 'tv') {
        final List<SeasonSummary> seasons = detail.seasons
            .where((SeasonSummary season) => season.seasonNumber > 0)
            .toList(growable: false);
        if (seasons.isNotEmpty) {
          _selectedSeasonNumber ??= seasons.first.seasonNumber;
          unawaited(_loadEpisodes(_selectedSeasonNumber!));
        }
      }
    } catch (_) {
      if (retryCount > 0) {
        final int delayMs = 400 * (_initialRetryCount - retryCount + 1);
        await Future<void>.delayed(Duration(milliseconds: delayMs));
        if (!mounted) {
          return;
        }
        await _loadDetail(retryCount: retryCount - 1);
        return;
      }

      if (!mounted) {
        return;
      }

      final MediaDetail? fallback = _fallbackDetail();
      setState(() {
        _detail = fallback;
        _loading = false;
      });
    }
  }

  Future<MediaDetail> _fetchDetail() async {
    if (widget.id > 0) {
      return widget.mediaService.getMediaDetail(widget.id, widget.mediaType);
    }

    final String externalId = (widget.externalId ?? '').trim();
    if (externalId.isNotEmpty) {
      final Future<MediaDetail?> addonFuture = _fetchAddonDetail(externalId);
      Object? tmdbError;
      final Future<MediaDetail?> tmdbFuture = widget.mediaService
          .findMediaByExternalId(externalId, widget.mediaType)
          .then<MediaDetail?>((MediaDetail? detail) => detail)
          .onError((Object error, StackTrace stackTrace) {
        tmdbError = error;
        return null;
      });
      final List<MediaDetail?> results = await Future.wait<MediaDetail?>(
        <Future<MediaDetail?>>[addonFuture, tmdbFuture],
      );
      final MediaDetail? addonDetail = results.first;
      final MediaDetail? tmdbDetail = results.last;

      if (addonDetail != null && tmdbDetail != null) {
        return _mergeDetails(addonDetail, tmdbDetail, externalId);
      }
      if (tmdbDetail != null) {
        return tmdbDetail;
      }
      if (addonDetail != null) {
        return addonDetail;
      }

      final MediaDetail? fallback = _fallbackDetail();
      if (fallback != null) {
        return fallback;
      }
      if (tmdbError != null) {
        throw tmdbError!;
      }
    }

    final MediaDetail? fallback = _fallbackDetail();
    if (fallback != null) {
      return fallback;
    }
    throw StateError('No metadata source was available for this title.');
  }

  MediaDetail _mergeDetails(
    MediaDetail addon,
    MediaDetail enriched,
    String externalId,
  ) {
    return MediaDetail(
      id: enriched.id > 0 ? enriched.id : addon.id,
      mediaType: enriched.mediaType,
      title: addon.title.trim().isNotEmpty ? addon.title : enriched.title,
      overview:
          addon.overview.trim().isNotEmpty ? addon.overview : enriched.overview,
      // Prefer TMDB artwork for the polished poster/backdrop treatment. Addon
      // artwork remains a fallback when TMDB has no image for the title.
      posterPath: enriched.posterPath ?? addon.posterPath,
      backdropPath: enriched.backdropPath ?? addon.backdropPath,
      logoPath: enriched.logoPath ?? addon.logoPath,
      voteAverage:
          enriched.voteAverage > 0 ? enriched.voteAverage : addon.voteAverage,
      voteCount: enriched.voteCount > 0 ? enriched.voteCount : addon.voteCount,
      releaseDate: addon.releaseDate.isNotEmpty
          ? addon.releaseDate
          : enriched.releaseDate,
      runtimeMinutes: enriched.runtimeMinutes > 0
          ? enriched.runtimeMinutes
          : addon.runtimeMinutes,
      genres: addon.genres.isNotEmpty ? addon.genres : enriched.genres,
      seasons: enriched.seasons.isNotEmpty ? enriched.seasons : addon.seasons,
      numberOfSeasons: enriched.numberOfSeasons > 0
          ? enriched.numberOfSeasons
          : addon.numberOfSeasons,
      networks:
          enriched.networks.isNotEmpty ? enriched.networks : addon.networks,
      imdbId: enriched.imdbId ?? addon.imdbId ?? externalId,
      cast: enriched.cast.isNotEmpty ? enriched.cast : addon.cast,
      similarItems: enriched.similarItems.isNotEmpty
          ? enriched.similarItems
          : addon.similarItems,
      productionCompanies: enriched.productionCompanies.isNotEmpty
          ? enriched.productionCompanies
          : addon.productionCompanies,
      trailers:
          enriched.trailers.isNotEmpty ? enriched.trailers : addon.trailers,
      episodes:
          enriched.episodes.isNotEmpty ? enriched.episodes : addon.episodes,
      director: enriched.director ?? addon.director,
      originalLanguage: enriched.originalLanguage ?? addon.originalLanguage,
      status: enriched.status ?? addon.status,
      country: (enriched.country ?? '').trim().isNotEmpty
          ? enriched.country
          : addon.country,
    );
  }

  Future<MediaDetail?> _fetchAddonDetail(String externalId) async {
    try {
      final AddonMetaItem? meta = await widget.addonsService.fetchMetadata(
        mediaType: widget.mediaType,
        id: externalId,
      );
      if (meta == null) {
        return null;
      }
      return _detailFromAddonMeta(meta, externalId);
    } catch (_) {
      return null;
    }
  }

  MediaDetail _detailFromAddonMeta(AddonMetaItem meta, String externalId) {
    final String fallbackTitle = (widget.fallbackTitle ?? '').trim();
    final String title = meta.name.trim().isNotEmpty
        ? meta.name.trim()
        : fallbackTitle.isNotEmpty
            ? fallbackTitle
            : externalId;

    final List<EpisodeItem> episodes = meta.videos
        .map(
          (AddonMetaVideo video) => EpisodeItem(
            id: video.numericId,
            name: video.name,
            overview: video.overview ?? '',
            episodeNumber: video.episodeNumber,
            seasonNumber: video.seasonNumber,
            airDate: video.released ?? '',
            voteAverage: video.rating,
            runtime: video.runtimeMinutes,
            stillPath: video.thumbnail,
          ),
        )
        .toList(growable: false)
      ..sort((EpisodeItem a, EpisodeItem b) {
        final int seasonOrder = a.seasonNumber.compareTo(b.seasonNumber);
        return seasonOrder != 0
            ? seasonOrder
            : a.episodeNumber.compareTo(b.episodeNumber);
      });
    final Map<int, List<AddonMetaVideo>> videosBySeason =
        <int, List<AddonMetaVideo>>{};
    for (final AddonMetaVideo video in meta.videos) {
      videosBySeason
          .putIfAbsent(video.seasonNumber, () => <AddonMetaVideo>[])
          .add(video);
    }
    final List<SeasonSummary> seasons = videosBySeason.entries
        .where((MapEntry<int, List<AddonMetaVideo>> entry) => entry.key > 0)
        .map(
          (MapEntry<int, List<AddonMetaVideo>> entry) => SeasonSummary(
            id: entry.key,
            name: 'Season ${entry.key}',
            posterPath: entry.value
                .map((AddonMetaVideo video) => video.seasonPoster)
                .whereType<String>()
                .firstOrNull,
            seasonNumber: entry.key,
            episodeCount: entry.value.length,
          ),
        )
        .toList(growable: false)
      ..sort((SeasonSummary a, SeasonSummary b) =>
          a.seasonNumber.compareTo(b.seasonNumber));

    return MediaDetail(
      id: widget.id,
      mediaType: meta.mediaType == 'tv' ? 'tv' : widget.mediaType,
      title: title,
      overview: (meta.description ?? widget.fallbackOverview ?? '').trim(),
      posterPath: meta.poster ?? widget.fallbackPosterPath,
      backdropPath:
          meta.background ?? widget.fallbackBackdropPath ?? meta.poster,
      logoPath: meta.logo,
      voteAverage: 0,
      voteCount: 0,
      releaseDate: _releaseDateFromInfo(
        meta.releaseInfo ?? widget.fallbackReleaseInfo,
      ),
      runtimeMinutes: _runtimeMinutesFromAddon(meta.runtime),
      genres: meta.genres
          .map((String genre) => GenreItem(id: 0, name: genre))
          .toList(growable: false),
      seasons: seasons,
      numberOfSeasons: seasons.length,
      networks: widget.fallbackSourceName == null
          ? const <NetworkItem>[]
          : <NetworkItem>[
              NetworkItem(id: 0, name: widget.fallbackSourceName!),
            ],
      imdbId: externalId,
      cast: meta.cast
          .asMap()
          .entries
          .map(
            (MapEntry<int, String> entry) => CastItem(
              id: entry.key,
              name: entry.value,
              character: '',
              profilePath: null,
            ),
          )
          .toList(growable: false),
      similarItems: const <MediaSummary>[],
      episodes: episodes,
      trailers: meta.trailers
          .map(
            (AddonMetaTrailer trailer) => MediaTrailer(
              name: trailer.name,
              key: trailer.key,
              site: trailer.site,
              type: trailer.type,
            ),
          )
          .toList(growable: false),
      director: meta.director ?? widget.fallbackSourceName,
      originalLanguage: meta.language,
      status: meta.status,
      country: meta.country,
    );
  }

  MediaDetail? _fallbackDetail() {
    final String title = (widget.fallbackTitle ?? '').trim();
    final String externalId = (widget.externalId ?? '').trim();
    if (title.isEmpty && externalId.isEmpty) {
      return null;
    }

    return MediaDetail(
      id: widget.id,
      mediaType: widget.mediaType,
      title: title.isEmpty ? externalId : title,
      overview: (widget.fallbackOverview ?? '').trim(),
      posterPath: widget.fallbackPosterPath,
      backdropPath: widget.fallbackBackdropPath ?? widget.fallbackPosterPath,
      voteAverage: 0,
      voteCount: 0,
      releaseDate: _releaseDateFromInfo(widget.fallbackReleaseInfo),
      runtimeMinutes: 0,
      genres: const <GenreItem>[],
      seasons: const <SeasonSummary>[],
      numberOfSeasons: 0,
      networks: widget.fallbackSourceName == null
          ? const <NetworkItem>[]
          : <NetworkItem>[
              NetworkItem(id: 0, name: widget.fallbackSourceName!),
            ],
      imdbId: externalId.isEmpty ? null : externalId,
      cast: const <CastItem>[],
      similarItems: const <MediaSummary>[],
      director: widget.fallbackSourceName,
    );
  }

  Future<void> _loadExternalRatings(MediaDetail detail) async {
    final List<ExternalRating> ratings =
        await widget.mdbListApiService.getRatings(detail);
    if (!mounted) {
      return;
    }
    setState(() {
      _externalRatings = ratings;
    });
  }

  Future<void> _loadEpisodes(int seasonNumber) async {
    final MediaDetail? detail = _detail;
    if (detail == null || detail.mediaType != 'tv') {
      return;
    }

    final List<EpisodeItem> addonEpisodes = detail.episodes
        .where((EpisodeItem episode) => episode.seasonNumber == seasonNumber)
        .toList(growable: false);

    final int request = ++_episodeRequest;
    setState(() {
      _selectedSeasonNumber = seasonNumber;
      _loadingEpisodes = true;
      if (addonEpisodes.isNotEmpty) {
        _episodes = addonEpisodes;
      }
    });

    if (detail.id <= 0) {
      setState(() {
        _loadingEpisodes = false;
      });
      return;
    }

    try {
      final List<EpisodeItem> episodes =
          await widget.mediaService.getSeasonEpisodes(detail.id, seasonNumber);
      if (!mounted || request != _episodeRequest) {
        return;
      }
      setState(() {
        _episodes = _mergeEpisodes(addonEpisodes, episodes);
        _loadingEpisodes = false;
      });
    } catch (_) {
      if (!mounted || request != _episodeRequest) {
        return;
      }
      setState(() {
        _episodes = addonEpisodes;
        _loadingEpisodes = false;
      });
    }
  }

  List<EpisodeItem> _mergeEpisodes(
    List<EpisodeItem> addonEpisodes,
    List<EpisodeItem> tmdbEpisodes,
  ) {
    if (addonEpisodes.isEmpty) {
      return tmdbEpisodes;
    }
    if (tmdbEpisodes.isEmpty) {
      return addonEpisodes;
    }

    final Map<int, EpisodeItem> addonByNumber = <int, EpisodeItem>{
      for (final EpisodeItem episode in addonEpisodes)
        episode.episodeNumber: episode,
    };
    final List<EpisodeItem> merged = tmdbEpisodes.map((EpisodeItem tmdb) {
      final EpisodeItem? addon = addonByNumber.remove(tmdb.episodeNumber);
      if (addon == null) {
        return tmdb;
      }
      return EpisodeItem(
        id: tmdb.id > 0 ? tmdb.id : addon.id,
        name: tmdb.name.trim().isNotEmpty ? tmdb.name : addon.name,
        overview:
            tmdb.overview.trim().isNotEmpty ? tmdb.overview : addon.overview,
        episodeNumber: tmdb.episodeNumber,
        seasonNumber: tmdb.seasonNumber,
        airDate: tmdb.airDate.trim().isNotEmpty ? tmdb.airDate : addon.airDate,
        voteAverage:
            tmdb.voteAverage > 0 ? tmdb.voteAverage : addon.voteAverage,
        runtime: tmdb.runtime > 0 ? tmdb.runtime : addon.runtime,
        stillPath: tmdb.stillPath ?? addon.stillPath,
      );
    }).toList(growable: true)
      ..addAll(addonByNumber.values)
      ..sort((EpisodeItem a, EpisodeItem b) =>
          a.episodeNumber.compareTo(b.episodeNumber));
    return merged;
  }

  Future<void> _loadFavoriteState() async {
    final bool favorited = await widget.favoritesRepository.isFavorite(
      widget.id,
      widget.mediaType,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _isFavorited = favorited;
    });
  }

  Future<void> _toggleFavorite() async {
    final MediaDetail? detail = _detail;
    if (detail == null) {
      return;
    }

    final FavoriteItem item = FavoriteItem(
      id: detail.id,
      mediaType: detail.mediaType,
      title: detail.title,
      posterPath: detail.posterPath,
      backdropPath: detail.backdropPath,
      rating: detail.voteAverage,
      year: _year(detail.releaseDate),
      addedAt: DateTime.now().millisecondsSinceEpoch,
    );

    final bool nextState =
        await widget.favoritesRepository.toggleFavorite(item);
    if (!mounted) {
      return;
    }

    setState(() {
      _isFavorited = nextState;
    });
  }

  void _showPlaybackTools() {
    final MediaDetail? detail = _detail;
    if (detail == null) {
      return;
    }

    if (detail.mediaType == 'tv') {
      final EpisodeItem? firstEpisode =
          _episodes.cast<EpisodeItem?>().firstWhere(
                (EpisodeItem? episode) => episode?.episodeNumber == 1,
                orElse: () => null,
              );
      if ((detail.imdbId ?? '').isNotEmpty) {
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (BuildContext context) => OmnioSourcesScreen(
              title: detail.title,
              logoPath: detail.logoPath,
              posterPath: detail.posterPath ?? detail.backdropPath,
              mediaType: detail.mediaType,
              imdbId: detail.imdbId!,
              tmdbId: detail.id > 0 ? detail.id : null,
              seasonNumber:
                  firstEpisode?.seasonNumber ?? _selectedSeasonNumber ?? 1,
              episodeNumber: firstEpisode?.episodeNumber ?? 1,
              episodeName: firstEpisode?.name,
            ),
          ),
        );
        return;
      }

      if (detail.id <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This show is missing an ID for episode playback.'),
          ),
        );
        return;
      }

      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => EpisodeScreen(
            tvId: detail.id,
            initialSeason: 1,
            showName: detail.title,
            posterPath: detail.posterPath,
            mediaService: widget.mediaService,
          ),
        ),
      );
      return;
    }

    if ((detail.imdbId ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This title is missing an IMDb ID, so sources cannot search it yet.',
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => OmnioSourcesScreen(
          title: detail.title,
          logoPath: detail.logoPath,
          posterPath: detail.posterPath ?? detail.backdropPath,
          mediaType: detail.mediaType,
          imdbId: detail.imdbId!,
          tmdbId: detail.id > 0 ? detail.id : null,
        ),
      ),
    );
  }

  void _openRelated(MediaSummary item) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => MovieDetailScreen(
          id: item.id,
          mediaType: item.mediaType,
          mediaService: widget.mediaService,
          favoritesRepository: widget.favoritesRepository,
        ),
      ),
    );
  }

  Future<void> _openTrailer(MediaTrailer trailer) async {
    final Uri? url = trailer.url;
    if (url == null) {
      return;
    }
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  void _openSeason(SeasonSummary season) {
    final MediaDetail? detail = _detail;
    if (detail == null) {
      return;
    }

    unawaited(_loadEpisodes(season.seasonNumber));
  }

  void _openEpisode(EpisodeItem episode) {
    final MediaDetail? detail = _detail;
    if (detail == null) {
      return;
    }

    if ((detail.imdbId ?? '').isEmpty) {
      _openSeason(
        SeasonSummary(
          id: 0,
          name: 'Season ${episode.seasonNumber}',
          posterPath: detail.posterPath,
          seasonNumber: episode.seasonNumber,
          episodeCount: 0,
        ),
      );
      return;
    }

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => OmnioSourcesScreen(
          title: detail.title,
          logoPath: detail.logoPath,
          posterPath: detail.posterPath ?? detail.backdropPath,
          mediaType: 'tv',
          imdbId: detail.imdbId!,
          tmdbId: detail.id > 0 ? detail.id : null,
          seasonNumber: episode.seasonNumber,
          episodeNumber: episode.episodeNumber,
          episodeName: episode.name,
        ),
      ),
    );
  }

  void _openMoreSheet() {
    final MediaDetail? detail = _detail;
    if (detail == null) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _SheetAction(
                  icon: _isFavorited
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: _isFavorited ? 'Remove from saved' : 'Add to saved',
                  onTap: () {
                    Navigator.of(context).pop();
                    _toggleFavorite();
                  },
                ),
                _SheetAction(
                  icon: Icons.link_rounded,
                  label: 'Open magnet/import tools',
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) => MagnetScreen(),
                      ),
                    );
                  },
                ),
                if (detail.trailers.isNotEmpty)
                  _SheetAction(
                    icon: Icons.smart_display_rounded,
                    label: 'Play trailer',
                    onTap: () {
                      Navigator.of(context).pop();
                      _openTrailer(detail.trailers.first);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.text),
        ),
      );
    }

    final MediaDetail? detail = _detail;
    if (detail == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'Could not load this title.',
                  style: TextStyle(color: AppColors.text),
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: _loadDetail,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final bool isMovie = detail.mediaType == 'movie';
    final double screenHeight = MediaQuery.of(context).size.height;
    final double heroHeight = (screenHeight * 0.66).clamp(460.0, 610.0);

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        children: <Widget>[
          CustomScrollView(
            controller: _scrollController,
            cacheExtent: 850,
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: _HeroPanel(
                  detail: detail,
                  height: heroHeight,
                  scrollController: _scrollController,
                  isShow: !isMovie,
                  isFavorited: _isFavorited,
                  onPlay: _showPlaybackTools,
                  onMore: _openMoreSheet,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 36),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    <Widget>[
                      _OverviewBlock(
                        detail: detail,
                        externalRatings: _externalRatings,
                        isExpanded: _showFullDescription,
                        onToggle: () {
                          setState(() {
                            _showFullDescription = !_showFullDescription;
                          });
                        },
                      ),
                      if (!isMovie &&
                          detail.seasons.any(
                            (SeasonSummary season) => season.seasonNumber > 0,
                          )) ...<Widget>[
                        const SizedBox(height: 30),
                        _ShowEpisodesSection(
                          seasons: detail.seasons
                              .where(
                                (SeasonSummary season) =>
                                    season.seasonNumber > 0,
                              )
                              .toList(growable: false),
                          selectedSeasonNumber: _selectedSeasonNumber,
                          episodes: _episodes,
                          loading: _loadingEpisodes,
                          fallbackPosterPath:
                              detail.backdropPath ?? detail.posterPath,
                          onSeasonChanged: _loadEpisodes,
                          onEpisodeTap: _openEpisode,
                        ),
                      ],
                      if (detail.trailers.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 28),
                        const Row(
                          children: <Widget>[
                            _SectionTitle(title: 'Trailers', showChevron: true),
                            SizedBox(width: 16),
                            _TrailerFilterChip(),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          child: Row(
                            children: detail.trailers
                                .map(
                                  (MediaTrailer trailer) => Padding(
                                    padding: const EdgeInsets.only(right: 14),
                                    child: _TrailerCard(
                                      trailer: trailer,
                                      onTap: () => _openTrailer(trailer),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ),
                      ],
                      if (detail.similarItems.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 30),
                        const _SectionTitle(
                            title: 'Related', showChevron: true),
                        const SizedBox(height: 14),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          child: Row(
                            children: detail.similarItems
                                .map(
                                  (MediaSummary item) => Padding(
                                    padding: const EdgeInsets.only(right: 14),
                                    child: _RelatedCard(
                                      item: item,
                                      onTap: () => _openRelated(item),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ),
                      ],
                      if (detail.cast.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 30),
                        const _SectionTitle(
                          title: 'Cast & Crew',
                          showChevron: true,
                        ),
                        const SizedBox(height: 14),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          child: Row(
                            children: detail.cast
                                .map(
                                  (CastItem member) => Padding(
                                    padding: const EdgeInsets.only(right: 18),
                                    child: _CastCard(member: member),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ),
                      ],
                      const SizedBox(height: 30),
                      const _SectionTitle(title: 'Information'),
                      const SizedBox(height: 12),
                      _DetailsTable(detail: detail),
                      if ((detail.originalLanguage ?? '')
                          .isNotEmpty) ...<Widget>[
                        const SizedBox(height: 28),
                        const _SectionTitle(title: 'Languages'),
                        const SizedBox(height: 10),
                        _InfoTextBlock(
                          label: 'Original audio',
                          value: detail.originalLanguage!.toUpperCase(),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: _PinnedToolbar(
              title: detail.title,
              logoPath: detail.logoPath,
              showTitle: _showPinnedTitle,
              isFavorited: _isFavorited,
              onBack: () => Navigator.of(context).maybePop(),
              onFavorite: _toggleFavorite,
            ),
          ),
        ],
      ),
    );
  }
}

class _PinnedToolbar extends StatelessWidget {
  const _PinnedToolbar({
    required this.title,
    this.logoPath,
    required this.showTitle,
    required this.isFavorited,
    required this.onBack,
    required this.onFavorite,
  });

  final String title;
  final String? logoPath;
  final bool showTitle;
  final bool isFavorited;
  final VoidCallback onBack;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        decoration: BoxDecoration(
          color:
              showTitle ? Colors.black.withOpacity(0.74) : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: showTitle
                  ? Colors.white.withOpacity(0.06)
                  : Colors.transparent,
            ),
          ),
        ),
        child: Row(
          children: <Widget>[
            _CircleActionButton(
              icon: Icons.arrow_back_rounded,
              onTap: onBack,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: showTitle ? 1 : 0,
                child: Center(
                  child: TitleLogo(
                    title: title,
                    logoPath: logoPath,
                    maxLines: 1,
                    logoHeight: 34,
                    maxLogoWidth: 190,
                    textStyle: const TextStyle(
                      color: AppColors.text,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _CircleActionButton(
              icon: isFavorited ? Icons.check_rounded : Icons.add_rounded,
              onTap: onFavorite,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.detail,
    required this.height,
    required this.scrollController,
    required this.isShow,
    required this.isFavorited,
    required this.onPlay,
    required this.onMore,
  });

  final MediaDetail detail;
  final double height;
  final ScrollController scrollController;
  final bool isShow;
  final bool isFavorited;
  final VoidCallback onPlay;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final double frameAspect = MediaQuery.sizeOf(context).width / height;
    final bool usePortraitArtwork = frameAspect < 1.05;
    final String? imagePath = usePortraitArtwork
        ? (detail.posterPath ?? detail.backdropPath)
        : (detail.backdropPath ?? detail.posterPath);
    final String genreLine =
        detail.genres.take(2).map((GenreItem item) => item.name).join(' - ');

    return SizedBox(
      height: height,
      child: AnimatedBuilder(
        animation: scrollController,
        builder: (BuildContext context, Widget? child) {
          final double offset = scrollController.hasClients
              ? scrollController.offset.clamp(0, height * 0.45).toDouble()
              : 0;
          final double scale = 1 + (offset / height) * 0.055;

          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (imagePath == null)
                const ColoredBox(color: AppColors.cardBackground)
              else
                ClipRect(
                  child: Transform.translate(
                    offset: Offset(0, offset * 0.24),
                    child: Transform.scale(
                      scale: scale,
                      child: OptimizedNetworkImage(
                        url: getImageUrl(imagePath, 'original'),
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        alignment: usePortraitArtwork
                            ? Alignment.topCenter
                            : Alignment.center,
                        cacheWidth: 1440,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (
                          BuildContext context,
                          Object error,
                          StackTrace? stackTrace,
                        ) {
                          return const ColoredBox(
                              color: AppColors.cardBackground);
                        },
                      ),
                    ),
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.black.withOpacity(0.10),
                      Colors.black.withOpacity(0.18),
                      Colors.black.withOpacity(0.64),
                      const Color(0xFF050505),
                    ],
                    stops: const <double>[0, 0.36, 0.76, 1],
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 28,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    TitleLogo(
                      title: detail.title,
                      logoPath: detail.logoPath,
                      maxLines: 2,
                      logoHeight: 96,
                      maxLogoWidth: 330,
                      textStyle: const TextStyle(
                        color: AppColors.text,
                        fontSize: 34,
                        height: 0.95,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.3,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (genreLine.isNotEmpty)
                      Text(
                        genreLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    const SizedBox(height: 18),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.text,
                              foregroundColor: AppColors.background,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            onPressed: onPlay,
                            icon:
                                const Icon(Icons.play_arrow_rounded, size: 24),
                            label: isShow
                                ? const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Text(
                                        'Play',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                        ),
                                      ),
                                      SizedBox(width: 5),
                                      Text(
                                        'First Episode',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  )
                                : const Text(
                                    'Play',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _RoundMoreButton(onTap: onMore),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OverviewBlock extends StatelessWidget {
  const _OverviewBlock({
    required this.detail,
    required this.externalRatings,
    required this.isExpanded,
    required this.onToggle,
  });

  final MediaDetail detail;
  final List<ExternalRating> externalRatings;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final List<String> facts = <String>[
      _year(detail.releaseDate),
      if (detail.runtimeMinutes > 0) _formatRuntime(detail.runtimeMinutes),
      if (detail.mediaType == 'tv' && detail.numberOfSeasons > 0)
        '${detail.numberOfSeasons} seasons',
    ].where((String item) => item.isNotEmpty).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            ...facts.map(
              (String item) => Text(
                item,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (detail.voteAverage > 0)
              _CompactRating(score: detail.voteAverage),
            ...externalRatings.take(2).map(
                  (ExternalRating rating) => _SmallBadge(label: rating.score),
                ),
          ],
        ),
        if ((detail.director ?? '').isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: detail.mediaType == 'tv' ? 'Creator: ' : 'Director: ',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(text: detail.director),
              ],
            ),
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          detail.overview.isEmpty
              ? 'No description available.'
              : detail.overview,
          maxLines: isExpanded ? null : 4,
          overflow: isExpanded ? null : TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 15,
            height: 1.48,
          ),
        ),
        if (detail.overview.length > 130)
          GestureDetector(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                isExpanded ? 'Show Less' : 'Show More',
                style: const TextStyle(
                  color: AppColors.textSubtle,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CompactRating extends StatelessWidget {
  const _CompactRating({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.star_rounded, color: Color(0xFFFFC83D), size: 17),
          const SizedBox(width: 4),
          Text(
            score.toStringAsFixed(1),
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ShowEpisodesSection extends StatelessWidget {
  const _ShowEpisodesSection({
    required this.seasons,
    required this.selectedSeasonNumber,
    required this.episodes,
    required this.loading,
    required this.fallbackPosterPath,
    required this.onSeasonChanged,
    required this.onEpisodeTap,
  });

  final List<SeasonSummary> seasons;
  final int? selectedSeasonNumber;
  final List<EpisodeItem> episodes;
  final bool loading;
  final String? fallbackPosterPath;
  final ValueChanged<int> onSeasonChanged;
  final ValueChanged<EpisodeItem> onEpisodeTap;

  @override
  Widget build(BuildContext context) {
    final int selected = selectedSeasonNumber ?? seasons.first.seasonNumber;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const _SectionTitle(title: 'Seasons'),
            const Spacer(),
            PopupMenuButton<int>(
              initialValue: selected,
              onSelected: onSeasonChanged,
              color: AppColors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              itemBuilder: (BuildContext context) => seasons
                  .map(
                    (SeasonSummary season) => PopupMenuItem<int>(
                      value: season.seasonNumber,
                      child: Text(
                        season.name,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Season ${selected.toString()}',
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.text,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (loading)
          const SizedBox(
            height: 166,
            child: Center(
              child: CircularProgressIndicator(color: AppColors.text),
            ),
          )
        else if (episodes.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              'Episode artwork is not available for this season yet.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                height: 1.35,
              ),
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: episodes
                  .map(
                    (EpisodeItem episode) => Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: _EpisodeCard(
                        episode: episode,
                        fallbackPosterPath: fallbackPosterPath,
                        onTap: () => onEpisodeTap(episode),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
      ],
    );
  }
}

class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({
    required this.episode,
    required this.fallbackPosterPath,
    required this.onTap,
  });

  final EpisodeItem episode;
  final String? fallbackPosterPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String? imagePath = episode.stillPath ?? fallbackPosterPath;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 214,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 214,
                height: 124,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    if (imagePath == null)
                      const ColoredBox(color: AppColors.cardBackground)
                    else
                      OptimizedNetworkImage(
                        url: getImageUrl(imagePath, 'w780'),
                        fit: BoxFit.cover,
                        cacheWidth: 640,
                        errorBuilder: (
                          BuildContext context,
                          Object error,
                          StackTrace? stackTrace,
                        ) {
                          return const ColoredBox(
                            color: AppColors.cardBackground,
                          );
                        },
                      ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            Colors.transparent,
                            Colors.black.withOpacity(0.76),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 10,
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              'E${episode.episodeNumber}',
                              style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (episode.runtime > 0)
                            Text(
                              '${episode.runtime}m',
                              style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Positioned(
                      right: 10,
                      top: 10,
                      child: Icon(
                        Icons.play_circle_fill_rounded,
                        color: AppColors.text,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              episode.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 14,
                height: 1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              episode.overview.isEmpty ? 'Play episode' : episode.overview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrailerFilterChip extends StatelessWidget {
  const _TrailerFilterChip();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'Trailer',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(width: 4),
        Icon(Icons.keyboard_arrow_down_rounded,
            color: AppColors.text, size: 19),
      ],
    );
  }
}

class _TrailerCard extends StatelessWidget {
  const _TrailerCard({
    required this.trailer,
    required this.onTap,
  });

  final MediaTrailer trailer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String? thumbnail = trailer.thumbnailUrl;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 230,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              height: 132,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  if (thumbnail == null)
                    const ColoredBox(color: AppColors.cardBackground)
                  else
                    OptimizedNetworkImage(
                      url: thumbnail,
                      fit: BoxFit.cover,
                      cacheWidth: 520,
                      errorBuilder: (
                        BuildContext context,
                        Object error,
                        StackTrace? stackTrace,
                      ) {
                        return const ColoredBox(
                            color: AppColors.cardBackground);
                      },
                    ),
                  Center(
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.58),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: AppColors.text,
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 9),
            Text(
              trailer.name.isEmpty ? 'Trailer' : trailer.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsTable extends StatelessWidget {
  const _DetailsTable({required this.detail});

  final MediaDetail detail;

  @override
  Widget build(BuildContext context) {
    final List<_DetailPair> rows = <_DetailPair>[
      _DetailPair(
        detail.mediaType == 'movie' ? 'Release Info' : 'First Air Date',
        _year(detail.releaseDate),
      ),
      _DetailPair('Runtime', _formatRuntime(detail.runtimeMinutes)),
      _DetailPair('Origin', _compactCountry(detail.country ?? '')),
      _DetailPair('Language', (detail.originalLanguage ?? '').toUpperCase()),
      _DetailPair('Status', detail.status ?? ''),
    ].where((_DetailPair row) => row.value.trim().isNotEmpty).toList();

    return Column(
      children: rows
          .map(
            (_DetailPair row) => _DetailRow(
              label: row.label,
              value: row.value,
              isLast: row == rows.last,
            ),
          )
          .toList(growable: false),
    );
  }
}

class _DetailPair {
  const _DetailPair(this.label, this.value);

  final String label;
  final String value;
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.isLast,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isLast ? Colors.transparent : Colors.white.withOpacity(0.08),
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTextBlock extends StatelessWidget {
  const _InfoTextBlock({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.showChevron = false});

  final String title;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 24,
            height: 1.0,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        if (showChevron) ...<Widget>[
          const SizedBox(width: 6),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textMuted,
            size: 24,
          ),
        ],
      ],
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withOpacity(0.34),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Icon(icon, color: AppColors.text, size: 24),
      ),
    );
  }
}

class _RoundMoreButton extends StatelessWidget {
  const _RoundMoreButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.12),
        ),
        child: const Icon(
          Icons.more_horiz_rounded,
          color: AppColors.text,
          size: 26,
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.text),
      title: Text(
        label,
        style: const TextStyle(
          color: AppColors.text,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _RelatedCard extends StatelessWidget {
  const _RelatedCard({
    required this.item,
    required this.onTap,
  });

  final MediaSummary item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 126,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 126,
              height: 188,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: AppColors.cardBackground,
              ),
              child: item.posterPath == null
                  ? const ColoredBox(color: AppColors.cardBackground)
                  : OptimizedNetworkImage(
                      url: getImageUrl(item.posterPath, 'w780'),
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      cacheWidth: 420,
                      errorBuilder: (
                        BuildContext context,
                        Object error,
                        StackTrace? stackTrace,
                      ) {
                        return const ColoredBox(
                            color: AppColors.cardBackground);
                      },
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CastCard extends StatelessWidget {
  const _CastCard({required this.member});

  final CastItem member;

  @override
  Widget build(BuildContext context) {
    final List<String> nameParts =
        member.name.split(' ').where((String part) => part.isNotEmpty).toList();
    final String initials = nameParts
        .take(2)
        .map((String part) => part.substring(0, 1).toUpperCase())
        .join();

    return SizedBox(
      width: 96,
      child: Column(
        children: <Widget>[
          Container(
            width: 86,
            height: 86,
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF191A1D),
            ),
            child: member.profilePath == null
                ? Center(
                    child: Text(
                      initials.isEmpty ? '?' : initials,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  )
                : OptimizedNetworkImage(
                    url: getImageUrl(member.profilePath, 'w185'),
                    fit: BoxFit.cover,
                    cacheWidth: 190,
                    errorBuilder: (
                      BuildContext context,
                      Object error,
                      StackTrace? stackTrace,
                    ) {
                      return const ColoredBox(color: Color(0xFF191A1D));
                    },
                  ),
          ),
          const SizedBox(height: 10),
          Text(
            member.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 13,
              height: 1.15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _year(String date) => date.isEmpty ? '' : date.split('-').first;

String _releaseDateFromInfo(String? value) {
  final RegExpMatch? match = RegExp(r'(19|20)\d{2}').firstMatch(value ?? '');
  return match == null ? '' : '${match.group(0)}-01-01';
}

int _runtimeMinutesFromAddon(String? value) {
  final String text = (value ?? '').toLowerCase();
  if (text.trim().isEmpty) {
    return 0;
  }
  final RegExpMatch? hourMinute =
      RegExp(r'(\d+)\s*h(?:ours?)?\s*(\d+)?\s*m?').firstMatch(text);
  if (hourMinute != null) {
    final int hours = int.tryParse(hourMinute.group(1) ?? '') ?? 0;
    final int minutes = int.tryParse(hourMinute.group(2) ?? '') ?? 0;
    return hours * 60 + minutes;
  }
  final RegExpMatch? minutesOnly = RegExp(r'(\d+)\s*m').firstMatch(text);
  if (minutesOnly != null) {
    return int.tryParse(minutesOnly.group(1) ?? '') ?? 0;
  }
  return int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
}

String _compactCountry(String value) {
  return value
      .replaceAll('United States of America', 'United States')
      .replaceAll('United Kingdom of Great Britain and Northern Ireland',
          'United Kingdom')
      .trim();
}

String _formatRuntime(int minutes) {
  if (minutes <= 0) {
    return '';
  }
  final int hours = minutes ~/ 60;
  final int mins = minutes % 60;
  if (hours <= 0) {
    return '${mins}m';
  }
  if (mins == 0) {
    return '${hours}h';
  }
  return '${hours}h ${mins}m';
}
