# 技术选型（PROPOSED）

状态：**提案，未锁定。** 本文比较 Unity、Cocos Creator 与 Godot，给出暂定默认项和必须先回答的问题。锁定之前不要生成完整引擎工程。

暂定默认（仅在「首发为 iOS + Android 原生、不要求微信小游戏」这一假设下）：

**Unity 6 LTS + URP 2D Renderer，语言 C#。** 内容用 Addressables。应用内购买用 Unity IAP，激励视频以后再接，二者都不进入第一张垂直切片。

若微信小游戏或国内 HTML5 是硬需求，暂定默认改为 **Cocos Creator 3.x + TypeScript**。Godot 4 作为第三选项保留，不作为默认。

## 决策标准

按这个顺序判断，避免先选引擎再倒推平台。

| 顺序 | 标准 | 在本项目里看什么 |
| --- | --- | --- |
| 1 | 首发平台 | iOS + Android 商店包，还是必须同时或首先上微信小游戏 / 国内 HTML5 |
| 2 | 2D 横屏工作流 | 固定路径、塔格、横屏 HUD、安全区能否在编辑器里直接摆 |
| 3 | 战斗模拟 | 玩法以固定 tick 为权威、表现按帧插值。倍速是模拟时钟，不是帧率碰运气 |
| 4 | 内容管线 | 塔、敌人、波次、关卡以数据驱动。源文件可评审，运行时再导入 |
| 5 | 商业化 SDK | 激励视频与 IAP 能落到目标商店 / 渠道。MVP 可以只有接口 |
| 6 | 包体与中低端机 | 休闲单局，启动与内存比画面上限更重要 |
| 7 | 语言与招聘 | C#（Unity / Godot）或 TypeScript（Cocos）哪边是实现垂直切片的人 |
| 8 | 许可证与后续迁移 | 引擎授权、以及 M1 之后换引擎等于重写切片 |

美术是 Q 版 2D。三条技术路线都能做 2D，美术风格不单独决定引擎。风格指南由美术总监并行编写，不入库。

## 三条路线

### Unity 6 LTS + URP 2D Renderer + C#（暂定默认）

适用：首发包是 iOS 与 Android 原生，横屏，内容需要分组加载。

提案中的组成：

- 渲染：URP，使用其 2D Renderer。M1 不必开 2D 光照。
- 语言：C#。
- 内容：源数据放仓库 `content/`。运行时目标是 Addressables。M1 允许先直接读 JSON TextAsset，避免被 Addressables 分组堵住切片。
- 输入：新工程使用 Input System 处理触控。此为工程习惯，不是玩法规则。
- 商业化：Services 层预留广告与 Unity IAP。垂直切片不接 SDK。
- 存档：先写 `Application.persistentDataPath` 本地文件。

选择它的理由：原生双端导出、URP 2D、Addressables、IAP 与后续广告都有现成路径，和「固定路径塔防 + 本地存档」匹配。

需要接受的代价：微信小游戏不是这条路线的一等目标。Unity 工程的 `Library/` 很大，所以本仓库在选型锁定前不提交工程，锁定后的工程 PR 也只提交源码与 `ProjectSettings` / `Packages`，不提交 `Library/`。

### Cocos Creator 3.x + TypeScript（小游戏硬需求时的默认）

适用：必须做微信小游戏，或国内 HTML5 与原生要共用一套 TypeScript。

提案中的组成：Creator 3.x、TypeScript、资源系统 / Asset Bundle、微信小游戏构建。IAP 与广告按渠道另接，不假设有与 Unity IAP 对等的单一插件。

选择它的理由：微信小游戏与国内 HTML5 的工具链比 Unity、Godot 直接。玩法层（tick 模拟、数据表、横屏 UI）可以按同一份架构文档实现。

需要接受的代价：若最终只上 App Store 与 Google Play，就要单独评估原生 IAP、广告与包体，不能因为「也许要做小游戏」提前把切片写在 Creator 里。

### Godot 4（备选，非默认）

适用：团队明确要开源引擎、2D 工程要轻，且首发只做原生、可以自己接商店与广告。

提案中的组成：Godot 4.x，GDScript 或 C#。导出 Android / iOS。内容仍用仓库里的 JSON，加载方式换成 Godot 的资源路径。

需要接受的代价：国内广告、渠道 IAP、微信小游戏都没有与前两者同级的现成生态。招聘与中间件也更窄。在开放问题 1 和 2 有答案之前，不把 Godot 升为默认。

## 暂定结论

```text
若首发 = iOS + Android 原生，且微信小游戏不是 M1–M6 的交付范围
    → Unity 6 LTS + URP 2D Renderer + C#
否则若微信小游戏或国内 HTML5 是硬需求
    → Cocos Creator 3.x + TypeScript
否则
    → 保持 PROPOSED，不生成工程
```

Godot 4 只在团队书面选择「开源引擎 + 原生 + 自建商店接入」时启用。

Addressables、Unity IAP、激励视频都依附于 Unity 提案。改选 Cocos 或 Godot 时，这三项改成该引擎的等价物，架构文档里的 Services 边界不变。

## 开放问题

锁定引擎前需要产品 / 制作人书面回答：

1. **微信小游戏是否是首发或同期必须交付？** 是则暂定默认改为 Cocos Creator 3.x。
2. **首发是否只有 iOS + Android 原生？** 国内安卓多渠道会影响广告与 IAP，但不改变「先本地存档」的 MVP。
3. **后端 MVP 要做什么？** 提案是：对局与进度只存本地；服务端以后只接 IAP 票据与权益。若 MVP 就要账号、云存档或排行，Services 与里程碑要改，引擎仍可按上面的平台规则选。
4. 相生邻接是四向还是八向，加成作用在伤害还是攻击间隔？这是数据规则，不改变引擎选择。见 [ARCHITECTURE.md](ARCHITECTURE.md)。
5. 漏怪失败条件的规则 id（鼎耐久、生命次数或其它）由策划表定义。工程只预留字段。
6. 英雄移动空间：沿路径、可建造区自由移动，或固定站位？M3 用桩，规则待定。
7. 内容在运行时直接读 JSON，还是导入为 ScriptableObject（或 Cocos / Godot 等价资产）再打包？提案：源 JSON 入库评审，M1 可直读，目标管线再导入。

数值（造价、生命、倍率、tick 赫兹、参考分辨率）不在本文锁定。

## 对仓库的含义

- 本 PR 只添加文档、样例 JSON、`tools/` 占位和 Unity 向 `.gitignore`。
- 下一步是回答开放问题 1–3，把本节状态从 PROPOSED 改成已锁定，再开后续 PR 生成工程。
- 在那之前不添加 `Packages/manifest.json`、`.unity` 场景、`.meta` 或 `Library/`。
