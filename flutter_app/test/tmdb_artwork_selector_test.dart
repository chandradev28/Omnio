import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/src/services/tmdb_artwork_selector.dart';

void main() {
  test('selects portrait artwork for poster-shaped frames', () {
    final String? path = selectTmdbArtworkPath(
      <String, dynamic>{
        'posters': <dynamic>[
          <String, dynamic>{
            'file_path': '/wide.jpg',
            'width': 1920,
            'height': 1080,
            'vote_average': 10,
            'vote_count': 100,
          },
          <String, dynamic>{
            'file_path': '/portrait.jpg',
            'width': 1000,
            'height': 1500,
            'vote_average': 8,
            'vote_count': 20,
          },
        ],
      },
      collection: 'posters',
      targetAspectRatio: 2 / 3,
      variantSeed: 0,
      variantPoolSize: 1,
    );

    expect(path, '/portrait.jpg');
  });

  test('selects landscape artwork for backdrop-shaped frames', () {
    final String? path = selectTmdbArtworkPath(
      <String, dynamic>{
        'backdrops': <dynamic>[
          <String, dynamic>{
            'file_path': '/portrait.jpg',
            'width': 1000,
            'height': 1500,
            'vote_average': 10,
            'vote_count': 100,
          },
          <String, dynamic>{
            'file_path': '/wide.jpg',
            'width': 1920,
            'height': 1080,
            'vote_average': 8,
            'vote_count': 20,
          },
        ],
      },
      collection: 'backdrops',
      targetAspectRatio: 16 / 9,
      variantSeed: 0,
      variantPoolSize: 1,
    );

    expect(path, '/wide.jpg');
  });
}
