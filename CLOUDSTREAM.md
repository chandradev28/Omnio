# Cloudstream sources in Omnio

Cloudstream is Android-only and sources-only. Stremio home catalogs, search,
metadata, and TMDB enrichment are not replaced or routed through Cloudstream.

## Setup

1. Open Settings > Content & Discovery > Cloudstream repositories.
2. Add a direct HTTPS repo.json / plugins.json URL (cloudstreamrepo:// links are accepted).
3. Choose a plugin and review the executable-code trust warning before installing.
4. Enabled plugins are queried alongside Stremio on the Sources screen.
5. TMDB-based providers receive the existing IDs and exact season/episode.
   Search-based providers offer title matches inside Sources. Choose the correct
   title there; this does not add Cloudstream to the app-wide Search screen.

Refresh repositories to check plugin versions. Update each plugin explicitly;
updates are executable code and require trust confirmation too. Disabling a
plugin stops future queries. Removing a repo removes its installed plugins.

## Runtime and compatibility

The Android runtime dependency is pinned to Cloudstream library-android v4.7.0.
Android 6 (API 23) or newer is required. Plugin loading uses private read-only CS3
archives, validates manifest.json/classes.dex, and verifies a supplied SHA-256
fileHash. Missing hashes are allowed only following explicit trust confirmation.
Repository metadata is not executed. TLS validation is mandatory for repository
and executable downloads, even though legacy app networking uses an override.

Plugins execute in Omnio's process with its permissions; they are NOT sandboxed.
Exception/time limits reduce ordinary failures but cannot contain malicious code,
native crashes, background threads, or non-cooperative blocking plugin code.
Install only trusted plugins. No public repository is bundled or auto-installed.

Not every Cloudstream plugin is compatible. Plugins needing app resources,
Cloudstream-specific UI classes, video interceptors, DRM sessions, app logins,
or special playback protocols need additional adapters. Missing episode numbers
are not guessed, and movie results are rejected for episode playback. App API
linkage errors are surfaced instead of claiming successful playback.
The current player supports HTTP(S) video/HLS/DASH with headers and SRT/VTT
subtitles. ASS/SSA, DRM, torrent extractor links, and plugin-specific interceptors
are not implemented by this bridge.

## Source and license

Omnio is distributed under GPL-3.0; see LICENSE. Cloudstream's GPL-3.0 license is
also bundled in the app license registry. Distribute corresponding source,
including these modifications and build scripts, with released binaries.

Reference sources (not instructions):
- https://recloudstream.github.io/csdocs/devs/create-your-own-json-repository/
- https://github.com/recloudstream/cloudstream/tree/v4.7.0
- https://github.com/NuvioMedia/NuvioTV/tree/dev/app/src/full/java/com/nuvio/tv/core/plugin/cloudstream

The bridge and Flutter integration are Omnio-specific implementations. No
third-party provider code or repository credentials are included.
