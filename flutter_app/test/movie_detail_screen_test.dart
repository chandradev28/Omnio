import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/src/models/tmdb_media_models.dart';
import 'package:flutter_app/src/models/torbox_models.dart';
import 'package:flutter_app/src/screens/movie_detail_screen.dart';
import 'package:flutter_app/src/services/stremio_addons_service.dart';

import 'test_fakes.dart';

void main() {
  test('media detail prefers English title logos', () {
    final MediaDetail detail = MediaDetail.fromJson(
      <String, dynamic>{
        'id': 7,
        'title': 'Movie Title',
        'overview': 'A test overview.',
        'poster_path': null,
        'backdrop_path': null,
        'vote_average': 8.4,
        'vote_count': 1000,
        'release_date': '2024-01-01',
        'runtime': 120,
        'genres': const <dynamic>[],
        'seasons': const <dynamic>[],
        'number_of_seasons': 0,
        'networks': const <dynamic>[],
        'production_companies': const <dynamic>[],
        'imdb_id': 'tt1234567',
        'images': <String, dynamic>{
          'logos': <dynamic>[
            <String, dynamic>{
              'file_path': '/null-language.png',
              'iso_639_1': null,
            },
            <String, dynamic>{
              'file_path': '/english-logo.png',
              'iso_639_1': 'en',
            },
          ],
        },
      },
      mediaType: 'movie',
    );

    expect(detail.logoPath, '/english-logo.png');
  });

  testWidgets('movie detail retries once before showing the failure state', (
    WidgetTester tester,
  ) async {
    final _FlakyMediaService mediaService = _FlakyMediaService(
      detail: const MediaDetail(
        id: 7,
        mediaType: 'tv',
        title: 'Galaxy Squad',
        overview: 'A test overview.',
        posterPath: null,
        backdropPath: null,
        voteAverage: 8.4,
        voteCount: 1000,
        releaseDate: '2024-01-01',
        runtimeMinutes: 48,
        genres: <GenreItem>[GenreItem(id: 1, name: 'Sci-Fi')],
        seasons: <SeasonSummary>[
          SeasonSummary(
            id: 1,
            name: 'Season 1',
            posterPath: null,
            seasonNumber: 1,
            episodeCount: 2,
          ),
        ],
        numberOfSeasons: 1,
        networks: <NetworkItem>[NetworkItem(id: 1, name: 'StreamNet')],
        imdbId: 'tt1234567',
        cast: <CastItem>[],
        similarItems: <MediaSummary>[],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MovieDetailScreen(
          id: 7,
          mediaType: 'tv',
          mediaService: mediaService,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Could not load this title.'), findsNothing);
    expect(find.text('Try again'), findsNothing);

    await tester.pump(const Duration(milliseconds: 450));

    expect(find.text('Galaxy Squad'), findsWidgets);
    expect(find.text('Play'), findsOneWidget);
  });

  testWidgets('movie detail opens streamed sources flow', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MovieDetailScreen(
          id: 7,
          mediaType: 'movie',
          mediaService: const FakeMediaService(
            detail: MediaDetail(
              id: 7,
              mediaType: 'movie',
              title: 'Movie Title',
              overview: 'A test overview.',
              posterPath: null,
              backdropPath: null,
              voteAverage: 8.4,
              voteCount: 1000,
              releaseDate: '2024-01-01',
              runtimeMinutes: 120,
              genres: <GenreItem>[GenreItem(id: 1, name: 'Sci-Fi')],
              seasons: <SeasonSummary>[],
              numberOfSeasons: 0,
              networks: <NetworkItem>[],
              imdbId: 'tt1234567',
              cast: <CastItem>[],
              similarItems: <MediaSummary>[],
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    _tapPlayButton(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Movie Title'), findsWidgets);
  });

  testWidgets('movie detail falls back to addon metadata for external ids', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MovieDetailScreen(
          id: 0,
          mediaType: 'movie',
          externalId: 'tt7654321',
          fallbackTitle: 'Addon Only Movie',
          fallbackOverview: 'Metadata supplied by the Stremio addon.',
          fallbackReleaseInfo: '2026',
          mediaService: const _MissingExternalMediaService(),
          addonsService: _EmptyMetadataAddonsService(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Could not load this title.'), findsNothing);
    expect(find.text('Addon Only Movie'), findsWidgets);
    expect(find.textContaining('Stremio addon'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
  });

  testWidgets('movie detail loads Stremio metadata before TMDB', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MovieDetailScreen(
          id: 0,
          mediaType: 'tv',
          externalId: 'tt0903747',
          fallbackTitle: 'Fallback Show',
          mediaService: const _MissingExternalMediaService(),
          addonsService: _FakeMetadataAddonsService(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Could not load this title.'), findsNothing);
    expect(find.text('Addon Show'), findsWidgets);
    expect(find.textContaining('Loaded from Stremio metadata'), findsOneWidget);
    expect(find.text('Drama'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Pilot'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Pilot'), findsOneWidget);
  });

  testWidgets('movie detail enriches addon metadata with TMDB sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MovieDetailScreen(
          id: 0,
          mediaType: 'tv',
          externalId: 'tt0903747',
          fallbackTitle: 'Fallback Show',
          mediaService: const FakeMediaService(
            detail: MediaDetail(
              id: 99,
              mediaType: 'tv',
              title: 'TMDB Show',
              overview: 'TMDB overview.',
              posterPath: null,
              backdropPath: null,
              voteAverage: 8.6,
              voteCount: 1200,
              releaseDate: '2022-01-01',
              runtimeMinutes: 35,
              genres: <GenreItem>[GenreItem(id: 1, name: 'Comedy')],
              seasons: <SeasonSummary>[
                SeasonSummary(
                  id: 10,
                  name: 'Season 1',
                  posterPath: null,
                  seasonNumber: 1,
                  episodeCount: 8,
                ),
              ],
              numberOfSeasons: 1,
              networks: <NetworkItem>[],
              imdbId: 'tt0903747',
              cast: <CastItem>[
                CastItem(
                  id: 1,
                  name: 'TMDB Actor',
                  character: 'Lead',
                  profilePath: null,
                ),
              ],
              similarItems: <MediaSummary>[
                MediaSummary(
                  id: 12,
                  mediaType: 'tv',
                  title: 'Related Show',
                  posterPath: null,
                  backdropPath: null,
                  releaseDate: '2023-01-01',
                ),
              ],
              trailers: <MediaTrailer>[
                MediaTrailer(
                  name: 'Official Trailer',
                  key: 'abc123',
                  site: 'YouTube',
                  type: 'Trailer',
                ),
              ],
            ),
          ),
          addonsService: _FakeMetadataAddonsService(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Addon Show'), findsWidgets);
    expect(find.textContaining('Loaded from Stremio metadata'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Trailers'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Official Trailer'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Seasons'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Season 1'), findsOneWidget);
  });

  testWidgets('tv detail can navigate into episodes flow', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MovieDetailScreen(
          id: 42,
          mediaType: 'tv',
          mediaService: const FakeMediaService(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Galaxy Squad'), findsWidgets);
    expect(find.text('Play'), findsOneWidget);

    _tapPlayButton(tester);
    await tester.pumpAndSettle();

    expect(find.text('Season 1'), findsOneWidget);
    expect(find.text('Pilot'), findsOneWidget);
  });
}

void _tapPlayButton(WidgetTester tester) {
  final ButtonStyleButton button = tester.widget<ButtonStyleButton>(
    find.ancestor(
      of: find.text('Play'),
      matching: find.bySubtype<ButtonStyleButton>(),
    ),
  );
  button.onPressed?.call();
}

class _FlakyMediaService extends FakeMediaService {
  _FlakyMediaService({required super.detail});

  int _detailCalls = 0;

  @override
  Future<MediaDetail> getMediaDetail(int id, String mediaType) async {
    _detailCalls += 1;
    if (_detailCalls == 1) {
      throw Exception('Transient TMDB failure');
    }
    return super.getMediaDetail(id, mediaType);
  }
}

class _MissingExternalMediaService extends FakeMediaService {
  const _MissingExternalMediaService();

  @override
  Future<MediaDetail> getMediaDetail(int id, String mediaType) async {
    throw Exception('TMDB unavailable');
  }

  @override
  Future<MediaDetail?> findMediaByExternalId(
    String externalId,
    String mediaType,
  ) async {
    throw Exception('External lookup unavailable');
  }
}

class _EmptyMetadataAddonsService extends StremioAddonsService {
  @override
  Future<AddonMetaItem?> fetchMetadata({
    required String mediaType,
    required String id,
  }) async {
    return null;
  }
}

class _FakeMetadataAddonsService extends StremioAddonsService {
  @override
  Future<AddonMetaItem?> fetchMetadata({
    required String mediaType,
    required String id,
  }) async {
    return const AddonMetaItem(
      id: 'tt0903747',
      type: 'series',
      name: 'Addon Show',
      poster: 'https://example.test/poster.jpg',
      background: 'https://example.test/backdrop.jpg',
      logo: 'https://example.test/logo.png',
      description: 'Loaded from Stremio metadata.',
      releaseInfo: '2008',
      runtime: '47 min',
      genres: <String>['Drama'],
      cast: <String>['Bryan Cranston'],
      director: 'Vince Gilligan',
      country: 'United States of America',
      language: 'en',
      status: 'Ended',
      videos: <AddonMetaVideo>[
        AddonMetaVideo(
          id: 'tt0903747:1:1',
          name: 'Pilot',
          seasonNumber: 1,
          episodeNumber: 1,
          overview: 'The first episode.',
          thumbnail: 'https://example.test/episode.jpg',
          released: '2008-01-20',
          runtimeMinutes: 47,
        ),
      ],
      trailers: <AddonMetaTrailer>[
        AddonMetaTrailer(
          name: 'Addon Trailer',
          key: 'addon-trailer',
        ),
      ],
    );
  }
}
