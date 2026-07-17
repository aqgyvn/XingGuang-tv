# Formal APK Parity Audit - 2026-07-06

## Reference

- Formal APK: `C:\Users\52396\Desktop\星光影视-纸黑片单UI结构版-播放核心弹层高度固定修复-正式签名.apk`
- Formal decoded resources: `apkwork/decoded`
- Current build APK: `app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk`
- Test device: MuMu `127.0.0.1:16384`

## Confirmed Same

- Package and entry: both APKs use `com.xingguang.video`, versionCode `522`, versionName `5.2.2-noad`, launch activity `com.fongmi.android.tv.ui.activity.HomeActivity`.
- Permissions and ABI: the checked `aapt dump badging` output matches for permissions, minSdk `26`, targetSdk `28`, and native code `arm64-v8a`.
- Manifest declarations: unique manifest declaration names match between the formal APK and current APK; no activity, service, receiver, provider, permission, or provider authority name is missing.
- Assets: the only current `assets/` name gap found so far is `assets/dexopt/baseline.prof` and `assets/dexopt/baseline.profm`, which are baseline profile optimization files rather than app feature files.
- Launcher icons: `mipmap-mdpi` through `mipmap-xxxhdpi` `ic_launcher.png` SHA-256 hashes match between the formal APK decode and current source.
- Built-in mobile wallpapers: `wallpaper_1.webp` through `wallpaper_4.webp` SHA-256 hashes match between the formal APK decode and `app/src/mobile/res/drawable-nodpi`.
- Portrait video layout: normalized `layout/activity_video.xml` matches the formal APK resource.
- Fullscreen right controls: `layout/view_control_right.xml` matches the formal APK resource after the previous fullscreen placeholder restoration.

## Fixed In This Pass

- Restored the formal wallpaper container defaults in `app/src/main/res/layout/view_wall.xml`:
  - Root `FrameLayout` now has `android:background="@color/xg_background"`.
  - Wallpaper `ImageView` now starts as `android:visibility="gone"`.
- Restored native libraries present in the formal APK but missing from the current source APK:
  - `libavdevice.so`
  - `libavfilter.so`
  - `libavformat.so`
  - `libc++_shared.so`
  - `libpostproc.so`

This directly addresses a confirmed resource difference that can affect the visible background layer before a wallpaper image is loaded.

## Verified In MuMu

- Build passed: `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.
- Install passed: `adb install -r -d app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk` returned `Success`.
- Launch passed: `monkey -p com.xingguang.video -c android.intent.category.LAUNCHER 1` opened `HomeActivity`.
- Checked log window after launch: no `FATAL EXCEPTION`, `Resources$NotFoundException`, or `InflateException` was found.
- Native library package check passed after restoring the missing libraries: formal APK and current APK both contain 30 `lib/` entries, with no missing or extra library names.
- Playback settings passed after the native library restore: the playback-core dialog shows `EXO`, `IJK`, and `MPV`; switching to `MPV` updated `engineText` to `MPV`, and switching back updated it to `EXO`.
- Recent-watch regression passed after the native library restore: `最近观看` shows `time` labels such as `20:41`, `20:06`, `19:39`, `19:26`, `18:28`, and `17:31`; video title nodes are still `selected=true` for marquee.
- Playback/fullscreen regression passed after the native library restore: portrait playback `video`, `widget`, and `exo` bounds are `[0,72][1080,522]`; fullscreen `video`, `widget`, and `exo` bounds are `[0,0][1920,1080]`.
- Checked log window after playback-core setting changes: no `FATAL EXCEPTION`, `UnsatisfiedLinkError`, or `dlopen failed` was found in the checked window.

Evidence files:

- `tmp/mumu-wall-verify-window.xml`
- `tmp/mumu-wall-verify-screen.png`
- `tmp/mumu-native-libs-window.xml`
- `tmp/mumu-native-libs-setting.xml`
- `tmp/mumu-native-libs-player-setting.xml`
- `tmp/mumu-native-libs-player-dialog.xml`
- `tmp/mumu-native-libs-player-mpv.xml`
- `tmp/mumu-native-libs-player-exo.xml`
- `tmp/mumu-post-libs-history.xml`
- `tmp/mumu-post-libs-playing.xml`
- `tmp/mumu-post-libs-fullscreen.xml`

## 2026-07-06 Color And Resource Compile Follow-up

Confirmed and fixed additional resource-level parity differences found after comparing `aapt2 dump resources` output from the formal APK and the current debug APK:

- Removed the mobile `values-night/colors.xml` override so `primary`, `primaryDark`, `accent`, and `indicator` resolve to the same `xg_*` colors as the formal APK in night mode.
- Aligned `app/src/mobile/res/color-night/nav.xml` with the formal APK selector: checked uses `@color/xg_primary`, unchecked uses `@color/xg_nav_inactive`.
- Corrected the app string resource `xliff` namespace to the Android standard namespace and marked `detail_title` as `formatted="false"`, matching the formal APK's compiled string shape.

Re-verified output after rebuild:

- `color/primary`, `color/primaryDark`, `color/accent`, and `color/indicator` now match the formal APK values.
- `string/app_name`, `string/app_history`, `string/player_line_auto`, and `string/detail_title` match the formal APK values for default, `zh-rCN`, and `zh-rTW`.
- Forced resource processing passed without the previous app-source `Ignoring element ... xliff:g` or `Multiple substitutions` warnings.
- Full APK build passed.
- MuMu install and launch passed.
- Settings playback-core dialog still shows `EXO`, `IJK`, and `MPV`; switching `EXO -> MPV -> EXO` works.
- Recent-watch list still shows time labels including `20:41`, `20:06`, `19:39`, and `17:31`.
- Portrait playback bounds remain `[0,72][1080,522]`; fullscreen playback bounds remain `[0,0][1920,1080]`.
- Checked logcat after launch/playback/fullscreen; no `FATAL EXCEPTION`, `E AndroidRuntime`, `Resources$NotFoundException`, `InflateException`, `UnsatisfiedLinkError`, or `dlopen failed` was found.

Evidence files:

- `tmp/process-resources-after-color-xliff.log`
- `tmp/current-aapt2-resources-after-color-xliff.txt`
- `tmp/mumu-color-xliff-home.xml`
- `tmp/mumu-color-xliff-home.png`
- `tmp/mumu-color-xliff-setting.xml`
- `tmp/mumu-color-xliff-player-setting.xml`
- `tmp/mumu-color-xliff-player-engine-dialog.xml`
- `tmp/mumu-color-xliff-player-mpv.xml`
- `tmp/mumu-color-xliff-player-exo.xml`
- `tmp/mumu-color-xliff-history2.xml`
- `tmp/mumu-color-xliff-playing.xml`
- `tmp/mumu-color-xliff-fullscreen.xml`

## Remaining Audit Scope

This pass does not claim complete byte-for-byte parity of every class and dependency. The APKs differ in expected build output areas such as debug multi-dex layout and third-party packaged resource qualifiers. Those differences must be filtered before deciding whether they represent missing app functionality.

The next useful checks are:

- Continue normalized comparison for the remaining app XML differences in `values`, menus, and `layout-sw600dp/activity_video.xml`.
- Investigate same-name native library size differences before changing them. The current APK still differs from the formal APK in size for `libavcodec.so`, `libavutil.so`, `libswresample.so`, `libswscale.so`, and `libmedia3ext.so`; these may come from dependency packaging or strip behavior and should not be overwritten without ABI confirmation.
- Compare behavior for settings, history, search, playback dialogs, live page, file page, and restore/config dialogs against the formal APK with MuMu evidence.
- Patch only differences that are confirmed to affect current user-facing behavior or formal APK parity.

## 2026-07-06 Fullscreen Playback Control Text Follow-up

Updated the fullscreen playback function/control text resources so player controls and playback function sheets render their labels in white over the fullscreen playback surface.

- Restored the mobile `Control` style text color to `@color/white`, matching the formal APK decoded `Control` style.
- Set fullscreen playback function sheets and playback list rows to white text for player engine, control, track, timer, quality, parse, and track-list resources.
- Kept background, icon, layout size, and player height resources unchanged in this pass.

Re-verified in MuMu:

- Build passed: `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.
- Install passed: MuMu `127.0.0.1:16384` installed `app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk` successfully.
- Playback opened from the home list into portrait playback; portrait player bounds remained `[0,72][1080,522]`.
- Double-tap fullscreen path entered landscape fullscreen; fullscreen player bounds were `[0,0][1920,1080]`.
- Fullscreen playback function sheet opened through the bottom action row and showed `播放核心`, `EXO`, `IJK`, and `MPV`.
- Screenshot pixel check on the fullscreen player-engine sheet found white text pixels in the title and option regions, with no dark text pixels in the option regions.
- Checked logcat after install, playback, fullscreen, and function-sheet opening; no `FATAL EXCEPTION`, `E AndroidRuntime`, `Resources$NotFoundException`, `InflateException`, `UnsatisfiedLinkError`, or `dlopen failed` was found.

Evidence files:

- `tmp/mumu-retest-start.xml`
- `tmp/mumu-retest-playing.xml`
- `tmp/mumu-retest-fullscreen2.xml`
- `tmp/mumu-retest-player-engine-dialog.xml`
- `tmp/mumu-retest-player-engine-dialog.png`

## 2026-07-06 Fullscreen Transition Smoothness Follow-up

Updated the mobile playback fullscreen/small-screen transition so the player surface uses a consistent bounds transition when entering fullscreen and returning to the embedded player.

- Started the player bounds transition before system UI fullscreen state changes, so the status-bar edge and player size changes are covered by the same transition.
- Applied the transition target only to the `video` container, keeping detail page, background, icons, control layout, and player height resources unchanged.
- Increased the transition duration to `240ms` with a decelerating interpolator to reduce the abrupt jump during fullscreen and small-screen switching.

Re-verified in MuMu:

- Build passed: `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.
- Install passed: MuMu `127.0.0.1:16384` installed `app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk` successfully.
- Portrait playback bounds remained `[0,72][1080,522]` before fullscreen switching.
- Double-tap fullscreen path entered landscape fullscreen; fullscreen player bounds were `[0,0][1920,1080]`.
- Portrait fullscreen button path also entered landscape fullscreen; fullscreen player bounds were `[0,0][1920,1080]`.
- Back from fullscreen returned to the embedded portrait player; player bounds returned to `[0,72][1080,522]`.
- Checked logcat after install, playback, fullscreen, and return to small screen; no `FATAL EXCEPTION`, `E AndroidRuntime`, `Resources$NotFoundException`, `InflateException`, `UnsatisfiedLinkError`, or `dlopen failed` was found.

Evidence files:

- `tmp/fullscreen_smooth_final_portrait.xml`
- `tmp/fullscreen_smooth_final_full.xml`
- `tmp/fullscreen_smooth_final_return.xml`
- `tmp/fullscreen_smooth_final_button.xml`
- `tmp/fullscreen_smooth_final_device_end.xml`

## 2026-07-06 Recent Playback Time And Player Engine Text Follow-up

Aligned two mobile UI details back to the formal APK behavior without changing backgrounds, icons, player height, player options, or playback logic.

- Recent playback cards no longer format and show `createTime` as an extra `HH:mm` label; the `time` view remains hidden like the formal APK/source behavior.
- The player-engine bottom sheet title now uses the theme surface text color, and the EXO/IJK/MPV option labels use the formal APK `@color/control` text color reference instead of forced white.

Re-verified in MuMu:

- Build passed: `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.
- Install passed: MuMu `127.0.0.1:16384` installed `app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk` successfully.
- Home/recent playback UI dump contained no visible `HH:mm` text nodes after the change.
- Entered real playback from a recent item and confirmed the app reached the `video`/`exo` playback view without crash; the playback control row did not expose a stable control node during this MuMu run, so the shared player-engine sheet was opened from playback settings for direct resource verification.
- Player settings opened the same `PlayerEngineDialog` and showed the title plus `EXO`, `IJK`, and `MPV` options.
- Switching playback engine from `EXO` to `IJK` updated the settings label to `IJK`, then switching back restored the final label to `EXO`.
- Checked logcat after install, launch, playback entry, dialog opening, and engine switching; no `FATAL EXCEPTION`, `E AndroidRuntime`, `Resources$NotFoundException`, `InflateException`, `UnsatisfiedLinkError`, or `dlopen failed` was found.

Evidence files:

- `tmp/recent_time_after_fix.xml`
- `tmp/try_play_for_engine.xml`
- `tmp/player_settings_for_engine.xml`
- `tmp/engine_dialog_settings_after_fix.xml`
- `tmp/engine_dialog_settings_after_fix.png`
- `tmp/engine_after_ijk.xml`
- `tmp/engine_restored_exo.xml`

## 2026-07-06 Recent Playback Watch Time Follow-up

Restored the recent playback card watch-time display to match the formal APK behavior.

- Recent playback cards now show the saved playback position when `position > 0`.
- If the saved duration is also available, the card shows `position/duration`, using Android `DateUtils.formatElapsedTime` for the same elapsed-time formatting as the formal APK.
- Cards with no positive playback position keep the time label hidden.
- This pass only touched the recent playback adapter logic; background, icons, player height, fullscreen controls, and player-engine resources were not changed.

Re-verified in MuMu:

- Build passed: `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.
- Install passed: MuMu `127.0.0.1:16384` installed `app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk` successfully.
- Local `History` table contained saved records with positive `position` and `duration`, including `5085/3771541`, `481318/2870907`, and `2009087/5191820` milliseconds.
- Opened the real recent playback list through the home history icon; UI dump showed `com.xingguang.video:id/time` labels such as `00:05/1:02:51`, `08:01/47:50`, `00:06/45:25`, `01:48/13:31`, and `33:29/1:26:31`.
- Checked logcat after install, launch, and opening recent playback; no `FATAL EXCEPTION`, `E AndroidRuntime`, `Resources$NotFoundException`, `InflateException`, `UnsatisfiedLinkError`, or `dlopen failed` was found.

Evidence files:

- `tmp/recent_watch_time_progress.xml`
- `tmp/recent_watch_time_progress.png`
- `tmp/recent_history_list_progress.xml`
- `tmp/recent_history_list_progress.png`

## 2026-07-07 Launch Splash Icon Follow-up

Aligned the startup splash icon resource with the formal APK behavior.

- The formal APK uses `@mipmap/ic_launcher` for `Theme.Splash` `windowSplashScreenAnimatedIcon`.
- The mobile and leanback source themes now use the same full launcher icon resource instead of `@drawable/ic_launcher_foreground`.
- This pass did not change launcher PNG assets, backgrounds, player layout, playback controls, or app logic.

Re-verified in MuMu:

- Build passed: `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.
- Packaged mobile resources showed `Theme.Splash` with `windowSplashScreenAnimatedIcon` set to `@mipmap/ic_launcher`.
- `aapt dump badging` reported APK version `523 / 5.2.3-noad` and launcher icons from `res/mipmap-*/ic_launcher.png`.
- Install passed: MuMu `127.0.0.1:16384` installed `app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk` successfully.
- Launch passed: current focus reached `com.fongmi.android.tv.ui.activity.HomeActivity`.
- Checked logcat after install and launch; no `FATAL EXCEPTION`, `E AndroidRuntime`, `Resources$NotFoundException`, `InflateException`, `UnsatisfiedLinkError`, or `dlopen failed` was found.

Evidence files:

- `tmp/splash_fix_20260707.mp4`
- `tmp/splash_fix_005.png`
- `tmp/splash_fix_010.png`
- `tmp/splash_fix_020.png`
- `tmp/splash_fix_040.png`

## 2026-07-07 Home Continue Watching Follow-up

Fixed the home page continue-watching card so it resumes the latest playback history record instead of opening the source/config history dialog.

- The home `vodHistory` card now reads `History.get()` and opens the first/latest playback history item.
- The launch path reuses the same `VideoActivity.start(...)` arguments used by the full recent playback list.
- If no playback history exists, the card opens the normal playback history screen instead of a config/source history dialog.
- This pass only changed the home continue-watching click handler and APK version fields; backgrounds, launcher icons, player layout, fullscreen controls, and playback core resources were not changed.

Re-verified in MuMu:

- Build passed: `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.
- Packaged APK badging reported `versionCode='524'` and `versionName='5.2.4-noad'`.
- Install passed: MuMu `127.0.0.1:16384` installed `app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk` successfully with `install -r`, preserving playback history.
- Device package state reported `versionCode=524` and `versionName=5.2.4-noad`.
- Local `History` table latest row before the click was `zhiqiu@@@644512@@@1`, `低智商犯罪`, `第1集`, `position=28912`, `duration=2530511`.
- Home UI dump showed `com.xingguang.video:id/vodHistory` clickable at `[48,313][1032,573]`.
- Clicking the card reached `com.fongmi.android.tv.ui.activity.VideoActivity`.
- Playback page UI dump showed `低智商犯罪` and `第1集`, matching the latest history item.
- Checked logcat after install, launch, and click; no `FATAL EXCEPTION`, `E AndroidRuntime`, `Resources$NotFoundException`, `InflateException`, `ANR`, `UnsatisfiedLinkError`, or `dlopen failed` was found.

Evidence files:

- `tmp/home_continue_v524_before.xml`
- `tmp/home_continue_v524_before.png`
- `tmp/home_continue_v524_after.xml`
- `tmp/home_continue_v524_after.png`