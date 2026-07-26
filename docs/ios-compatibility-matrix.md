# 星光 Android / iOS 兼容矩阵

更新日期：2026-07-26

本矩阵以仓库 Android `mobile` 版本为基准，记录 iOS/iPadOS 15+ 客户端的实际状态。状态含义如下：

- **已对齐**：主要数据、行为和用户流程已实现。
- **iOS 等效实现**：使用 iOS 原生能力达到相同业务目的，交互或能力边界不同。
- **平台限制**：iOS 公共 API 或播放核心无法安全实现 Android 行为。
- **不在本轮范围**：主功能补完计划明确排除，或 Android 的附加设置尚未纳入 iOS 主功能范围。

CI 通过只证明编译、测试、IPA 结构和签名有效；真机媒体、摄像头、画中画及 AirPlay 仍以 TrollStore 验收为准。

## 页面与主流程

| Android 移动端功能 | iOS 状态 | iOS 实现或边界 |
| --- | --- | --- |
| 点播首页、站源切换、首页推荐 | 已对齐 | 点播 Tab 提供站源菜单、首页内容和响应式海报网格。 |
| 分类、筛选 | 已对齐 | 支持配置分类与筛选参数。 |
| 分类和搜索连续分页 | 不在本轮范围 | Repository 接受页码，但当前 iOS 页面只展示首批结果。 |
| 搜索 | 已对齐 | 支持当前站源关键字搜索和详情跳转。 |
| 搜索记录、热搜、搜索建议 | 不在本轮范围 | 当前 iOS 搜索页不保存关键词，也不提供热搜和建议页。 |
| 收藏 | 已对齐 | 点播和直播收藏写入 GRDB，重启后保留。 |
| 历史与继续观看 | 已对齐 | 保存集数、线路、进度和倍速，首页提供继续观看入口。 |
| 点播详情、线路、选集 | 已对齐 | 支持详情、线路和选集切换。 |
| 本地媒体文件 | iOS 等效实现 | 通过系统 Files 选择器导入缓存后，交给用户选择的 MPV、MDK 或 AVPlayer 播放。 |
| Android 文件夹/本地 HTTP 文件浏览 | 不在本轮范围 | iOS 使用系统 Files；未复制 Android 自建文件浏览器及 LAN 文件服务。 |
| 直播分组、频道、编号、收藏 | 已对齐 | 支持 JSON/M3U/TXT 与 JavaScript 动态直播源。 |
| EPG、日期、当前节目、回看 | 已对齐 | 支持 JSON、XMLTV、XMLTV.gz 和回看/时移模板。 |
| 直播备用线路与失败换线 | 已对齐 | 可手动选线，启用自动换线后按备用线路继续。 |
| 配置输入、文件导入、二维码 | iOS 等效实现 | 使用 SwiftUI、Files 与 AVFoundation 扫码；只接受验证后的配置。 |
| Android 投屏设备发现与控制 | iOS 等效实现 | AVPlayer 使用系统 AirPlay；不实现 Android DLNA/接收端协议，MPV/MDK 路径不承诺 AirPlay。 |
| Android 推送/接收媒体页面 | 不在本轮范围 | 未提供 Android LAN 推送接收服务。 |
| 崩溃详情与重启页 | 不在本轮范围 | iOS 依赖系统崩溃日志和 CI/设备日志。 |

## 数据源与网络

| 能力 | iOS 状态 | iOS 实现或边界 |
| --- | --- | --- |
| `type 0` XML API | 已对齐 | 支持首页、分类、搜索、详情和播放解析。 |
| `type 1` JSON API | 已对齐 | 保持 Android 字段默认语义。 |
| `type 4` 扩展 API | 已对齐 | 支持扩展请求和需嗅探播放结果。 |
| `type 3` JavaScript Spider | 已对齐 | QuickJS 串行运行，覆盖 Spider 方法、模块、Promise、local、HTTP 和加密桥。 |
| Android JAR Spider | 不在本轮范围 | iOS 明确返回 JAR 来源不兼容，不显示空白结果。 |
| Python Spider | 不在本轮范围 | 需逐源改写为 Swift/JavaScript 或使用独立兼容服务。 |
| Header、Cookie、重定向、超时、取消 | 已对齐 | App 网络统一由 URLSession 执行并分类错误。 |
| WebView 媒体嗅探 | iOS 等效实现 | WKWebView 观察网页媒体请求并合并 Cookie 后生成播放请求。 |
| JavaScript 本地代理 | iOS 等效实现 | 只绑定 `127.0.0.1`，仅向已初始化的 JS 来源路由受控请求。 |
| 配置 Header 注入 | 已对齐 | 覆盖 API、直播、EPG、字幕、弹幕和 JavaScript HTTP。 |
| 广告规则 | iOS 等效实现 | 覆盖 App 请求和 WKWebView；三种播放内核内部的媒体请求无法保证完全复现。 |
| DoH | 平台限制 | 保留配置字段；iOS 15 URLSession 无逐 App DNS 注入 API，使用设备系统 DNS/加密 DNS。 |

## 播放器

| Android 播放能力 | iOS 状态 | iOS 实现或边界 |
| --- | --- | --- |
| 多播放核心 | iOS 等效实现 | 提供 MPV、MDK、AVPlayer；分别对应 Android MPV、IJK 的扩展格式角色与 EXO 的系统播放角色。 |
| HLS、MP4/MOV | 已对齐 | 默认使用 AVPlayer。 |
| RTSP、RTMP、MKV、FLV、WebM、DASH | iOS 等效实现 | 选择 MPV 或 MDK 后由对应内核尝试播放，具体协议/编码仍须真机验证。 |
| 自动选核与格式失败回退 | iOS 等效实现 | 已移除自动模式；每个请求严格使用设置中选择的内核，失败时显示该内核错误。 |
| 播放、暂停、跳转、倍速 | 已对齐 | 点播、直播和本地媒体共用 PlayerSession。 |
| 进度、线路、集数和倍速恢复 | 已对齐 | 通过 GRDB history/track 语义保存。 |
| 内嵌音轨、视频轨、字幕轨 | 已对齐 | AVPlayer、MPV、MDK 适配器均向统一轨道接口提供选择能力。 |
| 外置字幕 | 已对齐 | 支持 SRT、WebVTT、ASS/SSA 和本地文件。 |
| 弹幕 | 已对齐 | 支持 Bilibili XML、带时间文本、开关和进度同步。 |
| 字幕字号与位置 | iOS 等效实现 | 使用 App 内字幕覆盖层设置。 |
| 后台音频 | iOS 等效实现 | AVAudioSession playback 模式；需真机确认系统行为。 |
| 画中画 | iOS 等效实现 | AVPlayer 使用系统 PiP；MPV/MDK 路径不提供。 |
| AirPlay | iOS 等效实现 | AVPlayer 使用系统外部播放；MPV/MDK 路径不提供。 |
| 亮度/音量滑动手势 | 不在本轮范围 | 使用 iOS 控制中心和系统音量；未实现页面手势。 |
| 定时停止、循环、片头片尾跳过 | 不在本轮范围 | 当前播放器未提供这些 Android 控件。 |
| 缩放比例、画面反转、跨类/倒序 | 不在本轮范围 | 当前播放器保持系统渲染和正常选集顺序。 |
| 强制软/硬解、隧道模式、AAC 优先 | 平台限制 | AVPlayer 不公开对应控制；MPV/MDK 当前固定优先 VideoToolbox，不保证与 Android 参数等价。 |
| Widevine、PlayReady、CENC ClearKey | 平台限制 | 返回专门 DRM 错误；不进行无法验证的回退。 |
| HLS AES 等内核原生加密 | iOS 等效实现 | 交给当前选择内核的原生支持范围处理。 |

## 设置与数据管理

| Android 设置项 | iOS 状态 | iOS 实现或边界 |
| --- | --- | --- |
| 点播配置、直播配置 | 已对齐 | 支持 URL、配置文件和二维码。 |
| 播放核心 | iOS 等效实现 | MPV / MDK / AVPlayer 分段选择，无自动模式。 |
| 无痕模式 | 已对齐 | 开启后不写播放历史。 |
| 直播线路自动选择 | 已对齐 | 控制失败后的备用线路切换。 |
| 默认倍速 | 已对齐 | 播放器设置中可调并持久化。 |
| 字幕大小、字幕位置、弹幕显示 | 已对齐 | 播放器设置与播放页均提供对应控制。 |
| 备份与恢复 | 已对齐 | 支持 Android 字段 JSON、`.bk.gz`、完整校验和事务替换。 |
| 壁纸、图片尺寸 | 不在本轮范围 | iOS 固定使用云白响应式界面。 |
| 缓存大小与清理 | 不在本轮范围 | 本地媒体位于系统可清理 Caches，当前无手动缓存管理页。 |
| 全局 User-Agent | 不在本轮范围 | 支持来源和频道 Header/UA，但未提供独立全局 UA 设置。 |
| 渲染方式、Libass、系统字幕样式 | 平台限制 | 使用 AVPlayer、MPV/Metal、MDK Surface 与 App 字幕覆盖层，无 Android 渲染器等价开关。 |
| 自动更新与版本页 | 不在本轮范围 | TrollStore IPA 由 GitHub Actions artifact 手动更新。 |

## 验收边界

- 自动化必须通过 Swift 单元测试、iPhone/iPad UI 启动、Release 设备构建、IPA 解包和 `codesign` 检查。
- TrollStore 真机必须分别验证 MPV、MDK、AVPlayer 的真实点播/直播和本地文件，并检查横竖屏、后台恢复、AVPlayer 画中画及 AirPlay。
- 真机未验证的项目不能仅凭 CI 标为“真机通过”；上表状态表示代码和自动化覆盖状态。
