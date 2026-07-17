# 星光 TV

星光 TV 是一个面向 Android 手机、平板和电视设备的视频播放客户端，支持点播、直播、搜索、收藏、播放记录及多种播放设置。

当前版本：`5.5.7`

## 主要功能

- 支持手机端和 Android TV 端界面
- 支持点播、直播、搜索与换源
- 支持播放记录、收藏和多线路配置
- 支持字幕、音轨、画面比例及播放器设置
- 支持本地配置、网络配置和自定义数据源

## 环境要求

- Android Studio
- JDK 17
- Android SDK
- 最低 Android 版本：Android 8.0（API 26）

首次构建前，请在项目根目录创建 `local.properties`，并配置本机 Android SDK 路径：

```properties
sdk.dir=C:\\Android\\Sdk
```

## 构建项目

Windows 环境可使用 Gradle Wrapper 构建手机端 ARM64 调试包：

```powershell
.\gradlew.bat :app:assembleMobileArm64_v8aDebug
```

更多构建和本地环境说明请查看：

- [Android Studio 配置](docs/android-studio.md)
- [星光 TV 构建说明](docs/xingguang-rebuild.md)
- [版本管理说明](docs/release-version.md)
- [配置说明](docs/CONFIG.md)
- [直播配置说明](docs/LIVE.md)

## 项目说明

本项目基于 [FongMi/TV](https://github.com/FongMi/TV) 进行开发和维护。

本项目仅用于学习、研究和个人使用。使用者应确保所使用的数据源和内容符合所在地法律法规，并自行承担使用责任。

## 开源许可

本项目采用 [GNU General Public License v3.0](LICENSE.md) 开源许可。
