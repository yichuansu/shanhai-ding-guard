# 山海守鼎（Shanhai Ding Guard）

横屏 Q 版休闲塔防：固定路径布塔、五行相克、可操控英雄，并可捕获异兽作为助手。题材取自《山海经》。单局产品意图约 3–5 分钟，时长尚未用关卡数据验证。

**状态：预制作（pre-production）。**

- 引擎族已于 2026-11-08 锁定为 Unity 6 LTS + URP 2D Renderer + C#。
- 目标平台：iOS、Android、微信小游戏（产品目标）。
- MVP 进度：登录 + 云存档。本地文件只做缓存。
- 阻塞项：标准 Unity 不能原生导出微信小游戏。方案 A–D 未选定，建议先评估 A（团结引擎）。选定前不生成完整工程。

产品设计由产品经理另行维护，不入库。`docs/` 只写技术约定。

## 文档

| 文档 | 内容 |
| --- | --- |
| [docs/TECH_STACK.md](docs/TECH_STACK.md) | 引擎族已锁定；三端目标；云存档 MVP；微信导出 A–D 未决 |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | 客户端分层、Auth / CloudSave、内容 schema、战斗循环 |
| [docs/MILESTONES.md](docs/MILESTONES.md) | M0–M6 可交付里程碑 |
| [docs/REPO_LAYOUT.md](docs/REPO_LAYOUT.md) | 当前目录与未来 `Assets/Game/` 布局 |

样例数据在 [content/examples/](content/examples/)。字段是形状说明，数值为空，不代表策划表。

## 以后如何打开工程

仓库里还没有 Unity / 团结引擎 / Cocos 工程，也没有 `.unity` 场景。微信导出方案 A–D 锁定之后，才会提交可打开的工程。届时根目录会出现所选工具链的工程文件（Unity 或团结引擎时，其中包含 `ProjectSettings/ProjectVersion.txt`）。

1. 安装该 PR 写明的编辑器版本。方案 A 用团结引擎，方案 D 以及未改写引擎族时用 Unity 6 LTS，并带上 Android、iOS 与 2D（URP）相关模块。方案 C 则不再是 Unity 工程。
2. 用对应 Hub 打开含工程设置的仓库根目录。
3. 本地缓存 `Library/`、`Temp/`、`Logs/`、`UserSettings/` 由 [.gitignore](.gitignore) 排除，不要提交。

在那之前，阅读文档和样例 JSON 即可。

## 下一步

1. 按 [docs/TECH_STACK.md](docs/TECH_STACK.md) 先评估方案 A（团结引擎），再书面选定微信导出 A、B、C 或 D。
2. 路径锁定前不生成完整工程。
3. 路径锁定后做登录与云存档 spike，再生成竖切工程。

## 贡献

版权归 Yichuan Su 所有，All Rights Reserved。见 [LICENSE](LICENSE)。

外部贡献默认不接收。变更请先与维护者确认范围。提交保持技术向：架构、schema、工具与工程，不把完整产品设计贴进仓库。
