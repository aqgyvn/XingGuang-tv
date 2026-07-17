# Launcher Icon Replacement - 2026-07-07

## Source

- Source image: `C:\Users\52396\Desktop\1.png`
- Source size: `2816x1536`
- Visible alpha crop: `[758,101]-[2058,1434]`, `1301x1334`
- Generated square crop: side `1334`, top-left `[742,101]`

## Applied Resources

The new icon was generated into the existing launcher resource sizes:

- `app/src/main/ic_launcher-playstore.png`: `512x512`
- `app/src/main/res/mipmap-mdpi/ic_launcher.png`: `48x48`
- `app/src/main/res/mipmap-mdpi/ic_launcher_round.png`: `48x48`
- `app/src/main/res/mipmap-hdpi/ic_launcher.png`: `72x72`
- `app/src/main/res/mipmap-hdpi/ic_launcher_round.png`: `72x72`
- `app/src/main/res/mipmap-xhdpi/ic_launcher.png`: `96x96`
- `app/src/main/res/mipmap-xhdpi/ic_launcher_round.png`: `96x96`
- `app/src/main/res/mipmap-xxhdpi/ic_launcher.png`: `144x144`
- `app/src/main/res/mipmap-xxhdpi/ic_launcher_round.png`: `144x144`
- `app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`: `192x192`
- `app/src/main/res/mipmap-xxxhdpi/ic_launcher_round.png`: `192x192`

The mobile launcher, splash icon, home logo, and live shortcut all continue to use `@mipmap/ic_launcher`, so no layout or manifest icon reference was changed.

## Version

- APK version after this change: `525 / 5.2.5-noad`

## Verification

- Build passed: `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.
- APK badging reported `versionCode='525'` and `versionName='5.2.5-noad'`.
- APK badging reported application icon resources from `res/mipmap-mdpi-v4/ic_launcher.png` through `res/mipmap-xxxhdpi-v4/ic_launcher.png`.
- APK extraction confirmed packaged launcher and round launcher PNG sizes match the source resources.
- MuMu instance `0` was started through `mumu-cli.exe`; `mumu-cli adb --vmindex 0` installed the APK successfully with `install -r`.
- Device package state reported `versionCode=525` and `versionName=5.2.5-noad`.
- Launch passed: current focus reached `com.fongmi.android.tv.ui.activity.HomeActivity`.
- Home UI dump showed the top-left `logo` view present at `[84,150][186,252]`, which uses `@mipmap/ic_launcher` in `fragment_vod.xml`.
- Logcat after install and launch showed no `FATAL EXCEPTION`, `E AndroidRuntime`, `Resources$NotFoundException`, `InflateException`, `ANR`, `UnsatisfiedLinkError`, or `dlopen failed`.

## Evidence

- `tmp/launcher_icon_v525_apk/`: launcher PNGs extracted from the built APK.
- `tmp/icon_v525_home.xml`: MuMu home screen UI dump after launch.
- `tmp/icon_v525_home.png`: MuMu screenshot after launch.

## Rollback

Old launcher resources were backed up before replacement:

- `archive/launcher-icon-backup-20260707-v524/`

To roll back, copy the files from that backup directory back to the same relative paths under the repository, restore `app/build.gradle` and `docs/release-version.md` to `524 / 5.2.4-noad`, then rebuild.