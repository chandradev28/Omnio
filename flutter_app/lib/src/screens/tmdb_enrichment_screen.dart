import 'package:flutter/material.dart';

import '../models/torbox_models.dart';
import '../services/app_settings_repository.dart';
import '../services/tmdb_http_service.dart';
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
  bool _testingApiKey = false;
  String? _apiKeyStatus;
  bool _apiKeyStatusSuccess = false;

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

  Future<void> _testAndSaveApiKey() async {
    if (_testingApiKey) {
      return;
    }

    final String rawCredential = _apiKeyController.text;
    if (TmdbHttpService.normalizeCredential(rawCredential).isEmpty) {
      setState(() {
        _apiKeyStatus =
            'Enter a TMDB v3 API key or v4 Read Access Token first.';
        _apiKeyStatusSuccess = false;
      });
      return;
    }

    setState(() {
      _testingApiKey = true;
      _apiKeyStatus = 'Testing TMDB connection...';
      _apiKeyStatusSuccess = false;
    });

    try {
      final String credential = await TmdbHttpService(
        settingsRepository: widget.settingsRepository,
      ).validateCredential(rawCredential);
      await _save(_settings.copyWith(tmdbApiKey: credential));
      if (!mounted) {
        return;
      }
      _apiKeyController.text = credential;
      setState(() {
        _apiKeyStatus =
            'TMDB verified. Your credential was saved and is ready for search.';
        _apiKeyStatusSuccess = true;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _apiKeyStatus = _credentialErrorMessage(error);
        _apiKeyStatusSuccess = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _testingApiKey = false;
        });
      }
    }
  }

  Future<void> _clearApiKey() async {
    _apiKeyController.clear();
    await _save(_settings.copyWith(clearTmdbApiKey: true));
    if (!mounted) {
      return;
    }
    setState(() {
      _apiKeyStatus =
          'Personal credential removed. The built-in key will be used.';
      _apiKeyStatusSuccess = true;
    });
  }

  String _credentialErrorMessage(Object error) {
    if (error is TmdbRequestException) {
      if (error.statusCode == 401) {
        return 'TMDB rejected this credential. Check that you pasted the full '
            'v3 API key or v4 Read Access Token.';
      }
      if (error.statusCode == 403 || error.statusCode >= 500) {
        return 'TMDB or your network blocked the request. Connect VPN/WARP and '
            'try Test & Save again.';
      }
      return error.message;
    }
    return 'TMDB could not be reached. Connect VPN/WARP and try again.';
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
              'The app uses the built-in key by default. Add a TMDB v3 API key '
              'or v4 Read Access Token below, then test it before saving.',
              style: TextStyle(color: AppColors.textMuted, height: 1.4),
            ),
          ],
        ),
        const _SectionLabel('CREDENTIALS'),
        _SettingsPanel(
          children: <Widget>[
            const _FieldTitle(
              title: 'Personal API key',
              subtitle: 'Enter a v3 API key or v4 Read Access Token.',
            ),
            _SecretField(
              controller: _apiKeyController,
              hintText: 'TMDB key or read token',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _testingApiKey ? null : _testAndSaveApiKey,
                  icon: _testingApiKey
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.verified_rounded, size: 18),
                  label: Text(_testingApiKey ? 'Testing...' : 'Test & Save'),
                ),
                OutlinedButton(
                  onPressed: _testingApiKey ||
                          TmdbHttpService.normalizeCredential(
                            _apiKeyController.text,
                          ).isEmpty
                      ? null
                      : _clearApiKey,
                  child: const Text('Clear'),
                ),
              ],
            ),
            if (_apiKeyStatus != null) ...<Widget>[
              const SizedBox(height: 12),
              _CredentialStatus(
                message: _apiKeyStatus!,
                success: _apiKeyStatusSuccess,
              ),
            ],
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

class _CredentialStatus extends StatelessWidget {
  const _CredentialStatus({
    required this.message,
    required this.success,
  });

  final String message;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final Color color = success ? const Color(0xFF63D391) : AppColors.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            success ? Icons.check_circle_rounded : Icons.info_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 12,
                height: 1.35,
              ),
            ),
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
