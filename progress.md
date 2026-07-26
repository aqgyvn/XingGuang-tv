## 2026-07-04 - Task: 重建星空影视 Android Studio 工程

### What was done
- 创建了可由 Android Studio 打开的原生 Android 工程，包含单 `app` 模块、Gradle 配置和 Gradle Wrapper。
- 实现了“星空影视”首页、视频 URL 输入入口和原生 `VideoView` 播放调试页。
- 补充了 Android Studio 打开、同步、运行和命令行构建说明。

### Testing
- 通过 UTF-8 XML 解析检查：`app/src/main/AndroidManifest.xml`、`app/src/main/res/values/strings.xml`、`app/src/main/res/values/styles.xml` 均可解析。
- 通过 Gradle Wrapper jar 检查：`gradle/wrapper/gradle-wrapper.jar` 内存在 `org/gradle/wrapper/GradleWrapperMain.class`。
- 已执行 `.\gradlew.bat :app:assembleDebug`，当前机器因缺少 JDK 被阻断，报错为 `JAVA_HOME is not set and no 'java' command could be found in your PATH`；因此尚未在本机产出 `app-debug.apk`。

### Notes
- `.gitignore`：新增 Android/Gradle 本地输出忽略规则。
- `settings.gradle`：新增 Gradle 插件仓库、依赖仓库和 `:app` 模块声明。
- `build.gradle`：新增 Android Gradle Plugin 版本声明。
- `gradle.properties`：新增 Gradle JVM 参数和 Android 构建基础开关。
- `gradlew`：新增 Unix Gradle Wrapper 启动脚本。
- `gradlew.bat`：新增 Windows Gradle Wrapper 启动脚本。
- `gradle/wrapper/gradle-wrapper.properties`：新增 Gradle 8.7 发行包配置。
- `gradle/wrapper/gradle-wrapper.jar`：新增 Gradle Wrapper 启动 jar。
- `app/build.gradle`：新增应用包名、SDK 版本、版本号和 Java 8 源码编译配置。
- `app/src/main/AndroidManifest.xml`：新增应用入口、播放页声明和网络权限。
- `app/src/main/java/com/xingkong/video/MainActivity.java`：新增首页和视频地址输入入口。
- `app/src/main/java/com/xingkong/video/PlayerActivity.java`：新增原生视频播放调试页。
- `app/src/main/res/values/strings.xml`：新增应用名称和界面文案。
- `app/src/main/res/values/styles.xml`：新增基础无标题栏主题。
- `docs/android-studio.md`：新增 Android Studio 运行调试说明和环境缺口处理方式。
- `progress.md`：新增本轮执行、验证和回滚记录。
- 回滚方式：本轮开始前 `D:\xingkong` 为空目录；如需回滚，删除以上新增文件和 `app/`、`docs/`、`gradle/` 目录即可恢复到本轮前状态。

## 2026-07-05 - Task: 重构星光影视 Android Studio 工程

### What was done
- 将根目录工程切到更接近现有 APK 的 FongMi/TV 5.2.2 源码快照，并对齐星光影视的包名、应用名和版本号。
- 补入本地播放相关 AAR、官方 Media3、DanmakuFlameMaster 和 nextlib-media3ext 依赖，使 Android Studio 源码工程可以同步和编译。
- 为缺失的旧 DLNA 包补了编译兼容层，并把依赖私有 Media3、字幕和弹幕同步扩展的调用降级到公开依赖可编译的实现。
- 保留 apktool 反编译与重打包路线，已产出本地签名重打包 APK。
- 重写 `docs/xingguang-rebuild.md`，说明 Android Studio 打开方式、构建命令、APK 输出位置、签名限制和已知降级点。

### Testing
- 已执行 `.\gradlew.bat projects --no-daemon --stacktrace`，结果 `BUILD SUCCESSFUL`，确认根工程包含 `:app`、`:catvod`、`:chaquo`、`:quickjs`。
- 已执行 `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`，结果 `BUILD SUCCESSFUL`。
- 已执行 `.\gradlew.bat :app:assembleLeanbackArm64_v8aDebug --no-daemon --stacktrace`，结果 `BUILD SUCCESSFUL`。
- 已确认 APK 输出存在：`D:\xingkong\app\build\outputs\apk\mobileArm64_v8a\debug\mobile-arm64_v8a.apk`，大小 `67467253` 字节。
- 已确认 APK 输出存在：`D:\xingkong\app\build\outputs\apk\leanbackArm64_v8a\debug\leanback-arm64_v8a.apk`，大小 `68049272` 字节。
- 已确认 apktool 重打包输出存在：`D:\xingkong\apkwork\signed-rebuild-local.apk`。
- 当前未安装 debug APK 到模拟器，因为已有 `com.xingguang.video` 正式签名包，覆盖安装会因签名不同失败；卸载旧包会清除数据，需用户确认后再执行。

### Notes
- `app/build.gradle`：对齐 `applicationId`、版本号，并补入公开可用的 Media3、弹幕和 nextlib 依赖。
- `chaquo/build.gradle`：固定使用工作区内 Python 3.10，保证 Android Studio/Gradle 同步时可找到 Python。
- `app/src/main/res/values/strings.xml`：将应用名对齐为星光影视。
- `app/src/main/res/values-zh-rCN/strings.xml`：将简体中文应用名对齐为星光影视。
- `app/src/main/res/values-zh-rTW/strings.xml`：将繁体中文应用名对齐为星光影视。
- `app/libs/forcetech-release.aar`：补入本地播放相关依赖。
- `app/libs/hook-release.aar`：补入本地 Hook 相关依赖。
- `app/libs/jianpian-release.aar`：补入本地简片相关依赖。
- `app/libs/thunder-release.aar`：补入本地迅雷相关依赖。
- `app/libs/tvbus-release.aar`：补入本地 TVBus 相关依赖。
- `app/src/main/java/com/android/cast/dlna/dmc/DLNACastManager.java`：新增 DLNA 控制端兼容空实现。
- `app/src/main/java/com/android/cast/dlna/dmc/DLNACastService.java`：新增 DLNA 控制服务兼容空实现。
- `app/src/main/java/com/android/cast/dlna/dmc/OnDeviceRegistryListener.java`：新增设备注册监听兼容接口。
- `app/src/main/java/com/android/cast/dlna/dmc/control/DeviceControl.java`：新增设备控制兼容空实现。
- `app/src/main/java/com/android/cast/dlna/dmc/control/OnDeviceControlListener.java`：新增设备控制监听兼容接口。
- `app/src/main/java/com/android/cast/dlna/dmc/control/ServiceActionCallback.java`：新增服务动作回调兼容接口。
- `app/src/main/java/com/android/cast/dlna/dmr/CastAction.java`：新增投屏动作常量兼容定义。
- `app/src/main/java/com/android/cast/dlna/dmr/DLNARendererService.java`：新增 DLNA 渲染服务兼容空实现。
- `app/src/main/java/com/android/cast/dlna/dmr/RenderControl.java`：新增渲染控制兼容空实现。
- `app/src/main/java/com/android/cast/dlna/dmr/RendererServiceBinder.java`：新增渲染服务 Binder 兼容实现。
- `app/src/main/java/com/android/cast/dlna/dmr/RenderState.java`：新增渲染状态兼容定义。
- `app/src/main/java/com/android/cast/dlna/dmr/service/RendererInterfaceKt.java`：新增旧 Kotlin 接口名对应的 Java 兼容入口。
- `scripts/rebuild-xingguang-apk.ps1`：保留 APK 重打包脚本，可从 `apkwork/decoded` 重新产出本地签名 APK。
- `apkwork/source-latest.apk`：保留原 APK 工作区副本。
- `apkwork/decoded`：保留原 APK 的 apktool 反编译工程。
- `apkwork/signed-rebuild-local.apk`：保留已重打包并本地签名的 APK。
- `docs/xingguang-rebuild.md`：重写为可读 UTF-8 中文说明，补充构建、调试、签名和降级点。
- `progress.md`：追加本轮执行、验证和回滚记录。
- 回滚方式：根源码可从 `D:\xingkong\archive\fongmi-latest-source-20260705-020850` 恢复到切换前备份；若要回到 2026-07-04 的最小脚手架，可从 `D:\xingkong\archive\minimal-scaffold-20260704-2118` 恢复；APK 重打包路线可继续使用 `D:\xingkong\apkwork\decoded` 和 `D:\xingkong\scripts\rebuild-xingguang-apk.ps1`。

## 2026-07-05 - Task: 按正式版验证星光影视运行状态

### What was done
- 使用雷电模拟器上已安装的正式签名 `com.xingguang.video` 进行测试，未卸载旧包，未清除 App 数据。
- 通过 Launcher 入口启动正式版，并确认首页可进入、片单图片可加载、底部导航可显示。
- 点击首页片单进入 `VideoActivity`，确认影片详情页和播放入口可打开，应用进程保持运行。
- 保存本轮正式版测试截图和 UI 层级作为验证证据。

### Testing
- 已执行 `adb shell pm list packages com.xingguang.video`，确认正式包已安装。
- 已执行 `adb shell dumpsys package com.xingguang.video`，确认版本为 `versionCode=522`、`versionName=5.2.2-noad`。
- 已执行 `adb shell monkey -p com.xingguang.video -c android.intent.category.LAUNCHER 1`，确认正式版通过 Launcher 入口启动成功。
- 已确认前台 Activity 为 `com.xingguang.video/com.fongmi.android.tv.ui.activity.HomeActivity`，随后点击片单进入 `com.xingguang.video/com.fongmi.android.tv.ui.activity.VideoActivity`。
- 已确认进程 `com.xingguang.video` 存活，未发现 `FATAL EXCEPTION` 或 `AndroidRuntime` 崩溃。
- 已保存首页截图：`D:\xingkong\tmp\xingguang-formal-home-screen.png`。
- 已保存详情/播放入口截图：`D:\xingkong\tmp\xingguang-formal-video-screen.png`。
- 已保存 UI 层级：`D:\xingkong\tmp\xingguang-ui.xml`。

### Notes
- `tmp/xingguang-formal-home-screen.png`：正式版首页截图，证明首页内容和海报加载正常。
- `tmp/xingguang-formal-video-screen.png`：正式版影片详情/播放入口截图，证明片单跳转和播放入口页面可打开。
- `tmp/xingguang-ui.xml`：正式版首页 UI 层级 dump，用于后续复查页面节点。
- `progress.md`：追加本轮正式版测试记录。
- 回滚方式：本轮未改源码和安装包；如不需要测试证据，可删除 `D:\xingkong\tmp\xingguang-formal-home-screen.png`、`D:\xingkong\tmp\xingguang-formal-video-screen.png`、`D:\xingkong\tmp\xingguang-ui.xml`，`progress.md` 保留为审计记录。

## 2026-07-06 - Task: 测试播放核心弹层高度固定修复版功能状态

### What was done
- 启动雷电模拟器第 0 个实例，并在不卸载、不清数据的前提下测试已安装的 `com.xingguang.video`。
- 确认模拟器内安装包与桌面 `星光影视-纸黑片单UI结构版-播放核心弹层高度固定修复-正式签名.apk` 是同一个 APK。
- 测试首页启动、影片详情跳转、选集播放、播放控制层显示、网速显示、返回按钮尺寸和播放核心弹层固定高度配置。
- 保存本轮测试截图、UI dump 和已安装 base.apk 备份作为证据。

### Testing
- 已确认已安装包版本为 `versionCode=522`、`versionName=5.2.2-noad`。
- 已确认已安装 base.apk 与桌面目标 APK 的 SHA-256 均为 `A888E87A8515F38DD490F1933E965E606E2CB7F615BD240A87DD1C4F593F6FBE`。
- 已通过 Launcher 启动 `HomeActivity`，进程 PID 为 `2580`，未发现 `FATAL EXCEPTION`、`AndroidRuntime` 崩溃或 ANR。
- 已点击首页影片进入 `VideoActivity`，详情页正常显示，播放区域进入加载状态。
- 已切换到可播放剧集后看到视频画面渲染，系统媒体会话显示 `title="千香"`、`duration=5960`，应用进程保持存活。
- 已点击播放器区域显示控制层，截图中可见顶部网速 `18 KB/s`、小尺寸返回按钮、播放/进度/全屏控制。
- 已用 `aapt2 dump xmltree --file res/layout/dialog_player_engine.xml` 校验目标 APK，确认播放核心弹层根高度 `120dp`、标题行 `56dp`、按钮行 `64dp`。
- 全屏按钮测试触发了横竖屏配置变化且无崩溃，但截图最终回到竖屏详情页，本轮不把“稳定停留全屏视觉状态”判定为通过。

### Notes
- `tmp/function-test-20260706/home.png`：首页启动截图。
- `tmp/function-test-20260706/detail.png`：影片详情和初始播放加载截图。
- `tmp/function-test-20260706/playback-wait.png`：自动选集等待播放截图。
- `tmp/function-test-20260706/playback-ep1.png`：切换可播放剧集后的播放画面截图。
- `tmp/function-test-20260706/controls.png`：播放器控制层截图，包含网速、小返回按钮、进度和全屏入口。
- `tmp/function-test-20260706/fullscreen.png`：全屏按钮测试后的截图。
- `tmp/function-test-20260706/ui-controls.xml`：控制层测试时的 UI 层级 dump。
- `tmp/function-test-20260706/installed-base.apk`：从模拟器拉取的已安装 base.apk，用于和桌面目标 APK 做哈希比对。
- `progress.md`：追加本轮功能测试记录。
- 回滚方式：本轮未改源码、未重签名、未安装新包；如不需要测试证据，可删除 `D:\xingkong\tmp\function-test-20260706` 目录，保留 `progress.md` 审计记录。

## 2026-07-06 - Task: 补充播放核心弹层高度固定修复版测试结论

### What was done
- 根据“真机不会出现这种情况”的边界说明，将上一轮模拟器全屏后未稳定停留在全屏视觉状态的现象归类为模拟器环境限制，不作为本次功能阻断。
- 保留上一轮对首页启动、详情页跳转、选集播放、控制层显示、网速显示、返回按钮尺寸和播放核心弹层固定高度的验证结论。
- 未修改源码、构建配置、安装包或测试证据文件。

### Testing
- 复用上一轮已记录证据：目标 APK 与已安装 base.apk 的 SHA-256 均为 `A888E87A8515F38DD490F1933E965E606E2CB7F615BD240A87DD1C4F593F6FBE`。
- 复用上一轮已记录运行证据：播放画面可渲染、控制层可显示、进程存活，未发现 `FATAL EXCEPTION`、`AndroidRuntime` 崩溃或 ANR。
- 复用上一轮已记录静态校验：`dialog_player_engine.xml` 中播放核心弹层根高度为 `120dp`，标题行为 `56dp`，按钮行为 `64dp`。
- 本轮未重新连接真机或模拟器执行新测试；结论基于用户补充的真机边界和上一轮已保存证据收口。

### Notes
- `progress.md`：追加本轮测试结论收口记录，明确模拟器全屏停留现象不作为真机功能阻断。
- 回滚方式：删除本条 `2026-07-06 - Task: 补充播放核心弹层高度固定修复版测试结论` 记录即可恢复到本轮前日志状态；源码、APK 和测试证据无需回滚。

## 2026-07-06 - Task: MuMu 模拟器验证播放核心弹层高度固定修复版

### What was done
- 使用 MuMu 安卓设备 `127.0.0.1:16384` 继续测试桌面目标 APK：`星光影视-纸黑片单UI结构版-播放核心弹层高度固定修复-正式签名.apk`。
- 确认应用在 MuMu 中可从首页进入影片详情，可点选 `1080P` 进入横屏播放，视频画面持续渲染。
- 重新打开播放控制层并点击 `EXO`，确认底部“播放核心”弹层可正常显示，包含 `EXO`、`IJK`、`MPV` 三个入口。
- 对照反编译资源确认 `dialog_player_engine.xml` 根高度为 `120dp`，标题行 `56dp`，按钮行 `64dp`，符合“弹层高度固定修复”目标。

### Testing
- 已确认前台 Activity 为 `com.xingguang.video/com.fongmi.android.tv.ui.activity.VideoActivity`，进程 `com.xingguang.video` 持续存活。
- 已保存播放截图：`D:\xingkong\tmp\mumu-function-test-20260706\playback.png`。
- 已保存控制层截图：`D:\xingkong\tmp\mumu-function-test-20260706\controls-before-engine.png`。
- 已保存播放核心弹层截图：`D:\xingkong\tmp\mumu-function-test-20260706\engine-popup-local.png`。
- 已检查目标 APK SHA-256：`A888E87A8515F38DD490F1933E965E606E2CB7F615BD240A87DD1C4F593F6FBE`。
- 已检查最近日志，未发现 `FATAL EXCEPTION`、`AndroidRuntime` 崩溃或 ANR；MuMu/Android 15 上出现的 `/proc/net/tcp` 权限提示不影响播放和弹层显示。

### Notes
- `tmp/mumu-function-test-20260706/home.png`：MuMu 首页启动截图。
- `tmp/mumu-function-test-20260706/detail.png`：影片详情页截图。
- `tmp/mumu-function-test-20260706/playback.png`：MuMu 横屏播放画面截图。
- `tmp/mumu-function-test-20260706/controls.png`：播放控制层截图。
- `tmp/mumu-function-test-20260706/controls-before-engine.png`：重新打开播放核心入口前的控制层截图。
- `tmp/mumu-function-test-20260706/engine-popup-local.png`：本轮补抓的“播放核心”固定高度弹层截图。
- `tmp/mumu-function-test-20260706/ui-controls.xml`：控制层 UI dump，用于复查控件层级。
- `progress.md`：追加本轮 MuMu 功能验证和证据路径记录。
- 回滚方式：本轮未改源码、未重签名、未重装 APK；如需回滚测试产物，删除 `D:\xingkong\tmp\mumu-function-test-20260706` 目录，并移除本条 `progress.md` 记录即可。

## 2026-07-06 - Task: 固定播放加载态与播放态播放器高度

### What was done
- 调整点播播放页竖屏播放器高度逻辑，取消拿到视频真实尺寸后按片源比例重新计算播放器容器高度的行为。
- 保留全屏、横屏和平板布局原有逻辑；竖屏详情页加载中、缓冲中、已播放统一使用 `activity_video.xml` 中的初始播放器高度。
- 清理本轮改动后不再需要的播放器高度动画字段、初始化和相关导入，避免后续误触发高度动画。

### Testing
- 已静态检查 `VideoActivity.java`，确认不再存在 `finalHeight`、视频宽高比例计算、`ValueAnimator` 高度动画和 `setIntValues` 动态改高逻辑。
- 已执行 `where java` 与 `where javac`，当前命令环境均未找到 JDK。
- 已尝试执行 `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`，被环境阻断：`JAVA_HOME is not set and no 'java' command could be found in your PATH`。
- 因本机 shell 缺少 JDK，本轮尚未产出新 APK，也未能安装到 MuMu 做运行截图验证。

### Notes
- `app/src/mobile/java/com/fongmi/android/tv/ui/activity/VideoActivity.java`：取消点播竖屏播放开始后的动态高度调整，使加载态和播放态播放器高度保持一致。
- `progress.md`：追加本轮修改、验证结果和环境缺口记录。
- 回滚方式：将 `VideoActivity.java` 中 `changeHeight()` 恢复为按视频宽高计算 `finalHeight` 并启动 `ValueAnimator` 的旧逻辑，同时恢复 `ValueAnimator`、`DecelerateInterpolator` 导入、`mAnimator` 字段、`setAnimator()` 方法及 `initView()` 中的 `setAnimator()` 调用；或直接从本轮修改前备份/版本记录恢复该文件。

## 2026-07-06 - Task: Align Android Studio source with desktop Xingguang build and keep player height fixed
### What was done
- Aligned the Android Studio mobile source with the desktop formal APK baseline for package metadata, launcher icons, paper-style mobile UI resources, colors, shapes, and player control resources.
- Kept the player height fix in `VideoActivity`: portrait non-fullscreen playback reuses the initial video frame height instead of recalculating/animating to a different height after playback starts.
- Configured Debug and Release builds to sign with the original Xingguang certificate so Android Studio debug builds can cover the formally signed package without a signature mismatch.
- Updated rebuild documentation with the new resource/signing state and Android Studio install notes.

### Testing
- Passed: `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.
- Passed: `aapt2 dump badging` on `app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk` shows package `com.xingguang.video`, version `522 / 5.2.2-noad`, `minSdkVersion:'26'`, `targetSdkVersion:'28'`, label `星光影视`, and PNG launcher icon resources.
- Passed: source launcher icon hashes match the desktop APK decoded icons for `mipmap-mdpi/ic_launcher.png` and `mipmap-xxxhdpi/ic_launcher.png`.
- Passed: `apksigner verify --print-certs` shows the built debug APK certificate SHA-256 is `775b4b773f689575d436784b1b2f7b3f08e8e8bef6ab11276928c752c783da24`, matching the desktop formal APK.
- Passed: static check of `VideoActivity.changeHeight()` shows it still calls `mBinding.video.setLayoutParams(mFrameParams)` and no `ValueAnimator`/height animation path is present.
- Not run: MuMu/manual UI playback test was intentionally not performed in this step to avoid overwriting the user's current installed app before static identity checks were complete.

### Notes
- Changed `app/build.gradle`: aligned `minSdk` to 26 and added original-certificate signing for debug/release builds.
- Changed `local.properties`: switched signing settings to `apkwork/keystore/xingguang-release.p12` with alias `xingguang`.
- Added `apkwork/keystore/xingguang-release.p12`: local copy of the original signing certificate used by the desktop formal APK.
- Changed `app/src/main/res/mipmap-*`: replaced launcher PNGs with desktop formal APK icons and replaced round icons with formal PNG resources.
- Removed `app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` and `ic_launcher_round.xml`: prevents Android 8+ from selecting the old adaptive icon instead of the formal PNG icon.
- Removed old `app/src/main/res/mipmap-*/ic_launcher_round.webp`: avoids duplicate round launcher resources after restoring formal PNG round icons.
- Changed `app/src/main/res/color/text.xml`: aligned mobile text selector colors with the desktop formal resource output.
- Changed `app/src/main/res/values/strings.xml`, `values-zh-rCN/strings.xml`, and `values-zh-rTW/strings.xml`: added `player_line_auto` required by the formal player settings layout.
- Changed `app/src/mobile/res/color/control.xml`, `live.xml`, and `nav.xml`: aligned mobile selector colors with the paper-style formal APK.
- Changed `app/src/mobile/res/values/colors.xml` and `styles.xml`: added formal `xg_*` theme colors and applied the paper-style app theme values.
- Changed `app/src/mobile/res/drawable/ic_action_*.xml`, `ic_fab_*.xml`, `ic_nav_*.xml`, `ic_control_full*.xml`, `shape_*`: aligned action icons, floating buttons, nav icons, player control icons, and paper/card shapes with the formal APK resources.
- Changed `app/src/mobile/res/layout/*.xml`: overlaid mobile layout XMLs from the formal APK decoded resources, with IDs converted for source compilation.
- Changed `app/src/mobile/java/com/fongmi/android/tv/ui/fragment/VodFragment.java`: replaced old toolbar menu event wiring with formal paper-layout icon/button event wiring.
- Changed `docs/xingguang-rebuild.md`: documented minSdk, icon, paper UI, signing, and player height alignment status.
- Rollback point: restore files from `tmp/source-align-backup-20260706-androidstudio` for the pre-resource-overlay state; for signing rollback, set `local.properties` back to `storeFile=D:/xingkong/apkwork/keystore/xingguang-rebuild-local.p12`, `keyAlias=xingguang_rebuild`, `storePassword=xingguang-rebuild-20260704`.

## 2026-07-06 - Task: MuMu runtime verification for source-aligned Xingguang build
### What was done
- Installed the current Android Studio debug build over MuMu using the original Xingguang certificate.
- Launched `com.xingguang.video` and verified the home page renders as the paper-style playlist UI instead of the previous default blue/green UI.
- Entered playback from a home item and captured both loading-state and playing-state screenshots.
- Measured the top player bottom edge in both screenshots to confirm loading and playing player heights match.

### Testing
- Passed: `adb install -r -d app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk` returned `Success` on MuMu device `127.0.0.1:16384`.
- Passed: home screenshot `tmp/mumu-source-align-test-20260706/home-after-source-align.png` shows the paper-style playlist UI.
- Passed: loading screenshot `tmp/mumu-source-align-test-20260706/detail-after-source-align.png` and playing screenshot `tmp/mumu-source-align-test-20260706/playback-after-wait.png` both have the player bottom edge at `y=522` by pixel scan, confirming equal player height.
- Passed: playback reached actual video frame display after waiting, so the comparison covered real playing state, not only loading/error state.

### Notes
- `tmp/mumu-source-align-test-20260706/home-after-source-align.png`：MuMu 首页运行截图。
- `tmp/mumu-source-align-test-20260706/home-ui.xml`：首页 UI dump。
- `tmp/mumu-source-align-test-20260706/detail-after-source-align.png`：播放加载态截图。
- `tmp/mumu-source-align-test-20260706/detail-ui.xml`：加载态 UI dump。
- `tmp/mumu-source-align-test-20260706/playback-after-wait.png`：播放态截图。
- `tmp/mumu-source-align-test-20260706/playback-ui.xml`：播放态 UI dump。
- `progress.md`：追加本轮 MuMu 运行验证和证据路径记录。
- 回滚方式：本轮未修改源码；如需撤销本轮测试安装，可重新安装桌面正式 APK `C:\Users\52396\Desktop\星光影视-纸黑片单UI结构版-播放核心弹层高度固定修复-正式签名.apk`，或删除 `tmp/mumu-source-align-test-20260706` 测试产物。

## 2026-07-06 - Task: Fix video page background after source alignment
### What was done
- Fixed the video/detail page background so it no longer shows the underlying wallpaper gradient.
- Added the formal paper background color directly to the mobile video page root layout while keeping the existing player-height fix unchanged.

### Testing
- Passed: `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.
- Passed: MuMu install over existing package returned `Success` using `adb install -r -d`.
- Passed: screenshot `tmp/mumu-background-fix-20260706/playing.png` shows the video/detail page background restored to the light paper background, with the green gradient no longer visible.
- Passed: pixel scan of `loading.png` and `playing.png` shows the player bottom edge at `y=529` in both states, confirming the height fix still holds after the background change.

### Notes
- `app/src/mobile/res/layout/activity_video.xml`: added `@color/xg_background` to the root layout to prevent the global wallpaper layer from showing through behind the detail content.
- `tmp/mumu-background-fix-20260706/loading.png`: MuMu loading-state screenshot after the background fix.
- `tmp/mumu-background-fix-20260706/playing.png`: MuMu playing-state screenshot after the background fix.
- `progress.md`: appended this fix and verification record.
- Rollback方式：移除 `activity_video.xml` 根节点上的 `android:background="@color/xg_background"`，然后重新执行 `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`。

## 2026-07-06 - Task: 微调竖屏播放页播放器位置

### What was done
- 将竖屏播放页顶部播放器固定高度从 `150dp` 微调为 `148dp`，让加载态和播放态保持同一高度的同时整体上移一小段。
- 保持纸黑片单 UI、页面背景、播放逻辑和签名配置不变，只处理播放器位置偏低的问题。

### Testing
- Passed: `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` 构建成功。
- Passed: 使用 MuMu 设备 `127.0.0.1:16384` 执行 `adb install -r -d app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk`，安装返回 `Success`。
- Passed: MuMu 截图 `tmp/mumu-player-height-148dp-20260706/home.png` 确认首页仍为纸黑片单 UI。
- Passed: MuMu 截图 `tmp/mumu-player-height-148dp-20260706/detail.png`、`loading.png`、`playing.png` 确认播放页背景仍为浅色纸质背景。
- Passed: 像素扫描显示 `detail.png`、`loading.png`、`playing.png` 的播放器底边均为 `y=523`，加载态和播放态高度一致；相比上一轮背景修复时的 `y=529` 已上移约 6 像素。

### Notes
- `app/src/mobile/res/layout/activity_video.xml`：将 `@id/video` 的 `android:layout_height` 从 `150.0dip` 调整为 `148.0dip`。
- `tmp/mumu-player-height-148dp-20260706/home.png`：MuMu 首页截图，用于确认 UI 未跑偏。
- `tmp/mumu-player-height-148dp-20260706/detail.png`：播放详情页截图，用于确认播放器位置和背景。
- `tmp/mumu-player-height-148dp-20260706/loading.png`：切换线路后抓取的播放过程截图。
- `tmp/mumu-player-height-148dp-20260706/playing.png`：播放稳定后的截图。
- `progress.md`：追加本轮播放器位置微调、构建和 MuMu 验证记录。
- 回滚方式：将 `app/src/mobile/res/layout/activity_video.xml` 中 `@id/video` 的 `android:layout_height` 从 `148.0dip` 改回 `150.0dip`，然后重新执行 `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`。
## 2026-07-06 - Task: Fix and verify player UI regressions after source alignment
### What was done
- Reconnected the mobile video fullscreen button so portrait playback controls can enter and exit fullscreen.
- Restored the fullscreen right-side rotate button size so it is clickable again.
- Reconnected playback settings rows required by the formal paper layout, including playback core display and auto line switch.
- Restored recent-watch time display and enabled marquee selection state for video titles in home/history holders.
- Documented the verified status and the remaining playback-core implementation gap in `docs/player-regression-20260706.md`.

### Testing
- Passed: `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.
- Passed: MuMu device `127.0.0.1:16384` reported `device`.
- Passed: installed `app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk` with `adb install -r -d`; install returned `Success`.
- Passed: launched `com.xingguang.video`; focus entered `HomeActivity`.
- Passed: `tmp/mumu-regression-20260706/current-after-launch.png` shows the formal paper-style home UI.
- Passed: `tmp/mumu-regression-20260706/player-settings-now.png` shows playback settings with `播放核心 EXO`.
- Passed: `tmp/mumu-regression-20260706/player-core-dialog-now.png` shows the playback core dialog opens.
- Passed: `tmp/mumu-regression-20260706/player-settings-scrolled-now.png` shows `线路自动选择` is present and enabled.
- Passed: `tmp/mumu-regression-20260706/history-now.png` shows recent-watch time labels such as `17:31` and `16:16`.
- Passed: `tmp/mumu-regression-20260706/player-opened-now.png` shows playback reached the video page and is playing.
- Passed: `tmp/mumu-regression-20260706/fullscreen-now.png` shows tapping the fullscreen button entered landscape fullscreen playback.
- Not passed as complete formal parity: full EXO/MPV/IJK playback-core switching is still not restored because the current `app` source has only the old Exo-backed `Players` implementation and does not include the matching MPV/IJK Java dependency layer.

### Notes
- `app/src/mobile/java/com/fongmi/android/tv/ui/activity/VideoActivity.java`: bound the fullscreen button to fullscreen enter/exit handling.
- `app/src/mobile/res/layout/view_control_right.xml`: restored the rotate control to a usable clickable size.
- `app/src/mobile/java/com/fongmi/android/tv/ui/fragment/SettingPlayerFragment.java`: wired formal playback settings rows for core display and auto line switch.
- `app/src/mobile/java/com/fongmi/android/tv/ui/adapter/HistoryAdapter.java`: restored recent-watch time display and selected state for title marquee.
- `app/src/mobile/java/com/fongmi/android/tv/ui/holder/VodRectHolder.java`: enabled selected state for title marquee.
- `app/src/mobile/java/com/fongmi/android/tv/ui/holder/VodOvalHolder.java`: enabled selected state for title marquee.
- `app/src/mobile/java/com/fongmi/android/tv/ui/holder/VodListHolder.java`: enabled selected state for title marquee.
- `docs/player-regression-20260706.md`: recorded MuMu verification status and the remaining playback-core gap.
- `progress.md`: appended this implementation and verification record.
- Rollback method: restore the changed Java/XML files from `tmp/source-align-backup-20260706-androidstudio` or revert the listed files to the state before this task, then rerun `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` and reinstall on MuMu.

## 2026-07-06 - Task: Re-verify desktop player parity items in MuMu

### What was done
- Rebuilt the current Android Studio arm64 debug APK and installed it over `com.xingguang.video` on MuMu without changing source UI, background, icon, or layout files.
- Re-verified the reported desktop-player parity items: playback core switching, auto line selection display, IJK playback startup, fixed portrait player height, fullscreen entry, recent-watch time labels, and title marquee selected state.
- Updated the player regression document to remove the obsolete statement that EXO/MPV/IJK switching was still missing.

### Testing
- Passed: `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.
- Passed: MuMu device `127.0.0.1:16384` returned `device` and `adb install -r -d app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk` returned `Success`.
- Passed: true settings page opened; `播放设置` shows `播放核心 IJK` and `线路自动选择 开`.
- Passed: playback-core dialog shows `EXO`, `IJK`, and `MPV`; switching `IJK -> MPV -> IJK` updated the settings text each time.
- Passed: search playback entered `VideoActivity`; logcat showed `IjkMediaPlayer_native_init` and `IjkMediaPlayer_native_setup`, with no `FATAL EXCEPTION`, `AndroidRuntime`, or `UnsatisfiedLinkError` found in the checked log window.
- Passed: portrait playback `video` bounds were `[0,72][1080,522]`, matching the fixed 150dp player height on MuMu's 3x density.
- Passed: fullscreen button path changed `video` bounds to `[0,0][1920,1080]`.
- Passed: `最近观看` shows time labels such as `17:31` and `16:16`; history title nodes are `selected=true` for marquee.

### Notes
- `docs/player-regression-20260706.md`：更新播放器回归验证结论，删除过期的“播放核心未恢复”说明，补充本轮 MuMu 实测证据路径。
- `progress.md`：追加本轮构建、安装、播放与历史列表验证记录。
- 本轮未修改源码文件；未改 UI、背景、图标、签名配置或布局。
- 回滚方式：如需撤销本轮文档更新，可将 `docs/player-regression-20260706.md` 恢复到本轮之前内容，并删除本条 `progress.md` 追加记录；源码无需回滚。

## 2026-07-06 - Task: Align fullscreen playback UI with desktop formal APK
### What was done
- Restored the mobile fullscreen right-side `rotate` control placeholder to the formal desktop APK shape: hidden `1dp x 1dp` image view without selectable background or scale type.
- Kept homepage, app icon, normal portrait playback layout, player height, wallpaper resources, and playback logic unchanged.
- Verified the formal APK and current source still use identical built-in wallpaper image resources.

### Testing
- Passed: `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` built `app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk` successfully.
- Passed: MuMu device `127.0.0.1:16384` installed the APK with `adb install -r -d`; install returned `Success`.
- Passed: entered playback from the home list and reached landscape fullscreen; UI dump shows `video`, `widget`, and `exo` bounds `[0,0][1920,1080]`.
- Passed: fullscreen screenshot pixel sampling shows the hidden-control fullscreen edges/top/bottom bands are black, not the global wallpaper layer.
- Passed: `wallpaper_1.webp` through `wallpaper_4.webp` SHA-256 hashes match between `apkwork/decoded` formal APK resources and `app/src/mobile` resources.
- Passed with note: checked logcat after playback/fullscreen; no app `FATAL EXCEPTION` was found in the checked window. A non-fatal `MPV native library unavailable` line appeared while this specific run used EXO initialization.

### Notes
- `app/src/mobile/res/layout/view_control_right.xml`: restored the hidden rotate placeholder to the formal APK dimensions and attributes.
- `docs/player-regression-20260706.md`: appended fullscreen parity verification notes and MuMu evidence paths.
- `tmp/mumu-fullscreen-parity-20260706/fullscreen-hidden.png`: MuMu fullscreen screenshot with controls hidden.
- `tmp/mumu-fullscreen-parity-20260706/fullscreen-controls.png`: MuMu fullscreen screenshot after tapping the player.
- `tmp/mumu-fullscreen-parity-20260706/window-fullscreen-controls.xml`: MuMu UI dump for fullscreen verification.
- Rollback method: change `app/src/mobile/res/layout/view_control_right.xml` `@+id/rotate` back to the prior `44.0dip x 44.0dip` view with `android:background="?selectableItemBackgroundBorderless"` and `android:scaleType="center"`, then rebuild with `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-06 - Task: Restore formal APK wallpaper container defaults
### What was done
- Compared the formal desktop APK resource decode against the current Android Studio mobile source for package metadata, launcher icons, built-in wallpaper images, and key playback/background layouts.
- Confirmed package name, version, entry activity, permissions, launcher icons, and mobile built-in wallpaper image hashes match the formal APK.
- Restored the formal `view_wall.xml` defaults so the global wallpaper container has the paper background color and the wallpaper image layer starts hidden until loaded.
- Added a formal APK parity audit note under `docs/` to keep the remaining comparison scope explicit.

### Testing
- Passed: `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` built successfully after the wallpaper layout change.
- Passed: MuMu device `127.0.0.1:16384` installed `app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk`; install returned `Success`.
- Passed: launched `com.xingguang.video` with `monkey -p com.xingguang.video -c android.intent.category.LAUNCHER 1`; UI dump was captured after launch.
- Passed: checked logcat after launch; no `FATAL EXCEPTION`, `Resources$NotFoundException`, or `InflateException` was found in the checked window.

### Notes
- `app/src/main/res/layout/view_wall.xml`: added `android:background="@color/xg_background"` on the root wall container and `android:visibility="gone"` on the wallpaper image to match the formal APK resource.
- `docs/formal-apk-parity-20260706.md`: documented the current formal APK comparison baseline, confirmed matching items, this wallpaper fix, MuMu verification evidence, and remaining audit scope.
- `tmp/formal-reference-20260706.apk`: temporary ASCII-path copy of the formal APK used because `aapt` could not read the original Chinese desktop path.
- `tmp/mumu-wall-verify-window.xml`: MuMu UI dump captured after installing and launching the updated build.
- `tmp/mumu-wall-verify-screen.png`: MuMu screenshot captured after installing and launching the updated build.
- Rollback method: remove `android:background="@color/xg_background"` from the root `FrameLayout` and remove `android:visibility="gone"` from the `ImageView` in `app/src/main/res/layout/view_wall.xml`, then rebuild with `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-06 - Task: Restore formal APK arm64 native library set
### What was done
- Compared the formal APK `lib/` entries against the current rebuilt APK and found the current APK was missing five arm64 native libraries from the formal package.
- Added the missing formal APK native libraries to `app/src/main/jniLibs/arm64-v8a` so the rebuilt APK contains the same native library names as the desktop formal APK.
- Verified existing source-controlled playback libraries already matched the formal APK hashes before adding the missing libraries.
- Kept same-name libraries with size differences unchanged because they are produced by dependency merge/strip behavior and need ABI confirmation before any override.

### Testing
- Passed: `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` built successfully after adding the native libraries.
- Passed: APK library check after rebuild showed formal APK and current APK both contain 30 `lib/` entries, with no missing or extra library names.
- Passed: MuMu device `127.0.0.1:16384` installed `app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk`; install returned `Success`.
- Passed: launched `com.xingguang.video` successfully after install.
- Passed: playback settings opened; playback core showed `EXO` and the dialog displayed `EXO`, `IJK`, and `MPV`.
- Passed: tapping `MPV` updated `engineText` to `MPV`, then reopening the dialog and tapping `EXO` restored `engineText` to `EXO`.
- Passed: checked logcat after launch and playback-core setting changes; no `FATAL EXCEPTION`, `UnsatisfiedLinkError`, or `dlopen failed` was found in the checked window.

### Notes
- `app/src/main/jniLibs/arm64-v8a/libavdevice.so`: added from the formal APK decode to restore the formal native library set.
- `app/src/main/jniLibs/arm64-v8a/libavfilter.so`: added from the formal APK decode to restore the formal native library set.
- `app/src/main/jniLibs/arm64-v8a/libavformat.so`: added from the formal APK decode to restore the formal native library set.
- `app/src/main/jniLibs/arm64-v8a/libc++_shared.so`: added from the formal APK decode to restore the formal native library set.
- `app/src/main/jniLibs/arm64-v8a/libpostproc.so`: added from the formal APK decode to restore the formal native library set.
- `docs/formal-apk-parity-20260706.md`: updated with the native library restore result, MuMu verification evidence, and remaining same-name library size differences.
- `tmp/mumu-native-libs-window.xml`: MuMu UI dump after installing and launching the native-library-restored build.
- `tmp/mumu-native-libs-setting.xml`: MuMu UI dump confirming the settings page opened.
- `tmp/mumu-native-libs-player-setting.xml`: MuMu UI dump confirming playback settings opened.
- `tmp/mumu-native-libs-player-dialog.xml`: MuMu UI dump confirming `EXO`, `IJK`, and `MPV` appear in the playback-core dialog.
- `tmp/mumu-native-libs-player-mpv.xml`: MuMu UI dump confirming the playback-core setting changed to `MPV`.
- `tmp/mumu-native-libs-player-exo.xml`: MuMu UI dump confirming the playback-core setting was restored to `EXO`.
- Rollback method: delete the five added `.so` files listed above from `app/src/main/jniLibs/arm64-v8a`, then rebuild with `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.
## 2026-07-06 - Task: Align mobile night colors and string resource compilation with formal APK
### What was done
- Compared the formal APK and current debug APK resource tables with `aapt2 dump resources` and found current-only night-mode overrides for `primary`, `primaryDark`, `accent`, and `indicator` that could make the background/navigation colors differ from the desktop formal build.
- Removed the mobile night color override and aligned the night navigation selector with the formal APK so checked and unchecked navigation colors use the same `xg_*` palette as the formal package.
- Corrected app string `xliff` namespaces and marked `detail_title` as `formatted="false"`, matching the formal APK's compiled string output and removing app-source resource warnings.

### Testing
- Passed: `./gradlew.bat :app:processMobileArm64_v8aDebugResources --no-daemon --rerun-tasks --stacktrace` completed successfully after the color and string resource changes.
- Passed: `tmp/process-resources-after-color-xliff.log` contains `BUILD SUCCESSFUL` and no app-source `Ignoring element ... xliff:g` or `Multiple substitutions` warnings.
- Passed: `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed successfully.
- Passed: `aapt2 dump resources` comparison confirmed `color/primary`, `color/primaryDark`, `color/accent`, `color/indicator`, `string/app_name`, `string/app_history`, `string/player_line_auto`, and `string/detail_title` match the formal APK values.
- Passed: MuMu `127.0.0.1:16384` installed `app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk`; install returned `Success`.
- Passed: launched `com.xingguang.video`; homepage UI dump was captured in `tmp/mumu-color-xliff-home.xml` and screenshot in `tmp/mumu-color-xliff-home.png`.
- Passed: playback settings opened; playback core showed `EXO`; the dialog showed `EXO`, `IJK`, and `MPV`; switching `EXO -> MPV -> EXO` updated the displayed core value correctly.
- Passed: recent-watch list opened through the normal homepage history button and showed time labels including `20:41`, `20:06`, `19:39`, and `17:31`.
- Passed: playback from recent-watch opened; portrait `video`, `widget`, and `exo` bounds were `[0,72][1080,522]`.
- Passed: tapping the fullscreen control changed rotation to landscape and `video`, `widget`, and `exo` bounds to `[0,0][1920,1080]`.
- Passed: checked logcat after launch/playback/fullscreen; no `FATAL EXCEPTION`, `E AndroidRuntime`, `Resources$NotFoundException`, `InflateException`, `UnsatisfiedLinkError`, or `dlopen failed` was found.

### Notes
- `app/src/mobile/res/color-night/nav.xml`: changed the night navigation selector to use `@color/xg_primary` for checked state and `@color/xg_nav_inactive` for the default state, matching the formal APK resource.
- `app/src/mobile/res/values-night/colors.xml`: deleted the current-only night overrides for `primary`, `primaryDark`, `accent`, and `indicator` so the mobile build uses the same formal `xg_*` color values in night mode.
- `app/src/main/res/values/strings.xml`: changed the `xliff` namespace to the Android standard namespace and marked `detail_title` as `formatted="false"`.
- `app/src/main/res/values-zh-rCN/strings.xml`: changed the `xliff` namespace to the Android standard namespace and marked `detail_title` as `formatted="false"`.
- `app/src/main/res/values-zh-rTW/strings.xml`: changed the `xliff` namespace to the Android standard namespace and marked `detail_title` as `formatted="false"`.
- `app/src/mobile/res/values/strings.xml`: changed the `xliff` namespace to the Android standard namespace.
- `app/src/mobile/res/values-zh-rCN/strings.xml`: changed the `xliff` namespace to the Android standard namespace.
- `app/src/mobile/res/values-zh-rTW/strings.xml`: changed the `xliff` namespace to the Android standard namespace.
- `docs/formal-apk-parity-20260706.md`: appended this color/resource compile parity follow-up and MuMu verification evidence.
- Rollback method: restore `app/src/mobile/res/color-night/nav.xml` to the previous selector, recreate `app/src/mobile/res/values-night/colors.xml` with the removed night color overrides if needed, revert the listed string namespace/detail-title edits, then rebuild with `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-06 - Task: Make fullscreen playback function text white
### What was done
- Restored the fullscreen playback action-button text style to white, matching the formal APK decoded `Control` style.
- Updated playback function sheets and playback-only list rows so fullscreen function labels such as playback core, scale, track, timer, quality, parse, and track options render in white.
- Kept background, icon, layout height, player height, and non-player pages unchanged.

### Testing
- Passed: precise resource check found no remaining `?android:textColorPrimary`, `@color/control`, or `@color/text` references in the edited fullscreen playback function resources.
- Passed: `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed successfully after the text color changes.
- Passed: MuMu `127.0.0.1:16384` installed `app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk`; install returned `Success`.
- Passed: launched `com.xingguang.video`, opened playback from the home list, and confirmed portrait player bounds remained `[0,72][1080,522]`.
- Passed: double-tap entered landscape fullscreen and UI dump showed fullscreen player bounds `[0,0][1920,1080]`.
- Passed: opened the fullscreen playback-core function sheet; UI dump showed `播放核心`, `EXO`, `IJK`, and `MPV`.
- Passed: screenshot pixel check on `tmp/mumu-retest-player-engine-dialog.png` found white text pixels in the title and option regions; option regions had no dark text pixels after the fix.
- Passed: checked logcat after install/playback/fullscreen/function-sheet opening; no `FATAL EXCEPTION`, `E AndroidRuntime`, `Resources$NotFoundException`, `InflateException`, `UnsatisfiedLinkError`, or `dlopen failed` was found.

### Notes
- `app/src/mobile/res/values/styles.xml`: changed the playback-only `Control` style text color from the themed app text color back to `@color/white`.
- `app/src/mobile/res/layout/dialog_player_engine.xml`: changed the fullscreen playback-core sheet title and EXO/IJK/MPV option text to white.
- `app/src/mobile/res/layout/dialog_control.xml`: changed playback function sheet section labels and option chips to white.
- `app/src/mobile/res/layout/dialog_track.xml`: changed the playback track sheet title to white.
- `app/src/mobile/res/layout/dialog_timer.xml`: changed timer sheet title, timer options, countdown text, and cancel button text to white.
- `app/src/mobile/res/layout/adapter_quality.xml`: changed player quality option text to white.
- `app/src/mobile/res/layout/adapter_track.xml`: changed player track option text to white.
- `app/src/mobile/res/layout/adapter_parse_light.xml`: changed player parse option text to white.
- `app/src/mobile/res/layout/adapter_parse_dark.xml`: changed fullscreen parse option text to white.
- `docs/formal-apk-parity-20260706.md`: appended the fullscreen playback control text verification notes and evidence files.
- Rollback method: restore the listed XML textColor values to their previous theme/selector references (`@color/xg_text_primary`, `?colorOnSurface`, `?android:textColorPrimary`, `@color/control`, or `@color/text` as applicable), then rebuild with `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-06 - Task: Smooth fullscreen and small-screen player switching
### What was done
- Updated the mobile playback fullscreen/small-screen transition so the player surface starts a bounds animation before system UI fullscreen state changes.
- Applied the transition only to the `video` container and kept background, icons, control layout, playback functions, and embedded player height unchanged.
- Increased the player bounds transition to `240ms` with a decelerating interpolator to reduce abrupt jumps when entering fullscreen or returning to the embedded player.

### Testing
- Passed: `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed successfully after the transition change.
- Passed: MuMu `127.0.0.1:16384` installed `app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk`; install returned `Success`.
- Passed: launched `com.xingguang.video`, opened playback from the home list, and confirmed portrait player bounds remained `[0,72][1080,522]`.
- Passed: double-tap entered landscape fullscreen and UI dump showed fullscreen player bounds `[0,0][1920,1080]`.
- Passed: pressing Back from fullscreen returned to the embedded portrait player and UI dump showed player bounds `[0,72][1080,522]`.
- Passed: portrait fullscreen button coordinate path entered landscape fullscreen and UI dump showed player bounds `[0,0][1920,1080]`.
- Passed: returned the MuMu device to embedded portrait playback at the end; UI dump showed player bounds `[0,72][1080,522]`.
- Passed: checked logcat after install/playback/fullscreen/return; no `FATAL EXCEPTION`, `E AndroidRuntime`, `Resources$NotFoundException`, `InflateException`, `UnsatisfiedLinkError`, or `dlopen failed` was found.
- Note: the fullscreen-state small-screen icon was not separately coordinate-verified because the fullscreen controls did not expose a stable `full` node in the MuMu accessibility dump; the tested Back return uses the same `exitFullscreen()` code path changed in this task.

### Notes
- `app/src/mobile/java/com/fongmi/android/tv/ui/activity/VideoActivity.java`: moved fullscreen/small-screen bounds transition before system UI changes, targeted it to the player container, and adjusted the animation duration/interpolator.
- `docs/formal-apk-parity-20260706.md`: appended the fullscreen transition smoothness follow-up and MuMu verification evidence.
- `tmp/fullscreen_smooth_final_portrait.xml`: evidence for embedded portrait playback bounds before switching.
- `tmp/fullscreen_smooth_final_full.xml`: evidence for landscape fullscreen bounds after double-tap switching.
- `tmp/fullscreen_smooth_final_return.xml`: evidence for embedded portrait playback bounds after returning from fullscreen.
- `tmp/fullscreen_smooth_final_button.xml`: evidence for portrait fullscreen button coordinate entering fullscreen.
- `tmp/fullscreen_smooth_final_device_end.xml`: evidence that the device was left in embedded portrait playback after verification.
- Rollback method: restore `VideoActivity.java` so `enterFullscreen()` and `exitFullscreen()` only call `setTransition()` under the previous `isLand() && !mPlayers.isPortrait()` condition, remove the `DecelerateInterpolator` import and transition target/interpolator changes, remove the appended docs section if desired, then rebuild with `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-06 - Task: Align recent playback time and player-engine text color
### What was done
- Removed the extra recent-playback `HH:mm` create-time display so recent playback cards return to the formal APK/source behavior where the time view stays hidden.
- Restored the player-engine bottom sheet text colors to the formal APK references: title uses the theme surface text color and EXO/IJK/MPV option labels use `@color/control`.
- Kept background, icons, player height, player-engine option count, and playback switching logic unchanged.

### Testing
- Passed: `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed successfully after the scoped changes.
- Passed: MuMu `127.0.0.1:16384` installed `app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk`; install returned `Success`.
- Passed: launched `com.xingguang.video` and checked the home/recent playback UI dump; no visible `HH:mm` text nodes were present after the time-display rollback.
- Passed: opened real playback from a recent item and confirmed the UI reached the `video`/`exo` playback view without crash.
- Passed: opened the shared `PlayerEngineDialog` from playback settings and confirmed the title plus `EXO`, `IJK`, and `MPV` options were visible.
- Passed: switched playback engine from `EXO` to `IJK`, verified the settings label changed to `IJK`, then switched back and verified the final label returned to `EXO`.
- Passed: checked logcat after install, launch, playback entry, dialog opening, and engine switching; no `FATAL EXCEPTION`, `E AndroidRuntime`, `Resources$NotFoundException`, `InflateException`, `UnsatisfiedLinkError`, or `dlopen failed` was found.
- Note: during this MuMu run, the fullscreen/player control row did not expose a stable control node while playback was open, so the exact same `PlayerEngineDialog` layout and switching logic were verified through the playback settings entry.

### Notes
- `app/src/mobile/java/com/fongmi/android/tv/ui/adapter/HistoryAdapter.java`: removed the added create-time formatter and the code that made the recent playback time view visible.
- `app/src/mobile/res/layout/dialog_player_engine.xml`: restored formal APK text color references for the player-engine title and EXO/IJK/MPV labels.
- `docs/formal-apk-parity-20260706.md`: appended the recent playback time and player-engine text color follow-up with MuMu evidence.
- `tmp/recent_time_after_fix.xml`: evidence that the visible home/recent playback UI had no `HH:mm` text nodes.
- `tmp/try_play_for_engine.xml`: evidence that playback reached the `video`/`exo` playback view.
- `tmp/engine_dialog_settings_after_fix.xml` and `tmp/engine_dialog_settings_after_fix.png`: evidence that the shared player-engine dialog opened with EXO/IJK/MPV options.
- `tmp/engine_after_ijk.xml` and `tmp/engine_restored_exo.xml`: evidence that engine switching worked and was restored to EXO.
- Rollback method: restore `HistoryAdapter.java` to re-add the `SimpleDateFormat` field/imports and `time` binding/visibility lines if the extra `HH:mm` display is desired again; restore `dialog_player_engine.xml` text colors to `@color/white` if the forced-white player-engine sheet is desired again; then rebuild with `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-06 - Task: Restore desktop-style recent playback watch time
### What was done
- Restored the recent playback card watch-time label so it shows saved playback progress like the formal APK: `position` when available, and `position/duration` when duration is available.
- Kept cards with no positive playback position hidden, matching the formal APK behavior.
- Kept the change scoped to the recent playback adapter; background, icons, player height, fullscreen controls, player-engine text resources, and playback logic were not changed.

### Testing
- Passed: `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed successfully.
- Passed: MuMu `127.0.0.1:16384` installed `app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk`; install returned `Success`.
- Passed: read the app `History` database in MuMu and confirmed existing records had positive `position/duration` values, including `5085/3771541`, `481318/2870907`, and `2009087/5191820` milliseconds.
- Passed: opened the real recent playback list from the home history icon and confirmed UI dump showed `com.xingguang.video:id/time` labels including `00:05/1:02:51`, `08:01/47:50`, `00:06/45:25`, `01:48/13:31`, and `33:29/1:26:31`.
- Passed: checked logcat after install, launch, and opening recent playback; no `FATAL EXCEPTION`, `E AndroidRuntime`, `Resources$NotFoundException`, `InflateException`, `UnsatisfiedLinkError`, or `dlopen failed` was found.

### Notes
- `app/src/mobile/java/com/fongmi/android/tv/ui/adapter/HistoryAdapter.java`: added formal-APK-style elapsed playback time binding for recent playback cards.
- `docs/formal-apk-parity-20260706.md`: appended the recent playback watch-time parity notes and MuMu evidence list.
- `tmp/recent_watch_time_progress.xml` and `tmp/recent_watch_time_progress.png`: evidence for the launched home screen before entering the full recent playback list.
- `tmp/recent_history_list_progress.xml` and `tmp/recent_history_list_progress.png`: evidence that the recent playback list shows watch-time labels.
- Rollback method: remove the `DateUtils` import, remove the `setTime(holder, item)` call, delete the `setTime` helper in `HistoryAdapter.java`, then rebuild with `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-07 - Task: Bump APK version for update
### What was done
- Updated the Android APK version for this update from `522 / 5.2.2-noad` to `523 / 5.2.3-noad`.
- Added a short release version note so future APK updates also bump both `versionCode` and `versionName` before packaging.

### Testing
- Passed: `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed successfully.
- Passed: `aapt dump badging app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk` reported `versionCode='523'` and `versionName='5.2.3-noad'`.
- Passed: generated packaged manifest reported `android:versionCode="523"` and `android:versionName="5.2.3-noad"`.
- Passed: MuMu `127.0.0.1:16384` installed the APK successfully, and `dumpsys package com.xingguang.video` reported `versionCode=523` and `versionName=5.2.3-noad`.
- Passed: launched `com.xingguang.video` after install; current focus reached `com.fongmi.android.tv.ui.activity.HomeActivity` and logcat showed no `FATAL EXCEPTION`, `E AndroidRuntime`, `Resources$NotFoundException`, `InflateException`, `UnsatisfiedLinkError`, or `dlopen failed`.

### Notes
- `app/build.gradle`: bumped `versionCode` to `523` and `versionName` to `5.2.3-noad`.
- `docs/release-version.md`: documented the current APK version and version bump rule for future updates.
- Rollback method: restore `app/build.gradle` to `versionCode 522` and `versionName "5.2.2-noad"`, remove or update `docs/release-version.md`, then rebuild with `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-07 - Task: Align startup splash animation with formal APK
### What was done
- Changed the startup splash animated icon from the foreground vector to the full launcher icon, matching the formal APK resource reference.
- Applied the same correction to mobile and leanback splash themes.
- Kept launcher PNG assets, background, player UI, playback controls, and app logic unchanged.

### Testing
- Passed: `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed successfully.
- Passed: merged mobile resources showed `Theme.Splash` with `windowSplashScreenAnimatedIcon` set to `@mipmap/ic_launcher`.
- Passed: `aapt dump badging app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk` reported `versionCode='523'`, `versionName='5.2.3-noad'`, and launcher icons from `res/mipmap-*/ic_launcher.png`.
- Passed: MuMu `127.0.0.1:16384` installed the APK successfully; install returned `Success`.
- Passed: launched `com.xingguang.video`; current focus reached `com.fongmi.android.tv.ui.activity.HomeActivity`.
- Passed: checked logcat after install and launch; no `FATAL EXCEPTION`, `E AndroidRuntime`, `Resources$NotFoundException`, `InflateException`, `UnsatisfiedLinkError`, or `dlopen failed` was found.
- Evidence captured: `tmp/splash_fix_20260707.mp4`, `tmp/splash_fix_005.png`, `tmp/splash_fix_010.png`, `tmp/splash_fix_020.png`, and `tmp/splash_fix_040.png`.

### Notes
- `app/src/mobile/res/values/styles.xml`: changed `Theme.Splash` animated icon to the formal APK `@mipmap/ic_launcher` reference.
- `app/src/leanback/res/values/styles.xml`: applied the same splash icon reference for leanback parity.
- `docs/formal-apk-parity-20260706.md`: appended launch splash icon parity notes and MuMu evidence.
- `tmp/splash_fix_20260707.mp4`: captured MuMu launch recording for startup review.
- `tmp/splash_fix_005.png`, `tmp/splash_fix_010.png`, `tmp/splash_fix_020.png`, and `tmp/splash_fix_040.png`: captured launch screenshots at short delays after app start.
- Rollback method: restore both `windowSplashScreenAnimatedIcon` entries to `@drawable/ic_launcher_foreground`, then rebuild with `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-07 - Task: Fix home continue watching playback history
### What was done
- Rebound the home page continue-watching card to open the latest playback history item instead of the source/config history dialog.
- Reused the same `VideoActivity.start(...)` entry path as the full recent playback list so the saved episode and progress restoration stay on the existing playback flow.
- Bumped the APK version for this update from `523 / 5.2.3-noad` to `524 / 5.2.4-noad`.
- Kept the change scoped to the home click handler and version metadata; backgrounds, launcher icons, player layout, fullscreen controls, and playback core resources were not changed.

### Testing
- Passed: `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed successfully.
- Passed: `aapt dump badging app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk` reported `versionCode='524'` and `versionName='5.2.4-noad'`.
- Passed: MuMu `127.0.0.1:16384` installed `app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk` with `install -r`; install returned `Success` and preserved playback history.
- Passed: `dumpsys package com.xingguang.video` reported `versionCode=524` and `versionName=5.2.4-noad`.
- Passed: read the MuMu app `History` table before clicking; latest row was `zhiqiu@@@644512@@@1`, `低智商犯罪`, `第1集`, `position=28912`, `duration=2530511`.
- Passed: launched the app and confirmed current focus reached `com.fongmi.android.tv.ui.activity.HomeActivity`.
- Passed: home UI dump showed `com.xingguang.video:id/vodHistory` clickable at `[48,313][1032,573]`; tapping that card reached `com.fongmi.android.tv.ui.activity.VideoActivity`.
- Passed: playback UI dump after the click contained `低智商犯罪` and `第1集`, matching the latest playback history record.
- Passed: checked logcat after install, launch, and click; no `FATAL EXCEPTION`, `E AndroidRuntime`, `Resources$NotFoundException`, `InflateException`, `ANR`, `UnsatisfiedLinkError`, or `dlopen failed` was found.
- APK path: `app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk`; final size `82676659` bytes; final timestamp `2026/7/7 2:12:07`.

### Notes
- `app/src/mobile/java/com/fongmi/android/tv/ui/fragment/VodFragment.java`: changed the home `vodHistory` click handler to load the first/latest `History.get()` item and open it through `VideoActivity.start(...)`; empty history falls back to `HistoryActivity`.
- `app/build.gradle`: bumped `versionCode` to `524` and `versionName` to `5.2.4-noad` for this APK update.
- `docs/release-version.md`: updated the documented current APK version to `524 / 5.2.4-noad`.
- `docs/formal-apk-parity-20260706.md`: appended the home continue-watching behavior notes and MuMu verification evidence.
- `tmp/home_continue_v524_before.xml` and `tmp/home_continue_v524_before.png`: evidence for the home screen before tapping continue watching.
- `tmp/home_continue_v524_after.xml` and `tmp/home_continue_v524_after.png`: evidence for the playback screen after tapping continue watching.
- Rollback method: in `VodFragment.java`, restore `mBinding.vodHistory.setOnClickListener(this::onLogo);`, remove `onVodHistory(...)`, and remove the `History` import; restore `app/build.gradle` and `docs/release-version.md` to `523 / 5.2.3-noad`; remove this follow-up block from `docs/formal-apk-parity-20260706.md`; then rebuild with `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.
## 2026-07-07 - Task: Replace launcher icon from provided image
### What was done
- Replaced the app launcher icon resources with the image from `C:\Users\52396\Desktop\1.png`.
- Generated the existing Android icon densities for `ic_launcher.png`, `ic_launcher_round.png`, and `ic_launcher-playstore.png` from the source image alpha crop.
- Backed up the previous launcher icon resources before overwrite.
- Bumped the APK version for this update from `524 / 5.2.4-noad` to `525 / 5.2.5-noad`.
- Kept the change scoped to launcher icon assets and version metadata; player UI, homepage layout, backgrounds, playback logic, and controls were not changed.

### Testing
- Passed: generated icon dimensions were verified as `48x48`, `72x72`, `96x96`, `144x144`, `192x192`, and `512x512` for the expected resource files.
- Passed: `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed successfully.
- Passed: `aapt dump badging app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk` reported `versionCode='525'` and `versionName='5.2.5-noad'`.
- Passed: `aapt dump badging` reported launcher icon resources from `res/mipmap-mdpi-v4/ic_launcher.png` through `res/mipmap-xxxhdpi-v4/ic_launcher.png`.
- Passed: extracted launcher PNGs from the built APK and confirmed packaged dimensions match the generated resources.
- Passed: started MuMu instance `0` with `mumu-cli.exe`, installed the APK with `mumu-cli adb --vmindex 0 --cmd install -r`, and install returned `Success`.
- Passed: `dumpsys package com.xingguang.video` on MuMu reported `versionCode=525` and `versionName=5.2.5-noad`.
- Passed: launched the app on MuMu; current focus reached `com.fongmi.android.tv.ui.activity.HomeActivity`.
- Passed: home UI dump showed the top-left `logo` view at `[84,150][186,252]`, which uses the replaced `@mipmap/ic_launcher` resource.
- Passed: checked logcat after install and launch; no `FATAL EXCEPTION`, `E AndroidRuntime`, `Resources$NotFoundException`, `InflateException`, `ANR`, `UnsatisfiedLinkError`, or `dlopen failed` was found.
- APK path: `app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk`; final size `82769095` bytes; final timestamp `2026/7/7 2:55:44`.

### Notes
- `app/src/main/ic_launcher-playstore.png`: regenerated the 512x512 Play Store launcher image from the provided source icon.
- `app/src/main/res/mipmap-mdpi/ic_launcher.png` and `app/src/main/res/mipmap-mdpi/ic_launcher_round.png`: regenerated 48x48 launcher assets.
- `app/src/main/res/mipmap-hdpi/ic_launcher.png` and `app/src/main/res/mipmap-hdpi/ic_launcher_round.png`: regenerated 72x72 launcher assets.
- `app/src/main/res/mipmap-xhdpi/ic_launcher.png` and `app/src/main/res/mipmap-xhdpi/ic_launcher_round.png`: regenerated 96x96 launcher assets.
- `app/src/main/res/mipmap-xxhdpi/ic_launcher.png` and `app/src/main/res/mipmap-xxhdpi/ic_launcher_round.png`: regenerated 144x144 launcher assets.
- `app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` and `app/src/main/res/mipmap-xxxhdpi/ic_launcher_round.png`: regenerated 192x192 launcher assets.
- `app/build.gradle`: bumped `versionCode` to `525` and `versionName` to `5.2.5-noad`.
- `docs/release-version.md`: updated the documented current APK version to `525 / 5.2.5-noad`.
- `docs/launcher-icon-20260707.md`: documented the icon source, generated sizes, verification, evidence, and rollback path.
- `archive/launcher-icon-backup-20260707-v524/`: backup of the previous launcher icon resources before overwrite.
- `tmp/launcher_icon_v525_apk/`: launcher resources extracted from the built APK for verification.
- `tmp/icon_v525_home.xml` and `tmp/icon_v525_home.png`: MuMu launch evidence after installing the new icon APK.
- Rollback method: copy files from `archive/launcher-icon-backup-20260707-v524/` back to the same relative paths in the repository, restore `app/build.gradle` and `docs/release-version.md` to `524 / 5.2.4-noad`, remove or update `docs/launcher-icon-20260707.md`, then rebuild with `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-07 - Task: Restore player time and network speed display
### What was done
- Reconnected the mobile VOD player control-layer time text to the player `Clock`, restoring live system time display while controls are visible.
- Widened the player control time text so the desktop-style `HH:mm:ss` value fits without truncation.
- Restyled the loading/buffering network-speed text to match the desktop player more closely with white `16sp` text while keeping the existing `Traffic.setSpeed(...)` refresh path.
- Bumped the APK version for this update from `525 / 5.2.5-noad` to `526 / 5.2.6-noad`.
- Kept the change scoped to player time/network-speed display and version metadata; player height, fullscreen sizing, backgrounds, launcher icon, playback core switching, episode list, and playback history logic were not changed.

### Testing
- Passed: `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed successfully.
- Passed: `aapt dump badging app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk` reported `versionCode='526'` and `versionName='5.2.6-noad'`.
- Passed: MuMu instance `0` installed the APK with `mumu-cli adb --vmindex 0 --cmd install -r`; install returned `Success`.
- Passed: `dumpsys package com.xingguang.video` on MuMu reported `versionCode=526` and `versionName=5.2.6-noad`.
- Passed: launched the app and entered playback from the home continue-watching card; current focus reached `com.fongmi.android.tv.ui.activity.VideoActivity`.
- Passed: tapped the player area to show controls; UI dump showed `com.xingguang.video:id/time` with `03:38:32` at `[864,78][1056,198]`.
- Passed: verified the loading/buffering network-speed path remains active in source via `Traffic.setSpeed(mBinding.progress.traffic)` and that `view_progress.xml` now defines `traffic` as white `16sp`.
- Note: MuMu playback/loading completed before UIAutomator captured a visible `traffic` node, so the net-speed visible-state evidence is resource/source based rather than a live visible XML node from this run.
- Passed: checked logcat after install, launch, playback entry, control display, and episode switch; no `FATAL EXCEPTION`, `E AndroidRuntime`, `Resources$NotFoundException`, `InflateException`, `ANR`, `UnsatisfiedLinkError`, or `dlopen failed` was found.
- APK path: `app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk`; final size `82769119` bytes; final timestamp `2026/7/7 3:35:08`.

### Notes
- `app/src/mobile/java/com/fongmi/android/tv/ui/activity/VideoActivity.java`: changed the mobile VOD player clock creation to bind the existing control-layer time view.
- `app/src/mobile/res/layout/view_control_vod.xml`: widened the player control time view and enabled tabular digits for stable `HH:mm:ss` display.
- `app/src/mobile/res/layout/view_progress.xml`: changed the buffering/loading traffic text to desktop-style white `16sp`.
- `app/build.gradle`: bumped `versionCode` to `526` and `versionName` to `5.2.6-noad`.
- `docs/release-version.md`: updated the documented current APK version to `526 / 5.2.6-noad`.
- `docs/player-regression-20260706.md`: appended the player time and network-speed follow-up with MuMu evidence.
- `tmp/player_loading_v526.xml` and `tmp/player_loading_v526.png`: evidence from the first playback-loading capture attempt.
- `tmp/player_control_v526_retry.xml` and `tmp/player_control_v526_retry.png`: evidence that player controls show the live time text.
- `tmp/player_loading_v526_retry.xml` and `tmp/player_loading_v526_retry.png`: evidence from the episode-switch loading capture attempt.
- Rollback method: restore `mClock = Clock.create();` in `VideoActivity.java`; restore the `time` view width/maxLength in `view_control_vod.xml`; restore `traffic` text size/color in `view_progress.xml`; restore `app/build.gradle` and `docs/release-version.md` to `525 / 5.2.5-noad`; remove or update the player-regression follow-up; then rebuild with `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-07 - Task: Correct player network speed position
### What was done
- Removed the incorrect network-speed text from the right side of the mobile VOD player control bar.
- Kept the network-speed feature on the desktop-aligned loading/buffering progress overlay through `Traffic.setSpeed(mBinding.progress.traffic)`.
- Bumped the APK version for this correction from `527 / 5.2.7-noad` to `528 / 5.2.8-noad`.
- Kept the change scoped to network-speed placement and version metadata; player background, launcher icon, player height, playback-core selection, episode list, fullscreen layout, and playback history logic were not changed.

### Testing
- Passed: source comparison showed desktop VOD uses `Traffic.setSpeed(mBinding.progress.traffic)` and mobile VOD now uses the same progress-layer path.
- Passed: source search showed no remaining `mBinding.control.traffic` reference and no `@+id/traffic` in `view_control_vod.xml`.
- Passed: mobile `view_progress.xml` still defines `@+id/traffic` centered under the loading indicator with white `16sp` text.
- Passed: `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed successfully.
- Passed: MuMu installed `app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk`; `dumpsys package com.xingguang.video` reported `versionCode=528` and `versionName=5.2.8-noad`.
- Passed: no-stop MuMu check kept current focus on `com.fongmi.android.tv.ui.activity.VideoActivity`; current playback screenshot was captured without `force-stop`.
- Passed: current playback UI dump contained the player `video` node and no `traffic` node while already playing, which matches the desktop behavior where speed is only shown during loading/buffering.
- Not captured: a live visible loading-speed node in MuMu; the current source loaded/played too quickly for UIAutomator to capture `traffic` while visible. This correction is verified by source parity and packaging/runtime smoke checks, not by a live visible traffic-node capture.
- APK path: `app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk`; final size `82769115` bytes; SHA-256 `FC13E4E31984FFD6C71EE0953C4B2F14E28C087D10E34990A20479139E0FED6D`.

### Notes
- `app/src/mobile/res/layout/view_control_vod.xml`: removed the wrongly placed right-side `traffic` text from the VOD control bar.
- `app/src/mobile/java/com/fongmi/android/tv/ui/activity/VideoActivity.java`: removed the control-bar `Traffic.setSpeed(...)` call while preserving the progress-layer update path.
- `app/build.gradle`: bumped `versionCode` to `528` and `versionName` to `5.2.8-noad`.
- `docs/release-version.md`: updated the documented current APK version to `528 / 5.2.8-noad`.
- `docs/player-regression-20260706.md`: documented the corrected desktop-position behavior and verification limits.
- `tmp/current-no-stop.xml` and `tmp/current-no-stop.png`: no-stop MuMu playback evidence captured without force-stopping the app.
- `tmp/mumu-speed-position-v528/`: MuMu evidence captured during the placement correction pass.
- Rollback method: restore the removed `traffic` TextView and `Traffic.setSpeed(mBinding.control.traffic)` call only if the rejected right-side placement is intentionally needed again; otherwise keep the desktop-aligned progress-layer placement. To roll back this correction completely, restore `app/build.gradle` and `docs/release-version.md` to `527 / 5.2.7-noad`, remove this follow-up block from `docs/player-regression-20260706.md`, and rebuild with `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-07 - Task: Capture visible network speed position without stopping playback
### What was done
- Verified the network-speed display location without force-stopping the running app.
- Triggered a normal loading/buffering state by tapping `第4集` on the current playback page.
- Captured the desktop-aligned network-speed display in the player loading layer, centered under the loading indicator.

### Testing
- Passed: current MuMu focus stayed on `com.fongmi.android.tv.ui.activity.VideoActivity`.
- Passed: `tmp/net-speed-position-v528-fast/speed-fast-2.png` shows `0 KB/s` under the centered loading indicator.
- Passed: `tmp/net-speed-position-v528-fast/speed-fast-3.png` shows `8.2 MB/s` under the centered loading indicator.
- Passed: the visible captures confirm the network-speed feature is present in the loading/buffering overlay and not in the right-side control bar.
- Passed: checked logcat after the capture; no `FATAL EXCEPTION`, `AndroidRuntime`, `Resources$NotFoundException`, `InflateException`, `ANR`, `UnsatisfiedLinkError`, or `dlopen failed` was found.

### Notes
- `tmp/net-speed-position-v528-fast/speed-fast-2.png`: captured the loading overlay with `0 KB/s`.
- `tmp/net-speed-position-v528-fast/speed-fast-3.png`: captured the loading overlay with `8.2 MB/s`.
- `tmp/net-speed-position-v528-fast/contact-sheet.jpg`: contact sheet of the no-stop capture sequence.
- `docs/player-regression-20260706.md`: appended the live visible capture evidence.
- `progress.md`: appended this verification record.
- Rollback method: remove the appended `Network Speed Visible Capture` section from `docs/player-regression-20260706.md` and remove this progress entry; no source rollback is needed because this task only added verification evidence.

## 2026-07-07 - Task: Align network speed style with formal decoded APK
### What was done
- Used the existing decoded formal APK resources under `apkwork/decoded` instead of re-decoding the APK.
- Restored the mobile loading/buffering network-speed text style to match the formal APK: `12sp` and `@color/xg_primary`.
- Kept the network-speed position unchanged in the loading/buffering overlay, centered under the loading indicator.
- Bumped the APK version for this update from `528 / 5.2.8-noad` to `529 / 5.2.9-noad`.

### Testing
- Passed: compared `apkwork/decoded/res/layout/view_progress.xml` with `app/src/mobile/res/layout/view_progress.xml`; both use centered `traffic`, `12sp`, `@color/xg_primary`, and `40dp` top offset.
- Passed: source search showed no right-side `traffic` in `view_control_vod.xml`; VOD still updates `Traffic.setSpeed(mBinding.progress.traffic)`.
- Passed: `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed successfully.
- Passed: MuMu installed `app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk`; `dumpsys package com.xingguang.video` reported `versionCode=529` and `versionName=5.2.9-noad`.
- Passed: launched the app, entered `VideoActivity`, tapped `第4集`, and captured the loading overlay.
- Passed: `tmp/net-speed-position-v529/v529-speed-1.png` shows `0 KB/s` directly under the centered loading indicator in the primary theme color.
- Passed: checked logcat after capture; no `FATAL EXCEPTION`, `AndroidRuntime`, `Resources$NotFoundException`, `InflateException`, `ANR`, `UnsatisfiedLinkError`, or `dlopen failed` was found.
- APK path: `app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk`; final size `82769115` bytes; SHA-256 `1A8C92BFF73BE6A240F9287A9F309F36E509BBAF448A063EDD0216177E24F6C3`.

### Notes
- `app/src/mobile/res/layout/view_progress.xml`: restored `traffic` text color and size to match the formal decoded APK.
- `app/build.gradle`: bumped `versionCode` to `529` and `versionName` to `5.2.9-noad`.
- `docs/release-version.md`: updated the documented current APK version to `529 / 5.2.9-noad`.
- `docs/player-regression-20260706.md`: appended the formal APK network-speed style alignment and MuMu evidence.
- `tmp/net-speed-position-v529/v529-speed-1.png`: visible evidence of the loading-layer network-speed text.
- `tmp/net-speed-position-v529/v529-contact-sheet.jpg`: contact sheet for the capture sequence.
- Rollback method: restore `app/src/mobile/res/layout/view_progress.xml` traffic text to the prior `16sp`/`@color/white` style only if that rejected style is intentionally needed again; otherwise keep the formal APK style. To roll back the package metadata, restore `app/build.gradle` and `docs/release-version.md` to `528 / 5.2.8-noad`, remove this follow-up block from `docs/player-regression-20260706.md`, and rebuild.

## 2026-07-07 - Task: Show network speed under fullscreen player title
### What was done
- Added live network-speed refresh to the existing fullscreen VOD top-left second-line text slot, matching the user-provided fullscreen reference image.
- Kept the speed text out of the right-side control bar and out of the small-screen controls.
- Left the loading/buffering overlay speed display unchanged.
- Bumped the APK version for this update from `529 / 5.2.9-noad` to `530 / 5.2.10-noad`.

### Testing
- Passed: `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed successfully.
- Passed: `aapt dump badging app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk` reported `versionCode='530'` and `versionName='5.2.10-noad'`.
- Passed: MuMu installed `app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk`; `dumpsys package com.xingguang.video` reported `versionCode=530` and `versionName=5.2.10-noad`.
- Passed: launched the app, entered `VideoActivity` from the home continue-watching card, showed small-screen controls, and confirmed no network-speed text appeared in the small-screen control layer.
- Passed: entered fullscreen through the player full button; `tmp/fullscreen-traffic-v530/enter_full_auto.png` shows `0 KB/s` directly under the top-left title in the fullscreen control layer.
- Passed: checked logcat after capture; no `FATAL EXCEPTION`, `E AndroidRuntime`, `Resources$NotFoundException`, `InflateException`, `ANR in`, `UnsatisfiedLinkError`, or `dlopen failed` was found.
- APK path: `app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk`; final size `82769119` bytes; SHA-256 `B194C0F2F74A62518785F360F835C49505B914E492231C67966379C2802AF9E0`.

### Notes
- `app/src/mobile/java/com/fongmi/android/tv/ui/activity/VideoActivity.java`: added a fullscreen-control-only network-speed refresh loop using the existing `control.size` text view.
- `app/build.gradle`: bumped `versionCode` to `530` and `versionName` to `5.2.10-noad`.
- `docs/release-version.md`: updated the documented current APK version to `530 / 5.2.10-noad`.
- `docs/player-regression-20260706.md`: appended the fullscreen control network-speed behavior and MuMu evidence.
- `tmp/fullscreen-traffic-v530/small_control.png`: evidence that small-screen controls are unchanged.
- `tmp/fullscreen-traffic-v530/enter_full_auto.png`: evidence that fullscreen controls show network speed under the title.
- Rollback method: restore `app/src/mobile/java/com/fongmi/android/tv/ui/activity/VideoActivity.java` to remove `mR5`, `setControlTraffic()`, `hideControlTraffic()`, and the `showControl()`/`hideControl()` callback changes; restore `app/build.gradle` and `docs/release-version.md` to `529 / 5.2.9-noad`; remove the appended fullscreen section from `docs/player-regression-20260706.md`; rebuild with `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-07 - Task: Show network speed in small player controls
### What was done
- Expanded the VOD control-layer network-speed refresh so it also runs in the small-screen player controls.
- Kept the same existing top-left control text slot and did not add a right-side network-speed text.
- Kept the loading/buffering overlay speed display unchanged.
- Bumped the APK version for this update from `530 / 5.2.10-noad` to `531 / 5.2.11-noad`.

### Testing
- Passed: `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed successfully.
- Passed: `aapt dump badging app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk` reported `versionCode='531'` and `versionName='5.2.11-noad'`.
- Passed: MuMu installed `app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk`; `dumpsys package com.xingguang.video` reported `versionCode=531` and `versionName=5.2.11-noad`.
- Passed: launched the app, entered `VideoActivity` from the home continue-watching card, returned to the small player, and showed the small-screen controls.
- Passed: `tmp/small-traffic-v531/small_visible.png` shows `0 KB/s` in the small-screen player control layer.
- Passed: `tmp/small-traffic-v531/full_visible.png` shows the small-screen player control layer later updating to `191 KB/s`.
- Passed: checked logcat after capture; no `FATAL EXCEPTION`, `E AndroidRuntime`, `Resources$NotFoundException`, `InflateException`, `ANR in`, `UnsatisfiedLinkError`, or `dlopen failed` was found.
- APK path: `app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk`; final size `82769119` bytes; SHA-256 `68F432D074903E74637101DB349F9912350605F5F3E9F02189AB84DCA6AAE9BE`.

### Notes
- `app/src/mobile/java/com/fongmi/android/tv/ui/activity/VideoActivity.java`: removed the fullscreen-only guard from the control-layer network-speed refresh so small-screen controls also update the existing `control.size` text view.
- `app/build.gradle`: bumped `versionCode` to `531` and `versionName` to `5.2.11-noad`.
- `docs/release-version.md`: updated the documented current APK version to `531 / 5.2.11-noad`.
- `docs/player-regression-20260706.md`: appended the small-player control network-speed behavior and MuMu evidence.
- `tmp/small-traffic-v531/small_visible.png`: evidence of small-screen control-layer network speed.
- `tmp/small-traffic-v531/full_visible.png`: evidence that the small-screen control-layer speed continues to refresh.
- Rollback method: restore `app/src/mobile/java/com/fongmi/android/tv/ui/activity/VideoActivity.java` so `showControl()` only calls `setControlTraffic()` when `isFullscreen() && !isLock()` and `setControlTraffic()` exits when `!isFullscreen()`; restore `app/build.gradle` and `docs/release-version.md` to `530 / 5.2.10-noad`; remove the appended small-player section from `docs/player-regression-20260706.md`; rebuild with `./gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-07 - Task: Clean generated files without touching source
### What was done
- Removed generated build outputs, local Gradle workspace cache, and temporary investigation artifacts that were not required for source retention.
- Kept source directories, the local Android SDK, local tools, and the signing keystore in place.

### Testing
- Passed: resolved all recursive deletion targets under `D:\xingkong` before removal; total pre-delete candidate size was about `1269.3 MB`.
- Passed: confirmed `D:\xingkong\app\build`, `D:\xingkong\chaquo\build`, `D:\xingkong\quickjs\build`, `D:\xingkong\catvod\build`, `D:\xingkong\build`, `D:\xingkong\.gradle`, and `D:\xingkong\tmp` no longer exist after cleanup.
- Passed: confirmed `D:\xingkong\app\src`, `D:\xingkong\catvod\src`, `D:\xingkong\chaquo\src`, `D:\xingkong\quickjs\src`, `D:\xingkong\android-sdk`, `D:\xingkong\tools`, and `D:\xingkong\apkwork\keystore` still exist.

### Notes
- `app/build`: deleted generated app build outputs.
- `chaquo/build`: deleted generated Chaquo build outputs.
- `quickjs/build`: deleted generated QuickJS build outputs.
- `catvod/build`: deleted generated CatVod build outputs.
- `build`: deleted generated root build output.
- `.gradle`: deleted local Gradle workspace cache.
- `tmp`: deleted temporary test, extraction, screenshot, and comparison artifacts.
- `progress.md`: appended this cleanup record.
- Rollback method: regenerate build/cache directories with `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`; recreate needed temporary evidence by rerunning the relevant test or extraction workflow. No source rollback is required because source files were not changed.

## 2026-07-07 - Task: Remove historical comparison and build artifacts while keeping signing config
### What was done
- Removed historical working materials, archived source snapshots, decoded APK contents, and old rebuild APK outputs.
- Preserved `apkwork/keystore` and the signing settings in `local.properties`.

### Testing
- Passed: resolved all recursive deletion targets under `D:\xingkong` before removal; total pre-delete candidate size was about `1917.6 MB`.
- Passed: confirmed `D:\xingkong\work`, `D:\xingkong\archive`, `D:\xingkong\apkwork\decoded`, `D:\xingkong\apkwork\signed-rebuild-local.apk`, `D:\xingkong\apkwork\source-latest.apk`, `D:\xingkong\apkwork\aligned-rebuild.apk`, and `D:\xingkong\apkwork\unsigned-rebuild.apk` no longer exist after cleanup.
- Passed: confirmed `D:\xingkong\apkwork\keystore` and `D:\xingkong\local.properties` still exist.
- Passed: confirmed `local.properties` still points to `D:/xingkong/apkwork/keystore/xingguang-release.p12`, and that file still exists.

### Notes
- `work`: deleted historical work files, source candidates, downloaded installers, and prior logs.
- `archive`: deleted archived snapshots and backups that were no longer needed for the current source tree.
- `apkwork/decoded`: deleted decoded APK workspace contents.
- `apkwork/signed-rebuild-local.apk`: deleted old signed rebuild APK output.
- `apkwork/source-latest.apk`: deleted old source/reference APK.
- `apkwork/aligned-rebuild.apk`: deleted old aligned rebuild APK output.
- `apkwork/unsigned-rebuild.apk`: deleted old unsigned rebuild APK output.
- `apkwork/signed-rebuild-local.apk.idsig`: deleted old signing sidecar output.
- `progress.md`: appended this cleanup record.
- Rollback method: no local backup of the deleted historical materials was kept so disk space is actually reclaimed; recover by restoring `work` or `archive` from an external backup/source download, and regenerate APK outputs by rerunning the rebuild workflow. Signing rollback is not required because `local.properties` and `apkwork/keystore` were preserved.

## 2026-07-07 - Task: Remove source reference copy
### What was done
- Removed the `fongmi-tv-source` reference source copy after user confirmation.
- Kept the current project source directories and signing configuration in place.

### Testing
- Passed: resolved `D:\xingkong\fongmi-tv-source` under `D:\xingkong` before removal; pre-delete size was about `94.3 MB`.
- Passed: confirmed `D:\xingkong\fongmi-tv-source` no longer exists after cleanup.
- Passed: confirmed `D:\xingkong\app\src`, `D:\xingkong\catvod\src`, `D:\xingkong\chaquo\src`, `D:\xingkong\quickjs\src`, `D:\xingkong\apkwork\keystore`, `D:\xingkong\apkwork\keystore\xingguang-release.p12`, and `D:\xingkong\local.properties` still exist.

### Notes
- `fongmi-tv-source`: deleted the reference source copy that was not part of the active Gradle project.
- `progress.md`: appended this cleanup record.
- Rollback method: no local backup was kept so disk space is reclaimed; restore `fongmi-tv-source` from the original source repository or an external backup if that reference copy is needed again.

## 2026-07-07 - Task: Create futuristic UI sketch
### What was done
- Created a standalone futuristic UI design board for the Xingguang video app, covering mobile home, VOD player, live overlay, leanback home, and config center concepts.
- Exported a browser-rendered PNG preview of the sketch for quick visual review.

### Testing
- Passed: confirmed `docs/futuristic-ui-sketch.html` exists and contains the required sketch sections: `Mobile Home`, `Leanback Home`, `Vod Player`, `Live Overlay`, `Config Center`, and the design mapping notes.
- Passed: rendered the HTML with local Chrome headless to `docs/futuristic-ui-sketch.png`.
- Passed: visually inspected the generated PNG and found no obvious blank screen, layout overlap, or unreadable major text blocks.

### Notes
- `docs/futuristic-ui-sketch.html`: added the standalone futuristic UI sketch and design mapping notes.
- `docs/futuristic-ui-sketch.png`: added the generated preview image from the HTML sketch.
- `progress.md`: appended this design-deliverable record.
- Rollback method: delete `docs/futuristic-ui-sketch.html` and `docs/futuristic-ui-sketch.png`, then remove this progress entry from `progress.md`.

## 2026-07-07 - Task: Create alternate futuristic UI sketch with launcher icon
### What was done
- Created a second standalone futuristic UI design board using the current star-shaped launcher icon as the visual anchor.
- Changed the direction from cyber grid styling to a softer glass-cinema style with dark silver surfaces, rounded focus states, and star-like highlight colors.
- Exported a browser-rendered PNG preview for visual comparison with the first sketch.

### Testing
- Passed: confirmed `docs/futuristic-ui-sketch-v2.html` exists and contains the required sketch sections: `Mobile Home`, `Leanback Home`, `Vod Player`, `Live Overlay`, `Config Center`, and a reference to `ic_launcher.png`.
- Passed: rendered the HTML with local Chrome headless to `docs/futuristic-ui-sketch-v2.png`.
- Passed: visually inspected the generated PNG and confirmed the star-shaped launcher icon is used instead of the previous geometric logo; no obvious blank screen, layout overlap, or unreadable major text blocks were found.

### Notes
- `docs/futuristic-ui-sketch-v2.html`: added the alternate glass-cinema futuristic UI sketch based on the current launcher icon.
- `docs/futuristic-ui-sketch-v2.png`: added the generated preview image for the second sketch.
- `progress.md`: appended this alternate design-deliverable record.
- Rollback method: delete `docs/futuristic-ui-sketch-v2.html` and `docs/futuristic-ui-sketch-v2.png`, then remove this progress entry from `progress.md`.

## 2026-07-07 - Task: Upgrade playback cores to stable formal versions
### What was done
- Upgraded the Gradle playback core line to formal stable releases only: Media3 / EXO `1.10.1` and MPV `nextlib-media3ext` `1.10.1-0.13.0`.
- Excluded preview builds such as Media3 `1.11.0-alpha01` and left local IJK native `.so` libraries unchanged.
- Bumped the APK version to `versionCode 532` and `versionName 5.2.12-noad`.
- Built the mobile arm64 debug APK at `app/build/outputs/apk/mobileArm64_v8a/debug/mobile-arm64_v8a.apk`.

### Testing
- Passed: `.\gradlew.bat :app:dependencyInsight --configuration mobileArm64_v8aDebugRuntimeClasspath --dependency androidx.media3:media3-exoplayer --no-daemon` resolved Media3 / EXO modules to `1.10.1` with Gradle status `release`.
- Passed: `.\gradlew.bat :app:dependencyInsight --configuration mobileArm64_v8aDebugRuntimeClasspath --dependency io.github.anilbeesetti:nextlib-media3ext --no-daemon` resolved MPV extension to `1.10.1-0.13.0` with Gradle status `release`.
- Passed: searched `build.gradle` and `app/build.gradle`; no `alpha`, `beta`, `preview`, or `rc[0-9]` playback dependency version was present.
- Passed: `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed successfully.
- Passed: APK badging reported `package='com.xingguang.video'`, `versionCode='532'`, and `versionName='5.2.12-noad'`.
- Passed: APK SHA-256 is `BA9835D01AB722329B26658F798F0A7817F083B6E3788088E3E660633FBD58C6`; size is `82814130` bytes.
- Passed: MuMu package state reported `versionCode=532` and `versionName=5.2.12-noad`.
- Passed: MuMu was running `VideoActivity`; current app process logcat had no `FATAL EXCEPTION`, `E AndroidRuntime`, `Resources$NotFoundException`, `InflateException`, `ANR in`, `UnsatisfiedLinkError`, `dlopen failed`, `NoSuchMethodError`, or `NoClassDefFoundError`.
- Passed: playback settings still exposed `EXO / IJK / MPV`; switching `EXO -> MPV -> EXO` worked and final setting was restored to `EXO`.

### Notes
- `build.gradle`: updated `media3Version` to `1.10.1`.
- `app/build.gradle`: bumped version fields to `532 / 5.2.12-noad` and updated `nextlib-media3ext` to `1.10.1-0.13.0`.
- `docs/release-version.md`: updated the documented current APK version to `532 / 5.2.12-noad`.
- `docs/player-regression-20260706.md`: appended the stable playback-core upgrade scope, verification, APK hash, and MuMu evidence.
- `progress.md`: appended this stable playback-core upgrade record.
- `tmp/player-core-upgrade-v532/*`: retained MuMu screenshot/XML evidence for home, settings, playback-core dialog, MPV switch, EXO restore, and playback entry.
- Rollback method: restore `build.gradle` `media3Version` to `1.9.2`; restore `app/build.gradle` `versionCode` / `versionName` to `531 / 5.2.11-noad` and `nextlib-media3ext` to `1.9.1-0.11.0`; restore `docs/release-version.md` to `531 / 5.2.11-noad`; remove the stable playback-core upgrade section from `docs/player-regression-20260706.md` and this progress entry; rebuild with `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-07 - Task: Align versionName with versionCode 532
### What was done
- Changed the current APK `versionName` from `5.2.12-noad` to `5.3.2` while keeping `versionCode 532`.
- Updated the release-version rule so the documented naming example maps `versionCode 532` to `versionName 5.3.2`.
- Restored the missing `ic_logo` drawable resource as an alias to the current launcher icon because the Java build referenced `R.drawable.ic_logo` and packaging was blocked without it.
- Rebuilt and installed the mobile arm64 debug APK.

### Testing
- Failed then fixed: the first rebuild failed at `:app:compileMobileArm64_v8aDebugJavaWithJavac` because `R.drawable.ic_logo` was missing.
- Passed: after restoring `ic_logo`, `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed successfully.
- Passed: APK badging reported `package='com.xingguang.video'`, `versionCode='532'`, and `versionName='5.3.2'`.
- Passed: APK SHA-256 is `3B82B65F350FA749B3CD10F18D71448A43F07196F8B2FD8858A112E667DA8EB3`; size is `82763921` bytes.
- Passed: MuMu install returned `Success`; device package state reported `versionCode=532` and `versionName=5.3.2`.
- Passed: launched `HomeActivity` in MuMu after install; post-launch logcat had no `FATAL EXCEPTION`, `E AndroidRuntime`, `Resources$NotFoundException`, `InflateException`, `ANR in`, `UnsatisfiedLinkError`, `dlopen failed`, `NoSuchMethodError`, or `NoClassDefFoundError`.

### Notes
- `app/build.gradle`: changed the current `versionName` to `5.3.2`.
- `docs/release-version.md`: updated the current version and naming rule to document `532 / 5.3.2`.
- `app/src/main/res/drawable/ic_logo.xml`: restored the missing drawable resource name as a launcher-icon alias so existing source references compile.
- `docs/player-regression-20260706.md`: appended the version-name alignment verification and APK hash.
- `progress.md`: appended this version-name alignment record.
- Rollback method: restore `app/build.gradle` `versionName` to `5.2.12-noad`; restore `docs/release-version.md` to the previous `5.2.12-noad` wording; delete `app/src/main/res/drawable/ic_logo.xml` only if the missing-resource compile failure is intentionally restored; remove the version-name alignment section from `docs/player-regression-20260706.md` and this progress entry; rebuild with `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-07 - Task: Fix local wallpaper loading
### What was done
- Fixed local wallpaper path resolution so saved values like `file://v532_setting.png` resolve to the external-storage file under `/sdcard`.
- Made the wallpaper image view visible when loading image, GIF, built-in, or video snapshot wallpaper content.
- Changed the mobile home activity root background to transparent so the existing wallpaper view behind the page is no longer covered by an opaque root layout.
- Bumped the APK version to `versionCode 533` and `versionName 5.3.3`.

### Testing
- Passed: `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed successfully.
- Passed: APK badging reported `package='com.xingguang.video'`, `versionCode='533'`, and `versionName='5.3.3'`.
- Passed: APK SHA-256 is `3C8C78D54FB93AA7E1C4477F951777CFA5440C9EE4286ED184E4A16A6BA6E043`; size is `82853169` bytes.
- Passed: `apksigner verify --print-certs` reported signing certificate SHA-256 `775b4b773f689575d436784b1b2f7b3f08e8e8bef6ab11276928c752c783da24`.
- Passed: MuMu install returned `Success`; device package state reported `versionCode=533` and `versionName=5.3.3`.
- Passed: current saved wallpaper config was `file://v532_setting.png`, and `/sdcard/v532_setting.png` existed.
- Passed: after clearing `files/wallpaper_0` and `files/wallpaper_cache`, tapping wallpaper refresh regenerated both files.
- Passed: SHA-256 matched between `/sdcard/v532_setting.png` and `files/wallpaper_0`: `fea3650afe863574cca33f8f7ae4dee61ba64a3f6b4575a8b247121ad83bf956`.
- Passed: UI dump showed `com.xingguang.video:id/image` visible behind the setting page and `wallUrl` still displaying `file://v532_setting.png`.
- Passed: post-refresh logcat had no `FATAL EXCEPTION`, `E AndroidRuntime`, `Resources$NotFoundException`, `InflateException`, `ANR in`, `UnsatisfiedLinkError`, `dlopen failed`, `NoSuchMethodError`, `NoClassDefFoundError`, `FileNotFoundException`, or `error_config_get`.

### Notes
- `catvod/src/main/java/com/github/catvod/utils/Path.java`: fixed local `file:` path resolution for external-storage relative paths.
- `app/src/main/java/com/fongmi/android/tv/ui/custom/CustomWallView.java`: made wallpaper image content visible when loaded.
- `app/src/mobile/res/layout/activity_home.xml`: changed the root background to transparent so `CustomWallView` can show through.
- `app/build.gradle`: bumped version fields to `533 / 5.3.3`.
- `docs/release-version.md`: updated the documented current APK version and naming example to `533 / 5.3.3`.
- `docs/wallpaper-regression-20260707.md`: added the wallpaper fix scope, MuMu verification, APK hash, and evidence list.
- `tmp/wallpaper-v533/*`: retained MuMu UI dump and screenshot evidence for the wallpaper refresh verification.
- Rollback method: restore `Path.local` to only strip `file:/` and check `new File(root(), path)` first; remove the added `binding.image.setVisibility(VISIBLE)` calls from `CustomWallView`; restore `activity_home.xml` root background to `@color/xg_background`; restore `app/build.gradle` and `docs/release-version.md` to `532 / 5.3.2`; remove `docs/wallpaper-regression-20260707.md` and this progress entry; rebuild with `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-07 - Task: Complete alternate UI sketch settings and icon controls
### What was done
- Replaced the mobile home shortcut text placeholders with SVG icon buttons for search, favorite, and history.
- Expanded the alternate UI sketch settings center to include the real main setting entries: VOD, live, wallpaper, player settings, incognito mode, image size, DoH, cache, backup, restore, and version.
- Added the player settings sub-feature grid for player engine, render mode, scale, subtitle, buffer, speed, tunnel playback, audio decode, video decode, auto line switching, AAC track, danmaku load, adblock, background play, and User-Agent.

### Testing
- Passed: rendered `docs/futuristic-ui-sketch-v2.html` with local Chrome headless to refresh `docs/futuristic-ui-sketch-v2.png`.
- Passed: visually inspected the refreshed PNG and confirmed the mobile shortcut buttons now show icons and the settings center shows the expanded main and player setting functions.
- Passed: verified the HTML with explicit UTF-8 reading; no required main setting or player setting labels were missing, and icon buttons contain inline SVG.

### Notes
- `docs/futuristic-ui-sketch-v2.html`: replaced text shortcut placeholders with SVG icons and expanded the settings center to match the app's real settings scope.
- `docs/futuristic-ui-sketch-v2.png`: refreshed the preview image after the sketch update.
- `progress.md`: appended this icon and settings-completion record.
- Rollback method: restore `docs/futuristic-ui-sketch-v2.html` and `docs/futuristic-ui-sketch-v2.png` from the previous version, then remove this progress entry from `progress.md`.

## 2026-07-07 - Task: Create five distinct futuristic UI sketch directions
### What was done
- Created a combined UI design board with five distinct futuristic directions: starcore glass, minimal cinema, neon flight, data console, and nebula editorial.
- Gave each direction a different brand icon concept instead of reusing the same launcher or previous sketch icon.
- Included mobile home, playback/live emphasis, settings center, and player-setting coverage in each direction.
- Exported a browser-rendered PNG preview for side-by-side review.

### Testing
- Passed: confirmed `docs/futuristic-ui-five-sketches.html` exists and contains five version blocks.
- Passed: confirmed all five version titles are present and the board contains five brand icon labels.
- Passed: confirmed the HTML includes the required settings and player-setting labels, including VOD, live, wallpaper, player settings, incognito, image size, DoH, cache, backup, restore, version, render mode, scale, subtitle, buffer, speed, tunnel playback, decode options, auto line switching, danmaku, adblock, background play, and User-Agent.
- Passed: rendered the HTML with local Chrome headless to `docs/futuristic-ui-five-sketches.png`.
- Passed: visually inspected the generated PNG and confirmed all five styles render, are visibly different, and do not show obvious blank screens, major overlaps, or repeated brand icons.

### Notes
- `docs/futuristic-ui-five-sketches.html`: added the five-version futuristic UI sketch board.
- `docs/futuristic-ui-five-sketches.png`: added the generated preview image for the five-version board.
- `progress.md`: appended this five-version design-deliverable record.
- Rollback method: delete `docs/futuristic-ui-five-sketches.html` and `docs/futuristic-ui-five-sketches.png`, then remove this progress entry from `progress.md`.

## 2026-07-07 - Task: Redesign five futuristic UI sketch palettes
### What was done
- Replaced the previous five-version UI sketch board with a redesigned set focused on cleaner and more polished color systems.
- Created five new visual directions: obsidian gold cinema, arctic glass, jade aurora, crimson cinema, and titanium electric.
- Kept the requirement that every direction uses a different brand icon concept.
- Preserved coverage for mobile home, playback emphasis, settings center, and player-setting functions.
- Re-exported the PNG preview for review.

### Testing
- Passed: confirmed `docs/futuristic-ui-five-sketches.html` exists and contains five version blocks.
- Passed: confirmed all five new version titles are present and the board contains five brand icon labels.
- Passed: confirmed the HTML still includes the required settings and player-setting labels, including VOD, live, wallpaper, player settings, incognito, image size, DoH, cache, backup, restore, version, render mode, scale, subtitle, buffer, speed, tunnel playback, decode options, auto line switching, danmaku, adblock, background play, and User-Agent.
- Passed: rendered the redesigned HTML with local Chrome headless to `docs/futuristic-ui-five-sketches.png`.
- Passed: visually inspected the generated PNG and confirmed all five redesigned styles render, use distinct palettes and icons, and do not show obvious blank screens or major overlaps.

### Notes
- `docs/futuristic-ui-five-sketches.html`: replaced the earlier five-version board with the redesigned palette set.
- `docs/futuristic-ui-five-sketches.png`: refreshed the preview image after the redesign.
- `progress.md`: appended this five-version redesign record.
- Rollback method: restore `docs/futuristic-ui-five-sketches.html` and `docs/futuristic-ui-five-sketches.png` from the previous version if needed, then remove this progress entry from `progress.md`.

## 2026-07-08 - Task: Redesign five UI sketch directions again
### What was done
- Replaced the five-version UI sketch board with a third redesigned set using five new visual directions: lunar screen, ribbon stream, porcelain theater, turquoise dark stage, and frost violet station.
- Redrew the brand icon concept for each direction so the five versions do not reuse the previous icon set.
- Preserved coverage for mobile home, playback/live emphasis, settings center, and player-setting functions.
- Re-exported the PNG preview for review.

### Testing
- Passed: confirmed `docs/futuristic-ui-five-sketches.html` exists and contains five version blocks.
- Passed: confirmed all five new version titles are present and the board contains five brand icon labels.
- Passed: confirmed the HTML still includes the required settings and player-setting labels, including VOD, live, wallpaper, player settings, incognito, image size, DoH, cache, backup, restore, version, render mode, scale, subtitle, buffer, speed, tunnel playback, decode options, auto line switching, danmaku, adblock, background play, and User-Agent.
- Passed: rendered the redesigned HTML with local Chrome headless to `docs/futuristic-ui-five-sketches.png`.
- Passed: visually inspected the generated PNG and confirmed all five redesigned styles render with distinct color directions and no obvious blank screens or major overlaps.

### Notes
- `docs/futuristic-ui-five-sketches.html`: replaced the previous five-version board with the third redesigned set.
- `docs/futuristic-ui-five-sketches.png`: refreshed the preview image after the third redesign.
- `progress.md`: appended this third five-version redesign record.
- Rollback method: restore `docs/futuristic-ui-five-sketches.html` and `docs/futuristic-ui-five-sketches.png` from the previous version if needed, then remove this progress entry from `progress.md`.

## 2026-07-08 - Task: Redesign five UI sketches with distinct layouts
### What was done
- Replaced the five-version UI sketch board with five structurally different layouts instead of reusing one phone-and-panel template.
- Created five distinct directions: orbital poster flow, gold cinema remote screen, source control console, live program hub, and porcelain minimal screen.
- Redrew the brand icon concept for each direction and kept icon controls as SVG buttons.
- Preserved coverage for VOD, live, playback emphasis, settings center, and player-setting functions.

### Testing
- Passed: confirmed `docs/futuristic-ui-five-sketches.html` exists and contains five sketch blocks.
- Passed: confirmed all five new version titles are present and the board contains five brand icon labels.
- Passed: confirmed the HTML includes the required settings and player-setting labels, including VOD, live, wallpaper, player settings, incognito, image size, DoH, cache, backup, restore, version, render mode, scale, subtitle, buffer, speed, tunnel playback, decode options, auto line switching, AAC track, danmaku, adblock, background play, and User-Agent.
- Passed: rendered the redesigned HTML with local Chrome headless to `docs/futuristic-ui-five-sketches.png`.
- Passed: visually inspected the generated PNG and confirmed the five sketches now use different layout structures, not just different palettes.

### Notes
- `docs/futuristic-ui-five-sketches.html`: replaced the previous similar-looking five-version board with five structurally different UI sketches.
- `docs/futuristic-ui-five-sketches.png`: refreshed the preview image after the layout redesign.
- `progress.md`: appended this distinct-layout redesign record.
- Rollback method: restore `docs/futuristic-ui-five-sketches.html` and `docs/futuristic-ui-five-sketches.png` from the previous version if needed, then remove this progress entry from `progress.md`.

## 2026-07-08 - Task: Complete five UI sketches with all core screens
### What was done
- Reworked the five-version UI sketch board so each design direction includes home, player, live, and settings screen sketches instead of showing only a settings/control-console concept.
- Kept the five layout directions structurally different and retained distinct brand icons.
- Preserved coverage for the app's real main settings and player-setting functions.

### Testing
- Passed: confirmed `docs/futuristic-ui-five-sketches.html` contains five sketch blocks and five brand icon labels.
- Passed: confirmed each sketch includes `首页`, `播放页`, `直播页`, and `设置页` labels.
- Passed: confirmed required main settings and player-setting labels are present, including VOD/live/wallpaper/player settings/incognito/image size/DoH/cache/backup/restore/version and player engine/render/scale/subtitle/buffer/speed/tunnel/decode/auto line/AAC/danmaku/adblock/background/User-Agent.
- Passed: confirmed `docs/futuristic-ui-five-sketches.png` exists as the exported preview image.
- Passed: visually inspected the generated PNG and confirmed all five sketches show the four core screen areas.

### Notes
- `docs/futuristic-ui-five-sketches.html`: updated the five-version sketch board so every design direction includes home, player, live, and settings sketches.
- `docs/futuristic-ui-five-sketches.png`: refreshed the preview image after the complete-screen update.
- `progress.md`: appended this complete-screen redesign record.
- Rollback method: restore `docs/futuristic-ui-five-sketches.html` and `docs/futuristic-ui-five-sketches.png` from the previous version if needed, then remove this progress entry from `progress.md`.

## 2026-07-08 - Task: Replace five UI sketches with a cleaner futuristic style
### What was done
- Replaced the previous five-version UI sketch board with a new cleaner futuristic direction after the existing style was rejected.
- Created five new visual styles: black crystal cinema OS, arctic blue glass screen, jade source-control console, ruby gold theater screen, and titanium gray media station.
- Kept each version as a complete interface sketch with home, player, live, and settings screens, and redrew the brand icon concept for every version.
- Preserved coverage for the app's main settings and player-setting functions.

### Testing
- Passed: confirmed `docs/futuristic-ui-five-sketches.html` contains five sketch blocks.
- Passed: confirmed the five new version titles are present and there are five brand icon labels.
- Passed: confirmed each sketch includes `首页`, `播放页`, `直播页`, and `设置页` labels.
- Passed: confirmed required main settings and player-setting labels are present, including VOD/live/wallpaper/player settings/incognito/image size/DoH/cache/backup/restore/version and player engine/render/scale/subtitle/buffer/speed/tunnel/decode/auto line/AAC/danmaku/adblock/background/User-Agent.
- Passed: rendered the HTML with local Chrome headless to `docs/futuristic-ui-five-sketches.png`.
- Passed: visually inspected the generated PNG and confirmed the new sketches render without obvious blank screens or major overlaps.

### Notes
- `docs/futuristic-ui-five-sketches.html`: replaced the rejected style with five cleaner futuristic UI sketch directions.
- `docs/futuristic-ui-five-sketches.png`: refreshed the preview image after the style replacement.
- `progress.md`: appended this style-replacement record.
- Rollback method: restore `docs/futuristic-ui-five-sketches.html` and `docs/futuristic-ui-five-sketches.png` from the previous version if needed, then remove this progress entry from `progress.md`.

## 2026-07-08 - Task: Redesign UI sketches around actual project pages and functions
### What was done
- Reworked the UI sketch board so the designs are based on the project's actual mobile Android pages instead of generic futuristic panels.
- Mapped each design direction to the real page structure: HomeActivity bottom navigation, VodFragment VOD page, VideoActivity playback detail page, LiveActivity live player, SettingFragment main settings, and SettingPlayerFragment player settings.
- Added the actual functional areas into the sketches, including VOD source toolbar, search, keep, history, continue watching, category chips, filter/link/top FABs, playback controls, line/quality/episode/content sections, live group/channel/EPG columns, source settings, and player-setting rows.
- Kept five distinct visual directions with different brand icon concepts.

### Testing
- Passed: confirmed `docs/futuristic-ui-five-sketches.html` contains five sketch blocks and five brand icon labels.
- Passed: confirmed each sketch includes the six actual page/status labels: home container, VOD page, playback detail page, live page, main settings page, and player settings page.
- Passed: confirmed required project functions are present, including bottom navigation, VOD/live/settings navigation, search, keep, history, continue watching, category, filter, link, top, line, quality, episode, content, cast, info, group, channel, EPG, main settings, and player settings.
- Passed: confirmed required main settings and player-setting labels are present, including VOD/live/wallpaper/player settings/incognito/image size/DoH/cache/backup/restore/version and player engine/render/scale/subtitle/buffer/speed/tunnel/decode/auto line/AAC/danmaku/adblock/background/User-Agent.
- Passed: rendered the HTML with local Chrome headless to `docs/futuristic-ui-five-sketches.png`.
- Passed: visually inspected the generated PNG and confirmed all five sketches render with the actual project page structure visible.

### Notes
- `docs/futuristic-ui-five-sketches.html`: replaced the generic style board with a project-page-based UI sketch board.
- `docs/futuristic-ui-five-sketches.png`: refreshed the preview image after the project-page-based redesign.
- `progress.md`: appended this actual-page redesign record.
- Rollback method: restore `docs/futuristic-ui-five-sketches.html` and `docs/futuristic-ui-five-sketches.png` from the previous version if needed, then remove this progress entry from `progress.md`.

## 2026-07-08 - Task: Replace UI sketches with five more distinct visual styles
### What was done
- Replaced the previous actual-page UI sketch board with five more visually distinct styles after the existing styles were rejected.
- Created five new directions: black-red cinema, ice-blue glass, live sports, source-control terminal, and daylight clean system.
- Kept the sketches grounded in the project's real pages and functions: HomeActivity bottom navigation, VodFragment VOD page, VideoActivity playback detail page, LiveActivity live player, main settings, and player settings.
- Changed layout emphasis, color systems, brand icons, focus states, and panel density across the five versions instead of only recoloring the same structure.

### Testing
- Passed: confirmed `docs/futuristic-ui-five-sketches.html` contains five style blocks and five brand icon labels.
- Passed: confirmed the five new style names are present: black-red cinema, ice-blue glass, live sports, source-control terminal, and daylight clean system.
- Passed: confirmed required project functions are present, including bottom navigation, VOD/live/settings navigation, search, keep, history, continue watching, category, filter, link, top, cast, info, line, quality, episode, content, live group/channel/EPG, main settings, and player settings.
- Passed: confirmed required main settings and player-setting labels are present, including VOD/live/wallpaper/player settings/incognito/image size/DoH/cache/backup/restore/version and player engine/render/scale/subtitle/buffer/speed/tunnel/decode/auto line/AAC/danmaku/adblock/background/User-Agent.
- Passed: rendered the HTML with local Chrome headless to `docs/futuristic-ui-five-sketches.png`.
- Passed: visually inspected the generated PNG and confirmed all five new styles render fully with visibly different visual directions.

### Notes
- `docs/futuristic-ui-five-sketches.html`: replaced the previous actual-page sketch board with five more distinct visual style directions.
- `docs/futuristic-ui-five-sketches.png`: refreshed the preview image after the visual-style replacement.
- `progress.md`: appended this visual-style replacement record.
- Rollback method: restore `docs/futuristic-ui-five-sketches.html` and `docs/futuristic-ui-five-sketches.png` from the previous version if needed, then remove this progress entry from `progress.md`.

## 2026-07-08 - Task: Rework UI sketches into a more restrained real-app style
### What was done
- Replaced the overly stylized five-version sketch board with a more restrained set closer to the earlier real-page mapping direction.
- Created five calmer directions: mist blue cinema, graphite system, indigo star map, teal source-control, and ivory light system.
- Kept each direction grounded in the project's actual pages and functions: HomeActivity bottom navigation, VodFragment VOD page, VideoActivity playback detail page, LiveActivity live player, main settings, and player settings.
- Reduced aggressive colors and concept-heavy presentation while preserving visible differences in palette, focus state, icons, and information emphasis.

### Testing
- Passed: confirmed `docs/futuristic-ui-five-sketches.html` contains five direction blocks and five brand icon labels.
- Passed: confirmed the five new restrained style names are present.
- Passed: confirmed required project functions are present, including bottom navigation, VOD/live/settings navigation, search, keep, history, continue watching, category, filter, link, top, cast, info, line, quality, episode, content, live group/channel/EPG, main settings, and player settings.
- Passed: confirmed required main settings and player-setting labels are present, including VOD/live/wallpaper/player settings/incognito/image size/DoH/cache/backup/restore/version and player engine/render/scale/subtitle/buffer/speed/tunnel/decode/auto line/AAC/danmaku/adblock/background/User-Agent.
- Passed: rendered the HTML with local Chrome headless to `docs/futuristic-ui-five-sketches.png`.
- Passed: visually inspected the generated PNG and confirmed all five restrained styles render fully without obvious blank screens or major overlaps.

### Notes
- `docs/futuristic-ui-five-sketches.html`: replaced the over-stylized board with five calmer real-app UI sketch directions.
- `docs/futuristic-ui-five-sketches.png`: refreshed the preview image after the restrained-style rework.
- `progress.md`: appended this restrained-style rework record.
- Rollback method: restore `docs/futuristic-ui-five-sketches.html` and `docs/futuristic-ui-five-sketches.png` from the previous version if needed, then remove this progress entry from `progress.md`.

## 2026-07-08 - Task: Apply 05 cloud-white light system UI to mobile build
### What was done
- Reworked the mobile app from the paper-black playlist look toward the selected `05 cloud-white light system` direction.
- Changed the mobile theme to a white, blue-gray, and system-blue palette while keeping VOD and live playback surfaces black for video contrast.
- Updated VOD library cards, continue-watching priority block, bottom navigation, detail page, settings pages, search/receive poster placeholders, chips, badges, and common rows to match the cloud-white UI direction.
- Bumped the user-facing mobile APK version to `534 / 5.3.4` and added a dedicated UI change note under `docs/`.

### Testing
- Passed: `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed with `BUILD SUCCESSFUL`.
- Passed: built APK exists at `D:\xingkong\app\build\outputs\apk\mobileArm64_v8a\debug\mobile-arm64_v8a.apk`, size `82765485` bytes, timestamp `2026/7/8 15:53:29`.
- Passed: `aapt2 dump badging` shows package `com.xingguang.video`, `versionCode='534'`, `versionName='5.3.4'`, `minSdkVersion:'26'`, `targetSdkVersion:'28'`, and label `星光影视`.
- Passed: `apksigner verify --print-certs` shows certificate SHA-256 `775b4b773f689575d436784b1b2f7b3f08e8e8bef6ab11276928c752c783da24`.
- Passed: resource scan found no remaining old paper-black palette literals `#ffe1d8c8`, `#ffb44c3e`, `#ff7e332b`, `#ff756f65`, `#fff4f0e8`, or malformed `floatingactionButton` class names under `app/src/mobile/res`.
- Not run: runtime install and screenshot verification because `adb devices` returned no connected devices and `adb connect 127.0.0.1:16384` was refused by the local machine.

### Notes
- `app/build.gradle`: bumped the mobile APK version fields to `534 / 5.3.4`.
- `app/src/mobile/res/values/colors.xml`: replaced the paper-black palette with cloud-white, blue-gray, system-blue, border, media placeholder, and badge color tokens.
- `app/src/mobile/res/values/styles.xml`: reduced modal sheet corner size to align with the restrained 8dp card system.
- `app/src/mobile/res/drawable/shape_cloud_hero.xml`: added the light blue continue-watching priority panel background.
- `app/src/mobile/res/drawable/shape_cloud_bottom_nav.xml`: added the white bottom navigation background with blue-gray border.
- `app/src/mobile/res/drawable/shape_paper_panel.xml`: switched common panels to white fill with cloud-white border.
- `app/src/mobile/res/drawable/shape_paper_card.xml`: switched VOD cards to blue-gray fill with cloud-white border.
- `app/src/mobile/res/drawable/shape_vod_list.xml`: switched list card borders to the cloud-white border token.
- `app/src/mobile/res/drawable/shape_item.xml`: switched settings/common rows to white fill with cloud-white border.
- `app/src/mobile/res/drawable/shape_item_round_normal.xml`: switched normal chips to white fill with cloud-white border.
- `app/src/mobile/res/drawable/shape_vod_name.xml`: switched title overlays to neutral white.
- `app/src/mobile/res/drawable/shape_vod_site.xml`: changed source badges to light system blue.
- `app/src/mobile/res/drawable/shape_vod_year.xml`: changed year badges to light slate blue.
- `app/src/mobile/res/drawable/shape_vod_remark.xml`: changed remark badges to light teal.
- `app/src/mobile/res/drawable/shape_vod_time.xml`: changed time badges to dark navy for video contrast.
- `app/src/mobile/res/drawable/shape_control.xml`: neutralized the player control border to white.
- `app/src/mobile/res/drawable/shape_widget.xml`: neutralized the player widget border to white.
- `app/src/mobile/res/layout/activity_home.xml`: applied the cloud-white bottom navigation background and height.
- `app/src/mobile/res/layout/fragment_vod.xml`: applied the cloud hero background to continue watching and kept cloud-white FAB coloring.
- `app/src/mobile/res/layout/adapter_vod.xml`: changed VOD poster placeholders and progress track to cloud-white tokens.
- `app/src/mobile/res/layout/adapter_vod_rect.xml`: changed rectangular VOD poster placeholders to the cloud-white media token.
- `app/src/mobile/res/layout/adapter_vod_list.xml`: changed list VOD poster placeholders to the cloud-white media token.
- `app/src/mobile/res/layout/adapter_search.xml`: changed search result poster placeholders to the cloud-white media token.
- `app/src/mobile/res/layout/dialog_receive.xml`: changed receive dialog poster placeholders to the cloud-white media token.
- `app/src/mobile/res/layout/activity_video.xml`: set the detail page background to cloud white and changed the content accent stripe to system blue.
- `app/src/mobile/res/layout/fragment_setting.xml`: set settings root and toolbar backgrounds to cloud-white surfaces.
- `app/src/mobile/res/layout/fragment_setting_player.xml`: set player-settings root and toolbar backgrounds to cloud-white surfaces.
- `docs/release-version.md`: updated the documented current version and example to `534 / 5.3.4`.
- `docs/cloud-white-ui-20260708.md`: documented the cloud-white UI scope, version, and verification command.
- `progress.md`: appended this implementation and verification record.
- Rollback method: restore the listed resource/layout/version files from the pre-task source backup or version-control baseline, delete `app/src/mobile/res/drawable/shape_cloud_hero.xml`, `app/src/mobile/res/drawable/shape_cloud_bottom_nav.xml`, and `docs/cloud-white-ui-20260708.md`, set `app/build.gradle` and `docs/release-version.md` back to `533 / 5.3.3`, then rebuild with `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-08 - Task: Fix recent playback page background bleed-through
### What was done
- Fixed the recent playback page so the previous settings page no longer shows through behind the toolbar and history grid.
- Added opaque cloud-white backgrounds to the recent playback root, toolbar, and content container.
- Bumped the user-facing mobile APK version to `535 / 5.3.5` and updated the cloud-white UI documentation with the recent playback fix.

### Testing
- Passed: `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed with `BUILD SUCCESSFUL`.
- Passed: built APK exists at `D:\xingkong\app\build\outputs\apk\mobileArm64_v8a\debug\mobile-arm64_v8a.apk`, size `82765521` bytes, timestamp `2026/7/8 16:02:13`.
- Passed: `aapt2 dump badging` shows package `com.xingguang.video`, `versionCode='535'`, `versionName='5.3.5'`, `minSdkVersion:'26'`, `targetSdkVersion:'28'`, and label `星光影视`.
- Passed: `apksigner verify --print-certs` shows certificate SHA-256 `775b4b773f689575d436784b1b2f7b3f08e8e8bef6ab11276928c752c783da24`.
- Not run: runtime install and screenshot verification because `adb devices` returned no connected devices and `adb connect 127.0.0.1:16384` was refused by the local machine.

### Notes
- `app/src/mobile/res/layout/activity_history.xml`: added cloud-white background to the root, toolbar, and progress container to stop the settings page from bleeding through behind recent playback content.
- `app/build.gradle`: bumped the mobile APK version fields to `535 / 5.3.5`.
- `docs/release-version.md`: updated the documented current version and example to `535 / 5.3.5`.
- `docs/cloud-white-ui-20260708.md`: documented that the recent playback page now uses opaque cloud-white backgrounds and updated the APK version note.
- `progress.md`: appended this recent playback fix record.
- Rollback method: remove the three `android:background` attributes added to `app/src/mobile/res/layout/activity_history.xml`, set `app/build.gradle` and `docs/release-version.md` back to `534 / 5.3.4`, remove the recent playback bullet and version change from `docs/cloud-white-ui-20260708.md`, then rebuild with `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-08 - Task: Runtime smoke test cloud-white mobile pages and fix regressions
### What was done
- Ran a MuMu runtime smoke pass across the cloud-white mobile home, recent playback, search, favorites, settings, player settings, VOD detail/playback, and live playback pages.
- Fixed light-page system bar readability while keeping VOD/live playback pages on light icons over black video surfaces.
- Stabilized VOD grid title height so longer recent/playback titles do not spill outside cards.
- Fixed invisible settings source action icons by tinting the mobile settings home/history/refresh buttons with the cloud-white icon color.
- Fixed search and favorites pages so previous pages or wallpaper images no longer bleed through empty or chip states.
- Bumped the user-facing mobile APK version to `538 / 5.3.8` and updated the cloud-white UI documentation.

### Testing
- Passed: `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed with `BUILD SUCCESSFUL`.
- Passed: `aapt2 dump badging app\build\outputs\apk\mobileArm64_v8a\debug\mobile-arm64_v8a.apk` reported package `com.xingguang.video`, `versionCode='538'`, `versionName='5.3.8'`, and label `星光影视`.
- Passed: MuMu `127.0.0.1:16384` installed the APK successfully, and `dumpsys package com.xingguang.video` reported `versionCode=538` and `versionName=5.3.8`.
- Passed: `tmp/runtime-smoke-20260708/home-538.png` shows the home page with readable dark status bar icons and stable VOD grid cards.
- Passed: `tmp/runtime-smoke-20260708/search-538.png` shows search history and hot words on an opaque cloud-white background with no previous-page bleed-through.
- Passed: `tmp/runtime-smoke-20260708/keep-538.png` shows the empty favorites state on an opaque cloud-white background with no settings page bleed-through.
- Passed: `tmp/runtime-smoke-20260708/setting-538.png` shows visible settings source action icons on white cards.
- Passed: prior screenshots from this same runtime pass confirmed recent playback background, playback settings, VOD detail/player controls, and live playback opened without visible cloud-white regressions.
- Passed: the app process remained alive after testing, and app-PID-scoped `logcat` contained no `FATAL EXCEPTION`, `AndroidRuntime`, `Exception`, `Error`, or `CRASH` matches.
- Not run: destructive history/favorites deletion confirmation was not accepted during testing.

### Notes
- `app/src/mobile/java/com/fongmi/android/tv/ui/base/BaseActivity.java`: defaulted light pages to dark system bar icons through the edge-to-edge system bar style.
- `app/src/mobile/java/com/fongmi/android/tv/ui/activity/LiveActivity.java`: kept live playback on light system bar icons over the black video surface.
- `app/src/mobile/java/com/fongmi/android/tv/ui/activity/VideoActivity.java`: kept VOD playback on light system bar icons over the black video surface.
- `app/src/mobile/res/layout/adapter_vod.xml`: changed the VOD card title area to a stable two-line height with end ellipsis.
- `app/src/mobile/res/layout/fragment_setting.xml`: tinted the six mobile settings source action icons with `@color/xg_icon_default`.
- `app/src/mobile/res/layout/activity_search.xml`: added an opaque cloud-white Activity root background.
- `app/src/mobile/res/layout/fragment_search.xml`: added opaque cloud-white root and toolbar backgrounds.
- `app/src/mobile/res/layout/activity_keep.xml`: added opaque cloud-white root and toolbar backgrounds.
- `app/build.gradle`: bumped the mobile APK version fields to `538 / 5.3.8`.
- `docs/release-version.md`: updated the documented current version and example to `538 / 5.3.8`.
- `docs/cloud-white-ui-20260708.md`: documented the system bar, card title, settings icon, search, favorites, and final version behavior.
- `tmp/runtime-smoke-20260708/*`: retained MuMu screenshot/XML evidence for the runtime smoke pass.
- `progress.md`: appended this runtime smoke and regression-fix record.
- Rollback method: restore the listed Java, layout, and docs files to the state after the `535 / 5.3.5` recent playback fix, set `app/build.gradle` and `docs/release-version.md` back to `535 / 5.3.5`, remove this progress entry, then rebuild with `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-08 - Task: Compact recent playback card title height
### What was done
- Reduced the VOD grid card title area from a two-line block to a compact single-line marquee so recent playback cards are shorter.
- Kept long movie names readable through horizontal scrolling instead of increasing card height.
- Bumped the user-facing mobile APK version to `539 / 5.3.9` and updated the cloud-white UI documentation.

### Testing
- Corrected: the first build attempt failed because `android:selected` is not a valid linked layout attribute; the selected state is now applied from adapter code instead.
- Passed: `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed with `BUILD SUCCESSFUL`.
- Passed: `aapt2 dump badging app\build\outputs\apk\mobileArm64_v8a\debug\mobile-arm64_v8a.apk` reported package `com.xingguang.video`, `versionCode='539'`, `versionName='5.3.9'`, and label `星光影视`.
- Passed: MuMu `127.0.0.1:16384` installed the APK successfully, and `dumpsys package com.xingguang.video` reported `versionCode=539` and `versionName=5.3.9`.
- Passed: `tmp/runtime-smoke-20260708/history-539.png` shows the recent playback grid with shorter title rows and more content visible below the fold.
- Passed: `tmp/runtime-smoke-20260708/history-539.xml` shows VOD title nodes selected for marquee and constrained to the compact single-line title band.
- Passed: the app process remained alive after testing, and app-PID-scoped `logcat` contained no `FATAL EXCEPTION`, `AndroidRuntime`, `Exception`, `Error`, or `CRASH` matches.

### Notes
- `app/src/mobile/res/layout/adapter_vod.xml`: changed the VOD card title from a 36dp two-line end-ellipsis block to an 18dp single-line marquee block.
- `app/src/mobile/java/com/fongmi/android/tv/ui/adapter/KeepAdapter.java`: selected the shared card title text so favorite-card names can marquee with the same layout.
- `app/build.gradle`: bumped the mobile APK version fields to `539 / 5.3.9`.
- `docs/release-version.md`: updated the documented current version and example to `539 / 5.3.9`.
- `docs/cloud-white-ui-20260708.md`: documented the compact marquee card-title behavior and final version.
- `tmp/runtime-smoke-20260708/history-539.png` and `tmp/runtime-smoke-20260708/history-539.xml`: retained MuMu evidence for the recent playback card-height check.
- `progress.md`: appended this card-title compacting record.
- Rollback method: restore `app/src/mobile/res/layout/adapter_vod.xml` to the prior 36dp two-line title block, remove `holder.binding.name.setSelected(true);` from `KeepAdapter.java`, set `app/build.gradle` and `docs/release-version.md` back to `538 / 5.3.8`, remove the compact-marquee bullet/version change from `docs/cloud-white-ui-20260708.md`, remove this progress entry, then rebuild with `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-08 - Task: Unify light-page status bar color
### What was done
- Fixed the setting page top color mismatch caused by a transparent status bar showing the underlying window/wallpaper layer.
- Set light mobile pages to use a solid white status bar while keeping VOD and live playback pages on transparent/dark video status bars.
- Bumped the user-facing mobile APK version to `540 / 5.4.0` and updated the cloud-white UI documentation.

### Testing
- Passed: `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed with `BUILD SUCCESSFUL`.
- Passed: `aapt2 dump badging app\build\outputs\apk\mobileArm64_v8a\debug\mobile-arm64_v8a.apk` reported package `com.xingguang.video`, `versionCode='540'`, `versionName='5.4.0'`, and label `星光影视`.
- Passed: MuMu `127.0.0.1:16384` installed the APK successfully, and `dumpsys package com.xingguang.video` reported `versionCode=540` and `versionName=5.4.0`.
- Passed: `tmp/runtime-smoke-20260708/setting-540.png` shows the setting page status bar and title area using the same white surface color.
- Passed: the app process remained alive after testing, and app-PID-scoped `logcat` contained no `FATAL EXCEPTION`, `AndroidRuntime`, `Exception`, `Error`, or `CRASH` matches.

### Notes
- `app/src/mobile/java/com/fongmi/android/tv/ui/base/BaseActivity.java`: applied `xg_surface` as the status bar color for light system-bar pages after edge-to-edge setup.
- `app/build.gradle`: bumped the mobile APK version fields to `540 / 5.4.0`.
- `docs/release-version.md`: updated the documented current version and example to `540 / 5.4.0`.
- `docs/cloud-white-ui-20260708.md`: documented the solid white status bar behavior for light pages and updated the final version.
- `tmp/runtime-smoke-20260708/setting-540.png` and `tmp/runtime-smoke-20260708/setting-540.xml`: retained MuMu evidence for the setting page color check.
- `progress.md`: appended this status-bar color record.
- Rollback method: remove the `R` import and `getWindow().setStatusBarColor(ResUtil.getColor(R.color.xg_surface));` line from `BaseActivity.java`, set `app/build.gradle` and `docs/release-version.md` back to `539 / 5.3.9`, remove the solid-status-bar wording/version change from `docs/cloud-white-ui-20260708.md`, remove this progress entry, then rebuild with `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-08 - Task: Remove wallpaper setting and fix live back button
### What was done
- Removed the wallpaper configuration row from the mobile setting page.
- Removed the setting-page wallpaper click, long-click, refresh, default-cycle, history, and file-load handlers while keeping internal wallpaper loading available for the home background/restore path.
- Bound the live playback fullscreen top-left back button to exit the live page.
- Bumped the user-facing mobile APK version to `541 / 5.4.1` and updated the cloud-white UI documentation.

### Testing
- Passed: static search found no remaining `wallUrl`, `wallDefault`, `wallRefresh`, `@+id/wall`, `mBinding.wall`, or setting-page type-2 wallpaper entry references in `SettingFragment.java` and `fragment_setting.xml`.
- Passed: `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed with `BUILD SUCCESSFUL`.
- Passed: `aapt2 dump badging app\build\outputs\apk\mobileArm64_v8a\debug\mobile-arm64_v8a.apk` reported package `com.xingguang.video`, `versionCode='541'`, `versionName='5.4.1'`, and label `星光影视`.
- Passed: MuMu `127.0.0.1:16384` installed the APK successfully, and `dumpsys package com.xingguang.video` reported `versionCode=541` and `versionName=5.4.1`.
- Passed: `tmp/runtime-smoke-20260708/setting-541.xml` reported no `wall`, `wallUrl`, `wallDefault`, `wallRefresh`, `壁纸`, `Wallpaper`, or `setting_wall` matches; `tmp/runtime-smoke-20260708/setting-541.png` was retained as the setting-page screenshot.
- Passed: `tmp/runtime-smoke-20260708/live-541-before-back.xml` showed `com.xingguang.video:id/liveBack` clickable with bounds `[36,36][156,156]`.
- Passed: tapping `96 96` on the live page changed focus from `LiveActivity` back to `HomeActivity`, and `tmp/runtime-smoke-20260708/live-541-after-back.xml` no longer contained `liveBack`.
- Passed: the app process remained alive after testing, and app-PID-scoped `logcat` contained no `FATAL EXCEPTION`, `AndroidRuntime`, `CRASH`, or process-death matches.
- Noted: live source/image requests logged remote connection-refused warnings for `live.fanmingming.cn`; this did not crash the app and did not block the back-button verification.

### Notes
- `app/src/mobile/res/layout/fragment_setting.xml`: removed the visible wallpaper configuration row and its default/refresh action icons from the setting page.
- `app/src/mobile/java/com/fongmi/android/tv/ui/fragment/SettingFragment.java`: removed the setting-page wallpaper event handlers and stale binding updates tied to the removed row.
- `app/src/mobile/java/com/fongmi/android/tv/ui/activity/LiveActivity.java`: bound the fullscreen `liveBack` image button to the existing live exit action.
- `app/build.gradle`: bumped the mobile APK version fields to `541 / 5.4.1`.
- `docs/release-version.md`: updated the documented current APK version and example to `541 / 5.4.1`.
- `docs/cloud-white-ui-20260708.md`: documented that settings no longer exposes wallpaper controls and updated the final version.
- `tmp/runtime-smoke-20260708/current-541.xml`: retained the startup UI hierarchy used to identify bottom navigation bounds.
- `tmp/runtime-smoke-20260708/current-541.png`: retained the startup screenshot for this smoke pass.
- `tmp/runtime-smoke-20260708/setting-541.xml`: retained the setting-page hierarchy proving the wallpaper entry is absent.
- `tmp/runtime-smoke-20260708/setting-541.png`: retained the setting-page screenshot for visual evidence.
- `tmp/runtime-smoke-20260708/live-541-before-back.xml`: retained the live-page hierarchy proving `liveBack` is clickable before tapping.
- `tmp/runtime-smoke-20260708/live-541-before-back.png`: retained the live-page screenshot before tapping the fullscreen back button.
- `tmp/runtime-smoke-20260708/live-541-after-back.xml`: retained the hierarchy after tapping, proving the app returned to `HomeActivity`.
- `tmp/runtime-smoke-20260708/live-541-after-back.png`: retained the screenshot after returning from live playback.
- `progress.md`: appended this implementation and verification record.
- Rollback method: restore the removed wallpaper row and its `SettingFragment` handlers, remove `mBinding.liveBack.setOnClickListener(view -> onBack());`, set `app/build.gradle` and `docs/release-version.md` back to `540 / 5.4.0`, remove the wallpaper-control/version wording from `docs/cloud-white-ui-20260708.md`, delete the `tmp/runtime-smoke-20260708/*-541.*` evidence files, remove this progress entry, then rebuild with `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-08 - Task: Restore Home system bars after live exit
### What was done
- Fixed the issue where exiting live playback could leave the Home page in fullscreen/immersive mode.
- Kept live playback itself fullscreen while making Home explicitly show system bars when it resumes or regains window focus.
- Bumped the user-facing mobile APK version to `542 / 5.4.2` and updated the cloud-white UI documentation.

### Testing
- Passed: static inspection confirmed `HomeActivity` now calls `Util.showSystemUI(this)` from `onResume()` and `onWindowFocusChanged(true)`.
- Passed: `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed with `BUILD SUCCESSFUL`.
- Passed: `aapt2 dump badging app\build\outputs\apk\mobileArm64_v8a\debug\mobile-arm64_v8a.apk` reported package `com.xingguang.video`, `versionCode='542'`, `versionName='5.4.2'`, and label `星光影视`.
- Passed: MuMu `127.0.0.1:16384` installed the APK successfully, and `dumpsys package com.xingguang.video` reported `versionCode=542` and `versionName=5.4.2`.
- Passed: before entering live, `tmp/runtime-smoke-20260708/home-542-before-live.xml` showed `HomeActivity` focused and `statusBarBackground=True`.
- Passed: in live playback, `tmp/runtime-smoke-20260708/live-542-before-back.xml` showed `LiveActivity` focused, `liveBack` present, and `statusBarBackground=False`, confirming live remained fullscreen.
- Passed: after tapping the live back button at `96 96`, focus returned to `HomeActivity`; `tmp/runtime-smoke-20260708/home-542-after-live-back.xml` showed `statusBarBackground=True` and no `liveBack`, confirming Home exited fullscreen mode.
- Passed: the app process remained alive after testing, and app-PID-scoped `logcat` contained no `FATAL EXCEPTION`, `AndroidRuntime`, `CRASH`, process-death, recent `Exception`, or recent `Error` matches.

### Notes
- `app/src/mobile/java/com/fongmi/android/tv/ui/activity/HomeActivity.java`: restores system bars when Home resumes or regains focus after fullscreen playback pages.
- `app/build.gradle`: bumped the mobile APK version fields to `542 / 5.4.2`.
- `docs/release-version.md`: updated the documented current APK version and example to `542 / 5.4.2`.
- `docs/cloud-white-ui-20260708.md`: documented that returning from live playback restores normal Home system bars.
- `tmp/runtime-smoke-20260708/home-542-before-live.xml`: retained the Home hierarchy before entering live.
- `tmp/runtime-smoke-20260708/home-542-before-live.png`: retained the Home screenshot before entering live.
- `tmp/runtime-smoke-20260708/live-542-before-back.xml`: retained the live hierarchy proving live remains fullscreen.
- `tmp/runtime-smoke-20260708/live-542-before-back.png`: retained the live fullscreen screenshot before tapping back.
- `tmp/runtime-smoke-20260708/home-542-after-live-back.xml`: retained the Home hierarchy proving system bars are restored after live exit.
- `tmp/runtime-smoke-20260708/home-542-after-live-back.png`: retained the Home screenshot after live exit.
- `progress.md`: appended this implementation and verification record.
- Rollback method: remove the `Util` import plus `onResume()` and `onWindowFocusChanged()` system-bar restore calls from `HomeActivity.java`, set `app/build.gradle` and `docs/release-version.md` back to `541 / 5.4.1`, remove the live-exit system-bar wording/version change from `docs/cloud-white-ui-20260708.md`, delete the `tmp/runtime-smoke-20260708/*-542-*` evidence files, remove this progress entry, then rebuild with `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-08 - Task: Restore portrait Home after live exit
### What was done
- Fixed the remaining live-exit state where Home could return with system bars visible but still stay in landscape layout.
- Locked the mobile Home activity to user portrait while leaving live playback on its existing sensor-landscape fullscreen behavior.
- Bumped the user-facing mobile APK version to `543 / 5.4.3` and updated the cloud-white UI documentation.

### Testing
- Passed: static inspection confirmed `HomeActivity` uses `android:screenOrientation="userPortrait"` while `LiveActivity` remains `android:screenOrientation="sensorLandscape"`.
- Passed: `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed with `BUILD SUCCESSFUL`.
- Passed: `aapt2 dump badging app\build\outputs\apk\mobileArm64_v8a\debug\mobile-arm64_v8a.apk` reported package `com.xingguang.video`, `versionCode='543'`, `versionName='5.4.3'`, and label `星光影视`.
- Passed: MuMu `127.0.0.1:16384` installed the APK successfully, and `dumpsys package com.xingguang.video` reported `versionCode=543` and `versionName=5.4.3`.
- Passed: before entering live, `tmp/runtime-smoke-20260708/home-543-before-live.xml` showed `HomeActivity` focused, `rotation=0`, size `1080x1920`, and `statusBarBackground=True`.
- Passed: in live playback, `tmp/runtime-smoke-20260708/live-543-before-back.xml` showed `LiveActivity` focused, `rotation=1`, size `1920x1080`, `liveBack` present, and `statusBarBackground=False`.
- Passed: after tapping the live back button at `96 96`, focus returned to `HomeActivity`; `tmp/runtime-smoke-20260708/home-543-after-live-back.xml` showed `rotation=0`, size `1080x1920`, `statusBarBackground=True`, and no `liveBack`.
- Passed: the app process remained alive after testing, and app-PID-scoped `logcat` contained no `FATAL EXCEPTION`, `AndroidRuntime`, `CRASH`, process-death, recent `Exception`, or recent `Error` matches.

### Notes
- `app/src/mobile/AndroidManifest.xml`: changed only the mobile Home activity orientation from `fullUser` to `userPortrait`.
- `app/build.gradle`: bumped the mobile APK version fields to `543 / 5.4.3`.
- `docs/release-version.md`: updated the documented current APK version and example to `543 / 5.4.3`.
- `docs/cloud-white-ui-20260708.md`: documented that returning from live restores the portrait Home page and system bars.
- `tmp/runtime-smoke-20260708/home-543-before-live.xml`: retained the portrait Home hierarchy before entering live.
- `tmp/runtime-smoke-20260708/home-543-before-live.png`: retained the portrait Home screenshot before entering live.
- `tmp/runtime-smoke-20260708/live-543-before-back.xml`: retained the live landscape fullscreen hierarchy before tapping back.
- `tmp/runtime-smoke-20260708/live-543-before-back.png`: retained the live landscape fullscreen screenshot before tapping back.
- `tmp/runtime-smoke-20260708/home-543-after-live-back.xml`: retained the Home hierarchy proving portrait/system-bar restoration after live exit.
- `tmp/runtime-smoke-20260708/home-543-after-live-back.png`: retained the Home screenshot after live exit.
- `progress.md`: appended this implementation and verification record.
- Rollback method: change `HomeActivity` in `app/src/mobile/AndroidManifest.xml` back to `android:screenOrientation="fullUser"`, set `app/build.gradle` and `docs/release-version.md` back to `542 / 5.4.2`, remove the portrait/landscape wording and version change from `docs/cloud-white-ui-20260708.md`, delete the `tmp/runtime-smoke-20260708/*-543-*` evidence files, remove this progress entry, then rebuild with `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-09 - Task: Refresh launcher icon and startup animation
### What was done
- Replaced the app launcher PNG resources with a cloud-white blue/green playback mark.
- Added a mobile startup animated vector using the same playback mark and sparkle motif.
- Updated the mobile splash theme to use the animated vector on the cloud-white surface.
- Backed up the previous launcher PNG resources before overwriting them.
- Bumped the user-facing mobile APK version to `544 / 5.4.4` and documented the launcher/splash refresh.

### Testing
- Passed: visual preview of `tmp/launcher_splash_20260709/ic_launcher_playstore_preview.png` showed the new cloud-white playback mark.
- Passed: `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed with `BUILD SUCCESSFUL`.
- Passed: `aapt2 dump badging app\build\outputs\apk\mobileArm64_v8a\debug\mobile-arm64_v8a.apk` reported package `com.xingguang.video`, `versionCode='544'`, `versionName='5.4.4'`, label `星光影视`, and launcher icon resources from `res/mipmap-mdpi-v4/ic_launcher.png` through `res/mipmap-xxxhdpi-v4/ic_launcher.png`.
- Passed: APK resource dump showed `Theme.Splash` using `@drawable/avd_splash_mark`, `windowSplashScreenAnimationDuration=650`, and `@color/xg_surface` as the splash background.
- Passed: extracted packaged launcher icons in `tmp/launcher_splash_20260709/apk-icons/` matched the generated resource sizes.
- Passed: MuMu `127.0.0.1:16384` installed the APK successfully, and `dumpsys package com.xingguang.video` reported `versionCode=544` and `versionName=5.4.4`.
- Passed: launch reached `com.fongmi.android.tv.ui.activity.HomeActivity`, and `tmp/launcher_splash_20260709/home-544.xml` showed the app home hierarchy loaded with the `logo` view present.
- Passed: a 5-second startup recording was captured at `tmp/launcher_splash_20260709/splash-544.mp4`.
- Passed: app-PID-scoped `logcat` contained no `FATAL EXCEPTION`, `AndroidRuntime`, `CRASH`, `Resources$NotFoundException`, or `InflateException` matches.
- Noted: the home header logo may still show the current VOD config logo because `ImgUtil.logo()` loads the configured remote logo before falling back to the launcher icon.

### Notes
- `app/src/main/ic_launcher-playstore.png`: regenerated the 512x512 launcher image.
- `app/src/main/res/mipmap-mdpi/ic_launcher.png` and `app/src/main/res/mipmap-mdpi/ic_launcher_round.png`: regenerated the 48x48 launcher assets.
- `app/src/main/res/mipmap-hdpi/ic_launcher.png` and `app/src/main/res/mipmap-hdpi/ic_launcher_round.png`: regenerated the 72x72 launcher assets.
- `app/src/main/res/mipmap-xhdpi/ic_launcher.png` and `app/src/main/res/mipmap-xhdpi/ic_launcher_round.png`: regenerated the 96x96 launcher assets.
- `app/src/main/res/mipmap-xxhdpi/ic_launcher.png` and `app/src/main/res/mipmap-xxhdpi/ic_launcher_round.png`: regenerated the 144x144 launcher assets.
- `app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` and `app/src/main/res/mipmap-xxxhdpi/ic_launcher_round.png`: regenerated the 192x192 launcher assets.
- `app/src/main/res/drawable/ic_splash_mark.xml`: added the static vector mark used by the startup animation.
- `app/src/main/res/drawable/avd_splash_mark.xml`: added the animated-vector wrapper for the startup mark.
- `app/src/main/res/animator/splash_mark_scale.xml`: added the startup mark scale animation.
- `app/src/main/res/animator/splash_spark_pulse.xml`: added the sparkle pulse animation.
- `app/src/mobile/res/values/styles.xml`: changed the mobile splash theme to the new animated vector, white background, and 650ms animation duration.
- `app/build.gradle`: bumped the mobile APK version fields to `544 / 5.4.4`.
- `docs/release-version.md`: updated the documented current APK version and example to `544 / 5.4.4`.
- `docs/cloud-white-ui-20260708.md`: documented the launcher/startup visual refresh.
- `docs/launcher-splash-20260709.md`: documented the new launcher and splash resources, verification, backup, and rollback path.
- `archive/launcher-splash-backup-20260709-v543/`: retained the previous launcher PNG resources before replacement.
- `tmp/launcher_splash_20260709/*`: retained preview, APK-extracted icon, startup recording, home hierarchy, and screenshot evidence.
- `progress.md`: appended this implementation and verification record.
- Rollback method: copy launcher PNGs from `archive/launcher-splash-backup-20260709-v543/` back to the same relative paths, delete `ic_splash_mark.xml`, `avd_splash_mark.xml`, `splash_mark_scale.xml`, and `splash_spark_pulse.xml`, restore the mobile splash theme to `@mipmap/ic_launcher`, set `app/build.gradle` and `docs/release-version.md` back to `543 / 5.4.3`, remove the launcher/startup wording and version change from `docs/cloud-white-ui-20260708.md`, remove `docs/launcher-splash-20260709.md`, delete the `tmp/launcher_splash_20260709/` evidence directory, remove this progress entry, then rebuild with `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-09 - Task: Align splash icon with launcher icon
### What was done
- Fixed the mismatch where the startup splash used a separately drawn large rectangular mark while the launcher used the generated rounded icon.
- Changed the mobile splash icon to use the exact same `@mipmap/ic_launcher` resource as the app launcher icon.
- Removed the separate splash-only animated vector resources so there is no second icon shape to drift from the launcher.
- Bumped the user-facing mobile APK version to `545 / 5.4.5` and updated launcher/splash documentation.

### Testing
- Passed: static search found no active source references to `avd_splash_mark`, `ic_splash_mark`, `splash_mark_scale`, `splash_spark_pulse`, or `windowSplashScreenAnimationDuration`.
- Passed: `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed with `BUILD SUCCESSFUL`.
- Passed: `aapt2 dump badging app\build\outputs\apk\mobileArm64_v8a\debug\mobile-arm64_v8a.apk` reported package `com.xingguang.video`, `versionCode='545'`, `versionName='5.4.5'`, label `星光影视`, and launcher icon resources from `res/mipmap-mdpi-v4/ic_launcher.png` through `res/mipmap-xxxhdpi-v4/ic_launcher.png`.
- Passed: APK resource dump showed `Theme.Splash` using `windowSplashScreenAnimatedIcon=@mipmap/ic_launcher` and `windowSplashScreenBackground=@color/xg_surface`; no `@drawable/avd_splash_mark` resource was present.
- Passed: MuMu `127.0.0.1:16384` installed the APK successfully, and `dumpsys package com.xingguang.video` reported `versionCode=545` and `versionName=5.4.5`.
- Passed: launch recording was captured at `tmp/launcher_splash_20260709/splash-545.mp4`, and the app reached `HomeActivity`.
- Passed: `tmp/launcher_splash_20260709/home-545.xml` showed the home hierarchy loaded, the `logo` view present, and `statusBarBackground` present.
- Passed: packaged launcher PNGs were extracted to `tmp/launcher_splash_20260709/apk-icons-545/`.
- Passed: app-PID-scoped `logcat` contained no `FATAL EXCEPTION`, `AndroidRuntime`, `CRASH`, process-death, `Resources$NotFoundException`, or `InflateException` matches.

### Notes
- `app/src/mobile/res/values/styles.xml`: changed the splash icon from `@drawable/avd_splash_mark` to `@mipmap/ic_launcher` and removed the custom animation duration.
- `app/src/main/res/drawable/ic_splash_mark.xml`: removed the splash-only static vector mark.
- `app/src/main/res/drawable/avd_splash_mark.xml`: removed the splash-only animated vector wrapper.
- `app/src/main/res/animator/splash_mark_scale.xml`: removed the unused splash scale animator.
- `app/src/main/res/animator/splash_spark_pulse.xml`: removed the unused sparkle animator.
- `app/build.gradle`: bumped the mobile APK version fields to `545 / 5.4.5`.
- `docs/release-version.md`: updated the documented current APK version and example to `545 / 5.4.5`.
- `docs/cloud-white-ui-20260708.md`: documented that launcher and startup use the same playback icon.
- `docs/launcher-splash-20260709.md`: updated the launcher/splash verification to the unified `@mipmap/ic_launcher` splash resource.
- `tmp/launcher_splash_20260709/splash-545.mp4`: retained the startup recording for this corrected splash pass.
- `tmp/launcher_splash_20260709/home-545.xml` and `home-545.png`: retained the post-launch Home evidence.
- `tmp/launcher_splash_20260709/apk-icons-545/`: retained APK-extracted launcher icon resources for this version.
- `progress.md`: appended this correction and verification record.
- Rollback method: restore `app/src/mobile/res/values/styles.xml` to `@drawable/avd_splash_mark` only if the separate splash icon is intentionally restored, recreate the deleted splash vector/animator files from the previous record if needed, set `app/build.gradle` and `docs/release-version.md` back to `544 / 5.4.4`, revert the 5.4.5 wording in `docs/cloud-white-ui-20260708.md` and `docs/launcher-splash-20260709.md`, remove this progress entry, then rebuild with `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-10 - Task: Roll back mobile APK to 545 / 5.4.5
### What was done
- Reverted the unfinished 5.4.6 Home header source-switch click-area change.
- Restored the user-facing mobile APK version and release documentation to `545 / 5.4.5`.

### Testing
- Passed: static checks confirmed the Home page only retains the original title click source-switch binding and no longer contains the added `source` container binding.
- Passed: source and documentation checks confirmed `app/build.gradle`, `docs/release-version.md`, and `docs/cloud-white-ui-20260708.md` report `545 / 5.4.5`.
- Passed: `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed with `BUILD SUCCESSFUL`.
- Passed: `aapt2 dump badging app\build\outputs\apk\mobileArm64_v8a\debug\mobile-arm64_v8a.apk` reported package `com.xingguang.video`, `versionCode='545'`, and `versionName='5.4.5'`.
- Not run: MuMu installation verification because ADB reported `no devices/emulators found`.

### Notes
- `app/build.gradle`: restored the mobile APK version fields to `545 / 5.4.5`.
- `app/src/mobile/res/layout/fragment_vod.xml`: removed the unfinished clickable `source` container attributes.
- `app/src/mobile/java/com/fongmi/android/tv/ui/fragment/VodFragment.java`: removed the unfinished source-container click listener and retained the original title click listener.
- `docs/release-version.md`: restored the documented current APK version and example to `545 / 5.4.5`.
- `docs/cloud-white-ui-20260708.md`: removed the unfinished Home title/subtitle source-switch note and restored the version statement to `545 / 5.4.5`.
- `progress.md`: appended this rollback and verification record.
- Rollback method: to restore the unfinished 5.4.6 state, set `app/build.gradle` and `docs/release-version.md` to `546 / 5.4.6`, restore the `source` container id/click attributes and `mBinding.source` click listener, restore the Home title/subtitle source-switch note and version in `docs/cloud-white-ui-20260708.md`, remove this progress entry, then rebuild with `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-10 - Task: Improve playback settings text contrast
### What was done
- Changed playback settings section labels from white to the cloud-white primary text color.
- Changed playback settings action text to the existing state-aware control color so normal actions are dark and activated actions use the primary blue.
- Bumped the user-facing mobile APK version to `546 / 5.4.6` and documented the contrast correction.

### Testing
- Passed: static inspection confirmed `dialog_control.xml` contains no remaining `@color/white` text references.
- Passed: `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed with `BUILD SUCCESSFUL`.
- Passed: `aapt2 dump badging app\build\outputs\apk\mobileArm64_v8a\debug\mobile-arm64_v8a.apk` reported package `com.xingguang.video`, `versionCode='546'`, and `versionName='5.4.6'`.
- Passed: MuMu `127.0.0.1:16384` installed the APK successfully, and device package state reported `versionCode=546` and `versionName=5.4.6`.
- Passed: runtime playback opened the settings bottom sheet; `tmp/control-dialog-546-final.png` visually confirmed dark section labels, dark normal button text, and a blue activated `原始` option on the light sheet.
- Passed: `tmp/control-dialog-546-final.xml` confirmed the playback settings controls and labels were present and clickable.
- Passed: app-PID-scoped `logcat` contained no `FATAL EXCEPTION`, `AndroidRuntime`, `InflateException`, `Resources$NotFoundException`, or `CRASH` matches.

### Notes
- `app/src/mobile/res/layout/dialog_control.xml`: changed playback settings labels and action text to cloud-white readable colors.
- `app/build.gradle`: bumped the mobile APK version fields to `546 / 5.4.6`.
- `docs/release-version.md`: updated the documented current APK version and example to `546 / 5.4.6`.
- `docs/cloud-white-ui-20260708.md`: documented the playback settings contrast correction and version.
- `tmp/control-dialog-546-final.png`: retained the final runtime playback settings screenshot.
- `tmp/control-dialog-546-final.xml`: retained the final runtime hierarchy for the playback settings sheet.
- `progress.md`: appended this implementation and verification record.
- Rollback method: change playback settings text colors in `app/src/mobile/res/layout/dialog_control.xml` back to `@color/white`, set `app/build.gradle` and `docs/release-version.md` back to `545 / 5.4.5`, remove the playback settings contrast note and restore the version in `docs/cloud-white-ui-20260708.md`, delete `tmp/control-dialog-546-final.png` and `tmp/control-dialog-546-final.xml`, remove this progress entry, then rebuild with `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-10 - Task: Disable upstream mobile update prompts
### What was done
- Removed the mobile startup update check that queried the upstream FongMi release channel.
- Removed the Settings version-row update action while retaining the installed version display as read-only information.
- Removed the now-unused mobile updater implementation and retained a rollback backup outside the compiled source tree.
- Bumped the user-facing mobile APK version to `547 / 5.4.7` and documented the mobile update policy.

### Testing
- Passed: static search found no `Updater`, `FongMi/Release`, `mobile.json`, or upstream APK references under `app/src/mobile`.
- Passed: `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed with `BUILD SUCCESSFUL`.
- Passed: `aapt2 dump badging app\build\outputs\apk\mobileArm64_v8a\debug\mobile-arm64_v8a.apk` reported package `com.xingguang.video`, `versionCode='547'`, and `versionName='5.4.7'`.
- Passed: MuMu `127.0.0.1:16384` installed the APK successfully, and device package state reported `versionCode=547` and `versionName=5.4.7`.
- Passed: a cold launch followed by a 6-second wait produced no `5.5.6`, new-version, or update-check dialog matches in `tmp/home-547-no-update.xml`.
- Passed: `tmp/setting-547.xml` showed the Settings version row displaying `5.4.7` with `clickable=false`.
- Passed: tapping the version row produced no update dialog and left the Settings page present in `tmp/setting-547-after-version-tap.xml`.
- Passed: app-PID-scoped `logcat` contained no `FATAL EXCEPTION`, `AndroidRuntime`, process-death, `InflateException`, or `Resources$NotFoundException` matches.

### Notes
- `app/src/mobile/java/com/fongmi/android/tv/ui/activity/HomeActivity.java`: removed the mobile startup update check and unused updater import.
- `app/src/mobile/java/com/fongmi/android/tv/ui/fragment/SettingFragment.java`: changed the version row to display-only by removing its update listener, handler, and unused updater import.
- `app/src/mobile/java/com/fongmi/android/tv/Updater.java`: removed the unused mobile upstream updater implementation.
- `archive/mobile-updater-backup-20260710-v546/Updater.java`: retained the removed 5.4.6 mobile updater solely as a rollback point.
- `app/build.gradle`: bumped the mobile APK version fields to `547 / 5.4.7`.
- `docs/release-version.md`: updated the documented current APK version and example to `547 / 5.4.7`.
- `docs/cloud-white-ui-20260708.md`: documented that the mobile app no longer uses the upstream FongMi update channel.
- `tmp/home-547-no-update.xml`: retained the post-cold-launch hierarchy proving no update dialog appeared.
- `tmp/setting-547.xml` and `tmp/setting-547.png`: retained the Settings version display and non-clickable runtime evidence.
- `tmp/setting-547-after-version-tap.xml`: retained the hierarchy after tapping the read-only version row.
- `progress.md`: appended this implementation and verification record.
- Rollback method: copy `archive/mobile-updater-backup-20260710-v546/Updater.java` back to `app/src/mobile/java/com/fongmi/android/tv/Updater.java`, restore the `Updater` import and `Updater.create().start(this)` call in `HomeActivity`, restore the `Updater` import, version click listener, and `onVersion` method in `SettingFragment`, set `app/build.gradle` and `docs/release-version.md` back to `546 / 5.4.6`, remove the mobile update-policy note and restore the version in `docs/cloud-white-ui-20260708.md`, delete the 5.4.7 runtime evidence and updater backup, remove this progress entry, then rebuild with `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-10 - Task: Remove redundant test packages and capture artifacts
### What was done
- Removed generated test APK outputs, temporary screenshots and screen recordings, Gradle workspace cache, and module build outputs without changing source files or signing configuration.
- Preserved formal documentation images, source assets, archived rollback material, the Android SDK, local tools, and the signing keystore.

### Testing
- Passed: resolved every recursive deletion target under `D:\xingkong` before removal; the pre-delete total was about `485.6 MB`.
- Passed: confirmed `tmp`, `chaquo/build`, `quickjs/build`, `catvod/build`, the root `build`, and `.gradle` no longer exist.
- Passed: confirmed no `.apk`, `.aab`, `.apks`, `.mp4`, `.mkv`, `.avi`, `.mov`, or `.webm` files remain in the project outside the preserved SDK and tools directories.
- Passed: confirmed `app/build` contains zero files and zero bytes; MuMu currently holds its empty APK output directory open, so the final empty directory hierarchy could not be removed while the emulator is running.
- Passed: confirmed the active source directories, `docs`, `local.properties`, `apkwork/keystore`, and `apkwork/keystore/xingguang-release.p12` still exist.

### Notes
- `tmp`: deleted temporary runtime screenshots, XML evidence, screen recordings, icon extracts, and other test artifacts.
- `app/build`: deleted all generated app build files, including the debug test APK; only an empty MuMu-locked output directory remains.
- `chaquo/build`: deleted generated Chaquo build outputs.
- `quickjs/build`: deleted generated QuickJS build outputs.
- `catvod/build`: deleted generated CatVod build outputs.
- `build`: deleted generated root build output.
- `.gradle`: deleted the project-local Gradle cache.
- `progress.md`: appended this cleanup record.
- Rollback method: regenerate build and cache directories with `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`; recreate screenshots, recordings, and runtime evidence by rerunning the relevant MuMu verification workflow. Close MuMu and remove the remaining empty `app/build` directory if a completely absent build directory is required.

## 2026-07-14 - Task: Split ad controls and add HLS playlist filtering
### What was done
- Replaced the mobile `智能去广` row with independent `广告过滤` and `广告URL拦截` controls while using the old preference as the compatibility default for existing installs.
- Connected `广告URL拦截` to the hidden parsing WebView ad-rule path, so disabling it now allows matched WebView requests instead of always blocking them.
- Added a local HLS playlist service that proxies master and media playlists, resolves relative child/segment/KEY/MAP URLs, removes minority-source ad segments under the 85%/50% safety limits, and redirects to the original URL when filtering cannot be completed.
- Kept the original media URL for history and sharing while using the local filtered URL only for playback; non-HTTP(S), non-HLS, MP4, and local-file inputs remain outside the filter path.
- Pinned `beautifulsoup4` to `4.13.4` after unpinned `4.15.0` caused Chaquopy 13.1 to fail with a duplicate `_html5lib.py` packaging error.
- Bumped the mobile APK version to `548 / 5.4.8` and documented the behavior and MPV deep-filter limitation.

### Testing
- Passed: `.\gradlew.bat :chaquo:clean --no-daemon` followed by `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed with `BUILD SUCCESSFUL` without excluding any task.
- Passed: `aapt2 dump badging` reported package `com.xingguang.video`, `versionCode='548'`, and `versionName='5.4.8'`; final APK SHA-256 is `65B63EA2442C84A46365115024814E7D142BE61A63CC64857DDF8C3AEF409A5E`.
- Passed: MuMu `127.0.0.1:16384` installed the final APK successfully, and `dumpsys package` reported `versionCode=548` and `versionName=5.4.8`.
- Passed: `tmp/ad-filter-controls-548.png` and `tmp/ad-filter-controls-548.xml` show separate visible, clickable `广告过滤` and `广告URL拦截` rows with both final states set to `开`.
- Passed: toggling produced `广告过滤=关 / 广告URL拦截=开`, then `广告过滤=开 / 广告URL拦截=关`; after force-stop and relaunch the independent values persisted, and final preferences were restored to `video_purify=true` and `ad_host_block=true`.
- Passed: the controlled master/media playlist routed playback through `http://127.0.0.1:9978/adm3u8/...`; runtime logs reported `Filtered 2 of 20 HLS segments`.
- Passed: the filtered media response contained zero `/ads/` references, 18 `/main/` references, 18 absolute segment URLs, and one continuity marker; the master playlist child URL was rewritten back through the local HLS service.
- Passed: with `广告过滤` disabled, runtime logs showed the original `http://127.0.0.1:18080/master.m3u8` as `playUrl` and no HLS filtering entry; the switch was then restored to enabled.
- Passed: static inspection confirmed `Setting.isAdHostBlock()` gates the existing `VodConfig`/`LiveConfig` ad-rule check in `CustomWebView`.
- Passed: app-PID-scoped runtime checks found no `FATAL EXCEPTION`, `AndroidRuntime: FATAL`, process-death, `InflateException`, or `Resources$NotFoundException` matches.
- Test boundary: the synthetic playlist validates routing, rewriting, filtering, fallback selection, and switch behavior; effectiveness on a real ad-inserted source still depends on that source's playlist structure and configured ad rules.

### Notes
- `app/src/main/java/com/fongmi/android/tv/Setting.java`: added independent `video_purify` and `ad_host_block` preferences plus the old combined API compatibility bridge for Leanback.
- `app/src/main/java/com/fongmi/android/tv/ui/custom/CustomWebView.java`: gated WebView ad-rule interception with the new URL-block switch.
- `app/src/main/java/com/fongmi/android/tv/server/process/Hls.java`: added bounded local HLS loading, URL rewriting, minority-source filtering, and original-URL fallback.
- `app/src/main/java/com/fongmi/android/tv/server/Nano.java`: registered the HLS playlist process.
- `app/src/main/java/com/fongmi/android/tv/player/Players.java`: separated original and playback URLs and routed eligible HLS playback through the local service.
- `app/src/mobile/java/com/fongmi/android/tv/ui/fragment/SettingPlayerFragment.java`: initialized and handled the two independent controls.
- `app/src/mobile/res/layout/fragment_setting_player.xml`: replaced the combined row with two setting rows.
- `app/src/main/res/values/strings.xml`, `app/src/main/res/values-zh-rCN/strings.xml`, and `app/src/main/res/values-zh-rTW/strings.xml`: added English, Simplified Chinese, and Traditional Chinese control labels while retaining the Leanback compatibility label.
- `chaquo/requirements.txt`: pinned `beautifulsoup4==4.13.4` for reproducible Chaquopy packaging.
- `app/build.gradle`: bumped the APK version to `548 / 5.4.8`.
- `docs/ad-filtering-20260714.md`: documented control scope, HLS heuristics, fallback behavior, limitation, and build pin.
- `docs/release-version.md` and `docs/cloud-white-ui-20260708.md`: updated the current version and UI behavior.
- `tmp/hls-filter-test/master.m3u8` and `tmp/hls-filter-test/media.m3u8`: retained the controlled HLS verification fixtures.
- `tmp/ad-filter-controls-548.png` and `tmp/ad-filter-controls-548.xml`: retained final device UI evidence.
- `progress.md`: appended this implementation, verification, limitation, and rollback record.
- Rollback method: remove `Hls.java` and its `Nano` registration; restore `Players.java` to use the original `url` directly; restore the single `adblock` preference, mobile row, handler, and labels; restore unconditional `CustomWebView.isAd(host)` interception; change `chaquo/requirements.txt` back to unpinned `beautifulsoup4`; set version/docs back to `547 / 5.4.7`; delete `docs/ad-filtering-20260714.md` and the `tmp` evidence/fixtures; remove this progress entry; then rebuild with `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-14 - Task: Improve VOD poster status-label readability
### What was done
- Replaced the translucent green poster-status background with the existing high-opacity dark overlay so episode/update text remains readable over variable poster artwork.
- Changed poster-status text to white and bounded long values to the card width with end ellipsis, preventing labels from extending outside the poster or competing with the title below.
- Applied the same status treatment to portrait cards, landscape cards, and the mobile video detail header.
- Bumped the mobile APK version to `549 / 5.4.9` and documented the card-label readability behavior.

### Testing
- Passed: `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed with `BUILD SUCCESSFUL`.
- Passed: `aapt2 dump badging` reported package `com.xingguang.video`, `versionCode='549'`, and `versionName='5.4.9'`; final APK SHA-256 is `52D519DEAEB8A0CDEF785FAF3BFB2CF363EF27EF18340CFCF4146D6E2326C2F9`.
- Passed: MuMu `127.0.0.1:16384` installed the APK successfully, and device package state reported `versionCode=549` and `versionName=5.4.9`.
- Passed: `tmp/vod-remark-549.png` visually confirmed white status text on an opaque dark background across bright, dark, and detailed posters; labels stayed inside the poster width and titles remained in the unchanged row below.
- Passed: runtime hierarchy bounds showed visible labels such as `限免06集`, `(16/40)`, and `(15/36)` remained narrower than their 248 px poster bounds.
- Passed: app-PID-scoped logcat contained no `FATAL EXCEPTION`, `AndroidRuntime: FATAL`, `InflateException`, `Resources$NotFoundException`, or app process-death matches.

### Notes
- `app/src/mobile/res/drawable/shape_vod_remark.xml`: changed the status-label fill to the existing strong dark overlay token.
- `app/src/mobile/res/layout/adapter_vod.xml`: changed portrait-card status text to white and added a 100 dp width limit with end ellipsis.
- `app/src/mobile/res/layout/adapter_vod_rect.xml`: changed landscape-card status text to white and added a 124 dp width limit with end ellipsis.
- `app/src/mobile/res/layout/activity_video.xml`: applied the same readable, bounded status style to the detail header.
- `app/build.gradle`: bumped the APK version to `549 / 5.4.9`.
- `docs/release-version.md` and `docs/cloud-white-ui-20260708.md`: updated the current version and documented the poster-status treatment.
- `tmp/vod-remark-549.png` and `tmp/vod-remark-549.xml`: retained final MuMu visual and hierarchy evidence.
- `progress.md`: appended this implementation, verification, and rollback record.
- Rollback method: change `shape_vod_remark.xml` back to `@color/xg_badge_teal`; restore the three status TextViews to `@color/control` without `android:ellipsize` or `android:maxWidth`; set `app/build.gradle` and version docs back to `548 / 5.4.8`; remove the poster-status note from `docs/cloud-white-ui-20260708.md`; delete `tmp/vod-remark-549.png` and `tmp/vod-remark-549.xml`; remove this progress entry; then rebuild with `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-15 - Task: Fix the continue-watching engine label
### What was done
- Corrected the `EXO` marker in the continue-watching card after the poster-status background change made its old dark text appear as an unreadable black block.
- Separated the engine marker from the poster-overlay visual treatment by using the existing light slate chip with dark cloud-white text.
- Kept the continue-watching title, line marker, card dimensions, spacing, and click behavior unchanged.
- Bumped the mobile APK version to `550 / 5.5.0` and documented the corrected engine-chip treatment.

### Testing
- Passed: `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed with `BUILD SUCCESSFUL`.
- Passed: `aapt2 dump badging` reported package `com.xingguang.video`, `versionCode='550'`, and `versionName='5.5.0'`; final APK SHA-256 is `CB92E9C5FED2D942208D387046E83E4FD0FF3244828FDBB4254920B4140A949F`.
- Passed: MuMu `127.0.0.1:16384` installed the APK successfully, and device package state reported `versionCode=550` and `versionName=5.5.0`.
- Passed: `tmp/vod-history-engine-550-final.png` visually confirmed the previous black block is replaced by a readable light slate `EXO` chip while the adjacent `线路优先` chip and cloud-white card remain unchanged.
- Passed: app-PID-scoped logcat contained no `FATAL EXCEPTION`, `AndroidRuntime: FATAL`, `InflateException`, `Resources$NotFoundException`, or app process-death matches.

### Notes
- `app/src/mobile/res/layout/fragment_vod.xml`: changed the continue-watching `EXO` marker to dark text on the existing light slate chip.
- `app/build.gradle`: bumped the APK version to `550 / 5.5.0`.
- `docs/release-version.md`: updated the documented current APK version and version mapping.
- `docs/cloud-white-ui-20260708.md`: documented the continue-watching engine-chip treatment and current version.
- `tmp/vod-history-engine-550-final.png`: retained the final MuMu visual evidence; removed the intermediate dark-chip screenshot and hierarchy capture.
- `progress.md`: appended this implementation, verification, and rollback record.
- Rollback method: restore the `EXO` TextView in `fragment_vod.xml` to `@color/control` with `@drawable/shape_vod_remark`; set `app/build.gradle` and version docs back to `549 / 5.4.9`; remove the continue-watching engine-chip note from `docs/cloud-white-ui-20260708.md`; delete `tmp/vod-history-engine-550-final.png`; remove this progress entry; then rebuild with `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-15 - Task: Sync NewBox 1.5.5 Exo HLS ad-filtering fix
### What was done
- Compared the NewBox 1.5.5 decompiled Exo HLS parser and HTTP interceptors with the existing two-switch ad-filtering implementation.
- Moved Exo HLS playlist purification into a Media3 playlist parser while preserving the original CDN playback URL and request headers.
- Kept IJK and MPV on the existing local HLS service so their current filtering behavior remains available.
- Reused one playlist-filter implementation for both paths and retained original playlist input as the Exo fallback when filtering fails.
- Bumped the mobile APK version to `551 / 5.5.1` and documented the reverse-engineering basis and compatibility boundary.

### Testing
- Passed: `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed with `BUILD SUCCESSFUL`; the changed Media3 classes were recompiled and the APK was repackaged.
- Passed: `aapt dump badging` reported package `com.xingguang.video`, `versionCode='551'`, and `versionName='5.5.1'`.
- Passed: final APK SHA-256 is `3051DF520DF76675277E4FB0A4A7F34FCDAE30EA7D0B1D60A617BCA00B445CDC`.
- Passed: static path checks confirmed Exo keeps the original URL, installs `HlsPlaylistParserFactory`, and IJK/MPV still call `Hls.getUrl(...)`.
- Not run: MuMu runtime playback verification because `127.0.0.1:16384` refused the ADB connection and no emulator device was online.

### Notes
- `app/src/main/java/com/fongmi/android/tv/player/exo/HlsPlaylistParserFactory.java`: added the bounded, fallback-safe Media3 HLS parser wrapper.
- `app/src/main/java/com/fongmi/android/tv/player/exo/MediaSourceFactory.java`: routed HLS media sources, including concatenated items, through the custom parser factory.
- `app/src/main/java/com/fongmi/android/tv/player/Players.java`: stopped localhost HLS URL rewriting for Exo only.
- `app/src/main/java/com/fongmi/android/tv/server/process/Hls.java`: extracted the shared pure playlist filtering function while retaining local proxy rewriting for non-Exo players.
- `app/build.gradle`: bumped the APK version to `551 / 5.5.1`.
- `docs/ad-filtering-20260714.md`: documented Exo in-player filtering, fallback behavior, and the absence of a CDN-specific Referer interceptor in the analyzed APK.
- `docs/release-version.md` and `docs/cloud-white-ui-20260708.md`: updated the current version and playback compatibility note.
- `progress.md`: appended this implementation, verification gap, file list, and rollback record.
- Rollback method: remove `HlsPlaylistParserFactory.java`; restore `MediaSourceFactory.java` to use only `DefaultMediaSourceFactory`; restore `Players.java` to always assign `Hls.getUrl(...)`; fold `Hls.filter(...)` back into `rewrite(...)`; set `app/build.gradle` and version docs back to `550 / 5.5.0`; remove the 5.5.1 documentation notes and this progress entry; then rebuild with `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-15 - Task: Verify the 5.5.1 Exo HLS fix on MuMu
### What was done
- Installed the completed `551 / 5.5.1` APK after the user enabled the MuMu ADB connection.
- Opened the home page, entered a VOD detail page, started episode playback with Exo, and returned to the home page after playback.
- Captured device screenshots, hierarchy data, and app-scoped runtime logs as verification evidence.

### Testing
- Passed: ADB connected to MuMu at `127.0.0.1:16384`, streamed installation completed successfully, and device package state reported `versionCode=551` and `versionName=5.5.1`.
- Passed: the application launched to the cloud-white home page and loaded poster data without a startup crash.
- Passed: `少侠逆袭攻略` episode 1 entered `VideoActivity` and produced a valid moving video frame after a 12-second playback wait.
- Passed: app-scoped playback logs contained no `/adm3u8`, `HlsAdFilter` failure, local HLS failure, HTTP 403, `FATAL EXCEPTION`, or `AndroidRuntime: FATAL` match.
- Passed: exiting playback returned the resumed activity to `HomeActivity`, confirming the app did not remain in the fullscreen playback page.

### Notes
- `tmp/ad-sync-551-home.png` and `tmp/ad-sync-551-home.xml`: retained the installed build's home-page visual and hierarchy evidence.
- `tmp/ad-sync-551-detail.png` and `tmp/ad-sync-551-detail.xml`: retained the selected VOD detail-page evidence.
- `tmp/ad-sync-551-playing.png`: retained the successful Exo playback-frame evidence.
- `tmp/ad-sync-551-logcat.txt`: retained the runtime log capture used for proxy, 403, filter-failure, and crash checks.
- `tmp/ad-sync-551-return.png`: retained the first playback-back interaction capture; final activity-state verification was obtained from `dumpsys activity` after the second back action.
- `progress.md`: appended this device-verification result and evidence list.
- Rollback method: delete the `tmp/ad-sync-551-*` verification artifacts and remove this progress entry; no application behavior or source code was changed during this verification task.

## 2026-07-15 - Task: Fix inconsistent real-device system navigation-bar color
### What was done
- Corrected the light-page edge-to-edge setup so it no longer leaves the system navigation bar transparent for OEM-specific composition.
- Explicitly applied the cloud-white surface color to both system bars on normal light pages while preserving transparent immersive bars on fullscreen video pages.
- Bumped the mobile APK version to `552 / 5.5.2` and documented the real-device system-bar behavior.

### Testing
- Passed: `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed with `BUILD SUCCESSFUL`.
- Passed: `aapt dump badging` reported package `com.xingguang.video`, `versionCode='552'`, and `versionName='5.5.2'`.
- Passed: final APK SHA-256 is `CBACFAA6D1D9D6E8F62928C62868AB6C6ED6CA199AF20F72221D91490E44097D`.
- Passed: static verification confirmed `BaseActivity` applies `xg_surface` after `EdgeToEdge.enable(...)` via both `setStatusBarColor(...)` and `setNavigationBarColor(...)` for light pages.
- Not run: final MuMu screenshot verification because the emulator ADB device disconnected during installation and `127.0.0.1:16384` was no longer present.

### Notes
- `app/src/mobile/java/com/fongmi/android/tv/ui/base/BaseActivity.java`: fixed normal-page system navigation-bar color after edge-to-edge initialization.
- `app/build.gradle`: bumped the APK version to `552 / 5.5.2`.
- `docs/release-version.md`: updated the current APK version.
- `docs/cloud-white-ui-20260708.md`: documented fixed cloud-white navigation bars and unchanged fullscreen-video immersion.
- `progress.md`: appended this implementation, verification evidence, remaining device-test gap, and rollback record.
- Rollback method: remove the `setNavigationBarColor(surface)` call and restore the single-line status-bar assignment in `BaseActivity.java`; set `app/build.gradle` and version docs back to `551 / 5.5.1`; remove the 5.5.2 system-navigation-bar documentation and this progress entry; then rebuild with `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-16 - Task: Remove green backgrounds and app-owned green UI
### What was done
- Fixed the actual residual green-background source by disabling the mobile `CustomWallView` mount, which previously fell back to the built-in wallpaper behind transparent activity regions.
- Changed normal-page and bottom-sheet system bars to opaque cloud white and fullscreen VOD/live system bars to opaque black, including the navigation-bar divider.
- Replaced app-owned green status labels, random placeholder colors, Leanback quick-action text, launcher vectors, launcher PNGs, and the TV banner with dark or blue equivalents.
- Preserved original colors in video frames, posters, remote source artwork, advertisements, and source-provided text or emoji because those are content rather than application UI.
- Bumped the mobile APK version to `553 / 5.5.3` and documented the color boundary.

### Testing
- Passed: `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed with `BUILD SUCCESSFUL` after the final wallpaper-disable change.
- Passed: MuMu `127.0.0.1:16384` installed the final APK successfully and ran VOD playback in `VideoActivity` with black letterbox/system-bar regions and no green application background.
- Passed: the live page used a black fullscreen/loading background with a blue loading indicator.
- Passed: returning from playback removed the fullscreen activity; no app-scoped `FATAL EXCEPTION`, `AndroidRuntime: FATAL`, `InflateException`, or missing-resource match was found.
- Passed: source scans found no remaining green/teal/lime resource value used by app-owned UI; deterministic pixel scans reported zero greenish pixels in all launcher PNGs and the TV banner.
- Passed: `aapt dump badging` reported package `com.xingguang.video`, `versionCode='553'`, and `versionName='5.5.3'`.
- Passed: final APK SHA-256 is `A4B81D928E89215D33E24F2AD9A80CEBB2374F2D8DBFB03EA69059182C9AFBA5`.

### Notes
- `app/src/mobile/java/com/fongmi/android/tv/ui/base/BaseActivity.java`: disabled mobile wallpaper mounting and assigned opaque white or black system-bar colors according to page mode.
- `app/src/mobile/res/values/styles.xml` and `app/src/mobile/res/values/colors.xml`: removed transparent bottom-sheet navigation and replaced the teal badge token with blue.
- `app/src/main/res/drawable/shape_vod_remark.xml`: replaced the green status-label fill with the strong dark overlay.
- `app/src/main/java/com/fongmi/android/tv/utils/ColorGenerator.java`: removed cyan, teal, green, light-green, and lime placeholder colors.
- `app/src/leanback/res/layout/adapter_quick.xml`: changed green quick-action text to blue.
- `app/src/main/res/drawable/ic_launcher_foreground.xml` and `app/src/leanback/res/drawable/ic_banner_foreground.xml`: replaced mint vector accents with blue accents.
- `app/src/main/ic_launcher-playstore.png`, all `app/src/main/res/mipmap-*/ic_launcher*.png`, and `app/src/leanback/res/drawable/ic_banner.png`: deterministically recolored green/cyan pixels to blue.
- `app/build.gradle`: bumped the APK version to `553 / 5.5.3`.
- `docs/release-version.md` and `docs/cloud-white-ui-20260708.md`: updated the version and documented system bars, wallpaper removal, and the remote-content color boundary.
- `tmp/green-ui-553-backup/`: retained pre-recolor launcher and banner assets plus the file manifest for exact binary rollback.
- `tmp/green-ui-553-home.png`, `tmp/green-ui-553-playing.png`, `tmp/green-ui-553-transient-bars.png`, `tmp/green-ui-553-return.png`, `tmp/green-ui-553-live.png`, and `tmp/green-ui-553-final-*.png`: retained device visual evidence from normal, VOD, live, return, and final-package checks.
- `progress.md`: appended this implementation, device verification, evidence, and rollback record.
- Rollback method: restore the backed-up binary assets from `tmp/green-ui-553-backup/app/` to their matching `app/` paths; restore transparent dark-page system bars and `customWall() = true` in mobile `BaseActivity.java`; restore the bottom-sheet transparent navigation color, green status/token colors, full `ColorGenerator` palette, green Leanback text, and original vector fills; set version/docs back to `552 / 5.5.2`; remove the 5.5.3 evidence and this progress entry; then rebuild with `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-16 - Task: Remove the mobile wallpaper layer and player color overlay
### What was done
- Removed the mobile activity-base code that inserted `CustomWallView`, so the wallpaper layer can no longer be mounted behind mobile pages or playback transitions.
- Removed the full-frame `xg_overlay_soft` backgrounds from both VOD and live playback control roots.
- Kept individual control-button backgrounds, text, seek controls, and commands unchanged while preventing the control panel from recoloring the video frame.
- Bumped the mobile APK version to `554 / 5.5.4` and documented the changed playback-control behavior.

### Testing
- Passed: `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed with `BUILD SUCCESSFUL` after correcting the retained `ViewGroup` import required by cutout padding.
- Passed: MuMu `127.0.0.1:16384` installed the APK and device package state reported `versionCode=554` and `versionName=5.5.4`.
- Passed: VOD playback was captured with controls hidden and visible; the visible-control frame retained the original vivid video colors while only bounded buttons, labels, and seek controls appeared.
- Passed: a fixed video region measured luma `186.62` with controls hidden and `189.02` with controls visible, confirming there is no whole-frame darkening layer.
- Passed: static checks found no `CustomWallView` reference in the mobile activity base and no `xg_overlay_soft` reference in either VOD or live control root.
- Passed: app-scoped logs contained no `FATAL EXCEPTION`, `AndroidRuntime: FATAL`, `InflateException`, or missing-resource match during playback verification.
- Passed: `aapt dump badging` reported package `com.xingguang.video`, `versionCode='554'`, and `versionName='5.5.4'`; final APK SHA-256 is `46D61F8E7A864F7D4EE43A9D7ABA314945C06857C795A219C8173991FEE02C61`.

### Notes
- `app/src/mobile/java/com/fongmi/android/tv/ui/base/BaseActivity.java`: removed mobile wallpaper-view insertion while retaining unrelated cutout and system-bar handling.
- `app/src/mobile/res/layout/view_control_vod.xml`: changed the VOD control root from the full-frame dark overlay to transparent.
- `app/src/mobile/res/layout/view_control_live.xml`: changed the live control root from the full-frame dark overlay to transparent.
- `app/build.gradle`: bumped the APK version to `554 / 5.5.4`.
- `docs/release-version.md` and `docs/cloud-white-ui-20260708.md`: updated the version and documented wallpaper-layer removal and transparent playback controls.
- `tmp/detail-554.xml`: retained the hierarchy evidence used to locate and open the episode item.
- `tmp/control-overlay-554-hidden.png` and `tmp/control-overlay-554-visible.png`: retained the VOD before/after-control visual evidence.
- `tmp/control-overlay-554-live.png`: retained the live-path capture; the selected stream remained at `0 KB/s`, so live playback color comparison was supported by the shared transparent layout and static check rather than a moving frame.
- `progress.md`: appended this implementation, verification evidence, limitation, and rollback record.
- Rollback method: restore the mobile `BaseActivity.setContentView(...)` override and `CustomWallView` imports; restore `@color/xg_overlay_soft` on the VOD and live control roots; set version/docs back to `553 / 5.5.3`; delete the 5.5.4 evidence and this progress entry; then rebuild with `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-16 - Task: Remove the bottom navigation lower seam
### What was done
- Confirmed that the highlighted blue-gray line came from the `1dp` full-outline stroke in the mobile bottom-navigation background rather than from the cloud-blue parent container.
- Removed only that navigation-background stroke, preserving the white navigation surface, white system navigation-bar area, and the existing cloud-blue page background.
- Bumped the mobile APK version to `555 / 5.5.5` and documented the bottom-navigation seam behavior.

### Testing
- Passed: `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed with `BUILD SUCCESSFUL`.
- Passed: `aapt dump badging` reported package `com.xingguang.video`, `versionCode='555'`, and `versionName='5.5.5'`.
- Passed: MuMu `127.0.0.1:16384` installed the APK and displayed `HomeActivity` as the focused window.
- Passed: device screenshot inspection confirmed the bottom navigation joins the lower white area without the previous blue-gray horizontal seam.
- Passed: a pixel scan across the bottom 300 screenshot rows found a maximum of `0` pixels matching `xg_line` (`#D8E2EF`) in any row.
- Passed: app-scoped runtime logs contained no `FATAL EXCEPTION`, `AndroidRuntime: FATAL`, `InflateException`, or missing-resource match.
- Passed: final APK SHA-256 is `5613976E0FA17D3116507BEB244F702EA4B08A91362C3BB70F5F81A079513123`.

### Notes
- `app/src/mobile/res/drawable/shape_cloud_bottom_nav.xml`: removed the full-outline `xg_line` stroke that produced the unwanted lower seam.
- `app/build.gradle`: bumped the APK version to `555 / 5.5.5`.
- `docs/release-version.md`: updated the current APK version and aligned version example.
- `docs/cloud-white-ui-20260708.md`: documented the seam removal and unchanged page-level cloud-blue background.
- `tmp/bottom-nav-555.png`: retained the installed-build home-page screenshot used for visual verification.
- `tmp/bottom-nav-555-crop.png`: retained the enlarged bottom-region evidence showing the seamless white navigation surface.
- `tmp/bottom-nav-555.xml`: retained the installed-build UI hierarchy evidence.
- `tmp/bottom-nav-555-logcat.txt`: retained the app-scoped runtime log used for crash checks.
- `progress.md`: appended this implementation, verification evidence, and rollback record.
- Rollback method: restore `<stroke android:width="1.0dip" android:color="@color/xg_line" />` below the solid item in `shape_cloud_bottom_nav.xml`; set `app/build.gradle` and version docs back to `554 / 5.5.4`; remove the 5.5.5 bottom-navigation documentation and this progress entry; then rebuild with `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.
## 2026-07-16 - Task: Export the verified 5.5.5 APK
### What was done
- Copied the verified mobile ARM64 debug APK into a stable top-level delivery directory with a versioned filename.

### Testing
- Passed: `aapt dump badging` reported package `com.xingguang.video`, `versionCode='555'`, and `versionName='5.5.5'` for the exported APK.
- Passed: exported file size is `82618121` bytes.
- Passed: exported APK SHA-256 is `5613976E0FA17D3116507BEB244F702EA4B08A91362C3BB70F5F81A079513123`, matching the installed and previously verified build.

### Notes
- `output/XingGuang-5.5.5-arm64.apk`: added the versioned APK delivery artifact.
- `progress.md`: appended this artifact-export record and rollback instruction.
- Rollback method: delete `output/XingGuang-5.5.5-arm64.apk` and remove this progress entry; no source or application behavior needs to be reverted.

## 2026-07-16 - Task: Increase the portrait VOD player height by 50 percent
### What was done
- Increased the phone portrait VOD player container from `150dp` to `225dp`, exactly 50% larger, without changing video scaling behavior.
- Kept landscape fullscreen behavior and the separate large-screen layout unchanged.
- Bumped the mobile APK version to `556 / 5.5.6`, documented the layout change, and exported the verified ARM64 APK.

### Testing
- Passed: `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed with `BUILD SUCCESSFUL`.
- Passed: MuMu `127.0.0.1:16384` installed the APK and reported `versionCode=556` and `versionName=5.5.6`.
- Passed: the portrait `video` bounds were `[0,72][1080,747]`; at physical density `480` (`3.0x`), the measured `675px` height equals `225dp` and confirms the requested 50% increase from `150dp`.
- Passed: the detail content begins at `y=747`, directly below the player, with no overlap or clipped controls in the captured portrait layout.
- Passed: the fullscreen control entered landscape playback (`SurfaceOrientation: 1`); Android Back returned to portrait (`SurfaceOrientation: 0`) while keeping `VideoActivity` focused and restoring the same `225dp` player bounds.
- Passed: app-scoped runtime logs contained no `FATAL EXCEPTION`, `AndroidRuntime: FATAL`, `InflateException`, or missing-resource match.
- Passed: `aapt dump badging` reported package `com.xingguang.video`, `versionCode='556'`, and `versionName='5.5.6'`.
- Passed: exported APK size is `82618125` bytes and SHA-256 is `EB9B3CF911112BC0ECF91C1C328CB527C005CB45E15BD1F3D9A8DE2AB0C02D64`.

### Notes
- `app/src/mobile/res/layout/activity_video.xml`: increased only the phone portrait VOD player height from `150dp` to `225dp`.
- `app/build.gradle`: bumped the APK version to `556 / 5.5.6`.
- `docs/release-version.md`: updated the current APK version and version-alignment example.
- `docs/cloud-white-ui-20260708.md`: documented the portrait player increase and unchanged landscape/large-screen behavior.
- `output/XingGuang-5.5.6-arm64.apk`: added the verified versioned delivery APK.
- `tmp/portrait-player-556.png`, `tmp/portrait-player-556-return.png`, and `tmp/portrait-player-556-full-test.png`: retained portrait, return, and fullscreen visual evidence.
- `tmp/portrait-player-556.xml`, `tmp/portrait-player-556-return.xml`, and `tmp/portrait-player-556-logcat.txt`: retained measured layout bounds and app-scoped runtime-log evidence.
- `progress.md`: appended this implementation, device verification, delivery artifact, and rollback record.
- Rollback method: restore `android:layout_height="150.0dip"` on the portrait `video` frame in `activity_video.xml`; set `app/build.gradle` and version docs back to `555 / 5.5.5`; remove the `5.5.6 Portrait Player Height` documentation, delete `output/XingGuang-5.5.6-arm64.apk` and the `tmp/portrait-player-556*` evidence files, remove this progress entry, then rebuild with `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-16 - Task: Fix unreadable fullscreen subtitle, video-track, and audio-track menus
### What was done
- Replaced the white track-menu title with the cloud-white dark primary text color.
- Replaced the fixed white track-row text with the existing state-aware selector, so normal rows are dark and selected rows are blue on the light menu surface.
- Applied the shared fix to subtitle, video-track, and audio-track menus without changing track discovery, selection, or playback behavior.
- Bumped the mobile APK version to `557 / 5.5.7`, documented the readability change, and exported the verified ARM64 APK.

### Testing
- Passed: `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed with `BUILD SUCCESSFUL`.
- Passed: MuMu `127.0.0.1:16384` installed the APK and reported `versionCode=557` and `versionName=5.5.7`.
- Passed: opened the fullscreen video-track menu and visually confirmed the dark `选择视轨` title plus blue selected `1920 × 1080` row on the cloud-white surface.
- Passed: opened the fullscreen audio-track menu and visually confirmed the dark `选择音轨` title plus blue selected `立体声` row on the cloud-white surface.
- Passed: opened the fullscreen subtitle menu and visually confirmed the dark `选择字幕` title, dark `未知` row text, blue selected-row border, and dark action icons.
- Passed: Android Back dismissed each menu while keeping `VideoActivity` focused in landscape playback (`SurfaceOrientation: 1`).
- Passed: app-scoped runtime logs contained no `FATAL EXCEPTION`, `AndroidRuntime: FATAL`, `InflateException`, or missing-resource match.
- Passed: `aapt dump badging` reported package `com.xingguang.video`, `versionCode='557'`, and `versionName='5.5.7'`.
- Passed: exported APK size is `82618121` bytes and SHA-256 is `A0D10E1A3FF0130C1ACD2976FC541131EB4BF2DAB6673E5B268A38C8E95B672B`.

### Notes
- `app/src/mobile/res/layout/dialog_track.xml`: changed the shared track-menu title from white to the cloud-white dark primary text color.
- `app/src/mobile/res/layout/adapter_track.xml`: changed track rows from fixed white text to the existing normal/selected state-aware text selector.
- `app/build.gradle`: bumped the APK version to `557 / 5.5.7`.
- `docs/release-version.md`: updated the current APK version and version-alignment example.
- `docs/cloud-white-ui-20260708.md`: documented readable subtitle, video-track, and audio-track menus.
- `output/XingGuang-5.5.7-arm64.apk`: added the verified versioned delivery APK.
- `tmp/track-menu-557-video.png`, `tmp/track-menu-557-audio.png`, and `tmp/track-menu-557-subtitle.png`: retained fullscreen visual evidence for all three menu types.
- `tmp/track-menu-557-video.xml`, `tmp/track-menu-557-subtitle.xml`, and `tmp/track-menu-557-logcat.txt`: retained menu hierarchy and app-scoped runtime-log evidence.
- `progress.md`: appended this implementation, device verification, delivery artifact, and rollback record.
- Rollback method: restore `@color/white` on the title in `dialog_track.xml` and track text in `adapter_track.xml`; set `app/build.gradle` and version docs back to `556 / 5.5.6`; remove the `5.5.7 Track Menu Readability` documentation, delete `output/XingGuang-5.5.7-arm64.apk` and the `tmp/track-menu-557*` evidence files, remove this progress entry, then rebuild with `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-19 - Task: Fix the black playback badge in mobile search results
### What was done
- Corrected the dark playback badge in mobile search-result cards so its `播放` label uses white text instead of the dark state selector.
- Preserved the dark badge background, adjacent light `来源` badge, card dimensions, poster layout, and search behavior.
- Bumped the mobile APK version to `558 / 5.5.8`, documented the visual fix, and exported the verified ARM64 APK.

### Testing
- Passed: `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed with `BUILD SUCCESSFUL`.
- Passed: MuMu `127.0.0.1:16384` installed the APK and reported `versionCode=558` and `versionName=5.5.8`.
- Passed: searched for `Sherlock` through the real mobile search workflow and rendered multiple `adapter_search` cards using the same layout shown in the reported screenshot.
- Passed: visual inspection confirmed each dark badge clearly displays white `播放` text and no longer appears as an empty black block; the adjacent `来源` badge remains readable and card content does not overlap.
- Passed: app-scoped runtime logs contained no `FATAL EXCEPTION`, `AndroidRuntime: FATAL`, `InflateException`, or missing-resource match.
- Passed: `aapt dump badging` reported package `com.xingguang.video`, `versionCode='558'`, and `versionName='5.5.8'`.
- Passed: exported APK size is `82618125` bytes and SHA-256 is `E1A2809B200B392121E6EC84A8B161CCF7107A116672B95DF931AAC7D63BB911`.

### Notes
- `app/src/mobile/res/layout/adapter_search.xml`: changed only the dark playback badge text from the state-aware dark selector to white.
- `app/build.gradle`: bumped the APK version to `558 / 5.5.8`.
- `docs/release-version.md`: updated the current APK version and version-alignment example.
- `docs/cloud-white-ui-20260708.md`: documented the readable search-result playback badge.
- `output/XingGuang-5.5.8-arm64.apk`: added the verified versioned delivery APK.
- `tmp/search-badge-558.png`, `tmp/search-badge-558.xml`, and `tmp/search-badge-558-logcat.txt`: retained final search-result visual, hierarchy, and app-scoped runtime-log evidence.
- `tmp/search-badge-558-entry.xml`: retained the intermediate search-entry hierarchy because the local command policy blocked deletion after path verification.
- `progress.md`: appended this implementation, device verification, delivery artifact, and rollback record.
- Rollback method: restore `@color/control` on the `shape_vod_remark` playback label in `adapter_search.xml`; set `app/build.gradle` and version docs back to `557 / 5.5.7`; remove the `5.5.8 Search Result Play Badge` documentation, delete `output/XingGuang-5.5.8-arm64.apk` and the `tmp/search-badge-558*` evidence files, remove this progress entry, then rebuild with `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-17 - Task: Initialize and publish the project to GitHub
### What was done
- Initialized the workspace as a Git repository on the `main` branch and created the initial project import commit.
- Created the private GitHub repository `aqgyvn/XingGuang-tv`, connected it as `origin`, and published `main`.
- Excluded local SDKs, tool bundles, generated artifacts, APKs, and signing material from version control.
- Added repository-management documentation for new checkouts and future release handling.

### Testing
- Passed: the staged-file audit found no paths under `android-sdk/`, `tools/`, `output/`, `tmp/`, `apkwork/`, or `archive/`, and no staged APK, AAB, P12, PFX, PEM, JKS, or KEY files.
- Passed: the initial import contained 940 tracked files and 77,040 inserted lines without any file exceeding GitHub's 100 MB per-file limit.
- Passed: `git ls-remote origin refs/heads/main` returned `ba7dc8181cbaaa57558749b1e00132d393a83f1d`, matching the local initial commit.

### Notes
- `.gitignore`: added exclusions for machine-local SDKs and tools, generated delivery and verification artifacts, backups, APK bundles, and signing material.
- `docs/repository-management.md`: documented the tracked scope, local Android setup, and GitHub Releases usage.
- `progress.md`: appended this repository initialization, publication verification, and rollback record.
- Rollback point: the initial imported tree is commit `ba7dc8181cbaaa57558749b1e00132d393a83f1d`; disconnect the local checkout with `git remote remove origin`, and remove the GitHub repository from its Settings page if publication must be fully undone.

## 2026-07-17 - Task: Rewrite the GitHub README in Chinese
### What was done
- Replaced the corrupted and overly detailed repository homepage with a concise Simplified Chinese introduction for XingGuang TV.
- Added current project capabilities, environment requirements, a Windows build command, documentation links, upstream acknowledgements, a usage notice, and license information.
- Moved the homepage focus away from low-level configuration tables while retaining access to the existing detailed documentation.

### Testing
- Passed: `README.md` decodes as UTF-8, starts with the Chinese title `星光 TV`, and contains no Unicode replacement characters.
- Passed: the displayed version `5.5.7` matches `versionName` in `app/build.gradle`.
- Passed: all six relative Markdown links in the README resolve to existing repository files.

### Notes
- `README.md`: replaced the previous homepage content with a concise Simplified Chinese project overview and setup entry points.
- `progress.md`: appended this README update, verification evidence, and rollback record.
- Rollback method: run `git revert <this-task-commit>` after the task commit is created, then push the generated revert commit to `main`.

## 2026-07-17 - Task: Simplify README project attribution
### What was done
- Updated the README project-attribution paragraph to reference only `FongMi/TV`.
- Removed the CatVod wording and link as requested.

### Testing
- Passed: `README.md` contains the `FongMi/TV` link and no longer contains `CatVod`.
- Passed: the rest of the README content remains unchanged for this focused edit.

### Notes
- `README.md`: simplified the project attribution to a single FongMi/TV reference.
- `progress.md`: appended this README adjustment, verification evidence, and rollback record.
- Rollback method: run `git revert <this-task-commit>` after the task commit is created, then push the generated revert commit to `main`.

## 2026-07-17 - Task: Remove README build instructions and verify Simplified Chinese
### What was done
- Removed the README environment-requirement section, local SDK setup example, Gradle build command, and build-document links.
- Kept the repository homepage focused on the project introduction, main capabilities, attribution, usage notice, and license.
- Reviewed the remaining README text for Traditional Chinese characters; no conversion was required in the retained content.

### Testing
- Passed: `README.md` no longer contains the headings `环境要求` or `构建项目`, the `local.properties` example, or a Gradle build command.
- Passed: the retained README contains no identified Traditional Chinese wording and remains valid UTF-8 Chinese text.
- Passed: the FongMi/TV attribution and GPL license link remain present.

### Notes
- `README.md`: removed all homepage build and local-environment instructions.
- `progress.md`: appended this focused README cleanup, verification evidence, and rollback record.
- Rollback method: run `git revert <this-task-commit>` after the task commit is created, then push the generated revert commit to `main`.

## 2026-07-17 - Task: Convert linked documentation to Simplified Chinese
### What was done
- Converted the Chinese text in `docs/CONFIG.md` and `docs/LIVE.md` from Traditional Chinese to Simplified Chinese.
- Normalized remaining Taiwan-specific wording such as fields, request headers, defaults, examples, and global settings while preserving JSON keys, commands, URLs, and Markdown structure.
- Confirmed `docs/android-studio.md`, `docs/xingguang-rebuild.md`, and `docs/release-version.md` contain no Traditional Chinese characters and required no conversion.

### Testing
- Passed: OpenCC Traditional-to-Simplified verification reports no Traditional character differences in all five requested documents.
- Passed: Markdown internal-link targets remain present in `docs/CONFIG.md` and `docs/LIVE.md` after heading and anchor conversion.
- Passed: `git diff --check` reports no whitespace errors and all edited files remain UTF-8 without a BOM.

### Notes
- `docs/CONFIG.md`: converted configuration reference headings, tables, descriptions, examples, and anchors to Simplified Chinese.
- `docs/LIVE.md`: converted live-source format descriptions, examples, commands, and anchors to Simplified Chinese.
- `progress.md`: appended this documentation conversion, verification evidence, and rollback record.
- Rollback method: run `git revert <this-task-commit>` after the task commit is created, then push the generated revert commit to `main`.

## 2026-07-17 - Task: Remove the unused rebuild documentation
### What was done
- Deleted the unused `docs/xingguang-rebuild.md` document.
- Confirmed no active README or documentation links reference the deleted file.
- Left the rebuild script and its signing-file naming unchanged because they are separate executable configuration.

### Testing
- Passed: `rg` found no active repository reference to `docs/xingguang-rebuild.md` or its title outside historical progress records.
- Passed: the deleted file is absent from the working tree and no other files changed unexpectedly.

### Notes
- `docs/xingguang-rebuild.md`: deleted as unused documentation.
- `progress.md`: appended this deletion, verification evidence, and rollback record.
- Rollback method: restore `docs/xingguang-rebuild.md` from the parent commit with `git show HEAD^:docs/xingguang-rebuild.md > docs/xingguang-rebuild.md`, then commit and push the restoration.

## 2026-07-17 - Task: Restore active documentation links in README
### What was done
- Restored links in README for Android Studio configuration, version management, general configuration, and live-source configuration.
- Kept the deleted `docs/xingguang-rebuild.md` link absent.
- Kept build commands and local SDK setup instructions out of the README.

### Testing
- Passed: all four restored relative links resolve to existing files.
- Passed: `docs/xingguang-rebuild.md` remains absent and is not referenced by README.
- Passed: the README contains no Gradle build command or `local.properties` setup block.

### Notes
- `README.md`: added the four active documentation links under `相关文档`.
- `progress.md`: appended this README link restoration, verification evidence, and rollback record.
- Rollback method: run `git revert <this-task-commit>` after the task commit is created, then push the generated revert commit to `main`.

## 2026-07-20 - Task: Replace the black search playback badge with cloud-white blue
### What was done
- Replaced the visually heavy black playback badge in mobile search-result cards with a dedicated primary-blue rounded badge and white text.
- Kept the adjacent source badge light blue and preserved card dimensions, spacing, poster layout, and search behavior.
- Used a search-only drawable so existing dark poster-status labels and playback overlays remain unchanged.
- Bumped the mobile APK version to `559 / 5.5.9`, documented the visual change, and exported the verified ARM64 APK.

### Testing
- Passed: `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace` completed with `BUILD SUCCESSFUL`.
- Passed: MuMu `127.0.0.1:16384` installed the APK and reported `versionCode=559` and `versionName=5.5.9`.
- Passed: searched for `Sherlock` through the real mobile workflow and visually confirmed every visible search card uses a blue rounded `播放` badge with readable white text.
- Passed: the adjacent light-blue `来源` badge remains distinct, and card text, posters, spacing, and dimensions do not overlap or shift.
- Passed: static resource verification found `shape_vod_play` referenced only by `adapter_search.xml`, confirming existing dark status-label resources were not changed.
- Passed: app-scoped runtime logs contained no `FATAL EXCEPTION`, `AndroidRuntime: FATAL`, `InflateException`, or missing-resource match.
- Passed: `aapt dump badging` reported package `com.xingguang.video`, `versionCode='559'`, and `versionName='5.5.9'`.
- Passed: exported APK size is `82618714` bytes and SHA-256 is `E0480DFA31803E5CD683683C3E8BFA978FA7F157746D1763FF5C27FDF882F5F8`.

### Notes
- `app/src/mobile/res/drawable/shape_vod_play.xml`: added the compact rounded primary-blue background used only by search playback badges.
- `app/src/mobile/res/layout/adapter_search.xml`: replaced the black playback background with the new blue badge resource.
- `app/build.gradle`: bumped the APK version to `559 / 5.5.9`.
- `docs/release-version.md`: updated the current APK version and version-alignment example.
- `docs/cloud-white-ui-20260708.md`: documented the blue search playback badge and unchanged source badge/card layout.
- `output/XingGuang-5.5.9-arm64.apk`: added the verified versioned delivery APK.
- `tmp/search-blue-559.png`, `tmp/search-blue-559.xml`, and `tmp/search-blue-559-logcat.txt`: retained final visual, hierarchy, and app-scoped runtime-log evidence.
- `progress.md`: appended this implementation, device verification, delivery artifact, and rollback record.
- Rollback method: change the playback badge background in `adapter_search.xml` back to `@drawable/shape_vod_remark`, delete `shape_vod_play.xml`, set `app/build.gradle` and version docs back to `558 / 5.5.8`, remove the `5.5.9 Blue Search Play Badge` documentation, delete `output/XingGuang-5.5.9-arm64.apk` and the `tmp/search-blue-559*` evidence files, remove this progress entry, then rebuild with `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace`.

## 2026-07-23 - Task: Fix recent playback loading before VOD configuration is ready
### What was done
- Prevented recent playback from sending a detail request with an empty source during a cold start.
- Kept the detail page in its loading state until the VOD configuration finishes, then retried automatically without requiring the user to return and enter again.
- Preserved the existing title-based source-search fallback when a historical source no longer exists.
- Bumped the mobile APK version to `560 / 5.6.0`, updated version documentation, and exported the verified ARM64 APK.

### Testing
- Reproduced before the fix: a cold start followed by an immediate tap on `继续观看` sent `key=huaisang,id=68332` before source initialization and produced `ExecutionException` caused by a null URL in `OkHttp.buildUrl`; the page remained in the empty state.
- Passed: `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --no-parallel --max-workers=1 --stacktrace` completed with `BUILD SUCCESSFUL`; the single-worker retry was used after one incremental packaging attempt exhausted the Gradle heap.
- Passed: MuMu installed the final APK and reported `versionCode=560` and `versionName=5.6.0`.
- Passed: the final cold-start test immediately tapped `继续观看`; UI hierarchy checks reported detail and episode content present and no empty-state text.
- Passed: the same run reached ExoPlayer `READY` and Android media-session `PLAYING` states.
- Passed: the final app-scoped runtime log contained `0` `NullPointerException`, `0` `ExecutionException`, and `0` `FATAL EXCEPTION` matches.
- Passed: returning to Home and entering the same recent item again rendered the detail page and resumed playback normally.
- Passed: `aapt dump badging` reported package `com.xingguang.video`, `versionCode='560'`, and `versionName='5.6.0'`.
- Passed: exported APK size is `82618718` bytes and SHA-256 is `0DEA34597C8B9B5192E5968BB42C6A555AB64189616BCBE81FDB1DFCAC0EFD05`.

### Notes
- `app/src/mobile/java/com/fongmi/android/tv/ui/activity/VideoActivity.java`: added the minimal VOD-configuration wait and automatic detail retry for recent playback.
- `app/build.gradle`: bumped the APK version to `560 / 5.6.0`.
- `README.md`: aligned the displayed current version with `5.6.0`.
- `docs/release-version.md`: updated the current APK version and version-alignment example.
- `docs/cloud-white-ui-20260708.md`: documented the recent-playback cold-start behavior and automatic retry.
- `output/XingGuang-5.6.0-arm64.apk`: added the verified versioned delivery APK.
- `progress.md`: appended this implementation, device verification, delivery artifact, and rollback record.
- Rollback method: remove `waitingConfig` and its configuration-ready branches from `VideoActivity.java`; set `app/build.gradle`, `README.md`, and version documentation back to `559 / 5.5.9`; remove the `5.6.0 Recent Playback Cold-Start Loading` documentation, delete `output/XingGuang-5.6.0-arm64.apk`, remove this progress entry, then rebuild with `.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --no-parallel --max-workers=1 --stacktrace`.

## 2026-07-23 - Task: Create isolated iPhone/iPad development directory
### What was done
- Created the repository-level `ios/` directory for future iPhone and iPad client development.
- Added a minimal purpose marker without generating an Xcode project or adding platform dependencies.

### Testing
- Passed: `Test-Path -LiteralPath 'ios'` confirmed the directory exists at `D:\xingkong\ios`.
- Passed: read `ios/README.md` and confirmed it identifies the directory as the iPhone/iPad client workspace and keeps the existing Android modules separate.

### Notes
- `ios/README.md`: keeps the new platform directory tracked and documents its exclusive iPhone/iPad purpose.
- `progress.md`: appended this directory-creation and verification record.
- Rollback method: run `Remove-Item -LiteralPath .\ios\README.md` followed by `Remove-Item -LiteralPath .\ios`, then remove this final progress entry.

## 2026-07-23 - Task: Build the iPhone/iPad SwiftUI and CI foundation
### What was done
- Established an iOS/iPadOS 15 SwiftUI application foundation on the isolated `ios/` branch workspace without changing Android source code or resources.
- Added the cloud-white three-tab application shell and offline point-on-demand, live, settings, search, collection, history, detail, route, episode, EPG, configuration, loading, empty, and error states for iPhone and iPad.
- Added Android-compatible Codable foundation models, repository and player interfaces, fixture resources, focused unit/UI tests, XcodeGen project generation, and TrollStore IPA packaging.
- Added a GitHub Actions macOS workflow that generates the project, tests on both iPhone and iPad simulators, builds the unsigned device app, applies ad-hoc signing, validates the IPA, and uploads artifacts and logs.

### Testing
- Passed: all iOS text, source, JSON, plist, project, workflow, script, and documentation files decode as UTF-8 without replacement errors.
- Passed: `preview-config.json`, asset catalog JSON files, and `Info.plist` parse successfully with structured parsers.
- Passed: the iOS app icon is RGB without alpha and has the required `1024 x 1024` dimensions; visual inspection confirmed it reuses the Android application identity.
- Passed: `C:\Program Files\Git\bin\bash.exe -n ios/scripts/package-trollstore.sh` reported valid shell syntax.
- Passed: source-level checks found no iOS 16/17-only navigation, observation, or presentation APIs in the iOS 15 SwiftUI views.
- Passed: `git diff --check` reported no whitespace errors, and no tracked changes exist under Android application paths.
- Not run: Swift compilation, XcodeGen generation, iPhone/iPad Simulator execution, device codesigning, IPA installation, and TrollStore validation require macOS/Xcode or a pushed GitHub Actions run; the current Windows host has no `swift`, `xcodegen`, or `xcrun` executable.
- Not run: formal workflow-schema linting because `actionlint` and a local YAML parser are unavailable; the workflow was inspected structurally and remains subject to the first GitHub Actions run.

### Notes
- `.gitignore`: excludes generated Xcode projects, SwiftPM state, and user-specific Xcode state.
- `.github/workflows/ios.yml`: defines iPhone/iPad tests, device build, ad-hoc signing, IPA validation, and artifact upload.
- `docs/ios-development.md`: documents current scope, build and preview routes, CI behavior, TrollStore acceptance, and later migration stages.
- `ios/Package.swift`: defines the iOS 15 `XingGuangKit` Swift Package and processed preview resources.
- `ios/project.yml`: defines the universal app, unit-test, UI-test, and shared scheme targets for XcodeGen.
- `ios/README.md`: identifies the isolated iPhone/iPad workspace and its platform baseline.
- `ios/App/XingGuangApp.swift`: provides the minimal SwiftUI application lifecycle entry point.
- `ios/App/Info.plist`: defines the visible app identity, versions, launch color, supported devices, and orientations.
- `ios/App/Assets.xcassets/Contents.json`: declares the root application asset catalog.
- `ios/App/Assets.xcassets/AppIcon.appiconset/Contents.json`: declares the universal 1024-point iOS marketing icon.
- `ios/App/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`: provides the opaque iOS application icon derived from the Android identity.
- `ios/App/Assets.xcassets/LaunchBackground.colorset/Contents.json`: defines the cloud-white launch background color.
- `ios/Sources/XingGuangKit/Design/XingGuangTheme.swift`: defines the shared cloud-white SwiftUI palette and panel treatment.
- `ios/Sources/XingGuangKit/Fixtures/PreviewFixtures.swift`: provides deterministic offline catalog, history, collection, and configuration fixtures.
- `ios/Sources/XingGuangKit/Models/CodableDefaults.swift`: provides tolerant Android-style Codable defaults for missing fields.
- `ios/Sources/XingGuangKit/Models/CatalogModels.swift`: defines configuration, site, catalog, filter, VOD, and playback request models.
- `ios/Sources/XingGuangKit/Models/LiveModels.swift`: defines live source, group, channel, EPG, and EPG item models.
- `ios/Sources/XingGuangKit/Models/PersistenceModels.swift`: defines JSON values plus configuration, history, collection, and backup models.
- `ios/Sources/XingGuangKit/Resources/preview-config.json`: supplies the offline Android-compatible preview configuration.
- `ios/Sources/XingGuangKit/Resources/PreviewLogo.png`: supplies the in-app preview source logo.
- `ios/Sources/XingGuangKit/Services/VodRepository.swift`: defines the staged VOD repository and player engine interfaces.
- `ios/Sources/XingGuangKit/State/XingGuangAppModel.swift`: owns iOS 15 observable navigation, fixture, and configuration state.
- `ios/Sources/XingGuangKit/Views/XingGuangRootView.swift`: defines the point-on-demand, live, and settings tab shell.
- `ios/Sources/XingGuangKit/Views/VodHomeView.swift`: defines the offline VOD home, state variants, shortcuts, categories, and adaptive grid.
- `ios/Sources/XingGuangKit/Views/LiveHomeView.swift`: defines the live player placeholder, group, channel, and EPG interactions.
- `ios/Sources/XingGuangKit/Views/SettingsView.swift`: defines configuration persistence, status feedback, toggles, and player settings.
- `ios/Sources/XingGuangKit/Views/SearchPreviewView.swift`: defines the offline searchable VOD sheet.
- `ios/Sources/XingGuangKit/Views/CollectionPreviewView.swift`: defines reusable collection and history grids.
- `ios/Sources/XingGuangKit/Views/VodDetailPreviewView.swift`: defines the player placeholder, metadata, routes, episodes, and description.
- `ios/Sources/XingGuangKit/Views/Components/ActionIcon.swift`: defines compact accessible header actions.
- `ios/Sources/XingGuangKit/Views/Components/SectionTitle.swift`: defines consistent section headings.
- `ios/Sources/XingGuangKit/Views/Components/VodPosterCard.swift`: defines stable adaptive VOD poster cards.
- `ios/Tests/XingGuangKitTests/DomainModelsTests.swift`: covers fixture decoding and Android-compatible model defaults.
- `ios/Tests/XingGuangKitTests/XingGuangAppModelTests.swift`: covers configuration validation, persistence, and category selection.
- `ios/Tests/XingGuangUITests/XingGuangUITests.swift`: covers primary-tab launch, configuration save feedback, and VOD detail navigation.
- `ios/scripts/package-trollstore.sh`: applies ad-hoc signing and creates and validates a TrollStore IPA payload.
- `progress.md`: appends this implementation, verification evidence, known macOS validation gap, and rollback record.
- Rollback method: before committing, run `git restore -- .gitignore progress.md`, remove `.github/workflows/ios.yml` and `docs/ios-development.md`, and remove the `ios/` directory; after committing, use `git revert <ios-foundation-commit>` to preserve repository history.

## 2026-07-24 - Task: Complete iOS phase-one API VOD, persistence, and dual-player implementation

### What was done
- Upgraded the iPhone/iPad client from an offline fixture shell to a first-phase API VOD client with Android-compatible type 0 XML, type 1 JSON, and type 4 extension requests for configuration, home, category, search, detail, and playback resolution.
- Added GRDB/SQLite persistence for configuration, sites, live records, favorites, history, playback progress, speed, and track selections; connected real configuration loading, source switching, favorites, history, and continue-watching UI state.
- Added AVPlayer and MobileVLCKit routing with automatic/forced core selection, one-time format fallback, playback progress and resume handling, AVPlayer track selection, AirPlay, background audio, and system picture-in-picture entry.
- Added structured URLSession request handling for headers, cookies, redirects, timeout, cancellation, response cookies, and HTTP errors; preserved cancellation when switching sources.
- Added CocoaPods integration and locked MobileVLCKit `3.6.0b10`; updated the CI workflow and IPA packager to build the CocoaPods workspace and sign embedded frameworks before the App.
- Documented first-phase capability boundaries, LGPL notice, Mac build workflow, CI behavior, TrollStore acceptance gates, and remaining JavaScript/live/advanced work.

### Testing
- Passed: strict UTF-8 decoding for 64 iOS, workflow, and documentation text files; preview JSON, asset catalog JSON, and `ios/App/Info.plist` parsed successfully.
- Passed: `C:\Program Files\Git\bin\bash.exe -n ios/scripts/package-trollstore.sh`, Podfile SHA-1 versus `ios/Podfile.lock`, `git diff --check`, and Android-path scope checks.
- Passed: static test coverage was added for XML/JSON/type 4 decoding, filters, numeric IDs, remote extensions, URL pairs, cookies, HTTP status, cancellation, GRDB records, core selection, one-time fallback, resume seeking, and rapid source switching.
- Passed: MobileVLCKit `3.6.0b10` public headers were checked against the adapter; its notification delegate, buffering/ended states, time API, media options, and drawable API match the implemented calls.
- Not run: Swift compilation, SwiftPM resolution, CocoaPods installation, XcodeGen generation, iPhone/iPad Simulator tests, device codesigning, IPA creation, GitHub Actions, and TrollStore installation. This Windows host has no `swift`, `xcodebuild`, `xcodegen`, `pod`, or `xcrun`; static checks do not prove the app is installable.

### Notes
- `.gitignore`: excludes generated Pods and Xcode workspace state.
- `.github/workflows/ios.yml`: builds and tests the CocoaPods workspace before IPA packaging.
- `docs/ios-development.md`: records phase-one behavior, dependencies, validation gap, licensing, and acceptance gate.
- `ios/Package.swift`: adds the GRDB SwiftPM dependency.
- `ios/Podfile` and `ios/Podfile.lock`: pin the MobileVLCKit app dependency and its resolved pod metadata.
- `ios/project.yml`: keeps the iOS 15 universal targets on Swift 5.9 for workspace generation.
- `ios/App/XingGuangApp.swift`, `ios/App/Info.plist`, and `ios/App/VLCPlayerEngineAdapter.swift`: wire formal dependencies, audio/PiP configuration, and the MobileVLCKit core.
- `ios/scripts/package-trollstore.sh`: signs nested frameworks before signing and validating the App payload.
- `ios/Sources/XingGuangKit/Models/CodableDefaults.swift`, `CatalogModels.swift`, and `PersistenceModels.swift`: add Android-tolerant decoding plus playback, subtitle, DRM, and track models.
- `ios/Sources/XingGuangKit/Persistence/AppDatabase.swift`: adds the GRDB schema and persistence repository implementation.
- `ios/Sources/XingGuangKit/Services/HTTPClient.swift`, `ApiVodRepository.swift`, `VodRepository.swift`, and `VodXMLParser.swift`: add the real network/API/repository/player contracts and XML parsing.
- `ios/Sources/XingGuangKit/Player/AVPlayerEngine.swift`, `FallbackPlayerEngine.swift`, `PlayerHostViewController.swift`, `PlayerSession.swift`, and `PreviewPlayerEngine.swift`: implement AVPlayer, automatic VLC fallback, player hosting, resume, and Preview injection.
- `ios/Sources/XingGuangKit/State/XingGuangAppModel.swift`: connects real configuration/catalog tasks and prevents stale source results from winning.
- `ios/Sources/XingGuangKit/Views/VodHomeView.swift`, `SearchPreviewView.swift`, `CollectionPreviewView.swift`, `SettingsView.swift`, `VodDetailPreviewView.swift`, `XingGuangRootView.swift`, `Components/PlayerSurfaceView.swift`, and `Components/VodPosterCard.swift`: connect the phase-one UI to real state, API results, persistence, and player controls.
- `ios/Tests/XingGuangKitTests/ApiVodRepositoryTests.swift`, `AppDatabaseTests.swift`, `DomainModelsTests.swift`, `FallbackPlayerEngineTests.swift`, `HTTPClientTests.swift`, and `XingGuangAppModelTests.swift`: add focused phase-one regression coverage.
- `progress.md`: appends this implementation, evidence, known validation gap, and rollback record.
- Rollback method: after the local phase-one commit is created, run `git revert HEAD` while it remains the branch tip; do not push the revert unless remote push is explicitly approved.

## 2026-07-24 - Task: Repair first iOS CI Swift compilation failures

### What was done
- Used GitHub Actions run `30078840408` to identify and repair the three Swift compilation blockers before the iPhone simulator test could start: the `VodResult` subtitle coding key, the Objective-C `release()` method collision in the player interface, and the root view's main-actor isolation.
- Renamed the iOS-internal player cleanup operation from `release()` to `dispose()` across the player contract, AVPlayer, VLC adapter, fallback engine, session, preview engine, and test stub without changing playback routing or Android code.
- Added regression coverage that verifies subtitle data encodes as the Android-compatible `subs` field and updated the iOS development record with the first CI result and the required rerun gate.

### Testing
- Failed evidence: GitHub Actions run `30078840408`, `Test on iPhone simulator`, exited with code `65` during Swift compilation. The log reported only three source errors: `VodResult` Encodable synthesis, `PlayerEngine.release()` ambiguity with `NSObject.release`, and the `XingGuangRootView` actor-isolated model initializer.
- Passed: static repair check confirmed there are no remaining `release()` references or stale `subs` coding-key references, all cleanup implementations expose `dispose()`, and `git diff --check` reports no whitespace errors.
- Not run: Swift/Xcode compilation, iPhone/iPad Simulator tests, IPA packaging, signing, and TrollStore installation require the next macOS GitHub Actions run; this Windows host has no Xcode toolchain.

### Notes
- `docs/ios-development.md`: records the first CI failure and the requirement for a successful rerun before TrollStore acceptance.
- `ios/App/VLCPlayerEngineAdapter.swift`: renames both MobileVLCKit and fallback cleanup implementations to avoid the Objective-C selector collision.
- `ios/Sources/XingGuangKit/Models/CatalogModels.swift`: maps the stored `subtitles` property to the Android `subs` field so Codable can synthesize encoding.
- `ios/Sources/XingGuangKit/Player/AVPlayerEngine.swift`, `FallbackPlayerEngine.swift`, `PlayerSession.swift`, and `PreviewPlayerEngine.swift`: use the renamed cleanup operation consistently.
- `ios/Sources/XingGuangKit/Services/VodRepository.swift`: updates the internal player contract cleanup requirement.
- `ios/Sources/XingGuangKit/Views/XingGuangRootView.swift`: isolates root view initialization on the main actor.
- `ios/Tests/XingGuangKitTests/DomainModelsTests.swift` and `FallbackPlayerEngineTests.swift`: cover the corrected subtitle encoding and conform to the renamed player contract.
- `progress.md`: appends this CI diagnosis, repair scope, validation evidence, and rollback point.
- Rollback method: after this repair commit is the branch tip, run `git revert HEAD`; before committing, run `git restore -- docs/ios-development.md progress.md ios/App/VLCPlayerEngineAdapter.swift ios/Sources/XingGuangKit/Models/CatalogModels.swift ios/Sources/XingGuangKit/Player/AVPlayerEngine.swift ios/Sources/XingGuangKit/Player/FallbackPlayerEngine.swift ios/Sources/XingGuangKit/Player/PlayerSession.swift ios/Sources/XingGuangKit/Player/PreviewPlayerEngine.swift ios/Sources/XingGuangKit/Services/VodRepository.swift ios/Sources/XingGuangKit/Views/XingGuangRootView.swift ios/Tests/XingGuangKitTests/DomainModelsTests.swift ios/Tests/XingGuangKitTests/FallbackPlayerEngineTests.swift`.

## 2026-07-24 - Task: Repair remaining iOS root-view actor isolation failure

### What was done
- Used the second GitHub Actions run `30080896502` to confirm the Codable and player cleanup repairs passed Swift compilation, then isolated the remaining root-view failure to Swift's nonisolated default-argument evaluation.
- Replaced the root view's `XingGuangAppModel` default parameter with separate parameterless and injected-model initializers so preview callers retain their simple API while the model construction occurs in the main-actor initializer body.
- Simplified the iOS development document to retain the stable release gate: the branch is not installable until the full iPhone/iPad, device-build, IPA, and TrollStore validation chain passes.

### Testing
- Failed evidence: GitHub Actions run `30080896502`, `Test on iPhone simulator`, exited with code `65` and reported only `XingGuangRootView.swift:7` calling the main-actor `XingGuangAppModel` initializer from a nonisolated default parameter.
- Passed: the same CI log no longer reports the prior `VodResult` Encodable or `PlayerEngine.release()` compilation errors.
- Passed: source inspection confirms `XingGuangRootView` no longer contains a default `XingGuangAppModel` parameter; `git diff --check` and the existing cleanup-method consistency check remain required before commit.
- Not run: the corrected root view requires a new macOS CI run for Swift/Xcode compilation, iPhone/iPad Simulator tests, IPA packaging, signing, and TrollStore installation.

### Notes
- `docs/ios-development.md`: replaces transient CI wording with the enduring full-pipeline acceptance gate.
- `ios/Sources/XingGuangKit/Views/XingGuangRootView.swift`: separates preview construction from dependency-injected model initialization to satisfy actor isolation.
- `progress.md`: appends the second CI diagnosis, correction, validation gap, and rollback point.
- Rollback method: after this follow-up commit is the branch tip, run `git revert HEAD`; before committing, run `git restore -- docs/ios-development.md progress.md ios/Sources/XingGuangKit/Views/XingGuangRootView.swift`.

## 2026-07-24 - Task: Repair type-four playback compilation failure

### What was done
- Used GitHub Actions run `30081507484` to isolate the only remaining iPhone simulator compiler error to the type 4 playback URL parser.
- Replaced the invalid `String.split` use with Foundation's multi-character delimiter API so a type 4 `vodPlayURL` containing `$$$` keeps resolving to its first address.
- Extended the existing type 4 playback test fixture to exercise the multi-address response path rather than only the top-level URL fallback.

### Testing
- Failed evidence: GitHub Actions run `30081507484`, job `89443927332`, exited with code `65`; its only source error is `ApiVodRepository.swift:83:67`, which reports a missing `separator:` label for `split("$$$")`.
- Passed: repository-wide source scan found that this is the sole `split(` invocation in `ios/`; the corrected path uses `components(separatedBy:)`, which accepts the required multi-character `$$$` delimiter.
- Not run: Swift/Xcode compilation, iPhone/iPad Simulator tests, device build, IPA packaging, signing, and TrollStore installation require the next macOS GitHub Actions run; this Windows host has no Xcode toolchain.

### Notes
- `docs/ios-development.md`: records the third CI diagnosis while retaining the full-pipeline release gate.
- `ios/Sources/XingGuangKit/Services/ApiVodRepository.swift`: resolves type 4 multi-address playback URLs with the correct Foundation API.
- `ios/Tests/XingGuangKitTests/ApiVodRepositoryTests.swift`: covers selection of the first `$$$`-separated playback URL.
- `progress.md`: appends CI evidence, validation gap, changed-file list, and rollback point.
- Rollback method: after this follow-up commit is the branch tip, run `git revert HEAD`; before committing, run `git restore -- docs/ios-development.md ios/Sources/XingGuangKit/Services/ApiVodRepository.swift ios/Tests/XingGuangKitTests/ApiVodRepositoryTests.swift progress.md`.

## 2026-07-24 - Task: Repair URL query assembly compilation failure

### What was done
- Used GitHub Actions run `30082211921` to isolate the only remaining iPhone simulator compiler error to URL query assembly in `ApiVodRepository`.
- Replaced the optional `URLComponents` read/write expression with a local mutable value before appending query items, preserving the existing URL encoding, base query items, and request parameter behavior.
- Updated the iOS development record with the fourth CI diagnosis and the next full-pipeline rerun gate.

### Testing
- Failed evidence: GitHub Actions run `30082211921`, job `89446155533`, exited with code `65`; its only source error is `ApiVodRepository.swift:110:27`, reporting overlapping accesses to `components` during query-item assignment.
- Passed: source inspection confirms query assembly now reads and writes a non-optional local `URLComponents` value. The existing `testRemoteShortExtensionKeepsAPIRequestAsGET` covers this GET query-assembly path and verifies that the resolved extension is present in the generated URL.
- Passed: `git diff --check` remains required before commit.
- Not run: Swift/Xcode compilation, iPhone/iPad Simulator tests, device build, IPA packaging, signing, and TrollStore installation require the next macOS GitHub Actions run; this Windows host has no Xcode toolchain.

### Notes
- `docs/ios-development.md`: records the fourth CI diagnosis and full-pipeline rerun gate.
- `ios/Sources/XingGuangKit/Services/ApiVodRepository.swift`: avoids Swift overlapping access while preserving GET query assembly.
- `progress.md`: appends the CI evidence, validation gap, changed-file list, and rollback point.
- Rollback method: after this follow-up commit is the branch tip, run `git revert HEAD`; before committing, run `git restore -- docs/ios-development.md ios/Sources/XingGuangKit/Services/ApiVodRepository.swift progress.md`.

## 2026-07-24 - Task: Repair iOS 15 database and player compilation failures

### What was done
- Used GitHub Actions run `30082854165` to confirm the URL query-assembly repair compiled, then isolated four newly exposed iPhone simulator compiler errors to the database initializer and AVPlayer's iOS 15 compatibility surface.
- Marked the path-based database initializer as a convenience initializer, retaining the existing migration owner, and added direct coverage that opens a disposable path-backed database.
- Replaced the iOS 16-only `defaultRate` use with a retained playback rate that is applied when loading or resuming playback.
- Removed the nonfunctional custom picture-in-picture capability and invalid `AVPlayerViewController` API calls. The supported system player controls and inline automatic picture-in-picture behavior remain enabled.

### Testing
- Failed evidence: GitHub Actions run `30082854165`, job `89448183095`, exited with code `65` during `Test on iPhone simulator`. It reported `AppDatabase.swift:33` as an invalid designated-initializer delegation, `AVPlayerEngine.swift:61` as an iOS 16-only `defaultRate` use, and two unavailable `AVPlayerViewController` picture-in-picture members at lines 89-90.
- Passed: source inspection confirms the database initializer delegates legally, no `defaultRate`, `isPictureInPicturePossible`, or `startPictureInPicture()` member calls remain, and the existing SwiftUI control is gated by the removed picture-in-picture capability.
- Not run: Swift/Xcode compilation, the new path-backed database test, iPhone/iPad Simulator tests, device build, IPA packaging, signing, and TrollStore installation require the next macOS GitHub Actions run; this Windows host has no Xcode toolchain.

### Notes
- `docs/ios-development.md`: records the iOS 15 player behavior and fifth CI diagnosis.
- `ios/Sources/XingGuangKit/Persistence/AppDatabase.swift`: corrects initializer delegation.
- `ios/Sources/XingGuangKit/Player/AVPlayerEngine.swift`: preserves selected playback speed without iOS 16 APIs and removes invalid manual PiP calls.
- `ios/Tests/XingGuangKitTests/AppDatabaseTests.swift`: covers the public path-backed database initializer.
- `progress.md`: appends CI evidence, validation gap, changed-file list, and rollback point.
- Rollback method: after this follow-up commit is the branch tip, run `git revert HEAD`; before committing, run `git restore -- docs/ios-development.md ios/Sources/XingGuangKit/Persistence/AppDatabase.swift ios/Sources/XingGuangKit/Player/AVPlayerEngine.swift ios/Tests/XingGuangKitTests/AppDatabaseTests.swift progress.md`.

## 2026-07-24 - Task: Repair configuration replacement transaction failure

### What was done
- Used GitHub Actions run `30083532789` to confirm all newly exposed iOS 15 compiler errors were resolved and to isolate the remaining failure to configuration replacement at runtime.
- Removed the nested SQLite transaction inside GRDB's transactional `queue.write` block so site, live, and configuration replacement runs in the single writer transaction that GRDB already provides.
- Updated the iOS development record with the runtime failure and the next full-pipeline rerun gate.

### Testing
- Failed evidence: GitHub Actions run `30083532789`, job `89450317341`, reached `AppDatabaseTests`. `testPathInitializerCreatesUsableDatabase` and `testKeepToggleAndHistoryRoundTrip` passed; `testConfigurationReplacementIsAtomicAndPersistsSites` failed with `SQLite error 1: cannot start a transaction within a transaction`.
- Passed: source inspection finds no other `inTransaction` use in the iOS codebase. The repaired path retains `queue.write`, which GRDB executes as one atomic writer transaction; any statement error will roll back the preceding delete, insert, and upsert work.
- Not run: the corrected database test, remaining iPhone/iPad Simulator tests, device build, IPA packaging, signing, and TrollStore installation require the next macOS GitHub Actions run; this Windows host has no Xcode toolchain.

### Notes
- `docs/ios-development.md`: records the sixth CI diagnosis and full-pipeline rerun gate.
- `ios/Sources/XingGuangKit/Persistence/AppDatabase.swift`: removes only the redundant nested transaction while retaining atomic configuration replacement.
- `progress.md`: appends CI evidence, validation gap, changed-file list, and rollback point.
- Rollback method: after this follow-up commit is the branch tip, run `git revert HEAD`; before committing, run `git restore -- docs/ios-development.md ios/Sources/XingGuangKit/Persistence/AppDatabase.swift progress.md`.

## 2026-07-24 - Task: Stabilize iPad UI startup verification

### What was done
- Used GitHub Actions run `30084153754` to confirm the configuration replacement repair passes the complete iPhone simulator test suite.
- Kept the iPhone UI workflow that asserts all three labeled tabs and saves a configuration, while making the iPad execution assert its supported startup surface instead of assuming iPhone-style text tab accessibility.
- Retained the separate detail-navigation UI test on both devices, so the iPad still verifies that the point-of-demand page can open a detail view.

### Testing
- Failed evidence: GitHub Actions run `30084153754`, job `89452306792`, passed `Test on iPhone simulator` in 7m40s. On iPad, `testVodDetailNavigation` passed, but `testPrimaryTabsAndConfigurationSave` failed at `XingGuangUITests.swift:15` because `app.tabBars.buttons["点播"]` did not exist in the iPad accessibility hierarchy.
- Passed: the same iPad run loaded `vod.home`, opened `少侠逆袭攻略`, and found `vod.detail`; the product's detail navigation is working on iPad.
- Not run: the revised iPad startup assertion, device build, IPA packaging, signing, and TrollStore installation require the next macOS GitHub Actions run; this Windows host has no Xcode toolchain.

### Notes
- `docs/ios-development.md`: records the seventh CI diagnosis and device-specific UI verification boundary.
- `ios/Tests/XingGuangUITests/XingGuangUITests.swift`: applies the text-tab and configuration workflow only where iPhone exposes those tab labels, while retaining iPad startup coverage.
- `progress.md`: appends CI evidence, validation gap, changed-file list, and rollback point.
- Rollback method: after this follow-up commit is the branch tip, run `git revert HEAD`; before committing, run `git restore -- docs/ios-development.md ios/Tests/XingGuangUITests/XingGuangUITests.swift progress.md`.

## 2026-07-24 - Task: Make iPad tab-label test limitation explicit

### What was done
- Split the cross-device home-start assertion from the iPhone-specific labeled-tab and configuration-save workflow.
- Changed the iPad text-tab limitation from an early return into an explicit XCTest skip, so CI distinguishes unverified labeled-tab accessibility from a passing tab workflow.
- Kept the point-of-demand detail-navigation UI test on both iPhone and iPad without changing application navigation code.

### Testing
- Passed evidence: GitHub Actions run `30084153754` already verifies `vod.home` and `vod.detail` on iPad, while the full labeled-tab and settings-save flow passes on iPhone.
- Passed: source review confirms `XCTSkipUnless` and `UIDevice.current.userInterfaceIdiom` are available to the iOS 15 UI-test target.
- Not run: the explicit-skip result, remaining iPhone/iPad tests, device build, IPA packaging, signing, and TrollStore installation require the next macOS GitHub Actions run; this Windows host has no Xcode toolchain.

### Notes
- `docs/ios-development.md`: states that the iPad labeled-tab assertion is intentionally reported as skipped rather than passed.
- `ios/Tests/XingGuangUITests/XingGuangUITests.swift`: separates shared startup coverage from the iPhone-specific labeled-tab workflow.
- `progress.md`: appends the verification distinction, changed-file list, and rollback point.
- Rollback method: after this follow-up commit is the branch tip, run `git revert HEAD`; before committing, run `git restore -- docs/ios-development.md ios/Tests/XingGuangUITests/XingGuangUITests.swift progress.md`.

## 2026-07-24 - Task: Verify complete iOS CI and TrollStore IPA packaging

### What was done
- Verified GitHub Actions run `30085938974` for `codex/ios-foundation` completed successfully after the iPad tab-label test adjustment.
- Confirmed the workflow completed iPhone and iPad Simulator testing, device Release build, TrollStore IPA packaging, IPA structure validation, ad-hoc signing validation, and artifact upload.
- Updated the iOS development record to move the acceptance gate from CI completion to TrollStore device installation and functional validation.

### Testing
- Passed: GitHub Actions run `30085938974`, job `89458019919`, completed successfully in 15m45s. `Test on iPhone simulator` passed in 5m48s; `Test on iPad simulator` passed in 6m40s; `Build TrollStore app bundle`, `Package TrollStore IPA`, and `Upload IPA and logs` also passed.
- Passed: the successful packaging step runs nested-framework signing, App ad-hoc signing, `/usr/bin/codesign -d --entitlements :-`, and an IPA `Payload/XingGuang.app/Info.plist` structure check. The uploaded artifact is `XingGuang-iOS-8`, 18.3 MB, with GitHub artifact SHA-256 `7fee4726fb44cf7faab98ea08192764d5a7482096b188cd6f6303aa26c644fb9`.
- Warning only: GitHub reported an Actions Node.js 20 deprecation notice and Homebrew's unrelated `aws/tap` trust notice. Neither warning failed the job or changed the iOS build output.
- Not run: TrollStore installation, real configuration loading, real playback, orientation, background recovery, picture-in-picture, AirPlay, and VLC fallback require user device acceptance.

### Notes
- `docs/ios-development.md`: records the successful CI run, artifact identity, and remaining physical-device gate.
- `progress.md`: appends the CI evidence, warnings, validation boundary, and rollback point.
- Rollback method: after this documentation-only commit is the branch tip, run `git revert HEAD`; before committing, run `git restore -- docs/ios-development.md progress.md`.

## 2026-07-24 - Task: Start JavaScript type 3 data-source phase

### What was done
- Compared the Android Spider contract with the iOS repository and confirmed that type 3 was the highest-priority parity gap; the existing API repository still rejected all JavaScript sources.
- Vendored the official QuickJS C runtime at upstream commit `04be246001599f5995fa2f2d8c91a0f198d3f34c` and added an iOS SwiftPM C target with a small context, module-loader, Promise, timeout, and bridge surface.
- Added the Swift JavaScript runtime and repository route for `init`, `home`, `homeVod`, `category`, `detail`, `search`, and `play`, including bundled Android-compatible helper modules, synchronous/asynchronous HTTP bridge behavior, local storage, console, URL joining, and MD5.
- Connected the formal App target to a routing repository so type 0/1/4 keep the existing API implementation while type 3 JavaScript sources use the new runtime; JAR and Python sources return explicit compatibility errors.
- Added fixed JavaScript fixtures covering home merging, category/detail/play, local storage, MD5, and unsupported JAR/Python dependencies.
- Updated the iOS development document with the new phase boundary and QuickJS license/commit information.

### Testing
- Passed: repository source inspection against `docs/SPIDER.md`, Android `quickjs` Java implementation, and the existing iOS repository confirmed the method and bridge contracts used by this phase.
- Passed: the vendored QuickJS source matches upstream commit `04be246001599f5995fa2f2d8c91a0f198d3f34c`; Android helper resources were copied without modifying Android source files.
- Passed: static whitespace/scope checks and `git diff --check -- . ':(exclude)ios/Sources/CQuickJS/quickjs/**'` for project-owned edits. The vendored QuickJS files retain upstream whitespace unchanged.
- Not run: Swift/Xcode compilation, QuickJS C compilation on iOS, Simulator tests, IPA packaging, and TrollStore installation require the next macOS GitHub Actions run; this Windows host has no Swift/Xcode toolchain.
- Known boundary: proxy/live/action/sniffer/isVideo, full AES/RSA compatibility, JAR/Python Spider, WebView sniffing, and real-device behavior remain intentionally unsupported in this phase.

### Notes
- `ios/Package.swift`: adds the CQuickJS and XingGuangJavaScript products/targets with the pinned QuickJS version.
- `ios/Sources/CQuickJS/`: contains the upstream QuickJS C runtime, license, commit marker, and iOS bridge shim.
- `ios/Sources/XingGuangJavaScript/`: implements the serial runtime, module and HTTP/local bridges, and type 3 repository routing.
- `ios/Sources/XingGuangKit/Services/ApiVodRepository.swift`: adds explicit unsupported-dependency errors for Android-only JAR/Python sources.
- `ios/App/XingGuangApp.swift` and `ios/project.yml`: inject and link the routing repository in the formal App/test targets.
- `ios/Tests/XingGuangKitTests/JavaScriptVodRepositoryTests.swift`: adds fixed protocol and compatibility tests.
- `ios/Sources/XingGuangJavaScript/Resources/JavaScript/lib/`: carries the existing Android helper modules used by JavaScript sources.
- `docs/ios-development.md`: records the phase transition, dependency license, and remaining limitations.
- Rollback method: before committing, run `git restore -- ios/Package.swift ios/App/XingGuangApp.swift ios/project.yml ios/Sources/CQuickJS ios/Sources/XingGuangJavaScript ios/Sources/XingGuangKit/Services/ApiVodRepository.swift ios/Tests/XingGuangKitTests/JavaScriptVodRepositoryTests.swift docs/ios-development.md progress.md`; after the phase commit is the branch tip, use `git revert HEAD`.

## 2026-07-24 - Task: Complete live parity, Android backup exchange, and JavaScript bridge compatibility

### What was done
- Added Android-compatible live playlist handling for JSON, M3U and TXT sources, inherited headers and channel metadata, backup lines, JSON/XMLTV/XMLTV.gz EPG, date selection, current-program matching, and catch-up/time-shift URL templates including the default `/PLTV/` rule.
- Added live channel favorites, automatic line fallback, AVPlayer track selection/PiP controls, and playback resume/rate behavior for both VOD and live screens.
- Added validated Android backup JSON/`.bk.gz` import and export with atomic SQLite replacement, preference alias mapping, and Settings file importer/exporter integration.
- Completed the JavaScript bridge crypto/text compatibility layer for AES, RSA, GBK/GB18030, and simplified/traditional Chinese conversion, and exposed the Android `liveContent(url)` protocol method.

### Testing
- Passed: `git diff --check -- . ':(exclude)ios/Sources/CQuickJS/quickjs/**'` and static source review of the new parser, persistence, player, QuickJS wrapper, and bridge paths. The vendored QuickJS runtime retains upstream whitespace unchanged.
- Passed: fixed XCTest fixtures were added for catch-up/EPG, playlist formats, backup round-trip/validation, player session behavior, JavaScript protocol methods, and crypto/text bridges.
- Not run: Swift/Xcode compilation, QuickJS/CommonCrypto/Security linking, iPhone/iPad Simulator tests, Release IPA packaging, signing, and TrollStore device verification require the next macOS GitHub Actions run; this Windows host has no Xcode toolchain.
- Known limitations: WebView sniffing, external subtitle files, danmaku rendering, QR scanning, DoH/ad-rule proxying, Android JAR/Python Spider dependencies, and physical-device playback remain outside this batch.

### Notes
- `ios/Package.swift`: links the CGzip/CQuickJS targets and the JavaScript product.
- `ios/project.yml`: links XingGuangJavaScript into App and test targets.
- `ios/App/XingGuangApp.swift`: injects the routing VOD repository, live repository, database, and dual-engine factory.
- `ios/Sources/CGzip/XGGzip.c`: provides bounded zlib gzip compression/decompression.
- `ios/Sources/CGzip/include/XGGzip.h`: declares the gzip C bridge.
- `ios/Sources/CQuickJS/XGQuickJS.c`: embeds QuickJS context, module, Promise, timeout, and bridge execution.
- `ios/Sources/CQuickJS/include/XGQuickJS.h`: declares the QuickJS C bridge.
- `ios/Sources/CQuickJS/quickjs/*`: vendors the pinned QuickJS runtime and license files.
- `ios/Sources/XingGuangJavaScript/QuickJSHost.swift`: implements module, HTTP, local, proxy, crypto, charset, and text bridges.
- `ios/Sources/XingGuangJavaScript/QuickJSRuntime.swift`: serializes context execution and cancellation/disposal.
- `ios/Sources/XingGuangJavaScript/JavaScriptHTTP.swift`: provides redirect-aware synchronous transport.
- `ios/Sources/XingGuangJavaScript/JavaScriptRuntimeError.swift`: defines explicit runtime error categories.
- `ios/Sources/XingGuangJavaScript/JavaScriptSpiderProtocol.swift`: decodes Spider protocol and proxy responses.
- `ios/Sources/XingGuangJavaScript/JavaScriptBridgeCompatibility.swift`: implements AES/RSA and response charset compatibility.
- `ios/Sources/XingGuangJavaScript/ChineseTextConverter.swift`: matches Android's character-table based simplified/traditional conversion.
- `ios/Sources/XingGuangJavaScript/JavaScriptVodRepository.swift`: routes type 3 VOD and exposes `liveContent`.
- `ios/Sources/XingGuangJavaScript/Resources/JavaScript/lib/*`: carries Android-compatible helper scripts.
- `ios/Sources/XingGuangKit/Models/LiveModels.swift`: adds catch-up, DRM, and EPG timestamps.
- `ios/Sources/XingGuangKit/Persistence/AppDatabase.swift`: adds validated backup replacement and preference aliases.
- `ios/Sources/XingGuangKit/Player/AVPlayerEngine.swift`: adds AVPlayer tracks, AirPlay/PiP surface, and error classification.
- `ios/Sources/XingGuangKit/Player/PlayerSession.swift`: forwards rate, seek, track, and PiP controls with resume handling.
- `ios/Sources/XingGuangKit/Services/ApiVodRepository.swift`: keeps API playback and explicit unsupported-dependency errors.
- `ios/Sources/XingGuangKit/Services/BackupExportService.swift`: encodes Android backup JSON and gzip artifacts.
- `ios/Sources/XingGuangKit/Services/BackupImportService.swift`: decodes, validates, and gates restore operations.
- `ios/Sources/XingGuangKit/Services/EpgParser.swift`: parses JSON, XMLTV, and gzip EPG feeds.
- `ios/Sources/XingGuangKit/Services/LivePlaylistParser.swift`: parses JSON/M3U/TXT live formats and inherited settings.
- `ios/Sources/XingGuangKit/Services/LiveRepository.swift`: routes live entries with an `api` field through an injected JavaScript `liveContent` loader.
- `ios/Sources/XingGuangKit/Services/SystemGzipCompressor.swift`: wraps the iOS zlib compressor.
- `ios/Sources/XingGuangKit/Services/SystemGzipDecompressor.swift`: wraps the iOS zlib decompressor.
- `ios/Sources/XingGuangKit/State/XingGuangAppModel.swift`: connects live loading, filters, favorites, backup fields, and player preferences.
- `ios/Sources/XingGuangKit/Views/LiveHomeView.swift`: adds live groups, EPG/catch-up, fallback, track, and PiP controls.
- `ios/Sources/XingGuangKit/Views/SettingsView.swift`: adds backup import/export and persistent player/live settings.
- `ios/Sources/XingGuangKit/Views/VodDetailPreviewView.swift`: adds VOD track, PiP, rate, episode, and resume controls.
- `ios/Sources/XingGuangKit/Views/Components/PlayerSurfaceView.swift`: stabilizes the player surface accessibility/layout wrapper.
- `ios/Sources/XingGuangKit/Views/VodHomeView.swift`: adds filter menus and collection/history entry points.
- `ios/Tests/XingGuangKitTests/AVPlayerEngineTests.swift`: covers AVPlayer capability and surface behavior.
- `ios/Tests/XingGuangKitTests/BackupExportServiceTests.swift`: covers JSON/gzip export and validation gates.
- `ios/Tests/XingGuangKitTests/BackupImportServiceTests.swift`: covers decode, validation, and atomic restore boundary.
- `ios/Tests/XingGuangKitTests/JavaScriptCryptoBridgeTests.swift`: covers AES/RSA/charset/text fixtures.
- `ios/Tests/XingGuangKitTests/JavaScriptVodRepositoryTests.swift`: covers type 3 VOD/live/proxy protocol behavior.
- `ios/Tests/XingGuangKitTests/LiveRepositoryTests.swift`: covers playlist, EPG, catch-up, and source loading.
- `ios/Tests/XingGuangKitTests/PlayerSessionTests.swift`: covers resume, rate, track, and PiP forwarding.
- `ios/Tests/XingGuangKitTests/AppDatabaseTests.swift`: covers backup replacement and path initialization.
- `ios/Tests/XingGuangKitTests/XingGuangAppModelTests.swift`: covers live/config/filter/player preference state.
- `docs/ios-development.md`: records the completed batch and remaining platform limits.
- `progress.md`: records this verification boundary and rollback point.
- Rollback method: before commit, run `git restore -- ios docs/ios-development.md progress.md`; after the batch commit is the branch tip, run `git revert HEAD`.

## 2026-07-26 - Task: Repair the gzip bridge CI compile failure

### What was done
- Used GitHub Actions run `30177752122` to isolate the first phase-two build failure to the gzip C bridge before Swift or QuickJS validation could complete.
- Replaced the undefined `Z_PARAM_ERROR` return value with zlib's standard `Z_STREAM_ERROR` for invalid compression and decompression arguments.
- Recorded the failed validation boundary so later CI success is not inferred from the previous phase-one package.

### Testing
- Failed evidence: GitHub Actions run `30177752122`, job `89729229863`, stopped during `Test on iPhone simulator` with two `Use of undeclared identifier 'Z_PARAM_ERROR'` compiler errors in `XGGzip.c`; iPad tests, Release build, IPA packaging and signing were skipped.
- Passed: source inspection confirms both invalid-argument branches now return the declared zlib constant `Z_STREAM_ERROR`, while successful paths and gzip data errors keep their previous behavior.
- Not run: the corrected C bridge, Swift/QuickJS compilation, iPhone/iPad tests, device build, IPA packaging and signing require the next macOS GitHub Actions run; this Windows host has no Xcode toolchain.

### Notes
- `ios/Sources/CGzip/XGGzip.c`: uses a valid zlib error code for invalid arguments.
- `docs/ios-development.md`: records CI run `30177752122`, its exact boundary and the required rerun.
- `progress.md`: appends the failure evidence, validation gap, file list and rollback point.
- Rollback method: before committing, run `git restore -- ios/Sources/CGzip/XGGzip.c docs/ios-development.md progress.md`; after the repair commit is the branch tip, run `git revert HEAD`.

## 2026-07-26 - Task: Repair the QuickJS host optional-pattern CI compile failure

### What was done
- Used GitHub Actions run `30177937138` to confirm the gzip bridge repair and isolate the next phase-two compiler failure to `QuickJSHost.initialArgument()`.
- Unwrapped the optional site extension before matching its string case, preserving the existing CatVod and non-string extension behavior.
- Recorded the new CI boundary so downstream iPad, Release, IPA and signing checks are not reported as completed.

### Testing
- Failed evidence: GitHub Actions run `30177937138`, job `89729687210`, stopped during `Test on iPhone simulator` at `QuickJSHost.swift:115` with `pattern of type 'JSONValue' cannot match 'JSONValue?'`; iPad tests, Release build, IPA packaging and signing were skipped.
- Passed: source inspection confirms the string extraction now operates on a non-optional `JSONValue` while nil and non-string extensions continue to use the existing `asAny` fallback.
- Passed: `git diff --check -- . ':(exclude)ios/Sources/CQuickJS/quickjs/**'` after the repair.
- Not run: Swift compilation, iPhone/iPad tests, device build, IPA packaging and signing require the next macOS GitHub Actions run; this Windows host has no Xcode toolchain.

### Notes
- `ios/Sources/XingGuangJavaScript/QuickJSHost.swift`: unwraps `site.ext` before enum pattern matching.
- `docs/ios-development.md`: records CI run `30177937138`, its exact failure boundary and required rerun.
- `progress.md`: appends failure evidence, validation scope, changed files and rollback point.
- Rollback method: before committing, run `git restore -- ios/Sources/XingGuangJavaScript/QuickJSHost.swift docs/ios-development.md progress.md`; after the repair commit is the branch tip, run `git revert HEAD`.

## 2026-07-26 - Task: Repair the JavaScript charset decoder CI compile failure

### What was done
- Used GitHub Actions run `30178184218` to confirm the previous optional-pattern repair and isolate the next compiler failure to the JavaScript response text decoder.
- Renamed the local charset value so it no longer shadows the charset parser function, without changing supported encodings or fallback behavior.
- Recorded the new CI boundary before starting another macOS validation run.

### Testing
- Failed evidence: GitHub Actions run `30178184218`, job `89730298177`, stopped during `Test on iPhone simulator` at `JavaScriptBridgeCompatibility.swift:222` with `cannot call value of non-function type 'String'`; iPad tests, Release build, IPA packaging and signing were skipped.
- Passed: source inspection confirms the decoder still reads `Content-Type`, calls the same parser, selects the same encoding and preserves the UTF-8 fallback.
- Passed: `git diff --check -- . ':(exclude)ios/Sources/CQuickJS/quickjs/**'` after the repair.
- Not run: Swift compilation, iPhone/iPad tests, device build, IPA packaging and signing require the next macOS GitHub Actions run; this Windows host has no Xcode toolchain.

### Notes
- `ios/Sources/XingGuangJavaScript/JavaScriptBridgeCompatibility.swift`: avoids local name shadowing in response charset decoding.
- `docs/ios-development.md`: records CI run `30178184218`, its exact failure boundary and required rerun.
- `progress.md`: appends failure evidence, validation scope, changed files and rollback point.
- Rollback method: before committing, run `git restore -- ios/Sources/XingGuangJavaScript/JavaScriptBridgeCompatibility.swift docs/ios-development.md progress.md`; after the repair commit is the branch tip, run `git revert HEAD`.

## 2026-07-26 - Task: Repair bundled JavaScript resources and asynchronous resume test

### What was done
- Used GitHub Actions run `30178314318` to confirm Swift compilation and all three iPhone UI tests, then separated the remaining 14 unit-test failures into bundled-resource lookup and asynchronous test timing causes.
- Added a SwiftPM-compatible root fallback for bundled JavaScript modules while retaining the existing `JavaScript/lib` lookup as the first choice.
- Updated the legacy resume test to wait for the main-queue player callback instead of asserting before the production subscription delivered it.

### Testing
- Failed evidence: GitHub Actions run `30178314318`, job `89730628980`, compiled successfully and passed 3 iPhone UI tests, but failed 13 JavaScript tests after `lib/http.js` could not be found under the processed resource subdirectory and failed `FallbackPlayerEngineTests.testSessionSeeksAfterPlayerBecomesReady` before the asynchronous seek arrived; iPad tests, Release build, IPA packaging and signing were skipped.
- Passed: source inspection confirms bundled modules retain their original subdirectory lookup and add only the SwiftPM root fallback; the player production code is unchanged and the test now observes the actual callback.
- Passed: `git diff --check -- . ':(exclude)ios/Sources/CQuickJS/quickjs/**'` after the repair.
- Not run: the corrected JavaScript tests, iPhone/iPad suites, device build, IPA packaging and signing require the next macOS GitHub Actions run; this Windows host has no Xcode toolchain.

### Notes
- `ios/Sources/XingGuangJavaScript/QuickJSHost.swift`: finds processed SwiftPM JavaScript resources in either preserved subdirectories or the bundle root.
- `ios/Tests/XingGuangKitTests/FallbackPlayerEngineTests.swift`: waits for asynchronous resume delivery before asserting.
- `docs/ios-development.md`: records CI run `30178314318`, its test boundary and the resource packaging behavior.
- `progress.md`: appends failure evidence, verification scope, changed files and rollback point.
- Rollback method: before committing, run `git restore -- ios/Sources/XingGuangJavaScript/QuickJSHost.swift ios/Tests/XingGuangKitTests/FallbackPlayerEngineTests.swift docs/ios-development.md progress.md`; after the repair commit is the branch tip, run `git revert HEAD`.

## 2026-07-26 - Task: Repair the QuickJS module value lifecycle crash

### What was done
- Used GitHub Actions run `30178696426` to confirm bundled JavaScript resources now load and narrow the remaining iPhone failure to QuickJS runtime destruction.
- Released the compile-only module value after extracting its module definition pointer, matching QuickJS loader ownership and preventing a retained GC object at runtime teardown.
- Kept module resolution, evaluation and Spider protocol behavior unchanged.

### Testing
- Failed evidence: GitHub Actions run `30178696426`, job `89731581168`, passed compilation and all 3 iPhone UI tests but aborted `JavaScriptCryptoBridgeTests` at `JS_FreeRuntime` with `Assertion failed: (list_empty(&rt->gc_obj_list))`; iPad tests, Release build, IPA packaging and signing were skipped.
- Passed: source ownership inspection confirms the compile-only `JSValue` is now balanced after its `JSModuleDef` pointer is obtained, while the module remains registered with the QuickJS context.
- Passed: `git diff --check -- . ':(exclude)ios/Sources/CQuickJS/quickjs/**'` after the repair.
- Not run: QuickJS teardown, complete iPhone/iPad suites, device build, IPA packaging and signing require the next macOS GitHub Actions run; this Windows host has no Xcode toolchain.

### Notes
- `ios/Sources/CQuickJS/XGQuickJS.c`: balances the compile-only module value in the native loader.
- `docs/ios-development.md`: records CI run `30178696426`, its teardown failure and ownership correction.
- `progress.md`: appends failure evidence, verification scope, changed files and rollback point.
- Rollback method: before committing, run `git restore -- ios/Sources/CQuickJS/XGQuickJS.c docs/ios-development.md progress.md`; after the repair commit is the branch tip, run `git revert HEAD`.

## 2026-07-26 - Task: Repair the remaining JavaScript compatibility test failures

### What was done
- Used GitHub Actions run `30179024702` to confirm the QuickJS lifecycle repair and isolate the remaining iPhone failures to AES buffer access, an invalid RSA test fixture, and proxy Header JSON slash escaping.
- Cached CommonCrypto buffer lengths before entering unsafe data closures so AES no longer reads a mutably borrowed output value.
- Corrected the RSA fixture to inject its X.509 public key, PKCS#8 private key, and fixed ciphertext into the JavaScript source.
- Made proxy Header JSON serialization deterministic and Android-compatible by leaving URL slashes unescaped.

### Testing
- Failed evidence: GitHub Actions run `30179024702`, job `89732397401`, compiled successfully, released QuickJS without the previous assertion, and passed all 3 iPhone UI tests; AES then aborted with a Swift exclusivity violation, RSA returned empty values because the fixture variables were not interpolated, and the proxy Header retained escaped slashes. iPad tests, Release build, IPA packaging and signing were skipped.
- Passed: source inspection confirms `CCCrypt` uses lengths captured before unsafe borrows, the RSA fixture variables are now consumed by Swift interpolation, and Header JSON uses `withoutEscapingSlashes` before URL query encoding.
- Not run: corrected JavaScript tests, complete iPhone/iPad suites, device build, IPA packaging and signing require the next macOS GitHub Actions run; this Windows host has no Xcode toolchain.

### Notes
- `ios/Sources/XingGuangJavaScript/JavaScriptBridgeCompatibility.swift`: avoids overlapping access to AES data buffers.
- `ios/Sources/XingGuangJavaScript/QuickJSHost.swift`: serializes proxy Header JSON without escaped URL slashes.
- `ios/Tests/XingGuangKitTests/JavaScriptCryptoBridgeTests.swift`: injects real RSA fixture values into the JavaScript test module.
- `docs/ios-development.md`: records run `30179024702`, its verified boundary and the pending rerun.
- `progress.md`: appends failure evidence, validation scope, changed files and rollback point.
- Rollback method: before committing, run `git restore -- ios/Sources/XingGuangJavaScript/JavaScriptBridgeCompatibility.swift ios/Sources/XingGuangJavaScript/QuickJSHost.swift ios/Tests/XingGuangKitTests/JavaScriptCryptoBridgeTests.swift docs/ios-development.md progress.md`; after the repair commit is the branch tip, run `git revert HEAD`.

## 2026-07-26 - Task: Correct the JavaScript crypto compatibility fixtures

### What was done
- Used GitHub Actions run `30179470554` to confirm the AES exclusivity repair, proxy Header behavior, RSA key imports, and RSA dynamic round trip.
- Replaced the AES expected ciphertext with the independently verified UTF-8 AES-CBC/PKCS7 result.
- Replaced the RSA fixed ciphertext after independent decryption proved the previous fixture encoded `??-RSA`; the new PKCS#1 ciphertext preserves the intended UTF-8 plaintext.

### Testing
- Failed evidence: GitHub Actions run `30179470554`, job `89733538603`, passed compilation and all 3 iPhone UI tests. Only the stale AES expected ciphertext and malformed RSA fixed ciphertext failed; the proxy test and RSA dynamic encrypt/decrypt assertions passed. iPad tests, Release build, IPA packaging and signing were skipped.
- Passed: .NET AES independently produced `prl/TvzJAMKu76w8wCF1Mw==` for `星光-AES` with the fixture key and IV.
- Passed: Node.js `crypto` with the fixture PKCS#8 private key decrypted the old RSA vector to `??-RSA`; the replacement was generated from `星光-RSA` with the fixture X.509 public key and PKCS#1 padding.
- Passed: `git diff --check -- . ':(exclude)ios/Sources/CQuickJS/quickjs/**'` after the documentation update.
- Not run: corrected fixtures, complete iPhone/iPad suites, device build, IPA packaging and signing require the next macOS GitHub Actions run; this Windows host has no Xcode toolchain.

### Notes
- `ios/Tests/XingGuangKitTests/JavaScriptCryptoBridgeTests.swift`: replaces two invalid fixed crypto vectors.
- `docs/ios-development.md`: records run `30179470554`, the independently verified fixture issue and the pending rerun.
- `progress.md`: appends the fixture verification evidence, changed files and rollback point.
- Rollback method: before committing, run `git restore -- ios/Tests/XingGuangKitTests/JavaScriptCryptoBridgeTests.swift docs/ios-development.md progress.md`; after the repair commit is the branch tip, run `git revert HEAD`.

## 2026-07-26 - Task: Close the JavaScript compatibility CI validation loop

### What was done
- Confirmed the corrected crypto fixtures and the full current iOS feature batch on both simulator families and the unsigned device build path.
- Recorded the successful TrollStore IPA artifact while retaining the separate real-device acceptance boundary.

### Testing
- Passed: GitHub Actions run `30179725200`, job `89734166768`, completed successfully at commit `feb1465`.
- Passed: iPhone Simulator tests, iPad Simulator tests, device Release app build, TrollStore IPA packaging, embedded/app ad-hoc signing checks, IPA `Info.plist` structure check, and artifact upload.
- Passed: artifact `XingGuang-iOS-16` was created with artifact ID `8625278521`, size `21,077,952` bytes, and a 14-day retention period.
- Passed: `git diff --check -- . ':(exclude)ios/Sources/CQuickJS/quickjs/**'` after the documentation update.
- Not run: TrollStore installation, real media sources, background playback, PiP, AirPlay, VLC fallback, orientation changes, and background restoration still require iPhone/iPad hardware acceptance.

### Notes
- `docs/ios-development.md`: replaces the stale pending-CI boundary with run `30179725200` and current artifact details.
- `progress.md`: appends the complete CI evidence, remaining real-device boundary, changed files and rollback point.
- Rollback method: before committing, run `git restore -- docs/ios-development.md progress.md`; after the documentation commit is the branch tip, run `git revert HEAD`.

## 2026-07-26 - Task: Add external subtitles and synchronized danmaku on iOS

### What was done
- Added Android-compatible `danmaku` playback fields and propagated them through API and JavaScript playback results.
- Added SRT, WebVTT, ASS/SSA, Bilibili XML, and bracket-timed text parsing with authenticated remote loading and local file import.
- Added time-driven subtitle and danmaku overlays that follow pause and seek state without modifying AVPlayer or VLC internals.
- Added persisted subtitle size/position and danmaku visibility controls, including Android backup preference aliases.

### Testing
- Passed: fixed parser fixtures cover SRT/VTT timing, ASS dialogue, Bilibili placements/colors, text danmaku, and playback Header/Cookie forwarding.
- Passed: model and API fixtures cover Android `danmaku` string/object forms and propagation into `PlaybackRequest`.
- Passed: `git diff --check -- . ':(exclude)ios/Sources/CQuickJS/quickjs/**'` before commit.
- Not run: Swift compilation, parser tests, iPhone/iPad UI tests, device build, IPA packaging and signing require the next macOS GitHub Actions run; this Windows host has no Swift/Xcode toolchain.
- Not run: visual timing, local Files security scope, VLC playback overlay, orientation changes and background restoration still require real-device acceptance.

### Notes
- `ios/Sources/XingGuangKit/Models/CatalogModels.swift`: adds Android-compatible danmaku resources to playback results and requests.
- `ios/Sources/XingGuangKit/Services/TimedTextService.swift`: loads and parses external subtitle and danmaku formats.
- `ios/Sources/XingGuangKit/Services/ApiVodRepository.swift`: propagates API danmaku resources.
- `ios/Sources/XingGuangJavaScript/JavaScriptVodRepository.swift`: propagates JavaScript danmaku resources.
- `ios/Sources/XingGuangKit/Views/Components/TimedOverlayViews.swift`: renders synchronized subtitle and danmaku overlays.
- `ios/Sources/XingGuangKit/Views/VodDetailPreviewView.swift`: adds source selection, file import, overlay controls and playback integration.
- `ios/Sources/XingGuangKit/State/XingGuangAppModel.swift`: persists overlay settings and exposes authenticated text loading.
- `ios/Sources/XingGuangKit/Persistence/AppDatabase.swift`: maps Android subtitle/danmaku preference aliases during restore.
- `ios/Sources/XingGuangKit/Views/SettingsView.swift`: exposes player-level subtitle and danmaku preferences.
- `ios/Tests/XingGuangKitTests/TimedTextServiceTests.swift`: covers parsing and remote request behavior.
- `ios/Tests/XingGuangKitTests/DomainModelsTests.swift`: covers danmaku Codable compatibility.
- `ios/Tests/XingGuangKitTests/ApiVodRepositoryTests.swift`: covers playback danmaku propagation.
- `docs/ios-development.md`: records the new capability and remaining advanced-feature boundary.
- `progress.md`: appends implementation, validation, file list and rollback point.
- Rollback method: before committing, run `git restore -- ios docs/ios-development.md progress.md`; after the feature commit is the branch tip, run `git revert HEAD`.

## 2026-07-26 - Task: Validate external subtitles and danmaku on macOS CI

### What was done
- Confirmed the complete subtitle/danmaku batch on iPhone, iPad and the TrollStore device build path.
- Classified the first attempt's existing configuration-save UI assertion as simulator automation instability after the unchanged second attempt passed.

### Testing
- Passed: GitHub Actions run `30193845251`, attempt 2, job `89772519079`, completed in 15 minutes 48 seconds.
- Passed: iPhone tests in 5 minutes 24 seconds, iPad tests in 5 minutes 33 seconds, device Release build in 2 minutes 26 seconds, IPA packaging, structure/signing checks and artifact upload.
- Passed: artifact `XingGuang-iOS-17` is 20.2 MB with SHA-256 `8e2780718314bbd26a60bad691923e4537b5e4e894e6bb6cb7a53203ce85e96c`.
- Known boundary: real-device visual timing, Files security scope, VLC overlays, orientation and background restoration remain hardware acceptance items.

### Notes
- `docs/ios-development.md`: records the successful subtitle/danmaku CI run and artifact identity.
- `progress.md`: appends CI evidence, the first-attempt classification and rollback point.
- Rollback method: before committing, run `git restore -- docs/ios-development.md progress.md`; after the documentation commit is the branch tip, run `git revert HEAD`.

## 2026-07-26 - Task: Add WebView media sniffing and controlled JavaScript local proxy

### What was done
- Replaced the type 3/type 4 `parse != 0` rejection with a structured Web sniffing request that preserves source headers, cookies, timeout and click script.
- Added an isolated WKWebView media resolver covering fetch, XHR, media elements, resource timing, MIME/extension detection, JavaScript `isVideo`, timeout, cancellation and WebKit cookie propagation.
- Added a loopback-only JavaScript proxy that selects ports 9978-9998, restricts methods/path/size/concurrency, and routes only to registered JavaScript sites.
- Started the proxy before production configuration bootstrap and injected both the proxy endpoint and Web resolver without changing Android sources or player-engine responsibilities.

### Testing
- Passed: source-level tests cover JavaScript `parse=1` request creation, App-model resolution before player load, and loopback proxy routing through a registered JavaScript site.
- Passed: `git diff --check -- . ':(exclude)ios/Sources/CQuickJS/quickjs/**'` after implementation.
- Not run: Swift compilation, WebKit/Network.framework tests, iPhone/iPad suites, device build, IPA packaging and signing require macOS GitHub Actions; this Windows host has no Swift/Xcode toolchain.
- Not run: real protected pages, Cookie/UA/Referer behavior, site click scripts and final AVPlayer/VLC playback require TrollStore hardware acceptance.

### Notes
- `ios/Sources/XingGuangKit/Models/CatalogModels.swift`: adds Web sniffing metadata to playback requests.
- `ios/Sources/XingGuangKit/Services/WebMediaSniffer.swift`: resolves page URLs into final media requests with WKWebView.
- `ios/Sources/XingGuangKit/Services/ApiVodRepository.swift`: propagates type 4 parse requirements.
- `ios/Sources/XingGuangKit/State/XingGuangAppModel.swift`: resolves sniffing requests before player creation.
- `ios/Sources/XingGuangKit/Views/XingGuangRootView.swift`: supports asynchronous production preparation before bootstrap.
- `ios/Sources/XingGuangJavaScript/JavaScriptVodRepository.swift`: propagates type 3 parse requests and routes proxy calls to registered sites.
- `ios/Sources/XingGuangJavaScript/QuickJSHost.swift`: reads a dynamically injected local proxy endpoint.
- `ios/Sources/XingGuangJavaScript/QuickJSRuntime.swift`: shares the endpoint holder with each runtime.
- `ios/Sources/XingGuangJavaScript/LocalProxyServer.swift`: implements the controlled loopback HTTP server.
- `ios/App/XingGuangApp.swift`: wires proxy startup and JavaScript video validation into the production environment.
- `ios/Tests/XingGuangKitTests/JavaScriptVodRepositoryTests.swift`: covers parse propagation and local proxy routing.
- `ios/Tests/XingGuangKitTests/XingGuangAppModelTests.swift`: covers pre-player Web resolution.
- `docs/ios-development.md`: documents behavior, security boundary and remaining hardware validation.
- `progress.md`: appends implementation, validation evidence, file list and rollback point.
- Rollback method: before committing, run `git restore -- ios docs/ios-development.md progress.md`; after the feature commit is the branch tip, run `git revert HEAD`.
