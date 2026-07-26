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
- 外置字幕支持远程或文件导入的 SRT、WebVTT、ASS/SSA，弹幕支持 Android 对齐的 Bilibili XML 与 `[时间]文本`；两者以播放器时间驱动覆盖层，支持跳转同步、弹幕开关、字幕字号和底部位置持久化。

尚未完成或尚未验收：

- GitHub Actions 运行 `30179725200` 已通过完整的 iPhone/iPad 测试、设备 Release 构建、IPA 打包、IPA 结构和 ad-hoc 签名检查，并上传了 `XingGuang-iOS-16` artifact。仍未完成 TrollStore 真机安装与功能验收，因此不能宣称媒体播放和设备兼容性已经在真实设备上验证。
- JavaScript 仍不能运行依赖 Android JAR 的扩展函数；Android JAR、Python Spider 和部分来源专用 `playUrl` 解析链会返回明确的不兼容错误。
- WebView 媒体嗅探、二维码扫描、DoH/广告规则代理和完整配置文件打开流程仍在后续阶段，当前不能宣称已移植。
- HLS AES 等由系统播放核心原生处理；传入 Widevine、PlayReady、ClearKey 或其他外置 DRM 描述时会给出 DRM 错误。当前没有 FairPlay 许可证代理实现。
- VLC 路径不承诺 AirPlay、系统画中画或任意自定义 Header 与 Android 完全一致；外置字幕采用播放器上层同步渲染，不依赖 AVPlayer/VLC 的内置字幕实现。

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

运行 `30193845251` 的第 2 次尝试已通过完整 iPhone/iPad 测试、设备 Release 构建、TrollStore IPA 打包和签名检查。产物为 `XingGuang-iOS-17`（20.2 MB，SHA-256 `8e2780718314bbd26a60bad691923e4537b5e4e894e6bb6cb7a53203ce85e96c`）；第 1 次尝试仅有既有配置保存 UI 断言波动，原样重跑通过。

运行 `30179725200` 已通过工程生成、依赖安装、完整 iPhone/iPad 单元与 UI 测试、设备 Release 构建、TrollStore IPA 打包、IPA 结构及 ad-hoc 签名检查。产物为 `XingGuang-iOS-16`，artifact 大小 `21,077,952` 字节，保留 14 天。该结果关闭了本批 QuickJS/CommonCrypto、直播解析和备份导出的 CI 验证缺口，但真机媒体能力仍需 TrollStore 验收。

运行 `30179470554` 已确认代理兼容用例通过、AES 加解密不再触发独占访问冲突，并确认 RSA X.509/PKCS#8 动态加密与往返解密通过。剩余两个失败来自测试向量：AES 旧期望值不符合 UTF-8 输入的标准 CBC/PKCS7 结果，RSA 旧固定密文实际解密为 `??-RSA`；现已用独立加密实现核验并替换向量。修正后的完整 iPhone/iPad、Release、IPA 和签名检查仍需下一次 macOS CI 确认。

运行 `30179024702` 已确认 QuickJS 销毁、Swift 编译和 3 个 iPhone UI 测试通过。剩余失败为 AES 输出缓冲区的 Swift 独占访问冲突、RSA 测试夹具未实际插入密钥，以及代理 Header JSON 在 Apple 平台保留 `\/` 转义；现已分别缓存 CommonCrypto 调用长度、修正测试插值并使用不转义斜杠的 JSON 序列化。上述修复仍需新的 macOS CI 运行确认；iPad、设备 Release、IPA 和签名步骤在该失败运行中均未执行。

`iOS` workflow 在改动 `ios/**` 或 `.github/workflows/ios.yml` 时运行，也支持手动触发。它会：

1. 安装 XcodeGen 和 CocoaPods，生成项目并安装 Pods。
2. 在一个 iPhone Simulator 和一个 iPad Simulator 上运行单元/UI 测试。
3. 使用 `iphoneos` SDK 构建 Release App bundle。
4. 先对嵌入框架执行 ad-hoc 签名，再签名 App，验证签名并打包 IPA。
5. 校验 IPA 的 `Payload/XingGuang.app/Info.plist`，上传 IPA 与构建日志 14 天。

`codex/ios-foundation` 的运行 `30179725200` 已通过当前完整 CI 链路：iPhone Simulator、iPad Simulator、设备 Release 构建、IPA 打包、结构检查、ad-hoc 签名检查和 artifact 上传，总耗时约 10 分钟。当前产物为 `XingGuang-iOS-16`（`21,077,952` 字节）。

第七次运行 `30084153754` 已定位 iPad 的文本 tab 自动化限制；第八次运行已确认其修复边界：iPhone 继续验收文本 tab 和配置保存，iPad 将该断言显式标记为跳过，同时验收应用启动与详情导航。下一道门槛是 TrollStore 真机验收。

## TrollStore 第一阶段验收

从成功的 GitHub Actions artifact 下载 IPA 后，在支持 TrollStore 的 iPhone/iPad 上验证：

- 应用能安装、启动，三个底部入口均可进入；iPhone/iPad 横竖屏下没有重叠或截断。
- 可加载真实 type 0、1、4 配置，切换来源、分类、搜索、详情、线路和选集正常。
- 收藏、历史、继续观看、进度、倍速和线路在重启后保持正确。
- HLS/MP4 走 AVPlayer，RTSP/RTMP 或 MKV/FLV/WebM/MPD 走 VLC；强制内核不自动切换，自动模式只进行一次格式回退。
- AVPlayer 的后台播放、画中画与 AirPlay 实际可用；VLC 格式播放、切换、暂停、跳转正常。
- 遇到网络、鉴权和 DRM 失败时显示明确错误，不错误回退或静默空白。

第一阶段真机验收仍需完成；QuickJS/CommonCrypto、直播解析和备份导出的 CI 已通过，后续可在真机验收稳定后进入 WebView、外置字幕、弹幕与高级网络阶段。

## 2026-07-26 CI 诊断

GitHub Actions 运行 `30177752122` 已通过工程生成、CocoaPods 安装和模拟器选择，但在 iPhone 模拟器编译 `CGzip` 时失败。原因是参数校验使用了 zlib 未定义的 `Z_PARAM_ERROR`；现已改为 zlib 标准错误码 `Z_STREAM_ERROR`。该修复仍需新的 macOS CI 运行验证，不能据此宣称 QuickJS、Swift 测试或 IPA 打包已经通过。

后续运行 `30177937138` 已通过 `CGzip` 编译，并将下一处失败定位到 `QuickJSHost.swift`：可选的 `site.ext` 使用了非可选枚举模式匹配。现已先解包可选值再匹配字符串扩展，行为保持不变。该修复仍需新的 macOS CI 运行确认；iPad 测试、设备 Release 构建和 IPA 打包在这次失败运行中均未执行。

## Web 媒体嗅探与本地代理

- API type 4 和 JavaScript type 3 播放结果中的 `parse != 0` 不再直接返回“不支持”。播放请求会保留页面 URL、Header、Cookie、超时及来源 `click` 脚本，由正式 App 注入的 `WKWebView` 嗅探器解析真实媒体 URL 后再交给 AVPlayer/VLC。
- 嗅探器观察 `fetch`、`XMLHttpRequest`、`video/audio/source`、Performance Resource 和页面媒体事件；优先按媒体 MIME/扩展名识别，并可调用来源的 JavaScript `isVideo` 协议补充判断。每次任务最多检查 128 个 URL，支持超时和任务取消。
- 成功解析后会合并 WebKit Cookie，并清除嗅探标记，播放器仍只接收最终 `PlaybackRequest`，不承载网页生命周期。
- 正式 App 在读取配置前启动本地代理。代理仅绑定 `127.0.0.1`，在 9978-9998 中选择可用端口，只接受 `/proxy?do=js` 的 GET/HEAD 请求，限制请求头、参数长度和同时连接数，并只路由到已经初始化的 JavaScript 来源。
- `getProxy/js2Proxy` 使用可动态注入的回环端点；带 `siteKey` 的请求按来源路由，无 `siteKey` 时仅回退到最近初始化的 JavaScript 来源。代理不提供任意文件访问或通用外网转发。
- Windows 主机无法编译 WebKit/Network.framework。本批次必须由 macOS GitHub Actions 完成 iPhone/iPad 测试、设备构建、IPA 和签名检查；真实网页兼容性、Cookie 鉴权及媒体播放仍需 TrollStore 真机验收。

运行 `30178184218` 继续通过上述两处编译点，并将下一处失败定位到 `JavaScriptBridgeCompatibility.swift`：字符集局部变量与同名解析函数发生遮蔽。现已将局部值明确命名为 `charsetName`，字符集解析行为不变。该修复仍需新的 macOS CI 运行确认；本次运行同样未进入 iPad、设备 Release 和 IPA 步骤。

运行 `30178314318` 已完成 Swift 编译和全部 iPhone UI 测试，但单元测试仍有 14 个失败：13 个 JavaScript 用例无法在 SwiftPM 平铺后的 bundle 根目录找到内置模块，1 个播放器恢复进度用例在主队列异步回调前提前断言。资源加载现按原子目录优先并兼容 bundle 根目录，播放器测试改为等待恢复回调；生产播放器时序未改变。上述修复仍需新的 macOS CI 运行确认，iPad、设备 Release 和 IPA 步骤在该失败运行中未执行。

运行 `30178696426` 已确认资源加载修复和 iPhone UI 测试通过，剩余失败收敛为 QuickJS 销毁时的 `JS_FreeRuntime` 断言。模块加载器取得 compile-only 模块指针后未释放临时 `JSValue`，导致运行时仍有 GC 对象；现已按 QuickJS 模块加载器生命周期释放该临时值。该修复仍需新的 macOS CI 运行确认，iPad、设备 Release 和 IPA 步骤在该失败运行中未执行。

运行 `30195499024` 已通过 Swift 编译、3 个 iPhone UI 用例及除本地代理外的单元测试。本地代理请求已到达回环服务器，但 QuickJS 在 `xg-arguments:1:1` 解析第二次异步调用参数时返回 502。桥接层现改为由 Swift 在 C 调用期间固定 JSON `Data` 缓冲区，并显式传入 UTF-8 字节长度，不再依赖临时 C 字符串和 `strlen`；同时新增跨异步让步的重复参数调用回归测试。该修复仍须新的 macOS CI 确认，不能据此宣称本地代理或本批 IPA 已通过。

运行 `30196066791` 已确认上述 Swift/C 接口可以编译，随后在新增测试源码处失败：测试把异步调用直接放进了 `XCTAssertEqual` 自动闭包。现已先等待异步结果再执行同步断言；该次运行未执行 iPad、设备 Release 和 IPA 步骤，完整链路仍待下一次 CI。

运行 `30196244674` 已确认测试编译修复和直接重复异步参数用例通过，但回环代理仍返回 502；显式参数长度接口还导致两个既有 JavaScript 用例新增 `xg-arguments` 失败，证明该修改无效。现已恢复原 QuickJS 参数接口，并让 Network.framework 回调通过独立任务进入 Repository/actor，避免继承网络回调执行上下文。该修复仍须新的 macOS CI 验证。

运行 `30196524299` 已确认独立代理任务修复有效，并通过 iPhone/iPad 完整测试、设备 Release 构建、TrollStore IPA 打包、结构与 ad-hoc 签名检查。产物为 `XingGuang-iOS-21`（artifact ID `8630371695`，`21,238,473` 字节，保留至 2026-08-09）；真实网页嗅探、鉴权 Cookie 和最终媒体播放仍需 TrollStore 真机验收。

## 配置网络策略

- iOS 现保留 Android 配置中的 `headers`、`ads` 和 `doh` 字段。配置加载成功后才替换共享网络策略，旧请求仍由原任务取消机制结束。
- `headers` 按 Android 的“主机包含或完整正则匹配”语义注入，并覆盖同名请求头；覆盖 API、扩展配置、直播/EPG、字幕弹幕及 JavaScript `req/http`。
- `ads` 在 App 自有 HTTP 发出前阻止匹配主机，并在 WKWebView 嗅探中同时过滤页面导航、媒体候选和内容子资源。AVPlayer/VLC 内部媒体请求不经过该策略，不能保证与 Android 完全一致。
- `doh` 服务器配置会被兼容解码和保留，但 iOS/iPadOS 15 的公开 `URLSession` API 不允许 App 为单次请求替换 DNS 解析器。当前使用设备系统 DNS/加密 DNS 设置；未使用会破坏 HTTPS SNI/证书校验的 IP 替换方案，也不把仅预查询 DoH 冒充为生效。
- 本批次已添加配置解码、Header 注入、广告阻止和配置切换更新策略的固定测试；Swift/WebKit 编译与完整 IPA 仍须下一次 macOS CI 确认。

运行 `30197040000` 已通过 `XingGuangKit` 网络策略与 WebKit 源码编译，但 `XingGuangJavaScript` target 因 `JavaScriptHTTP.swift` 缺少共享模块导入而停止。现已补充 `import XingGuangKit`；该次运行未进入测试、iPad、Release 和 IPA 步骤。
