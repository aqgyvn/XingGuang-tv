# iPhone/iPad 开发说明

## 当前阶段

当前实现处于“第二阶段：JavaScript 数据源接入（进行中）”。第一阶段的 API 点播、持久化与双播放核心已经通过 CI；目标平台为 iOS/iPadOS 15.0 及以上，分发方式为 TrollStore 私人安装。

已实现的代码能力：

- 点播、直播、设置三个 SwiftUI 主入口，适配 iPhone 与 iPad。
- `type 0` XML、`type 1` JSON、`type 4` 扩展 API 的配置、首页、分类、搜索、详情和播放地址请求。
- Android 字段语义兼容的配置、站点、影片、筛选、播放线路、收藏、历史、进度和轨道模型；数字型 ID、URL 对数组及 type 4 的字幕/DRM/请求头结果均可解码。
- GRDB/SQLite 持久化：`config`、`site`、`live`、`keep`、`history`、`track` 表；支持配置替换、收藏、历史、继续观看、线路、进度和倍速保存。
- `Automatic`、`AVPlayer`、`VLC` 三种播放内核模式。自动模式对 RTSP/RTMP/RTP、MKV、FLV、WebM、AVI、DASH/MPD 先选 VLC；其他地址先选 AVPlayer，格式或解码失败时仅回退一次。认证、网络和 DRM 错误不会回退。
- AVPlayer 支持系统可播放的 HLS、MP4/MOV、内嵌音视频/字幕轨道、倍速、后台音频、AirPlay 与系统画中画；画中画通过单层 `AVPlayerLayer` 的显式入口启动，是否可用仍需真机验收。MobileVLCKit 负责 RTSP、RTMP 和非系统封装/编码的回退播放。
- 配置切换会取消旧配置与片库请求，UI 状态只在主线程更新。
- JavaScript `type 3` 已接入官方 QuickJS C runtime、按来源串行 context、模块加载、`init/home/homeVod/category/detail/search/play`、`proxy/live/action/sniffer/isVideo`、`req/http`、`local`、console、URL 合并、MD5、AES/RSA、GBK 和繁简转换桥；正式 App 已按来源类型路由 API 与 JavaScript 实现。
- 直播已支持 JSON/M3U/TXT、分组、频道备用线路、请求头继承、JavaScript `liveContent(url)` 动态源、JSON/XMLTV/XMLTV.gz EPG、日期切换、当前节目和 Android 兼容回看/时移模板；备份已支持 Android 字段 JSON 与 `.bk.gz` 导入/导出，并在校验后事务替换本地数据。

尚未完成或尚未验收：

- GitHub Actions 第八次运行 `30085938974` 已通过完整的 iPhone/iPad 测试、设备构建、IPA 打包、IPA 结构和 ad-hoc 签名检查，并上传了 `XingGuang-iOS-8` artifact。仍未完成 TrollStore 真机安装与功能验收，因此不能宣称媒体播放和设备兼容性已经在真实设备上验证。
- JavaScript 仍不能运行依赖 Android JAR 的扩展函数；Android JAR、Python Spider 和部分来源专用 `playUrl` 解析链会返回明确的不兼容错误。
- WebView 媒体嗅探、外置字幕文件、弹幕显示、二维码扫描、DoH/广告规则代理和完整文件打开流程仍在后续阶段，当前不能宣称已移植。
- HLS AES 等由系统播放核心原生处理；传入 Widevine、PlayReady、ClearKey 或其他外置 DRM 描述时会给出 DRM 错误。当前没有 FairPlay 许可证代理实现。
- VLC 路径不承诺 AirPlay、系统画中画、任意自定义 Header 或外置字幕行为与 Android 完全一致；AVPlayer 的外置字幕资源也尚未接入播放器。

本阶段是在用户明确要求下提前启动的；第一阶段真机验收仍是发布门槛，第二阶段完成后必须重新通过完整 CI，再进行真机验收，不能把模拟器通过当作设备功能通过。

## 工程结构

- `ios/Package.swift`：可预览、可测试的 `XingGuangKit` Swift Package，并通过 SwiftPM 引入 GRDB。
- `ios/Sources/CQuickJS/`：固定 QuickJS `2026-06-04` 上游提交的 C runtime 与 iOS 薄桥接层。
- `ios/Sources/XingGuangJavaScript/`：JavaScript context、模块/网络/local 桥、type 3 Repository 和内置兼容库资源。
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
- [QuickJS](https://github.com/bellard/quickjs)：固定提交 `04be246001599f5995fa2f2d8c91a0f198d3f34c`，遵循仓库内 `ios/Sources/CQuickJS/quickjs/LICENSE` 的 MIT 许可文本。

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

`codex/ios-foundation` 的第八次运行 `30085938974` 已通过完整第一阶段链路：iPhone Simulator 测试（5 分 48 秒）、iPad Simulator 测试（6 分 40 秒）、设备 Release 构建（1 分 50 秒）、IPA 打包、结构检查、ad-hoc 签名检查和 artifact 上传，总耗时 15 分 45 秒。当前 JavaScript 改动需要新的 CI 运行确认。上一产物为 `XingGuang-iOS-8`（18.3 MB，artifact SHA-256 `7fee4726fb44cf7faab98ea08192764d5a7482096b188cd6f6303aa26c644fb9`）。

第七次运行 `30084153754` 已定位 iPad 的文本 tab 自动化限制；第八次运行已确认其修复边界：iPhone 继续验收文本 tab 和配置保存，iPad 将该断言显式标记为跳过，同时验收应用启动与详情导航。下一道门槛是 TrollStore 真机验收。

## TrollStore 第一阶段验收

从成功的 GitHub Actions artifact 下载 IPA 后，在支持 TrollStore 的 iPhone/iPad 上验证：

- 应用能安装、启动，三个底部入口均可进入；iPhone/iPad 横竖屏下没有重叠或截断。
- 可加载真实 type 0、1、4 配置，切换来源、分类、搜索、详情、线路和选集正常。
- 收藏、历史、继续观看、进度、倍速和线路在重启后保持正确。
- HLS/MP4 走 AVPlayer，RTSP/RTMP 或 MKV/FLV/WebM/MPD 走 VLC；强制内核不自动切换，自动模式只进行一次格式回退。
- AVPlayer 的后台播放、画中画与 AirPlay 实际可用；VLC 格式播放、切换、暂停、跳转正常。
- 遇到网络、鉴权和 DRM 失败时显示明确错误，不错误回退或静默空白。

第一阶段真机验收仍需完成；本批次需要新的 CI 验证 QuickJS/CommonCrypto、直播解析和备份导出，再进入 WebView、外置字幕、弹幕与高级网络阶段。

## 2026-07-26 CI 诊断

GitHub Actions 运行 `30177752122` 已通过工程生成、CocoaPods 安装和模拟器选择，但在 iPhone 模拟器编译 `CGzip` 时失败。原因是参数校验使用了 zlib 未定义的 `Z_PARAM_ERROR`；现已改为 zlib 标准错误码 `Z_STREAM_ERROR`。该修复仍需新的 macOS CI 运行验证，不能据此宣称 QuickJS、Swift 测试或 IPA 打包已经通过。

后续运行 `30177937138` 已通过 `CGzip` 编译，并将下一处失败定位到 `QuickJSHost.swift`：可选的 `site.ext` 使用了非可选枚举模式匹配。现已先解包可选值再匹配字符串扩展，行为保持不变。该修复仍需新的 macOS CI 运行确认；iPad 测试、设备 Release 构建和 IPA 打包在这次失败运行中均未执行。
