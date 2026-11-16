# 本机验证 · 0.1.0

验证日期：2026-11-16。

环境：macOS 27.0（26A428），arm64，Swift 6.4 / macOS 27 SDK，Xcode Command Line Tools。

## 构建及核心逻辑

- Release 构建成功，`.app` 与 `.zip` 已生成。
- `file` 确认主程序为 Mach-O 64-bit arm64，无需 Rosetta。
- `otool -L` 确认仅依赖系统框架和 Swift 系统运行库。
- ad-hoc 签名通过 `codesign --verify --deep --strict` 检查。
- `bash scripts/test.sh`：6 项测试，0 失败。
- 覆盖初始空选择、勾选去重与移除、双向排序、排序边界、配置保存恢复、损坏配置报错。

## 原生界面实测

- 应用库扫描出 125 个条目，能搜索 Bambu Studio 和明日方舟。
- 勾选这两个应用后，启动台仅展示这两个应用。
- 搜索未勾选的 Safari 显示无结果，没有泄露应用库中的其他条目。
- 拖动 Bambu Studio 到明日方舟的位置，实际界面顺序变为明日方舟、Bambu Studio。
- 退出并重开应用后，已勾选列表恢复；排序结果同时检查了磁盘配置。
- 快捷键录制可从 `⌥ Space` 改为 `⌃⌥ B`，设置成功后已恢复 `⌥ Space`。
- 从 Bambu Studio 发送默认快捷键后可看到启动台。
- 点击 Bambu Studio 图标后，系统应用清单确认其进程从未运行变为运行。
- 检查了空状态、应用库、两应用启动台、搜索无结果、排序和快捷键录制布局。

## 验证范围

这是本机开发版本，未做 Developer ID 签名或 Apple 公证。仅验证了上述 macOS 27 / Apple Silicon 环境；未覆盖多显示器、全屏 Space、所有第三方应用或其他 macOS 版本。

自动化工具无法稳定直接访问系统 Dock，因此 Dock 图标的真实鼠标点击仍适合人工补充验收；应用已实现标准 Dock 身份和 `applicationShouldHandleReopen` 回调，并验证了重新打开应用后的面板恢复。
