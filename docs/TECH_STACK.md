# 技术选型

**决策日期：2026-11-08。**
**状态：引擎、v1 平台、MVP 进度、云后端、MVP 登录形态、首发发行范围均已锁定。** 前三项来源：工程负责人确认，产品经理复核（2026-11-08）。云后端、MVP 登录形态与首发发行范围由产品经理按用户决定锁定。

## 已锁定

| 项 | 决定 |
| --- | --- |
| 引擎 | **Unity 6 LTS + 2D（URP 2D Renderer / Unity 2D）+ C#** |
| v1 首发平台 | **仅 iOS + Android**。微信小游戏是二期（方案 D，已延后） |
| MVP 进度 | **登录 + 云存档**。账号上的云存档是进度来源，本地文件只做缓存 |
| 云后端 | **Unity Gaming Services（Authentication + Cloud Save）**。PlayFab 仅为应急，MVP 不并行评估 |
| MVP 登录 | **先游客 / 设备登录 + 云存档**。默认路径是 UGS Anonymous（Guest）→ Cloud Save。Apple / Google Sign-In 与账号绑定为 POST-MVP / M2+，不进 M1 验收 |
| 首发发行范围 | **海外 / 非大陆 iOS + Android**。不含中国大陆渠道。大陆 App Store 与国内安卓渠道为 phase 2+，不阻塞 M0/M1 |

微信小游戏已按方案 D 放到二期，不是仍在比较的 A–D。见下文。

在此锁定下的客户端组成：

- 渲染：URP，使用其 2D Renderer。M1 不必开 2D 光照。
- 语言：C#。
- 内容：源数据放仓库 `content/`。运行时目标是 Addressables。M1 允许先直接读 JSON TextAsset。
- 输入：新工程使用 Input System 处理触控。
- 商业化：Services 层预留广告与 Unity IAP。垂直切片不接 SDK。首发不含中国大陆渠道，本阶段不接国内渠道 SDK，大陆合规不进入 M0/M1。
- 进度：MVP 走 UGS Anonymous（游客 / 设备）登录，再写入 Cloud Save。见 [ARCHITECTURE.md](ARCHITECTURE.md)。

Unity 6.3 LTS 工程在仓库根目录（`6000.3.28f1`）。`IAuthService` / `ICloudSaveService` 的默认实现走游客路径。UGS SDK 仍由后续 spike 接入。本环境没有 Editor 时，工程是手写骨架，首次打开会重新导入。

## 云后端（LOCKED）

MVP 用现成的登录 + 玩家数据服务，不自建完整账号平台。供应商**已锁定**为 **Unity Gaming Services（Authentication + Cloud Save）**。登录和云存档成对使用，与 Unity 6 同一套服务。

**PlayFab**（认证 + Player Data）仅为应急（contingency），不是 MVP 的并行评估项。仅当已锁定的 UGS 登录或存档无法满足需求时，才另开决策改用 PlayFab。M0/M1 的 spike 只实现 UGS，不并行对接 PlayFab。

原评估顺序见工程负责人的 [Notion 提案](https://app.notion.com/p/412a33c747a981bb8b69ff360926c96e)。该页保留为提案记录；以本次锁定为准。

两台设备同时写入的冲突规则随 UGS spike 一起定，现在不锁。IAP 票据校验晚于这个 spike。

## 登录（LOCKED：游客 / 设备）

默认路径已锁定：**UGS Anonymous / Guest（设备）登录 → Cloud Save**。M0 的 `IAuthService` / `ICloudSaveService` stub 默认走这条路径。M1 验收只要求游客登录后能从云端恢复进度。

**Apple / Google Sign-In 与账号绑定（link）为 POST-MVP / M2+，不进 M1 验收**，也不阻塞 M1。iOS 若在该后置阶段提供第三方登录，需要同时提供 Sign in with Apple。具体登录按钮清单不在本文指定。

## 发行范围（LOCKED：海外 / 非大陆）

首发包**不含中国大陆渠道**。目标是海外 / 非大陆的 iOS 与 Android。大陆 App Store 与国内安卓渠道后置到 phase 2+。M0 与 M1 不以此为阻塞，本阶段不接入国内渠道 SDK，也不把大陆合规放进验收。

## 微信小游戏（二期，方案 D）

已选定方案 D：v1 用 Unity 交付 iOS 与 Android，微信小游戏放到二期。这是已延后的决定，不是仍在比较的 A–D，也不阻塞 Unity 工程。

方案 A（团结引擎）、B（双客户端）和 C（三端改 Cocos）不是当前待选项。v1 不评估它们，也不维护第二套客户端。标准 Unity 没有微信小游戏的原生导出；v1 不需要这条导出。二期启动时再定微信导出的具体工具。

Godot 与 Cocos Creator 不用于 v1。

## 其他仍开放的问题

这些不推翻上面的锁定，也不挡住 Unity 空工程。下列问题尚未回答，本文不代答。

1. 相生邻接是四向还是八向，加成作用在伤害还是攻击间隔？见 [ARCHITECTURE.md](ARCHITECTURE.md)。
2. 漏怪失败条件的规则 id 由策划表定义。工程只预留字段。
3. 英雄移动空间：沿路径、可建造区，或固定站位？M3 用桩。
4. 运行时直接读 JSON，还是导入为 ScriptableObject 再打 Addressables？源 JSON 入库评审，M1 可直读。

数值（造价、生命、倍率、tick 赫兹、参考分辨率）另表填写。

## 对仓库的含义

- 引擎、v1 平台、云存档要求、云后端供应商（Unity Gaming Services Authentication + Cloud Save）、MVP 登录（UGS Anonymous / Guest → Cloud Save），以及首发发行范围（海外 / 非大陆 iOS + Android，不含中国大陆渠道）均为 LOCKED。PlayFab 仅为应急，不进入 MVP 并行评估。Apple / Google Sign-In 与账号绑定为 POST-MVP / M2+。大陆 App Store 与国内安卓渠道为 phase 2+。
- Unity 6.3 LTS 空工程在仓库根目录，含 `ProjectSettings/` 与 `Packages/`，不提交 `Library/`。
- 工程内已有 `IAuthService` / `ICloudSaveService` stub，默认走 UGS Anonymous / Guest（设备）→ Cloud Save。下一步把桩换成 UGS SDK，再做 M1 竖切。不并行对接 PlayFab，不把平台登录列为 M1 阻塞项，也不把大陆渠道或大陆合规列为 M0/M1 阻塞。
