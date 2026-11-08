# 山海守鼎（Shanhai Ding Guard）

横屏 Q 版休闲塔防：固定路径布塔、五行相克、可操控英雄，并可捕获异兽作为助手。题材取自《山海经》。单局产品意图约 3–5 分钟，时长尚未用关卡数据验证。

**状态：预制作（pre-production）。** 2026-11-08 已锁定：

- 引擎：Unity 6.3 LTS（`6000.3.28f1`）+ 2D（URP 2D Renderer）+ C#。工程在仓库根目录。
- v1 首发平台：仅 iOS 与 Android。微信小游戏是二期（方案 D，已延后），不是待选的 A–D。
- MVP 进度：登录 + 云存档。本地文件只做缓存。
- 云后端：**Unity Gaming Services（Authentication + Cloud Save）**。PlayFab 仅为应急，MVP 不并行评估。
- MVP 登录：**先游客 / 设备登录 + 云存档**。默认路径是 UGS Anonymous（Guest）→ Cloud Save。Apple / Google Sign-In 与账号绑定为 POST-MVP / M2+，不进 M1 验收。
- 首发发行范围：**海外 / 非大陆 iOS + Android**。不含中国大陆渠道。大陆 App Store 与国内安卓渠道为 phase 2+，不阻塞 M0/M1。

栈已锁定。Unity 工程在仓库根目录，与 `docs/`、`content/` 并列。

产品设计由产品经理另行维护，不入库。`docs/` 只写技术约定。

## 文档

| 文档 | 内容 |
| --- | --- |
| [docs/TECH_STACK.md](docs/TECH_STACK.md) | 引擎、平台、MVP 进度、云后端（UGS）、游客登录与海外首发已锁定；PlayFab 仅应急；Apple/Google 与大陆渠道为后置；微信为二期方案 D |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | 客户端分层、Auth / CloudSave、内容 schema、战斗循环 |
| [docs/MILESTONES.md](docs/MILESTONES.md) | M0–M6 可交付里程碑 |
| [docs/REPO_LAYOUT.md](docs/REPO_LAYOUT.md) | 根目录 Unity 工程与 `Assets/Game/` 布局 |

样例数据在 [content/examples/](content/examples/)。字段是形状说明，数值为空，不代表策划表。

## 文档与协作

仓库内 `docs/` 只保留技术约定。产品与协作材料在仓库外：

- [产品设计 Canvas](https://cursor.com/canvas/store-1838654e-7bc4-415b-9f4d-c229663f31b0/cffcba2f-711b-4a64-9493-b9a2e46f5528)
- [项目管理 Notion](https://app.notion.com/p/412a33c747a9814d84b2ea89ffa04b3b)
- [云存档方案草案](https://app.notion.com/p/412a33c747a981bb8b69ff360926c96e)

## 如何打开 Unity 工程

工程在仓库根目录。用 Unity Hub 打开含 `ProjectSettings/ProjectVersion.txt` 的这一层。

- 编辑器：Unity **6.3 LTS**，`6000.3.28f1`，changeset `8f082d2fe476`。
- 包：URP `17.3.0`（2D Renderer）与 Input System，见 `Packages/manifest.json`。
- Hub 模块：Android Build Support（含 SDK、NDK、OpenJDK）和 iOS Build Support。打 iOS 包需要 macOS。2D / URP 来自 `Packages/`，不是单独的 Hub 模块。

打开后：

1. 首次打开会重新导入并生成 `Library/`。本环境没有 Unity Editor，骨架是按上述版本手写的。
2. 不要提交 `Library/`、`Temp/`、`Obj/`、`Logs/`、`UserSettings/`。规则在 [.gitignore](.gitignore)。
3. 打开 `Assets/Game/Scenes/Boot.unity` 并 Play。Boot 只走 UGS Anonymous / Guest（设备）桩，再按该玩家 id 读云存档桩，然后进入 `Hub`。
4. 横屏：允许左右横屏，关闭竖屏。默认游戏视图 1920×1080，这不是已锁定的参考分辨率。
5. 包名占位是 `com.yichuansu.shanhaidingguard`。首发是海外 / 非大陆商店。

`Assets/Game/` 按架构分层。`IAuthService` 与 `ICloudSaveService` 在 `Assets/Game/Services/`。`Assets/Settings/` 是 URP 2D 管线资产。

## 登录与云存档桩

默认路径与文档一致：**UGS Anonymous / Guest（设备）→ Cloud Save**。当前没有引用 `com.unity.services.authentication` 或 `com.unity.services.cloudsave`。PlayFab 仅为应急，MVP 不并行评估，工程里没有 PlayFab 包。

| 路径 | 现在 | Spike 替换成 |
| --- | --- | --- |
| `Assets/Game/Services/Auth/IAuthService.cs` | 主入口 `SignInGuestAsync` | `AuthenticationService.SignInAnonymouslyAsync` |
| `Assets/Game/Services/Auth/DevAuthService.cs` | 本地游客 id `dev.guest`，不联网 | 同上，使用 UGS PlayerId |
| `Assets/Game/Services/CloudSave/ICloudSaveService.cs` | 按游客 id 读写 `shdg.save` | `CloudSaveService.Instance.Data.Player` |
| `Assets/Game/Services/CloudSave/FakeRemoteCloudSaveService.cs` | 假远端 + 本地缓存 | 同上，键 `shdg.save` |

Apple / Google Sign-In 与账号绑定是 POST-MVP / M2+，不进 M1 验收，Boot 不调用。没有玩家 id 时，本地缓存不是进度。

## 下一步

1. 在本机用 Unity `6000.3.28f1` 打开仓库根目录，确认 Boot 进入 Hub。
2. 把桩换成 UGS Anonymous 登录与 Cloud Save。同一游客写入一份最小档案，另一次会话读回。冲突规则写回 `docs/TECH_STACK.md`。不并行评估 PlayFab，也不把 Apple / Google 列为 M1 阻塞项。
3. 再做 M1 竖切。微信小游戏、大陆 App Store 与国内安卓渠道留在 phase 2+，不作为 M0/M1 阻塞。

## 贡献

版权归 Yichuan Su 所有，All Rights Reserved。见 [LICENSE](LICENSE)。

外部贡献默认不接收。变更请先与维护者确认范围。提交保持技术向：架构、schema、工具与工程，不把完整产品设计贴进仓库。
