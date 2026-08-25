import 'package:flutter/material.dart';

import '../models/torbox_models.dart';
import '../services/app_settings_repository.dart';
import '../theme/app_colors.dart';

class TmdbEnrichmentScreen extends StatefulWidget {
  TmdbEnrichmentScreen({
    super.key,
    AppSettingsRepository? settingsRepository,
  }) : settingsRepository = settingsRepository ?? AppSettingsRepository();

  final AppSettingsRepository settingsRepository;

  @override
  State<TmdbEnrichmentScreen> createState() => _TmdbEnrichmentScreenState();
}

class _TmdbEnrichmentScreenState extends State<TmdbEnrichmentScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _languageController = TextEditingController();
  AppSettings _settings = const AppSettings();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _languageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final AppSettings settings = await widget.settingsRepository.loadSettings();
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
      _apiKeyController.text = settings.tmdbApiKey ?? '';
      _languageController.text = settings.tmdbLanguage;
    });
  }

  Future<void> _save(AppSettings settings) async {
    await widget.settingsRepository.saveSettings(settings);
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
    });
  }

  Future<void> _saveApiKey() async {
    await _save(_settings.copyWith(tmdbApiKey: _apiKeyController.text.trim()));
  }

  Future<void> _saveLanguage() async {
    final String language = _languageController.text.trim();
    if (language.isEmpty) {
      return;
    }
    await _save(_settings.copyWith(tmdbLanguage: language));
  }

  @override
  Widget build(BuildContext context) {
    return _IntegrationSettingsScaffold(
      title: 'TMDB\nEnrichment',
      children: <Widget>[
        const _SectionLabel('TMDB ENRICHMENT'),
        _SettingsPanel(
          children: <Widget>[
            _SwitchRow(
              title: 'Enable TMDB Enrichment',
              subtitle: 'Use TMDB as a metadata source to enhance app content.',
              value: _settings.tmdbEnrichmentEnabled,
              onChanged: (bool value) =>
                  _save(_settings.copyWith(tmdbEnrichmentEnabled: value)),
            ),
            const SizedBox(height: 10),
            const Text(
              'The app uses the built-in Omnio API key by default. Add your own TMDB v3 API key below if you want to use personal quota.',
              style: TextStyle(color: AppColors.textMuted, height: 1.4),
            ),
          ],
        ),
        const _SectionLabel('CREDENTIALS'),
        _SettingsPanel(
          children: <Widget>[
            const _FieldTitle(
              title: 'Personal API key',
              subtitle: 'Enter your TMDB v3 API key.',
            ),
            _SecretField(
              controller: _apiKeyController,
              hintText: 'API Key',
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saveApiKey,
              child: const Text('Save'),
            ),
          ],
        ),
        const _SectionLabel('LOCALIZATION'),
        _SettingsPanel(
          children: <Widget>[
            const _FieldTitle(
              title: 'Language',
              subtitle:
                  'TMDB metadata language for title, logo, and enabled fields.',
            ),
            _SecretField(
              controller: _languageController,
              hintText: 'en-US',
              obscure: false,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saveLanguage,
              child: const Text('Save'),
            ),
          ],
        ),
        const _SectionLabel('MODULES'),
        _SettingsPanel(
          children: <Widget>[
            _SwitchRow(
              title: 'Trailers',
              subtitle: 'Trailer candidates from TMDB videos.',
              value: _settings.tmdbTrailersEnabled,
              onChanged: (bool value) =>
                  _save(_settings.copyWith(tmdbTrailersEnabled: value)),
            ),
            _SwitchRow(
              title: 'Artwork',
              subtitle: 'Logo, poster, and backdrop images from TMDB.',
              value: _settings.tmdbArtworkEnabled,
              onChanged: (bool value) =>
                  _save(_settings.copyWith(tmdbArtworkEnabled: value)),
            ),
            _SwitchRow(
              title: 'Basic info',
              subtitle: 'Description, genres, and rating from TMDB.',
              value: _settings.tmdbBasicInfoEnabled,
              onChanged: (bool value) =>
                  _save(_settings.copyWith(tmdbBasicInfoEnabled: value)),
            ),
            _SwitchRow(
              title: 'Details',
              subtitle: 'Runtime, status, country, and language from TMDB.',
              value: _settings.tmdbDetailsEnabled,
              onChanged: (bool value) =>
                  _save(_settings.copyWith(tmdbDetailsEnabled: value)),
            ),
            _SwitchRow(
              title: 'Credits',
              subtitle: 'Cast with photos, director, and writer from TMDB.',
              value: _settings.tmdbCreditsEnabled,
              onChanged: (bool value) =>
                  _save(_settings.copyWith(tmdbCreditsEnabled: value)),
            ),
            _SwitchRow(
              title: 'Productions',
              subtitle: 'Production companies from TMDB.',
              value: _settings.tmdbProductionsEnabled,
              onChanged: (bool value) =>
                  _save(_settings.copyWith(tmdbProductionsEnabled: value)),
            ),
            _SwitchRow(
              title: 'Networks',
              subtitle: 'Networks with logos from TMDB.',
              value: _settings.tmdbNetworksEnabled,
              onChanged: (bool value) =>
                  _save(_settings.copyWith(tmdbNetworksEnabled: value)),
            ),
            _SwitchRow(
              title: 'Episodes',
              subtitle: 'Episode titles, overviews, thumbnails, and runtime.',
              value: _settings.tmdbEpisodesEnabled,
              onChanged: (bool value) =>
                  _save(_settings.copyWith(tmdbEpisodesEnabled: value)),
            ),
            _SwitchRow(
              title: 'Season posters',
              subtitle: 'Use TMDB season posters in the season selector.',
              value: _settings.tmdbSeasonPostersEnabled,
              onChanged: (bool value) =>
                  _save(_settings.copyWith(tmdbSeasonPostersEnabled: value)),
            ),
            _SwitchRow(
              title: 'More Like This',
              subtitle: 'Related movie and series rows from TMDB.',
              value: _settings.tmdbMoreLikeThisEnabled,
              onChanged: (bool value) =>
                  _save(_settings.copyWith(tmdbMoreLikeThisEnabled: value)),
            ),
          ],
        ),
      ],
    );
  }
}

class _IntegrationSettingsScaffold extends StatelessWidget {
  const _IntegrationSettingsScaffold({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 120),
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 38,
                      height: 1.0,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    height: 1.25,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _FieldTitle extends StatelessWidget {
  const _FieldTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SecretField extends StatefulWidget {
  const _SecretField({
    required this.controller,
    required this.hintText,
    this.obscure = true,
  });

  final TextEditingController controller;
  final String hintText;
  final bool obscure;

  @override
  State<_SecretField> createState() => _SecretFieldState();
}

class _SecretFieldState extends State<_SecretField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: widget.obscure && !_visible,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.none,
      style: const TextStyle(color: AppColors.text),
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: const TextStyle(color: AppColors.textSubtle),
        suffixIcon: widget.obscure
            ? IconButton(
                onPressed: () => setState(() {
                  _visible = !_visible;
                }),
                icon: Icon(_visible ? Icons.visibility_off : Icons.visibility),
              )
            : null,
        filled: true,
        fillColor: Colors.black.withOpacity(0.14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
    );
  }
}
