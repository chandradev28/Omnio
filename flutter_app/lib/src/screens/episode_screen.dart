import 'package:flutter/material.dart';

import '../models/tmdb_media_models.dart';
import '../services/tmdb_image.dart';
import '../services/tmdb_media_service.dart';
import '../theme/app_colors.dart';
import '../widgets/optimized_network_image.dart';
import 'streamed_sources_screen.dart';

class EpisodeScreen extends StatefulWidget {
  EpisodeScreen({
    super.key,
    required this.tvId,
    required this.initialSeason,
    required this.showName,
    this.posterPath,
    MediaCatalogService? mediaService,
  }) : mediaService = mediaService ?? TmdbMediaService();

  final int tvId;
  final int initialSeason;
  final String showName;
  final String? posterPath;
  final MediaCatalogService mediaService;

  @override
  State<EpisodeScreen> createState() => _EpisodeScreenState();
}

class _EpisodeScreenState extends State<EpisodeScreen> {
  MediaDetail? _showDetail;
  List<EpisodeItem> _episodes = const <EpisodeItem>[];
  late int _selectedSeason;
  bool _loadingShow = true;
  bool _loadingEpisodes = true;
  bool _seasonMenuOpen = false;

  @override
  void initState() {
    super.initState();
    _selectedSeason = widget.initialSeason;
    _loadShowAndSeason();
  }

  Future<void> _loadShowAndSeason() async {
    setState(() {
      _loadingShow = true;
    });

    try {
      final MediaDetail detail =
          await widget.mediaService.getMediaDetail(widget.tvId, 'tv');
      if (!mounted) {
        return;
      }

      setState(() {
        _showDetail = detail;
        _loadingShow = false;
      });

      await _loadSeason(_selectedSeason);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingShow = false;
      });
    }
  }

  Future<void> _loadSeason(int seasonNumber) async {
    setState(() {
      _selectedSeason = seasonNumber;
      _loadingEpisodes = true;
      _seasonMenuOpen = false;
    });

    try {
      final List<EpisodeItem> items = await widget.mediaService
          .getSeasonEpisodes(widget.tvId, seasonNumber);
      if (!mounted) {
        return;
      }

      setState(() {
        _episodes = items;
        _loadingEpisodes = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _episodes = const <EpisodeItem>[];
        _loadingEpisodes = false;
      });
    }
  }

  void _openPlaybackTools(EpisodeItem episode) {
    final MediaDetail? show = _showDetail;
    if (show == null || (show.imdbId ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'IMDb ID is missing for ${episode.name}, so Torboxers cannot search it yet.',
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => OmnioSourcesScreen(
          title: widget.showName,
          logoPath: show.logoPath,
          posterPath: widget.posterPath ?? show.posterPath,
          mediaType: 'tv',
          imdbId: show.imdbId!,
          tmdbId: show.id,
          seasonNumber: episode.seasonNumber,
          episodeNumber: episode.episodeNumber,
          episodeName: episode.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingShow) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.text),
        ),
      );
    }

    final MediaDetail? show = _showDetail;
    if (show == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(),
        body: const Center(
          child: Text(
            'Could not load show details.',
            style: TextStyle(color: AppColors.text),
          ),
        ),
      );
    }

    final List<SeasonSummary> seasons = show.seasons
        .where((SeasonSummary season) => season.seasonNumber > 0)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFF1A1A1A),
              Color(0xFF0A0A0A),
              Color(0xFF000000),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.1),
                    ),
                    icon: const Icon(Icons.close, color: AppColors.text),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 120,
                          height: 170,
                          child: (widget.posterPath ?? show.posterPath) == null
                              ? const ColoredBox(
                                  color: AppColors.cardBackground,
                                  child: Center(
                                    child: Icon(
                                      Icons.movie_creation_outlined,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                )
                              : OptimizedNetworkImage(
                                  url: getImageUrl(
                                      widget.posterPath ?? show.posterPath,
                                      'w342'),
                                  fit: BoxFit.cover,
                                  errorBuilder: (
                                    BuildContext context,
                                    Object error,
                                    StackTrace? stackTrace,
                                  ) {
                                    return const ColoredBox(
                                      color: AppColors.cardBackground,
                                      child: Center(
                                        child: Icon(
                                          Icons.movie_creation_outlined,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              if (show.networks.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    show.networks.first.name,
                                    style: const TextStyle(
                                      color: AppColors.text,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              Text(
                                widget.showName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _year(show.releaseDate),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSubtle,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: <Widget>[
                                  _Badge(label: 'TV-MA'),
                                  _Badge(label: 'HD'),
                                  _Badge(label: '4K'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: <Widget>[
                      InkWell(
                        onTap: seasons.isEmpty
                            ? null
                            : () {
                                setState(() {
                                  _seasonMenuOpen = !_seasonMenuOpen;
                                });
                              },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              Text(
                                'Season $_selectedSeason',
                                style: const TextStyle(
                                  color: AppColors.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.keyboard_arrow_down,
                                color: AppColors.text,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_seasonMenuOpen)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xF21E1E1E),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Column(
                            children: seasons
                                .map(
                                  (SeasonSummary season) => InkWell(
                                    onTap: () =>
                                        _loadSeason(season.seasonNumber),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _selectedSeason ==
                                                season.seasonNumber
                                            ? Colors.white.withOpacity(0.08)
                                            : Colors.transparent,
                                        border: Border(
                                          bottom: BorderSide(
                                            color:
                                                Colors.white.withOpacity(0.05),
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: <Widget>[
                                          Expanded(
                                            child: Text(
                                              season.name,
                                              style: TextStyle(
                                                color: AppColors.text,
                                                fontSize: 15,
                                                fontWeight: _selectedSeason ==
                                                        season.seasonNumber
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '${season.episodeCount} episodes',
                                            style: const TextStyle(
                                              color: AppColors.textSubtle,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_loadingEpisodes)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.text),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      children: _episodes
                          .map(
                            (EpisodeItem episode) => _EpisodeRow(
                              episode: episode,
                              onTap: () => _openPlaybackTools(episode),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({
    required this.episode,
    required this.onTap,
  });

  final EpisodeItem episode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
          ),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Episode ${episode.episodeNumber}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSubtle,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    episode.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Text(
              _runtime(episode.runtime),
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _runtime(int minutes) => minutes <= 0 ? '' : '$minutes min';

String _year(String date) => date.isEmpty ? '' : date.split('-').first;
