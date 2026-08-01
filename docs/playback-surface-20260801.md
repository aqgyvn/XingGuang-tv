# Playback Surface - 2026-08-01

## Scope

This update addresses darker ExoPlayer video output reported on Android phones, especially for HEVC and HDR content.

## Root Cause

- The phone VOD layout forced ExoPlayer to render through `TextureView`.
- `TextureView` participates in application-window composition. On some Android devices this can prevent the decoder's HDR dataspace or system tone mapping from reaching the display correctly, producing compressed dark detail.
- The playback control root is transparent and does not apply a full-frame dark overlay.
- The supplied comparison screenshots use different source routes, so they demonstrate the symptom but are not a controlled pixel-for-pixel color test.

## Change

- Use Media3 `SurfaceView` output for phone VOD ExoPlayer playback.
- Keep the phone live layout, tablet layout, IJK renderer and MPV renderer unchanged.
- Keep the existing 8-bit incomplete-SDR BT.709 metadata correction unchanged.
- Do not add a brightness, gamma or contrast filter and do not rewrite explicit HDR metadata.

## Verification

- The mobile arm64 debug build completes successfully.
- MuMu Android 15 creates a `1080 x 675` ExoPlayer surface and plays the public adaptive HLS stream through `OMX.qcom.video.decoder.avc`.
- The stream reports `BT709/Limited range/SDR SMPTE 170M/8/8` and adapts from `848 x 480` to `1280 x 720`.
- Portrait playback, fullscreen playback, playback controls, the video-track menu, fullscreen exit and return to Home render correctly above the video surface.
- No app crash, inflation failure or playback failure occurred during the successful public-stream regression run.
- The final `563 / 5.6.3` APK passes APK Signature Scheme v2 verification and installs over existing MuMu application data.
- Deliverable: `output/XingGuang-5.6.3-arm64.apk`, `82,618,722` bytes, SHA-256 `6BCA2103E555EBF9630F8A97A274FE6933EF435C7DC1008402F32454BC2F8B77`.
- MuMu does not provide the target phone's HDR display pipeline. Final brightness confirmation requires the same route, episode and timestamp on the user's physical device and comparison player.

## Rollback

Before committing, change `app:surface_type` in `app/src/mobile/res/layout/activity_video.xml` from `surface_view` back to `texture_view`, restore release metadata and remove this document. After a single fix commit, use `git revert <commit>`.
