import 'package:flutter/material.dart';

import '../services/app_update_service.dart';

Future<void> showAppUpdateDialog({
  required BuildContext context,
  required AppUpdateService updateService,
  required AppUpdateInfo update,
}) async {
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
                Text('Omnio ${update.version} is ready to install.'),
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
                              await updateService.downloadAndInstall(
                            update,
                            onProgress: (double value) {
                              if (dialogContext.mounted) {
                                setDialogState(() {
                                  progress = value;
                                });
                              }
                            },
                          );
                          if (!dialogContext.mounted) {
                            return;
                          }
                          if (result == AppInstallResult.permissionRequired) {
                            setDialogState(() {
                              downloading = false;
                              error =
                                  'Allow installs from this app, then tap Install again.';
                            });
                          } else {
                            Navigator.of(dialogContext).pop();
                          }
                        } catch (_) {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              downloading = false;
                              error =
                                  'Could not download the update. Try again later.';
                            });
                          }
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
