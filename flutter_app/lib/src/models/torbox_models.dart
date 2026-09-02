class AppSettings {
  const AppSettings({
    this.torBoxApiKey,
    this.realDebridApiKey,
    this.preferredDebridProvider = 'torbox',
    this.useAddons = false,
    this.cloudLibraryEnabled = false,
    this.resolvePlayableLinksEnabled = true,
    this.tmdbEnrichmentEnabled = true,
    this.tmdbApiKey,
    this.tmdbLanguage = 'en-US',
    this.tmdbTrailersEnabled = true,
    this.tmdbArtworkEnabled = true,
    this.tmdbBasicInfoEnabled = true,
    this.tmdbDetailsEnabled = true,
    this.tmdbCreditsEnabled = true,
    this.tmdbProductionsEnabled = true,
    this.tmdbNetworksEnabled = true,
    this.tmdbEpisodesEnabled = true,
    this.tmdbSeasonPostersEnabled = true,
    this.tmdbMoreLikeThisEnabled = true,
    this.mdbListRatingsEnabled = false,
    this.mdbListApiKey,
    this.mdbListImdbEnabled = true,
    this.mdbListTmdbEnabled = true,
    this.mdbListRottenTomatoesEnabled = true,
    this.mdbListMetacriticEnabled = true,
    this.mdbListTraktEnabled = true,
    this.mdbListLetterboxdEnabled = true,
    this.mdbListAudienceScoreEnabled = true,
    this.layoutTheme = 'white',
    this.amoledBlackEnabled = true,
    this.continueWatchingEnabled = true,
    this.continueWatchingStyle = 'wide',
    this.continueWatchingPreferEpisodeThumbs = true,
    this.continueWatchingFurthestEpisode = true,
    this.continueWatchingShowUnaired = false,
    this.continueWatchingBlurUnwatched = false,
    this.continueWatchingResumePrompt = true,
    this.continueWatchingSortOrder = 'default',
    this.posterWidthPreset = 'balanced',
    this.posterRadiusPreset = 'rounded',
    this.posterLandscapeEnabled = false,
    this.posterHideLabels = false,
    this.playbackAutoPlay = true,
    this.playbackPreferExternalPlayer = false,
    this.playbackResumeEnabled = true,
    this.playbackSaveProgress = true,
    this.playbackSkipSeconds = 10,
    this.playbackHoldToSpeed = true,
    this.playbackSpeedControls = true,
    this.playbackDefaultSpeed = 1.0,
    this.playbackHoldSpeed = 2.0,
    this.playbackPreferredSubtitleLanguage = 'en',
    this.playbackSecondarySubtitleLanguage = '',
    this.playbackPreferredAudioLanguage = '',
    this.playbackSecondaryAudioLanguage = '',
    this.playbackUseForcedSubtitles = false,
    this.playbackShowOnlyPreferredLanguages = false,
    this.playbackAddonSubtitleStartup = 'all',
    this.playbackShowFilesButton = true,
    this.playbackShowSubtitlesButton = true,
    this.playbackShowAudioButton = true,
    this.playbackShowExternalButton = true,
    this.playbackAutoPlayNextEpisode = false,
    this.playbackBingeGroupNextEpisode = true,
    this.playbackNextEpisodeThreshold = 90,
    this.streamBadgesEnabled = false,
    this.streamBadgesJson = '',
  });

  final String? torBoxApiKey;
  final String? realDebridApiKey;
  final String preferredDebridProvider;
  final bool useAddons;
  final bool cloudLibraryEnabled;
  final bool resolvePlayableLinksEnabled;
  final bool tmdbEnrichmentEnabled;
  final String? tmdbApiKey;
  final String tmdbLanguage;
  final bool tmdbTrailersEnabled;
  final bool tmdbArtworkEnabled;
  final bool tmdbBasicInfoEnabled;
  final bool tmdbDetailsEnabled;
  final bool tmdbCreditsEnabled;
  final bool tmdbProductionsEnabled;
  final bool tmdbNetworksEnabled;
  final bool tmdbEpisodesEnabled;
  final bool tmdbSeasonPostersEnabled;
  final bool tmdbMoreLikeThisEnabled;
  final bool mdbListRatingsEnabled;
  final String? mdbListApiKey;
  final bool mdbListImdbEnabled;
  final bool mdbListTmdbEnabled;
  final bool mdbListRottenTomatoesEnabled;
  final bool mdbListMetacriticEnabled;
  final bool mdbListTraktEnabled;
  final bool mdbListLetterboxdEnabled;
  final bool mdbListAudienceScoreEnabled;
  final String layoutTheme;
  final bool amoledBlackEnabled;
  final bool continueWatchingEnabled;
  final String continueWatchingStyle;
  final bool continueWatchingPreferEpisodeThumbs;
  final bool continueWatchingFurthestEpisode;
  final bool continueWatchingShowUnaired;
  final bool continueWatchingBlurUnwatched;
  final bool continueWatchingResumePrompt;
  final String continueWatchingSortOrder;
  final String posterWidthPreset;
  final String posterRadiusPreset;
  final bool posterLandscapeEnabled;
  final bool posterHideLabels;
  final bool playbackAutoPlay;
  final bool playbackPreferExternalPlayer;
  final bool playbackResumeEnabled;
  final bool playbackSaveProgress;
  final int playbackSkipSeconds;
  final bool playbackHoldToSpeed;
  final bool playbackSpeedControls;
  final double playbackDefaultSpeed;
  final double playbackHoldSpeed;
  final String playbackPreferredSubtitleLanguage;
  final String playbackSecondarySubtitleLanguage;
  final String playbackPreferredAudioLanguage;
  final String playbackSecondaryAudioLanguage;
  final bool playbackUseForcedSubtitles;
  final bool playbackShowOnlyPreferredLanguages;
  final String playbackAddonSubtitleStartup;
  final bool playbackShowFilesButton;
  final bool playbackShowSubtitlesButton;
  final bool playbackShowAudioButton;
  final bool playbackShowExternalButton;
  final bool playbackAutoPlayNextEpisode;
  final bool playbackBingeGroupNextEpisode;
  final int playbackNextEpisodeThreshold;
  final bool streamBadgesEnabled;
  final String streamBadgesJson;

  AppSettings copyWith({
    String? torBoxApiKey,
    String? realDebridApiKey,
    bool clearApiKey = false,
    bool clearRealDebridApiKey = false,
    String? preferredDebridProvider,
    bool? useAddons,
    bool? cloudLibraryEnabled,
    bool? resolvePlayableLinksEnabled,
    bool? tmdbEnrichmentEnabled,
    String? tmdbApiKey,
    bool clearTmdbApiKey = false,
    String? tmdbLanguage,
    bool? tmdbTrailersEnabled,
    bool? tmdbArtworkEnabled,
    bool? tmdbBasicInfoEnabled,
    bool? tmdbDetailsEnabled,
    bool? tmdbCreditsEnabled,
    bool? tmdbProductionsEnabled,
    bool? tmdbNetworksEnabled,
    bool? tmdbEpisodesEnabled,
    bool? tmdbSeasonPostersEnabled,
    bool? tmdbMoreLikeThisEnabled,
    bool? mdbListRatingsEnabled,
    String? mdbListApiKey,
    bool clearMdbListApiKey = false,
    bool? mdbListImdbEnabled,
    bool? mdbListTmdbEnabled,
    bool? mdbListRottenTomatoesEnabled,
    bool? mdbListMetacriticEnabled,
    bool? mdbListTraktEnabled,
    bool? mdbListLetterboxdEnabled,
    bool? mdbListAudienceScoreEnabled,
    String? layoutTheme,
    bool? amoledBlackEnabled,
    bool? continueWatchingEnabled,
    String? continueWatchingStyle,
    bool? continueWatchingPreferEpisodeThumbs,
    bool? continueWatchingFurthestEpisode,
    bool? continueWatchingShowUnaired,
    bool? continueWatchingBlurUnwatched,
    bool? continueWatchingResumePrompt,
    String? continueWatchingSortOrder,
    String? posterWidthPreset,
    String? posterRadiusPreset,
    bool? posterLandscapeEnabled,
    bool? posterHideLabels,
    bool? playbackAutoPlay,
    bool? playbackPreferExternalPlayer,
    bool? playbackResumeEnabled,
    bool? playbackSaveProgress,
    int? playbackSkipSeconds,
    bool? playbackHoldToSpeed,
    bool? playbackSpeedControls,
    double? playbackDefaultSpeed,
    double? playbackHoldSpeed,
    String? playbackPreferredSubtitleLanguage,
    String? playbackSecondarySubtitleLanguage,
    String? playbackPreferredAudioLanguage,
    String? playbackSecondaryAudioLanguage,
    bool? playbackUseForcedSubtitles,
    bool? playbackShowOnlyPreferredLanguages,
    String? playbackAddonSubtitleStartup,
    bool? playbackShowFilesButton,
    bool? playbackShowSubtitlesButton,
    bool? playbackShowAudioButton,
    bool? playbackShowExternalButton,
    bool? playbackAutoPlayNextEpisode,
    bool? playbackBingeGroupNextEpisode,
    int? playbackNextEpisodeThreshold,
    bool? streamBadgesEnabled,
    String? streamBadgesJson,
  }) {
    return AppSettings(
      torBoxApiKey: clearApiKey ? null : (torBoxApiKey ?? this.torBoxApiKey),
      realDebridApiKey: clearRealDebridApiKey
          ? null
          : (realDebridApiKey ?? this.realDebridApiKey),
      preferredDebridProvider:
          preferredDebridProvider ?? this.preferredDebridProvider,
      useAddons: useAddons ?? this.useAddons,
      cloudLibraryEnabled: cloudLibraryEnabled ?? this.cloudLibraryEnabled,
      resolvePlayableLinksEnabled:
          resolvePlayableLinksEnabled ?? this.resolvePlayableLinksEnabled,
      tmdbEnrichmentEnabled:
          tmdbEnrichmentEnabled ?? this.tmdbEnrichmentEnabled,
      tmdbApiKey: clearTmdbApiKey ? null : (tmdbApiKey ?? this.tmdbApiKey),
      tmdbLanguage: tmdbLanguage ?? this.tmdbLanguage,
      tmdbTrailersEnabled: tmdbTrailersEnabled ?? this.tmdbTrailersEnabled,
      tmdbArtworkEnabled: tmdbArtworkEnabled ?? this.tmdbArtworkEnabled,
      tmdbBasicInfoEnabled: tmdbBasicInfoEnabled ?? this.tmdbBasicInfoEnabled,
      tmdbDetailsEnabled: tmdbDetailsEnabled ?? this.tmdbDetailsEnabled,
      tmdbCreditsEnabled: tmdbCreditsEnabled ?? this.tmdbCreditsEnabled,
      tmdbProductionsEnabled:
          tmdbProductionsEnabled ?? this.tmdbProductionsEnabled,
      tmdbNetworksEnabled: tmdbNetworksEnabled ?? this.tmdbNetworksEnabled,
      tmdbEpisodesEnabled: tmdbEpisodesEnabled ?? this.tmdbEpisodesEnabled,
      tmdbSeasonPostersEnabled:
          tmdbSeasonPostersEnabled ?? this.tmdbSeasonPostersEnabled,
      tmdbMoreLikeThisEnabled:
          tmdbMoreLikeThisEnabled ?? this.tmdbMoreLikeThisEnabled,
      mdbListRatingsEnabled:
          mdbListRatingsEnabled ?? this.mdbListRatingsEnabled,
      mdbListApiKey:
          clearMdbListApiKey ? null : (mdbListApiKey ?? this.mdbListApiKey),
      mdbListImdbEnabled: mdbListImdbEnabled ?? this.mdbListImdbEnabled,
      mdbListTmdbEnabled: mdbListTmdbEnabled ?? this.mdbListTmdbEnabled,
      mdbListRottenTomatoesEnabled:
          mdbListRottenTomatoesEnabled ?? this.mdbListRottenTomatoesEnabled,
      mdbListMetacriticEnabled:
          mdbListMetacriticEnabled ?? this.mdbListMetacriticEnabled,
      mdbListTraktEnabled: mdbListTraktEnabled ?? this.mdbListTraktEnabled,
      mdbListLetterboxdEnabled:
          mdbListLetterboxdEnabled ?? this.mdbListLetterboxdEnabled,
      mdbListAudienceScoreEnabled:
          mdbListAudienceScoreEnabled ?? this.mdbListAudienceScoreEnabled,
      layoutTheme: layoutTheme ?? this.layoutTheme,
      amoledBlackEnabled: amoledBlackEnabled ?? this.amoledBlackEnabled,
      continueWatchingEnabled:
          continueWatchingEnabled ?? this.continueWatchingEnabled,
      continueWatchingStyle:
          continueWatchingStyle ?? this.continueWatchingStyle,
      continueWatchingPreferEpisodeThumbs:
          continueWatchingPreferEpisodeThumbs ??
              this.continueWatchingPreferEpisodeThumbs,
      continueWatchingFurthestEpisode: continueWatchingFurthestEpisode ??
          this.continueWatchingFurthestEpisode,
      continueWatchingShowUnaired:
          continueWatchingShowUnaired ?? this.continueWatchingShowUnaired,
      continueWatchingBlurUnwatched:
          continueWatchingBlurUnwatched ?? this.continueWatchingBlurUnwatched,
      continueWatchingResumePrompt:
          continueWatchingResumePrompt ?? this.continueWatchingResumePrompt,
      continueWatchingSortOrder:
          continueWatchingSortOrder ?? this.continueWatchingSortOrder,
      posterWidthPreset: posterWidthPreset ?? this.posterWidthPreset,
      posterRadiusPreset: posterRadiusPreset ?? this.posterRadiusPreset,
      posterLandscapeEnabled:
          posterLandscapeEnabled ?? this.posterLandscapeEnabled,
      posterHideLabels: posterHideLabels ?? this.posterHideLabels,
      playbackAutoPlay: playbackAutoPlay ?? this.playbackAutoPlay,
      playbackPreferExternalPlayer:
          playbackPreferExternalPlayer ?? this.playbackPreferExternalPlayer,
      playbackResumeEnabled:
          playbackResumeEnabled ?? this.playbackResumeEnabled,
      playbackSaveProgress: playbackSaveProgress ?? this.playbackSaveProgress,
      playbackSkipSeconds: playbackSkipSeconds ?? this.playbackSkipSeconds,
      playbackHoldToSpeed: playbackHoldToSpeed ?? this.playbackHoldToSpeed,
      playbackSpeedControls:
          playbackSpeedControls ?? this.playbackSpeedControls,
      playbackDefaultSpeed: playbackDefaultSpeed ?? this.playbackDefaultSpeed,
      playbackHoldSpeed: playbackHoldSpeed ?? this.playbackHoldSpeed,
      playbackPreferredSubtitleLanguage: playbackPreferredSubtitleLanguage ??
          this.playbackPreferredSubtitleLanguage,
      playbackSecondarySubtitleLanguage: playbackSecondarySubtitleLanguage ??
          this.playbackSecondarySubtitleLanguage,
      playbackPreferredAudioLanguage:
          playbackPreferredAudioLanguage ?? this.playbackPreferredAudioLanguage,
      playbackSecondaryAudioLanguage:
          playbackSecondaryAudioLanguage ?? this.playbackSecondaryAudioLanguage,
      playbackUseForcedSubtitles:
          playbackUseForcedSubtitles ?? this.playbackUseForcedSubtitles,
      playbackShowOnlyPreferredLanguages: playbackShowOnlyPreferredLanguages ??
          this.playbackShowOnlyPreferredLanguages,
      playbackAddonSubtitleStartup:
          playbackAddonSubtitleStartup ?? this.playbackAddonSubtitleStartup,
      playbackShowFilesButton:
          playbackShowFilesButton ?? this.playbackShowFilesButton,
      playbackShowSubtitlesButton:
          playbackShowSubtitlesButton ?? this.playbackShowSubtitlesButton,
      playbackShowAudioButton:
          playbackShowAudioButton ?? this.playbackShowAudioButton,
      playbackShowExternalButton:
          playbackShowExternalButton ?? this.playbackShowExternalButton,
      playbackAutoPlayNextEpisode:
          playbackAutoPlayNextEpisode ?? this.playbackAutoPlayNextEpisode,
      playbackBingeGroupNextEpisode:
          playbackBingeGroupNextEpisode ?? this.playbackBingeGroupNextEpisode,
      playbackNextEpisodeThreshold:
          playbackNextEpisodeThreshold ?? this.playbackNextEpisodeThreshold,
      streamBadgesEnabled: streamBadgesEnabled ?? this.streamBadgesEnabled,
      streamBadgesJson: streamBadgesJson ?? this.streamBadgesJson,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      torBoxApiKey: json['torBoxApiKey'] as String?,
      realDebridApiKey: json['realDebridApiKey'] as String?,
      preferredDebridProvider:
          json['preferredDebridProvider'] as String? ?? 'torbox',
      useAddons: json['useAddons'] as bool? ?? false,
      cloudLibraryEnabled: json['cloudLibraryEnabled'] as bool? ?? false,
      resolvePlayableLinksEnabled:
          json['resolvePlayableLinksEnabled'] as bool? ?? true,
      tmdbEnrichmentEnabled: json['tmdbEnrichmentEnabled'] as bool? ?? true,
      tmdbApiKey: json['tmdbApiKey'] as String?,
      tmdbLanguage: json['tmdbLanguage'] as String? ?? 'en-US',
      tmdbTrailersEnabled: json['tmdbTrailersEnabled'] as bool? ?? true,
      tmdbArtworkEnabled: json['tmdbArtworkEnabled'] as bool? ?? true,
      tmdbBasicInfoEnabled: json['tmdbBasicInfoEnabled'] as bool? ?? true,
      tmdbDetailsEnabled: json['tmdbDetailsEnabled'] as bool? ?? true,
      tmdbCreditsEnabled: json['tmdbCreditsEnabled'] as bool? ?? true,
      tmdbProductionsEnabled: json['tmdbProductionsEnabled'] as bool? ?? true,
      tmdbNetworksEnabled: json['tmdbNetworksEnabled'] as bool? ?? true,
      tmdbEpisodesEnabled: json['tmdbEpisodesEnabled'] as bool? ?? true,
      tmdbSeasonPostersEnabled:
          json['tmdbSeasonPostersEnabled'] as bool? ?? true,
      tmdbMoreLikeThisEnabled: json['tmdbMoreLikeThisEnabled'] as bool? ?? true,
      mdbListRatingsEnabled: json['mdbListRatingsEnabled'] as bool? ?? false,
      mdbListApiKey: json['mdbListApiKey'] as String?,
      mdbListImdbEnabled: json['mdbListImdbEnabled'] as bool? ?? true,
      mdbListTmdbEnabled: json['mdbListTmdbEnabled'] as bool? ?? true,
      mdbListRottenTomatoesEnabled:
          json['mdbListRottenTomatoesEnabled'] as bool? ?? true,
      mdbListMetacriticEnabled:
          json['mdbListMetacriticEnabled'] as bool? ?? true,
      mdbListTraktEnabled: json['mdbListTraktEnabled'] as bool? ?? true,
      mdbListLetterboxdEnabled:
          json['mdbListLetterboxdEnabled'] as bool? ?? true,
      mdbListAudienceScoreEnabled:
          json['mdbListAudienceScoreEnabled'] as bool? ?? true,
      layoutTheme: json['layoutTheme'] as String? ?? 'white',
      amoledBlackEnabled: json['amoledBlackEnabled'] as bool? ?? true,
      continueWatchingEnabled: json['continueWatchingEnabled'] as bool? ?? true,
      continueWatchingStyle: json['continueWatchingStyle'] as String? ?? 'wide',
      continueWatchingPreferEpisodeThumbs:
          json['continueWatchingPreferEpisodeThumbs'] as bool? ?? true,
      continueWatchingFurthestEpisode:
          json['continueWatchingFurthestEpisode'] as bool? ?? true,
      continueWatchingShowUnaired:
          json['continueWatchingShowUnaired'] as bool? ?? false,
      continueWatchingBlurUnwatched:
          json['continueWatchingBlurUnwatched'] as bool? ?? false,
      continueWatchingResumePrompt:
          json['continueWatchingResumePrompt'] as bool? ?? true,
      continueWatchingSortOrder:
          json['continueWatchingSortOrder'] as String? ?? 'default',
      posterWidthPreset: json['posterWidthPreset'] as String? ?? 'balanced',
      posterRadiusPreset: json['posterRadiusPreset'] as String? ?? 'rounded',
      posterLandscapeEnabled: json['posterLandscapeEnabled'] as bool? ?? false,
      posterHideLabels: json['posterHideLabels'] as bool? ?? false,
      playbackAutoPlay: json['playbackAutoPlay'] as bool? ?? true,
      playbackPreferExternalPlayer:
          json['playbackPreferExternalPlayer'] as bool? ?? false,
      playbackResumeEnabled: json['playbackResumeEnabled'] as bool? ?? true,
      playbackSaveProgress: json['playbackSaveProgress'] as bool? ?? true,
      playbackSkipSeconds: (json['playbackSkipSeconds'] as num?)?.toInt() ?? 10,
      playbackHoldToSpeed: json['playbackHoldToSpeed'] as bool? ?? true,
      playbackSpeedControls: json['playbackSpeedControls'] as bool? ?? true,
      playbackDefaultSpeed:
          (json['playbackDefaultSpeed'] as num?)?.toDouble() ?? 1.0,
      playbackHoldSpeed: (json['playbackHoldSpeed'] as num?)?.toDouble() ?? 2.0,
      playbackPreferredSubtitleLanguage:
          json['playbackPreferredSubtitleLanguage'] as String? ?? 'en',
      playbackSecondarySubtitleLanguage:
          json['playbackSecondarySubtitleLanguage'] as String? ?? '',
      playbackPreferredAudioLanguage:
          json['playbackPreferredAudioLanguage'] as String? ?? '',
      playbackSecondaryAudioLanguage:
          json['playbackSecondaryAudioLanguage'] as String? ?? '',
      playbackUseForcedSubtitles:
          json['playbackUseForcedSubtitles'] as bool? ?? false,
      playbackShowOnlyPreferredLanguages:
          json['playbackShowOnlyPreferredLanguages'] as bool? ?? false,
      playbackAddonSubtitleStartup:
          json['playbackAddonSubtitleStartup'] as String? ?? 'all',
      playbackShowFilesButton: json['playbackShowFilesButton'] as bool? ?? true,
      playbackShowSubtitlesButton:
          json['playbackShowSubtitlesButton'] as bool? ?? true,
      playbackShowAudioButton: json['playbackShowAudioButton'] as bool? ?? true,
      playbackShowExternalButton:
          json['playbackShowExternalButton'] as bool? ?? true,
      playbackAutoPlayNextEpisode:
          json['playbackAutoPlayNextEpisode'] as bool? ?? false,
      playbackBingeGroupNextEpisode:
          json['playbackBingeGroupNextEpisode'] as bool? ?? true,
      playbackNextEpisodeThreshold:
          (json['playbackNextEpisodeThreshold'] as num?)?.toInt() ?? 90,
      streamBadgesEnabled: json['streamBadgesEnabled'] as bool? ?? false,
      streamBadgesJson: json['streamBadgesJson'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'torBoxApiKey': torBoxApiKey,
      'realDebridApiKey': realDebridApiKey,
      'preferredDebridProvider': preferredDebridProvider,
      'useAddons': useAddons,
      'cloudLibraryEnabled': cloudLibraryEnabled,
      'resolvePlayableLinksEnabled': resolvePlayableLinksEnabled,
      'tmdbEnrichmentEnabled': tmdbEnrichmentEnabled,
      'tmdbApiKey': tmdbApiKey,
      'tmdbLanguage': tmdbLanguage,
      'tmdbTrailersEnabled': tmdbTrailersEnabled,
      'tmdbArtworkEnabled': tmdbArtworkEnabled,
      'tmdbBasicInfoEnabled': tmdbBasicInfoEnabled,
      'tmdbDetailsEnabled': tmdbDetailsEnabled,
      'tmdbCreditsEnabled': tmdbCreditsEnabled,
      'tmdbProductionsEnabled': tmdbProductionsEnabled,
      'tmdbNetworksEnabled': tmdbNetworksEnabled,
      'tmdbEpisodesEnabled': tmdbEpisodesEnabled,
      'tmdbSeasonPostersEnabled': tmdbSeasonPostersEnabled,
      'tmdbMoreLikeThisEnabled': tmdbMoreLikeThisEnabled,
      'mdbListRatingsEnabled': mdbListRatingsEnabled,
      'mdbListApiKey': mdbListApiKey,
      'mdbListImdbEnabled': mdbListImdbEnabled,
      'mdbListTmdbEnabled': mdbListTmdbEnabled,
      'mdbListRottenTomatoesEnabled': mdbListRottenTomatoesEnabled,
      'mdbListMetacriticEnabled': mdbListMetacriticEnabled,
      'mdbListTraktEnabled': mdbListTraktEnabled,
      'mdbListLetterboxdEnabled': mdbListLetterboxdEnabled,
      'mdbListAudienceScoreEnabled': mdbListAudienceScoreEnabled,
      'layoutTheme': layoutTheme,
      'amoledBlackEnabled': amoledBlackEnabled,
      'continueWatchingEnabled': continueWatchingEnabled,
      'continueWatchingStyle': continueWatchingStyle,
      'continueWatchingPreferEpisodeThumbs':
          continueWatchingPreferEpisodeThumbs,
      'continueWatchingFurthestEpisode': continueWatchingFurthestEpisode,
      'continueWatchingShowUnaired': continueWatchingShowUnaired,
      'continueWatchingBlurUnwatched': continueWatchingBlurUnwatched,
      'continueWatchingResumePrompt': continueWatchingResumePrompt,
      'continueWatchingSortOrder': continueWatchingSortOrder,
      'posterWidthPreset': posterWidthPreset,
      'posterRadiusPreset': posterRadiusPreset,
      'posterLandscapeEnabled': posterLandscapeEnabled,
      'posterHideLabels': posterHideLabels,
      'playbackAutoPlay': playbackAutoPlay,
      'playbackPreferExternalPlayer': playbackPreferExternalPlayer,
      'playbackResumeEnabled': playbackResumeEnabled,
      'playbackSaveProgress': playbackSaveProgress,
      'playbackSkipSeconds': playbackSkipSeconds,
      'playbackHoldToSpeed': playbackHoldToSpeed,
      'playbackSpeedControls': playbackSpeedControls,
      'playbackDefaultSpeed': playbackDefaultSpeed,
      'playbackHoldSpeed': playbackHoldSpeed,
      'playbackPreferredSubtitleLanguage': playbackPreferredSubtitleLanguage,
      'playbackSecondarySubtitleLanguage': playbackSecondarySubtitleLanguage,
      'playbackPreferredAudioLanguage': playbackPreferredAudioLanguage,
      'playbackSecondaryAudioLanguage': playbackSecondaryAudioLanguage,
      'playbackUseForcedSubtitles': playbackUseForcedSubtitles,
      'playbackShowOnlyPreferredLanguages': playbackShowOnlyPreferredLanguages,
      'playbackAddonSubtitleStartup': playbackAddonSubtitleStartup,
      'playbackShowFilesButton': playbackShowFilesButton,
      'playbackShowSubtitlesButton': playbackShowSubtitlesButton,
      'playbackShowAudioButton': playbackShowAudioButton,
      'playbackShowExternalButton': playbackShowExternalButton,
      'playbackAutoPlayNextEpisode': playbackAutoPlayNextEpisode,
      'playbackBingeGroupNextEpisode': playbackBingeGroupNextEpisode,
      'playbackNextEpisodeThreshold': playbackNextEpisodeThreshold,
      'streamBadgesEnabled': streamBadgesEnabled,
      'streamBadgesJson': streamBadgesJson,
    };
  }
}

class TorBoxUser {
  const TorBoxUser({
    required this.email,
    required this.plan,
    required this.createdAt,
    required this.totalSlots,
    required this.usedSlots,
    this.premiumExpiresAt,
  });

  final String email;
  final String plan;
  final String? createdAt;
  final int totalSlots;
  final int usedSlots;
  final String? premiumExpiresAt;

  bool get hasSlotInfo => totalSlots > 0 || usedSlots > 0;

  factory TorBoxUser.fromJson(Map<String, dynamic> json) {
    final int planCode = _readInt(json['plan']) ?? -1;
    final int extraSlots = _readInt(json['additional_concurrent_slots']) ?? 0;
    final int totalSlots = _readInt(json['total_slots']) ??
        _readInt(json['slots']) ??
        _planSlots(planCode, extraSlots);
    final int usedSlots =
        _readInt(json['used_slots']) ?? _readInt(json['active_downloads']) ?? 0;

    return TorBoxUser(
      email: _readString(json['email']) ??
          _readString(json['username']) ??
          'TorBox account',
      plan: _readString(json['plan_name']) ??
          _planLabel(planCode) ??
          _readString(json['plan']) ??
          _readString(json['subscription']) ??
          'Unknown plan',
      createdAt: _readString(json['created_at']),
      totalSlots: totalSlots,
      usedSlots: usedSlots,
      premiumExpiresAt: _readString(json['premium_expires_at']) ??
          _readString(json['premium_expiration']),
    );
  }

  static int? _readInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  static String? _readString(dynamic value) {
    final String text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static String? _planLabel(int code) {
    switch (code) {
      case 0:
        return 'Free';
      case 1:
        return 'Essential';
      case 2:
        return 'Pro';
      case 3:
        return 'Standard';
      default:
        return null;
    }
  }

  static int _planSlots(int code, int extraSlots) {
    final int baseSlots;
    switch (code) {
      case 0:
        baseSlots = 1;
        break;
      case 1:
        baseSlots = 3;
        break;
      case 2:
        baseSlots = 10;
        break;
      case 3:
        baseSlots = 5;
        break;
      default:
        baseSlots = 0;
        break;
    }

    return baseSlots + extraSlots;
  }
}

class TorBoxTorrentFile {
  const TorBoxTorrentFile({
    required this.id,
    required this.name,
    required this.size,
    this.shortName,
  });

  final int id;
  final String name;
  final int size;
  final String? shortName;

  String get displayName {
    if (shortName != null && shortName!.trim().isNotEmpty) {
      return shortName!;
    }

    final List<String> parts = name.split('/');
    return parts.isEmpty ? name : parts.last;
  }

  factory TorBoxTorrentFile.fromJson(Map<String, dynamic> json) {
    return TorBoxTorrentFile(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? 'Unknown file',
      size: (json['size'] as num?)?.toInt() ?? 0,
      shortName: json['short_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'size': size,
      'short_name': shortName,
    };
  }
}

class RealDebridUser {
  const RealDebridUser({
    required this.username,
    required this.email,
    required this.type,
    this.expiration,
  });

  final String username;
  final String email;
  final String type;
  final String? expiration;

  factory RealDebridUser.fromJson(Map<String, dynamic> json) {
    return RealDebridUser(
      username: _readString(json['username']) ?? 'Real-Debrid account',
      email: _readString(json['email']) ?? '',
      type: _readString(json['type']) ?? 'Unknown',
      expiration: _readString(json['expiration']),
    );
  }
}

class RealDebridTorrentFile {
  const RealDebridTorrentFile({
    required this.id,
    required this.path,
    required this.bytes,
    this.selected = false,
  });

  final int id;
  final String path;
  final int bytes;
  final bool selected;

  String get displayName {
    final List<String> parts = path.split(RegExp(r'[/\\]'));
    return parts.isEmpty ? path : parts.last;
  }

  factory RealDebridTorrentFile.fromJson(Map<String, dynamic> json) {
    return RealDebridTorrentFile(
      id: _readInt(json['id']) ?? 0,
      path: _readString(json['path']) ?? 'Unknown file',
      bytes: _readInt(json['bytes']) ?? 0,
      selected: _readInt(json['selected']) == 1,
    );
  }
}

class RealDebridTorrentInfo {
  const RealDebridTorrentInfo({
    required this.id,
    required this.filename,
    required this.hash,
    required this.bytes,
    required this.status,
    required this.files,
    required this.links,
  });

  final String id;
  final String filename;
  final String hash;
  final int bytes;
  final String status;
  final List<RealDebridTorrentFile> files;
  final List<String> links;

  factory RealDebridTorrentInfo.fromJson(Map<String, dynamic> json) {
    return RealDebridTorrentInfo(
      id: _readString(json['id']) ?? '',
      filename: _readString(json['filename']) ??
          _readString(json['original_filename']) ??
          'Real-Debrid torrent',
      hash: (_readString(json['hash']) ?? '').toLowerCase(),
      bytes: _readInt(json['bytes']) ?? _readInt(json['original_bytes']) ?? 0,
      status: _readString(json['status']) ?? '',
      files: ((json['files'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(RealDebridTorrentFile.fromJson)
          .toList(growable: false),
      links: ((json['links'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic item) => item.toString())
          .where((String item) => item.trim().isNotEmpty)
          .toList(growable: false),
    );
  }
}

class RealDebridResolvedLink {
  const RealDebridResolvedLink({
    required this.url,
    this.filename,
    this.filesize,
  });

  final String url;
  final String? filename;
  final int? filesize;

  factory RealDebridResolvedLink.fromJson(Map<String, dynamic> json) {
    return RealDebridResolvedLink(
      url: _readString(json['download']) ?? _readString(json['link']) ?? '',
      filename: _readString(json['filename']),
      filesize: _readInt(json['filesize']),
    );
  }
}

class TorBoxTorrent {
  const TorBoxTorrent({
    required this.id,
    required this.hash,
    required this.name,
    required this.size,
    required this.downloadState,
    required this.downloadSpeed,
    required this.progress,
    required this.files,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String hash;
  final String name;
  final int size;
  final String downloadState;
  final int downloadSpeed;
  final double progress;
  final List<TorBoxTorrentFile> files;
  final String? createdAt;
  final String? updatedAt;

  bool get isReady => progress >= 100;

  factory TorBoxTorrent.fromJson(Map<String, dynamic> json) {
    final double primaryProgress = (json['progress'] as num?)?.toDouble() ?? -1;
    final double secondaryProgress =
        (json['download_progress'] as num?)?.toDouble() ?? 0;
    final double rawProgress =
        primaryProgress >= 0 ? primaryProgress : secondaryProgress;

    return TorBoxTorrent(
      id: (json['id'] as num?)?.toInt() ?? 0,
      hash: (json['hash'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Unknown torrent',
      size: (json['size'] as num?)?.toInt() ?? 0,
      downloadState: (json['download_state'] as String?) ?? '',
      downloadSpeed: (json['download_speed'] as num?)?.toInt() ?? 0,
      progress: rawProgress <= 1 ? rawProgress * 100 : rawProgress,
      files: ((json['files'] as List<dynamic>?) ?? const <dynamic>[])
          .map(
            (dynamic item) =>
                TorBoxTorrentFile.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }
}

class AddonCatalogItem {
  const AddonCatalogItem({
    required this.id,
    required this.type,
    required this.name,
    this.poster,
    this.background,
    this.description,
    this.releaseInfo,
  });

  final String id;
  final String type;
  final String name;
  final String? poster;
  final String? background;
  final String? description;
  final String? releaseInfo;

  AddonCatalogItem copyWith({
    String? poster,
    String? background,
  }) {
    return AddonCatalogItem(
      id: id,
      type: type,
      name: name,
      poster: poster ?? this.poster,
      background: background ?? this.background,
      description: description,
      releaseInfo: releaseInfo,
    );
  }

  String get mediaType => type == 'series' ? 'tv' : type;

  factory AddonCatalogItem.fromJson(Map<String, dynamic> json) {
    return AddonCatalogItem(
      id: (json['id'] as String?) ?? '',
      type: (json['type'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      poster: json['poster'] as String?,
      background: json['background'] as String?,
      description: json['description'] as String?,
      releaseInfo: json['releaseInfo'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'type': type,
      'name': name,
      'poster': poster,
      'background': background,
      'description': description,
      'releaseInfo': releaseInfo,
    };
  }
}

class AddonMetaVideo {
  const AddonMetaVideo({
    required this.id,
    required this.name,
    required this.seasonNumber,
    required this.episodeNumber,
    this.numericId = 0,
    this.overview,
    this.thumbnail,
    this.seasonPoster,
    this.released,
    this.runtimeMinutes = 0,
    this.rating = 0,
  });

  final String id;
  final String name;
  final int seasonNumber;
  final int episodeNumber;
  final int numericId;
  final String? overview;
  final String? thumbnail;
  final String? seasonPoster;
  final String? released;
  final int runtimeMinutes;
  final double rating;

  factory AddonMetaVideo.fromJson(Map<String, dynamic> json) {
    final int episodeNumber =
        _readInt(json['episode']) ?? _readInt(json['number']) ?? 0;
    return AddonMetaVideo(
      id: _readString(json['id']) ?? '',
      name: _readString(json['name']) ??
          _readString(json['title']) ??
          (episodeNumber > 0 ? 'Episode $episodeNumber' : 'Episode'),
      seasonNumber: _readInt(json['season']) ?? 0,
      episodeNumber: episodeNumber,
      numericId: _readInt(json['tvdb_id']) ?? 0,
      overview:
          _readString(json['overview']) ?? _readString(json['description']),
      thumbnail: _readString(json['thumbnail']),
      seasonPoster: _readString(json['seasonPoster']) ??
          _readString(json['season_poster']),
      released:
          _readString(json['released']) ?? _readString(json['firstAired']),
      runtimeMinutes: _readMinutes(json['runtime']),
      rating: _readDouble(json['rating']) ?? 0,
    );
  }
}

class AddonMetaTrailer {
  const AddonMetaTrailer({
    required this.name,
    required this.key,
    this.site = 'YouTube',
    this.type = 'Trailer',
  });

  final String name;
  final String key;
  final String site;
  final String type;
}

class AddonMetaLink {
  const AddonMetaLink({
    required this.name,
    required this.category,
    required this.url,
  });

  final String name;
  final String category;
  final String url;

  factory AddonMetaLink.fromJson(Map<String, dynamic> json) {
    return AddonMetaLink(
      name: _readString(json['name']) ?? '',
      category: _readString(json['category']) ?? '',
      url: _readString(json['url']) ?? '',
    );
  }
}

class AddonMetaItem {
  const AddonMetaItem({
    required this.id,
    required this.type,
    required this.name,
    this.poster,
    this.background,
    this.logo,
    this.description,
    this.releaseInfo,
    this.runtime,
    this.genres = const <String>[],
    this.cast = const <String>[],
    this.director,
    this.country,
    this.language,
    this.status,
    this.videos = const <AddonMetaVideo>[],
    this.trailers = const <AddonMetaTrailer>[],
    this.links = const <AddonMetaLink>[],
    this.defaultVideoId,
    this.hasScheduledVideos = false,
  });

  final String id;
  final String type;
  final String name;
  final String? poster;
  final String? background;
  final String? logo;
  final String? description;
  final String? releaseInfo;
  final String? runtime;
  final List<String> genres;
  final List<String> cast;
  final String? director;
  final String? country;
  final String? language;
  final String? status;
  final List<AddonMetaVideo> videos;
  final List<AddonMetaTrailer> trailers;
  final List<AddonMetaLink> links;
  final String? defaultVideoId;
  final bool hasScheduledVideos;

  String get mediaType => type == 'series' ? 'tv' : type;

  factory AddonMetaItem.fromJson(Map<String, dynamic> json) {
    return AddonMetaItem(
      id: (json['id'] as String?) ?? '',
      type: (json['type'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      poster: json['poster'] as String?,
      background: json['background'] as String?,
      logo: json['logo'] as String?,
      description: _readString(json['description']),
      releaseInfo: _readString(json['releaseInfo']),
      runtime: _readString(json['runtime']),
      genres: _readStringList(json['genres']),
      cast: _readStringList(json['cast']),
      director: _readStringList(json['director']).join(', '),
      country: _readStringList(json['country']).join(', '),
      language: _readString(json['language']),
      status: _readString(json['status']),
      videos: ((json['videos'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(AddonMetaVideo.fromJson)
          .where((AddonMetaVideo video) =>
              video.seasonNumber >= 0 && video.episodeNumber > 0)
          .toList(growable: false),
      trailers: _readAddonTrailers(json),
      links: ((json['links'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(AddonMetaLink.fromJson)
          .where((AddonMetaLink link) => link.name.isNotEmpty)
          .toList(growable: false),
      defaultVideoId: _readString(
        (json['behaviorHints'] as Map<String, dynamic>?)?['defaultVideoId'],
      ),
      hasScheduledVideos: (json['behaviorHints']
              as Map<String, dynamic>?)?['hasScheduledVideos'] as bool? ??
          false,
    );
  }
}

class AddonCatalogRow {
  const AddonCatalogRow({
    required this.addonName,
    required this.catalogName,
    required this.catalog,
    required this.addon,
    required this.items,
  });

  final String addonName;
  final String catalogName;
  final AddonCatalog catalog;
  final AddonManifest addon;
  final List<AddonCatalogItem> items;
}

class AddonCatalog {
  const AddonCatalog({
    required this.type,
    required this.id,
    required this.name,
    this.extraNames = const <String>[],
    this.requiredExtraNames = const <String>[],
  });

  final String type;
  final String id;
  final String name;
  final List<String> extraNames;
  final List<String> requiredExtraNames;

  bool get supportsSearch => extraNames.contains('search');
  bool get hasRequiredExtras => requiredExtraNames.isNotEmpty;

  factory AddonCatalog.fromJson(Map<String, dynamic> json) {
    final Set<String> extraNames = <String>{};
    final Set<String> requiredExtraNames = <String>{};
    final dynamic rawExtra = json['extra'];
    if (rawExtra is List<dynamic>) {
      for (final dynamic value in rawExtra) {
        if (value is String) {
          extraNames.add(value);
        } else if (value is Map<String, dynamic> && value['name'] is String) {
          final String name = value['name'] as String;
          extraNames.add(name);
          if (value['isRequired'] == true) {
            requiredExtraNames.add(name);
          }
        }
      }
    }
    final dynamic rawSupported = json['extraSupported'];
    if (rawSupported is List<dynamic>) {
      extraNames.addAll(
        rawSupported.whereType<String>(),
      );
    }

    return AddonCatalog(
      type: (json['type'] as String?) ?? '',
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      extraNames: extraNames.toList(growable: false),
      requiredExtraNames: requiredExtraNames.toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'id': id,
      'name': name,
      'extra': extraNames
          .map((String name) => <String, dynamic>{
                'name': name,
                if (requiredExtraNames.contains(name)) 'isRequired': true,
              })
          .toList(growable: false),
      'extraSupported': extraNames,
    };
  }
}

class AddonResource {
  const AddonResource({
    required this.name,
    required this.types,
    required this.idPrefixes,
  });

  final String name;
  final List<String> types;
  final List<String> idPrefixes;

  factory AddonResource.fromDynamic(dynamic value) {
    if (value is String) {
      return AddonResource(
          name: value, types: const <String>[], idPrefixes: const <String>[]);
    }

    final Map<String, dynamic> json = value as Map<String, dynamic>;
    return AddonResource(
      name: (json['name'] as String?) ?? '',
      types: ((json['types'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(growable: false),
      idPrefixes: ((json['idPrefixes'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'types': types,
      'idPrefixes': idPrefixes,
    };
  }
}

class AddonManifest {
  const AddonManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.url,
    required this.originalUrl,
    this.description,
    this.types = const <String>[],
    this.catalogs = const <AddonCatalog>[],
    this.resources = const <AddonResource>[],
    this.idPrefixes = const <String>[],
    this.logo,
    this.background,
    this.enabled = true,
    this.configurable = false,
    this.configurationRequired = false,
  });

  final String id;
  final String name;
  final String version;
  final String? description;
  final String url;
  final String originalUrl;
  final List<String> types;
  final List<AddonCatalog> catalogs;
  final List<AddonResource> resources;
  final List<String> idPrefixes;
  final String? logo;
  final String? background;
  final bool enabled;
  final bool configurable;
  final bool configurationRequired;

  bool get hasStreamResource => resources.any(
        (AddonResource resource) => resource.name == 'stream',
      );

  bool get hasSubtitleResource => resources.any(
        (AddonResource resource) => resource.name == 'subtitles',
      );

  bool get hasMetaResource => resources.any(
        (AddonResource resource) => resource.name == 'meta',
      );

  List<String> get supportedMediaTypes {
    final Set<String> values = <String>{};
    for (final String type in types) {
      if (type.trim().isNotEmpty) {
        values.add(type.trim());
      }
    }
    for (final AddonResource resource in resources) {
      for (final String type in resource.types) {
        if (type.trim().isNotEmpty) {
          values.add(type.trim());
        }
      }
    }
    return values.toList(growable: false);
  }

  bool supportsContent(String mediaType, String id) {
    if (!hasStreamResource) {
      return false;
    }

    if (idPrefixes.isNotEmpty &&
        !idPrefixes.any((String prefix) => id.startsWith(prefix))) {
      return false;
    }

    final Iterable<AddonResource> streamResources = resources.where(
      (AddonResource resource) => resource.name == 'stream',
    );
    for (final AddonResource resource in streamResources) {
      if (resource.types.isNotEmpty &&
          !resource.types.contains(mediaType) &&
          !(mediaType == 'series' && resource.types.contains('tv'))) {
        continue;
      }

      if (resource.idPrefixes.isNotEmpty &&
          !resource.idPrefixes.any((String prefix) => id.startsWith(prefix))) {
        continue;
      }

      return true;
    }

    return streamResources.isEmpty;
  }

  bool supportsMeta(String mediaType, String id) {
    final String stremioType = mediaType == 'tv' ? 'series' : mediaType;
    if (!hasMetaResource) {
      return catalogs
          .any((AddonCatalog catalog) => catalog.type == stremioType);
    }

    if (idPrefixes.isNotEmpty &&
        !idPrefixes.any((String prefix) => id.startsWith(prefix))) {
      return false;
    }

    final Iterable<AddonResource> metaResources = resources.where(
      (AddonResource resource) => resource.name == 'meta',
    );
    for (final AddonResource resource in metaResources) {
      if (resource.types.isNotEmpty &&
          !resource.types.contains(stremioType) &&
          !(stremioType == 'series' && resource.types.contains('tv'))) {
        continue;
      }

      if (resource.idPrefixes.isNotEmpty &&
          !resource.idPrefixes.any((String prefix) => id.startsWith(prefix))) {
        continue;
      }

      return true;
    }
    return false;
  }

  factory AddonManifest.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> behaviorHints =
        json['behaviorHints'] as Map<String, dynamic>? ??
            const <String, dynamic>{};

    return AddonManifest(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Unknown addon',
      version: (json['version'] as String?) ?? '0.0.0',
      description: json['description'] as String?,
      url: (json['url'] as String?) ?? '',
      originalUrl: (json['originalUrl'] as String?) ?? '',
      types: ((json['types'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(growable: false),
      catalogs: ((json['catalogs'] as List<dynamic>?) ?? const <dynamic>[])
          .map(
            (dynamic item) =>
                AddonCatalog.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      resources: ((json['resources'] as List<dynamic>?) ?? const <dynamic>[])
          .map(AddonResource.fromDynamic)
          .toList(growable: false),
      idPrefixes: ((json['idPrefixes'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(growable: false),
      logo: json['logo'] as String?,
      background: json['background'] as String?,
      enabled: json['enabled'] as bool? ?? true,
      configurable: behaviorHints['configurable'] as bool? ?? false,
      configurationRequired:
          behaviorHints['configurationRequired'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'version': version,
      'description': description,
      'url': url,
      'originalUrl': originalUrl,
      'types': types,
      'catalogs': catalogs.map((AddonCatalog item) => item.toJson()).toList(),
      'resources':
          resources.map((AddonResource item) => item.toJson()).toList(),
      'idPrefixes': idPrefixes,
      'logo': logo,
      'background': background,
      'enabled': enabled,
      'behaviorHints': <String, dynamic>{
        'configurable': configurable,
        'configurationRequired': configurationRequired,
      },
    };
  }
}

class SourceSearchDiagnostics {
  const SourceSearchDiagnostics({
    this.sourceCounts = const <String, int>{},
    this.sourceErrors = const <String, String>{},
  });

  final Map<String, int> sourceCounts;
  final Map<String, String> sourceErrors;
}

class StreamSource {
  const StreamSource({
    required this.id,
    required this.provider,
    required this.sourceDisplayName,
    required this.title,
    required this.description,
    required this.quality,
    required this.sizeLabel,
    required this.isCached,
    this.cacheProvider,
    this.addonId,
    this.infoHash,
    this.directUrl,
    this.fileIndex,
    this.fileName,
    this.videoSizeBytes,
    this.magnetUri,
    this.sourceTrackers = const <String>[],
    this.streamHeaders = const <String, String>{},
  });

  final String id;
  final String provider;
  final String sourceDisplayName;
  final String title;
  final String description;
  final String quality;
  final String sizeLabel;
  final bool isCached;
  final String? cacheProvider;
  final String? addonId;
  final String? infoHash;
  final String? directUrl;
  final int? fileIndex;
  final String? fileName;
  final int? videoSizeBytes;
  final String? magnetUri;
  final List<String> sourceTrackers;
  final Map<String, String> streamHeaders;

  bool get isDirectUrl => directUrl != null && directUrl!.isNotEmpty;
  bool get isTorBoxCached => (cacheProvider ?? '').contains('TB+');
  bool get isRealDebridCached => (cacheProvider ?? '').contains('RD+');
  bool get hasTorrentSource =>
      (infoHash != null && infoHash!.isNotEmpty) ||
      (magnetUri != null && magnetUri!.isNotEmpty);

  factory StreamSource.fromJson(Map<String, dynamic> json) {
    return StreamSource(
      id: json['id'] as String,
      provider: json['provider'] as String,
      sourceDisplayName: json['sourceDisplayName'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      quality: json['quality'] as String? ?? 'Unknown',
      sizeLabel: json['sizeLabel'] as String? ?? '',
      isCached: json['isCached'] as bool? ?? false,
      cacheProvider: json['cacheProvider'] as String?,
      addonId: json['addonId'] as String?,
      infoHash: json['infoHash'] as String?,
      directUrl: json['directUrl'] as String?,
      fileIndex: (json['fileIndex'] as num?)?.toInt(),
      fileName: json['fileName'] as String?,
      videoSizeBytes: (json['videoSizeBytes'] as num?)?.toInt(),
      magnetUri: json['magnetUri'] as String?,
      sourceTrackers:
          ((json['sourceTrackers'] as List<dynamic>?) ?? const <dynamic>[])
              .map((dynamic item) => item.toString())
              .toList(growable: false),
      streamHeaders: ((json['streamHeaders'] as Map<String, dynamic>?) ??
              const <String, dynamic>{})
          .map(
        (String key, dynamic value) => MapEntry<String, String>(
          key,
          value.toString(),
        ),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'provider': provider,
      'sourceDisplayName': sourceDisplayName,
      'title': title,
      'description': description,
      'quality': quality,
      'sizeLabel': sizeLabel,
      'isCached': isCached,
      'cacheProvider': cacheProvider,
      'addonId': addonId,
      'infoHash': infoHash,
      'directUrl': directUrl,
      'fileIndex': fileIndex,
      'fileName': fileName,
      'videoSizeBytes': videoSizeBytes,
      'magnetUri': magnetUri,
      'sourceTrackers': sourceTrackers,
      'streamHeaders': streamHeaders,
    };
  }
}

int? _readInt(dynamic value) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}

String? _readString(dynamic value) {
  final String text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

List<String> _readStringList(dynamic value) {
  if (value is List<dynamic>) {
    return value
        .map((dynamic item) => item.toString().trim())
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
  }
  final String? single = _readString(value);
  return single == null ? const <String>[] : <String>[single];
}

double? _readDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '');
}

int _readMinutes(dynamic value) {
  if (value is num) {
    return value.toInt();
  }
  final String text = value?.toString() ?? '';
  final Match? hours = RegExp(r'(\d+)\s*h').firstMatch(text);
  final Match? minutes = RegExp(r'(\d+)\s*m').firstMatch(text);
  if (hours != null || minutes != null) {
    return (int.tryParse(hours?.group(1) ?? '') ?? 0) * 60 +
        (int.tryParse(minutes?.group(1) ?? '') ?? 0);
  }
  return int.tryParse(RegExp(r'\d+').firstMatch(text)?.group(0) ?? '') ?? 0;
}

List<AddonMetaTrailer> _readAddonTrailers(Map<String, dynamic> json) {
  final List<AddonMetaTrailer> trailers = <AddonMetaTrailer>[];
  final Set<String> seen = <String>{};

  void addTrailer({
    required String? key,
    required String? name,
    String? type,
  }) {
    final String normalizedKey = (key ?? '').trim();
    if (normalizedKey.isEmpty || !seen.add(normalizedKey)) {
      return;
    }
    final String normalizedName = (name ?? '').trim();
    final String normalizedType = (type ?? '').trim();
    trailers.add(
      AddonMetaTrailer(
        name: normalizedName.isEmpty ? 'Trailer' : normalizedName,
        key: normalizedKey,
        type: normalizedType.isEmpty ? 'Trailer' : normalizedType,
      ),
    );
  }

  for (final Map<String, dynamic> trailer
      in ((json['trailers'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()) {
    addTrailer(
      key: _readString(trailer['source']) ?? _readString(trailer['ytId']),
      name: _readString(trailer['name']) ?? _readString(trailer['type']),
      type: _readString(trailer['type']),
    );
  }
  for (final Map<String, dynamic> trailer
      in ((json['trailerStreams'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()) {
    addTrailer(
      key: _readString(trailer['ytId']) ?? _readString(trailer['source']),
      name: _readString(trailer['title']),
    );
  }
  return trailers;
}

class MagnetHistoryItem {
  const MagnetHistoryItem({
    required this.hash,
    required this.addedAt,
  });

  final String hash;
  final int addedAt;

  factory MagnetHistoryItem.fromJson(Map<String, dynamic> json) {
    return MagnetHistoryItem(
      hash: (json['hash'] as String?) ?? '',
      addedAt: (json['addedAt'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'hash': hash,
      'addedAt': addedAt,
    };
  }
}
