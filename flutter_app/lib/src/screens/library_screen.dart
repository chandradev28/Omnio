import 'package:flutter/material.dart';

import '../constants/layout.dart';
import '../models/favorite_item.dart';
import '../models/torbox_models.dart';
import '../services/app_settings_repository.dart';
import '../services/favorites_repository.dart';
import '../services/real_debrid_api_service.dart';
import '../services/tmdb_image.dart';
import '../services/torbox_api_service.dart';
import '../theme/app_colors.dart';
import '../theme/layout_options.dart';
import '../widgets/optimized_network_image.dart';
import 'movie_detail_screen.dart';
import 'video_player_screen.dart';

enum _LibraryMode { cloud, saved }

class LibraryScreen extends StatefulWidget {
  LibraryScreen({
    super.key,
    FavoritesRepository? favoritesRepository,
    AppSettingsRepository? settingsRepository,
    TorBoxApiService? torBoxApiService,
    RealDebridApiService? realDebridApiService,
  })  : favoritesRepository = favoritesRepository ?? FavoritesRepository(),
        settingsRepository = settingsRepository ?? AppSettingsRepository(),
        torBoxApiService = torBoxApiService ?? TorBoxApiService(),
        realDebridApiService = realDebridApiService ?? RealDebridApiService();

  final FavoritesRepository favoritesRepository;
  final AppSettingsRepository settingsRepository;
  final TorBoxApiService torBoxApiService;
  final RealDebridApiService realDebridApiService;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<FavoriteItem> _favorites = const <FavoriteItem>[];
  List<TorBoxTorrent> _torBoxTorrents = const <TorBoxTorrent>[];
  List<RealDebridTorrentInfo> _realDebridTorrents =
      const <RealDebridTorrentInfo>[];
  AppSettings _settings = const AppSettings();
  bool _loading = true;
  String? _cloudError;
  _LibraryMode _mode = _LibraryMode.cloud;
  bool _modeInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _loading = true;
    });

    final AppSettings settings = await widget.settingsRepository.loadSettings();
    final List<FavoriteItem> items =
        await widget.favoritesRepository.getFavorites();
    List<TorBoxTorrent> torBoxTorrents = const <TorBoxTorrent>[];
    List<RealDebridTorrentInfo> realDebridTorrents =
        const <RealDebridTorrentInfo>[];
    String? cloudError;

    if (settings.cloudLibraryEnabled) {
      try {
        if ((settings.torBoxApiKey ?? '').trim().isNotEmpty) {
          torBoxTorrents = await widget.torBoxApiService.getUserTorrents();
        }
        if ((settings.realDebridApiKey ?? '').trim().isNotEmpty) {
          realDebridTorrents =
              await widget.realDebridApiService.getUserTorrents();
        }
      } catch (error) {
        cloudError = 'Could not refresh cloud library: $error';
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _settings = settings;
      _favorites = items;
      _torBoxTorrents = torBoxTorrents;
      _realDebridTorrents = realDebridTorrents;
      _cloudError = cloudError;
      _loading = false;
      if (!_modeInitialized) {
        _mode = settings.cloudLibraryEnabled
            ? _LibraryMode.cloud
            : _LibraryMode.saved;
        _modeInitialized = true;
      }
    });
  }

  Future<void> _removeFavorite(FavoriteItem item) async {
    await widget.favoritesRepository.removeFromFavorites(
      item.id,
      item.mediaType,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _favorites = _favorites
          .where(
            (favorite) =>
                favorite.id != item.id || favorite.mediaType != item.mediaType,
          )
          .toList(growable: false);
    });
  }

  void _openDetail(FavoriteItem item) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => MovieDetailScreen(
          id: item.id,
          mediaType: item.mediaType,
        ),
      ),
    );
  }

  void _openTorBoxTorrent(TorBoxTorrent torrent) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => VideoPlayerScreen(
          title: torrent.name,
          torrentId: torrent.id,
          torrentHash: torrent.hash,
          initialFiles: torrent.files,
          provider: 'torbox',
        ),
      ),
    );
  }

  Future<void> _openRealDebridTorrent(RealDebridTorrentInfo torrent) async {
    final String link = torrent.links.isNotEmpty ? torrent.links.first : '';
    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Real-Debrid did not expose a playable link yet.'),
        ),
      );
      return;
    }

    try {
      final RealDebridResolvedLink resolved =
          await widget.realDebridApiService.unrestrictLink(link);
      if (!mounted) {
        return;
      }
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => VideoPlayerScreen(
            title: resolved.filename ?? torrent.filename,
            initialVideoUrl: resolved.url,
            initialFileName: resolved.filename ?? torrent.filename,
            provider: 'real-debrid',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open Real-Debrid item: $error')),
      );
    }
  }

  int get _cloudCount => _torBoxTorrents.length + _realDebridTorrents.length;

  @override
  Widget build(BuildContext context) {
    final Color accent = LayoutOptions.accentFor(_settings);
    return SafeArea(
      child: RefreshIndicator(
        color: accent,
        backgroundColor: AppColors.surface,
        onRefresh: _loadFavorites,
        child: CustomScrollView(
          cacheExtent: 850,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppLayout.horizontalPadding,
                12,
                AppLayout.horizontalPadding,
                24,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  <Widget>[
                    Row(
                      children: <Widget>[
                        const Text(
                          'Library',
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: AppLayout.largeTitle,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            (_favorites.length +
                                    _torBoxTorrents.length +
                                    _realDebridTorrents.length)
                                .toString(),
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _LibraryModeSelector(
                      mode: _mode,
                      cloudCount: _cloudCount,
                      savedCount: _favorites.length,
                      accent: accent,
                      onChanged: (_LibraryMode mode) {
                        setState(() {
                          _mode = mode;
                        });
                      },
                    ),
                    const SizedBox(height: 22),
                    if (_loading)
                      SizedBox(
                        height: 320,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: accent,
                          ),
                        ),
                      )
                    else if (_mode == _LibraryMode.cloud)
                      _CloudLibrarySection(
                        torBoxTorrents: _torBoxTorrents,
                        realDebridTorrents: _realDebridTorrents,
                        cloudEnabled: _settings.cloudLibraryEnabled,
                        error: _cloudError,
                        accent: accent,
                        onOpenTorBox: _openTorBoxTorrent,
                        onOpenRealDebrid: _openRealDebridTorrent,
                      )
                    else
                      _SavedLibrarySection(
                        favorites: _favorites,
                        settings: _settings,
                        accent: accent,
                        onOpen: _openDetail,
                        onRemove: _removeFavorite,
                      ),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryModeSelector extends StatelessWidget {
  const _LibraryModeSelector({
    required this.mode,
    required this.cloudCount,
    required this.savedCount,
    required this.accent,
    required this.onChanged,
  });

  final _LibraryMode mode;
  final int cloudCount;
  final int savedCount;
  final Color accent;
  final ValueChanged<_LibraryMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _LibraryModeChip(
              label: 'Cloud',
              count: cloudCount,
              selected: mode == _LibraryMode.cloud,
              accent: accent,
              onTap: () => onChanged(_LibraryMode.cloud),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _LibraryModeChip(
              label: 'Saved',
              count: savedCount,
              selected: mode == _LibraryMode.saved,
              accent: accent,
              onTap: () => onChanged(_LibraryMode.saved),
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryModeChip extends StatelessWidget {
  const _LibraryModeChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? accent : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.background : AppColors.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.background.withOpacity(0.16)
                      : Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    color:
                        selected ? AppColors.background : AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedLibrarySection extends StatelessWidget {
  const _SavedLibrarySection({
    required this.favorites,
    required this.settings,
    required this.accent,
    required this.onOpen,
    required this.onRemove,
  });

  final List<FavoriteItem> favorites;
  final AppSettings settings;
  final Color accent;
  final ValueChanged<FavoriteItem> onOpen;
  final ValueChanged<FavoriteItem> onRemove;

  @override
  Widget build(BuildContext context) {
    if (favorites.isEmpty) {
      return _EmptyFavoritesState(accent: accent);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Saved titles',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: favorites.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppLayout.libraryGridGap,
            crossAxisSpacing: AppLayout.libraryGridGap,
            childAspectRatio: AppLayout.libraryCardAspectRatio * 0.76,
          ),
          itemBuilder: (BuildContext context, int index) {
            final FavoriteItem item = favorites[index];
            return _FavoriteCard(
              item: item,
              settings: settings,
              accent: accent,
              onOpen: () => onOpen(item),
              onRemove: () => onRemove(item),
            );
          },
        ),
      ],
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({
    required this.item,
    required this.settings,
    required this.accent,
    required this.onOpen,
    required this.onRemove,
  });

  final FavoriteItem item;
  final AppSettings settings;
  final Color accent;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: Material(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(
                    LayoutOptions.posterRadius(settings),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onOpen,
                    child: OptimizedNetworkImage(
                      url: getImageUrl(item.posterPath, 'w342'),
                      fit: BoxFit.cover,
                      cacheWidth: 360,
                      errorBuilder: (
                        BuildContext context,
                        Object error,
                        StackTrace? stackTrace,
                      ) {
                        return const _PosterFallback();
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: _IconPill(
                  icon: Icons.close,
                  onPressed: onRemove,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: _StaticPill(
                  child: Icon(
                    Icons.favorite,
                    size: 14,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _favoriteSubtitle(item),
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _CloudLibrarySection extends StatelessWidget {
  const _CloudLibrarySection({
    required this.torBoxTorrents,
    required this.realDebridTorrents,
    required this.cloudEnabled,
    required this.accent,
    required this.onOpenTorBox,
    required this.onOpenRealDebrid,
    this.error,
  });

  final List<TorBoxTorrent> torBoxTorrents;
  final List<RealDebridTorrentInfo> realDebridTorrents;
  final bool cloudEnabled;
  final Color accent;
  final ValueChanged<TorBoxTorrent> onOpenTorBox;
  final Future<void> Function(RealDebridTorrentInfo) onOpenRealDebrid;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final int count = torBoxTorrents.length + realDebridTorrents.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                'Cloud library',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _StaticPill(
              child: Text(
                '$count items',
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if ((error ?? '').isNotEmpty)
          _CloudEmptyCard(
            message: error!,
            icon: Icons.cloud_off_rounded,
            accent: accent,
          )
        else if (!cloudEnabled)
          _CloudEmptyCard(
            message:
                'Cloud library is off. Enable it in Settings > Integrations > Connected Services to show TorBox and Real-Debrid files here.',
            icon: Icons.toggle_off_rounded,
            accent: accent,
          )
        else if (count == 0)
          _CloudEmptyCard(
            message:
                'No cloud items found yet. Connect TorBox or Real-Debrid in Settings > Integrations > Connected Services.',
            icon: Icons.cloud_queue_rounded,
            accent: accent,
          )
        else ...<Widget>[
          ...torBoxTorrents.map(
            (TorBoxTorrent torrent) => _CloudLibraryTile(
              title: torrent.name,
              subtitle:
                  'TorBox - ${_formatBytesStatic(torrent.size)} - ${torrent.progress.round()}%',
              icon: Icons.dns_rounded,
              accent: accent,
              onTap: () async => onOpenTorBox(torrent),
            ),
          ),
          ...realDebridTorrents.map(
            (RealDebridTorrentInfo torrent) => _CloudLibraryTile(
              title: torrent.filename,
              subtitle:
                  'Real-Debrid - ${_formatBytesStatic(torrent.bytes)} - ${torrent.status}',
              icon: Icons.bolt_rounded,
              accent: accent,
              onTap: () => onOpenRealDebrid(torrent),
            ),
          ),
        ],
      ],
    );
  }
}

class _CloudLibraryTile extends StatelessWidget {
  const _CloudLibraryTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => onTap(),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.play_arrow_rounded, color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CloudEmptyCard extends StatelessWidget {
  const _CloudEmptyCard({
    required this.message,
    required this.icon,
    required this.accent,
  });

  final String message;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _IconPill extends StatelessWidget {
  const _IconPill({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.7),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 14,
            color: AppColors.text,
          ),
        ),
      ),
    );
  }
}

class _StaticPill extends StatelessWidget {
  const _StaticPill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.cardBackground,
      child: Center(
        child: Icon(
          Icons.movie_creation_outlined,
          size: 36,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _EmptyFavoritesState extends StatelessWidget {
  const _EmptyFavoritesState({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 18),
      child: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              children: <Widget>[
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.favorite_border_rounded,
                    size: 30,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Your saved library is empty',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Liked movies and shows will appear here. Cloud files stay in the Cloud tab.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                    height: 1.4,
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

String _formatBytesStatic(int bytes) {
  if (bytes <= 0) {
    return '0 B';
  }

  const List<String> sizes = <String>['B', 'KB', 'MB', 'GB', 'TB'];
  double value = bytes.toDouble();
  int index = 0;
  while (value >= 1024 && index < sizes.length - 1) {
    value /= 1024;
    index += 1;
  }

  return '${value.toStringAsFixed(value >= 10 || index == 0 ? 0 : 1)} ${sizes[index]}';
}

String _favoriteSubtitle(FavoriteItem item) {
  final String type = item.mediaType == 'movie' ? 'Movie' : 'TV Show';
  final String? year = item.year?.trim();
  if (year == null || year.isEmpty) {
    return type;
  }
  return '$type - $year';
}
