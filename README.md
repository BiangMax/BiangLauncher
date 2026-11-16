# BiangLauncher

属于你的 macOS 启动台。只显示你勾选的应用，拖动即可排序。

开发者 **BiangMax** · **StudioBiangMax**

## 使用

1. 打开 `dist/BiangLauncher.app`。也可以把它拖到“应用程序”文件夹。
2. 点击“选择应用”，搜索并勾选需要的应用，再点击“完成”。未勾选的应用不会出现在启动台或启动台搜索结果中。
3. 点击图标启动应用。将一个图标拖到另一个图标上，松开后保存新顺序。点击“排序”还可用左右按钮调整位置。
4. 按 Esc 或点击其他应用收起；点击 Dock 图标重新呼出。若要退出后仍保留 Dock 入口，右键 Dock 图标 → 选项 → 在程序坞中保留。
5. 点击右下角快捷键录制自己的组合键。默认是 `⌥ Space`；录制时使用包含 `⌘`、`⌥` 或 `⌃` 的组合，Esc 取消，Delete 停用。若被占用，会提示并保留旧设置。

菜单栏图标也可以开关启动台；右键显示菜单。`⌘ ,` 打开应用选择，`⌘ Q` 完全退出。应用搜索框按 Return 打开首个匹配项。

扫描范围：`/Applications`、`~/Applications`、`/System/Applications`、系统 CoreServices 的 Applications 子目录。其他位置的应用可通过“添加应用…”选取。刷新不会擅自更改已选列表。已移动或卸载的已选应用会保留占位，供你取消选择或重新添加。

## 构建

需要 Apple Silicon Mac 和支持 Swift 6.0 或更新版本的 Xcode Command Line Tools / Xcode。

```sh
bash scripts/build.sh
bash scripts/test.sh
open dist/BiangLauncher.app
```

产物：

- `dist/BiangLauncher.app`：原生 arm64 应用。
- `dist/BiangLauncher-0.1.0-macOS-arm64.zip`：应用压缩包。

Swift Package 可直接用 Xcode 打开 `Package.swift`。直接运行 Swift Package 可调试界面；日常使用请运行打包后的 `.app`，以获得完整的应用身份、Dock 图标和启动行为。

`scripts/test.sh` 在仅安装 Command Line Tools 的环境中用轻量断言运行器执行测试；完整 Xcode 环境也可用 `swift test` 执行同一组 XCTest 测试用例。

构建脚本使用 `--disable-sandbox` 避免受限开发环境中的 SwiftPM 嵌套沙盒错误，只影响构建进程。程序没有第三方依赖，不联网，不使用辅助功能或屏幕录制权限。全局快捷键通过系统 RegisterEventHotKey API 注册。

## 技术与数据

- SwiftUI 界面，AppKit 浮动面板、Dock/菜单栏入口、应用图标与启动。
- 深色半透明背景、细描边和淡青色交互高亮；原生应用图标。
- 根据应用数量自动调整弹窗高度；拖动使用窗口内部手势，显示移动预览和目标高亮，在松手时更新顺序。
- 配置以 JSON 原子写入，勾选、排序、自定义位置和快捷键跨重启保留。
- 配置位置：`~/Library/Application Support/StudioBiangMax/BiangLauncher/preferences.json`。
- 如果配置损坏，报告错误并保留原文件，不静默覆盖。
- 文件路径标识应用。移动应用后需重新添加新位置。

项目声明最低 macOS 14，目标使用环境为 macOS 27 / Apple Silicon。其他系统版本需要单独验证。

## 签名和分发

当前构建使用本机 ad-hoc 签名，适合本机使用；未使用 Developer ID 签名或 Apple 公证。若要给其他 Mac 分发正式版本，需要 Apple Developer 账号、Developer ID 签名及公证；不要关闭系统安全保护。仓库内容不包含任何开发者证书或账号信息。

源码仓库：[BiangMax/BiangLauncher](https://github.com/BiangMax/BiangLauncher)。开源许可证尚未指定；Copyright © 2026 StudioBiangMax。

## 源码结构

| 路径 | 用途 |
| --- | --- |
| `Sources/LauncherCore` | 配置、选择与排序逻辑 |
| `Sources/BiangLauncher` | 原生界面、应用发现、快捷键、窗口生命周期 |
| `Tests/LauncherCoreTests` | 选择隔离、双向排序、持久化和损坏配置测试 |
| `Resources` | 应用元数据 |
| `scripts` | 构建、图标生成及测试 |

原生 API 参考：[NSWorkspace](https://developer.apple.com/documentation/appkit/nsworkspace)、[SwiftUI 拖放](https://developer.apple.com/documentation/swiftui/drag-and-drop)。

本机验证记录见 `docs/VERIFICATION.md`。
