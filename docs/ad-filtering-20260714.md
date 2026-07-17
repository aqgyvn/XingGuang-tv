# Ad Filtering Controls

## Business Behavior

- `广告过滤` controls HLS/M3U8 playlist purification before playback.
- `广告URL拦截` controls ad-domain rules inside the hidden parsing WebView.
- The two controls are independent and default to the previous `智能去广` preference for existing installs.

## HLS Filtering Scope

- ExoPlayer filters HLS media playlists inside Media3 while keeping the original CDN URL and request headers.
- IJK and MPV keep using the local playlist service when HLS filtering is enabled.
- Master playlists, relative segment URLs, KEY/MAP URIs, and child playlists are rewritten to valid absolute URLs.
- Minority segment sources are removed only when one URL source pattern accounts for at least 85% of the playlist and removed duration is no more than 50% of total duration.
- Playlist downloads are limited to 1 MiB. Exo filtering failures fall back to Media3's original parser input; local proxy failures redirect playback to the original HLS URL.
- MP4, local files, and non-HLS live streams are not changed.

## NewBox 1.5.5 Sync

- Synchronized the confirmed Exo in-player playlist parser mechanism from the 2026-07-14 APK analysis.
- The analyzed Exo HTTP interceptors contain no CDN-specific Referer removal rule. The reported false 403 fix is therefore attributed to avoiding the localhost playlist proxy for Exo requests, not to a copied host blacklist.
- MPV proxy behavior remains unchanged because the latest APK still retains its `/mpvhls` path.

## Intentional Limitation

The implementation does not copy NewBox's MPV MPEG-TS PTS/PCR rewriting and segment prefetch cache. That path requires a separate transport layer and has a higher playback-regression risk; this release implements the independently testable M3U8 layer only.

## Build Note

`beautifulsoup4` is pinned to `4.13.4` because Chaquopy 13.1 fails while packaging the unpinned `4.15.0` release with a duplicate `_html5lib.py` output. This keeps the documented standard Gradle build reproducible.
