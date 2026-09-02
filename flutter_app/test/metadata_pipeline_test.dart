import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/src/models/torbox_models.dart';
import 'package:flutter_app/src/services/tmdb_http_service.dart';
import 'package:flutter_app/src/services/tmdb_media_service.dart';

import 'test_fakes.dart';

void main() {
  test('parses Cinemeta episodes, trailers, links, and behavior hints', () {
    final AddonMetaItem meta = AddonMetaItem.fromJson(
      <String, dynamic>{
        'id': 'tt26545992',
        'type': 'series',
        'name': 'Lanterns',
        'behaviorHints': <String, dynamic>{
          'defaultVideoId': 'tt26545992:1:1',
          'hasScheduledVideos': true,
        },
        'videos': <dynamic>[
          <String, dynamic>{
            'id': 'tt26545992:1:1',
            'name': 'Pilot',
            'season': 1,
            'episode': 1,
            'tvdb_id': 9216985,
            'overview': 'Episode overview',
            'thumbnail': 'https://episodes.example/pilot.jpg',
            'released': '2026-08-17T05:00:00Z',
          },
        ],
        'trailers': <dynamic>[
          <String, dynamic>{'source': 'youtube-key', 'type': 'Trailer'},
        ],
        'trailerStreams': <dynamic>[
          <String, dynamic>{'ytId': 'youtube-key', 'title': 'Official'},
        ],
        'links': <dynamic>[
          <String, dynamic>{
            'name': 'Action',
            'category': 'Genres',
            'url': 'stremio:///discover/action',
          },
        ],
      },
    );

    expect(meta.videos, hasLength(1));
    expect(meta.videos.single.name, 'Pilot');
    expect(meta.videos.single.episodeNumber, 1);
    expect(meta.videos.single.thumbnail, contains('pilot.jpg'));
    expect(meta.trailers, hasLength(1));
    expect(meta.trailers.single.key, 'youtube-key');
    expect(meta.links.single.category, 'Genres');
    expect(meta.defaultVideoId, 'tt26545992:1:1');
    expect(meta.hasScheduledVideos, isTrue);
  });

  test('preserves required catalog extras across persistence', () {
    final AddonCatalog catalog = AddonCatalog.fromJson(
      <String, dynamic>{
        'id': 'year',
        'type': 'series',
        'name': 'New',
        'extra': <dynamic>[
          <String, dynamic>{'name': 'genre', 'isRequired': true},
          <String, dynamic>{'name': 'skip'},
        ],
      },
    );

    expect(catalog.hasRequiredExtras, isTrue);
    expect(catalog.requiredExtraNames, contains('genre'));

    final AddonCatalog restored = AddonCatalog.fromJson(catalog.toJson());
    expect(restored.hasRequiredExtras, isTrue);
    expect(restored.requiredExtraNames, contains('genre'));
  });

  test('TMDB service sends paths without a duplicate API version', () async {
    final _RecordingTmdbHttpService http = _RecordingTmdbHttpService();
    final TmdbMediaService service = TmdbMediaService(
      settingsRepository: FakeAppSettingsRepository(),
      httpService: http,
    );

    await service.findMediaByExternalId('tt0903747', 'tv');
    await service.getSeasonEpisodes(1396, 2);

    expect(http.paths, <String>[
      '/find/tt0903747',
      '/tv/1396',
      '/tv/1396/season/2',
    ]);
    expect(http.paths, everyElement(isNot(startsWith('/3/'))));
  });
}

class _RecordingTmdbHttpService extends TmdbHttpService {
  _RecordingTmdbHttpService()
      : super(settingsRepository: FakeAppSettingsRepository());

  final List<String> paths = <String>[];

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String> params = const <String, String>{},
    AppSettings? settings,
    String? apiKeyOverride,
  }) async {
    paths.add(path);
    if (path.startsWith('/find/')) {
      return <String, dynamic>{
        'tv_results': <dynamic>[
          <String, dynamic>{'id': 1396},
        ],
      };
    }
    if (path.contains('/season/')) {
      return <String, dynamic>{'episodes': <dynamic>[]};
    }
    return <String, dynamic>{
      'id': 1396,
      'name': 'Breaking Bad',
      'overview': '',
      'seasons': <dynamic>[],
      'networks': <dynamic>[],
      'production_companies': <dynamic>[],
    };
  }
}
