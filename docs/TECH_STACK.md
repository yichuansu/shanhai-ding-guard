# 技术选型

**决策日期：2026-11-08。**
**状态：三项已锁定。** 来源：工程负责人。云后端供应商仍是提案。

## 已锁定

| 项 | 决定 |
| --- | --- |
| 引擎 | **Unity 6 LTS + 2D（URP 2D Renderer / Unity 2D）+ C#** |
| v1 首发平台 | **仅 iOS + Android** |
| MVP 进度 | **登录 + 云存档**。账号上的云存档是进度来源，本地文件只做缓存 |

微信小游戏不在 v1。见下文「微信小游戏（v1 范围外）」。

在此锁定下的客户端组成：

- 渲染：URP，使用其 2D Renderer。M1 不必开 2D 光照。
- 语言：C#。
- 内容：源数据放仓库 `content/`。运行时目标是 Addressables。M1 允许先直接读 JSON TextAsset。
- 输入：新工程使用 Input System 处理触控。
- 商业化：Services 层预留广告与 Unity IAP。垂直切片不接 SDK。国内安卓多渠道只影响这些 SDK 的后续选择。
- 进度：MVP 走 Auth 与 CloudSave。见 [ARCHITECTURE.md](ARCHITECTURE.md)。

本提交不生成 Unity 工程。栈已锁定，**下一次 PR 创建可打开的 Unity 6 LTS 空工程**。

## 云后端（PROPOSED）

MVP 用现成的登录 + 玩家数据服务，不自建完整账号平台。供应商**未锁定**。

提案的评估顺序：

1. **PlayFab**（认证 + Player Data）。Unity 有现成 SDK，登录和云存档在同一个服务里，贴近 iOS / Android 的 MVP。
2. **Firebase Auth + Cloud Save**（或 Firestore 上的玩家文档）。登录渠道成熟，存档需要自己定文档形状。
3. **薄自定义 API**。只提供登录会话和按账号读写一份档案。在前两者的登录渠道或数据模型不够时再采用。

M0/M1 的 spike 在这三者里选定一个，把结论写回本文。两台设备同时写入的冲突规则随 spike 一起定，现在不锁。IAP 票据校验晚于这个 spike。

iOS 若提供第三方登录，需要同时提供 Sign in with Apple。具体登录按钮清单不在本文指定。

## 微信小游戏（v1 范围外）

v1 只交付 iOS 与 Android。微信小游戏延后，不进入 v1 里程碑。

标准 Unity 没有微信小游戏的原生导出。该限制不阻塞 v1。v1 不评估团结引擎、不维护 Cocos / Web 第二客户端，也不把导出方案 A–D 当作当前开放决策。

若 v1 之后把微信小游戏列为硬需求，再单独立项。届时再评估团结引擎、双客户端或更换引擎。

Godot 与 Cocos Creator 不用于 v1。

## 其他仍开放的问题

这些不推翻上面三项锁定，也不挡住 Unity 空工程。

1. 云后端供应商：PlayFab、Firebase 或薄 API，spike 选定。
2. 相生邻接是四向还是八向，加成作用在伤害还是攻击间隔？见 [ARCHITECTURE.md](ARCHITECTURE.md)。
3. 漏怪失败条件的规则 id 由策划表定义。工程只预留字段。
4. 英雄移动空间：沿路径、可建造区，或固定站位？M3 用桩。
5. 运行时直接读 JSON，还是导入为 ScriptableObject 再打 Addressables？源 JSON 入库评审，M1 可直读。

数值（造价、生命、倍率、tick 赫兹、参考分辨率）另表填写。

## 对仓库的含义

- 本提交把引擎、v1 平台和云存档要求标为 LOCKED，并把云后端标为 PROPOSED。
- 下一步 PR：生成 Unity 6 LTS 空工程（含 `ProjectSettings/` 与 `Packages/`），不提交 `Library/`。
- 空工程落地后，在该工程里做登录与云存档 spike，再做 M1 竖切。
