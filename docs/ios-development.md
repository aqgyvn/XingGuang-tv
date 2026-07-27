# iPhone/iPad 开发说明

## 当前阶段

当前分支使用 MPV、MDK、AVPlayer 三播放核心，已通过 macOS CI 的编译、测试、设备 Release、IPA 结构和签名检查；真实媒体兼容性仍须 TrollStore 真机验收。目标平台为 iOS/iPadOS 15.0 及以上，分发方式为 TrollStore 私人安装。

已实现的代码能力：

- 点播、直播、设置三个 SwiftUI 主入口，适配 iPhone 与 iPad。
- `type 0` XML、`type 1` JSON、`type 4` 扩展 API 的配置、首页、分类、搜索、详情和播放地址请求。
- Android 字段语义兼容的配置、站点、影片、筛选、播放线路、收藏、历史、进度和轨道模型；数字型 ID、URL 对数组及 type 4 的字幕/DRM/请求头结果均可解码。
- GRDB/SQLite 持久化：`config`、`site`、`live`、`keep`、`history`、`track` 表；支持配置替换、收藏、历史、继续观看、线路、进度和倍速保存。
- `MPV`、`MDK`、`AVPlayer` 三种强制播放内核模式，不再提供自动选核或隐藏回退。默认使用 AVPlayer；Android 备份的 `player_engine` 按 `0=AVPlayer`、`1=MDK`、`2=MPV` 导入，旧 iOS 的 `automatic/vlc` 偏好回退为 AVPlayer。
- AVPlayer 支持系统可播放的 HLS、MP4/MOV、内嵌音视频/字幕轨道、倍速、后台音频、AirPlay 与系统画中画；MPVKit 使用 libmpv + Metal/MoltenVK，swift-mdk 使用 MDK 原生 Surface，负责用户明确选择后的扩展格式播放。
- 配置切换会取消旧配置与片库请求，UI 状态只在主线程更新。
- JavaScript `type 3` 已接入官方 QuickJS C runtime、按来源串行 context、模块加载、`init/home/homeVod/category/detail/search/play`、`proxy/live/action/sniffer/isVideo`、`req/http`、`local`、console、URL 合并、MD5、AES/RSA、GBK 和繁简转换桥；正式 App 已按来源类型路由 API 与 JavaScript 实现。
- 直播已支持 JSON/M3U/TXT、分组、频道备用线路、请求头继承、JavaScript `liveContent(url)` 动态源、JSON/XMLTV/XMLTV.gz EPG、日期切换、当前节目和 Android 兼容回看/时移模板；备份已支持 Android 字段 JSON 与 `.bk.gz` 导入/导出，并在校验后事务替换本地数据。
- 外置字幕支持远程或文件导入的 SRT、WebVTT、ASS/SSA，弹幕支持 Android 对齐的 Bilibili XML 与 `[时间]文本`；两者以播放器时间驱动覆盖层，支持跳转同步、弹幕开关、字幕字号和底部位置持久化。

尚未完成或尚未验收：

- `XingGuang-iOS-33` 已包含 MPV/MDK/AVPlayer、播放体验控制及完整 iPhone/iPad CI 验证；真实格式兼容、亮度、系统音量和画面比例仍以 TrollStore 真机验收为准。
- JavaScript 仍不能运行依赖 Android JAR 的扩展函数；Android JAR、Python Spider 和依赖 Android 扩展运行时的 type 2/3 解析器会返回明确的不兼容错误。
- WebView 媒体嗅探、二维码扫描、广告规则和配置文件打开流程已有 iOS 等效实现；DoH 受 iOS 15 URLSession 公共 API 限制，保留配置但使用系统 DNS。
- HLS AES 等由系统播放核心原生处理；传入 Widevine、PlayReady、ClearKey 或其他外置 DRM 描述时会给出 DRM 错误。当前没有 FairPlay 许可证代理实现。
- MPV/MDK 路径不承诺 AirPlay、系统画中画或任意自定义 Header 与 Android 完全一致；外置字幕仍可采用播放器上层同步渲染，不依赖某个内核的字幕样式实现。

本阶段是在用户明确要求下提前启动的；第一阶段真机验收仍是发布门槛，第二阶段完成后必须重新通过完整 CI，再进行真机验收，不能把模拟器通过当作设备功能通过。

## 工程结构

- `ios/Package.swift`：可预览、可测试的 `XingGuangKit` Swift Package，并通过 SwiftPM 引入 GRDB。
- `ios/Sources/CQuickJS/`：固定 QuickJS `2026-06-04` 上游提交的 C runtime 与 iOS 薄桥接层。
- `ios/Sources/XingGuangJavaScript/`：JavaScript context、模块/网络/local 桥、type 3 Repository 和内置兼容库资源。
- `ios/project.yml`：XcodeGen 工程定义；生成通用 iPhone/iPad App、单元测试和 UI 测试 target，并通过 SwiftPM 固定 MPVKit `1.0.0` 与 swift-mdk 提交 `d52412460acf238c4780a1a3da16190fa05e27b4`。
- `ios/App/`：SwiftUI 启动壳、Info.plist、应用图标及 MPV、MDK App 层适配器。
- `ios/Sources/XingGuangKit/`：模型、网络、持久化、播放器、状态和 SwiftUI 页面。
- `ios/Tests/`：模型、API、数据库、选核、续播、状态和 UI 启动测试。
- `.github/workflows/ios.yml`：macOS 构建、iPhone/iPad Simulator 测试与 TrollStore IPA 打包。

Android Gradle 模块继续位于仓库根目录。iOS 工程不引用或修改 Android Java、XML、AAR 或 `.so` 文件。

## 依赖与许可

- [GRDB.swift](https://github.com/groue/GRDB.swift)：SwiftPM 依赖，用于 SQLite 持久化；遵循其 MIT 许可证。
- [MPVKit](https://github.com/mpvkit/MPVKit)：SwiftPM 固定 `1.0.0`，使用非 GPL 的 `MPVKit` product；其 libmpv/FFmpeg 二进制按 LGPL v3 提供，分发 IPA 前必须履行相应告知和可替换/重链接义务。
- [swift-mdk](https://github.com/wang-bin/swift-mdk)：SwiftPM 固定提交 `d52412460acf238c4780a1a3da16190fa05e27b4`，其二进制 SDK 为 `v0.37.0`。当前仓库没有 MDK License Key；无 Key 构建可运行，但官方说明可能在最后一帧显示二维码，正式使用前需取得适用授权并通过 `MDK_LICENSE_KEY` 构建设置注入。
- [QuickJS](https://github.com/bellard/quickjs)：固定提交 `04be246001599f5995fa2f2d8c91a0f198d3f34c`，遵循仓库内 `ios/Sources/CQuickJS/quickjs/LICENSE` 的 MIT 许可文本。

MPVKit 包含多组媒体二进制，会显著增加依赖下载量和 IPA 体积；MPVKit、swift-mdk 与 GRDB 的 SwiftPM 解析及链接结果必须由 macOS/Xcode 构建确认。

## Mac 本地构建

前置条件：Xcode、XcodeGen 和已安装的 iOS Simulator runtime。

```bash
cd ios
xcodegen generate
xcodebuild \
  -project XingGuang.xcodeproj \
  -scheme XingGuang \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test
```

在 Xcode 中打开生成的 `ios/XingGuang.xcodeproj`。`XingGuangKit` 保留离线 fixtures，可用于 SwiftUI Canvas；真正的网络、GRDB、MPV 和 MDK 验证应使用 App target。

当前 Windows 主机没有 `swift`、`xcodebuild`、`xcodegen` 或 `xcrun`，因此无法提供实时 iOS Simulator 预览。接入 Mac 后可用 Xcode Canvas，或使用已安装的 Build iOS Apps 模拟器预览能力进行热迭代。

## GitHub Actions

以下成功记录是历史构建证据；本次三内核替换必须产生新的成功运行和 artifact 后，才能作为当前版本的安装依据。

运行 `30193845251` 的第 2 次尝试已通过完整 iPhone/iPad 测试、设备 Release 构建、TrollStore IPA 打包和签名检查。产物为 `XingGuang-iOS-17`（20.2 MB，SHA-256 `8e2780718314bbd26a60bad691923e4537b5e4e894e6bb6cb7a53203ce85e96c`）；第 1 次尝试仅有既有配置保存 UI 断言波动，原样重跑通过。

运行 `30179725200` 已通过工程生成、依赖安装、完整 iPhone/iPad 单元与 UI 测试、设备 Release 构建、TrollStore IPA 打包、IPA 结构及 ad-hoc 签名检查。产物为 `XingGuang-iOS-16`，artifact 大小 `21,077,952` 字节，保留 14 天。该结果关闭了本批 QuickJS/CommonCrypto、直播解析和备份导出的 CI 验证缺口，但真机媒体能力仍需 TrollStore 验收。

运行 `30179470554` 已确认代理兼容用例通过、AES 加解密不再触发独占访问冲突，并确认 RSA X.509/PKCS#8 动态加密与往返解密通过。剩余两个失败来自测试向量：AES 旧期望值不符合 UTF-8 输入的标准 CBC/PKCS7 结果，RSA 旧固定密文实际解密为 `??-RSA`；现已用独立加密实现核验并替换向量。修正后的完整 iPhone/iPad、Release、IPA 和签名检查仍需下一次 macOS CI 确认。

运行 `30179024702` 已确认 QuickJS 销毁、Swift 编译和 3 个 iPhone UI 测试通过。剩余失败为 AES 输出缓冲区的 Swift 独占访问冲突、RSA 测试夹具未实际插入密钥，以及代理 Header JSON 在 Apple 平台保留 `\/` 转义；现已分别缓存 CommonCrypto 调用长度、修正测试插值并使用不转义斜杠的 JSON 序列化。上述修复仍需新的 macOS CI 运行确认；iPad、设备 Release、IPA 和签名步骤在该失败运行中均未执行。

`iOS` workflow 在改动 `ios/**` 或 `.github/workflows/ios.yml` 时运行，也支持手动触发。它会：

1. 安装 XcodeGen，生成项目并由 Xcode/SwiftPM 解析依赖。
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
- 分别选择 MPV、MDK、AVPlayer 后，同一播放请求只进入所选内核，不发生自动切换或隐藏回退。
- AVPlayer 的后台播放、画中画与 AirPlay 实际可用；MPV/MDK 的扩展格式、Header/Cookie、切换、暂停、跳转和倍速正常。
- 遇到网络、鉴权和 DRM 失败时显示明确错误，不错误回退或静默空白。

第一阶段真机验收仍需完成；QuickJS/CommonCrypto、直播解析和备份导出的 CI 已通过，后续可在真机验收稳定后进入 WebView、外置字幕、弹幕与高级网络阶段。

## 2026-07-26 CI 诊断

GitHub Actions 运行 `30177752122` 已通过工程生成、CocoaPods 安装和模拟器选择，但在 iPhone 模拟器编译 `CGzip` 时失败。原因是参数校验使用了 zlib 未定义的 `Z_PARAM_ERROR`；现已改为 zlib 标准错误码 `Z_STREAM_ERROR`。该修复仍需新的 macOS CI 运行验证，不能据此宣称 QuickJS、Swift 测试或 IPA 打包已经通过。

后续运行 `30177937138` 已通过 `CGzip` 编译，并将下一处失败定位到 `QuickJSHost.swift`：可选的 `site.ext` 使用了非可选枚举模式匹配。现已先解包可选值再匹配字符串扩展，行为保持不变。该修复仍需新的 macOS CI 运行确认；iPad 测试、设备 Release 构建和 IPA 打包在这次失败运行中均未执行。

## Web 媒体嗅探与本地代理

- API type 4 和 JavaScript type 3 播放结果中的 `parse != 0` 不再直接返回“不支持”。播放请求会保留页面 URL、Header、Cookie、超时及来源 `click` 脚本，由正式 App 注入的 `WKWebView` 嗅探器解析真实媒体 URL 后再交给当前选择的 MPV、MDK 或 AVPlayer。
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
- `ads` 在 App 自有 HTTP 发出前阻止匹配主机，并在 WKWebView 嗅探中同时过滤页面导航、媒体候选和内容子资源。MPV、MDK、AVPlayer 内部媒体请求不经过该策略，不能保证与 Android 完全一致。
- `doh` 服务器配置会被兼容解码和保留，但 iOS/iPadOS 15 的公开 `URLSession` API 不允许 App 为单次请求替换 DNS 解析器。当前使用设备系统 DNS/加密 DNS 设置；未使用会破坏 HTTPS SNI/证书校验的 IP 替换方案，也不把仅预查询 DoH 冒充为生效。
- 本批次已添加配置解码、Header 注入、广告阻止和配置切换更新策略的固定测试；Swift/WebKit 编译与完整 IPA 仍须下一次 macOS CI 确认。

运行 `30197040000` 已通过 `XingGuangKit` 网络策略与 WebKit 源码编译，但 `XingGuangJavaScript` target 因 `JavaScriptHTTP.swift` 缺少共享模块导入而停止。现已补充 `import XingGuangKit`；该次运行未进入测试、iPad、Release 和 IPA 步骤。

运行 `30197188009` 已通过 Header/广告策略批次的 iPhone/iPad 测试、设备 Release 构建、IPA 结构和 ad-hoc 签名检查。产物为 `XingGuang-iOS-23`（artifact ID `8630553500`，`21,265,946` 字节，保留至 2026-08-09）；真实来源规则和 Web 页面仍需 TrollStore 真机验收。

## 配置文件与二维码

- 设置页的点播和直播配置框均提供文件与二维码图标入口。二维码仅接受包含主机的 `http/https` 地址，扫描成功后直接保存并加载对应配置。
- 文件入口先读取并验证内容：点播要求至少一个具有 `key/api` 的来源，直播要求 JSON/M3U/TXT 中至少一个可用频道；空文件、超过 10 MB 或格式无效时不改变当前配置。
- 验证成功的文件会原子复制到 App `Application Support/ImportedConfigurations` 后再保存 `file://` 地址，不依赖 Files 临时安全作用域，重启后仍可读取。
- App 声明相机用途仅用于配置二维码；无相机、拒绝权限和无效二维码均显示明确错误。模拟器只能验证界面和错误状态，实际摄像头扫描需 TrollStore 真机验收。
- Android `.bk.gz` 备份入口与事务恢复逻辑保持独立：配置文件导入不会覆盖收藏、历史、偏好或数据库表。

运行 `30197705390` 第 2 次尝试已通过 iPhone/iPad 测试、设备 Release 构建、IPA 结构和 ad-hoc 签名检查。可安装产物是 artifact ID `8630820708` 的 `XingGuang-iOS-24`（`21,312,143` 字节，保留至 2026-08-09）；同名 artifact ID `8630678736` 仅 `52,450` 字节，是第 1 次 UI runner 初始化失败时上传的日志，不包含可安装 IPA。

## 本地媒体文件

- 设置页的“打开本地媒体”通过系统 Files 选择器接收常用视频和音频格式。所选文件会在安全作用域有效期间复制到 App 的 `Caches/ImportedMedia`，播放器不依赖 Files 提供方的临时授权。
- 本地媒体复用正式三内核选择：文件只交给设置中明确选择的 MPV、MDK 或 AVPlayer，不再按扩展名自动选核或失败回退。
- 页面提供播放暂停、进度跳转、倍速和实际内核状态。缓存目录可能由系统回收，当前不提供媒体库或长期收藏语义。
- 文件复制、SwiftUI 播放页和 MPVKit/swift-mdk 链接仍须 macOS CI；真实大文件、外部 Files 提供方及格式兼容性须 TrollStore 真机验收。

## Android / iOS 兼容审计

完整页面、数据源、播放器和设置项审计见 [`ios-compatibility-matrix.md`](ios-compatibility-matrix.md)。矩阵明确区分已对齐、iOS 等效、平台限制和不在本轮范围；CI 通过与 TrollStore 真机通过分别记录，不互相替代。

运行 `30203798664` 已通过本地媒体与兼容审计批次的 iPhone/iPad 单元和 UI 测试、设备 Release 构建、TrollStore IPA 打包、结构与 ad-hoc 签名检查。可安装产物为 `XingGuang-iOS-25`（artifact ID `8632548070`，`21,367,271` 字节，SHA-256 `9252d978f2425eb91f94e0c0ec3d84388688d596d08ba6d503590819b0cc807a`，保留至 2026-08-09）；本地大文件、外部 Files 提供方与具体编解码兼容性仍需 TrollStore 真机验收。

## 三内核版本 CI 状态

运行 `30209861414` 的两次尝试均已完成 MPVKit、swift-mdk、GRDB 解析和 iPhone 编译，三个播放核心的适配器、动态框架嵌入、播放器单元测试及 iPhone UI 测试均通过。当前流水线只阻塞在既有本地 JavaScript 代理回环测试：代理返回 HTTP 502，QuickJS 报告 `xg-arguments:1:1`，因此 iPad、Release 和 IPA 步骤尚未执行。

运行 `30211242453` 证明显式固定 UTF-8 参数缓冲区仍会在同一回环用例失败，因此该实现已撤回，连续五次回环回归保留。当前原生桥会在解析失败时附带实际参数长度和前四个字节，用于区分空缓冲、截断和执行上下文问题；这只是诊断信息，不改变 JavaScript 协议。通过最终修复的 macOS CI 前，仍没有包含 MPV、MDK、AVPlayer 三内核的可安装 IPA。

运行 `30211833730` 已通过五次连续 QuickJS 回环请求、全部 iPhone/iPad 单元与 UI 测试、设备 Release、IPA 结构和 ad-hoc 签名检查。产物为 `XingGuang-iOS-28`（artifact ID `8634779269`，`22,742,377` 字节，SHA-256 `d26735777bd5773f0120491d67af1ee376c52540818ecb6a37505ca3cb5c2775`，保留至 2026-08-09）。由于此前同一用例存在间歇失败，后续每批 CI 仍必须保留回环测试和诊断信息，不能仅凭本次成功认定根因已消失。

## 分页与搜索记录

- 分类页和搜索页使用 Repository 已有页码接口连续加载，结果按影片 ID 去重，并以服务端 `pagecount` 决定是否继续。
- 搜索关键词在提交时写入本地偏好，最近使用的记录置顶，大小写重复项合并，最多保留 20 条；搜索页支持再次发起、单条删除和全部清空。
- Android 热搜和联想依赖 360、爱奇艺第三方接口，本轮不在 iOS 新增该外部依赖。分页与搜索记录改动仍须下一次 macOS CI 编译和测试。

运行 `30212470946` 已进入完整 iPhone 测试阶段，但在该步骤失败，iPad、Release 和 IPA 未执行。为消除本地代理 detached task 与 QuickJS actor 之间的参数处理边界，参数校验、JSON 序列化和原生调用现统一在 `QuickJSRuntime` actor 内串行执行；JavaScript 方法和代理协议不变。该修复与分页功能须由下一次 macOS CI 一并验证。

运行 `30213000078` 已确认 iPhone 全部测试通过，iPad 仅本地 JavaScript 代理回环用例失败；五次请求均返回 502。原生诊断显示 QuickJS 收到的参数长度为 52、前缀为 `5b7b2276`（`[{"v`），因此输入并非空缓冲或截断。参数数组现改由 QuickJS 常规全局表达式求值生成，不再调用该场景下间歇失败的 `JS_ParseJSON`；Swift 侧的结构化 JSON 校验、数组检查和错误诊断保持不变。该修复必须通过新的 iPhone/iPad、设备 Release、IPA 和签名检查后才算完成。

运行 `30213741191` 在 iPhone 的第 3 次回环代理请求上复现同一首字符异常，证明改用常规表达式求值没有解决问题，该方案已撤回。QuickJS 公共头文件明确要求 runtime 换线程后调用 `JS_UpdateStackTop`；Swift actor 虽然保证串行，但不保证每次恢复在同一系统线程。原生桥现于加载 Spider 和每次方法调用前更新栈顶，并恢复结构化 `JS_ParseJSON`。该线程切换修复仍须完整 macOS CI 验证。

运行 `30214215174` 已通过五次连续本地代理请求、全部 iPhone/iPad 单元与 UI 测试、设备 Release 构建、TrollStore IPA 结构和 ad-hoc 签名检查，确认线程切换修复有效。产物为 `XingGuang-iOS-32`（artifact ID `8635451446`，`22,777,323` 字节，保留至 2026-08-09）；真实 JavaScript 来源及代理媒体仍需 TrollStore 真机验收。

## 播放体验对齐

- 点播播放器现支持单集循环、5/15/30/60 分钟定时暂停、延长/取消定时器、当前进度设为片头、剩余时长设为片尾，以及按正序或倒序自动连播下一集。
- 点播历史继续使用既有 `opening`、`ending`、`revSort` 和 `scale` 字段；周期性进度保存会读取并保留这些设置，不新增数据库字段。
- 点播、直播和本地媒体均提供原始、16:9、4:3、填充和裁剪。默认比例与直播比例写入 iOS 偏好，并兼容 Android 备份的 `scale`、`scale_live`。
- 三个播放页面的左侧纵向手势调用 `UIScreen.brightness`，右侧通过系统 `MPVolumeView` 修改媒体音量；水平拖动不触发亮度或音量修改。
- 三个播放页面共用横向拖动跳转、双击播放/暂停和双指缩放手势。跳转目标限制在媒体有效时长内；缩放范围为 1x 到 5x，播放菜单可恢复为 1x。
- `MediaPlayer` 为系统框架，仅用于系统音量控件，不引入第三方二进制。Windows 无法编译或模拟这些 UIKit/MediaPlayer 行为，本批次须通过新的 iPhone/iPad、Release、IPA 和签名 CI；真实亮度、音量和三内核裁剪效果仍需 TrollStore 真机验收。

横向跳转与缩放边界已有纯逻辑单元测试；SwiftUI 多手势组合、双击命中以及 MPV/MDK/AVPlayer 三种画面承载视图的实际缩放仍须下一次 macOS CI 和 TrollStore 真机确认。

运行 `30217502376` 已通过手势边界单元测试、全部 iPhone/iPad 单元与 UI 测试、设备 Release、TrollStore IPA 结构和 ad-hoc 签名检查。产物为 `XingGuang-iOS-37`（artifact ID `8636317881`，`22,918,293` 字节，保留至 2026-08-09）；多指识别、双击命中和三内核画面缩放仍需 TrollStore 真机逐项验收。

- 播放画面外侧四分之一区域继续用于亮度和系统音量，中间二分之一区域识别超过 100pt 的垂直滑动。点播按当前正序/倒序切换相邻剧集，直播在当前分组切换相邻频道。
- 长按画面会临时切换到播放器设置中的默认倍速，松手恢复页面当前倍速；没有可跳转时长的直播流不启用该手势。
- 分区、距离、方向和正倒序映射已有纯逻辑测试；SwiftUI 长按释放、手势竞争和真实频道/剧集切换仍须下一次 macOS CI 与 TrollStore 真机确认。

运行 `30218024066` 已通过新增手势分区与选集方向测试、全部 iPhone/iPad 单元与 UI 测试、设备 Release、TrollStore IPA 结构和 ad-hoc 签名检查。产物为 `XingGuang-iOS-38`（artifact ID `8636458699`，`22,930,634` 字节，保留至 2026-08-09）；长按释放、外侧亮度/音量与中间换台/换集的触控竞争仍需 TrollStore 真机验收。

- 点播、直播和本地媒体的播放菜单提供播放信息与系统分享。信息页显示标题、实际内核、格式、URL 和请求头；Cookie 只列出名称，Cookie 与 Authorization 等鉴权 Header 不显示值。
- 分享通过 iOS `UIActivityViewController` 执行，仅传递标题与当前媒体 URL，不附加 Header 或 Cookie。HTTP URL 可分享给其他 App，本地文件由系统分享其缓存文件 URL。
- 三内核显示名称和分享载荷已有单元测试；iPad 分享面板锚点、外部 App 接收和本地大文件分享仍须下一次 macOS CI 与 TrollStore 真机确认。

运行 `30218561934` 已通过三内核标签、分享载荷与鉴权脱敏测试、全部 iPhone/iPad 单元与 UI 测试、设备 Release、TrollStore IPA 结构和 ad-hoc 签名检查。产物为 `XingGuang-iOS-39`（artifact ID `8636645112`，`22,992,050` 字节，保留至 2026-08-09）；iPad 分享面板、外部 App 接收和本地大文件分享仍需 TrollStore 真机验收。

- 点播详情页补充地区、导演、演员和当前站点；空字段不占用页面空间，长文本按多行展示。
- 片名提供当前站源再搜索入口，复用既有分页与搜索记录；简介提供系统剪贴板复制按钮。
- 本批次不新增搜索服务或并发请求，仍只访问用户已配置的当前站源；SwiftUI 页面与预填搜索须由下一次 macOS CI 验证。

运行 `30219170472` 已通过全部 iPhone/iPad 单元与 UI 测试、设备 Release、TrollStore IPA 结构和 ad-hoc 签名检查。产物为 `XingGuang-iOS-40`（artifact ID `8636797938`，`23,009,399` 字节，保留至 2026-08-09）；真实站源的片名再搜索结果和系统剪贴板行为仍需 TrollStore 真机验收。

## 多站点聚合搜索

- 搜索页在配置含多个可搜索站点时提供“全部站点/当前站点”选择；从详情页点击片名仍固定搜索该影片所属站点。
- 全部站点模式只访问未隐藏且允许搜索的站点，同时请求上限为 4。结果按配置站点顺序合并，以“站点 key + 影片 ID”去重；单站失败显示提示但保留其他站点结果，全部站点失败才进入错误状态。
- 聚合结果携带来源站点，后续详情、收藏、历史和播放解析均使用该来源，不会因首页当前站点不同而串线。取消搜索会取消仍在执行的子请求。
- 并发上限、结果顺序、去重、失败隔离、取消传播和来源站点持久化已有单元测试。本批次 Windows 主机无 Swift 工具链，仅完成静态差异检查；完整编译、iPhone/iPad 测试、设备 Release、IPA 和签名仍须 macOS CI 验证。

运行 `30246061357` 已通过新增聚合搜索测试、全部 iPhone/iPad 单元与 UI 测试、设备 Release、TrollStore IPA 结构和 ad-hoc 签名检查。产物为 `XingGuang-iOS-41`；真实多站点并发、部分站点超时提示和来源绑定播放仍需 TrollStore 真机验收。

## `parses` / `playUrl` 播放解析链

- `VodRepository` 的播放入口接收当前配置中的 `parses` 与 `flags`；API、JavaScript 和路由 Repository 均保留旧入口，既有测试替身和预览不会被迫实现新方法。
- 播放结果支持 Android 字段 `parse`、`jx`、`playUrl`、`jxFrom`、`flag` 和 `click`。`json:` 使用 JSON 解析器，`parse:` 选择具名解析器，其他非空 `playUrl` 作为 Web 解析前缀；没有显式解析器的普通网页进入 WKWebView 嗅探。
- type 1 JSON 解析器接受根级或 `data.url`，只接受 User-Agent、Referer 和 Cookie 播放 Header；配置与 App 网络策略继续通过同一 `HTTPClient` 生效。type 4 先按线路 flag 选择 JSON 解析器，失败后使用匹配的 type 0 Web 解析器或原页面嗅探。
- type 2/3 依赖 Android `BaseLoader`/JAR 扩展，iOS 返回明确不兼容错误。播放器核心仍只接收解析完成的媒体请求，不在 MPV、MDK 或 AVPlayer 内部重复执行解析链。
- 新增测试覆盖直接媒体、未知页面嗅探、Web 前缀、JSON 嵌套 URL、Header 白名单、具名不兼容解析器、线路匹配聚合、type 4 结果指令和 JavaScript `vipFlags`。Windows 无 Swift 工具链，完整编译与 IPA 验证仍须 macOS CI。

首次验证运行 `30248524082` 在 iPhone 测试步骤以 exit code 65 失败，后续 iPad、设备 Release 和 IPA 步骤均被跳过。静态复核发现线路匹配聚合测试错误地用 `parse=0` 构造了预期需要解析的结果；测试输入已改为 Android 语义要求的 `parse=1`，生产解析逻辑未改变，须通过下一次完整 CI 确认。

修复后运行 `30257596430` 已通过解析链测试、全部 iPhone/iPad 单元与 UI 测试、设备 Release、TrollStore IPA 结构和 ad-hoc 签名检查。产物为 `XingGuang-iOS-43`；真实 JSON 解析服务、Web 嗅探和 type 4 回退仍需 TrollStore 真机验收。

运行 `30215168139` 已通过新增播放器会话、持久化和备份测试、全部 iPhone/iPad UI 测试、设备 Release、IPA 结构和 ad-hoc 签名检查。产物为 `XingGuang-iOS-33`（artifact ID `8635726897`，`22,866,630` 字节，保留至 2026-08-09）；亮度、系统音量、定时暂停和三内核画面比例仍需 TrollStore 真机逐项验收。

## 缓存与全局 User-Agent

- 设置页的缓存项统计并清理 App 的 iOS `Caches` 目录，同时清空 `URLCache`。导入的本地媒体属于缓存，因此会被删除；SQLite、配置、收藏、历史和 UserDefaults 位于缓存目录之外，不参与清理。
- 播放器设置提供全局 User-Agent。API、JavaScript HTTP、直播/EPG、字幕/弹幕、网页嗅探和媒体播放请求共用“显式 Header 优先、全局 UA 缺省补充”的规则；配置 Header、站点 Header、直播源或频道 UA 不会被全局值覆盖。
- 备份同时写入 `ios.globalUserAgent` 和 Android 字段 `ua`，恢复 Android 备份时会把 `ua` 映射到 iOS 全局设置。本批次在 Windows 仅完成差异检查，须等待 macOS CI 编译、测试和 IPA 验证。

首次验证运行 `30215997513` 在 iPhone 编译阶段发现 JavaScript HTTP 请求头与响应头局部变量重名，iPad、Release 和 IPA 未执行。请求侧变量已改为 `requestHeaders`；该修复不改变 Header 合并和全局 UA 优先级，仍需新一轮完整 CI 确认。

修复后运行 `30216229525` 已通过全部 iPhone/iPad 单元与 UI 测试、设备 Release、TrollStore IPA 结构和 ad-hoc 签名检查。产物为 `XingGuang-iOS-35`（artifact ID `8635974723`，`22,895,448` 字节，保留至 2026-08-09）；清理真实缓存及真实站点/频道 UA 优先级仍需 TrollStore 真机验收。

## 版本与更新

- 设置页从 App Bundle 读取 `CFBundleShortVersionString` 和 `CFBundleVersion`，显示当前安装 IPA 的版本号与构建号。
- TrollStore 私人分发继续使用 GitHub Actions artifact 手动更新。iOS App 不在后台下载并替换自身，避免把 Android APK 自更新流程错误移植到 iOS。

运行 `30216711028` 已通过版本行 UI 断言、全部 iPhone/iPad 测试、设备 Release、TrollStore IPA 结构和 ad-hoc 签名检查。产物为 `XingGuang-iOS-36`（artifact ID `8636151881`，`22,896,793` 字节，保留至 2026-08-09）。
