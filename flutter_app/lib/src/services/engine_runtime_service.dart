import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:xml/xml.dart';

import '../models/engine_models.dart';
import '../models/torbox_models.dart';
import 'engine_catalog_service.dart';
import 'engine_storage_service.dart';
import 'engine_yaml_parser.dart';
import 'real_debrid_api_service.dart';
import 'torbox_api_service.dart';

typedef EngineRequestExecutor = Future<String> Function(EngineRequestSpec spec);

class EngineRuntimeService {
  EngineRuntimeService({
    EngineCatalogService? catalogService,
    EngineStorageService? storageService,
    EngineYamlParser? yamlParser,
    EngineRequestExecutor? requestExecutor,
    TorBoxApiService? torBoxApiService,
    RealDebridApiService? realDebridApiService,
  })  : _catalogService = catalogService ?? EngineCatalogService(),
        _storageService = storageService ?? EngineStorageService(),
        _yamlParser = yamlParser ?? const EngineYamlParser(),
        _requestExecutor = requestExecutor,
        _torBoxApiService = torBoxApiService ?? TorBoxApiService(),
        _realDebridApiService = realDebridApiService ?? RealDebridApiService();

  static const Set<String> _recommendedIds = <String>{
    'torrents_csv',
    'pirate_bay',
    'solid_torrents',
    'yts',
    'knaben',
    'therarbg',
    'nyaa',
  };

  final EngineCatalogService _catalogService;
  final EngineStorageService _storageService;
  final EngineYamlParser _yamlParser;
  final EngineRequestExecutor? _requestExecutor;
  final TorBoxApiService _torBoxApiService;
  final RealDebridApiService _realDebridApiService;

  Future<List<RemoteEngineInfo>> getCatalog({bool forceRefresh = false}) {
    return _catalogService.fetchCatalog(forceRefresh: forceRefresh);
  }

  Future<List<ImportedEngine>> getImportedEngines() {
    return _storageService.getImportedEngines();
  }

  Future<void> importEngine(RemoteEngineInfo engine) async {
    final String yaml =
        await _catalogService.downloadEngineYaml(engine.fileName);
    final ParsedEngineConfig parsed = _yamlParser.parse(
      yaml,
      fileName: engine.fileName,
    );
    await _storageService.saveImportedEngine(
      engine: parsed.toImportedEngine(engine.fileName),
      yamlContent: yaml,
    );
  }

  Future<int> importRecommendedEngines() async {
    final List<RemoteEngineInfo> catalog = await getCatalog();
    final List<ImportedEngine> imported = await getImportedEngines();
    final Set<String> importedIds =
        imported.map((ImportedEngine item) => item.id).toSet();
    int added = 0;

    for (final RemoteEngineInfo engine in catalog) {
      if (!_recommendedIds.contains(engine.id) ||
          importedIds.contains(engine.id)) {
        continue;
      }
      if (!engine.keywordSearch || !engine.supportedInApp) {
        continue;
      }
      await importEngine(engine);
      added += 1;
    }

    return added;
  }

  Future<void> setEnabled(String engineId, bool enabled) async {
    final List<ImportedEngine> engines = await getImportedEngines();
    final ImportedEngine target = engines.firstWhere(
      (ImportedEngine item) => item.id == engineId,
    );
    await _storageService
        .updateImportedEngine(target.copyWith(enabled: enabled));
  }

  Future<void> setMaxResults(String engineId, int maxResults) async {
    final List<ImportedEngine> engines = await getImportedEngines();
    final ImportedEngine target = engines.firstWhere(
      (ImportedEngine item) => item.id == engineId,
    );
    await _storageService.updateImportedEngine(
      target.copyWith(maxResults: maxResults),
    );
  }

  Future<void> deleteEngine(String engineId) {
    return _storageService.deleteImportedEngine(engineId);
  }

  Future<KeywordEngineSearchResult> searchKeyword(String query) async {
    final String trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const KeywordEngineSearchResult(
        streams: <StreamSource>[],
        diagnostics: SourceSearchDiagnostics(),
      );
    }

    final List<ImportedEngine> engines = await getImportedEngines();
    final List<ImportedEngine> active = engines
        .where((ImportedEngine item) => item.enabled)
        .toList(growable: false);

    if (active.isEmpty) {
      return const KeywordEngineSearchResult(
        streams: <StreamSource>[],
        diagnostics: SourceSearchDiagnostics(
          sourceErrors: <String, String>{
            'Engines': 'Import and enable at least one engine first.',
          },
        ),
      );
    }

    final Map<String, int> counts = <String, int>{};
    final Map<String, String> errors = <String, String>{};
    final List<StreamSource> merged = <StreamSource>[];
    final Set<String> seen = <String>{};

    for (final ImportedEngine engine in active) {
      if (!engine.keywordSearch) {
        counts[engine.displayName] = 0;
        errors[engine.displayName] =
            'Keyword search is not supported by this engine.';
        continue;
      }
      if (!engine.supportedInApp) {
        counts[engine.displayName] = 0;
        errors[engine.displayName] =
            'This engine format is not wired into the Flutter runtime yet.';
        continue;
      }

      try {
        final String? yaml = await _storageService.readEngineYaml(engine.id);
        if (yaml == null) {
          throw const HttpException('Missing local engine file.');
        }
        final ParsedEngineConfig parsed = _yamlParser.parse(
          yaml,
          fileName: engine.fileName,
        );
        final List<StreamSource> engineResults = await _searchEngine(
          parsed: parsed,
          engine: engine,
          query: trimmed,
        );
        counts[engine.displayName] = engineResults.length;
        for (final StreamSource item in engineResults) {
          final String key = item.infoHash?.toLowerCase() ?? item.id;
          if (seen.add(key)) {
            merged.add(item);
          }
        }
      } catch (error) {
        counts[engine.displayName] = 0;
        errors[engine.displayName] = _friendlyError(error);
      }
    }

    merged.sort((StreamSource a, StreamSource b) {
      final int sizeCompare =
          (b.videoSizeBytes ?? 0).compareTo(a.videoSizeBytes ?? 0);
      if (sizeCompare != 0) {
        return sizeCompare;
      }
      return a.sourceDisplayName.compareTo(b.sourceDisplayName);
    });

    return KeywordEngineSearchResult(
      streams: merged,
      diagnostics: SourceSearchDiagnostics(
        sourceCounts: counts,
        sourceErrors: errors,
      ),
    );
  }

  Future<KeywordEngineSearchResult> searchCachedKeyword(String query) async {
    await ensureRecommendedEnginesAvailable();
    final KeywordEngineSearchResult raw = await searchKeyword(query);
    final List<String> hashes = raw.streams
        .map((StreamSource source) => source.infoHash)
        .whereType<String>()
        .where((String hash) => RegExp(r'^[a-f0-9]{40}$').hasMatch(hash))
        .toSet()
        .toList(growable: false);
    if (hashes.isEmpty) {
      return KeywordEngineSearchResult(
        streams: const <StreamSource>[],
        diagnostics: SourceSearchDiagnostics(
          sourceCounts: raw.diagnostics.sourceCounts,
          sourceErrors: <String, String>{
            ...raw.diagnostics.sourceErrors,
            if (raw.streams.isNotEmpty)
              'TorBox cache': 'No valid torrent hashes were found to check.',
          },
        ),
      );
    }

    final Map<String, bool> torBoxCached =
        await _checkTorBoxCachedSafely(hashes);
    final Map<String, bool> realDebridCached =
        await _checkRealDebridCachedSafely(hashes);
    final List<StreamSource> cachedStreams = raw.streams
        .map(
          (StreamSource source) => _markCachedProviders(
            source,
            torBoxCached[source.infoHash] == true,
            realDebridCached[source.infoHash] == true,
          ),
        )
        .where((StreamSource source) => source.isCached)
        .toList(growable: false);
    return KeywordEngineSearchResult(
      streams: cachedStreams,
      diagnostics: SourceSearchDiagnostics(
        sourceCounts: <String, int>{
          ...raw.diagnostics.sourceCounts,
          'Cached engines': cachedStreams.length,
        },
        sourceErrors: raw.diagnostics.sourceErrors,
      ),
    );
  }

  Future<void> ensureRecommendedEnginesAvailable() async {
    final List<ImportedEngine> imported = await getImportedEngines();
    final bool hasEnabledKeywordEngine = imported.any(
      (ImportedEngine engine) =>
          engine.enabled && engine.keywordSearch && engine.supportedInApp,
    );
    if (hasEnabledKeywordEngine) {
      return;
    }

    await importRecommendedEngines();
  }

  Future<Map<String, bool>> _checkTorBoxCachedSafely(
      List<String> hashes) async {
    try {
      if (!await _torBoxApiService.isConfigured()) {
        return const <String, bool>{};
      }
      return _torBoxApiService.checkCached(hashes);
    } catch (_) {
      return const <String, bool>{};
    }
  }

  Future<Map<String, bool>> _checkRealDebridCachedSafely(
      List<String> hashes) async {
    try {
      if (!await _realDebridApiService.isConfigured()) {
        return const <String, bool>{};
      }
      return _realDebridApiService.checkCached(hashes);
    } catch (_) {
      return const <String, bool>{};
    }
  }

  StreamSource _markCachedProviders(
    StreamSource source,
    bool torBoxCached,
    bool realDebridCached,
  ) {
    final List<String> labels = <String>[
      if (torBoxCached) 'TB+',
      if (realDebridCached) 'RD+',
    ];
    return StreamSource(
      id: source.id,
      provider: source.provider,
      sourceDisplayName: source.sourceDisplayName,
      title: source.title,
      description: source.description,
      quality: source.quality,
      sizeLabel: source.sizeLabel,
      isCached: labels.isNotEmpty,
      cacheProvider: labels.isEmpty ? source.cacheProvider : labels.join(' / '),
      addonId: source.addonId,
      infoHash: source.infoHash,
      directUrl: source.directUrl,
      fileIndex: source.fileIndex,
      fileName: source.fileName,
      videoSizeBytes: source.videoSizeBytes,
      magnetUri: source.magnetUri,
      sourceTrackers: source.sourceTrackers,
      streamHeaders: source.streamHeaders,
    );
  }

  Future<List<StreamSource>> _searchEngine({
    required ParsedEngineConfig parsed,
    required ImportedEngine engine,
    required String query,
  }) async {
    final Map<String, dynamic> document = parsed.document;
    final Map<String, dynamic> pagination = _asMap(document['pagination']);
    final String paginationType =
        (pagination['type'] as String? ?? 'none').trim();
    final int pageSize = (pagination['results_per_page'] as num?)?.toInt() ??
        (pagination['page_size'] as num?)?.toInt() ??
        min(engine.maxResults, 50);
    final int maxPages = max(
      1,
      (pagination['max_pages'] as num?)?.toInt() ??
          ((engine.maxResults / max(pageSize, 1)).ceil()),
    );
    final List<StreamSource> results = <StreamSource>[];
    String? cursor;

    for (int pageIndex = 0; pageIndex < maxPages; pageIndex += 1) {
      final EngineRequestSpec requestSpec = _buildRequestSpec(
        document: document,
        query: query,
        pageIndex: pageIndex,
        pageSize: pageSize,
        cursor: cursor,
      );

      final String raw = await (_requestExecutor?.call(requestSpec) ??
          _performRequest(requestSpec));
      final dynamic payload = _parseResponse(
        raw,
        parsed.responseFormat,
      );
      _runPreChecks(document, payload);
      if (_isExplicitlyEmpty(document, payload)) {
        break;
      }

      final List<Map<String, dynamic>> rows = _extractRows(
        document: document,
        payload: payload,
      );
      final List<StreamSource> mapped = rows
          .map(
            (Map<String, dynamic> row) => _mapRowToSource(
              engine: engine,
              document: document,
              row: row,
            ),
          )
          .whereType<StreamSource>()
          .toList(growable: false);
      results.addAll(mapped);

      if (results.length >= engine.maxResults) {
        break;
      }

      if (paginationType == 'cursor') {
        final String? nextCursor = _readPath(
          payload,
          (pagination['cursor_field'] as String?) ??
              (_asMap(pagination['cursor'])['response_field'] as String?) ??
              '',
        )?.toString();
        if (nextCursor == null || nextCursor.isEmpty || nextCursor == cursor) {
          break;
        }
        cursor = nextCursor;
        continue;
      }

      if (paginationType == 'page') {
        final String? field =
            (_asMap(pagination['page'])['has_more_field'] as String?) ??
                (pagination['has_more_field'] as String?);
        if ((field ?? '').isNotEmpty) {
          final dynamic hasMore = _readPath(payload, field!);
          if (hasMore is bool && !hasMore) {
            break;
          }
          if (hasMore == null) {
            break;
          }
        } else if (mapped.length < pageSize) {
          break;
        }
        continue;
      }

      if (paginationType == 'offset') {
        if (mapped.length < pageSize) {
          break;
        }
        continue;
      }

      break;
    }

    if (results.length > engine.maxResults) {
      return results.take(engine.maxResults).toList(growable: false);
    }
    return results;
  }

  EngineRequestSpec _buildRequestSpec({
    required Map<String, dynamic> document,
    required String query,
    required int pageIndex,
    required int pageSize,
    required String? cursor,
  }) {
    final Map<String, dynamic> api = _asMap(document['api']);
    final Map<String, dynamic> urls = _asMap(api['urls']);
    final Map<String, dynamic> queryParams = _asMap(document['query_params']);
    final Map<String, dynamic> pagination = _asMap(document['pagination']);
    final List<dynamic> params = document['api'] is Map<String, dynamic>
        ? (_asMap(document['api'])['params'] as List<dynamic>? ??
            const <dynamic>[])
        : const <dynamic>[];
    final Map<String, dynamic> extraParams =
        _asMap(_asMap(document['extra_params'])['keyword']);

    final String method =
        (api['method'] as String? ?? 'GET').toUpperCase().trim();
    String baseUrl =
        (urls['keyword'] as String?) ?? (api['base_url'] as String?) ?? '';
    if (baseUrl.isEmpty) {
      throw const HttpException('Engine is missing a keyword URL.');
    }

    baseUrl = baseUrl
        .replaceAll('{query}', Uri.encodeComponent(query))
        .replaceAll('{imdb_id}', Uri.encodeComponent(query));

    final Map<String, dynamic> queryMap = <String, dynamic>{};
    final Map<String, dynamic> bodyMap = <String, dynamic>{};
    queryMap.addAll(extraParams);

    for (final dynamic row in params) {
      final Map<String, dynamic> param = _asMap(row);
      final String name = param['name'] as String? ?? '';
      if (name.isEmpty) {
        continue;
      }
      final String location = (param['location'] as String? ?? 'query').trim();
      final dynamic value = param.containsKey('source') &&
              (param['source'] as String?) == 'query'
          ? query
          : _coerceParamValue(param['value'], param['value_type'] as String?);
      if (location == 'body') {
        bodyMap[name] = value;
      } else {
        queryMap[name] = value;
      }
    }

    final dynamic paramName = queryParams['param_name'];
    final String? effectiveQueryParam = paramName is String
        ? paramName
        : _asMap(paramName)['keyword'] as String?;
    if (effectiveQueryParam != null &&
        effectiveQueryParam.isNotEmpty &&
        !baseUrl.contains('{query}') &&
        !queryMap.containsKey(effectiveQueryParam) &&
        !bodyMap.containsKey(effectiveQueryParam)) {
      if (method == 'POST') {
        bodyMap[effectiveQueryParam] = query;
      } else {
        queryMap[effectiveQueryParam] = query;
      }
    }

    final String paginationType =
        (pagination['type'] as String? ?? 'none').trim();
    if (paginationType == 'cursor') {
      if (cursor != null && cursor.isNotEmpty) {
        final String cursorParam = (pagination['cursor_param'] as String?) ??
            (_asMap(pagination['cursor'])['param_name'] as String?) ??
            'after';
        queryMap[cursorParam] = cursor;
      }
      if (!queryMap.containsKey('size')) {
        queryMap['size'] = pageSize;
      }
    } else if (paginationType == 'page') {
      final Map<String, dynamic> page = _asMap(pagination['page']);
      final String paramName = (page['param_name'] as String?) ??
          (pagination['page_param'] as String?) ??
          'page';
      final int startPage = (page['start_page'] as num?)?.toInt() ??
          (pagination['start_page'] as num?)?.toInt() ??
          1;
      final int pageNumber = startPage + pageIndex;
      final String location = (page['location'] as String? ?? 'query').trim();
      if (location == 'path') {
        baseUrl = baseUrl.replaceAll('{$paramName}', '$pageNumber');
      } else if (method == 'POST') {
        bodyMap[paramName] = pageNumber;
      } else {
        queryMap[paramName] = pageNumber;
      }
    } else if (paginationType == 'offset') {
      final Map<String, dynamic> offset = _asMap(pagination['offset']);
      final String paramName = (offset['param_name'] as String?) ??
          (pagination['offset_param'] as String?) ??
          'offset';
      final int startOffset = (offset['start_offset'] as num?)?.toInt() ??
          (pagination['start_offset'] as num?)?.toInt() ??
          0;
      final int offsetValue = startOffset + (pageIndex * pageSize);
      final String location = (offset['location'] as String? ?? 'query').trim();
      if (location == 'body' || method == 'POST') {
        bodyMap[paramName] = offsetValue;
      } else {
        queryMap[paramName] = offsetValue;
      }
    }

    final Uri uri = Uri.parse(baseUrl).replace(
      queryParameters: <String, String>{
        for (final MapEntry<String, dynamic> entry in queryMap.entries)
          entry.key: entry.value.toString(),
      }.isEmpty
          ? null
          : <String, String>{
              for (final MapEntry<String, dynamic> entry in queryMap.entries)
                entry.key: entry.value.toString(),
            },
    );

    return EngineRequestSpec(
      method: method,
      uri: uri,
      body: bodyMap.isEmpty ? null : jsonEncode(bodyMap),
    );
  }

  Future<String> _performRequest(EngineRequestSpec spec) async {
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final HttpClientRequest request = spec.method == 'POST'
          ? await client.postUrl(spec.uri)
          : await client.getUrl(spec.uri);
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/json, application/rss+xml, application/xml, text/xml, */*',
      );
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 Omnio/1.0',
      );
      if (spec.body != null) {
        request.headers.contentType = ContentType.json;
        request.write(spec.body);
      }

      final HttpClientResponse response = await request.close();
      final String raw = await response.transform(utf8.decoder).join();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Request failed with status ${response.statusCode}',
          uri: spec.uri,
        );
      }
      return raw;
    } finally {
      client.close(force: true);
    }
  }

  dynamic _parseResponse(String raw, String responseFormat) {
    switch (responseFormat) {
      case 'direct_json':
      case 'json':
        return jsonDecode(raw);
      case 'jina_wrapped':
        final String extracted = _extractJson(raw);
        return jsonDecode(extracted);
      case 'rss':
        return _parseRss(raw);
      default:
        throw UnsupportedError('Unsupported response format: $responseFormat');
    }
  }

  String _extractJson(String raw) {
    final int objectStart = raw.indexOf('{');
    final int arrayStart = raw.indexOf('[');
    if (objectStart == -1 && arrayStart == -1) {
      throw const FormatException(
          'Could not extract JSON from wrapped response.');
    }

    final bool useArray =
        arrayStart != -1 && (objectStart == -1 || arrayStart < objectStart);
    final int start = useArray ? arrayStart : objectStart;
    final int end = useArray ? raw.lastIndexOf(']') : raw.lastIndexOf('}');
    if (end <= start) {
      throw const FormatException(
          'Wrapped response did not contain valid JSON.');
    }
    return raw.substring(start, end + 1);
  }

  Map<String, dynamic> _parseRss(String raw) {
    final XmlDocument document = XmlDocument.parse(raw);
    final Map<String, dynamic> root = _xmlElementToMap(document.rootElement);
    final dynamic unwrapped = root[document.rootElement.name.local];
    return unwrapped is Map<String, dynamic>
        ? unwrapped
        : <String, dynamic>{document.rootElement.name.local: unwrapped};
  }

  Map<String, dynamic> _xmlElementToMap(XmlElement element) {
    final Iterable<XmlElement> childElements = element.childElements;
    if (childElements.isEmpty) {
      return <String, dynamic>{element.name.local: _xmlTextValue(element)};
    }

    final Map<String, dynamic> grouped = <String, dynamic>{};
    for (final XmlElement child in childElements) {
      final String key = child.name.local;
      final dynamic value = child.childElements.isEmpty
          ? _xmlTextValue(child)
          : _xmlElementToMap(child)[key];

      if (!grouped.containsKey(key)) {
        grouped[key] = value;
      } else if (grouped[key] is List<dynamic>) {
        (grouped[key] as List<dynamic>).add(value);
      } else {
        grouped[key] = <dynamic>[grouped[key], value];
      }
    }

    if (element.name.local == 'item') {
      return <String, dynamic>{element.name.local: _normalizeRssItem(grouped)};
    }
    return <String, dynamic>{element.name.local: grouped};
  }

  Map<String, dynamic> _normalizeRssItem(Map<String, dynamic> item) {
    final Map<String, dynamic> normalized = Map<String, dynamic>.from(item);
    final String sizeText = (normalized['size'] as String?)?.trim() ?? '';
    if (sizeText.isNotEmpty) {
      normalized['size_bytes'] = _parseHumanReadableSize(sizeText);
    }
    return normalized;
  }

  String _xmlTextValue(XmlElement element) {
    return element.innerText.trim();
  }

  void _runPreChecks(Map<String, dynamic> document, dynamic payload) {
    final List<dynamic> checks =
        _asMap(document['response_format'])['pre_checks'] as List<dynamic>? ??
            document['pre_checks'] as List<dynamic>? ??
            const <dynamic>[];
    for (final dynamic row in checks) {
      final Map<String, dynamic> check = _asMap(row);
      final String field = check['field'] as String? ?? '';
      if (field.isEmpty) {
        continue;
      }
      final dynamic actual = _readPath(payload, field);
      if (check.containsKey('equals') && actual != check['equals']) {
        throw HttpException('Engine response check failed for "$field".');
      }
    }
  }

  bool _isExplicitlyEmpty(Map<String, dynamic> document, dynamic payload) {
    final Map<String, dynamic> emptyCheck = _asMap(document['empty_check']);
    if (emptyCheck.isEmpty) {
      return false;
    }
    final String field = emptyCheck['field'] as String? ?? '';
    if (field.isEmpty) {
      return false;
    }
    return _readPath(payload, field) == emptyCheck['equals'];
  }

  List<Map<String, dynamic>> _extractRows({
    required Map<String, dynamic> document,
    required dynamic payload,
  }) {
    final Map<String, dynamic> response = _asMap(document['response_format']);
    dynamic resultsPath = response['results_path'];
    if (resultsPath is Map<String, dynamic>) {
      resultsPath = resultsPath['keyword'];
    }
    final String? resultsPathString = resultsPath as String?;
    final dynamic base =
        resultsPathString == null || resultsPathString.trim() == r'$'
            ? payload
            : _readPath(payload, resultsPathString);
    final List<dynamic> rows = base is List<dynamic>
        ? base
        : base == null
            ? const <dynamic>[]
            : <dynamic>[base];

    final Map<String, dynamic> nested = _asMap(response['nested_results']);
    if (nested['enabled'] != true) {
      return rows.map((dynamic row) => _asMap(row)).toList(growable: false);
    }

    final String itemsField = nested['items_field'] as String? ?? '';
    final List<dynamic> parentFields =
        nested['parent_fields'] as List<dynamic>? ?? const <dynamic>[];
    final List<Map<String, dynamic>> flattened = <Map<String, dynamic>>[];

    for (final dynamic row in rows) {
      final Map<String, dynamic> parent = _asMap(row);
      final Map<String, dynamic> parentData = <String, dynamic>{};
      for (final dynamic fieldRow in parentFields) {
        final Map<String, dynamic> field = _asMap(fieldRow);
        final String name = field['name'] as String? ?? '';
        if (name.isEmpty) {
          continue;
        }
        dynamic value = _readPath(parent, field['source'] as String? ?? '');
        if ((value == null || '$value'.isEmpty) && field['fallback'] != null) {
          value = _readPath(parent, field['fallback'] as String);
        }
        if (field['type'] == 'join_comma' && value is List<dynamic>) {
          value = value.join(', ');
        }
        parentData[name] = value;
      }

      final List<dynamic> nestedItems =
          _readPath(parent, itemsField) as List<dynamic>? ?? const <dynamic>[];
      for (final dynamic nestedRow in nestedItems) {
        flattened.add(<String, dynamic>{
          ..._asMap(nestedRow),
          ...parentData,
        });
      }
    }

    return flattened;
  }

  StreamSource? _mapRowToSource({
    required ImportedEngine engine,
    required Map<String, dynamic> document,
    required Map<String, dynamic> row,
  }) {
    final Map<String, dynamic> fieldMappings =
        _asMap(document['field_mappings']);
    final Map<String, dynamic> specialParsers =
        _asMap(document['special_parsers']);
    final Map<String, dynamic> values = <String, dynamic>{};

    fieldMappings.forEach((String key, dynamic config) {
      values[key] = _resolveMappedValue(row, config);
    });
    specialParsers.forEach((String key, dynamic config) {
      values[key] = _runSpecialParser(row, _asMap(config));
    });

    final String title = (values['name']?.toString().trim() ?? '').isEmpty
        ? 'Unknown torrent'
        : values['name'].toString().trim();
    final String infoHash =
        (values['infohash']?.toString().trim() ?? '').toLowerCase();
    final int sizeBytes = _toInt(values['size_bytes']);
    final int seeders = _toInt(values['seeders']);
    final int leechers = _toInt(values['leechers']);
    final String category = values['category']?.toString() ?? '';

    return StreamSource(
      id: '${engine.id}:${infoHash.isEmpty ? title : infoHash}',
      provider: 'engine',
      sourceDisplayName: engine.displayName,
      title: title,
      description: _buildDescription(
        seeders: seeders,
        leechers: leechers,
        category: category,
      ),
      quality: _extractQuality(title),
      sizeLabel: _formatBytes(sizeBytes),
      isCached: false,
      infoHash: infoHash.isEmpty ? null : infoHash,
      videoSizeBytes: sizeBytes > 0 ? sizeBytes : null,
      magnetUri: infoHash.isEmpty ? null : 'magnet:?xt=urn:btih:$infoHash',
    );
  }

  dynamic _resolveMappedValue(Map<String, dynamic> row, dynamic config) {
    if (config is String) {
      return _readPath(row, config);
    }

    final Map<String, dynamic> map = _asMap(config);
    final String type = (map['type'] as String? ?? 'direct').trim();
    if (type == 'template') {
      return _applyTemplate(map['template'] as String? ?? '', row);
    }

    dynamic value = _readPath(row, map['source'] as String? ?? '');
    final dynamic conversion = map['conversion'];
    if (conversion != null) {
      value = _applyConversion(value, conversion);
    }
    return value;
  }

  dynamic _runSpecialParser(
      Map<String, dynamic> row, Map<String, dynamic> config) {
    final String sourceField =
        config['source'] as String? ?? config['source_field'] as String? ?? '';
    final String sourceValue = _readPath(row, sourceField)?.toString() ?? '';
    final RegExp regex = RegExp(
      config['pattern'] as String? ?? '',
      caseSensitive: false,
    );
    final RegExpMatch? match = regex.firstMatch(sourceValue);
    if (match == null) {
      return config['default_value'];
    }

    final int captureGroup = (config['capture_group'] as num?)?.toInt() ?? 1;
    final String raw = match.group(captureGroup) ?? '';
    final String parserType =
        (config['parser_type'] as String?) ?? (config['type'] as String?) ?? '';
    if (parserType == 'size_with_unit') {
      final String unit = match.group(captureGroup + 1) ?? '';
      return _parseSizeWithUnit(raw, unit);
    }
    final dynamic conversion = config['conversion'];
    return conversion == null ? raw : _applyConversion(raw, conversion);
  }

  dynamic _applyConversion(dynamic value, dynamic conversion) {
    if (conversion is String) {
      switch (conversion) {
        case 'string_to_int':
          return _toInt(value);
        case 'lowercase':
          return value?.toString().toLowerCase();
        case 'uppercase':
          return value?.toString().toUpperCase();
        default:
          return value;
      }
    }

    final Map<String, dynamic> map = _asMap(conversion);
    if (map['type'] == 'replace') {
      return value?.toString().replaceAll(
          map['find'] as String? ?? '', map['replace'] as String? ?? '');
    }
    return value;
  }

  String _applyTemplate(String template, Map<String, dynamic> row) {
    return template.replaceAllMapped(RegExp(r'\{([^}]+)\}'), (Match match) {
      final String key = match.group(1) ?? '';
      final dynamic value = row[key];
      return value == null ? '' : value.toString();
    }).trim();
  }

  dynamic _readPath(dynamic root, String path) {
    if (path.isEmpty) {
      return root;
    }
    if (path == r'$') {
      return root;
    }

    dynamic current = root;
    for (final String token in _tokenizePath(path)) {
      if (current == null) {
        return null;
      }
      if (token.startsWith('[') && token.endsWith(']')) {
        final int? index = int.tryParse(token.substring(1, token.length - 1));
        if (index == null ||
            current is! List<dynamic> ||
            index >= current.length) {
          return null;
        }
        current = current[index];
        continue;
      }

      if (current is Map<String, dynamic>) {
        current = current[token];
      } else {
        return null;
      }
    }
    return current;
  }

  List<String> _tokenizePath(String path) {
    final List<String> tokens = <String>[];
    final StringBuffer current = StringBuffer();
    for (int i = 0; i < path.length; i += 1) {
      final String char = path[i];
      if (char == '.') {
        if (current.isNotEmpty) {
          tokens.add(current.toString());
          current.clear();
        }
        continue;
      }
      if (char == '[') {
        if (current.isNotEmpty) {
          tokens.add(current.toString());
          current.clear();
        }
        final int end = path.indexOf(']', i);
        if (end == -1) {
          break;
        }
        tokens.add(path.substring(i, end + 1));
        i = end;
        continue;
      }
      current.write(char);
    }
    if (current.isNotEmpty) {
      tokens.add(current.toString());
    }
    return tokens;
  }

  dynamic _coerceParamValue(dynamic value, String? valueType) {
    if (valueType == 'int') {
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }
    if (valueType == 'bool') {
      return value.toString().toLowerCase() == 'true';
    }
    return value;
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _parseSizeWithUnit(String amountRaw, String unitRaw) {
    final double amount = double.tryParse(amountRaw) ?? 0;
    const Map<String, int> factors = <String, int>{
      'KB': 1,
      'MB': 2,
      'GB': 3,
      'TB': 4,
    };
    final int exponent = factors[unitRaw.toUpperCase()] ?? 0;
    return (amount * pow(1024, exponent)).round();
  }

  int _parseHumanReadableSize(String raw) {
    final RegExpMatch? match = RegExp(
      r'([\d.]+)\s*(B|KB|KIB|MB|MIB|GB|GIB|TB|TIB)',
      caseSensitive: false,
    ).firstMatch(raw);
    if (match == null) {
      return 0;
    }
    final String unit =
        (match.group(2) ?? 'B').toUpperCase().replaceAll('IB', 'B');
    return _parseSizeWithUnit(match.group(1) ?? '0', unit);
  }

  String _buildDescription({
    required int seeders,
    required int leechers,
    required String category,
  }) {
    final List<String> parts = <String>[
      'Seeders $seeders',
      'Leechers $leechers',
    ];
    if (category.trim().isNotEmpty) {
      parts.add(category.trim());
    }
    return parts.join(' | ');
  }

  String _extractQuality(String text) {
    final RegExpMatch? match = RegExp(
      r'(2160p|4k|1080p|720p|480p)',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) {
      return 'Unknown';
    }
    final String value = match.group(1)!.toUpperCase();
    return value == '2160P' ? '4K' : value;
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) {
      return '';
    }
    const List<String> sizes = <String>['B', 'KB', 'MB', 'GB', 'TB'];
    double value = bytes.toDouble();
    int index = 0;
    while (value >= 1024 && index < sizes.length - 1) {
      value /= 1024;
      index += 1;
    }
    final int decimals = value >= 10 || index == 0 ? 0 : 1;
    return '${value.toStringAsFixed(decimals)} ${sizes[index]}';
  }

  String _friendlyError(Object error) {
    final String message = error.toString();
    if (message.startsWith('HttpException: ')) {
      return message.replaceFirst('HttpException: ', '');
    }
    return message;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map<dynamic, dynamic>) {
      return value.map(
        (dynamic key, dynamic item) => MapEntry(key.toString(), item),
      );
    }
    return <String, dynamic>{};
  }
}

class KeywordEngineSearchResult {
  const KeywordEngineSearchResult({
    required this.streams,
    required this.diagnostics,
  });

  final List<StreamSource> streams;
  final SourceSearchDiagnostics diagnostics;
}

class EngineRequestSpec {
  const EngineRequestSpec({
    required this.method,
    required this.uri,
    this.body,
  });

  final String method;
  final Uri uri;
  final String? body;
}
