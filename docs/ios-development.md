# iPhone/iPad 开发说明

## 当前阶段

当前实现处于“第一阶段：API 点播、持久化与双播放核心”。目标平台为 iOS/iPadOS 15.0 及以上，分发方式为 TrollStore 私人安装。

已实现的代码能力：

- 点播、直播、设置三个 SwiftUI 主入口，适配 iPhone 与 iPad。
- `type 0` XML、`type 1` JSON、`type 4` 扩展 API 的配置、首页、分类、搜索、详情和播放地址请求。
- Android 字段语义兼容的配置、站点、影片、筛选、播放线路、收藏、历史、进度和轨道模型；数字型 ID、URL 对数组及 type 4 的字幕/DRM/请求头结果均可解码。
- GRDB/SQLite 持久化：`config`、`site`、`live`、`keep`、`history`、`track` 表；支持配置替换、收藏、历史、继续观看、线路、进度和倍速保存。
- `Automatic`、`AVPlayer`、`VLC` 三种播放内核模式。自动模式对 RTSP/RTMP/RTP、MKV、FLV、WebM、AVI、DASH/MPD 先选 VLC；其他地址先选 AVPlayer，格式或解码失败时仅回退一次。认证、网络和 DRM 错误不会回退。
- AVPlayer 支持系统可播放的 HLS、MP4/MOV、内嵌音视频/字幕轨道、倍速、后台音频、AirPlay 与系统画中画；画中画由系统播放器控件或内联自动启动。MobileVLCKit 负责 RTSP、RTMP 和非系统封装/编码的回退播放。
- 配置切换会取消旧配置与片库请求，UI 状态只在主线程更新。

尚未完成或尚未验收：

- GitHub Actions 已在 macOS 上运行，但尚未通过完整的 iPhone/iPad 测试、设备构建和 IPA 打包链路；在全部 CI 步骤与 TrollStore 真机验收通过前，不能将当前分支视为可安装 IPA。
- JavaScript `type 3`、Android JAR、Python Spider、直播/EPG、WebView 嗅探、外置字幕、弹幕、备份恢复和高级网络能力仍在后续阶段，不能宣称已移植。
- `playUrl` 解析链和网页嗅探尚未实现；需要该链路的 type 0/1 来源将在后续 WebView 阶段处理。
- HLS AES 等由系统播放核心原生处理；传入 Widevine、PlayReady、ClearKey 或其他外置 DRM 描述时会给出 DRM 错误。当前没有 FairPlay 许可证代理实现。
- VLC 路径不承诺 AirPlay、系统画中画、任意自定义 Header 或外置字幕行为与 Android 完全一致。

后续阶段必须在第一阶段 CI 与真机验收通过后开始，不能跳过该门槛。

## 工程结构

- `ios/Package.swift`：可预览、可测试的 `XingGuangKit` Swift Package，并通过 SwiftPM 引入 GRDB。
- `ios/project.yml`：XcodeGen 工程定义；生成通用 iPhone/iPad App、单元测试和 UI 测试 target。
- `ios/Podfile` 与 `ios/Podfile.lock`：App 层引入固定版本 `MobileVLCKit 3.6.0b10`。
- `ios/App/`：SwiftUI 启动壳、Info.plist、应用图标和 MobileVLCKit 适配器。
- `ios/Sources/XingGuangKit/`：模型、网络、持久化、播放器、状态和 SwiftUI 页面。
- `ios/Tests/`：模型、API、数据库、选核、续播、状态和 UI 启动测试。
- `.github/workflows/ios.yml`：macOS 构建、iPhone/iPad Simulator 测试与 TrollStore IPA 打包。

Android Gradle 模块继续位于仓库根目录。iOS 工程不引用或修改 Android Java、XML、AAR 或 `.so` 文件。

## 依赖与许可

- [GRDB.swift](https://github.com/groue/GRDB.swift)：SwiftPM 依赖，用于 SQLite 持久化；遵循其 MIT 许可证。
- [MobileVLCKit](https://code.videolan.org/videolan/VLCKit)：CocoaPods 依赖，用于 VLC 回退播放；版本 `3.6.0b10` 的 podspec 标示为 LGPL v2.1。分发 IPA 前必须按该许可证保留相应告知与合规义务。

MobileVLCKit 会增加 IPA 体积。`Podfile.lock` 固定 pod 版本与规格校验；SwiftPM 的 GRDB 解析结果需由首次 macOS/Xcode 构建确认。

## Mac 本地构建

前置条件：Xcode、XcodeGen、CocoaPods 和已安装的 iOS Simulator runtime。

```bash
cd ios
xcodegen generate
pod install
xcodebuild \
  -workspace XingGuang.xcworkspace \
  -scheme XingGuang \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test
```

在 Xcode 中打开 `ios/XingGuang.xcworkspace`，不要打开生成的 `.xcodeproj`。`XingGuangKit` 保留离线 fixtures，可用于 SwiftUI Canvas；真正的网络、GRDB 和 VLC 验证应使用 App target。

当前 Windows 主机没有 `swift`、`xcodebuild`、`xcodegen`、`pod` 或 `xcrun`，因此无法提供实时 iOS Simulator 预览。接入 Mac 后可用 Xcode Canvas，或使用已安装的 Build iOS Apps 模拟器预览能力进行热迭代。

## GitHub Actions

`iOS` workflow 在改动 `ios/**` 或 `.github/workflows/ios.yml` 时运行，也支持手动触发。它会：

1. 安装 XcodeGen 和 CocoaPods，生成项目并安装 Pods。
2. 在一个 iPhone Simulator 和一个 iPad Simulator 上运行单元/UI 测试。
3. 使用 `iphoneos` SDK 构建 Release App bundle。
4. 先对嵌入框架执行 ad-hoc 签名，再签名 App，验证签名并打包 IPA。
5. 校验 IPA 的 `Payload/XingGuang.app/Info.plist`，上传 IPA 与构建日志 14 天。

`codex/ios-foundation` 已推送并触发 workflow。修复后的分支必须通过 iPhone/iPad 测试、设备构建、IPA 结构与签名检查，结果通过后才能开始 TrollStore 验收。

第五次运行 `30082854165` 已确认此前的 URL 查询参数独占访问错误不再出现；新的编译阻断是 `AppDatabase` 的构造器委托、iOS 16 专属的 `AVPlayer.defaultRate`，以及错误调用 `AVPlayerViewController` 的画中画启动 API。现已改为 Swift 合法构造器委托、iOS 15 可用的保存倍速逻辑，并保留系统原生画中画入口，仍须重新运行完整 CI 链路。

## TrollStore 第一阶段验收

从成功的 GitHub Actions artifact 下载 IPA 后，在支持 TrollStore 的 iPhone/iPad 上验证：

- 应用能安装、启动，三个底部入口均可进入；iPhone/iPad 横竖屏下没有重叠或截断。
- 可加载真实 type 0、1、4 配置，切换来源、分类、搜索、详情、线路和选集正常。
- 收藏、历史、继续观看、进度、倍速和线路在重启后保持正确。
- HLS/MP4 走 AVPlayer，RTSP/RTMP 或 MKV/FLV/WebM/MPD 走 VLC；强制内核不自动切换，自动模式只进行一次格式回退。
- AVPlayer 的后台播放、画中画与 AirPlay 实际可用；VLC 格式播放、切换、暂停、跳转正常。
- 遇到网络、鉴权和 DRM 失败时显示明确错误，不错误回退或静默空白。

真机验收通过前，不进入 QuickJS、直播或高级兼容阶段。
