import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class OmnioPlayerValue {
  const OmnioPlayerValue({
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isPlaying = false,
    this.isBuffering = false,
    this.isCompleted = false,
    this.isReady = false,
    this.hasError = false,
    this.errorDescription,
    this.playbackSpeed = 1,
    this.engine = 'media3',
  });

  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final bool isBuffering;
  final bool isCompleted;
  final bool isReady;
  final bool hasError;
  final String? errorDescription;
  final double playbackSpeed;
  final String engine;

  OmnioPlayerValue copyWith({
    Duration? position,
    Duration? duration,
    bool? isPlaying,
    bool? isBuffering,
    bool? isCompleted,
    bool? isReady,
    bool? hasError,
    String? errorDescription,
    bool clearError = false,
    double? playbackSpeed,
    String? engine,
  }) {
    return OmnioPlayerValue(
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      isCompleted: isCompleted ?? this.isCompleted,
      isReady: isReady ?? this.isReady,
      hasError: clearError ? false : hasError ?? this.hasError,
      errorDescription:
          clearError ? null : errorDescription ?? this.errorDescription,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      engine: engine ?? this.engine,
    );
  }
}

class OmnioPlayerController extends ChangeNotifier {
  OmnioPlayerController({
    required String url,
    required Map<String, String> headers,
    required String? streamFormat,
    required List<Map<String, String>> sourceSubtitles,
    required bool autoplay,
    required int startPositionMs,
  })  : instanceKey = 'player_${++_nextId}',
        _channel = MethodChannel('omnio/native_player/player_$_nextId') {
    surface = AndroidView(
      key: ValueKey<String>(instanceKey),
      viewType: 'omnio/native_player',
      creationParamsCodec: const StandardMessageCodec(),
      creationParams: <String, Object?>{
        'instanceKey': instanceKey,
        'url': url,
        'headers': headers,
        'format': streamFormat,
        'sourceSubtitles': sourceSubtitles,
        'autoplay': autoplay,
        'startPositionMs': startPositionMs,
        'engine': 'auto',
      },
    );
    _pollTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => unawaited(_poll()),
    );
  }

  static int _nextId = 0;

  final String instanceKey;
  final MethodChannel _channel;
  late final Widget surface;
  late final Timer _pollTimer;
  OmnioPlayerValue _value = const OmnioPlayerValue();
  bool _started = false;

  OmnioPlayerValue get value => _value;

  Future<void> initialize() async {}

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _invokeWithRetry('start');
    await _poll();
  }

  Future<void> play() => _invoke('play');

  Future<void> pause() => _invoke('pause');

  Future<void> toggle() => _invoke('toggle');

  Future<void> seekTo(Duration position) => _invoke(
      'seekTo', <String, Object?>{'positionMs': position.inMilliseconds});

  Future<void> seekBy(Duration offset) =>
      _invoke('seekBy', <String, Object?>{'offsetMs': offset.inMilliseconds});

  Future<void> setPlaybackSpeed(double speed) =>
      _invoke('setSpeed', <String, Object?>{'speed': speed});

  Future<void> selectTrack(int index) =>
      _invoke('selectTrack', <String, Object?>{'index': index});

  Future<void> disableSubtitles() => _invoke('disableSubtitles');

  Future<void> addSubtitle(String url, {String? name}) => _invoke(
        'addSubtitle',
        <String, Object?>{'url': url, 'name': name},
      );

  Future<void> switchEngine() => _invoke('switchEngine');

  Future<void> retry() => _invoke('retry');

  Future<List<dynamic>> tracks() async {
    final List<dynamic>? tracks =
        await _channel.invokeListMethod<dynamic>('tracks');
    return tracks ?? const <dynamic>[];
  }

  Future<void> release() async {
    _pollTimer.cancel();
    try {
      await _channel.invokeMethod<void>('release');
    } on MissingPluginException {
      // The platform view may already have been removed during route teardown.
    }
  }

  Future<void> _invoke(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // A route can dispose the platform view between a tap and the channel call.
    }
  }

  Future<void> _invokeWithRetry(String method) async {
    for (int attempt = 0; attempt < 20; attempt += 1) {
      try {
        await _channel.invokeMethod<void>(method);
        return;
      } on MissingPluginException {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  }

  Future<void> _poll() async {
    if (!_started) return;
    try {
      final Map<dynamic, dynamic>? raw =
          await _channel.invokeMapMethod<dynamic, dynamic>('snapshot');
      if (raw == null) return;
      final OmnioPlayerValue next = OmnioPlayerValue(
        position: Duration(milliseconds: _number(raw['positionMs'])),
        duration: Duration(milliseconds: _number(raw['durationMs'])),
        isPlaying: raw['isPlaying'] == true,
        isBuffering: raw['isBuffering'] == true,
        isCompleted: raw['isCompleted'] == true,
        isReady: raw['isReady'] == true,
        hasError: raw['error'] != null,
        errorDescription: raw['error']?.toString(),
        playbackSpeed: _decimal(raw['speed'], fallback: 1),
        engine: raw['engine']?.toString() ?? 'media3',
      );
      if (_sameValue(_value, next)) return;
      _value = next;
      notifyListeners();
    } on MissingPluginException {
      // The view is still waiting for its first Android platform frame.
    } catch (_) {
      // A transient platform teardown should not break the player route.
    }
  }

  static int _number(Object? value, {int fallback = 0}) {
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _decimal(Object? value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static bool _sameValue(OmnioPlayerValue a, OmnioPlayerValue b) {
    return a.position == b.position &&
        a.duration == b.duration &&
        a.isPlaying == b.isPlaying &&
        a.isBuffering == b.isBuffering &&
        a.isCompleted == b.isCompleted &&
        a.isReady == b.isReady &&
        a.hasError == b.hasError &&
        a.errorDescription == b.errorDescription &&
        (a.playbackSpeed - b.playbackSpeed).abs() < 0.001 &&
        a.engine == b.engine;
  }

  @override
  void dispose() {
    unawaited(release());
    super.dispose();
  }
}
