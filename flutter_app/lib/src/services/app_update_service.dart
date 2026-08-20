import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.version,
    required this.downloadUrl,
    this.releaseNotes,
  });

  final String version;
  final Uri downloadUrl;
  final String? releaseNotes;
}

enum AppInstallResult {
  started,
  permissionRequired,
}

class AppUpdateService {
  AppUpdateService({
    HttpClient? client,
    MethodChannel? channel,
  })  : _client = client ?? HttpClient(),
        _channel = channel ?? const MethodChannel('streamed/app_updater');

  static const String _latestReleaseUrl =
      'https://api.github.com/repos/chandradev28/streamed-flutter/releases/latest';
  static const String _userAgent = 'Streamed-Flutter-App';
  static const String _currentVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );

  final HttpClient _client;
  final MethodChannel _channel;

  Future<AppUpdateInfo?> checkForUpdate() async {
    if (kIsWeb || !Platform.isAndroid) {
      return null;
    }

    final Uri releaseUri = Uri.parse(_latestReleaseUrl);
    final HttpClientRequest request = await _client.getUrl(releaseUri);
    request.headers
      ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
      ..set(HttpHeaders.userAgentHeader, _userAgent);

    final HttpClientResponse response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      return null;
    }

    final Map<String, dynamic> release =
        jsonDecode(await response.transform(utf8.decoder).join())
            as Map<String, dynamic>;
    if (release['draft'] == true || release['prerelease'] == true) {
      return null;
    }

    final String tagName = release['tag_name'] as String? ?? '';
    final String latestVersion =
        tagName.startsWith('v') ? tagName.substring(1) : tagName;
    final Uri? apkUrl = _findApkUrl(release['assets']);
    if (latestVersion.isEmpty || apkUrl == null) {
      return null;
    }

    if (_compareVersions(latestVersion, _currentVersion) <= 0) {
      return null;
    }

    final String? body = release['body'] as String?;
    return AppUpdateInfo(
      version: latestVersion,
      downloadUrl: apkUrl,
      releaseNotes: body == null || body.trim().isEmpty ? null : body.trim(),
    );
  }

  Future<AppInstallResult> downloadAndInstall(
    AppUpdateInfo update, {
    ValueChanged<double>? onProgress,
  }) async {
    if (kIsWeb || !Platform.isAndroid) {
      throw UnsupportedError('APK updates are only supported on Android.');
    }

    final HttpClientRequest request = await _client.getUrl(update.downloadUrl);
    request.headers
      ..set(HttpHeaders.acceptHeader, 'application/vnd.android.package-archive')
      ..set(HttpHeaders.userAgentHeader, _userAgent);

    final HttpClientResponse response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.drain<void>();
      throw HttpException(
        'Update download failed with HTTP ${response.statusCode}.',
      );
    }

    final Directory temporaryDirectory = await getTemporaryDirectory();
    final String safeVersion = update.version.replaceAll(
      RegExp(r'[^0-9A-Za-z._-]'),
      '_',
    );
    final File apkFile = File(
      '${temporaryDirectory.path}${Platform.pathSeparator}streamed-$safeVersion.apk',
    );
    final IOSink sink = apkFile.openWrite();
    final int? contentLength =
        response.contentLength > 0 ? response.contentLength : null;
    int received = 0;
    try {
      await for (final List<int> chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        if (contentLength != null && onProgress != null) {
          onProgress((received / contentLength).clamp(0.0, 1.0));
        }
      }
    } finally {
      await sink.close();
    }

    final String result = await _channel.invokeMethod<String>(
          'installApk',
          <String, dynamic>{'path': apkFile.path},
        ) ??
        'started';
    if (result == 'permissionRequired') {
      return AppInstallResult.permissionRequired;
    }
    return AppInstallResult.started;
  }

  Uri? _findApkUrl(dynamic assets) {
    if (assets is! List<dynamic>) {
      return null;
    }

    for (final dynamic asset in assets) {
      if (asset is! Map<String, dynamic>) {
        continue;
      }
      final String name = asset['name'] as String? ?? '';
      final String? url = asset['browser_download_url'] as String?;
      if (name.toLowerCase().endsWith('.apk') && url != null) {
        return Uri.tryParse(url);
      }
    }
    return null;
  }

  int _compareVersions(String left, String right) {
    final List<int> leftParts = _versionParts(left);
    final List<int> rightParts = _versionParts(right);
    for (int index = 0; index < 3; index++) {
      final int difference = leftParts[index] - rightParts[index];
      if (difference != 0) {
        return difference.sign;
      }
    }
    return 0;
  }

  List<int> _versionParts(String version) {
    final List<String> parts = version.split('+').first.split('.');
    return List<int>.generate(
      3,
      (int index) => index < parts.length ? int.tryParse(parts[index]) ?? 0 : 0,
    );
  }
}
