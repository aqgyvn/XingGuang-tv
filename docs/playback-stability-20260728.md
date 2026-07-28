# Playback Stability - 2026-07-28

## Scope

This update fixes repeated buffering on adaptive streams and unreliable recent-playback persistence.

## Root Causes

- ExoPlayer forced the highest supported bitrate, so adaptive HLS streams could not step down when bandwidth changed.
- Playback history was written only when both position and duration were greater than zero. Exiting during startup or buffering skipped the database write.
- History timestamps were updated by the playback clock only after the player became ready, so early exits could produce records outside the recent-history query.
- The asynchronous save read the mutable activity field after it was queued, allowing a later source or episode change to affect the pending write.

## Changes

- Restored ExoPlayer adaptive bitrate selection. Existing manual track overrides are unchanged.
- Save history from `onStop`, with `onDestroy` retained as a fallback when `onStop` did not run.
- Synchronize valid player position and duration before saving, while allowing a selected episode to persist when either value is still unknown.
- Always stamp the save with the current time and pass an immutable JSON snapshot to the existing background executor.
- Keep incognito mode excluded from all history writes.

## Verification

- `:app:assembleMobileArm64_v8aDebug` completed successfully.
- MuMu Android 15 installed the APK with existing app data preserved.
- A five-variant HLS stream ranging from 246 Kbps to 6.2 Mbps selected about 836 Kbps instead of the highest variant.
- The adaptive stream played for 60 seconds without another `BUFFERING` transition or playback error.
- Returning before media preparation created a recent record with the selected episode and a current timestamp even though position and duration were unknown.
- Normal playback exit updated the same record to position `8949` ms and duration `2725056` ms.
- Temporary verification records were removed after testing.
- The final APK reports `versionCode 561 / versionName 5.6.1`, installed successfully over the existing MuMu app data and launched to `HomeActivity`.
- Opening an existing recent item reached `VideoActivity`; returning while it was still buffering refreshed that history row without a crash or database error.
- Deliverable: `output/XingGuang-5.6.1-arm64.apk`, `82,618,718` bytes, SHA-256 `065E1091D22A7E3B41F09D617597A8C25129B0579507797C052524F9C39BA6FA`.

## Rollback

Before committing, restore the modified tracked files and remove this document:

```powershell
git restore -- app/build.gradle app/src/main/java/com/fongmi/android/tv/player/exo/ExoUtil.java app/src/mobile/java/com/fongmi/android/tv/ui/activity/VideoActivity.java README.md docs/release-version.md progress.md
Remove-Item -LiteralPath docs/playback-stability-20260728.md
```

After this update is committed as a single commit, use `git revert <commit>`.
