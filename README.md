# BiangLauncher

属于你的 macOS 启动台。只显示你勾选的应用，拖动即可排序。

开发者 **BiangMax** · **StudioBiangMax**

当前版本：**v1.0.0** · [下载 Release](https://github.com/BiangMax/BiangLauncher/releases/latest)

## 使用

1. 打开 `dist/BiangLauncher.app`。也可以把它拖到“应用程序”文件夹。
2. 点击“选择应用”，搜索并勾选需要的应用，再点击“完成”。未勾选的应用不会出现在启动台或启动台搜索结果中。
3. 点击图标启动应用。将一个图标拖到另一个图标上，松开后保存新顺序。点击“排序”还可用左右按钮调整位置。
4. 按 Esc 或点击其他应用收起；点击 Dock 图标重新呼出。若要退出后仍保留 Dock 入口，右键 Dock 图标 → 选项 → 在程序坞中保留。
5. 点击右下角快捷键录制自己的组合键。默认是 `⌥ Space`；录制时使用包含 `⌘`、`⌥` 或 `⌃` 的组合，Esc 取消，Delete 停用。若被占用，会提示并保留旧设置。

### 文件夹

- 将一个应用拖到另一个图标中间并停留满 **1 秒**，看到“松开以创建文件夹”后松手。未满 1 秒松手仍执行普通排序；离开目标或滚动时会重新计时。
- 将应用拖到已有文件夹上停留 1 秒，看到提示后松手即可加入。文件夹本身也可拖动排序。
- 点击文件夹打开；点击左上角返回或按 Esc 返回启动台。文件夹内可启动、搜索和排序应用。
- 右键文件夹可重命名或解散；右键其中的应用可“移出文件夹”。解散保留全部应用，文件夹剩下一个应用时自动还原为独立图标。
- 启动台搜索会包含文件夹内的已选应用；搜索期间拖动不创建文件夹。暂不支持嵌套文件夹。
- 文件夹名称、内容和排序会自动保存，现有配置会兼容读取。

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
- `dist/BiangLauncher-1.0.0-macOS-arm64.zip`：应用压缩包。

Swift Package 可直接用 Xcode 打开 `Package.swift`。直接运行 Swift Package 可调试界面；日常使用请运行打包后的 `.app`，以获得完整的应用身份、Dock 图标和启动行为。

`scripts/test.sh` 在仅安装 Command Line Tools 的环境中用轻量断言运行器执行核心测试，并使用临时配置文件验证实际拖动模型的排序、一秒悬停和滚动重置行为，不修改本机应用选择。完整 Xcode 环境也可用 `swift test` 执行核心 XCTest 测试用例。

构建脚本使用 `--disable-sandbox` 避免受限开发环境中的 SwiftPM 嵌套沙盒错误，只影响构建进程。程序没有第三方依赖，不联网，不使用辅助功能或屏幕录制权限。全局快捷键通过系统 RegisterEventHotKey API 注册。

## 技术与数据

- SwiftUI 界面，AppKit 浮动面板、Dock/菜单栏入口、应用图标与启动。
- 深色半透明背景、细描边和淡青色交互高亮；参考系统启动台放大的原生应用图标，启动台和文件夹内均为每行 7 个。
- 打开时淡入并轻微放大，收起时淡出并轻微缩小；开启系统“减少动态效果”后保留简短淡变。
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

## 版本规则

版本格式为 `v主版本.次版本.补丁版本`。小改动和问题修复递增补丁号，例如 `v1.0.0` → `v1.0.1`；较大改动和功能更新递增次版本号并重置补丁号，例如 `v1.0.1` → `v1.1.0`。

`Resources/Info.plist` 的 `CFBundleShortVersionString` 是应用版本的唯一来源，菜单与构建压缩包名称自动读取它。发布前同步 README 版本、验证记录与 Release 标签；提交信息遵守 Conventional Commits。
