import 'dart:convert';
import 'dart:io';

import '../models/search_result.dart';
import '../models/torbox_models.dart';
import 'local_json_store.dart';

class StremioAddonsService {
  StremioAddonsService({
    LocalJsonStore? store,
  }) : _store =
            store ?? const LocalJsonStore('.streamed_installed_addons.json');

  final LocalJsonStore _store;

  Future<List<AddonManifest>> getInstalledAddons() async {
    final File file = await _store.file();
    if (!await file.exists()) {
      return const <AddonManifest>[];
    }

    try {
      final String raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return const <AddonManifest>[];
      }

      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map(
            (dynamic item) => AddonManifest.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const <AddonManifest>[];
    }
  }

  Future<bool> hasStreamAddons() async {
    final List<AddonManifest> addons = await getInstalledAddons();
    return addons.any(
      (AddonManifest addon) => addon.enabled && addon.hasStreamResource,
    );
  }

  Future<List<AddonManifest>> getEnabledAddons() async {
    final List<AddonManifest> addons = await getInstalledAddons();
    return addons
        .where((AddonManifest addon) => addon.enabled)
        .toList(growable: false);
  }

  Future<AddonManifest> installAddon(String manifestUrl) async {
    final Uri manifestUri = _normalizeManifestUri(manifestUrl);
    final Map<String, dynamic> payload = await _fetchJson(manifestUri);

    final AddonManifest addon = AddonManifest.fromJson(
      <String, dynamic>{
        ...payload,
        'id':
            (payload['id'] as String?) ?? _makeAddonId(manifestUri.toString()),
        'url': _stripManifestPath(manifestUri)
            .toString()
            .replaceAll(RegExp(r'/$'), ''),
        'originalUrl': manifestUri.toString(),
      },
    );

    final List<AddonManifest> installed = await getInstalledAddons();
    final Map<String, AddonManifest> byId = <String, AddonManifest>{
      for (final AddonManifest item in installed) item.id: item,
    };
    byId[addon.id] = addon;
    await _writeAddons(byId.values.toList(growable: false));
    return addon;
  }

  Future<void> removeAddon(String addonId) async {
    final List<AddonManifest> installed = await getInstalledAddons();
    await _writeAddons(
      installed
          .where((AddonManifest addon) => addon.id != addonId)
          .toList(growable: false),
    );
  }

  Future<void> setAddonEnabled(String addonId, bool enabled) async {
    final List<AddonManifest> installed = await getInstalledAddons();
    await _writeAddons(
      installed
          .map(
            (AddonManifest addon) => addon.id == addonId
                ? AddonManifest.fromJson(
                    <String, dynamic>{
                      ...addon.toJson(),
                      'enabled': enabled,
                    },
                  )
                : addon,
          )
          .toList(growable: false),
    );
  }

  Future<AddonManifest?> refreshAddon(String addonId) async {
    final List<AddonManifest> installed = await getInstalledAddons();
    final AddonManifest? existing = installed.cast<AddonManifest?>().firstWhere(
          (AddonManifest? addon) => addon?.id == addonId,
          orElse: () => null,
        );
    if (existing == null) {
      return null;
    }

    final AddonManifest refreshed = await installAddon(existing.originalUrl);
    if (!refreshed.enabled) {
      await setAddonEnabled(refreshed.id, existing.enabled);
    } else if (!existing.enabled) {
      await setAddonEnabled(refreshed.id, false);
    }
    final List<AddonManifest> addons = await getInstalledAddons();
    return addons.cast<AddonManifest?>().firstWhere(
          (AddonManifest? addon) => addon?.id == addonId,
          orElse: () => null,
        );
  }

  Future<List<AddonCatalogItem>> fetchCatalog(
    AddonManifest addon,
    AddonCatalog catalog, {
    String? search,
    int? skip,
  }) async {
    final Uri catalogUri = _buildCatalogUri(
      addon,
      catalog,
      search: search,
      skip: skip,
    );
    final Map<String, dynamic> payload = await _fetchJson(catalogUri);
    final List<dynamic> metas =
        payload['metas'] as List<dynamic>? ?? const <dynamic>[];
    return metas
        .map(
          (dynamic item) =>
              AddonCatalogItem.fromJson(item as Map<String, dynamic>),
        )
        .take(20)
        .toList(growable: false);
  }

  /// Searches catalog resources that advertise the standard Stremio `search`
  /// extra. The `top` fallback keeps older persisted manifests working even
  /// when their original `extra` metadata was not saved by an earlier build.
  Future<List<SearchResult>> searchCatalogs(String query) async {
    final String trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const <SearchResult>[];
    }

    final List<AddonManifest> addons = await getEnabledAddons();
    final List<SearchResult> results = <SearchResult>[];
    final Set<String> seen = <String>{};
    Object? lastError;
    bool attempted = false;

    for (final AddonManifest addon in addons) {
      for (final AddonCatalog catalog in addon.catalogs) {
        if (catalog.type != 'movie' && catalog.type != 'series') {
          continue;
        }
        if (!catalog.supportsSearch && catalog.id != 'top') {
          continue;
        }

        attempted = true;
        try {
          final List<AddonCatalogItem> items = await fetchCatalog(
            addon,
            catalog,
            search: trimmed,
          );
          for (final AddonCatalogItem item in items) {
            final String externalId = item.id.trim();
            final String title = item.name.trim();
            if (externalId.isEmpty || title.isEmpty) {
              continue;
            }

            final String mediaType = item.mediaType == 'tv' ? 'tv' : 'movie';
            final String dedupeKey = '$mediaType:$externalId';
            if (!seen.add(dedupeKey)) {
              continue;
            }

            results.add(
              SearchResult(
                id: 0,
                mediaType: mediaType,
                posterPath: resolveAddonUrl(addon, item.poster),
                backdropPath: resolveAddonUrl(addon, item.background),
                overview: item.description ?? '',
                voteAverage: 0,
                voteCount: 0,
                popularity: 0,
                genreIds: const <int>[],
                originalLanguage: 'en',
                adult: false,
                title: title,
                releaseDate: item.releaseInfo,
                externalId: externalId,
                sourceName: addon.name,
              ),
            );
          }
        } catch (error) {
          lastError = error;
        }
      }
    }

    if (results.isEmpty && attempted && lastError != null) {
      throw lastError;
    }
    return results.take(40).toList(growable: false);
  }

  String resolveAddonUrl(AddonManifest addon, String? raw) {
    if (raw == null || raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return Uri.parse(addon.url).resolve(raw).toString();
  }

  Future<List<AddonCatalogRow>> fetchAllCatalogRows() async {
    final List<AddonManifest> addons = await getEnabledAddons();
    final List<AddonCatalogRow> rows = <AddonCatalogRow>[];

    for (final AddonManifest addon in addons) {
      if (addon.catalogs.isEmpty) continue;
      for (final AddonCatalog catalog in addon.catalogs.take(5)) {
        try {
          final List<AddonCatalogItem> items =
              await fetchCatalog(addon, catalog);
          if (items.isNotEmpty) {
            rows.add(AddonCatalogRow(
              addonName: addon.name,
              catalogName: catalog.name,
              catalog: catalog,
              addon: addon,
              items: items,
            ));
          }
        } catch (_) {}
      }
    }
    return rows;
  }

  Future<AddonMetaItem?> fetchMetadata({
    required String mediaType,
    required String id,
  }) async {
    final List<AddonManifest> addons = await getEnabledAddons();
    final String contentType = mediaType == 'tv' ? 'series' : mediaType;

    for (final AddonManifest addon in addons) {
      if (!addon.supportsMeta(mediaType, id)) {
        continue;
      }

      try {
        final Uri metaUri = _buildMetaUri(addon, contentType, id);
        final Map<String, dynamic> payload = await _fetchJson(metaUri);
        final Map<String, dynamic>? meta =
            payload['meta'] as Map<String, dynamic>?;
        if (meta == null) {
          continue;
        }
        final AddonMetaItem item = AddonMetaItem.fromJson(
          <String, dynamic>{
            ...meta,
            'poster': resolveAddonUrl(addon, meta['poster'] as String?),
            'background': resolveAddonUrl(addon, meta['background'] as String?),
            'logo': resolveAddonUrl(addon, meta['logo'] as String?),
          },
        );
        if (item.name.trim().isNotEmpty || item.description != null) {
          return item;
        }
      } catch (_) {}
    }
    return null;
  }

  Future<List<StreamSource>> getStreams({
    required String mediaType,
    required String streamId,
  }) async {
    final AddonSearchResult result = await searchStreamsDetailed(
      mediaType: mediaType,
      streamId: streamId,
    );
    return result.streams;
  }

  Future<AddonSearchResult> searchStreamsDetailed({
    required String mediaType,
    required String streamId,
  }) async {
    final List<AddonManifest> addons = await getEnabledAddons();
    final String contentType = mediaType == 'tv' ? 'series' : 'movie';
    final List<StreamSource> results = <StreamSource>[];
    final Set<String> seen = <String>{};
    final Map<String, int> sourceCounts = <String, int>{};
    final Map<String, String> sourceErrors = <String, String>{};

    for (final AddonManifest addon in addons) {
      if (!addon.supportsContent(contentType, streamId)) {
        continue;
      }

      final Uri streamUri = _buildStreamUri(addon, contentType, streamId);
      try {
        final Map<String, dynamic> payload = await _fetchJson(streamUri);
        final List<dynamic> streams =
            payload['streams'] as List<dynamic>? ?? const <dynamic>[];
        int addedForAddon = 0;
        for (final dynamic row in streams) {
          final StreamSource? source = _streamFromAddonRow(
            addon,
            row as Map<String, dynamic>,
          );
          if (source == null) {
            continue;
          }

          final String dedupeKey = source.infoHash?.toLowerCase() ??
              source.directUrl?.toLowerCase() ??
              source.id;
          if (!seen.add(dedupeKey)) {
            continue;
          }
          results.add(source);
          addedForAddon += 1;
        }
        sourceCounts[addon.name] = addedForAddon;
      } catch (error) {
        sourceCounts[addon.name] = 0;
        sourceErrors[addon.name] = error.toString();
      }
    }

    results.sort((StreamSource a, StreamSource b) {
      if (a.isCached != b.isCached) {
        return a.isCached ? -1 : 1;
      }
      if (a.isDirectUrl != b.isDirectUrl) {
        return a.isDirectUrl ? -1 : 1;
      }
      return a.sourceDisplayName.compareTo(b.sourceDisplayName);
    });

    return AddonSearchResult(
      streams: results,
      diagnostics: SourceSearchDiagnostics(
        sourceCounts: sourceCounts,
        sourceErrors: sourceErrors,
      ),
    );
  }

  StreamSource? _streamFromAddonRow(
    AddonManifest addon,
    Map<String, dynamic> item,
  ) {
    final Map<String, dynamic> behaviorHints =
        item['behaviorHints'] as Map<String, dynamic>? ??
            const <String, dynamic>{};
    final String? directUrl =
        _readString(item['url']) ?? _readString(item['externalUrl']);
    final List<String> sourceTrackers = _extractTrackers(item['sources']);
    final String? infoHash = _normalizeInfoHash(
      _readString(item['infoHash']) ??
          _extractInfoHashFromSources(item['sources']) ??
          _extractInfoHashFromBehaviorHints(behaviorHints),
    );
    if ((directUrl == null || directUrl.isEmpty) &&
        (infoHash == null || infoHash.isEmpty) &&
        _readString(item['ytId']) == null) {
      return null;
    }

    final String title = _readString(item['name']) ??
        _readString(item['title']) ??
        _readString(behaviorHints['filename']) ??
        addon.name;
    final String description = _readString(item['description']) ??
        _readString(item['title']) ??
        _readString(behaviorHints['filename']) ??
        '';
    final String text = '$title\n$description';
    final bool cached = _isCached(text, directUrl, behaviorHints);
    final String dedupeKey = infoHash ?? directUrl ?? title;

    return StreamSource(
      id: '${addon.id}:$dedupeKey',
      provider: 'addon',
      sourceDisplayName: addon.name,
      title: title,
      description: description,
      quality: _extractQuality(text),
      sizeLabel: _extractSize(text, behaviorHints['videoSize']),
      isCached: cached,
      cacheProvider: cached ? _cacheProviderLabel(text, directUrl) : null,
      addonId: addon.id,
      infoHash: infoHash,
      directUrl: directUrl,
      fileIndex: ((item['fileIdx'] ?? item['fileIndex']) as num?)?.toInt(),
      fileName: _readString(behaviorHints['filename']),
      videoSizeBytes: (behaviorHints['videoSize'] as num?)?.toInt(),
      magnetUri: _readString(item['magnetUri']) ??
          _buildMagnetUri(infoHash, sourceTrackers),
      sourceTrackers: sourceTrackers,
      streamHeaders: _readProxyRequestHeaders(behaviorHints),
    );
  }

  Future<void> _writeAddons(List<AddonManifest> addons) async {
    final File file = await _store.file();
    await file.writeAsString(
      jsonEncode(
        addons.map((AddonManifest addon) => addon.toJson()).toList(),
      ),
    );
  }

  Future<Map<String, dynamic>> _fetchJson(Uri uri) async {
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
    try {
      final HttpClientRequest request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      );

      final HttpClientResponse response =
          await request.close().timeout(const Duration(seconds: 20));
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Addon request failed with status ${response.statusCode}',
          uri: uri,
        );
      }

      final String raw = await response.transform(utf8.decoder).join();
      return jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException {
      throw const FormatException('Addon server returned invalid JSON.');
    } finally {
      client.close(force: true);
    }
  }

  Uri _normalizeManifestUri(String rawInput) {
    final String trimmed = rawInput.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Paste a Stremio addon manifest URL first.');
    }

    String candidate = trimmed;
    if (candidate.startsWith('stremio://')) {
      candidate = 'https://${candidate.substring('stremio://'.length)}';
    } else if (!candidate.startsWith('http://') &&
        !candidate.startsWith('https://')) {
      candidate = 'https://$candidate';
    }

    Uri uri;
    try {
      uri = Uri.parse(candidate);
    } catch (_) {
      throw const FormatException('That addon URL could not be parsed.');
    }

    if (uri.host.isEmpty) {
      throw const FormatException('That addon URL is missing a valid host.');
    }

    String path = uri.path;
    if (!path.endsWith('manifest.json')) {
      path = path.replaceAll(RegExp(r'/$'), '');
      path = path.isEmpty ? '/manifest.json' : '$path/manifest.json';
    }

    return uri.replace(path: path);
  }

  Uri _stripManifestPath(Uri uri) {
    String path = uri.path.replaceAll(RegExp(r'manifest\.json$'), '');
    path = path.replaceAll(RegExp(r'/$'), '');
    return uri.replace(path: path);
  }

  Uri _buildStreamUri(
      AddonManifest addon, String contentType, String streamId) {
    final Uri originalUri = Uri.parse(addon.originalUrl);
    final Uri baseUri = Uri.parse(addon.url);
    return baseUri.replace(
      path: '${baseUri.path}/stream/$contentType/$streamId.json'
          .replaceAll('//', '/'),
      queryParameters: originalUri.queryParameters.isEmpty
          ? null
          : originalUri.queryParameters,
    );
  }

  Uri _buildCatalogUri(
    AddonManifest addon,
    AddonCatalog catalog, {
    String? search,
    int? skip,
  }) {
    final Uri originalUri = Uri.parse(addon.originalUrl);
    final Uri baseUri = Uri.parse(addon.url);
    final StringBuffer path = StringBuffer(
      '${baseUri.path}/catalog/${catalog.type}/${catalog.id}'
          .replaceAll('//', '/'),
    );
    final String trimmedSearch = (search ?? '').trim();
    if (trimmedSearch.isNotEmpty) {
      path.write('/search=${Uri.encodeComponent(trimmedSearch)}');
    }
    if (skip != null && skip > 0) {
      path.write('/skip=$skip');
    }
    path.write('.json');
    return baseUri.replace(
      path: path.toString(),
      queryParameters: originalUri.queryParameters.isEmpty
          ? null
          : originalUri.queryParameters,
    );
  }

  Uri _buildMetaUri(AddonManifest addon, String contentType, String id) {
    final Uri originalUri = Uri.parse(addon.originalUrl);
    final Uri baseUri = Uri.parse(addon.url);
    return baseUri.replace(
      path: '${baseUri.path}/meta/$contentType/$id.json'.replaceAll('//', '/'),
      queryParameters: originalUri.queryParameters.isEmpty
          ? null
          : originalUri.queryParameters,
    );
  }

  String _makeAddonId(String url) {
    return url.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-').toLowerCase();
  }

  String? _readString(dynamic value) {
    if (value == null) {
      return null;
    }
    final String text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  String _extractQuality(String text) {
    final RegExp match = RegExp(
      r'(2160p|4k|1080p|720p|480p)',
      caseSensitive: false,
    );
    final RegExpMatch? result = match.firstMatch(text);
    if (result == null) {
      return 'Unknown';
    }

    final String value = result.group(1)!.toUpperCase();
    return value == '2160P' ? '4K' : value;
  }

  String _extractSize(String text, dynamic videoSize) {
    final int? bytes = (videoSize as num?)?.toInt();
    if (bytes != null && bytes > 0) {
      return _formatBytes(bytes);
    }

    final RegExp match = RegExp(
      r'(\d+(?:\.\d+)?)\s?(GB|MB|TB)',
      caseSensitive: false,
    );
    final RegExpMatch? result = match.firstMatch(text);
    if (result == null) {
      return '';
    }

    return '${result.group(1)} ${result.group(2)!.toUpperCase()}';
  }

  String _formatBytes(int bytes) {
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

  bool _isCached(
    String text,
    String? directUrl,
    Map<String, dynamic> behaviorHints,
  ) {
    if ((behaviorHints['cached'] as bool?) == true) {
      return true;
    }

    final String haystack = '${directUrl ?? ''}\n$text';
    return RegExp(
      r'(cached|instant|torbox|real.?debrid|premiumize|alldebrid|debrid)',
      caseSensitive: false,
    ).hasMatch(haystack);
  }

  String _cacheProviderLabel(String text, String? directUrl) {
    final String haystack = '${directUrl ?? ''}\n$text';
    if (RegExp(r'(torbox|\btb\b)', caseSensitive: false).hasMatch(haystack)) {
      return 'TB+';
    }
    if (RegExp(r'(real.?debrid|\brd\b)', caseSensitive: false)
        .hasMatch(haystack)) {
      return 'RD+';
    }
    if (RegExp(r'premiumize', caseSensitive: false).hasMatch(haystack)) {
      return 'PM';
    }
    return 'Cached';
  }

  String? _extractInfoHashFromSources(dynamic sources) {
    if (sources is! List<dynamic>) {
      return null;
    }
    for (final dynamic source in sources) {
      final String? value = _readString(source);
      if (value == null) {
        continue;
      }
      final String? hash = _extractInfoHash(value);
      if (hash != null) {
        return hash;
      }
    }
    return null;
  }

  List<String> _extractTrackers(dynamic sources) {
    if (sources is! List<dynamic>) {
      return const <String>[];
    }
    return sources
        .map(_readString)
        .whereType<String>()
        .where(
          (String item) =>
              item.startsWith('tracker:', 0) ||
              item.startsWith('http://') ||
              item.startsWith('https://') ||
              item.startsWith('udp://'),
        )
        .toSet()
        .toList(growable: false);
  }

  String? _buildMagnetUri(String? hash, List<String> trackers) {
    if (hash == null || hash.trim().isEmpty) {
      return null;
    }
    final StringBuffer buffer =
        StringBuffer('magnet:?xt=urn:btih:${hash.trim()}');
    for (final String tracker in trackers) {
      final String normalized =
          tracker.replaceFirst(RegExp(r'^tracker:', caseSensitive: false), '');
      if (normalized.trim().isEmpty) {
        continue;
      }
      buffer.write('&tr=${Uri.encodeComponent(normalized.trim())}');
    }
    return buffer.toString();
  }

  Map<String, String> _readProxyRequestHeaders(
    Map<String, dynamic> behaviorHints,
  ) {
    final dynamic proxyHeaders = behaviorHints['proxyHeaders'];
    if (proxyHeaders is! Map<String, dynamic>) {
      return const <String, String>{};
    }
    final dynamic requestHeaders = proxyHeaders['request'];
    if (requestHeaders is! Map<String, dynamic>) {
      return const <String, String>{};
    }
    return requestHeaders.map(
      (String key, dynamic value) => MapEntry<String, String>(
        key,
        value.toString(),
      ),
    );
  }

  String? _extractInfoHashFromBehaviorHints(
      Map<String, dynamic> behaviorHints) {
    final String? bingeGroup = _readString(behaviorHints['bingeGroup']);
    return _extractInfoHash(bingeGroup);
  }

  String? _extractInfoHash(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final RegExpMatch? match = RegExp(
      r'([A-Fa-f0-9]{40})',
      caseSensitive: false,
    ).firstMatch(value);
    return match?.group(1)?.toLowerCase();
  }

  String? _normalizeInfoHash(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final String? extracted = _extractInfoHash(value);
    if (extracted != null) {
      return extracted;
    }
    return value.toLowerCase();
  }
}

class AddonSearchResult {
  const AddonSearchResult({
    required this.streams,
    required this.diagnostics,
  });

  final List<StreamSource> streams;
  final SourceSearchDiagnostics diagnostics;
}
