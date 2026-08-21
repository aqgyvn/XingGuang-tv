# Playback Color - 2026-07-28

## Scope

This update corrects dark ExoPlayer output for 8-bit SDR video whose stream omits color-space, color-range and transfer metadata.

## Root Cause

- The affected HLS stream was reported as `NA/NA/NA/8/8` by Media3.
- ExoPlayer passed the incomplete format to the device MediaCodec decoder. Device-specific dataspace assumptions then produced darker output than the IJK FFmpeg software conversion path.
- The activity window, player controls and overlay layers were shared across player cores and did not contain a persistent dark tint.

## Change

- Keep the existing NextLib renderer factory and FFmpeg extension ordering.
- Replace only the standard ExoPlayer MediaCodec video renderer with a color-aware subclass.
- For formats whose three dataspace fields are all unspecified, whose luma and chroma bit depths are both 8, and which Media3 considers equivalent to assumed SDR, supply BT.709, limited range and SDR transfer metadata before codec configuration.
- Preserve all explicit BT.601, BT.709, BT.2020, full-range, HDR and 10-bit metadata.
- Do not apply a brightness filter, force software decoding or change the IJK and MPV render paths.

## Verification

- Java compilation and the final mobile arm64 debug APK build completed successfully.
- MuMu Android 15 installed the final `562 / 5.6.2` build over existing app data.
- The affected HLS stream remained on `OMX.qcom.video.decoder.avc` and its Media3 input format changed from `NA/NA/NA/8/8` to `BT709/Limited range/SDR SMPTE 170M/8/8`.
- The corrected metadata remained present when adaptive playback changed from 848x480 to 1280x720.
- IJK remained on its FFmpeg `yuv420p` to `RV32` path. A transient emulator DNS failure interrupted the first comparison retry; playback and first-frame decoding succeeded after DNS resolution recovered.
- MPV could not be compared on this emulator because its native library does not load and the application falls back to ExoPlayer.
- APK Signature Scheme v2 verification passed with the existing XingGuang signing certificate.
- Temporary test-stream history was removed, the default EXO core was restored and the application returned to `HomeActivity`.
- Deliverable: `output/XingGuang-5.6.2-arm64.apk`, `82,618,718` bytes, SHA-256 `2A92E6733DF60FD3CE4B84746435E20AB179CA983C21C347E63BD7FC4919E038`.

## Rollback

Before committing, restore the release metadata and renderer selection, then remove the new renderer and this document:

```powershell
git restore -- app/build.gradle app/src/main/java/com/fongmi/android/tv/player/exo/ExoUtil.java README.md docs/release-version.md
Remove-Item -LiteralPath app/src/main/java/com/fongmi/android/tv/player/exo/ColorAwareRenderersFactory.java, docs/playback-color-20260728.md
```

After this update is committed as a single commit, use `git revert <commit>`.
