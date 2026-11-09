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
| [docs/UGS_SETUP.md](docs/UGS_SETUP.md) | UGS 包、Project ID 占位、Dev/Fake 开关、冲突规则仍 OPEN |

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
3. 打开 `Assets/Game/Scenes/Boot.unity` 并 Play。未填 Dashboard Project ID 时，Boot 走 Dev/Fake，然后进入 `Hub`。填上并链到工程后走 UGS Anonymous 与 Cloud Save。见 [docs/UGS_SETUP.md](docs/UGS_SETUP.md)。
4. 横屏：允许左右横屏，关闭竖屏。战斗参考 1920×1080。HUD 安全区为顶约 120px、底约 100px、左右各约 120px。战场 16×9 世界单位，正交相机 size 4.5。
5. 包名占位是 `com.yichuansu.shanhaidingguard`。首发是海外 / 非大陆商店。

`Assets/Game/` 按架构分层。`IAuthService` 与 `ICloudSaveService` 在 `Assets/Game/Services/`。`Assets/Settings/` 是 URP 2D 管线资产。

## 登录与云存档

默认路径：**UGS Anonymous / Guest（设备）→ Cloud Save**。`Packages/manifest.json` 引用 `com.unity.services.authentication` 3.8.1 与 `com.unity.services.cloudsave` 3.4.2。PlayFab 仅为应急，工程里没有 PlayFab 包。

`Assets/Game/Services/Ugs/Resources/UgsConfig.asset` 的 `projectId` 仍是 `REPLACE_WITH_DASHBOARD_PROJECT_ID`。这不是真实工程。未配置时 Boot 使用 Dev/Fake，游戏仍可离线进 Hub。

| 路径 | 作用 |
| --- | --- |
| `Assets/Game/Services/Auth/UgsAuthService.cs` | `SignInGuestAsync` → `AuthenticationService.SignInAnonymouslyAsync` |
| `Assets/Game/Services/Auth/DevAuthService.cs` | 离线游客 id `dev.guest` |
| `Assets/Game/Services/CloudSave/UgsCloudSaveService.cs` | `CloudSaveService.Instance.Data.Player`，键 `shdg.save` |
| `Assets/Game/Services/CloudSave/FakeRemoteCloudSaveService.cs` | 离线假远端 + 本地缓存 |
| `Assets/Game/App/GameServices.cs` | 有 Project ID 时选 UGS，否则选 Dev/Fake |

改回桩：`UgsConfig.forceOfflineStubs`，或脚本定义符号 `SHDG_FORCE_DEV_SERVICES`。步骤在 [docs/UGS_SETUP.md](docs/UGS_SETUP.md)。

Apple / Google Sign-In 与账号绑定是 POST-MVP / M2+，不进 M1 验收，Boot 不调用。没有玩家 id 时，本地缓存不是进度。多设备冲突规则仍是 OPEN。

## 下一步

1. 在本机用 Unity `6000.3.28f1` 打开仓库根目录，确认未填 Project ID 时 Boot 以 `services=dev` 进入 Hub。
2. 按 [docs/UGS_SETUP.md](docs/UGS_SETUP.md) 创建 Dashboard 工程，启用 Authentication（Anonymous）与 Cloud Save，把真实 Project ID 贴进 `UgsConfig` 和 `cloudProjectId`。同一游客写入一份最小档案，另一次会话读回。
3. 冲突规则仍 OPEN。临时后写覆盖只写在 `UgsCloudSaveService` 的注释里，确认后再写回 `docs/TECH_STACK.md`。
4. 再做 M1 竖切。微信小游戏、大陆 App Store 与国内安卓渠道留在 phase 2+，不作为 M0/M1 阻塞。

## 贡献

版权归 Yichuan Su 所有，All Rights Reserved。见 [LICENSE](LICENSE)。

外部贡献默认不接收。变更请先与维护者确认范围。提交保持技术向：架构、schema、工具与工程，不把完整产品设计贴进仓库。
