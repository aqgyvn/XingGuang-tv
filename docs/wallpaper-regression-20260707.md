# Wallpaper Regression Verification - 2026-07-07

## Scope

This pass fixes the mobile wallpaper feature when the saved wallpaper config points to a local external-storage file such as `file://v532_setting.png`.

## What Changed

- Local file path resolution now handles `file://name.png`, `file://Download/name.png`, and `file:///storage/emulated/0/name.png`.
- The wallpaper image view is made visible when loading built-in, image, GIF, or video wallpaper snapshots.
- The mobile home activity root background is transparent so the existing `CustomWallView` behind the page can actually show through.
- APK version was bumped to `versionCode=533` and `versionName=5.3.3`.

## MuMu Verification

- Installed APK: `app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk`.
- Device package state reported `versionCode=533` and `versionName=5.3.3`.
- Current saved wallpaper config was `file://v532_setting.png`.
- Source file existed at `/sdcard/v532_setting.png`.
- After clearing internal wallpaper files and tapping the wallpaper refresh button, the app regenerated:
  - `files/wallpaper_0`
  - `files/wallpaper_cache`
- SHA-256 matched between the external source and internal wallpaper copy:
  - `/sdcard/v532_setting.png`: `fea3650afe863574cca33f8f7ae4dee61ba64a3f6b4575a8b247121ad83bf956`
  - `files/wallpaper_0`: `fea3650afe863574cca33f8f7ae4dee61ba64a3f6b4575a8b247121ad83bf956`
- UI dump showed `com.xingguang.video:id/image` visible behind the setting page and `wallUrl` still displaying `file://v532_setting.png`.
- Post-refresh logcat check found no `FATAL EXCEPTION`, `E AndroidRuntime`, `Resources$NotFoundException`, `InflateException`, `ANR in`, `UnsatisfiedLinkError`, `dlopen failed`, `NoSuchMethodError`, `NoClassDefFoundError`, `FileNotFoundException`, or `error_config_get`.

## APK

- APK path: `app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk`
- APK SHA-256: `3C8C78D54FB93AA7E1C4477F951777CFA5440C9EE4286ED184E4A16A6BA6E043`
- Signing certificate SHA-256: `775b4b773f689575d436784b1b2f7b3f08e8e8bef6ab11276928c752c783da24`

## Evidence

- `tmp/wallpaper-v533/setting_before_refresh.xml`
- `tmp/wallpaper-v533/setting_refreshed.xml`
- `tmp/wallpaper-v533/setting_refreshed.png`
