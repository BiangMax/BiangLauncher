# 项目约定

- 提交信息严格使用 Conventional Commits。
- 公开仓库：提交和发布前检查密码、令牌、私钥、个人绝对路径等敏感内容。用户授权公开的提交身份是 BiangMax <2409114327@qq.com>。
- 完成修改后先交用户验收，用户确认提交/推送或发布后再执行对应操作。
- 版本格式使用 vX.Y.Z，首个正式版为 v1.0.0。小改动/修复递增 Z（如 v1.0.1），较大改动/功能更新递增 Y 并将 Z 归零（如 v1.1.0）。
- 应用版本以 Resources/Info.plist 的 CFBundleShortVersionString 为准。发布时同步 README、验证记录及 GitHub Release 标签，运行 bash scripts/test.sh 和 bash scripts/build.sh。
- Release 上传对应版本的 arm64 ZIP 与 SHA-256 校验文件。明确说明当前使用 ad-hoc 签名且尚未 Apple 公证。
