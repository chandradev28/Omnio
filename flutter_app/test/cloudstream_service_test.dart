import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/src/services/cloudstream_service.dart';
import 'package:flutter_app/src/services/local_json_store.dart';
import 'package:flutter_app/src/models/torbox_models.dart';

class _Store extends LocalJsonStore {
  _Store(this.path) : super('cs.json');
  final String path;
  @override
  Future<File> file() async => File(path);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('normalizes CS links and rejects unsafe/non-repo URLs', () {
    expect(
        CloudstreamService.repositoryUri(
                'cloudstreamrepo://example.com/repo.json')
            .toString(),
        'https://example.com/repo.json');
    for (final url in [
      'http://example.com/repo.json',
      'file:///tmp/plugin',
      'https://user:pass@example.com/repo.json',
      'shortcode'
    ]) {
      expect(
          () => CloudstreamService.repositoryUri(url), throwsFormatException);
    }
  });

  test(
      'loads every plugin list, resolves relative URLs, preserves failure diagnostics',
      () async {
    final service = CloudstreamService(fetch: (uri) async {
      if (uri.path == '/repo.json') {
        return {
          'name': 'Repo',
          'pluginLists': ['one/plugins.json', 'two.json', 'broken.json']
        };
      }
      if (uri.path == '/broken.json') throw const SocketException('offline');
      return [
        {
          'internalName': uri.path,
          'name': 'Provider',
          'url': 'provider.cs3',
          'version': 1
        }
      ];
    });
    final repo = await service.readRepository('https://example.com/repo.json');
    expect(repo['plugins'], hasLength(2));
    expect(repo['plugins'][0]['url'], 'https://example.com/one/provider.cs3');
    expect(repo['warnings'], hasLength(1));
  });

  test('partial refresh keeps prior plugins and deleting repo preserves others',
      () async {
    final dir = await Directory.systemTemp.createTemp('omnio-cs-test');
    addTearDown(() => dir.delete(recursive: true));
    var failed = false;
    final service = CloudstreamService(
        store: _Store('${dir.path}/state.json'),
        fetch: (uri) async {
          if (uri.path.endsWith('repo.json')) {
            return {
              'name': uri.path,
              'pluginLists': ['one.json', 'two.json']
            };
          }
          if (failed && uri.path == '/two.json') {
            throw const SocketException('offline');
          }
          return [
            {'internalName': uri.path, 'url': 'test.cs3', 'version': 1}
          ];
        });
    await service.addRepository('https://one.test/repo.json');
    await service.addRepository('https://two.test/repo.json');
    failed = true;
    await service.addRepository('https://one.test/repo.json');
    expect((await service.state())['repos'].last['plugins'], hasLength(2));
    await service.removeRepository('https://one.test/repo.json');
    expect((await service.state())['repos'], hasLength(1));
    expect((await service.state())['repos'][0]['url'],
        'https://two.test/repo.json');
  });

  test('Stremio manifests are not misreported as Cloudstream repos', () async {
    final service = CloudstreamService(
        fetch: (_) async => {'id': 'stremio', 'catalogs': []});
    await expectLater(
        service.readRepository('https://example.com/manifest.json'),
        throwsFormatException);
  });

  test(
      'native source mapping preserves headers, format, subtitle URLs and provider',
      () async {
    const channel = MethodChannel('test/omnio-cs');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'sources');
      expect(call.arguments['season'], 2);
      return {
        'streams': [
          {
            'id': 'cs:1',
            'provider': 'cloudstream',
            'sourceDisplayName': 'CS / Fixture',
            'title': 'Test',
            'description': '',
            'quality': '1080p',
            'sizeLabel': '',
            'isCached': false,
            'directUrl': 'https://video.test/master',
            'streamFormat': 'M3U8',
            'streamHeaders': {'Referer': 'https://provider.test/'},
            'subtitles': [
              {'name': 'English', 'url': 'https://video.test/en.vtt'}
            ]
          }
        ]
      };
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final data = await CloudstreamService(channel: channel)
        .sources({'season': 2, 'episode': 3});
    final source =
        StreamSource.fromJson(Map<String, dynamic>.from(data['streams'][0]));
    final restored = StreamSource.fromJson(source.toJson());
    expect(restored.streamFormat, 'M3U8');
    expect(restored.streamHeaders['Referer'], 'https://provider.test/');
    expect(restored.subtitles.single['name'], 'English');
    expect(restored.sourceDisplayName, 'CS / Fixture');
  });
}
