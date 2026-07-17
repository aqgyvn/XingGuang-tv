# Android Studio 运行调试说明

## 环境要求

- Android Studio：建议使用 Koala 或更新版本。
- JDK：Android Studio 自带 JBR 17 即可。
- Android SDK：需要安装 Android SDK Platform 35。
- Gradle：项目使用 Gradle Wrapper，首次同步会下载 Gradle 8.7。

## 打开方式

1. 在 Android Studio 中选择 `Open`。
2. 选择项目根目录 `D:\xingkong`。
3. 等待 Gradle Sync 完成。
4. 选择 `app` 运行配置。
5. 连接 Android 设备或启动模拟器，点击 `Run` 或 `Debug`。

## 命令行验证

在已配置 JDK 和 Android SDK 的环境中执行：

```powershell
.\gradlew.bat :app:assembleDebug
```

构建产物位于：

```text
app\build\outputs\apk\debug\app-debug.apk
```

如果命令行提示 `JAVA_HOME is not set`，请先安装 JDK 17，或在 Android Studio 中使用自带 JBR 17 打开项目。若 Gradle Sync 提示缺少 Android SDK Platform 35，请按提示安装对应 SDK。

## 当前功能范围

- 首页显示“星光影视”。
- 支持输入视频 URL。
- 支持进入原生 `VideoView` 播放页调试。

后续影视源、列表、搜索、收藏、播放历史等业务功能，需要在确认接口和交互需求后继续补充。
