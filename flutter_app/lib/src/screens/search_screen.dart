import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/layout.dart';
import '../models/search_result.dart';
import '../models/torbox_models.dart';
import '../services/app_settings_repository.dart';
import '../services/tmdb_image.dart';
import '../services/tmdb_search_service.dart';
import '../theme/app_colors.dart';
import '../theme/layout_options.dart';
import '../widgets/optimized_network_image.dart';
import 'movie_detail_screen.dart';

enum SearchFilter { all, movie, tv }

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    this.searchService,
    this.settingsRepository,
  });

  final SearchService? searchService;
  final AppSettingsRepository? settingsRepository;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Timer? _debounce;
  List<SearchResult> _results = const <SearchResult>[];
  bool _loading = false;
  bool _hasSearched = false;
  SearchFilter _activeFilter = SearchFilter.all;
  int _searchVersion = 0;
  AppSettings _settings = const AppSettings();

  @override
  void initState() {
    super.initState();
    _searchService = widget.searchService ??
        TmdbSearchService(
          settingsRepository: widget.settingsRepository,
        );
    _loadSettings();
  }

  late final SearchService _searchService;

  Future<void> _loadSettings() async {
    final AppSettings settings =
        await (widget.settingsRepository ?? AppSettingsRepository())
            .loadSettings();
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    setState(() {});

    if (value.trim().isEmpty) {
      setState(() {
        _results = const <SearchResult>[];
        _loading = false;
        _hasSearched = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(value);
    });
  }

  Future<void> _performSearch(String query) async {
    final String trimmed = query.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final int requestVersion = ++_searchVersion;
    setState(() {
      _loading = true;
      _hasSearched = true;
    });

    try {
      final List<SearchResult> results =
          await _searchService.searchMulti(trimmed);

      if (!mounted || requestVersion != _searchVersion) {
        return;
      }

      setState(() {
        _results = results;
      });
    } catch (_) {
      if (!mounted || requestVersion != _searchVersion) {
        return;
      }

      setState(() {
        _results = const <SearchResult>[];
      });
    } finally {
      if (mounted && requestVersion == _searchVersion) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _clearQuery() {
    _debounce?.cancel();
    _controller.clear();
    setState(() {
      _results = const <SearchResult>[];
      _loading = false;
      _hasSearched = false;
    });
    _focusNode.requestFocus();
  }

  void _openDetail(SearchResult item) {
    FocusScope.of(context).unfocus();
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => MovieDetailScreen(
          id: item.id,
          mediaType: item.mediaType,
          fallbackTitle: item.displayTitle,
          fallbackPosterPath: item.posterPath,
          fallbackBackdropPath: item.backdropPath,
          fallbackOverview: item.overview,
          fallbackReleaseInfo:
              item.mediaType == 'tv' ? item.firstAirDate : item.releaseDate,
        ),
      ),
    );
  }

  List<SearchResult> get _filteredResults {
    switch (_activeFilter) {
      case SearchFilter.movie:
        return _results
            .where((SearchResult item) => item.mediaType == 'movie')
            .toList(growable: false);
      case SearchFilter.tv:
        return _results
            .where((SearchResult item) => item.mediaType == 'tv')
            .toList(growable: false);
      case SearchFilter.all:
        return _results;
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<SearchResult> filteredResults = _filteredResults;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
      ),
      child: Stack(
        children: <Widget>[
          const _SearchFlare(),
          SafeArea(
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: <Widget>[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppLayout.horizontalPadding,
                    20,
                    AppLayout.horizontalPadding,
                    24,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(
                      <Widget>[
                        Row(
                          children: <Widget>[
                            const Text(
                              'Search',
                              style: TextStyle(
                                fontSize: 38,
                                height: 1,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.2,
                                color: AppColors.text,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              width: 48,
                              height: 48,
                              decoration: const BoxDecoration(
                                color: Color(0xFF9CA3AF),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                color: Color(0xFF30343B),
                                size: 28,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _SearchInput(
                          controller: _controller,
                          focusNode: _focusNode,
                          onChanged: _onQueryChanged,
                          onClear: _clearQuery,
                        ),
                        if (_hasSearched) ...<Widget>[
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: <Widget>[
                              _FilterChip(
                                label: 'All',
                                icon: Icons.tune,
                                selected: _activeFilter == SearchFilter.all,
                                onTap: () {
                                  setState(() {
                                    _activeFilter = SearchFilter.all;
                                  });
                                },
                              ),
                              _FilterChip(
                                label: 'Movies',
                                icon: Icons.local_movies,
                                selected: _activeFilter == SearchFilter.movie,
                                onTap: () {
                                  setState(() {
                                    _activeFilter = SearchFilter.movie;
                                  });
                                },
                              ),
                              _FilterChip(
                                label: 'TV Series',
                                icon: Icons.live_tv,
                                selected: _activeFilter == SearchFilter.tv,
                                onTap: () {
                                  setState(() {
                                    _activeFilter = SearchFilter.tv;
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                        if (_hasSearched &&
                            !_loading &&
                            filteredResults.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 16),
                          Text(
                            '${filteredResults.length} result${filteredResults.length == 1 ? '' : 's'} found',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSubtle,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        if (_loading)
                          const _LoadingState()
                        else if (!_hasSearched)
                          const _IdleSearchState()
                        else if (filteredResults.isEmpty)
                          const _NoResultsState()
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredResults.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 22,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.58,
                            ),
                            itemBuilder: (BuildContext context, int index) {
                              final SearchResult item = filteredResults[index];
                              return _SearchResultCard(
                                item: item,
                                settings: _settings,
                                onTap: () => _openDetail(item),
                              );
                            },
                          ),
                        const SizedBox(height: 120),
                      ],
                    ),
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

class _SearchFlare extends StatelessWidget {
  const _SearchFlare();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          height: 260,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.75),
              radius: 1.1,
              colors: <Color>[
                Color(0x246366F1),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchInput extends StatelessWidget {
  const _SearchInput({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.search,
            color: AppColors.textSubtle,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 16,
              ),
              cursorColor: AppColors.primary,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Search movies, TV series...',
                hintStyle: TextStyle(color: Color(0xFF666666)),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: onClear,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.close,
                  color: AppColors.textSubtle,
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.text : Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 14,
                color: selected ? AppColors.background : AppColors.textSubtle,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.background : AppColors.textSubtle,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 300,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          CircularProgressIndicator(color: AppColors.text),
          SizedBox(height: 12),
          Text(
            'Searching...',
            style: TextStyle(
              color: AppColors.textSubtle,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _IdleSearchState extends StatelessWidget {
  const _IdleSearchState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 80),
      child: Column(
        children: <Widget>[
          _RoundIcon(icon: Icons.search, color: Color(0xFF444444)),
          SizedBox(height: 24),
          Text(
            'Search Movies & TV Shows',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Find your favorite movies and series.\nBoth will appear if they share the same name.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.57,
              color: Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 80),
      child: Column(
        children: <Widget>[
          Text(
            'No results found',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Try a different search term or adjust your filters.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Icon(icon, color: color, size: 48),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.item,
    required this.settings,
    required this.onTap,
  });

  final SearchResult item;
  final AppSettings settings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isMovie = item.mediaType == 'movie';

    final String year = ((isMovie ? item.releaseDate : item.firstAirDate) ?? '')
        .split('-')
        .first;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          LayoutOptions.posterRadius(settings),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  LayoutOptions.posterRadius(settings),
                ),
                child: OptimizedNetworkImage(
                  url: getImageUrl(item.posterPath, 'w342'),
                  fit: BoxFit.cover,
                  cacheWidth: 360,
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
                          size: 30,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (!settings.posterHideLabels) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                item.displayTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                  height: 1.08,
                ),
              ),
              if (year.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  year,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
