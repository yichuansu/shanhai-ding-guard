# 技术选型

**决策日期：2026-11-08。**
**状态：三项已锁定。** 来源：工程负责人确认，产品经理复核（2026-11-08）。云后端供应商仍是提案。

## 已锁定

| 项 | 决定 |
| --- | --- |
| 引擎 | **Unity 6 LTS + 2D（URP 2D Renderer / Unity 2D）+ C#** |
| v1 首发平台 | **仅 iOS + Android**。微信小游戏是二期（方案 D，已延后） |
| MVP 进度 | **登录 + 云存档**。账号上的云存档是进度来源，本地文件只做缓存 |

微信小游戏已按方案 D 放到二期，不是仍在比较的 A–D。见下文。

在此锁定下的客户端组成：

- 渲染：URP，使用其 2D Renderer。M1 不必开 2D 光照。
- 语言：C#。
- 内容：源数据放仓库 `content/`。运行时目标是 Addressables。M1 允许先直接读 JSON TextAsset。
- 输入：新工程使用 Input System 处理触控。
- 商业化：Services 层预留广告与 Unity IAP。垂直切片不接 SDK。国内安卓多渠道只影响这些 SDK 的后续选择。
- 进度：MVP 走 Auth 与 CloudSave。见 [ARCHITECTURE.md](ARCHITECTURE.md)。

本提交不生成 Unity 工程。栈已锁定，**下一次 PR 创建可打开的 Unity 6 LTS 空工程**。

## 云后端（PROPOSED）

MVP 用现成的登录 + 玩家数据服务，不自建完整账号平台。供应商**未锁定**。顺序来自工程负责人的 [Notion 提案](https://app.notion.com/p/412a33c747a981bb8b69ff360926c96e)。

提案的评估顺序：

1. **Unity Gaming Services（Authentication + Cloud Save）**。首选。与 Unity 6 同一套服务，登录和云存档成对使用。
2. **PlayFab**（认证 + Player Data）。备选。UGS 的登录渠道或存档模型不够时再评估。

M0/M1 的 spike 按这个顺序选定一个，把结论写回本文。两台设备同时写入的冲突规则随 spike 一起定，现在不锁。IAP 票据校验晚于这个 spike。

iOS 若提供第三方登录，需要同时提供 Sign in with Apple。具体登录按钮清单不在本文指定。

## 微信小游戏（二期，方案 D）

已选定方案 D：v1 用 Unity 交付 iOS 与 Android，微信小游戏放到二期。这是已延后的决定，不是仍在比较的 A–D，也不阻塞 Unity 工程。

方案 A（团结引擎）、B（双客户端）和 C（三端改 Cocos）不是当前待选项。v1 不评估它们，也不维护第二套客户端。标准 Unity 没有微信小游戏的原生导出；v1 不需要这条导出。二期启动时再定微信导出的具体工具。

Godot 与 Cocos Creator 不用于 v1。

## 其他仍开放的问题

这些不推翻上面三项锁定，也不挡住 Unity 空工程。

1. 云后端供应商：首选 Unity Gaming Services（Authentication + Cloud Save），备选 PlayFab。spike 选定。
2. 相生邻接是四向还是八向，加成作用在伤害还是攻击间隔？见 [ARCHITECTURE.md](ARCHITECTURE.md)。
3. 漏怪失败条件的规则 id 由策划表定义。工程只预留字段。
4. 英雄移动空间：沿路径、可建造区，或固定站位？M3 用桩。
5. 运行时直接读 JSON，还是导入为 ScriptableObject 再打 Addressables？源 JSON 入库评审，M1 可直读。

数值（造价、生命、倍率、tick 赫兹、参考分辨率）另表填写。

## 对仓库的含义

- 本提交把引擎、v1 平台和云存档要求标为 LOCKED，并把云后端标为 PROPOSED。
- 下一步 PR：生成 Unity 6 LTS 空工程（含 `ProjectSettings/` 与 `Packages/`），不提交 `Library/`。
- 空工程落地后，在该工程里做登录与云存档 spike，再做 M1 竖切。
