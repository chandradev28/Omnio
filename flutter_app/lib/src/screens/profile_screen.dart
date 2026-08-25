import 'package:flutter/material.dart';

import '../models/torbox_models.dart';
import '../services/app_settings_repository.dart';
import '../services/app_update_service.dart';
import '../theme/app_colors.dart';
import '../theme/layout_options.dart';
import '../widgets/app_update_dialog.dart';
import 'addons_screen.dart';
import 'integrations_screen.dart';
import 'layout_screen.dart';
import 'playback_screen.dart';
import 'streams_screen.dart';
import 'torboxers_screen.dart';

class ProfileScreen extends StatefulWidget {
  ProfileScreen({
    super.key,
    this.showBackButton = true,
    AppSettingsRepository? settingsRepository,
  }) : settingsRepository = settingsRepository ?? AppSettingsRepository();

  final bool showBackButton;
  final AppSettingsRepository settingsRepository;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _searchController = TextEditingController();
  final AppUpdateService _updateService = AppUpdateService();
  AppSettings _settings = const AppSettings();
  bool _checkingForUpdate = false;

  Color get _accent => LayoutOptions.accentFor(_settings);

  @override
  void initState() {
    super.initState();
    AppSettingsRepository.settingsNotifier.addListener(_syncSettings);
    _loadSettings();
  }

  @override
  void dispose() {
    AppSettingsRepository.settingsNotifier.removeListener(_syncSettings);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final AppSettings settings = await widget.settingsRepository.loadSettings();
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
    });
  }

  void _syncSettings() {
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = AppSettingsRepository.settingsNotifier.value;
    });
  }

  void _openAddons() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AddonsScreen(),
      ),
    );
  }

  void _openIntegrations() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const IntegrationsScreen(),
      ),
    );
  }

  void _openLayout() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => LayoutScreen(),
      ),
    );
  }

  void _openTorboxers() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => TorboxersScreen(),
      ),
    );
  }

  void _openPlayback() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => PlaybackScreen(),
      ),
    );
  }

  void _openStreams() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => StreamsScreen(),
      ),
    );
  }

  bool _matchesSettingsSearch(String value) {
    final String query = _searchController.text.trim().toLowerCase();
    return query.isEmpty || value.toLowerCase().contains(query);
  }

  void _showPlaceholder(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title is not wired yet.')),
    );
  }

  Future<void> _checkForUpdates() async {
    if (_checkingForUpdate) {
      return;
    }
    setState(() {
      _checkingForUpdate = true;
    });
    try {
      final AppUpdateInfo? update = await _updateService.checkForUpdate();
      if (!mounted) {
        return;
      }
      if (update == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are using the latest version.')),
        );
      } else {
        await showAppUpdateDialog(
          context: context,
          updateService: _updateService,
          update: update,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not check for updates. Check your internet connection.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _checkingForUpdate = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool showGeneral = _matchesSettingsSearch(
      'general layout content discovery addons downloads playback streams badges integrations notifications torboxers',
    );
    final bool showAbout = _matchesSettingsSearch(
      'about supporters contributors updates update version',
    );

    return Scaffold(
      backgroundColor: LayoutOptions.backgroundFor(_settings),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 56),
          children: <Widget>[
            Row(
              children: <Widget>[
                if (widget.showBackButton) ...<Widget>[
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.arrow_back_rounded, color: _accent),
                  ),
                  const SizedBox(width: 6),
                ],
                const Expanded(
                  child: Text(
                    'Settings',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: AppColors.text),
              decoration: InputDecoration(
                hintText: 'Search settings...',
                prefixIcon: Icon(Icons.search_rounded, color: _accent),
                filled: true,
                fillColor: AppColors.cardBackground,
                hintStyle: const TextStyle(color: AppColors.textSubtle),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                ),
              ),
            ),
            const SizedBox(height: 22),
            if (showGeneral) ...<Widget>[
              const _SettingsSectionLabel('GENERAL'),
              _SettingsGroupCard(
                children: <Widget>[
                  _SettingsActionTile(
                    icon: Icons.palette_rounded,
                    title: 'Layout',
                    subtitle: 'Home structure and poster styles',
                    accent: _accent,
                    onTap: _openLayout,
                  ),
                  _SettingsActionTile(
                    icon: Icons.extension_rounded,
                    title: 'Content & Discovery',
                    subtitle: 'Manage addons and discovery sources.',
                    accent: _accent,
                    onTap: _openAddons,
                  ),
                  _SettingsActionTile(
                    icon: Icons.cloud_download_rounded,
                    title: 'Downloads',
                    subtitle: 'Manage your downloaded movies and episodes.',
                    accent: _accent,
                    onTap: () => _showPlaceholder('Downloads'),
                  ),
                  _SettingsActionTile(
                    icon: Icons.play_arrow_rounded,
                    title: 'Playback',
                    subtitle: 'Player, subtitles, and auto-play',
                    accent: _accent,
                    onTap: _openPlayback,
                  ),
                  _SettingsActionTile(
                    icon: Icons.local_offer_rounded,
                    title: 'Streams',
                    subtitle: 'Source badges and stream list display',
                    accent: _accent,
                    onTap: _openStreams,
                  ),
                  _SettingsActionTile(
                    icon: Icons.link_rounded,
                    title: 'Integrations',
                    subtitle: 'Manage available integrations',
                    accent: _accent,
                    onTap: _openIntegrations,
                  ),
                  _SettingsActionTile(
                    icon: Icons.notifications_rounded,
                    title: 'Notifications',
                    subtitle:
                        'Manage episode release alerts and test notifications.',
                    accent: _accent,
                    onTap: () => _showPlaceholder('Notifications'),
                  ),
                  _SettingsActionTile(
                    icon: Icons.rocket_launch_rounded,
                    title: 'Torboxers',
                    subtitle: 'Search streams and imported engines',
                    accent: _accent,
                    onTap: _openTorboxers,
                  ),
                ],
              ),
              const SizedBox(height: 22),
            ],
            if (showAbout) ...<Widget>[
              const _SettingsSectionLabel('ABOUT'),
              _SettingsGroupCard(
                children: <Widget>[
                  _SettingsActionTile(
                    icon: Icons.favorite_rounded,
                    title: 'Supporters & Contributors',
                    subtitle: 'Open recognition and project credits',
                    accent: _accent,
                    onTap: () => _showPlaceholder('Supporters & Contributors'),
                  ),
                  _SettingsActionTile(
                    icon: Icons.system_update_rounded,
                    title: 'Check for updates',
                    subtitle: _checkingForUpdate
                        ? 'Checking for a newer version...'
                        : 'Look for the latest Omnio APK',
                    accent: _accent,
                    onTap: _checkingForUpdate ? null : _checkForUpdates,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsSectionLabel extends StatelessWidget {
  const _SettingsSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 10),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsGroupCard extends StatelessWidget {
  const _SettingsGroupCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final Color tileAccent = accent ?? Theme.of(context).colorScheme.primary;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      leading: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: tileAccent.withOpacity(0.16),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: tileAccent, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 13,
          height: 1.25,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: tileAccent.withOpacity(0.78),
      ),
    );
  }
}
