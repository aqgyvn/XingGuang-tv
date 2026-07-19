# 05 Cloud White Light System UI

## Business Conclusion

The mobile build has been moved from the paper-black playlist style to the `05` cloud-white light system direction.

## Scope

- VOD library surfaces now use a white and blue-gray palette.
- The continue-watching block is a light blue priority area.
- VOD cards, search results, receive dialog posters, chips, rows, and settings panels use the same cloud-white tokens.
- The recent playback page uses an opaque cloud-white root, toolbar, and content background so previously opened pages cannot show through.
- Light pages use dark system-bar icons over a solid white status bar, while VOD/live playback pages keep light system-bar icons over black video surfaces.
- VOD grid cards use a compact single-line marquee title area so recent playback cards stay shorter while long names can scroll.
- VOD poster status labels use an opaque dark background, white text, and bounded ellipsis so episode updates remain readable over any poster artwork.
- The continue-watching player-engine marker uses a light slate chip instead of the poster-overlay style, avoiding a heavy black block inside the cloud-white card.
- Settings source action icons are tinted with the cloud-white dark icon color so home/history/refresh controls remain visible on white cards.
- Settings no longer expose wallpaper configuration controls; wallpaper loading remains an internal home-background capability.
- Search and keep/favorites pages use opaque cloud-white roots and toolbars so previous pages or wallpaper images cannot bleed through empty or chip states.
- Returning from live playback restores the normal portrait Home page and system bars instead of leaving the app in fullscreen or landscape mode.
- Launcher and startup visuals now use the same cloud-white blue/green playback icon instead of the older prism-star icon.
- Playback settings use dark section labels and state-aware button text so controls remain readable on the light bottom sheet.
- Playback settings expose separate `广告过滤` and `广告URL拦截` controls instead of the previous combined `智能去广` row.
- The mobile app no longer checks or downloads updates from the upstream FongMi release channel; the Settings version row is informational only.
- VOD and live playback surfaces remain black so video contrast is preserved.
- The user-facing mobile APK version is now `550 / 5.5.0`.

## Verification

Use:

```powershell
.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace
```

Output APK:

```text
D:\xingkong\app\build\outputs\apk\mobileArm64_v8a\debug\mobile-arm64_v8a.apk
```
## 5.5.1 Playback Compatibility

- Exo HLS ad filtering now runs inside Media3 and preserves the original CDN URL instead of exposing a localhost `/adm3u8` playback address.
- IJK and MPV behavior is unchanged.
## 5.5.2 System Navigation Bar

- Light application pages explicitly use the cloud-white surface color for the system navigation bar after edge-to-edge setup.
- Fullscreen video pages retain transparent immersive system bars.
## 5.5.3 Green UI Removal

- Normal pages and bottom sheets use opaque cloud-white system navigation bars.
- VOD and live fullscreen pages use opaque black system bars when transient bars are revealed; hidden immersive behavior is unchanged.
- The mobile activity base no longer mounts `CustomWallView`, removing the built-in wallpaper fallback that could show through transparent transition frames.
- App-owned green status labels, generated placeholder colors, and launcher vector accents were replaced with dark or blue tokens.
- Video frames, posters, source icons, and remote artwork keep their original content colors.
## 5.5.4 Player Controls

- Removed the mobile wallpaper view insertion from the activity base instead of only disabling it through a flag.
- VOD and live control roots are transparent, so showing playback controls no longer applies a full-frame color overlay to the video.
- Individual control buttons retain their own bounded backgrounds for visibility without recoloring the whole frame.
## 5.5.5 Bottom Navigation Seam

- Removed the full-outline stroke from the mobile bottom navigation background.
- The bottom navigation surface now joins the white system navigation-bar area without the unintended blue-gray line; the page-level cloud-blue background is unchanged.

## 5.5.6 Portrait Player Height

- Increased the phone portrait VOD player height from `150dp` to `225dp`, exactly 50% larger.
- Landscape fullscreen behavior and the separate large-screen layout are unchanged.

## 5.5.7 Track Menu Readability

- Subtitle, video-track, and audio-track bottom-sheet titles now use the cloud-white dark text color.
- Track rows use the existing state-aware text selector, keeping normal rows dark and selected rows blue on the light menu surface.

## 5.5.8 Search Result Play Badge

- The dark playback badge in mobile search-result cards now uses white text instead of the dark state selector.
- Source badges, card dimensions, poster content, and search behavior are unchanged.

## 5.5.9 Blue Search Play Badge

- Replaced the visually heavy black search-result playback badge with a dedicated cloud-white primary-blue badge and white text.
- Kept the adjacent source badge light blue and preserved the compact card spacing and dimensions.
