# Launcher And Splash Refresh - 2026-07-09

## Scope

- Replaced the launcher PNG resources with a cloud-white blue/green playback mark.
- Kept the same Android resource names so the app icon, home logo, shortcut icon, and package manifest continue to resolve through `@mipmap/ic_launcher`.
- Changed the mobile startup splash to use the same `@mipmap/ic_launcher` resource as the app icon on a white surface.

## Version

- APK version after this change: `545 / 5.4.5`

## Verification

- Build passed with `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.
- APK badging reported `versionCode='545'`, `versionName='5.4.5'`, and launcher icons from `res/mipmap-*/ic_launcher.png`.
- APK resources showed `Theme.Splash` using `@mipmap/ic_launcher` and `@color/xg_surface` for the splash background.
- MuMu installed the APK successfully and launched to `HomeActivity`.
- Startup recording was retained at `tmp/launcher_splash_20260709/splash-545.mp4`.
- Extracted APK launcher icons were retained at `tmp/launcher_splash_20260709/apk-icons-545/`.
- App-PID-scoped logcat contained no crash, AndroidRuntime, resource-not-found, or inflate-failure matches.

## Rollback

Old launcher PNG resources were backed up before replacement:

```text
archive/launcher-splash-backup-20260709-v543/
```

To roll back, copy that backup directory's files back to the same relative paths, restore `app/build.gradle` and `docs/release-version.md` to `543 / 5.4.3`, then rebuild.
