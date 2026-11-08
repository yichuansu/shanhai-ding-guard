# 技术选型（LOCKED）

**决策日期：2026-11-08。**
**状态：已锁定。**

引擎锁定为 **Unity 6 LTS + 2D / URP 2D Renderer + C#**。内容用 Addressables。应用内购买用 Unity IAP，激励视频以后再接。二者都不进入第一张垂直切片。

本次不生成 Unity 工程。空工程放到后续 PR，只提交源码与 `ProjectSettings` / `Packages`。

Cocos Creator 3.x 与 Godot 4 **本次不采用**。仅当微信小游戏日后成为硬需求时，才重新打开引擎选择；届时优先评估 Cocos Creator 3.x。在那之前工程只走 Unity。

## 已锁定的组成

- 渲染：URP，使用其 2D Renderer。M1 不必开 2D 光照。
- 语言：C#。
- 内容：源数据放仓库 `content/`。运行时目标是 Addressables。M1 允许先直接读 JSON TextAsset，避免被 Addressables 分组堵住切片。
- 输入：新工程使用 Input System 处理触控。此为工程习惯，玩法规则仍以数据为准。
- 商业化：Services 层预留广告与 Unity IAP。垂直切片不接 SDK。
- 存档：先写 `Application.persistentDataPath` 本地文件。

锁定理由：首发按 iOS 与 Android 原生推进。URP 2D、Addressables、Unity IAP 与后续广告都有现成路径，和固定路径塔防、本地存档匹配。微信小游戏不是当前硬需求。

接受的代价：微信小游戏不是这条路线的一等目标。Unity 工程的 `Library/` 很大，工程 PR 不提交 `Library/`。

## 本次不采用

### Cocos Creator 3.x + TypeScript

暂不采用。它适合微信小游戏或国内 HTML5 与原生共用 TypeScript 的情况。当前首发不把微信小游戏当作硬需求，因此不把垂直切片写在 Creator 上。

若微信小游戏日后成为硬需求，重新评估 Cocos，并单独立项迁移。在那之前不维护第二套工程。

### Godot 4

暂不采用。Godot 4 能做开源、较轻的 2D 原生导出，但国内广告、渠道 IAP 与招聘都弱于 Unity。引擎已锁定为 Unity，Godot 不并行。微信小游戏这条重开条件优先评估 Cocos，不自动改选 Godot。

## 锁定时看过的标准

这些标准留作决策记录。它们不再是未选引擎的比较表。

| 顺序 | 标准 | 锁定时的判断 |
| --- | --- | --- |
| 1 | 首发平台 | 按 iOS + Android 原生推进。微信小游戏不是当前硬需求 |
| 2 | 2D 横屏工作流 | URP 2D Renderer 能摆固定路径、塔格、横屏 HUD 与安全区 |
| 3 | 战斗模拟 | C# 里做固定 tick 权威模拟，表现按帧插值 |
| 4 | 内容管线 | JSON 入库评审，运行时目标为 Addressables |
| 5 | 商业化 SDK | Unity IAP 与后续激励视频留在 Services，M1 不接 |
| 6 | 包体与中低端机 | 休闲单局，启动与内存优先于画面上限 |
| 7 | 语言 | C# |
| 8 | 迁移成本 | M1 之后换引擎等于重写切片，所以在生成工程前锁定 |

美术是 Q 版 2D。风格指南由美术总监并行编写，不入库。风格不单独决定引擎。

## 仍开放的问题

下面各项不推翻 2026-11-08 的引擎锁定。

1. **微信小游戏若日后成为硬需求**，再重开选型，优先评估 Cocos Creator 3.x。当前不是硬需求。
2. **首发商店范围。** 国内安卓多渠道会影响广告与 IAP 的具体 SDK，存档仍先本地。
3. **后端 MVP。** 约定：对局与进度只存本地；服务端以后接 IAP 票据与权益。若 MVP 就要账号、云存档或排行，改 Services 与里程碑，引擎仍是 Unity。
4. 相生邻接是四向还是八向，加成作用在伤害还是攻击间隔？见 [ARCHITECTURE.md](ARCHITECTURE.md)。
5. 漏怪失败条件的规则 id（鼎耐久、生命次数或其它）由策划表定义。工程只预留字段。
6. 英雄移动空间：沿路径、可建造区自由移动，或固定站位？M3 用桩，规则待定。
7. 内容在运行时直接读 JSON，还是导入为 ScriptableObject 再打 Addressables？源 JSON 入库评审，M1 可直读，目标管线再导入。

数值（造价、生命、倍率、tick 赫兹、参考分辨率）另表填写，不在本文锁定。

## 对仓库的含义

- 本文把引擎标为 LOCKED。仓库仍只有文档、样例 JSON、`tools/` 占位和 Unity 向 `.gitignore`。
- 下一步是后续 PR 生成真实 Unity 6 LTS 工程。
- 工程落地前不添加 `Packages/manifest.json`、`.unity` 场景、`.meta` 或 `Library/`。
