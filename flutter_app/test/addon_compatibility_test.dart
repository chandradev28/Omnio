import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/src/models/torbox_models.dart';
import 'package:flutter_app/src/services/local_json_store.dart';
import 'package:flutter_app/src/services/stremio_addons_service.dart';
import 'package:flutter_app/src/services/tmdb_person_service.dart';

class TestStore extends LocalJsonStore {
  TestStore(this.target) : super('test.json');
  final File target;
  @override
  Future<File> file() async => target;
}

void main() {
  test(
      'required extras preserve choices and search-only catalogs stay off home',
      () {
    final catalog = AddonCatalog.fromJson({
      'id': 'custom',
      'type': 'anime',
      'extra': [
        {
          'name': 'genre',
          'isRequired': true,
          'options': ['Action', 'Drama']
        },
        {'name': 'search', 'isRequired': true},
      ],
    });
    expect(catalog.name, 'custom');
    expect(catalog.canRequest(), isFalse);
    expect(catalog.canRequest(search: true), isTrue);
    expect(AddonCatalog.fromJson(catalog.toJson()).extraOptions['genre'],
        ['Action', 'Drama']);
  });

  test(
      'multiple configured addons load custom catalogs and search independently',
      () async {
    final directory = await Directory.systemTemp.createTemp('omnio-addon-test');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <Uri>[];
    server.listen((request) async {
      requests.add(request.uri);
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path.endsWith('manifest.json')) {
        request.response.write(jsonEncode({
          'id': 'same.provider',
          'name': request.uri.pathSegments.first,
          'version': '1.0.0',
          'resources': ['catalog', 'meta'],
          'types': ['anime'],
          'catalogs': [
            {
              'id': 'popular/list',
              'type': 'anime',
              'extra': [
                {'name': 'search'}
              ]
            },
            {'id': 'broken', 'type': 'anime'},
          ],
        }));
      } else if (request.uri.path.contains('broken')) {
        request.response.statusCode = 500;
        request.response.write('{}');
      } else {
        request.response.write(jsonEncode({
          'metas': [
            {'id': 'bad', 'name': 'Malformed', 'genres': 12},
            for (var i = 0; i < 45; i++)
              {
                'id': 'custom:$i',
                'name': 'Title $i',
                'poster': 'images/$i.jpg'
              },
          ]
        }));
      }
      await request.response.close();
    });
    addTearDown(() async {
      await server.close(force: true);
      await directory.delete(recursive: true);
    });
    final service = StremioAddonsService(
        store: TestStore(File('${directory.path}/addons.json')));
    final base = 'http://127.0.0.1:${server.port}';
    final first = await service.installAddon('$base/one/manifest.json');
    final second = await service.installAddon('$base/two/manifest.json');
    expect(first.id, isNot(second.id));
    await service.installAddon('$base/one/manifest.json');
    expect(await service.getInstalledAddons(), hasLength(2));
    final rows = await service.fetchAllCatalogRows();
    expect(rows, hasLength(2));
    expect(rows.map((row) => row.addonName).toSet(), {'one', 'two'});
    expect(rows.first.items.length, greaterThanOrEqualTo(45));
    expect(rows.first.items.last.poster, '$base/one/images/44.jpg');
    expect(service.catalogErrors, hasLength(2));
    final results = await service.searchCatalogs('A & B/2026');
    expect(results.length, greaterThanOrEqualTo(90));
    final search = requests.last;
    expect(search.pathSegments, contains('popular/list'));
    expect(search.pathSegments.last, 'search=A & B/2026.json');
  });

  test('person filmography merges roles but keeps movie and TV IDs separate',
      () {
    final person = PersonDetail.fromJson({
      'name': 'Actor',
      'biography': 'Biography',
      'combined_credits': {
        'cast': [
          {
            'id': 1,
            'media_type': 'movie',
            'title': 'Movie',
            'character': 'Lead',
            'release_date': '2020-01-01'
          },
          {
            'id': 1,
            'media_type': 'tv',
            'name': 'Show',
            'character': 'Self',
            'first_air_date': '2024-01-01'
          },
        ],
        'crew': [
          {
            'id': 1,
            'media_type': 'movie',
            'title': 'Movie',
            'job': 'Producer',
            'release_date': '2020-01-01'
          }
        ],
      },
    });
    expect(person.credits, hasLength(2));
    expect(person.credits.first.media.mediaType, 'tv');
    expect(person.credits.last.role, 'Lead / Producer');
  });
}
