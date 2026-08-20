import 'package:flutter/material.dart';

import '../constants/layout.dart';
import '../models/playlist_movie.dart';
import '../services/tmdb_image.dart';
import '../services/tmdb_playlist_service.dart';
import '../theme/app_colors.dart';
import '../widgets/optimized_network_image.dart';
import 'movie_detail_screen.dart';

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({
    super.key,
    this.playlistService,
  });

  final PlaylistService? playlistService;

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  static const List<_ProviderOption> _providers = <_ProviderOption>[
    _ProviderOption(
      id: '8',
      name: 'Netflix',
      providerId: 8,
      color: Color(0xFFE50914),
      assetPath: 'assets/ott/netflix.png',
    ),
    _ProviderOption(
      id: '9',
      name: 'Prime',
      providerId: 9,
      color: Color(0xFF00A8E1),
      assetPath: 'assets/ott/prime.png',
    ),
    _ProviderOption(
      id: '1899',
      name: 'HBO',
      providerId: 1899,
      color: Color(0xFF991EEB),
      assetPath: 'assets/ott/hbo.png',
    ),
    _ProviderOption(
      id: '337',
      name: 'Disney+',
      providerId: 337,
      color: Color(0xFF113CCF),
      assetPath: 'assets/ott/disney.png',
    ),
    _ProviderOption(
      id: '350',
      name: 'Apple TV+',
      providerId: 350,
      color: Color(0xFF555555),
      assetPath: 'assets/ott/apple.png',
    ),
    _ProviderOption(
      id: '15',
      name: 'Hulu',
      providerId: 15,
      color: Color(0xFF1CE783),
      assetPath: 'assets/ott/hulu.png',
    ),
  ];

  late final PageController _pageController;
  late final PlaylistService _playlistService;
  _ProviderOption _activeProvider = _providers.first;
  List<PlaylistMovie> _movies = const <PlaylistMovie>[];
  final Map<int, List<PlaylistMovie>> _providerCache =
      <int, List<PlaylistMovie>>{};
  bool _loading = true;
  int _currentIndex = 0;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    _playlistService = widget.playlistService ?? TmdbPlaylistService();
    _pageController = PageController(viewportFraction: 0.78);
    _loadMoviesForProvider(_activeProvider);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadMoviesForProvider(_ProviderOption provider) async {
    final int requestVersion = ++_requestVersion;

    setState(() {
      _activeProvider = provider;
      _loading = true;
      _currentIndex = 0;
      _movies = _providerCache[provider.providerId] ?? _movies;
    });

    try {
      final List<PlaylistMovie> movies =
          await _playlistService.getMoviesByProvider(provider.providerId);

      if (!mounted || requestVersion != _requestVersion) {
        return;
      }

      setState(() {
        _movies = movies;
        if (movies.isNotEmpty) {
          _providerCache[provider.providerId] = movies;
        }
      });
    } catch (_) {
      if (!mounted || requestVersion != _requestVersion) {
        return;
      }

      final List<PlaylistMovie>? cached = _providerCache[provider.providerId];
      setState(() {
        _movies = cached ?? const <PlaylistMovie>[];
      });
    } finally {
      if (mounted && requestVersion == _requestVersion) {
        setState(() {
          _loading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pageController.hasClients) {
            _pageController.jumpToPage(0);
          }
        });
      }
    }
  }

  void _openMovie(PlaylistMovie movie) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => MovieDetailScreen(
          id: movie.id,
          mediaType: 'movie',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int safeIndex =
        _movies.isEmpty ? 0 : _currentIndex.clamp(0, _movies.length - 1);
    final PlaylistMovie? backgroundMovie =
        _movies.isEmpty ? null : _movies[safeIndex];

    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.background),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _PlaylistBackdrop(movie: backgroundMovie),
          SafeArea(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppLayout.horizontalPadding,
                        ),
                        child: Text(
                          'Playlist',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.horizontalPadding,
                        ),
                        child: Row(
                          children: _providers
                              .map(
                                (_ProviderOption provider) => Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: _ProviderChip(
                                    provider: provider,
                                    selected:
                                        provider.name == _activeProvider.name,
                                    onTap: () =>
                                        _loadMoviesForProvider(provider),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                      if (_loading) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.text,
                          ),
                        );
                      }

                      if (_movies.isEmpty) {
                        return const _PlaylistEmptyState();
                      }

                      final bool showDots = _movies.length > 1;
                      const double topSpacing = 12;
                      const double gapBelowCard = 18;
                      const double dotsBlockHeight = 16;
                      const double bottomSpacing = 28;
                      final double reservedHeight = topSpacing +
                          gapBelowCard +
                          (showDots ? dotsBlockHeight : 0) +
                          bottomSpacing;
                      final double pageHeight =
                          (constraints.maxHeight - reservedHeight)
                              .clamp(220.0, 430.0);

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const SizedBox(height: topSpacing),
                          SizedBox(
                            height: pageHeight,
                            child: PageView.builder(
                              controller: _pageController,
                              onPageChanged: (int index) {
                                setState(() {
                                  _currentIndex = index;
                                });
                              },
                              itemCount: _movies.length,
                              itemBuilder: (BuildContext context, int index) {
                                final PlaylistMovie movie = _movies[index];
                                final bool isActive = index == _currentIndex;

                                return AnimatedPadding(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOut,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: isActive ? 8 : 28,
                                  ),
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 220),
                                    opacity: isActive ? 1 : 0.56,
                                    child: AnimatedScale(
                                      duration:
                                          const Duration(milliseconds: 220),
                                      scale: isActive ? 1 : 0.92,
                                      curve: Curves.easeOut,
                                      child: _PlaylistCard(
                                        movie: movie,
                                        onTap: () => _openMovie(movie),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (showDots)
                            _PageDots(
                              count: _movies.length,
                              activeIndex: _currentIndex,
                            ),
                          const SizedBox(height: bottomSpacing),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderOption {
  const _ProviderOption({
    required this.id,
    required this.name,
    required this.providerId,
    required this.color,
    required this.assetPath,
  });

  final String id;
  final String name;
  final int providerId;
  final Color color;
  final String assetPath;
}

class _ProviderChip extends StatelessWidget {
  const _ProviderChip({
    required this.provider,
    required this.selected,
    required this.onTap,
  });

  final _ProviderOption provider;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xF23C3C3C) : const Color(0xD9282828),
      borderRadius: BorderRadius.circular(23),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(23),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(23),
            border: Border.all(
              color: selected ? provider.color : Colors.white.withOpacity(0.08),
              width: 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white.withOpacity(0.05),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  provider.assetPath,
                  fit: BoxFit.contain,
                  errorBuilder: (BuildContext context, Object error,
                      StackTrace? stackTrace) {
                    return Container(
                      color: provider.color,
                      alignment: Alignment.center,
                      child: Text(
                        provider.name[0],
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Text(
                provider.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.text : AppColors.textSubtle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistBackdrop extends StatelessWidget {
  const _PlaylistBackdrop({required this.movie});

  final PlaylistMovie? movie;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (movie != null)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: OptimizedNetworkImage(
              key: ValueKey<int>(movie!.id),
              url: getImageUrl(movie!.posterPath, 'w780'),
              fit: BoxFit.cover,
              errorBuilder: (
                BuildContext context,
                Object error,
                StackTrace? stackTrace,
              ) {
                return const ColoredBox(color: AppColors.background);
              },
            ),
          )
        else
          const ColoredBox(color: AppColors.background),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Colors.black.withOpacity(0.7),
                Colors.black.withOpacity(0.5),
                Colors.black.withOpacity(0.95),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({
    required this.movie,
    required this.onTap,
  });

  final PlaylistMovie movie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: 280 / 380,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compact = constraints.maxWidth < 170;
            final double horizontalInset = compact ? 14 : 20;
            final double bottomInset = compact ? 16 : 24;
            final double titleSize = compact ? 18 : 22;
            final double dateSize = compact ? 11 : 13;

            return Material(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    OptimizedNetworkImage(
                      url: getImageUrl(movie.posterPath, 'w500'),
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
                              size: 42,
                            ),
                          ),
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
                            Colors.black.withOpacity(0.9),
                          ],
                          stops: const <double>[0.45, 1],
                        ),
                      ),
                    ),
                    Positioned(
                      left: horizontalInset,
                      right: horizontalInset,
                      bottom: bottomInset,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            movie.title.toUpperCase(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: titleSize,
                              fontWeight: FontWeight.w700,
                              letterSpacing: compact ? 1.0 : 1.5,
                              height: 1.1,
                            ),
                          ),
                          SizedBox(height: compact ? 4 : 6),
                          Text(
                            _formatReleaseDate(movie.releaseDate),
                            style: TextStyle(
                              color: const Color(0xB3FFFFFF),
                              fontSize: dateSize,
                              fontWeight: FontWeight.w600,
                              letterSpacing: compact ? 0.7 : 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.count,
    required this.activeIndex,
  });

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    if (count <= 1) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(
        count,
        (int index) => AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: index == activeIndex ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: index == activeIndex
                ? AppColors.text
                : Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _PlaylistEmptyState extends StatelessWidget {
  const _PlaylistEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.movie_filter_outlined,
            color: AppColors.textMuted,
            size: 56,
          ),
          SizedBox(height: 18),
          Text(
            'No playlist titles found',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Try another provider and we will pull a fresh movie set for that service.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatReleaseDate(String date) {
  if (date.isEmpty) {
    return '';
  }

  final List<String> parts = date.split('-');
  if (parts.length < 3) {
    return date.toUpperCase();
  }

  const List<String> months = <String>[
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];

  final int? monthIndex = int.tryParse(parts[1]);
  final int? day = int.tryParse(parts[2]);

  if (monthIndex == null || day == null || monthIndex < 1 || monthIndex > 12) {
    return date.toUpperCase();
  }

  return '${months[monthIndex - 1]} $day';
}
