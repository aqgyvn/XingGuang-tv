# 资源响应与恢复修复（5.7.29 / 5729，同版本修订包）

## 已落地

- `SourceResponse` 仅用于宿主管理的资源 API：先检查 HTTP 状态，再判定空响应、HTML、JSON 对象。有效的空列表仍然是正常结果，XML 资源仍走 XML 解析。
- GET 遇到短暂连接/读超时、502/503/504 或空响应时最多再请求一次；每次重建 Call、关闭响应。保留请求头、参数；POST、403、HTML、格式错误以及含 Retry-After 的响应不主动重放。
- `Result.fromJsonChecked/fromTypeChecked` 与 `SiteViewModel` 保留异常分类，避免网络/格式异常被静默转换成“没有影片”；首页可重试，单站列表可显示错误。
- 修正 `RequestInterceptor` 将已经转义的 auth 再次转义的问题，并将追加参数放到 fragment 之前；仍按原主机限定保存的参数。
- DoH 网络异常/解析异常回退系统 DNS；显式 hosts 映射保持优先，别名使用全部解析地址。
- 封面补全或可选首页推荐失败时保留已经获得的数据。
- 固定异步任务自己的 Future，主线程发布前再次检查任务编号，防止旧请求覆盖新页面。

## 验证

- `:catvod:testDebugUnitTest`：14 tests，0 failures，0 errors；包含本机 MockWebServer 的真实 HTTP 往返。
- `:app:assembleMobileArm64_v8aDebugAndroidTest`：构建通过。
- MuMu Android 15，`127.0.0.1:16384`：11 项设备端回归通过，设备内 NanoHTTPD 提供本地故障响应，实际经过 XgHttp/SourceResponse/Result。
- 设备测试涵盖 503 恢复、空响应恢复、永久空响应上限、HTML、403、POST 不重放、XML、有效空列表、BOM、错误数据结构、正常资源。
- Debug UI 抽样：首页/搜索/流映 4K 详情加载成功，《无可替代》出现视频画面。此项不是所有站源回归。
- Release 构建成功、APK v2 签名验证通过、覆盖安装成功，未卸载或清除用户数据。

```powershell
$env:JAVA_HOME='C:\Program Files\Microsoft\jdk-21.0.11.10-hotspot'
.\gradlew.bat :catvod:testDebugUnitTest :app:assembleMobileArm64_v8aDebug :app:assembleMobileArm64_v8aDebugAndroidTest --no-daemon
.\android-sdk\platform-tools\adb.exe -s 127.0.0.1:16384 shell am instrument -w com.xingguang.video.test/com.fongmi.android.tv.SourceRegressionRunner
.\gradlew.bat :app:assembleMobileArm64_v8aRelease --no-daemon
```

日志：`work/source-tests.log`、`work/source-device-tests.log`、`work/source-fix-live.log`、`work/source-release-build.log`。
截图：`work/source-fix-playback.png`。

## 仍存在的原始站源故障

1. 枫眠 4K：外部 `AppGet` 插件调用 `appcms.4ksj.app:443` 仍连接失败，随后内部解析空字符串；本机 DNS 同样解析为 `111.92.242.202`，curl 直连也失败。这说明问题并非仅发生于播放器。
2. 曼波动漫：新模拟器日志仍出现 `AppGet.h` 收到 HTML 后尝试 JSONObject 解析，插件自己捕获后返回空列表。
3. 外部插件独立发起的请求及插件内部吞掉的异常不经过宿主的 SourceResponse。此补丁没有修改远端插件，不把其合法空列表强行当作网络异常，也没有替换站源为其他网站。

结论：宿主中可复现的恢复/数据丢弃/错误混淆问题已修正且经过测试；上面两个外部站源尚未恢复，接口或插件适配仍待处理。未宣称全站源修复完成。

## 修订包

- APK：`D:/xingkong/output/XingGuang-5.7.29-source-fix-arm64-release.apk`
- SHA-256：`C7D56622C6B0E29C8682163EBFC637FF4B6675BEB760CA53F5864351DD5C1220`
- 保留原 `XingGuang-5.7.29-arm64-release.apk`，避免同版本不同内容混淆。
