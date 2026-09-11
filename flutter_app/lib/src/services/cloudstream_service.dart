import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'local_json_store.dart';

class CloudstreamService {
  CloudstreamService(
      {LocalJsonStore? store,
      MethodChannel? channel,
      Future<dynamic> Function(Uri)? fetch})
      : _store = store ?? const LocalJsonStore('omnio_cloudstream.json'),
        _channel = channel ?? const MethodChannel('omnio/cloudstream'),
        _fetchOverride = fetch;
  final LocalJsonStore _store;
  final MethodChannel _channel;
  final Future<dynamic> Function(Uri)? _fetchOverride;
  static final changes = ValueNotifier<int>(0);
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Uri repositoryUri(String input) {
    var value = input.trim();
    if (value.startsWith('cloudstreamrepo://')) {
      value = 'https://${value.substring('cloudstreamrepo://'.length)}';
    }
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException(
          'Use a direct HTTPS repo.json or plugins.json URL.');
    }
    return uri;
  }

  Future<dynamic> _fetch(Uri uri) async {
    if (_fetchOverride != null) return _fetchOverride(uri);
    final client = HttpClient();
    client.badCertificateCallback = (_, __, ___) => false;
    client.connectionTimeout = const Duration(seconds: 15);
    try {
      for (var redirects = 0; redirects < 6; redirects++) {
        final request =
            await client.getUrl(uri).timeout(const Duration(seconds: 15));
        request.followRedirects = false;
        final response =
            await request.close().timeout(const Duration(seconds: 20));
        if (response.isRedirect) {
          final target = response.headers.value(HttpHeaders.locationHeader);
          if (target == null) {
            throw const FormatException('Missing redirect URL');
          }
          uri = repositoryUri(uri.resolve(target).toString());
          continue;
        }
        if (response.statusCode != 200) {
          throw HttpException(
              'Repository returned HTTP ${response.statusCode}');
        }
        final bytes = <int>[];
        await for (final chunk
            in response.timeout(const Duration(seconds: 20))) {
          bytes.addAll(chunk);
          if (bytes.length > 8 * 1024 * 1024) {
            throw const FormatException('Repository exceeds 8 MB');
          }
        }
        return jsonDecode(utf8.decode(bytes));
      }
      throw const FormatException('Too many repository redirects');
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> state() async {
    final file = await _store.file();
    if (!await file.exists()) {
      return {'repos': <dynamic>[], 'installed': <String, dynamic>{}};
    }
    final data = jsonDecode(await file.readAsString());
    if (data is! Map<String, dynamic> ||
        data['repos'] is! List ||
        data['installed'] is! Map) {
      throw const FormatException(
          'Cloudstream settings are damaged. Restore your backup rather than overwriting them.');
    }
    return data;
  }

  Future<void> _save(Map<String, dynamic> data) async {
    final file = await _store.file();
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(data), flush: true);
    await temp.rename(file.path);
    changes.value++;
  }

  Future<Map<String, dynamic>> readRepository(String input) async {
    final uri = repositoryUri(input);
    final payload = await _fetch(uri);
    final plugins = <Map<String, dynamic>>[];
    final failures = <String>[];
    void append(dynamic items, Uri base) {
      if (items is! List) {
        throw const FormatException('Expected a plugins.json array');
      }
      for (final item in items.whereType<Map<String, dynamic>>()) {
        final name = item['internalName']?.toString() ?? '';
        if (name.isEmpty || item['url'] is! String) continue;
        try {
          final url = repositoryUri(base.resolve(item['url']).toString());
          plugins.add({
            ...item,
            'url': url.toString(),
            'internalName': name,
            'name': item['name']?.toString() ?? name,
            'id': '${uri.toString()}::$name',
            'repo': uri.toString()
          });
        } on FormatException {
          failures.add('$name has an unsupported download URL');
        }
      }
    }

    if (payload is List) {
      append(payload, uri);
    } else if (payload is Map && payload['pluginLists'] is List) {
      final lists = payload['pluginLists'] as List;
      if (lists.length > 100) {
        throw const FormatException('Repository has too many plugin lists');
      }
      for (final value in lists) {
        try {
          final listUri =
              repositoryUri(uri.resolve(value.toString()).toString());
          append(await _fetch(listUri), listUri);
        } catch (_) {
          failures.add('A plugin list could not load. Refresh to retry.');
        }
      }
    } else {
      throw const FormatException(
          'Not a Cloudstream repository. Expected pluginLists or a plugins.json array.');
    }
    if (plugins.isEmpty && failures.isNotEmpty) {
      throw const FormatException(
          'No plugin lists could be loaded. Check the repository URL and connection.');
    }
    final unique = <String, Map<String, dynamic>>{
      for (final p in plugins) p['id']: p
    };
    return {
      'url': uri.toString(),
      'name': payload is Map ? payload['name'] ?? uri.host : uri.host,
      'plugins': unique.values.toList(),
      'warnings': failures
    };
  }

  Future<void> addRepository(String url) async {
    final repo = await readRepository(url);
    final data = await state();
    final repos = data['repos'] as List;
    final previous = repos
        .whereType<Map>()
        .where((r) => r['url'] == repo['url'])
        .firstOrNull;
    // A failed list refresh must not erase previously visible plugins.
    if ((repo['warnings'] as List).isNotEmpty && previous != null) {
      repo['plugins'] = <String, dynamic>{
        for (final p in previous['plugins'] as List) p['id']: p,
        for (final p in repo['plugins'] as List) p['id']: p,
      }.values.toList();
    }
    repos.removeWhere((r) => r['url'] == repo['url']);
    repos.add(repo);
    await _save(data);
  }

  Future<void> install(Map<String, dynamic> plugin) async {
    if (!supported) {
      throw UnsupportedError('Cloudstream playback is Android-only.');
    }
    if (plugin['status'] == 0) {
      throw StateError('The repository marks this plugin as broken.');
    }
    final result = await _channel.invokeMapMethod<String, dynamic>('install', {
      'url': plugin['url'],
      'hash': plugin['fileHash'] ?? '',
    });
    if (result == null || result['key'] is! String) {
      throw StateError('Plugin installation failed');
    }
    final data = await state();
    final installed = data['installed'] as Map;
    final old = installed[plugin['id']] as Map?;
    installed[plugin['id']] = {
      ...plugin,
      ...result,
      'enabled': old?['enabled'] ?? true
    };
    await _save(data);
    if (old != null && old['key'] != result['key']) {
      await _channel.invokeMethod('unload', {'key': old['key']});
    }
  }

  Future<void> setEnabled(String id, bool enabled) async {
    final data = await state();
    final plugin = data['installed'][id];
    if (plugin == null) return;
    plugin['enabled'] = enabled;
    await _save(data);
    if (!enabled) await _channel.invokeMethod('unload', {'key': plugin['key']});
  }

  Future<void> removePlugin(String id) async {
    final data = await state();
    final old = (data['installed'] as Map).remove(id);
    await _save(data);
    if (old != null &&
        !(data['installed'] as Map).values.any((p) => p['key'] == old['key'])) {
      await _channel.invokeMethod('remove', {'key': old['key']});
    }
  }

  Future<void> removeRepository(String url) async {
    final before = await state();
    for (final entry in (before['installed'] as Map).entries.toList()) {
      if (entry.value['repo'] == url) await removePlugin(entry.key);
    }
    final data = await state();
    (data['repos'] as List).removeWhere((r) => r['url'] == url);
    await _save(data);
  }

  Future<List<Map<String, dynamic>>> enabledPlugins() async {
    if (!supported) return [];
    return ((await state())['installed'] as Map)
        .values
        .whereType<Map<String, dynamic>>()
        .where((p) => p['enabled'] == true)
        .toList();
  }

  Future<Map<String, dynamic>> sources(Map<String, dynamic> args) async =>
      Map<String, dynamic>.from(
          await _channel.invokeMapMethod('sources', args) ?? {});
}
