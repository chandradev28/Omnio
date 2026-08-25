import 'package:flutter/material.dart';

import '../models/torbox_models.dart';
import '../services/stremio_addons_service.dart';
import '../theme/app_colors.dart';

class AddonsScreen extends StatefulWidget {
  AddonsScreen({
    super.key,
    StremioAddonsService? addonsService,
  }) : addonsService = addonsService ?? StremioAddonsService();

  final StremioAddonsService addonsService;

  @override
  State<AddonsScreen> createState() => _AddonsScreenState();
}

class _AddonsScreenState extends State<AddonsScreen> {
  final TextEditingController _urlController = TextEditingController();
  List<AddonManifest> _addons = const <AddonManifest>[];
  bool _loading = true;
  bool _installing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });

    final List<AddonManifest> addons =
        await widget.addonsService.getInstalledAddons();
    if (!mounted) {
      return;
    }

    setState(() {
      _addons = addons;
      _loading = false;
    });
  }

  Future<void> _installAddon() async {
    final String url = _urlController.text.trim();
    if (url.isEmpty) {
      return;
    }

    setState(() {
      _installing = true;
    });

    try {
      final AddonManifest addon = await widget.addonsService.installAddon(url);
      _urlController.clear();
      await _load();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${addon.name} installed.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _installing = false;
        });
      }
    }
  }

  Future<void> _removeAddon(AddonManifest addon) async {
    await widget.addonsService.removeAddon(addon.id);
    await _load();
  }

  Future<void> _toggleAddon(AddonManifest addon, bool value) async {
    await widget.addonsService.setAddonEnabled(addon.id, value);
    await _load();
  }

  Future<void> _refreshAddon(AddonManifest addon) async {
    try {
      final AddonManifest? refreshed =
          await widget.addonsService.refreshAddon(addon.id);
      await _load();
      if (!mounted || refreshed == null) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${refreshed.name} refreshed.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Addons'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Install addon',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _urlController,
                      style: const TextStyle(color: AppColors.text),
                      decoration: InputDecoration(
                        hintText: 'Manifest URL or stremio:// link',
                        hintStyle: const TextStyle(color: AppColors.textSubtle),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.04),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _installing ? null : _installAddon,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.text,
                        foregroundColor: AppColors.background,
                      ),
                      child: Text(_installing ? 'Installing...' : 'Install'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.text),
                  ),
                )
              else if (_addons.isEmpty)
                const _EmptyAddonsState()
              else
                ..._addons.map(
                  (AddonManifest addon) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _AddonCard(
                      addon: addon,
                      onToggle: (bool value) => _toggleAddon(addon, value),
                      onRefresh: () => _refreshAddon(addon),
                      onDelete: () => _removeAddon(addon),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddonCard extends StatelessWidget {
  const _AddonCard({
    required this.addon,
    required this.onToggle,
    required this.onRefresh,
    required this.onDelete,
  });

  final AddonManifest addon;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRefresh;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: <Widget>[
          _AddonLogo(addon: addon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  addon.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  addon.hasStreamResource ? 'Streams ready' : 'No streams',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: addon.enabled,
            onChanged: onToggle,
          ),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.text),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFFCA5A5),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddonLogo extends StatelessWidget {
  const _AddonLogo({required this.addon});

  final AddonManifest addon;

  @override
  Widget build(BuildContext context) {
    final String? logo = addon.logo;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 48,
        height: 48,
        color: Colors.white.withOpacity(0.08),
        child: logo == null || logo.isEmpty
            ? const Icon(Icons.extension_rounded, color: AppColors.text)
            : Image.network(
                logo,
                fit: BoxFit.cover,
                errorBuilder: (
                  BuildContext context,
                  Object error,
                  StackTrace? stackTrace,
                ) {
                  return const Icon(
                    Icons.extension_rounded,
                    color: AppColors.text,
                  );
                },
              ),
      ),
    );
  }
}

class _EmptyAddonsState extends StatelessWidget {
  const _EmptyAddonsState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        children: <Widget>[
          Icon(Icons.extension_outlined, color: AppColors.textMuted, size: 36),
          SizedBox(height: 12),
          Text(
            'No addons installed yet.',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Install Comet, MediaFusion, or any Stremio stream addon to power Omnio sources.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, height: 1.45),
          ),
        ],
      ),
    );
  }
}
