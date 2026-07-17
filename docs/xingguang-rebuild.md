# 星光影视重构说明

## 业务结论

当前工程已经分成两条可用路线：

- `apkwork/decoded`：来自现有星光影视 APK 的 apktool 反编译工程，可用于继续做 APK 级资源和 smali 修改，并能重新打包签名。
- `D:\xingkong` 根目录：已切到更接近现有 APK 的 FongMi/TV 5.2.2 源码快照，并调整为 Android Studio 可打开、可编译、可调试的源码工程。

源码工程不是从 APK 完整反推出的原始源码，而是用同版本上游源码对齐包名、应用名、版本号和本地依赖后重构出来的 Android Studio 工程。

## APK 来源

- 源 APK：`C:\Users\52396\Desktop\星光影视-纸黑片单UI结构版-播放核心弹层高度固定修复-正式签名.apk`
- 工作区副本：`D:\xingkong\apkwork\source-latest.apk`
- 包名：`com.xingguang.video`
- 入口 Activity：`com.fongmi.android.tv.ui.activity.HomeActivity`
- 版本：`versionCode 522`，`versionName 5.2.2-noad`
- 源 APK SHA-256：`A888E87A8515F38DD490F1933E965E606E2CB7F615BD240A87DD1C4F593F6FBE`
- 源 APK 签名证书 SHA-256：`775b4b773f689575d436784b1b2f7b3f08e8e8bef6ab11276928c752c783da24`

## APK 重打包

执行：

```powershell
.\scripts\rebuild-xingguang-apk.ps1
```

输出：

```text
D:\xingkong\apkwork\signed-rebuild-local.apk
```

这份重打包 APK 使用本地新证书签名，不能直接覆盖安装原正式签名包。如果要安装它，需要先卸载旧包；卸载会清除 App 数据。

## Android Studio 调试

Android Studio 打开目录：

```text
D:\xingkong
```

建议环境：

- JDK：使用 Android Studio 自带或 JetBrains JDK 21，例如 `C:\Users\52396\.gradle\jdks\jetbrains_s_r_o_-21-amd64-windows.2`
- Android SDK：`D:\xingkong\android-sdk`
- Chaquopy Python：`D:\xingkong\tools\python310-nuget\tools\python.exe`

关键构建命令：

```powershell
.\gradlew.bat projects --no-daemon --stacktrace
.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace
.\gradlew.bat :app:assembleLeanbackArm64_v8aDebug --no-daemon --stacktrace
```

调试 APK 输出位置：

```text
D:\xingkong\app\build\outputs\apk\mobileArm64_v8a\debug\mobile-arm64_v8a.apk
D:\xingkong\app\build\outputs\apk\leanbackArm64_v8a\debug\leanback-arm64_v8a.apk
```

## 已做对齐

- 应用包名改为 `com.xingguang.video`。
- 应用名改为 `星光影视`。
- 版本号对齐为 `522 / 5.2.2-noad`。
- `minSdk` 对齐桌面正式包为 `26`。
- 移除默认自适应启动图标，恢复桌面正式包的 `mipmap-*/ic_launcher.png` 与 `ic_launcher_round.png`。
- 移植桌面正式包的纸黑片单移动端布局、浅色主题色、卡片形状和播放控制图标。
- Debug/Release 构建改用原版签名证书 `apkwork/keystore/xingguang-release.p12`，证书 SHA-256 与桌面正式包一致：`775b4b773f689575d436784b1b2f7b3f08e8e8bef6ab11276928c752c783da24`。
- 播放页保持“加载时与播放时播放器高度一致”修复：竖屏非全屏时复用初始播放器高度，不再按播放内容重新动画计算高度。
- 上游源码固定到 `versionCode 522 / versionName 5.2.2` 对应的 5.2.2 快照。
- 补入本地 AAR：`forcetech-release.aar`、`hook-release.aar`、`jianpian-release.aar`、`thunder-release.aar`、`tvbus-release.aar`。
- 补入官方 Media3、DanmakuFlameMaster 和 nextlib-media3ext 依赖以满足当前源码编译。
- 固定 Chaquopy 使用工作区内 Python 3.10，避免 Android Studio 同步时找不到 Python。

## 已知降级点

为保证源码工程能基于公开依赖编译调试，以下私有或旧版能力做了编译兼容降级：

- `com.android.cast.dlna.*` 只保留空实现兼容层，不提供真实 DLNA 投屏能力。
- 自定义 Media3 渲染入口、广告过滤参数、解码参数已移除或降级为官方 API。
- 字幕快捷位置和字号增减接口已降级，不再依赖上游私有 `SubtitleView` 扩展。
- Danmaku 精准同步已降级，不再依赖缺失的 `AbsDanmakuSync`。

这些降级点会影响对应功能的完整行为，但不影响 Android Studio 打开、同步、编译和常规断点调试。

## 安装调试注意

当前 Debug APK 已使用原版证书签名，可覆盖安装桌面正式签名包并保留数据。覆盖前仍建议先确认当前构建包的签名指纹：

```powershell
$env:JAVA_HOME='D:\xingkong\tools\jdk17\jdk-17.0.19+10'
D:\xingkong\android-sdk\build-tools\36.0.0\apksigner.bat verify --print-certs D:\xingkong\app\build\outputs\apk\mobileArm64_v8a\debug\mobile-arm64_v8a.apk
```

可用设备检查：

```powershell
adb devices
```

覆盖安装：

```powershell
adb install D:\xingkong\app\build\outputs\apk\mobileArm64_v8a\debug\mobile-arm64_v8a.apk
```
