import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/torbox_models.dart';
import '../models/watch_history_item.dart';
import '../services/app_settings_repository.dart';
import '../services/episode_parser.dart';
import '../services/omnio_player_controller.dart';
import '../services/torbox_api_service.dart';
import '../services/watch_history_repository.dart';
import '../theme/app_colors.dart';

class VideoPlayerScreen extends StatefulWidget {
  VideoPlayerScreen({
    super.key,
    required this.title,
    this.posterUrl,
    this.tmdbId,
    this.imdbId,
    this.mediaType,
    this.seasonNumber,
    this.episodeNumber,
    this.episodeName,
    this.torrentHash,
    this.torrentId,
    this.initialVideoUrl,
    this.initialFiles = const <TorBoxTorrentFile>[],
    this.initialFileId,
    this.initialFileIndex,
    this.initialFileName,
    this.startPositionMs,
    this.provider,
    this.streamHeaders = const <String, String>{},
    this.sourceSubtitles = const <Map<String, String>>[],
    this.streamFormat,
    AppSettingsRepository? settingsRepository,
    TorBoxApiService? torBoxApiService,
    ContinueWatchingRepository? watchHistoryRepository,
  })  : settingsRepository = settingsRepository ?? AppSettingsRepository(),
        torBoxApiService = torBoxApiService ?? TorBoxApiService(),
        watchHistoryRepository =
            watchHistoryRepository ?? WatchHistoryRepository();

  final String title;
  final String? posterUrl;
  final int? tmdbId;
  final String? imdbId;
  final String? mediaType;
  final int? seasonNumber;
  final int? episodeNumber;
  final String? episodeName;
  final String? torrentHash;
  final int? torrentId;
  final String? initialVideoUrl;
  final List<TorBoxTorrentFile> initialFiles;
  final int? initialFileId;
  final int? initialFileIndex;
  final String? initialFileName;
  final int? startPositionMs;
  final String? provider;
  final Map<String, String> streamHeaders;
  final List<Map<String, String>> sourceSubtitles;
  final String? streamFormat;
  final AppSettingsRepository settingsRepository;
  final TorBoxApiService torBoxApiService;
  final ContinueWatchingRepository watchHistoryRepository;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  static const MethodChannel _externalPlayerChannel =
      MethodChannel('streamed/external_player');

  OmnioPlayerController? _controller;
  List<TorBoxTorrentFile> _files = const <TorBoxTorrentFile>[];
  String? _resolvedUrl;
  int? _activeFileId;
  Timer? _progressTimer;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _loading = true;
  bool _saving = false;
  bool _initialized = false;
  bool _showControls = true;
  bool _subtitlesVisible = true;
  bool _landscapeLocked = true;
  String? _error;
  String? _externalSubtitleName;
  _PlaybackIssue? _playbackIssue;
  List<dynamic> _audioTracks = const <dynamic>[];
  List<dynamic> _subtitleTracks = const <dynamic>[];
  List<int> _activeAudioTracks = const <int>[];
  List<int> _activeSubtitleTracks = const <int>[];
  int _lastPersistedSecond = -1;
  AppSettings _settings = const AppSettings();
  bool _settingsLoaded = false;
  bool _externalOpenedAutomatically = false;
  bool _autoNextStarted = false;

  @override
  void initState() {
    super.initState();
    unawaited(_enterLandscapeMode());
    unawaited(WakelockPlus.enable());
    _files = widget.initialFiles;
    _resolvedUrl = widget.initialVideoUrl;
    _activeFileId = widget.initialFileId;
    _load();
  }

  Future<void> _enterLandscapeMode() async {
    await SystemChrome.setPreferredOrientations(
      const <DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
    );
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (!mounted) {
      return;
    }
    if (!_landscapeLocked) {
      setState(() {
        _landscapeLocked = true;
      });
    }
  }

  Future<void> _loadSettings() async {
    if (_settingsLoaded) {
      return;
    }
    final AppSettings settings = await widget.settingsRepository.loadSettings();
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
      _settingsLoaded = true;
    });
  }

  Future<void> _load() async {
    await _loadSettings();
    if (_resolvedUrl != null && _resolvedUrl!.isNotEmpty) {
      await _openResolvedMedia(_resolvedUrl!);
      return;
    }

    final int? torrentId = widget.torrentId;
    if (torrentId == null) {
      setState(() {
        _loading = false;
        _error = 'No direct stream URL or TorBox torrent was provided.';
        _playbackIssue = const _PlaybackIssue(
          title: 'Nothing to play yet',
          body:
              'This screen needs either a direct stream URL or a TorBox torrent.',
          showExternalActions: false,
        );
      });
      return;
    }

    try {
      final List<TorBoxTorrentFile> files = _files.isNotEmpty
          ? _files
          : await widget.torBoxApiService.getTorrentFiles(torrentId);
      if (!mounted) {
        return;
      }

      final int? fileId = _preferredFileId(files);
      setState(() {
        _files = files;
        _activeFileId = fileId;
      });

      if (fileId != null) {
        await _resolveFile(fileId);
      } else if (mounted) {
        setState(() {
          _loading = false;
          _error = 'This torrent does not expose playable files yet.';
          _playbackIssue = const _PlaybackIssue(
            title: 'No playable files found',
            body:
                'TorBox returned the torrent, but it does not expose a playable video file yet. Refresh the library and try again.',
            showExternalActions: false,
          );
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = _friendlyError(error);
        _playbackIssue = _describePlaybackIssue(error);
      });
    }
  }

  int? _preferredFileId(List<TorBoxTorrentFile> files) {
    if (files.isEmpty) {
      return null;
    }

    final int? activeFileId = _activeFileId;
    if (activeFileId != null &&
        files.any((TorBoxTorrentFile file) => file.id == activeFileId)) {
      return activeFileId;
    }

    final int? initialFileId = widget.initialFileId;
    if (initialFileId != null &&
        files.any((TorBoxTorrentFile file) => file.id == initialFileId)) {
      return initialFileId;
    }

    final int? initialFileIndex = widget.initialFileIndex;
    if (initialFileIndex != null &&
        initialFileIndex >= 0 &&
        initialFileIndex < files.length) {
      return files[initialFileIndex].id;
    }

    final String? initialFileName = widget.initialFileName;
    if (initialFileName != null && initialFileName.trim().isNotEmpty) {
      final String normalizedTarget = _normalizeFileName(initialFileName);
      for (final TorBoxTorrentFile file in files) {
        if (_normalizeFileName(file.name) == normalizedTarget ||
            _normalizeFileName(file.displayName) == normalizedTarget) {
          return file.id;
        }
      }
    }

    if (widget.mediaType == 'tv' &&
        widget.seasonNumber != null &&
        widget.episodeNumber != null) {
      final List<SeasonFileGroup> seasons = parseSeasonPack(files);
      for (final SeasonFileGroup season in seasons) {
        for (final ParsedEpisodeFile episode in season.episodes) {
          if (episode.season == widget.seasonNumber &&
              episode.episode == widget.episodeNumber &&
              episode.originalIndex >= 0 &&
              episode.originalIndex < files.length) {
            return files[episode.originalIndex].id;
          }
        }
      }
    }

    final List<int> videoIndices = getAllVideoFiles(files);
    if (videoIndices.isNotEmpty) {
      final List<TorBoxTorrentFile> videoFiles = videoIndices
          .map((int index) => files[index])
          .toList(growable: false)
        ..sort(_comparePlaybackPreference);
      return videoFiles.first.id;
    }

    return files.first.id;
  }

  String _normalizeFileName(String value) {
    return value.split(RegExp(r'[/\\]')).last.trim().toLowerCase();
  }

  int _comparePlaybackPreference(
    TorBoxTorrentFile a,
    TorBoxTorrentFile b,
  ) {
    final int codecComparison =
        _codecPreferenceScore(a).compareTo(_codecPreferenceScore(b));
    if (codecComparison != 0) {
      return codecComparison;
    }
    return b.size.compareTo(a.size);
  }

  int _codecPreferenceScore(TorBoxTorrentFile file) {
    final String name = file.displayName.toLowerCase();
    if (_looksLikeHevc(name)) {
      return 10;
    }
    if (RegExp(r'(h\.?264|x264|avc)', caseSensitive: false).hasMatch(name)) {
      return 0;
    }
    return 2;
  }

  bool _looksLikeHevc(String value) {
    return RegExp(
      r'(hevc|h\.?265|x265|10bit|10-bit|hi10|hvc1)',
      caseSensitive: false,
    ).hasMatch(value);
  }

  Future<void> _resolveFile(int fileId) async {
    final int? torrentId = widget.torrentId;
    if (torrentId == null) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _playbackIssue = null;
      _activeFileId = fileId;
    });

    final String? url = await widget.torBoxApiService.getQuickStreamUrl(
      torrentId,
      fileId,
    );
    if (!mounted) {
      return;
    }

    if (url == null || url.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Could not resolve a stream URL for this file.';
        _playbackIssue = const _PlaybackIssue(
          title: 'Could not get stream link',
          body:
              'TorBox did not return a playable link for this file yet. Try refreshing the library or choose another file.',
          showExternalActions: false,
        );
      });
      return;
    }

    setState(() {
      _resolvedUrl = url;
    });
    _externalOpenedAutomatically = false;

    await _openResolvedMedia(url);
  }

  Future<void> _openResolvedMedia(String url) async {
    await _loadSettings();
    if (_settings.playbackPreferExternalPlayer &&
        !_externalOpenedAutomatically) {
      _externalOpenedAutomatically = true;
      setState(() {
        _resolvedUrl = url;
        _loading = false;
        _initialized = false;
        _playbackIssue = const _PlaybackIssue(
          title: 'Opening external player',
          body:
              'Your playback settings prefer an external video app for streams.',
          showExternalActions: true,
        );
        _error = 'Opening external player.';
      });
      await _openExternalPlayer();
      return;
    }

    OmnioPlayerController? nextController;
    try {
      final OmnioPlayerController? previousController = _controller;
      setState(() {
        _controller = null;
        _loading = true;
        _error = null;
        _playbackIssue = null;
        _initialized = false;
        _position = Duration.zero;
        _duration = Duration.zero;
      });
      _autoNextStarted = false;

      _progressTimer?.cancel();
      previousController?.removeListener(_handleControllerTick);
      await previousController?.release();
      previousController?.dispose();

      final int startPositionMs = await _initialStartPositionMs() ?? 0;
      nextController = OmnioPlayerController(
        url: url,
        headers: widget.streamHeaders,
        streamFormat: widget.streamFormat,
        sourceSubtitles: widget.sourceSubtitles,
        autoplay: _settings.playbackAutoPlay,
        startPositionMs: startPositionMs,
      );

      nextController.addListener(_handleControllerTick);
      _progressTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _handleControllerTick(),
      );

      if (!mounted) {
        await nextController.release();
        nextController.dispose();
        return;
      }

      setState(() {
        _controller = nextController;
        _initialized = false;
        _loading = true;
        _showControls = true;
        _duration = Duration.zero;
        _position = Duration.zero;
        _subtitlesVisible = _settings.playbackAddonSubtitleStartup != 'off';
      });
      unawaited(() async {
        await nextController!.start();
        await nextController.setPlaybackSpeed(_settings.playbackDefaultSpeed);
      }());
    } catch (error) {
      await nextController?.release();
      nextController?.dispose();
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _initialized = false;
        _error = _friendlyError(error);
        _playbackIssue = _describePlaybackIssue(error);
      });
    }
  }

  Future<int?> _initialStartPositionMs() async {
    if (!_settings.playbackResumeEnabled) {
      return null;
    }
    if (widget.startPositionMs != null && widget.startPositionMs! > 0) {
      return widget.startPositionMs;
    }

    final String? historyId = _historyId;
    if (historyId == null) {
      return null;
    }

    try {
      final List<WatchHistoryItem> history =
          await widget.watchHistoryRepository.getContinueWatching(100);
      for (final WatchHistoryItem item in history) {
        if (item.id == historyId &&
            item.currentTime > 0 &&
            item.progress < 95) {
          return item.currentTime;
        }
      }
    } catch (_) {}
    return null;
  }

  void _handleControllerTick() {
    final OmnioPlayerController? controller = _controller;
    if (controller == null || !mounted) {
      return;
    }

    final OmnioPlayerValue value = controller.value;
    final bool becameReady = value.isReady && !_initialized;
    setState(() {
      _position = value.position;
      _duration = value.duration;
      if (becameReady) {
        _initialized = true;
        _loading = false;
        _error = null;
        _playbackIssue = null;
      }
    });
    if (becameReady) {
      unawaited(() async {
        await _refreshMediaTracks();
        await _applyTrackPreferences();
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await _refreshMediaTracks();
      }());
    }

    if (value.hasError) {
      setState(() {
        final String raw = value.errorDescription ?? 'Video playback error.';
        _error = _friendlyError(raw);
        _playbackIssue = _describePlaybackIssue(raw);
      });
    }

    if (value.isCompleted) {
      unawaited(_persistProgress(forceCompleted: true));
      unawaited(_playNextEpisodeIfAllowed(force: true));
      return;
    }

    if (_settings.playbackAutoPlayNextEpisode &&
        !_autoNextStarted &&
        value.duration > Duration.zero) {
      final double percent =
          (value.position.inMilliseconds / value.duration.inMilliseconds) * 100;
      if (percent >= _settings.playbackNextEpisodeThreshold) {
        unawaited(_playNextEpisodeIfAllowed());
      }
    }

    if (value.position.inSeconds >= 10 &&
        value.position.inSeconds != _lastPersistedSecond &&
        value.position.inSeconds % 10 == 0) {
      _lastPersistedSecond = value.position.inSeconds;
      unawaited(_persistProgress());
    }
  }

  Future<void> _persistProgress({bool forceCompleted = false}) async {
    if (!_settings.playbackSaveProgress) {
      return;
    }
    final int? tmdbId = widget.tmdbId;
    final String? mediaType = widget.mediaType;
    if (tmdbId == null || mediaType == null) {
      return;
    }

    final Duration duration = _duration;
    if (duration <= Duration.zero) {
      return;
    }

    final double progress = forceCompleted
        ? 100
        : ((_position.inMilliseconds / duration.inMilliseconds) * 100)
            .clamp(0, 100);

    if (!forceCompleted &&
        _position.inSeconds < 10 &&
        (widget.startPositionMs ?? 0) <= 0) {
      return;
    }

    if (mounted) {
      setState(() {
        _saving = true;
      });
    }

    final String id = _historyId!;

    await widget.watchHistoryRepository.saveProgress(
      WatchHistoryItem(
        id: id,
        tmdbId: tmdbId,
        mediaType: mediaType,
        title: widget.title,
        posterPath: widget.posterUrl,
        backdropPath: widget.posterUrl,
        imdbId: widget.imdbId,
        seasonNumber: widget.seasonNumber,
        episodeNumber: widget.episodeNumber,
        episodeName: widget.episodeName,
        provider: widget.provider,
        resolvedUrl: _resolvedUrl,
        streamHeaders:
            widget.streamHeaders.isEmpty ? null : widget.streamHeaders,
        torrentHash: widget.torrentHash,
        torrentId: widget.torrentId,
        activeFileId: _activeFileId,
        activeFileIndex: _activeFileIndex,
        activeFileName: _activeFile?.displayName,
        progress: progress,
        currentTime:
            forceCompleted ? duration.inMilliseconds : _position.inMilliseconds,
        duration: duration.inMilliseconds,
        lastWatched: DateTime.now().millisecondsSinceEpoch,
        addedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _saving = false;
    });
  }

  String? get _historyId {
    final int? tmdbId = widget.tmdbId;
    final String? mediaType = widget.mediaType;
    if (tmdbId == null || mediaType == null) {
      return null;
    }
    return <String>[
      tmdbId.toString(),
      mediaType,
      if (widget.seasonNumber != null) 's${widget.seasonNumber}',
      if (widget.episodeNumber != null) 'e${widget.episodeNumber}',
    ].join('_');
  }

  Future<void> _togglePlayPause() async {
    final OmnioPlayerController? controller = _controller;
    if (controller == null) {
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _seekRelative(int seconds) async {
    final OmnioPlayerController? controller = _controller;
    if (controller == null || controller.value.duration <= Duration.zero) {
      return;
    }

    final Duration target =
        controller.value.position + Duration(seconds: seconds);
    final Duration clamped = target < Duration.zero
        ? Duration.zero
        : (target > controller.value.duration
            ? controller.value.duration
            : target);
    await controller.seekTo(clamped);
  }

  Future<void> _setPlaybackSpeed(double speed) async {
    final OmnioPlayerController? controller = _controller;
    if (controller == null) {
      return;
    }
    await controller.setPlaybackSpeed(speed);
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _setTemporarySpeed(bool active) async {
    if (!_settings.playbackHoldToSpeed) {
      return;
    }
    await _setPlaybackSpeed(
      active ? _settings.playbackHoldSpeed : _settings.playbackDefaultSpeed,
    );
  }

  Future<void> _openExternalPlayer() async {
    final String? url = _resolvedUrl;
    if (url == null || url.isEmpty) {
      return;
    }

    if (Platform.isAndroid) {
      try {
        final bool opened = await _externalPlayerChannel.invokeMethod<bool>(
              'openVideo',
              <String, String>{
                'url': url,
                'title': _activeFile?.displayName ?? widget.title,
              },
            ) ??
            false;
        if (opened) {
          return;
        }
      } on PlatformException {
        // Fall through to url_launcher/copy fallback below.
      }
    }

    final Uri uri = Uri.parse(url);
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return;
    }

    await _copyStreamUrl();
  }

  Future<void> _copyStreamUrl() async {
    final String? url = _resolvedUrl;
    if (url == null || url.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Stream URL copied for an external player.')),
    );
  }

  Future<void> _retryActiveFile() async {
    final int? activeFileId = _activeFileId;
    final String? resolvedUrl = _resolvedUrl;
    if (activeFileId != null) {
      await _resolveFile(activeFileId);
      return;
    }
    if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
      await _openResolvedMedia(resolvedUrl);
    }
  }

  Future<void> _playNextEpisodeIfAllowed({bool force = false}) async {
    if (!_settings.playbackAutoPlayNextEpisode || _autoNextStarted) {
      return;
    }

    final ParsedEpisodeFile? nextEpisode = _nextParsedEpisode();
    if (nextEpisode == null || nextEpisode.originalIndex >= _files.length) {
      return;
    }

    _autoNextStarted = true;
    await _persistProgress(forceCompleted: force);
    await _resolveFile(_files[nextEpisode.originalIndex].id);
    if (!mounted) {
      return;
    }
    _showFeatureMessage(
      'Playing next episode: ${formatEpisodeLabel(nextEpisode.season, nextEpisode.episode)}',
    );
  }

  ParsedEpisodeFile? _nextParsedEpisode() {
    final int? activeFileId = _activeFileId;
    if (activeFileId == null || _files.isEmpty) {
      return null;
    }

    final int activeIndex = _files.indexWhere(
      (TorBoxTorrentFile file) => file.id == activeFileId,
    );
    if (activeIndex < 0) {
      return null;
    }

    final List<ParsedEpisodeFile> episodes = parseSeasonPack(_files)
        .where((SeasonFileGroup group) => group.season > 0)
        .expand((SeasonFileGroup group) => group.episodes)
        .toList(growable: false)
      ..sort((ParsedEpisodeFile a, ParsedEpisodeFile b) {
        final int seasonComparison = a.season.compareTo(b.season);
        if (seasonComparison != 0) {
          return seasonComparison;
        }
        return a.episode.compareTo(b.episode);
      });

    final int currentEpisodeIndex = episodes.indexWhere(
      (ParsedEpisodeFile episode) => episode.originalIndex == activeIndex,
    );
    if (currentEpisodeIndex < 0 || currentEpisodeIndex >= episodes.length - 1) {
      return null;
    }

    final ParsedEpisodeFile current = episodes[currentEpisodeIndex];
    final ParsedEpisodeFile next = episodes[currentEpisodeIndex + 1];
    if (!_settings.playbackBingeGroupNextEpisode &&
        next.season != current.season) {
      return null;
    }
    return next;
  }

  Future<void> _refreshMediaTracks() async {
    final OmnioPlayerController? controller = _controller;
    if (controller == null || !_initialized) {
      return;
    }
    final List<dynamic> tracks = await controller.tracks();
    if (!mounted || controller != _controller) {
      return;
    }
    setState(() {
      _audioTracks = tracks
          .where((dynamic track) => _trackType(track) == 'audio')
          .toList(growable: false);
      _subtitleTracks = tracks
          .where((dynamic track) => _trackType(track) == 'subtitle')
          .toList(growable: false);
      _activeAudioTracks = _audioTracks
          .where((dynamic track) => _trackSelected(track))
          .map(_trackIndex)
          .toList(growable: false);
      _activeSubtitleTracks = _subtitleTracks
          .where((dynamic track) => _trackSelected(track))
          .map(_trackIndex)
          .toList(growable: false);
    });
  }

  Future<void> _applyTrackPreferences() async {
    final OmnioPlayerController? controller = _controller;
    if (!mounted || controller == null || !_initialized) {
      return;
    }
    if (_settings.playbackAddonSubtitleStartup == 'off') {
      await controller.disableSubtitles();
      if (!mounted || controller != _controller) return;
      setState(() {
        _subtitlesVisible = false;
      });
      return;
    }

    final List<int> preferredSubtitleTracks = _preferredTrackIndexes(
      _subtitleTracks,
      _preferredSubtitleCodes(),
      preferForced: _settings.playbackUseForcedSubtitles,
    );
    final List<int> preferredAudioTracks = _preferredTrackIndexes(
      _audioTracks,
      _preferredAudioCodes(),
    );

    if (_settings.playbackAddonSubtitleStartup == 'preferred' &&
        preferredSubtitleTracks.isNotEmpty) {
      await controller.selectTrack(preferredSubtitleTracks.first);
    }
    if (preferredAudioTracks.isNotEmpty) {
      await controller.selectTrack(preferredAudioTracks.first);
    }
    if (!mounted || controller != _controller) return;

    setState(() {
      if (_settings.playbackAddonSubtitleStartup == 'preferred') {
        _activeSubtitleTracks = preferredSubtitleTracks;
        _subtitlesVisible = preferredSubtitleTracks.isNotEmpty;
      }
      if (preferredAudioTracks.isNotEmpty) {
        _activeAudioTracks = preferredAudioTracks;
      }
    });
  }

  Future<void> _toggleOrientation() async {
    await _enterLandscapeMode();
    _showFeatureMessage('The player stays locked to landscape while open.');
  }

  Future<void> _selectAudioTrack(int trackIndex) async {
    final OmnioPlayerController? controller = _controller;
    if (controller == null) return;
    await controller.selectTrack(trackIndex);
    await _refreshMediaTracks();
  }

  Future<void> _selectSubtitleTrack(int? trackIndex) async {
    final OmnioPlayerController? controller = _controller;
    if (controller == null) {
      return;
    }
    try {
      if (trackIndex == null) {
        await controller.disableSubtitles();
        setState(() {
          _subtitlesVisible = false;
          _externalSubtitleName = null;
        });
      } else {
        await controller.selectTrack(trackIndex);
        setState(() {
          _subtitlesVisible = true;
          _externalSubtitleName = null;
        });
      }
      await _refreshMediaTracks();
    } catch (_) {
      _showFeatureMessage(
        'This player backend could not switch subtitle tracks for this file.',
      );
    }
  }

  Future<void> _pickExternalSubtitle() async {
    final OmnioPlayerController? controller = _controller;
    if (controller == null) {
      return;
    }
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['srt', 'vtt', 'ass', 'ssa'],
      allowMultiple: false,
    );
    final PlatformFile? pickedFile = result?.files.single;
    final String? path = pickedFile?.path;
    if (path == null || path.isEmpty) {
      return;
    }

    try {
      await controller.addSubtitle(path, name: pickedFile!.name);
      if (!mounted) {
        return;
      }
      setState(() {
        _externalSubtitleName = pickedFile.name;
        _subtitlesVisible = true;
      });
      await _refreshMediaTracks();
      _showFeatureMessage('External subtitles loaded: ${pickedFile.name}');
    } catch (error) {
      _showFeatureMessage('Could not load that subtitle file: $error');
    }
  }

  void _showFeatureMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  List<String> _preferredAudioCodes() {
    final List<String> codes = <String>[
      _settings.playbackPreferredAudioLanguage,
      _settings.playbackSecondaryAudioLanguage,
    ]
        .map((String value) => value.trim().toLowerCase())
        .where((String value) => value.isNotEmpty)
        .toList();
    if (codes.isEmpty) {
      final String deviceLanguage =
          WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      if (deviceLanguage.isNotEmpty) {
        codes.add(deviceLanguage.toLowerCase());
      }
    }
    return codes;
  }

  List<String> _preferredSubtitleCodes() {
    return <String>[
      _settings.playbackPreferredSubtitleLanguage,
      _settings.playbackSecondarySubtitleLanguage,
    ]
        .map((String value) => value.trim().toLowerCase())
        .where((String value) => value.isNotEmpty)
        .toList();
  }

  List<dynamic> _visibleSubtitleTracks() {
    final List<String> codes = _preferredSubtitleCodes();
    if (!_settings.playbackShowOnlyPreferredLanguages || codes.isEmpty) {
      return _subtitleTracks;
    }
    return _subtitleTracks
        .where((dynamic track) => _trackMatchesLanguage(track, codes))
        .toList(growable: false);
  }

  List<int> _preferredTrackIndexes(
    List<dynamic> tracks,
    List<String> languageCodes, {
    bool preferForced = false,
  }) {
    if (tracks.isEmpty || languageCodes.isEmpty) {
      return const <int>[];
    }
    final Iterable<dynamic> candidates = tracks
        .where((dynamic track) => _trackMatchesLanguage(track, languageCodes));
    if (preferForced) {
      final dynamic forcedTrack = candidates.firstWhere(
        (dynamic track) => _trackLooksForced(track),
        orElse: () => null,
      );
      if (forcedTrack != null) {
        return <int>[_trackIndex(forcedTrack)];
      }
    }
    final dynamic firstTrack = candidates.firstWhere(
      (dynamic track) => track != null,
      orElse: () => null,
    );
    return firstTrack == null ? const <int>[] : <int>[_trackIndex(firstTrack)];
  }

  bool _trackMatchesLanguage(dynamic track, List<String> languageCodes) {
    final String haystack = <String>[
      _trackLabel(track, 'Track'),
      _trackDetail(track),
      _trackMetadata(track)
          .values
          .map((dynamic value) => value.toString())
          .join(' '),
    ].join(' ').toLowerCase();
    return languageCodes.any((String code) {
      if (code.isEmpty) {
        return false;
      }
      final String label = _languageNameForCode(code).toLowerCase();
      return haystack.contains(code) || haystack.contains(label);
    });
  }

  bool _trackLooksForced(dynamic track) {
    final String haystack = <String>[
      _trackLabel(track, 'Track'),
      _trackDetail(track),
      _trackMetadata(track)
          .values
          .map((dynamic value) => value.toString())
          .join(' '),
    ].join(' ').toLowerCase();
    return haystack.contains('forced') || haystack.contains('sdh');
  }

  String _friendlyError(Object error) {
    final _PlaybackIssue issue = _describePlaybackIssue(error);
    return '${issue.title}. ${issue.body}';
  }

  _PlaybackIssue _describePlaybackIssue(Object error) {
    final String raw = error.toString();
    final TorBoxTorrentFile? activeFile = _activeFile;
    final bool hevcFile =
        activeFile != null && _looksLikeHevc(activeFile.displayName);
    final bool codecError = RegExp(
      r'(MediaCodecVideoRenderer|NO_EXCEEDS_CAPABILITIES|format_supported|video/hevc|hvc1|decoder|ExoPlaybackException)',
      caseSensitive: false,
    ).hasMatch(raw);

    if (codecError || hevcFile) {
      return _PlaybackIssue(
        title: 'This file is not supported by this device',
        body:
            'The selected video looks like HEVC/x265. Many Android phones cannot decode that inside Flutter. Choose an H.264/x264 file if available, or open the TorBox stream in an external player like VLC.',
        showExternalActions: true,
        rawDetails: raw,
      );
    }

    if (raw.contains('Source error') || raw.contains('HTTP')) {
      return _PlaybackIssue(
        title: 'Could not stream this file',
        body:
            'The TorBox link may have expired or the file is not ready yet. Try again, refresh the library, or choose another file.',
        showExternalActions: true,
        rawDetails: raw,
      );
    }

    return _PlaybackIssue(
      title: 'Playback failed',
      body:
          'The player could not start this stream. Try another file or open the stream in an external player.',
      showExternalActions: true,
      rawDetails: raw,
    );
  }

  TorBoxTorrentFile? get _activeFile =>
      _files.cast<TorBoxTorrentFile?>().firstWhere(
            (TorBoxTorrentFile? file) => file?.id == _activeFileId,
            orElse: () => null,
          );

  int? get _activeFileIndex {
    final int? activeFileId = _activeFileId;
    if (activeFileId == null) {
      return null;
    }
    for (int index = 0; index < _files.length; index += 1) {
      if (_files[index].id == activeFileId) {
        return index;
      }
    }
    return null;
  }

  void _showAudioSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (BuildContext context) {
        return _TrackSheet(
          title: 'Audio',
          emptyMessage:
              'No alternate audio tracks were exposed by this stream. If the file has tracks but they do not appear here, open it in VLC/external player.',
          tracks: _audioTracks,
          activeTracks: _activeAudioTracks,
          onSelect: (int trackIndex) async {
            Navigator.of(context).maybePop();
            await _selectAudioTrack(trackIndex);
          },
        );
      },
    );
  }

  Future<void> _loadSourceSubtitle(Map<String, String> subtitle) async {
    final OmnioPlayerController? controller = _controller;
    if (controller == null) return;
    try {
      final String url = subtitle['url']?.trim() ?? '';
      if (url.isEmpty) throw const FormatException('Subtitle URL is empty');
      await controller.addSubtitle(url, name: subtitle['name']);
      if (!mounted || controller != _controller) return;
      setState(() {
        _externalSubtitleName = subtitle['name'];
        _subtitlesVisible = true;
      });
    } catch (error) {
      if (mounted) _showFeatureMessage('Could not load subtitle: $error');
    }
  }

  void _showSubtitleSheet() {
    final List<dynamic> visibleTracks = _visibleSubtitleTracks();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (BuildContext context) {
        return _SubtitleSheet(
          sourceSubtitles: widget.sourceSubtitles,
          onSourceSubtitle: (subtitle) {
            Navigator.of(context).pop();
            _loadSourceSubtitle(subtitle);
          },
          tracks: visibleTracks,
          activeTracks: _activeSubtitleTracks,
          externalSubtitleName: _externalSubtitleName,
          subtitlesVisible: _subtitlesVisible,
          emptyMessage: _subtitleTracks.isEmpty
              ? 'No embedded subtitle tracks were exposed by this stream.'
              : 'No subtitle tracks match your preferred languages.',
          onDisable: () async {
            Navigator.of(context).maybePop();
            await _selectSubtitleTrack(null);
          },
          onSelect: (int trackIndex) async {
            Navigator.of(context).maybePop();
            await _selectSubtitleTrack(trackIndex);
          },
          onPickExternal: () async {
            Navigator.of(context).maybePop();
            await _pickExternalSubtitle();
          },
        );
      },
    );
  }

  void _showSpeedSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (BuildContext context) {
        final double currentSpeed =
            _controller?.value.playbackSpeed ?? _settings.playbackDefaultSpeed;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Playback speed',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: const <double>[0.75, 1.0, 1.25, 1.5, 2.0]
                      .map(
                        (double speed) => ChoiceChip(
                          label: Text(_speedLabel(speed)),
                          selected: (currentSpeed - speed).abs() < 0.01,
                          selectedColor: AppColors.accent.withOpacity(0.28),
                          backgroundColor: Colors.white.withOpacity(0.05),
                          labelStyle: const TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.w800,
                          ),
                          onSelected: (_) async {
                            Navigator.of(context).maybePop();
                            await _setPlaybackSpeed(speed);
                          },
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEpisodesSheet({
    required List<SeasonFileGroup> seasonGroups,
    required List<int> unparsedVideoIndices,
    required List<ParsedEpisodeFile> extras,
    required bool movieLikeFiles,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.35,
          maxChildSize: 0.92,
          builder: (
            BuildContext context,
            ScrollController scrollController,
          ) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: <Widget>[
                const Text(
                  'Episodes & files',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                if (!movieLikeFiles && seasonGroups.isNotEmpty)
                  ...seasonGroups.map(
                    (SeasonFileGroup group) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _EpisodeGroupCard(
                        title: 'Season ${group.season}',
                        episodes: group.episodes,
                        files: _files,
                        activeFileId: _activeFileId,
                        onSelectFile: _loading
                            ? null
                            : (ParsedEpisodeFile episode) {
                                Navigator.of(context).maybePop();
                                _resolveFile(_files[episode.originalIndex].id);
                              },
                      ),
                    ),
                  ),
                if (movieLikeFiles || unparsedVideoIndices.isNotEmpty) ...[
                  _SheetSectionTitle(
                    title: movieLikeFiles ? 'Video files' : 'Other video files',
                  ),
                  ...unparsedVideoIndices.map(
                    (int index) => _FileTile(
                      file: _files[index],
                      active: _files[index].id == _activeFileId,
                      onTap: _loading
                          ? null
                          : () {
                              Navigator.of(context).maybePop();
                              _resolveFile(_files[index].id);
                            },
                      subtitle: _formatBytes(_files[index].size),
                    ),
                  ),
                ],
                if (extras.isNotEmpty) ...[
                  const _SheetSectionTitle(title: 'Extras'),
                  ...extras.map(
                    (ParsedEpisodeFile episode) => _FileTile(
                      file: _files[episode.originalIndex],
                      active: _files[episode.originalIndex].id == _activeFileId,
                      onTap: _loading
                          ? null
                          : () {
                              Navigator.of(context).maybePop();
                              _resolveFile(
                                _files[episode.originalIndex].id,
                              );
                            },
                      leadingLabel: '#${episode.episode}',
                      subtitle:
                          '${episode.title} - ${_formatBytes(_files[episode.originalIndex].size)}',
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    unawaited(_persistProgress());
    _progressTimer?.cancel();
    _controller?.removeListener(_handleControllerTick);
    _controller?.dispose();
    unawaited(WakelockPlus.disable());
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final OmnioPlayerController? controller = _controller;
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final bool isLandscape = mediaQuery.orientation == Orientation.landscape;
    final bool isPlaying = controller?.value.isPlaying ?? false;
    final bool isBuffering = controller?.value.isBuffering ?? false;
    final double progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0, 1)
        : 0;
    final TorBoxTorrentFile? activeFile = _activeFile;
    final String displayTitle = activeFile?.displayName ?? widget.title;
    final List<SeasonFileGroup> parsedSeasons = parseSeasonPack(_files);
    final List<SeasonFileGroup> seasonGroups = parsedSeasons
        .where((SeasonFileGroup group) => group.season > 0)
        .toList(growable: false);
    final List<ParsedEpisodeFile> extras = parsedSeasons
        .where((SeasonFileGroup group) => group.isExtras)
        .expand((SeasonFileGroup group) => group.episodes)
        .toList(growable: false);
    final bool hasStreamUrl = (_resolvedUrl ?? '').isNotEmpty;
    final bool canControl = _initialized && controller != null;
    final bool movieLikeFiles =
        widget.mediaType == 'movie' || isMovieTorrent(_files);
    final List<int> videoFileIndices = getAllVideoFiles(_files);
    final Set<int> parsedIndices = <int>{
      for (final SeasonFileGroup group in parsedSeasons)
        for (final ParsedEpisodeFile episode in group.episodes)
          episode.originalIndex,
    };
    final List<int> unparsedVideoIndices = videoFileIndices
        .where((int index) => !parsedIndices.contains(index))
        .toList(growable: false);
    Future<void> saveProgressAction() async {
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
      await _persistProgress();
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Progress saved to Continue Watching.'),
        ),
      );
    }

    void closeScreen() {
      Navigator.of(context).maybePop();
    }

    final _PlaybackIssue? activeIssue = _error == null
        ? null
        : _playbackIssue ??
            _PlaybackIssue(
              title: 'Playback failed',
              body: _error!,
              showExternalActions: true,
            );

    return PopScope(
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          unawaited(_persistProgress());
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: isLandscape
            ? null
            : AppBar(
                title: const Text('Player'),
                actions: <Widget>[
                  if (_files.length > 1)
                    IconButton(
                      onPressed: () => _showEpisodesSheet(
                        seasonGroups: seasonGroups,
                        unparsedVideoIndices: unparsedVideoIndices,
                        extras: extras,
                        movieLikeFiles: movieLikeFiles,
                      ),
                      icon: const Icon(Icons.playlist_play_outlined),
                    ),
                ],
              ),
        body: MediaQuery.removePadding(
          context: context,
          removeTop: isLandscape,
          removeBottom: isLandscape,
          child: isLandscape
              ? _PlayerStage(
                  height: double.infinity,
                  playerSurface: controller?.surface,
                  initialized: _initialized,
                  loading: _loading,
                  issue: activeIssue,
                  showControls: _showControls,
                  canControl: canControl,
                  isPlaying: isPlaying,
                  isBuffering: isBuffering,
                  displayTitle: displayTitle,
                  provider: widget.provider,
                  activeFile: activeFile,
                  torrentHash: widget.torrentHash,
                  positionLabel: canControl
                      ? '${_formatDuration(_position)} / ${_formatDuration(_duration)}'
                      : 'Waiting for stream',
                  progress: progress,
                  subtitlesVisible: _subtitlesVisible,
                  externalSubtitleName: _externalSubtitleName,
                  audioTrackCount: _audioTracks.length,
                  subtitleTrackCount: _subtitleTracks.length,
                  landscapeLocked: _landscapeLocked,
                  hasFiles: _files.length > 1,
                  hasStreamUrl: hasStreamUrl,
                  skipSeconds: _settings.playbackSkipSeconds,
                  showFilesButton: _settings.playbackShowFilesButton,
                  showSubtitlesButton: _settings.playbackShowSubtitlesButton,
                  showAudioButton: _settings.playbackShowAudioButton,
                  showExternalButton: _settings.playbackShowExternalButton,
                  showSpeedButton: _settings.playbackSpeedControls,
                  saving: _saving,
                  showInlineCloseButton: true,
                  onTap: () {
                    setState(() {
                      _showControls = !_showControls;
                    });
                  },
                  onClose: closeScreen,
                  onHoldSpeedStart: () => _setTemporarySpeed(true),
                  onHoldSpeedEnd: () => _setTemporarySpeed(false),
                  onPlayPause: _togglePlayPause,
                  onBack: () => _seekRelative(-_settings.playbackSkipSeconds),
                  onForward: () => _seekRelative(_settings.playbackSkipSeconds),
                  onSeek: !canControl
                      ? null
                      : (double value) async {
                          final int millis =
                              (_duration.inMilliseconds * value).round();
                          await controller.seekTo(
                            Duration(milliseconds: millis),
                          );
                        },
                  onChooseFile: () => _showEpisodesSheet(
                    seasonGroups: seasonGroups,
                    unparsedVideoIndices: unparsedVideoIndices,
                    extras: extras,
                    movieLikeFiles: movieLikeFiles,
                  ),
                  onOpenExternal: _openExternalPlayer,
                  onCopyLink: _copyStreamUrl,
                  onRetry: _retryActiveFile,
                  onAudio: _showAudioSheet,
                  onSubtitle: _showSubtitleSheet,
                  onSpeed: _showSpeedSheet,
                  onOrientation: _toggleOrientation,
                  onSaveProgress: saveProgressAction,
                )
              : SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 22),
                    children: <Widget>[
                      _PlayerStage(
                        height:
                            (mediaQuery.size.height * 0.46).clamp(390.0, 520.0),
                        playerSurface: controller?.surface,
                        initialized: _initialized,
                        loading: _loading,
                        issue: activeIssue,
                        showControls: _showControls,
                        canControl: canControl,
                        isPlaying: isPlaying,
                        isBuffering: isBuffering,
                        displayTitle: displayTitle,
                        provider: widget.provider,
                        activeFile: activeFile,
                        torrentHash: widget.torrentHash,
                        positionLabel: canControl
                            ? '${_formatDuration(_position)} / ${_formatDuration(_duration)}'
                            : 'Waiting for stream',
                        progress: progress,
                        subtitlesVisible: _subtitlesVisible,
                        externalSubtitleName: _externalSubtitleName,
                        audioTrackCount: _audioTracks.length,
                        subtitleTrackCount: _subtitleTracks.length,
                        landscapeLocked: _landscapeLocked,
                        hasFiles: _files.length > 1,
                        hasStreamUrl: hasStreamUrl,
                        skipSeconds: _settings.playbackSkipSeconds,
                        showFilesButton: _settings.playbackShowFilesButton,
                        showSubtitlesButton:
                            _settings.playbackShowSubtitlesButton,
                        showAudioButton: _settings.playbackShowAudioButton,
                        showExternalButton:
                            _settings.playbackShowExternalButton,
                        showSpeedButton: _settings.playbackSpeedControls,
                        saving: _saving,
                        onClose: closeScreen,
                        onTap: () {
                          setState(() {
                            _showControls = !_showControls;
                          });
                        },
                        onHoldSpeedStart: () => _setTemporarySpeed(true),
                        onHoldSpeedEnd: () => _setTemporarySpeed(false),
                        onPlayPause: _togglePlayPause,
                        onBack: () =>
                            _seekRelative(-_settings.playbackSkipSeconds),
                        onForward: () =>
                            _seekRelative(_settings.playbackSkipSeconds),
                        onSeek: !canControl
                            ? null
                            : (double value) async {
                                final int millis =
                                    (_duration.inMilliseconds * value).round();
                                await controller
                                    .seekTo(Duration(milliseconds: millis));
                              },
                        onChooseFile: () => _showEpisodesSheet(
                          seasonGroups: seasonGroups,
                          unparsedVideoIndices: unparsedVideoIndices,
                          extras: extras,
                          movieLikeFiles: movieLikeFiles,
                        ),
                        onOpenExternal: _openExternalPlayer,
                        onCopyLink: _copyStreamUrl,
                        onRetry: _retryActiveFile,
                        onAudio: _showAudioSheet,
                        onSubtitle: _showSubtitleSheet,
                        onSpeed: _showSpeedSheet,
                        onOrientation: _toggleOrientation,
                        onSaveProgress: saveProgressAction,
                      ),
                      if (_files.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 12),
                        _MiniLibraryCard(
                          activeTitle: displayTitle,
                          fileCount: _files.length,
                          episodeCount:
                              seasonGroups.fold<int>(0, (int total, group) {
                            return total + group.episodes.length;
                          }),
                          onOpen: () => _showEpisodesSheet(
                            seasonGroups: seasonGroups,
                            unparsedVideoIndices: unparsedVideoIndices,
                            extras: extras,
                            movieLikeFiles: movieLikeFiles,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration <= Duration.zero) {
      return '00:00';
    }

    final int totalSeconds = duration.inSeconds;
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatBytes(int bytes) {
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
}

IconData _skipBackIcon(int seconds) {
  switch (seconds) {
    case 5:
      return Icons.replay_5_rounded;
    case 30:
      return Icons.replay_30_rounded;
    case 10:
    case 15:
    default:
      return Icons.replay_10_rounded;
  }
}

IconData _skipForwardIcon(int seconds) {
  switch (seconds) {
    case 5:
      return Icons.forward_5_rounded;
    case 30:
      return Icons.forward_30_rounded;
    case 10:
    case 15:
    default:
      return Icons.forward_10_rounded;
  }
}

String _speedLabel(double value) {
  if (value == value.roundToDouble()) {
    return '${value.toInt()}x';
  }
  return '${value.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '')}x';
}

class _PlayerStage extends StatelessWidget {
  const _PlayerStage({
    required this.height,
    required this.playerSurface,
    required this.initialized,
    required this.loading,
    required this.issue,
    required this.showControls,
    required this.canControl,
    required this.isPlaying,
    required this.isBuffering,
    required this.displayTitle,
    required this.provider,
    required this.activeFile,
    required this.torrentHash,
    required this.positionLabel,
    required this.progress,
    required this.subtitlesVisible,
    required this.externalSubtitleName,
    required this.audioTrackCount,
    required this.subtitleTrackCount,
    required this.landscapeLocked,
    required this.hasFiles,
    required this.hasStreamUrl,
    required this.skipSeconds,
    required this.showFilesButton,
    required this.showSubtitlesButton,
    required this.showAudioButton,
    required this.showExternalButton,
    required this.showSpeedButton,
    required this.saving,
    this.showInlineCloseButton = false,
    required this.onTap,
    required this.onClose,
    required this.onHoldSpeedStart,
    required this.onHoldSpeedEnd,
    required this.onPlayPause,
    required this.onBack,
    required this.onForward,
    required this.onSeek,
    required this.onChooseFile,
    required this.onOpenExternal,
    required this.onCopyLink,
    required this.onRetry,
    required this.onAudio,
    required this.onSubtitle,
    required this.onSpeed,
    required this.onOrientation,
    required this.onSaveProgress,
  });

  final double height;
  final Widget? playerSurface;
  final bool initialized;
  final bool loading;
  final _PlaybackIssue? issue;
  final bool showControls;
  final bool canControl;
  final bool isPlaying;
  final bool isBuffering;
  final String displayTitle;
  final String? provider;
  final TorBoxTorrentFile? activeFile;
  final String? torrentHash;
  final String positionLabel;
  final double progress;
  final bool subtitlesVisible;
  final String? externalSubtitleName;
  final int audioTrackCount;
  final int subtitleTrackCount;
  final bool landscapeLocked;
  final bool hasFiles;
  final bool hasStreamUrl;
  final int skipSeconds;
  final bool showFilesButton;
  final bool showSubtitlesButton;
  final bool showAudioButton;
  final bool showExternalButton;
  final bool showSpeedButton;
  final bool saving;
  final bool showInlineCloseButton;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final Future<void> Function() onHoldSpeedStart;
  final Future<void> Function() onHoldSpeedEnd;
  final Future<void> Function() onPlayPause;
  final Future<void> Function() onBack;
  final Future<void> Function() onForward;
  final ValueChanged<double>? onSeek;
  final VoidCallback onChooseFile;
  final Future<void> Function() onOpenExternal;
  final Future<void> Function() onCopyLink;
  final Future<void> Function() onRetry;
  final VoidCallback onAudio;
  final VoidCallback onSubtitle;
  final VoidCallback onSpeed;
  final Future<void> Function() onOrientation;
  final Future<void> Function() onSaveProgress;

  @override
  Widget build(BuildContext context) {
    final TorBoxTorrentFile? file = activeFile;
    final bool looksHevc = file != null &&
        RegExp(
          r'(hevc|h\.?265|x265|10bit|10-bit|hi10|hvc1)',
          caseSensitive: false,
        ).hasMatch(file.displayName);

    final Widget stage = GestureDetector(
      onTap: onTap,
      onLongPressStart: (_) => onHoldSpeedStart(),
      onLongPressEnd: (_) => onHoldSpeedEnd(),
      onLongPressCancel: () => onHoldSpeedEnd(),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Colors.black),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (playerSurface != null) Positioned.fill(child: playerSurface!),
            if (loading)
              const Center(
                child: CircularProgressIndicator(color: AppColors.text),
              ),
            if (issue != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: _PlayerErrorPanel(
                    issue: issue!,
                    hasFiles: hasFiles,
                    hasStreamUrl: hasStreamUrl,
                    onChooseFile: onChooseFile,
                    onOpenExternal: onOpenExternal,
                    onCopyLink: onCopyLink,
                    onRetry: onRetry,
                  ),
                ),
              ),
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: showControls ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: IgnorePointer(
                  ignoring: !showControls,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.black.withOpacity(0.74),
                          Colors.black.withOpacity(0.18),
                          Colors.black.withOpacity(0.88),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              if (showInlineCloseButton) ...<Widget>[
                                _TapIconButton(
                                  icon: Icons.arrow_back_rounded,
                                  onTap: onClose,
                                ),
                                const SizedBox(width: 10),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      displayTitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        height: 1.18,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: <Widget>[
                                        _PlayerPill(
                                          icon: isPlaying
                                              ? Icons.pause_rounded
                                              : Icons.play_arrow_rounded,
                                          label:
                                              isPlaying ? 'Playing' : 'Paused',
                                        ),
                                        if (isBuffering)
                                          const _PlayerPill(
                                            icon: Icons.sync_rounded,
                                            label: 'Buffering',
                                          ),
                                        if (provider != null)
                                          _PlayerPill(
                                            icon: Icons.storage_outlined,
                                            label: provider!,
                                          ),
                                        if (looksHevc)
                                          const _PlayerPill(
                                            icon: Icons.warning_amber_rounded,
                                            label: 'HEVC/x265',
                                          ),
                                        if ((torrentHash ?? '').isNotEmpty)
                                          _PlayerPill(
                                            icon: Icons.tag_outlined,
                                            label: torrentHash!.substring(
                                              0,
                                              torrentHash!.length > 8
                                                  ? 8
                                                  : torrentHash!.length,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              _MiniIconButton(
                                icon: landscapeLocked
                                    ? Icons.screen_lock_rotation_rounded
                                    : Icons.screen_rotation_alt_rounded,
                                onTap: onOrientation,
                              ),
                            ],
                          ),
                          const Spacer(),
                          if (initialized && playerSurface != null)
                            Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  _OverlayControlButton(
                                    icon: _skipBackIcon(skipSeconds),
                                    onTap: onBack,
                                  ),
                                  const SizedBox(width: 18),
                                  GestureDetector(
                                    onTap: onPlayPause,
                                    child: Container(
                                      width: 66,
                                      height: 66,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 160,
                                        ),
                                        transitionBuilder: (
                                          Widget child,
                                          Animation<double> animation,
                                        ) {
                                          return ScaleTransition(
                                            scale: animation,
                                            child: child,
                                          );
                                        },
                                        child: Icon(
                                          isPlaying
                                              ? Icons.pause_rounded
                                              : Icons.play_arrow_rounded,
                                          key: ValueKey<bool>(isPlaying),
                                          color: Colors.black,
                                          size: 34,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 18),
                                  _OverlayControlButton(
                                    icon: _skipForwardIcon(skipSeconds),
                                    onTap: onForward,
                                  ),
                                ],
                              ),
                            ),
                          const Spacer(),
                          Row(
                            children: <Widget>[
                              Text(
                                positionLabel,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              if ((externalSubtitleName ?? '').isNotEmpty)
                                Flexible(
                                  child: Text(
                                    externalSubtitleName!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                            ),
                            child: Slider(
                              value: progress,
                              onChanged: onSeek,
                              activeColor: AppColors.accent,
                              inactiveColor: Colors.white24,
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              if (showFilesButton)
                                _BottomToolButton(
                                  icon: Icons.playlist_play_rounded,
                                  label: hasFiles ? 'Episodes' : 'Files',
                                  onTap: onChooseFile,
                                ),
                              if (showSubtitlesButton)
                                _BottomToolButton(
                                  icon: Icons.subtitles_rounded,
                                  label: subtitleTrackCount > 0
                                      ? 'Subs $subtitleTrackCount'
                                      : 'Subs',
                                  active: subtitlesVisible,
                                  onTap: onSubtitle,
                                ),
                              if (showAudioButton)
                                _BottomToolButton(
                                  icon: Icons.graphic_eq_rounded,
                                  label: audioTrackCount > 0
                                      ? 'Audio $audioTrackCount'
                                      : 'Audio',
                                  onTap: onAudio,
                                ),
                              if (showSpeedButton)
                                _BottomToolButton(
                                  icon: Icons.speed_rounded,
                                  label: 'Speed',
                                  onTap: onSpeed,
                                ),
                              if (hasStreamUrl && showExternalButton)
                                _BottomToolButton(
                                  icon: Icons.open_in_new_rounded,
                                  label: 'External',
                                  onTap: onOpenExternal,
                                ),
                              _BottomToolButton(
                                icon: saving
                                    ? Icons.hourglass_top_rounded
                                    : Icons.bookmark_add_outlined,
                                label: saving ? 'Saving' : 'Save',
                                onTap: onSaveProgress,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (height.isInfinite) {
      return SizedBox.expand(child: stage);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: stage,
      ),
    );
  }
}

class _PlayerPill extends StatelessWidget {
  const _PlayerPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: Colors.white70, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.10),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _TapIconButton extends StatelessWidget {
  const _TapIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.10),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _BottomToolButton extends StatelessWidget {
  const _BottomToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final FutureOr<void> Function() onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active
          ? AppColors.accent.withOpacity(0.94)
          : Colors.white.withOpacity(0.12),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: () {
          final FutureOr<void> result = onTap();
          if (result is Future<void>) {
            unawaited(result);
          }
        },
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniLibraryCard extends StatelessWidget {
  const _MiniLibraryCard({
    required this.activeTitle,
    required this.fileCount,
    required this.episodeCount,
    required this.onOpen,
  });

  final String activeTitle;
  final int fileCount;
  final int episodeCount;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.video_library_outlined,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      activeTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      episodeCount > 0
                          ? '$episodeCount parsed episodes · $fileCount files'
                          : '$fileCount playable files',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_up_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetSectionTitle extends StatelessWidget {
  const _SheetSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TrackSheet extends StatelessWidget {
  const _TrackSheet({
    required this.title,
    required this.emptyMessage,
    required this.tracks,
    required this.activeTracks,
    required this.onSelect,
  });

  final String title;
  final String emptyMessage;
  final List<dynamic> tracks;
  final List<int> activeTracks;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (tracks.isEmpty)
            Text(
              emptyMessage,
              style: const TextStyle(color: AppColors.textMuted, height: 1.45),
            )
          else
            ...tracks.map(
              (dynamic track) {
                final int index = _trackIndex(track);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    activeTracks.contains(index)
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: AppColors.text,
                  ),
                  title: Text(
                    _trackLabel(track, title),
                    style: const TextStyle(color: AppColors.text),
                  ),
                  subtitle: Text(
                    _trackDetail(track),
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  onTap: () => onSelect(index),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _SubtitleSheet extends StatelessWidget {
  const _SubtitleSheet({
    this.sourceSubtitles = const [],
    this.onSourceSubtitle,
    required this.tracks,
    required this.activeTracks,
    required this.externalSubtitleName,
    required this.subtitlesVisible,
    required this.emptyMessage,
    required this.onDisable,
    required this.onSelect,
    required this.onPickExternal,
  });

  final List<dynamic> tracks;
  final List<Map<String, String>> sourceSubtitles;
  final ValueChanged<Map<String, String>>? onSourceSubtitle;
  final List<int> activeTracks;
  final String? externalSubtitleName;
  final bool subtitlesVisible;
  final String emptyMessage;
  final Future<void> Function() onDisable;
  final ValueChanged<int> onSelect;
  final Future<void> Function() onPickExternal;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: <Widget>[
          const Text(
            'Subtitles',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              !subtitlesVisible
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: AppColors.text,
            ),
            title: const Text(
              'Off',
              style: TextStyle(color: AppColors.text),
            ),
            onTap: onDisable,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.add_rounded, color: AppColors.text),
            title: const Text(
              'Add external subtitle',
              style: TextStyle(color: AppColors.text),
            ),
            subtitle: Text(
              externalSubtitleName ?? 'SRT and VTT files are supported.',
              style: const TextStyle(color: AppColors.textMuted),
            ),
            onTap: onPickExternal,
          ),
          for (final subtitle in sourceSubtitles)
            ListTile(
                title: Text(subtitle['name'] ?? 'Cloudstream subtitle'),
                subtitle: const Text('Cloudstream'),
                onTap: () => onSourceSubtitle?.call(subtitle)),
          if (tracks.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                emptyMessage,
                style:
                    const TextStyle(color: AppColors.textMuted, height: 1.45),
              ),
            )
          else ...<Widget>[
            const _SheetSectionTitle(title: 'Embedded tracks'),
            ...tracks.map(
              (dynamic track) {
                final int index = _trackIndex(track);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    activeTracks.contains(index)
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: AppColors.text,
                  ),
                  title: Text(
                    _trackLabel(track, 'Subtitle'),
                    style: const TextStyle(color: AppColors.text),
                  ),
                  subtitle: Text(
                    _trackDetail(track),
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  onTap: () => onSelect(index),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

int _trackIndex(dynamic track) {
  if (track is Map<dynamic, dynamic>) {
    final dynamic value = track['index'];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
  try {
    return track.index as int;
  } catch (_) {
    return 0;
  }
}

String _trackType(dynamic track) {
  if (track is Map<dynamic, dynamic>) {
    return track['type']?.toString() ?? '';
  }
  return '';
}

bool _trackSelected(dynamic track) {
  if (track is Map<dynamic, dynamic>) {
    return track['selected'] == true;
  }
  return false;
}

String _trackLabel(dynamic track, String fallback) {
  final int index = _trackIndex(track);
  final Map<dynamic, dynamic> metadata = _trackMetadata(track);
  final String? title = _metadataValue(metadata, <String>[
    'title',
    'handler_name',
    'language',
  ]);
  return title == null || title.isEmpty ? '$fallback ${index + 1}' : title;
}

String _trackDetail(dynamic track) {
  final Map<dynamic, dynamic> metadata = _trackMetadata(track);
  final List<String> parts = <String>[
    if (_metadataValue(metadata, <String>['language']) != null)
      _metadataValue(metadata, <String>['language'])!,
  ];
  final String codecName = _metadataValue(metadata, <String>['codec']) ?? '';
  if (codecName.isNotEmpty) {
    parts.add(codecName);
  }
  try {
    final dynamic codec = track.codec;
    final String legacyCodec = codec.codec?.toString() ?? '';
    if (legacyCodec.isNotEmpty && !parts.contains(legacyCodec)) {
      parts.add(legacyCodec);
    }
  } catch (_) {}
  return parts.isEmpty ? 'Track #${_trackIndex(track)}' : parts.join(' · ');
}

Map<dynamic, dynamic> _trackMetadata(dynamic track) {
  if (track is Map<dynamic, dynamic>) {
    final dynamic metadata = track['metadata'];
    if (metadata is Map<dynamic, dynamic>) return metadata;
    return track;
  }
  try {
    final dynamic metadata = track.metadata;
    if (metadata is Map<dynamic, dynamic>) {
      return metadata;
    }
  } catch (_) {}
  return const <dynamic, dynamic>{};
}

String? _metadataValue(Map<dynamic, dynamic> metadata, List<String> keys) {
  for (final String key in keys) {
    final String? value = metadata[key]?.toString().trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

String _languageNameForCode(String code) {
  switch (code.toLowerCase()) {
    case 'en':
      return 'English';
    case 'hi':
      return 'Hindi';
    case 'ja':
      return 'Japanese';
    case 'es':
      return 'Spanish';
    case 'fr':
      return 'French';
    case 'de':
      return 'German';
    case 'it':
      return 'Italian';
    case 'pt':
      return 'Portuguese';
    case 'ru':
      return 'Russian';
    case 'ko':
      return 'Korean';
    case 'zh':
      return 'Chinese';
    case 'ar':
      return 'Arabic';
    case 'tr':
      return 'Turkish';
    case 'id':
      return 'Indonesian';
    case 'bn':
      return 'Bengali';
    default:
      return code;
  }
}

class _EpisodeGroupCard extends StatelessWidget {
  const _EpisodeGroupCard({
    required this.title,
    required this.episodes,
    required this.files,
    required this.activeFileId,
    required this.onSelectFile,
  });

  final String title;
  final List<ParsedEpisodeFile> episodes;
  final List<TorBoxTorrentFile> files;
  final int? activeFileId;
  final ValueChanged<ParsedEpisodeFile>? onSelectFile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...episodes.map(
            (ParsedEpisodeFile episode) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _FileTile(
                file: files[episode.originalIndex],
                active: files[episode.originalIndex].id == activeFileId,
                onTap:
                    onSelectFile == null ? null : () => onSelectFile!(episode),
                leadingLabel:
                    formatEpisodeLabel(episode.season, episode.episode),
                subtitle:
                    '${episode.title} - ${_formatBytesStatic(files[episode.originalIndex].size)}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({
    required this.file,
    required this.active,
    required this.onTap,
    required this.subtitle,
    this.leadingLabel,
  });

  final TorBoxTorrentFile file;
  final bool active;
  final VoidCallback? onTap;
  final String subtitle;
  final String? leadingLabel;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      tileColor:
          active ? Colors.white.withOpacity(0.10) : AppColors.cardBackground,
      leading: leadingLabel == null
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                leadingLabel!,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
      title: Text(
        file.displayName,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.text),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.textMuted),
      ),
      trailing: IconButton(
        onPressed: onTap,
        icon: const Icon(
          Icons.play_arrow_rounded,
          color: AppColors.text,
        ),
      ),
      onTap: onTap,
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

class _PlaybackIssue {
  const _PlaybackIssue({
    required this.title,
    required this.body,
    required this.showExternalActions,
    this.rawDetails,
  });

  final String title;
  final String body;
  final bool showExternalActions;
  final String? rawDetails;

  String? get shortDetails {
    final String details = rawDetails?.trim() ?? '';
    if (details.isEmpty) {
      return null;
    }
    return details.length > 180 ? '${details.substring(0, 180)}...' : details;
  }
}

class _PlayerErrorPanel extends StatelessWidget {
  const _PlayerErrorPanel({
    required this.issue,
    required this.hasFiles,
    required this.hasStreamUrl,
    required this.onChooseFile,
    required this.onOpenExternal,
    required this.onCopyLink,
    required this.onRetry,
  });

  final _PlaybackIssue issue;
  final bool hasFiles;
  final bool hasStreamUrl;
  final VoidCallback onChooseFile;
  final Future<void> Function() onOpenExternal;
  final Future<void> Function() onCopyLink;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF180F10).withOpacity(0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x55F87171)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFFCA5A5),
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              issue.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              issue.body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (hasFiles)
                  FilledButton.tonalIcon(
                    onPressed: onChooseFile,
                    icon: const Icon(Icons.folder_open_outlined, size: 18),
                    label: const Text('Choose file'),
                  ),
                if (hasStreamUrl && issue.showExternalActions)
                  FilledButton.tonalIcon(
                    onPressed: onOpenExternal,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Open external'),
                  ),
                if (hasStreamUrl && issue.showExternalActions)
                  OutlinedButton.icon(
                    onPressed: onCopyLink,
                    icon: const Icon(Icons.link_rounded, size: 18),
                    label: const Text('Copy URL'),
                  ),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                ),
              ],
            ),
            if (issue.shortDetails != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                issue.shortDetails!,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 10,
                  height: 1.25,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OverlayControlButton extends StatelessWidget {
  const _OverlayControlButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.42),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: Colors.white, size: 27),
        ),
      ),
    );
  }
}
