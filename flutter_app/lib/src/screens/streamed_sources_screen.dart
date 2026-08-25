import 'package:flutter/material.dart';

import '../models/torbox_models.dart';
import '../services/app_settings_repository.dart';
import '../services/episode_parser.dart';
import '../services/real_debrid_api_service.dart';
import '../services/stream_badge_service.dart';
import '../services/stream_catalog_service.dart';
import '../services/stremio_addons_service.dart';
import '../services/tmdb_image.dart';
import '../services/torbox_api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/optimized_network_image.dart';
import '../widgets/title_logo.dart';
import 'video_player_screen.dart';

class OmnioSourcesScreen extends StatefulWidget {
  OmnioSourcesScreen({
    super.key,
    required this.title,
    this.logoPath,
    this.posterPath,
    required this.mediaType,
    required this.imdbId,
    this.tmdbId,
    this.seasonNumber,
    this.episodeNumber,
    this.episodeName,
    StreamCatalogService? streamCatalogService,
    StremioAddonsService? addonsService,
    TorBoxApiService? torBoxApiService,
    RealDebridApiService? realDebridApiService,
    AppSettingsRepository? settingsRepository,
    StreamBadgeService? streamBadgeService,
  })  : streamCatalogService = streamCatalogService ?? StreamCatalogService(),
        addonsService = addonsService ?? StremioAddonsService(),
        torBoxApiService = torBoxApiService ?? TorBoxApiService(),
        realDebridApiService = realDebridApiService ?? RealDebridApiService(),
        settingsRepository = settingsRepository ?? AppSettingsRepository(),
        streamBadgeService = streamBadgeService ?? const StreamBadgeService();

  final String title;
  final String? logoPath;
  final String? posterPath;
  final String mediaType;
  final String imdbId;
  final int? tmdbId;
  final int? seasonNumber;
  final int? episodeNumber;
  final String? episodeName;
  final StreamCatalogService streamCatalogService;
  final StremioAddonsService addonsService;
  final TorBoxApiService torBoxApiService;
  final RealDebridApiService realDebridApiService;
  final AppSettingsRepository settingsRepository;
  final StreamBadgeService streamBadgeService;

  @override
  State<OmnioSourcesScreen> createState() => _OmnioSourcesScreenState();
}

class _OmnioSourcesScreenState extends State<OmnioSourcesScreen> {
  final ScrollController _scrollController = ScrollController();

  AppSettings _settings = const AppSettings();
  List<StreamSource> _results = const <StreamSource>[];
  bool _loading = true;
  String? _message;
  String? _selectedSource;
  bool _cachedOnly = false;
  bool _showPinnedTitle = false;
  List<StreamBadge> _badges = const <StreamBadge>[];

  bool get _isEpisodeContext =>
      widget.mediaType == 'tv' &&
      widget.seasonNumber != null &&
      widget.episodeNumber != null;

  List<String> get _availableSources {
    final List<String> values = _results
        .map((StreamSource source) => source.sourceDisplayName)
        .toSet()
        .toList(growable: false)
      ..sort();
    return values;
  }

  List<StreamSource> get _visibleResults {
    return _results
        .where(
          (StreamSource source) =>
              (_selectedSource == null ||
                  source.sourceDisplayName == _selectedSource) &&
              (!_cachedOnly || source.isCached),
        )
        .toList(growable: false);
  }

  Map<String, List<StreamSource>> _groupVisibleResults(
    List<StreamSource> results,
  ) {
    final Map<String, List<StreamSource>> grouped =
        <String, List<StreamSource>>{};
    for (final StreamSource source in results) {
      grouped
          .putIfAbsent(source.sourceDisplayName, () => <StreamSource>[])
          .add(source);
    }
    final List<String> names = grouped.keys.toList(growable: false)..sort();
    return <String, List<StreamSource>>{
      for (final String name in names) name: grouped[name]!,
    };
  }

  List<_SourceListEntry> _buildSourceEntries(
    Map<String, List<StreamSource>> groupedSources,
  ) {
    final List<_SourceListEntry> entries = <_SourceListEntry>[];
    for (final MapEntry<String, List<StreamSource>> group
        in groupedSources.entries) {
      entries.add(_SourceHeaderEntry(group.key));
      if (!_isEpisodeContext) {
        for (final StreamSource source in group.value) {
          entries.add(_SourceCardEntry(source));
        }
      } else {
        final List<StreamSource> episodeSources = group.value
            .where((StreamSource source) => !_isSeasonPackSource(source))
            .toList(growable: false);
        final List<StreamSource> seasonPacks = group.value
            .where((StreamSource source) => _isSeasonPackSource(source))
            .toList(growable: false);

        if (episodeSources.isNotEmpty) {
          entries.add(const _SourceSmallHeaderEntry('Episode Sources'));
          for (final StreamSource source in episodeSources) {
            entries.add(_SourceCardEntry(source));
          }
        }
        if (seasonPacks.isNotEmpty) {
          entries.add(const _SourceSpacerEntry(4));
          entries.add(const _SourceSmallHeaderEntry('Season Packs'));
          for (final StreamSource source in seasonPacks) {
            entries.add(_SourceCardEntry(source));
          }
        }
      }
      entries.add(const _SourceSpacerEntry(14));
    }
    return entries;
  }

  Widget _buildSourceEntry(_SourceListEntry entry) {
    if (entry is _SourceHeaderEntry) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _SectionHeader(title: entry.title),
      );
    }
    if (entry is _SourceSmallHeaderEntry) {
      return _SmallGroupLabel(entry.title);
    }
    if (entry is _SourceSpacerEntry) {
      return SizedBox(height: entry.height);
    }
    final StreamSource source = (entry as _SourceCardEntry).source;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RepaintBoundary(
        child: _OmnioSourceCard(
          source: source,
          badges: _badgesForCard(widget.streamBadgeService, _badges, source),
          onPlay: () => _playSource(source),
          onAddToTorBox: () => _addToTorBox(source),
        ),
      ),
    );
  }

  bool _isSeasonPackSource(StreamSource source) {
    final String text = <String>[
      source.title,
      source.description,
      if (source.fileName != null) source.fileName!,
    ].join('\n');
    return isSeasonPackTitle(text);
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _bootstrap();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final bool shouldShow =
        _scrollController.hasClients && _scrollController.offset > 24;
    if (shouldShow == _showPinnedTitle) {
      return;
    }
    setState(() {
      _showPinnedTitle = shouldShow;
    });
  }

  Future<void> _bootstrap() async {
    final AppSettings settings = await widget.settingsRepository.loadSettings();
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
      _badges = settings.streamBadgesEnabled
          ? widget.streamBadgeService.parseBadges(settings.streamBadgesJson)
          : const <StreamBadge>[];
    });
    await _search();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _message = null;
    });

    final List<StreamSource> merged = <StreamSource>[];
    final Set<String> seen = <String>{};

    try {
      final List<AddonManifest> addons =
          await widget.addonsService.getInstalledAddons();

      final bool hasEnabledStreamAddon = addons.any(
        (AddonManifest addon) => addon.enabled && addon.hasStreamResource,
      );
      if (!hasEnabledStreamAddon) {
        _message = 'Install and enable a stream addon to search Omnio.';
      }

      if (hasEnabledStreamAddon) {
        final String streamId = widget.mediaType == 'tv'
            ? '${widget.imdbId}:${widget.seasonNumber ?? 1}:${widget.episodeNumber ?? 1}'
            : widget.imdbId;
        final AddonSearchResult addonSearch =
            await widget.addonsService.searchStreamsDetailed(
          mediaType: widget.mediaType,
          streamId: streamId,
        );
        final List<StreamSource> addonStreams =
            await widget.streamCatalogService.annotateCacheStatus(
          addonSearch.streams,
        );
        for (final StreamSource item in addonStreams) {
          if (seen.add(item.id)) {
            merged.add(item);
          }
        }
      }

      if (merged.isEmpty) {
        _message ??= 'No addon streams found for this title.';
      }

      merged.sort((StreamSource a, StreamSource b) {
        if (a.isCached == b.isCached) {
          return a.sourceDisplayName.compareTo(b.sourceDisplayName);
        }
        return a.isCached ? -1 : 1;
      });
    } catch (error) {
      _message = error.toString();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _results = merged;
      _badges = _settings.streamBadgesEnabled
          ? widget.streamBadgeService.parseBadges(_settings.streamBadgesJson)
          : const <StreamBadge>[];
      _selectedSource = null;
      _cachedOnly = false;
      _loading = false;
      _message = merged.isEmpty
          ? (_message ?? 'No sources came back for this title.')
          : _message;
    });
  }

  Future<void> _playSource(StreamSource source) async {
    if (source.hasTorrentSource && _settings.resolvePlayableLinksEnabled) {
      final bool played = await _playResolvedTorrentSource(source);
      if (played) {
        return;
      }
    }

    if (source.isDirectUrl) {
      _openDirectUrl(source);
      return;
    }

    if (!source.hasTorrentSource) {
      return;
    }

    if (!_settings.resolvePlayableLinksEnabled) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enable Connected Services > Resolve playable links to play torrent sources.',
          ),
        ),
      );
      return;
    }

    final bool played = await _playResolvedTorrentSource(source);
    if (!mounted || played) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not prepare this source in a connected service.'),
      ),
    );
  }

  void _openDirectUrl(StreamSource source) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => VideoPlayerScreen(
          title: widget.episodeName ?? widget.title,
          posterUrl: widget.posterPath,
          tmdbId: widget.tmdbId,
          imdbId: widget.imdbId,
          mediaType: widget.mediaType,
          seasonNumber: widget.seasonNumber,
          episodeNumber: widget.episodeNumber,
          episodeName: widget.episodeName,
          initialVideoUrl: source.directUrl,
          provider: source.sourceDisplayName,
          streamHeaders: source.streamHeaders,
        ),
      ),
    );
  }

  Future<bool> _playResolvedTorrentSource(StreamSource source) async {
    final String preferred = _preferredProviderFor(source);
    if (preferred == 'realdebrid') {
      final bool played = await _playViaRealDebrid(source);
      if (played) {
        return true;
      }
    }

    final TorBoxTorrent? torrent = await widget.torBoxApiService.addTorrent(
      source.magnetUri ?? source.infoHash!,
    );
    if (torrent == null) {
      if (source.isRealDebridCached) {
        final bool played = await _playViaRealDebrid(source);
        if (played) {
          return true;
        }
      }
      return false;
    }

    if (!mounted) {
      return true;
    }

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => VideoPlayerScreen(
          title: widget.episodeName ?? widget.title,
          posterUrl: widget.posterPath,
          tmdbId: widget.tmdbId,
          imdbId: widget.imdbId,
          mediaType: widget.mediaType,
          seasonNumber: widget.seasonNumber,
          episodeNumber: widget.episodeNumber,
          episodeName: widget.episodeName,
          torrentHash: torrent.hash,
          torrentId: torrent.id,
          initialFiles: torrent.files,
          initialFileId: _preferredInitialFileId(torrent.files, source),
          initialFileIndex: source.fileIndex,
          initialFileName: source.fileName,
          provider: source.sourceDisplayName,
        ),
      ),
    );
    return true;
  }

  String _preferredProviderFor(StreamSource source) {
    final String preferred = _settings.preferredDebridProvider;
    if (preferred == 'realdebrid' && source.isRealDebridCached) {
      return 'realdebrid';
    }
    if (preferred == 'torbox' && source.isTorBoxCached) {
      return 'torbox';
    }
    if (source.isTorBoxCached) {
      return 'torbox';
    }
    if (source.isRealDebridCached) {
      return 'realdebrid';
    }
    return preferred;
  }

  Future<bool> _playViaRealDebrid(StreamSource source) async {
    try {
      final RealDebridResolvedLink? link =
          await widget.realDebridApiService.resolveSource(
        source: source,
        seasonNumber: widget.seasonNumber,
        episodeNumber: widget.episodeNumber,
      );
      if (!mounted || link == null || link.url.isEmpty) {
        return false;
      }
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => VideoPlayerScreen(
            title: link.filename ?? widget.episodeName ?? widget.title,
            posterUrl: widget.posterPath,
            tmdbId: widget.tmdbId,
            imdbId: widget.imdbId,
            mediaType: widget.mediaType,
            seasonNumber: widget.seasonNumber,
            episodeNumber: widget.episodeNumber,
            episodeName: widget.episodeName,
            initialVideoUrl: link.url,
            provider: 'Real-Debrid',
          ),
        ),
      );
      return true;
    } on RealDebridApiException catch (error) {
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.detail)),
      );
      return false;
    }
  }

  Future<void> _addToTorBox(StreamSource source) async {
    if (source.infoHash == null || source.infoHash!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This source does not expose a torrent hash.'),
        ),
      );
      return;
    }

    final TorBoxTorrent? torrent = await widget.torBoxApiService.addTorrent(
      source.magnetUri ?? source.infoHash!,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          torrent == null
              ? 'Could not add that source to TorBox.'
              : 'Added "${torrent.name}" to TorBox.',
        ),
      ),
    );
  }

  int? _preferredInitialFileId(
    List<TorBoxTorrentFile> files,
    StreamSource source,
  ) {
    if (files.isEmpty) {
      return null;
    }

    final int? fileIndex = source.fileIndex;
    if (fileIndex != null && fileIndex >= 0 && fileIndex < files.length) {
      return files[fileIndex].id;
    }

    final String? fileName = source.fileName;
    if (fileName != null && fileName.trim().isNotEmpty) {
      final String normalizedTarget = _normalizeFileName(fileName);
      for (final TorBoxTorrentFile file in files) {
        if (_normalizeFileName(file.name) == normalizedTarget ||
            _normalizeFileName(file.displayName) == normalizedTarget) {
          return file.id;
        }
      }
    }

    final List<int> videoIndices = getAllVideoFiles(files);
    if (videoIndices.isNotEmpty) {
      return files[videoIndices.first].id;
    }
    return files.first.id;
  }

  String _normalizeFileName(String value) {
    return value.split(RegExp(r'[/\\]')).last.trim().toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final int cachedCount =
        _results.where((StreamSource source) => source.isCached).length;
    final List<String> sourceTabs = _availableSources;
    final List<StreamSource> visibleResults = _visibleResults;
    final Map<String, List<StreamSource>> visibleGroups =
        _groupVisibleResults(visibleResults);
    final List<_SourceListEntry> sourceEntries =
        _buildSourceEntries(visibleGroups);

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: _SourcesBackdrop(posterPath: widget.posterPath),
          ),
          RefreshIndicator(
            onRefresh: _search,
            color: AppColors.text,
            backgroundColor: AppColors.cardBackground,
            child: CustomScrollView(
              controller: _scrollController,
              cacheExtent: 900,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: _SourcesHero(
                    title: widget.title,
                    logoPath: widget.logoPath,
                    subtitle: _isEpisodeContext
                        ? 'S${widget.seasonNumber}E${widget.episodeNumber}'
                        : widget.mediaType == 'tv'
                            ? 'Show sources'
                            : 'Movie sources',
                    loading: _loading,
                    cachedOnly: _cachedOnly,
                    cachedCount: cachedCount,
                    totalCount: _results.length,
                    onRefresh: _loading ? null : _search,
                    onToggleCached: () {
                      setState(() {
                        _cachedOnly = !_cachedOnly;
                      });
                    },
                  ),
                ),
                if (sourceTabs.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _SourceTabsStrip(
                      selectedSource: _selectedSource,
                      sourceNames: sourceTabs,
                      onSelected: (String? sourceName) {
                        setState(() {
                          _selectedSource = sourceName;
                        });
                      },
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 34),
                  sliver: _loading
                      ? const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 56),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AppColors.text,
                              ),
                            ),
                          ),
                        )
                      : _results.isEmpty
                          ? SliverToBoxAdapter(
                              child: _EmptyState(message: _message),
                            )
                          : visibleResults.isEmpty
                              ? SliverToBoxAdapter(
                                  child: _EmptyState(
                                    message: _cachedOnly
                                        ? 'No cached streams match the current filter.'
                                        : _message,
                                  ),
                                )
                              : SliverList.builder(
                                  itemCount: sourceEntries.length,
                                  itemBuilder:
                                      (BuildContext context, int index) {
                                    return _buildSourceEntry(
                                      sourceEntries[index],
                                    );
                                  },
                                ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: _SourcesPinnedToolbar(
              title: widget.title,
              logoPath: widget.logoPath,
              showTitle: _showPinnedTitle,
              onBack: () => Navigator.of(context).maybePop(),
              onRefresh: _loading ? null : _search,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourcesBackdrop extends StatelessWidget {
  const _SourcesBackdrop({this.posterPath});

  final String? posterPath;

  @override
  Widget build(BuildContext context) {
    final String? path = posterPath;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (path == null || path.isEmpty)
          const ColoredBox(color: Color(0xFF050505))
        else
          OptimizedNetworkImage(
            url: _sourceImageUrl(path, 'w1280'),
            fit: BoxFit.cover,
            cacheWidth: 1080,
            errorBuilder: (
              BuildContext context,
              Object error,
              StackTrace? stackTrace,
            ) {
              return const ColoredBox(color: Color(0xFF050505));
            },
          ),
        ColoredBox(color: Colors.black.withOpacity(0.34)),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Colors.black.withOpacity(0.20),
                Colors.black.withOpacity(0.72),
                const Color(0xFF050505),
              ],
              stops: const <double>[0, 0.34, 1],
            ),
          ),
        ),
      ],
    );
  }
}

class _SourcesHero extends StatelessWidget {
  const _SourcesHero({
    required this.title,
    this.logoPath,
    required this.subtitle,
    required this.loading,
    required this.cachedOnly,
    required this.cachedCount,
    required this.totalCount,
    required this.onRefresh,
    required this.onToggleCached,
  });

  final String title;
  final String? logoPath;
  final String subtitle;
  final bool loading;
  final bool cachedOnly;
  final int cachedCount;
  final int totalCount;
  final VoidCallback? onRefresh;
  final VoidCallback onToggleCached;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 58),
            TitleLogo(
              title: title,
              logoPath: logoPath,
              maxLines: 2,
              textAlign: TextAlign.left,
              logoHeight: 88,
              maxLogoWidth: 330,
              textStyle: const TextStyle(
                color: AppColors.text,
                fontSize: 34,
                height: 0.95,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              loading
                  ? 'Searching addons...'
                  : '$subtitle - $totalCount source${totalCount == 1 ? '' : 's'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                GestureDetector(
                  onTap: onToggleCached,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: cachedOnly
                          ? AppColors.text
                          : Colors.white.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Text(
                      'Cached only $cachedCount',
                      style: TextStyle(
                        color:
                            cachedOnly ? AppColors.background : AppColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (onRefresh != null)
                  TextButton(
                    onPressed: onRefresh,
                    child: const Text('Refresh'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SourcesPinnedToolbar extends StatelessWidget {
  const _SourcesPinnedToolbar({
    required this.title,
    this.logoPath,
    required this.showTitle,
    required this.onBack,
    required this.onRefresh,
  });

  final String title;
  final String? logoPath;
  final bool showTitle;
  final VoidCallback onBack;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(showTitle ? 0.78 : 0.20),
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
            _TopIconButton(
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
                    logoHeight: 38,
                    maxLogoWidth: 210,
                    textStyle: const TextStyle(
                      color: AppColors.text,
                      fontSize: 20,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _TopIconButton(
              icon: Icons.refresh_rounded,
              onTap: onRefresh,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback? onTap;

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
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Icon(
          icon,
          color: onTap == null ? AppColors.textSubtle : AppColors.text,
          size: 24,
        ),
      ),
    );
  }
}

class _SourceTabsStrip extends StatelessWidget {
  const _SourceTabsStrip({
    required this.selectedSource,
    required this.sourceNames,
    required this.onSelected,
  });

  final String? selectedSource;
  final List<String> sourceNames;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: ListView(
        cacheExtent: 500,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
        children: <Widget>[
          _SourceFilterChip(
            label: 'All',
            selected: selectedSource == null,
            onTap: () => onSelected(null),
          ),
          ...sourceNames.map(
            (String sourceName) => Padding(
              padding: const EdgeInsets.only(left: 10),
              child: _SourceFilterChip(
                label: sourceName,
                selected: selectedSource == sourceName,
                onTap: () => onSelected(sourceName),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

abstract class _SourceListEntry {
  const _SourceListEntry();
}

class _SourceHeaderEntry extends _SourceListEntry {
  const _SourceHeaderEntry(this.title);

  final String title;
}

class _SourceSmallHeaderEntry extends _SourceListEntry {
  const _SourceSmallHeaderEntry(this.title);

  final String title;
}

class _SourceCardEntry extends _SourceListEntry {
  const _SourceCardEntry(this.source);

  final StreamSource source;
}

class _SourceSpacerEntry extends _SourceListEntry {
  const _SourceSpacerEntry(this.height);

  final double height;
}

class _SmallGroupLabel extends StatelessWidget {
  const _SmallGroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

List<StreamBadge> _badgesForCard(
  StreamBadgeService badgeService,
  List<StreamBadge> customBadges,
  StreamSource source,
) {
  final List<StreamBadge> matched = badgeService.matchesForSource(
    badges: customBadges,
    source: source,
    limit: 10,
  );
  if (matched.isNotEmpty) {
    return matched;
  }

  final List<StreamBadge> generated = _generatedStreamBadges(source);
  final Set<String> seen = <String>{};
  return generated
      .where((StreamBadge badge) {
        final String key = badge.name.trim().toLowerCase();
        return key.isNotEmpty && seen.add(key);
      })
      .take(12)
      .toList(growable: false);
}

List<StreamBadge> _generatedStreamBadges(StreamSource source) {
  final String text = <String>[
    source.quality,
    source.title,
    source.description,
    if (source.fileName != null) source.fileName!,
  ].join(' ').toLowerCase();
  final List<StreamBadge> badges = <StreamBadge>[];

  void add(String name, {String? tagColor, String? textColor}) {
    badges.add(
      StreamBadge(
        name: name,
        pattern: RegExp.escape(name),
        tagColor: tagColor,
        textColor: textColor,
        borderColor: '#33FFFFFF',
      ),
    );
  }

  if (text.contains('2160') || text.contains('4k') || text.contains('uhd')) {
    add('4K', tagColor: '#F7B928', textColor: '#050505');
  } else if (text.contains('1080')) {
    add('1080p', tagColor: '#FFFFFF', textColor: '#050505');
  } else if (text.contains('720')) {
    add('720p');
  }
  if (text.contains('remux')) {
    add('REMUX');
  }
  if (text.contains('bluray') || text.contains('blu-ray')) {
    add('BLURAY');
  } else if (text.contains('web-dl') || text.contains('webdl')) {
    add('WEBDL');
  } else if (text.contains('webrip')) {
    add('WEBRIP');
  } else if (text.contains('hdtv')) {
    add('HDTV');
  }
  if (text.contains('x265') ||
      text.contains('h.265') ||
      text.contains('hevc')) {
    add('HEVC', tagColor: '#1D8F3A');
  } else if (text.contains('x264') ||
      text.contains('h.264') ||
      text.contains('avc')) {
    add('H.264');
  }
  if (text.contains('dolby vision') || RegExp(r'\bdv\b').hasMatch(text)) {
    add('DV');
  }
  if (text.contains('hdr10+')) {
    add('HDR10+');
  } else if (text.contains('hdr10')) {
    add('HDR10');
  } else if (RegExp(r'\bhdr\b').hasMatch(text)) {
    add('HDR');
  }
  if (text.contains('atmos')) {
    add('ATMOS');
  }
  if (text.contains('7.1')) {
    add('7.1');
  } else if (text.contains('5.1')) {
    add('5.1');
  }
  if ((source.cacheProvider ?? '').contains('TB+')) {
    add('TB+');
  }
  if ((source.cacheProvider ?? '').contains('RD+')) {
    add('RD+');
  }
  if (source.sizeLabel.trim().isNotEmpty) {
    add(source.sizeLabel.trim().toUpperCase());
  }

  return badges;
}

class _OmnioSourceCard extends StatelessWidget {
  const _OmnioSourceCard({
    required this.source,
    required this.badges,
    required this.onPlay,
    required this.onAddToTorBox,
  });

  final StreamSource source;
  final List<StreamBadge> badges;
  final VoidCallback onPlay;
  final VoidCallback onAddToTorBox;

  @override
  Widget build(BuildContext context) {
    final bool seasonPack = isSeasonPackTitle(
      <String>[
        source.title,
        source.description,
        if (source.fileName != null) source.fileName!,
      ].join('\n'),
    );
    final String releaseLine = _releaseLine(source);
    final String featureLine = _featureLine(source);
    final String fileLine = _fileLine(source);
    final String sizeLine = _sizeLine(source);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onPlay,
        onLongPress: source.hasTorrentSource ? onAddToTorBox : null,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: const Color(0xFF141517).withOpacity(0.70),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Colors.white.withOpacity(0.09),
                Colors.white.withOpacity(0.025),
              ],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.bolt_rounded,
                          color: Color(0xFFFFD447),
                          size: 23,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            source.quality.isEmpty
                                ? 'Source'
                                : source.quality.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: IconButton.filled(
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.08),
                      ),
                      onPressed: onPlay,
                      icon: const Icon(
                        Icons.play_arrow_rounded,
                        color: AppColors.text,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
              if (releaseLine.isNotEmpty) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  '[$releaseLine]',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              if (featureLine.isNotEmpty)
                _SourceInfoLine(
                    icon: Icons.movie_creation_outlined, text: featureLine),
              if (sizeLine.isNotEmpty)
                _SourceInfoLine(
                    icon: Icons.inventory_2_outlined, text: sizeLine),
              _SourceInfoLine(
                  icon: Icons.build_rounded, text: source.sourceDisplayName),
              if (seasonPack)
                const _SourceInfoLine(
                    icon: Icons.folder_copy_outlined, text: 'Season pack'),
              if (source.isDirectUrl)
                const _SourceInfoLine(
                    icon: Icons.link_rounded, text: 'Direct URL'),
              if (fileLine.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    fileLine,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14.5,
                      height: 1.35,
                    ),
                  ),
                ),
              if (badges.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                _StreamBadgeWrap(badges: badges),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceInfoLine extends StatelessWidget {
  const _SourceInfoLine({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: AppColors.textMuted, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreamBadgeWrap extends StatelessWidget {
  const _StreamBadgeWrap({required this.badges});

  final List<StreamBadge> badges;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 9,
      runSpacing: 8,
      children: badges.map((StreamBadge badge) {
        final String? imageUrl = _badgeImageUrl(badge.imageUrl);
        if (imageUrl != null && imageUrl.isNotEmpty) {
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 124, maxHeight: 34),
            child: OptimizedNetworkImage(
              url: imageUrl,
              height: 28,
              fit: BoxFit.contain,
              cacheWidth: 180,
              errorBuilder: (
                BuildContext context,
                Object error,
                StackTrace? stackTrace,
              ) {
                return _TextBadge(badge: badge);
              },
            ),
          );
        }
        return _TextBadge(badge: badge);
      }).toList(growable: false),
    );
  }
}

String? _badgeImageUrl(String? raw) {
  final String value = (raw ?? '').trim();
  if (value.isEmpty) {
    return null;
  }
  if (value.startsWith('http://') ||
      value.startsWith('https://') ||
      value.startsWith('data:')) {
    return value;
  }
  if (value.startsWith('/')) {
    return 'https://nintle.github.io$value';
  }
  return 'https://nintle.github.io/Badger/$value';
}

class _TextBadge extends StatelessWidget {
  const _TextBadge({required this.badge});

  final StreamBadge badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color:
            _parseBadgeColor(badge.tagColor) ?? Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: _parseBadgeColor(badge.borderColor) ??
              Colors.white.withOpacity(0.10),
        ),
      ),
      child: Text(
        badge.name,
        style: TextStyle(
          color: _parseBadgeColor(badge.textColor) ?? AppColors.text,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.text,
        fontSize: 21,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.4,
      ),
    );
  }
}

class _SourceFilterChip extends StatelessWidget {
  const _SourceFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.text : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.background : AppColors.text,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: <Widget>[
          const Icon(Icons.search_outlined,
              color: AppColors.textMuted, size: 36),
          const SizedBox(height: 12),
          const Text(
            'No results yet',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message ?? 'No sources came back for this title.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, height: 1.45),
          ),
        ],
      ),
    );
  }
}

String _sourceImageUrl(String path, String size) {
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return path;
  }
  return getImageUrl(path, size);
}

String _releaseLine(StreamSource source) {
  final String text = '${source.title}\n${source.description}';
  final RegExpMatch? match = RegExp(
    r'(WEB[- ]?DL|WEBRip|BluRay|BRRip|HDRip|DVDRip|HDTV|Remux)',
    caseSensitive: false,
  ).firstMatch(text);
  return match?.group(0)?.toUpperCase().replaceAll(' ', '-') ?? '';
}

String _featureLine(StreamSource source) {
  final String text = '${source.title} ${source.description}'.toLowerCase();
  final List<String> parts = <String>[];

  if (text.contains('x265') ||
      text.contains('h.265') ||
      text.contains('hevc')) {
    parts.add('HEVC');
  } else if (text.contains('x264') ||
      text.contains('h.264') ||
      text.contains('avc')) {
    parts.add('H.264');
  }
  if (text.contains('hdr10+')) {
    parts.add('HDR10+');
  } else if (text.contains('hdr10')) {
    parts.add('HDR10');
  } else if (RegExp(r'\bhdr\b').hasMatch(text)) {
    parts.add('HDR');
  }
  if (text.contains(' dolby vision') || RegExp(r'\bdv\b').hasMatch(text)) {
    parts.add('DV');
  }
  if (text.contains('atmos')) {
    parts.add('Atmos');
  }
  if (text.contains('ddp') || text.contains('dd+')) {
    parts.add('DD+');
  }
  if (text.contains('5.1')) {
    parts.add('5.1');
  }
  if (text.contains('7.1')) {
    parts.add('7.1');
  }

  return parts.isEmpty
      ? source.description.split('\n').first.trim()
      : parts.join(' / ');
}

String _sizeLine(StreamSource source) {
  final List<String> parts = <String>[
    if (source.sizeLabel.trim().isNotEmpty) source.sizeLabel.trim(),
    if ((source.cacheProvider ?? '').trim().isNotEmpty)
      source.cacheProvider!.trim(),
  ];
  return parts.join(' / ');
}

String _fileLine(StreamSource source) {
  final String? fileName = source.fileName;
  if (fileName != null && fileName.trim().isNotEmpty) {
    return fileName.trim();
  }
  if (source.title.trim().isNotEmpty) {
    return source.title.trim();
  }
  return source.description.trim();
}

Color? _parseBadgeColor(String? raw) {
  final String value = (raw ?? '').trim();
  if (value.isEmpty ||
      value == '#00000000' ||
      value.toLowerCase() == 'transparent') {
    return null;
  }
  final String hex = value.replaceFirst('#', '');
  if (hex.length != 6 && hex.length != 8) {
    return null;
  }
  final int? parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) {
    return null;
  }
  return Color(hex.length == 6 ? 0xFF000000 | parsed : parsed);
}
