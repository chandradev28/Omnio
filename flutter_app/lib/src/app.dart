import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'models/torbox_models.dart';
import 'screens/home_shell.dart';
import 'services/app_update_service.dart';
import 'services/app_settings_repository.dart';
import 'theme/app_theme.dart';
import 'theme/layout_options.dart';
import 'widgets/app_update_dialog.dart';

class OmnioApp extends StatefulWidget {
  const OmnioApp({
    super.key,
    this.home,
  });

  final Widget? home;

  @override
  State<OmnioApp> createState() => _OmnioAppState();
}

class _OmnioAppState extends State<OmnioApp> {
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
      await showAppUpdateDialog(
        context: context,
        updateService: _updateService,
        update: update,
      );
    } catch (_) {
      // Updates are optional and must never prevent the app from opening.
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppSettings>(
      valueListenable: AppSettingsRepository.settingsNotifier,
      builder: (BuildContext context, AppSettings settings, Widget? child) {
        return MaterialApp(
          title: 'Omnio',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(accent: LayoutOptions.accentFor(settings)),
          home: widget.home ?? const HomeShell(),
        );
      },
    );
  }
}
