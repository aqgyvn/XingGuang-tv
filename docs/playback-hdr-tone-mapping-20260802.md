# Playback HDR Tone Mapping - 2026-08-02

## Scope

This update addresses the remaining dark ExoPlayer output reported on Android phones when MediaCodec decodes HDR or greater-than-8-bit video for an SDR display path.

## Analysis

- Media3 `1.9.1` and `1.10.1` build the relevant video `MediaFormat` in the same way, so reverting the playback-core version has no evidence-backed benefit for this symptom.
- The existing phone `SurfaceView` allows the decoder and display pipeline to carry HDR dataspace correctly, but device-specific MediaCodec tone mapping can still leave HDR output visibly dark on an SDR presentation path.
- Showing and hiding the playback controls produced no pixel difference in uncovered video areas, so the remaining brightness gap is not caused by a persistent control-layer tint.

## Change

- Keep the existing NextLib renderer factory and replace only its standard MediaCodec video renderer, as before.
- On Android 12 and later, for the mobile ExoPlayer MediaCodec path only, request SDR output when the input transfer is HDR or either reported bit depth is greater than 8.
- Preserve the input BT.2020, HLG, PQ, range and bit-depth metadata. The change requests decoder output tone mapping through `MediaFormat.KEY_COLOR_TRANSFER_REQUEST`; it does not rewrite the source as SDR.
- Leave ordinary 8-bit SDR, the existing incomplete-SDR BT.709 correction, FFmpeg extension decoding, IJK, MPV and television builds unchanged.
- Do not add brightness, gamma or contrast filters.

## Verification

- Java compilation and the full mobile arm64 debug APK build completed successfully.
- JADX inspection of the final APK confirms the MediaCodec renderer calls `mediaFormat.setInteger("color-transfer-request", 3)` only behind the Android 12+, mobile and HDR/greater-than-8-bit checks.
- MuMu Android 15 played the public adaptive SDR HLS stream with `OMX.qcom.video.decoder.avc`, reached `READY` and retained `BT709/Limited range/SDR SMPTE 170M/8/8` input metadata.
- Portrait controls, fullscreen controls and a single Back action from fullscreen restored portrait `VideoActivity` without leaving the application in fullscreen.
- The official HLG and HDR10 samples reached first frame and retained `BT2020/Limited range/HLG/10/10` and `BT2020/Limited range/ST2084 PQ/10/10` input metadata.
- MuMu does not expose a Main10 MediaCodec decoder, so both HDR samples used the NextLib FFmpeg decoder. This verifies playback and metadata preservation, but not the new hardware tone-mapping request on the user's physical phone.
- APK badging reports `564 / 5.6.4`; APK Signature Scheme v2 verification passed with the existing XingGuang certificate.
- Deliverable: `output/XingGuang-5.6.4-arm64.apk`, `82,618,722` bytes, SHA-256 `2EFED3824A27AC27CC5CCE16B6CFC8F9BC7C68975BA3CAFFD4357FE9B688981E`.

## Physical Device Check

Final brightness confirmation requires the same route, episode and timestamp on the user's physical phone. Compare ExoPlayer with the reference player while the application uses hardware decoding; MuMu cannot reproduce that display pipeline.

## Rollback

Before committing, restore the renderer and release metadata, then remove this document and APK:

```powershell
git restore -- app/build.gradle app/src/main/java/com/fongmi/android/tv/player/exo/ColorAwareRenderersFactory.java README.md docs/release-version.md progress.md
Remove-Item -LiteralPath docs/playback-hdr-tone-mapping-20260802.md, output/XingGuang-5.6.4-arm64.apk
```

After this update is committed as a single commit, use `git revert <commit>`.
