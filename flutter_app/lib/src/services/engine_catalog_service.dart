import 'dart:convert';
import 'dart:io';

import '../models/engine_models.dart';
import 'engine_yaml_parser.dart';

class EngineCatalogService {
  EngineCatalogService({
    EngineYamlParser? parser,
  }) : _parser = parser ?? const EngineYamlParser();

  static const String _metadataUrl =
      'https://gitlab.com/mediacontent/search-engines/-/raw/main/torrents/metadata.yaml';
  static const String _rawBaseUrl =
      'https://gitlab.com/mediacontent/search-engines/-/raw/main/torrents';

  final EngineYamlParser _parser;
  List<RemoteEngineInfo>? _cache;

  Future<List<RemoteEngineInfo>> fetchCatalog({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cache != null) {
      return _cache!;
    }

    final String metadataYaml = await _getString(Uri.parse(_metadataUrl));
    final ParsedEngineConfig metadataDoc = _parser.parse(
      metadataYaml,
      fileName: 'metadata.yaml',
    );
    final List<dynamic> engines =
        (metadataDoc.document['engines'] as List<dynamic>? ?? const <dynamic>[])
            .toList(growable: false);

    final List<RemoteEngineInfo> catalog = <RemoteEngineInfo>[];
    for (final dynamic row in engines) {
      final Map<String, dynamic> item = row as Map<String, dynamic>;
      final String path = item['path'] as String? ?? '';
      final String fileName = path.split('/').last;
      if (fileName.isEmpty) {
        continue;
      }

      try {
        final String yaml = await downloadEngineYaml(fileName);
        final ParsedEngineConfig engine = _parser.parse(
          yaml,
          fileName: fileName,
        );
        catalog.add(engine.toRemoteInfo(fileName));
      } catch (_) {
        catalog.add(
          RemoteEngineInfo(
            id: fileName.replaceAll('.yaml', ''),
            fileName: fileName,
            displayName:
                (item['name'] as String?) ?? fileName.replaceAll('.yaml', ''),
          ),
        );
      }
    }

    _cache = catalog;
    return catalog;
  }

  Future<String> downloadEngineYaml(String fileName) {
    return _getString(Uri.parse('$_rawBaseUrl/$fileName'));
  }

  Future<String> _getString(Uri uri) async {
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final HttpClientRequest request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'text/plain');
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 Omnio/1.0',
      );
      final HttpClientResponse response = await request.close();
      final String raw = await response.transform(utf8.decoder).join();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Engine catalog request failed with status ${response.statusCode}',
          uri: uri,
        );
      }
      return raw;
    } finally {
      client.close(force: true);
    }
  }
}
