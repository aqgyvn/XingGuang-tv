# Player Regression Verification - 2026-07-06

## Status

Current Android Studio mobile arm64 debug build can compile, install over the formal Xingguang package, launch in MuMu, enter playback, use IJK playback, switch playback-core settings, enter fullscreen, and show recent-watch time labels.

The player height fix remains active. Portrait loading and playing states reuse the fixed `activity_video.xml` video frame height. Current source height is `150.0dip`; MuMu UI dump shows `video` bounds `[0,72][1080,522]`, which is 450 px on the 3x device density.

## Verified In MuMu

- Device: `127.0.0.1:16384`
- APK: `app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk`
- Build: `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` passed.
- Install: `adb install -r -d` returned `Success`.
- Playback settings: `播放设置` opens, `播放核心` shows `IJK`, and `线路自动选择` shows `开`.
- Playback core dialog: `EXO`, `IJK`, and `MPV` all appear; switching `IJK -> MPV -> IJK` updates the settings text correctly.
- Playback: search result playback enters `VideoActivity`; IJK native logs show `IjkMediaPlayer_native_init` and `IjkMediaPlayer_native_setup` without `UnsatisfiedLinkError` or `FATAL EXCEPTION`.
- Player height: portrait playback `video`, `widget`, and surface bounds stay `[0,72][1080,522]`.
- Fullscreen: tapping the fullscreen control changes `video` bounds to `[0,0][1920,1080]`.
- Recent watch: `最近观看` list shows `time` labels such as `17:31` and `16:16`; title nodes are selected for marquee.

Evidence files from this pass:

- `tmp/mumu-player-settings-window.xml`
- `tmp/mumu-player-engine-dialog-window.xml`
- `tmp/mumu-player-settings-mpv-window.xml`
- `tmp/mumu-player-settings-ijk-window.xml`
- `tmp/mumu-playing-window.xml`
- `tmp/mumu-fullscreen-window.xml`
- `tmp/mumu-history-list.xml`

## Remaining Scope

This document verifies the player-related regressions reported in this round. It does not claim every remote content source, every site parser, every ABI, or every non-player page is byte-for-byte identical to the desktop APK.

For the reported player scope, the old statement that EXO/MPV/IJK switching was not restored is obsolete: the current source build includes the MPV/IJK Java wrappers and arm64 native playback path used by this MuMu test.

## Fullscreen Parity Follow-up

The mobile fullscreen right-side rotate placeholder has been restored to match the formal desktop APK resource. In the formal APK, `view_control_right.xml` keeps `rotate` as a hidden `1dp x 1dp` placeholder without selectable background or scale type; the current source now uses the same resource shape.

MuMu verification after this change:

- Build passed: `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.
- Install passed on `127.0.0.1:16384` using `adb install -r -d`.
- Playback entered landscape fullscreen; UI dump shows `video`, `widget`, and `exo` bounds `[0,0][1920,1080]`.
- Fullscreen content frame is letterboxed by the player at `[0,138][1920,942]`, with black player background around it.
- Screenshot pixel sampling shows fullscreen hidden-control edges and top/bottom bands are black, not the global wallpaper layer.
- Built-in wallpaper resources `wallpaper_1.webp` through `wallpaper_4.webp` have matching SHA-256 hashes between the formal APK decode and current source.

Evidence files from this follow-up:

- `tmp/mumu-fullscreen-parity-20260706/fullscreen-hidden.png`
- `tmp/mumu-fullscreen-parity-20260706/fullscreen-controls.png`
- `tmp/mumu-fullscreen-parity-20260706/window-fullscreen-controls.xml`

## Player Time And Network Speed Follow-up - 2026-07-07

The mobile player now restores the missing desktop-style playback overlay details reported in this round.

- The VOD player control-layer time text is now driven by `Clock`, matching the desktop player behavior of showing live system time while the player controls are visible.
- The VOD player time field was widened and switched to tabular digits so `HH:mm:ss` fits in the top-right control area.
- The loading/buffering network-speed text still uses the existing `Traffic.setSpeed(mBinding.progress.traffic)` path, but its visible style now matches the desktop player more closely: white text at `16sp`.
- No player height, fullscreen sizing, background, icon, player-core selection, episode list, or playback history logic was changed.

MuMu verification after this change:

- Build passed: `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.
- APK badging reported `versionCode='526'` and `versionName='5.2.6-noad'`.
- MuMu instance `0` installed the APK successfully through `mumu-cli adb --vmindex 0 --cmd install -r`.
- Device package state reported `versionCode=526` and `versionName=5.2.6-noad`.
- Entered playback from the home continue-watching card; current focus reached `com.fongmi.android.tv.ui.activity.VideoActivity`.
- Tapped the player area to show controls; UI dump showed `com.xingguang.video:id/time` with `03:38:32` at `[864,78][1056,198]`.
- Tried to capture the loading-speed node by entering playback and switching episode, but the selected source completed loading before UIAutomator captured a visible `traffic` node. The source path and resource packaging were verified instead: `Traffic.setSpeed(mBinding.progress.traffic)` remains active, and `view_progress.xml` now defines `traffic` as white `16sp`.
- Checked logcat after install, launch, playback entry, control display, and episode switch; no `FATAL EXCEPTION`, `E AndroidRuntime`, `Resources$NotFoundException`, `InflateException`, `ANR`, `UnsatisfiedLinkError`, or `dlopen failed` was found.

Evidence files from this follow-up:

- `tmp/player_loading_v526.xml`
- `tmp/player_loading_v526.png`
- `tmp/player_control_v526_retry.xml`
- `tmp/player_control_v526_retry.png`
- `tmp/player_loading_v526_retry.xml`
- `tmp/player_loading_v526_retry.png`

## Network Speed Position Correction - 2026-07-07

The mobile player network-speed display is kept in the same place as the desktop player: the loading/buffering progress overlay, centered under the loading indicator. It is not placed in the right side of the player control bar.

- Removed the incorrect right-side control-bar `traffic` text from the mobile VOD controls.
- Kept the desktop-aligned update path: `Traffic.setSpeed(mBinding.progress.traffic)`.
- The mobile progress overlay still defines `traffic` as centered, white `16sp`, with `40dp` top offset, matching the desktop layout position.
- No background, launcher icon, player height, playback-core selection, episode list, fullscreen layout, or playback history logic was changed in this correction.

MuMu verification after this correction:

- Build passed: `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.
- MuMu install passed and package state reported `versionCode=528` and `versionName=5.2.8-noad`.
- Current MuMu focus stayed on `com.fongmi.android.tv.ui.activity.VideoActivity` during the later no-stop check; no `force-stop` was used for that check.
- Source verification showed mobile VOD and desktop VOD both call `Traffic.setSpeed(mBinding.progress.traffic)`.
- Source verification showed mobile VOD no longer contains `mBinding.control.traffic` and `view_control_vod.xml` no longer contains `@+id/traffic`.
- Current playback UI dump had `video` present and `traffic_nodes=0`, which is expected while the video is already playing because desktop-style traffic is only visible during loading/buffering.
- A visible loading-speed node was not captured in this no-stop check because the current playback was already playing; this run does not claim a live visible `traffic` node capture.

Evidence files from this correction:

- `tmp/current-no-stop.xml`
- `tmp/current-no-stop.png`
- `tmp/mumu-speed-position-v528/window-player-v528.xml`
- `tmp/mumu-speed-position-v528/loading-v528.png`

## Network Speed Visible Capture - 2026-07-07

A later no-stop MuMu verification captured the network-speed text in the desktop-aligned position.

- Current focus stayed on `com.fongmi.android.tv.ui.activity.VideoActivity`; the app process was not force-stopped for this check.
- The test tapped the visible `第4集` button from the current playback page to trigger a normal loading/buffering state.
- `tmp/net-speed-position-v528-fast/speed-fast-2.png` shows the loading indicator centered in the player area with `0 KB/s` directly below it.
- `tmp/net-speed-position-v528-fast/speed-fast-3.png` shows the same loading-layer position with `8.2 MB/s` directly below the loading indicator.
- This confirms the feature is present and positioned in the loading/buffering overlay, not in the right-side control bar.
- Checked logcat after the capture; no `FATAL EXCEPTION`, `AndroidRuntime`, `Resources$NotFoundException`, `InflateException`, `ANR`, `UnsatisfiedLinkError`, or `dlopen failed` was found.

Evidence files from this no-stop capture:

- `tmp/net-speed-position-v528-fast/speed-fast-2.png`
- `tmp/net-speed-position-v528-fast/speed-fast-3.png`
- `tmp/net-speed-position-v528-fast/contact-sheet.jpg`

## Formal APK Network Speed Style Alignment - 2026-07-07

The formal APK reference for this comparison is `C:\Users\52396\Desktop\星光影视-纸黑片单UI结构版-播放核心弹层高度固定修复-正式签名.apk`. Existing decoded resources are under `apkwork/decoded`.

The current source now matches the formal APK network-speed loading overlay style:

- Formal decoded file: `apkwork/decoded/res/layout/view_progress.xml`.
- Current source file: `app/src/mobile/res/layout/view_progress.xml`.
- The `traffic` text remains in the loading/buffering overlay, centered under the loading indicator.
- The text style is aligned to the formal APK: `12sp` and `@color/xg_primary`.
- The right-side VOD control bar still has no `traffic` text.

MuMu verification after this alignment:

- Build passed: `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.
- Install passed; device package state reported `versionCode=529` and `versionName=5.2.9-noad`.
- Opened the app and entered `VideoActivity` from the home continue-watching card.
- Tapped the visible `第4集` item to trigger normal loading/buffering.
- `tmp/net-speed-position-v529/v529-speed-1.png` shows `0 KB/s` under the centered loading indicator, using the primary theme color.
- Checked logcat after capture; no `FATAL EXCEPTION`, `AndroidRuntime`, `Resources$NotFoundException`, `InflateException`, `ANR`, `UnsatisfiedLinkError`, or `dlopen failed` was found.

Evidence files from this pass:

- `tmp/net-speed-position-v529/v529-speed-1.png`
- `tmp/net-speed-position-v529/v529-contact-sheet.jpg`

## Fullscreen Control Network Speed - 2026-07-07

The user-provided fullscreen reference places the network-speed text directly under the top-left video title. The mobile fullscreen VOD controls now use the existing `size` text slot in `view_control_vod.xml` for that live speed value.

- The fullscreen title remains on the first line.
- The network speed appears on the second line under the title, in white, matching the control-layer text style from the formal fullscreen reference.
- The text is only refreshed while the fullscreen control overlay is visible and unlocked.
- The loading/buffering overlay speed remains unchanged and still uses `progress.traffic`.
- No right-side control-bar network-speed text was added.

MuMu verification after this update:

- Build passed: `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.
- APK badging reported `versionCode='530'` and `versionName='5.2.10-noad'`.
- Install passed; device package state reported `versionCode=530` and `versionName=5.2.10-noad`.
- Opened the app, entered `VideoActivity` from the home continue-watching card, showed the small player controls, and confirmed the small-screen controls did not show a network-speed text.
- Entered fullscreen through the player full button and captured `tmp/fullscreen-traffic-v530/enter_full_auto.png`, which shows `0 KB/s` directly under the top-left title.
- Checked logcat after the capture; no `FATAL EXCEPTION`, `E AndroidRuntime`, `Resources$NotFoundException`, `InflateException`, `ANR in`, `UnsatisfiedLinkError`, or `dlopen failed` was found.

Evidence files from this pass:

- `tmp/fullscreen-traffic-v530/small_control.png`
- `tmp/fullscreen-traffic-v530/enter_full_auto.png`

## Small Player Control Network Speed - 2026-07-07

The mobile VOD control-layer network-speed text is now shown in both small-screen and fullscreen playback controls.

- Small-screen controls use the same existing top-left `size` text slot as fullscreen controls.
- The speed refresh runs only while the control overlay is visible and unlocked.
- The loading/buffering overlay speed display remains unchanged.
- No right-side control-bar network-speed text was added.

MuMu verification after this update:

- Build passed: `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.
- APK badging reported `versionCode='531'` and `versionName='5.2.11-noad'`.
- Install passed; device package state reported `versionCode=531` and `versionName=5.2.11-noad`.
- Opened the app, entered `VideoActivity` from the home continue-watching card, exited fullscreen back to the small player, and showed the small-screen controls.
- `tmp/small-traffic-v531/small_visible.png` shows `0 KB/s` in the small-screen control layer.
- `tmp/small-traffic-v531/full_visible.png` shows the same small-screen control layer later updating to `191 KB/s`.
- Checked logcat after the captures; no `FATAL EXCEPTION`, `E AndroidRuntime`, `Resources$NotFoundException`, `InflateException`, `ANR in`, `UnsatisfiedLinkError`, or `dlopen failed` was found.

Evidence files from this pass:

- `tmp/small-traffic-v531/small_visible.png`
- `tmp/small-traffic-v531/full_visible.png`

## Stable Playback Core Upgrade - 2026-07-07

Only formal stable playback-core dependencies were upgraded in this pass.

- Media3 / EXO was upgraded from `1.9.2` to `1.10.1`.
- MPV `nextlib-media3ext` was upgraded from `1.9.1-0.11.0` to `1.10.1-0.13.0`.
- Preview versions such as Media3 `1.11.0-alpha01` were intentionally not used.
- Local IJK native libraries were not changed because they are local `.so` files, not Gradle playback-core dependencies.
- APK version was bumped to `versionCode=532` and `versionName=5.2.12-noad`.

Verification after the stable upgrade:

- `./gradlew.bat :app:dependencyInsight --configuration mobileArm64_v8aDebugRuntimeClasspath --dependency androidx.media3:media3-exoplayer --no-daemon` resolved Media3 / EXO modules to `1.10.1` with Gradle status `release`.
- `./gradlew.bat :app:dependencyInsight --configuration mobileArm64_v8aDebugRuntimeClasspath --dependency io.github.anilbeesetti:nextlib-media3ext --no-daemon` resolved MPV extension to `1.10.1-0.13.0` with Gradle status `release`.
- `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` passed.
- APK badging reported `package='com.xingguang.video'`, `versionCode='532'`, and `versionName='5.2.12-noad'`.
- MuMu package state reported `versionCode=532` and `versionName=5.2.12-noad`.
- MuMu was running `VideoActivity`; current-process logcat showed no `FATAL EXCEPTION`, `E AndroidRuntime`, `Resources$NotFoundException`, `InflateException`, `ANR in`, `UnsatisfiedLinkError`, `dlopen failed`, `NoSuchMethodError`, or `NoClassDefFoundError`.
- Playback settings still exposed `EXO / IJK / MPV`; the core was switched `EXO -> MPV -> EXO` and restored to `EXO`.

APK output:

- `app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk`
- SHA-256: `BA9835D01AB722329B26658F798F0A7817F083B6E3788088E3E660633FBD58C6`

Evidence files from this pass:

- `tmp/player-core-upgrade-v532/home.png`
- `tmp/player-core-upgrade-v532/setting.png`
- `tmp/player-core-upgrade-v532/player_setting.png`
- `tmp/player-core-upgrade-v532/player_dialog.png`
- `tmp/player-core-upgrade-v532/player_mpv.png`
- `tmp/player-core-upgrade-v532/player_exo_restored.png`
- `tmp/player-core-upgrade-v532/playback.png`

## Version Name Alignment - 2026-07-07

The current APK version name is aligned with `versionCode 532`.

- Current `versionCode`: `532`.
- Current `versionName`: `5.3.2`.
- The release-version rule now documents this mapping, so `versionCode 532` uses `versionName 5.3.2`.
- `ic_logo` was restored as a drawable alias to the current launcher icon because the Java build referenced `R.drawable.ic_logo` and the missing resource blocked packaging.

Verification after this alignment:

- `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` passed.
- APK badging reported `package='com.xingguang.video'`, `versionCode='532'`, and `versionName='5.3.2'`.
- MuMu install passed; device package state reported `versionCode=532` and `versionName=5.3.2`.
- Launched `HomeActivity` in MuMu after install; no `FATAL EXCEPTION`, `E AndroidRuntime`, `Resources$NotFoundException`, `InflateException`, `ANR in`, `UnsatisfiedLinkError`, `dlopen failed`, `NoSuchMethodError`, or `NoClassDefFoundError` was found in the post-launch logcat check.

APK output:

- `app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk`
- SHA-256: `3B82B65F350FA749B3CD10F18D71448A43F07196F8B2FD8858A112E667DA8EB3`
