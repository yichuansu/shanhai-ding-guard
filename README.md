# 山海守鼎（Shanhai Ding Guard）

横屏 Q 版休闲塔防：固定路径布塔、五行相克、可操控英雄，并可捕获异兽作为助手。题材取自《山海经》。单局产品意图约 3–5 分钟，时长尚未用关卡数据验证。

**状态：预制作（pre-production）。** 2026-11-08 已锁定三项：

- 引擎：Unity 6 LTS + 2D（URP 2D Renderer）+ C#。
- v1 首发平台：仅 iOS 与 Android。微信小游戏是二期（方案 D，已延后），不是待选的 A–D。
- MVP 进度：登录 + 云存档。本地文件只做缓存。

云后端供应商仍是提案（首选 Unity Gaming Services 的 Authentication + Cloud Save，备选 PlayFab）。本仓库目前是文档与内容样例。栈已锁定，下一次 PR 创建可打开的 Unity 工程。

产品设计由产品经理另行维护，不入库。`docs/` 只写技术约定。

## 文档

| 文档 | 内容 |
| --- | --- |
| [docs/TECH_STACK.md](docs/TECH_STACK.md) | 三项锁定；云后端提案（UGS 优先，PlayFab 备选）；微信为二期方案 D |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | 客户端分层、Auth / CloudSave、内容 schema、战斗循环 |
| [docs/MILESTONES.md](docs/MILESTONES.md) | M0–M6 可交付里程碑 |
| [docs/REPO_LAYOUT.md](docs/REPO_LAYOUT.md) | 当前目录与未来 `Assets/Game/` 布局 |

样例数据在 [content/examples/](content/examples/)。字段是形状说明，数值为空，不代表策划表。

## 以后如何打开 Unity 工程

仓库里还没有 Unity 工程，也没有 `.unity` 场景。下一次 PR 会提交可打开的 Unity 6 LTS 工程（根目录出现 `ProjectSettings/ProjectVersion.txt`）。届时：

1. 安装该 PR 写明的 Unity 6 LTS 编辑器版本，并带上 Android、iOS 与 2D（URP）相关模块。
2. 用 Unity Hub 打开含 `ProjectSettings/` 的仓库根目录。
3. 本地缓存 `Library/`、`Temp/`、`Logs/`、`UserSettings/` 由 [.gitignore](.gitignore) 排除，不要提交。

在那之前，阅读文档和样例 JSON 即可。

## 下一步

1. 用后续 PR 生成 Unity 6 LTS 空工程（URP 2D Renderer + C#）。该 PR 提交源码与 `ProjectSettings` / `Packages`，不提交 `Library/`。
2. 在该工程上做登录与云存档 spike，并在 Unity Gaming Services 与 PlayFab 中选定供应商。
3. 再做 M1 竖切。微信小游戏留在二期，不进入这些 PR。

## 贡献

版权归 Yichuan Su 所有，All Rights Reserved。见 [LICENSE](LICENSE)。

外部贡献默认不接收。变更请先与维护者确认范围。提交保持技术向：架构、schema、工具与工程，不把完整产品设计贴进仓库。
