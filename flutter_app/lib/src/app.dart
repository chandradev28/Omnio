import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'models/torbox_models.dart';
import 'screens/home_shell.dart';
import 'services/app_update_service.dart';
import 'services/app_settings_repository.dart';
import 'theme/app_theme.dart';
import 'theme/layout_options.dart';

class StreamedApp extends StatefulWidget {
  const StreamedApp({
    super.key,
    this.home,
  });

  final Widget? home;

  @override
  State<StreamedApp> createState() => _StreamedAppState();
}

class _StreamedAppState extends State<StreamedApp> {
  final AppSettingsRepository _settingsRepository = AppSettingsRepository();
  final AppUpdateService _updateService = AppUpdateService();
  bool _updatePromptShown = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadInitialSettings());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkForUpdate());
    });
  }

  Future<void> _loadInitialSettings() async {
    try {
      await _settingsRepository.loadSettings();
    } catch (_) {
      // Keep the default theme if persisted settings cannot be read.
    }
  }

  Future<void> _checkForUpdate() async {
    if (!kReleaseMode || _updatePromptShown || !mounted) {
      return;
    }

    try {
      final AppUpdateInfo? update = await _updateService.checkForUpdate();
      if (update == null || !mounted || _updatePromptShown) {
        return;
      }
      _updatePromptShown = true;
      await _showUpdateDialog(update);
    } catch (_) {
      // Updates are optional and must never prevent the app from opening.
    }
  }

  Future<void> _showUpdateDialog(AppUpdateInfo update) async {
    bool downloading = false;
    double progress = 0;
    String? error;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (
            BuildContext context,
            void Function(void Function()) setDialogState,
          ) {
            return AlertDialog(
              title: const Text('New update available'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Streamed ${update.version} is ready to install.'),
                  if (update.releaseNotes != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      update.releaseNotes!,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (downloading) ...<Widget>[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: progress == 0 ? null : progress,
                    ),
                    if (progress > 0) ...<Widget>[
                      const SizedBox(height: 6),
                      Text('${(progress * 100).round()}%'),
                    ],
                  ],
                  if (error != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: downloading
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Later'),
                ),
                FilledButton(
                  onPressed: downloading
                      ? null
                      : () async {
                          setDialogState(() {
                            downloading = true;
                            error = null;
                            progress = 0;
                          });
                          try {
                            final AppInstallResult result =
                                await _updateService.downloadAndInstall(
                              update,
                              onProgress: (double value) {
                                setDialogState(() {
                                  progress = value;
                                });
                              },
                            );
                            if (result == AppInstallResult.permissionRequired) {
                              setDialogState(() {
                                downloading = false;
                                error =
                                    'Allow installs from this app, then tap Install again.';
                              });
                            } else if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          } catch (_) {
                            setDialogState(() {
                              downloading = false;
                              error =
                                  'Could not download the update. Try again later.';
                            });
                          }
                        },
                  child: const Text('Install update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppSettings>(
      valueListenable: AppSettingsRepository.settingsNotifier,
      builder: (BuildContext context, AppSettings settings, Widget? child) {
        return MaterialApp(
          title: 'Streamed Flutter',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(accent: LayoutOptions.accentFor(settings)),
          home: widget.home ?? const HomeShell(),
        );
      },
    );
  }
}
