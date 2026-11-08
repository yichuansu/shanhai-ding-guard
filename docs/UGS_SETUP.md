# UGS 游客登录与 Cloud Save

状态：SDK 已接上 `IAuthService` / `ICloudSaveService`。仓库里的 Project ID 是占位符，不是 Dashboard 上的工程。多设备冲突规则仍是 **OPEN**。

本说明只覆盖 M1 的游客路径。不含 Apple / Google、PlayFab、中国大陆渠道 SDK。

## 包

`Packages/manifest.json`：

| 包 | 版本 | 用途 |
| --- | --- | --- |
| `com.unity.services.authentication` | 3.8.1 | `SignInAnonymouslyAsync` |
| `com.unity.services.cloudsave` | 3.4.2 | `CloudSaveService.Instance.Data.Player` |

传递依赖由锁文件钉住：`com.unity.services.core` 1.18.0、`com.unity.nuget.newtonsoft-json` 3.2.2。版本下限是 Unity 2022.3，可在 Unity 6.3（`6000.3.28f1`）里安装。首次用 Editor 打开时会解析这些包并可能改写 `packages-lock.json`。

## 配置资产

`Assets/Game/Services/Ugs/Resources/UgsConfig.asset`

| 字段 | 现在 | 含义 |
| --- | --- | --- |
| `projectId` | `REPLACE_WITH_DASHBOARD_PROJECT_ID` | Dashboard 上的 Project ID，形如 `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `environmentName` | `production` | Dashboard Environment。空值按 `production` |
| `forceOfflineStubs` | `0` | 为 1 时即使填了 Project ID 也走 Dev/Fake |

占位符、空字符串和全零 GUID 都不算已配置。Boot 此时用 `DevAuthService` 与 `FakeRemoteCloudSaveService`。

SDK 实际使用的工程 id 来自 Player Settings 的 `cloudProjectId`（`Application.cloudProjectId`），不是这张资产单独决定的。两边都要是同一个 GUID。`UgsSession` 发现不一致就拒绝初始化。

## Dashboard（需要人做）

1. 在 [Unity Dashboard](https://cloud.unity.com) 新建或打开工程。不要把虚构的 id 写进仓库。
2. 打开 Authentication。M1 只用 Anonymous。不要为这个 spike 打开 Apple 或 Google。
3. 打开 Cloud Save。
4. 确认环境 `production` 存在（新建工程默认有）。
5. 复制 Project ID。
6. 贴进 `UgsConfig.asset` 的 `projectId`。
7. 在 Unity 里把同一个 id 链到工程：Project Settings → Services，或直接写入 `ProjectSettings/ProjectSettings.asset` 的 `cloudProjectId`。`organizationId` 由链接过程填写。当前仓库里这两项是空的。
8. 打开 `Assets/Game/Scenes/Boot.unity` 并 Play。控制台应出现 `services=ugs`，随后是一条非 `dev.guest` 的 player id，以及 `origin=Remote` 或首次的 `NotFound`。

匿名登录会在本机留下 session token。`SignOutAsync` 使用 `SignOut(false)`，不清除该 token，下次游客登录仍是同一个 PlayerId。

## 如何改回 Dev/Fake

任选其一：

- `UgsConfig.forceOfflineStubs` 设为 1。
- Player Settings → Scripting Define Symbols 增加 `SHDG_FORCE_DEV_SERVICES`。
- 把 `projectId` 留在占位符。这是仓库的默认。

`GameServices.Configure` 打日志前会把模式记在 `GameServices.Mode`（`ugs` 或 `dev`）。`ConfigureStubs()` 仍可直接装上 Dev/Fake。

## 存档键

键名保持 `shdg.save`（`CloudSaveKeys.PlayerProfile`）。值是 `PlayerProfileJson` 写出的整段文本。

Cloud Save 3.4 的玩家数据键说明是：只含字母、数字、连字符和下划线，最长 255。`shdg.save` 含有点号。本 spike 不改键。Editor 里第一次 `SaveAsync` 若返回校验错误，需要另开一次决策再改 `CloudSaveKeys`，不要在未验证时换名。

## 冲突（OPEN）

两台设备同时写同一游客档案的规则**没有锁定**。

`UgsCloudSaveService.SaveAsync` 的注释里有一条临时行为：调用不带 writeLock 的 `SaveAsync(IDictionary<string, object>)`，后写覆盖整份 `shdg.save`。下一次读取看到的是服务端当前值；`Item.Modified` 是该值的 updated_at。代码不比较时间戳，也不按字段合并。这不是已接受的产品规则。

## 本环境没有 Unity Editor

写这些实现的环境不能打开 Unity，也没有跑通 Dashboard 往返。C# 只在本机用与上述 SDK 签名对齐的桩编译过。第一次真实编译、链接 Project ID、以及同一游客写入再读回，都要在 Unity `6000.3.28f1` 里做。
