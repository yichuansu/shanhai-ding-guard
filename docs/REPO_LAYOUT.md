# 仓库布局

本文件描述仓库根目录。文档、内容样例与 Unity 6.3 LTS 工程并列。引擎、v1 平台（仅 iOS + Android，首发为海外 / 非大陆）、云存档，以及云后端（Unity Gaming Services）已于 2026-11-08 锁定。

## 现在

```text
/
├── README.md
├── LICENSE                 # 专有权利声明，All Rights Reserved
├── .gitignore              # Unity 工程忽略规则；docs/、content/、tools/ 入库
├── docs/
│   ├── TECH_STACK.md
│   ├── ARCHITECTURE.md
│   ├── MILESTONES.md
│   ├── REPO_LAYOUT.md
│   └── UGS_SETUP.md          # Dashboard Project ID、包版本、Dev/Fake 开关
├── content/
│   └── examples/           # schema 形状样例，数值为 null
│       ├── tower_jin.json
│       ├── enemy_dangkang.json
│       └── level_jizhou_01_waves.json
├── tools/                  # 未来的校验与导入脚本，目前只有 .gitkeep
├── Assets/
│   ├── Game/               # 代码、asmdef、Boot / Hub / Battle
│   └── Settings/           # URP 2D Renderer 与管线资产
├── Packages/
└── ProjectSettings/
```

约定：

- `docs/` 是技术文档。产品设计全文不放这里。
- `content/examples/` 给程序和策划对齐字段名。正式数值进 M1 时写入正式表，或在替换样例时于提交说明里写清楚。
- `tools/` 预留给 JSON 校验、以及把 JSON 导入引擎资产的脚本。本 PR 不放可执行脚本。
- Unity 工程在仓库根目录。缓存目录被 `.gitignore` 排除。v1 只有这一套 Unity 工程。
- 若工程尚未在 Unity Editor 中导入过，首次打开会重新生成 `Library/`。不要提交 `Library/`。

## Unity 工程（仓库根目录）

游戏代码在 `Assets/Game/`。正式内容表仍按下面的 `content/` 子目录在后续里程碑添加。v1 只有这一套 Unity 工程。

```text
/
├── content/                      # 源 JSON，评审用。导入物不反向覆盖这里
│   ├── examples/
│   ├── towers/                   # 正式表，M1 起按需添加
│   ├── enemies/
│   ├── levels/
│   ├── heroes/
│   └── elements/                 # 相生相克表，M2
├── tools/
│   └── import/                   # JSON 校验、生成 ScriptableObject 或 Addressables 分组
├── Assets/
│   └── Game/
│       ├── App/                  # 启动与组合根
│       ├── Presentation/
│       │   ├── Hud/              # 战斗横屏 HUD
│       │   └── MetaHub/          # M6 局外壳
│       ├── Gameplay/
│       │   ├── CombatSimulation/
│       │   ├── Path/
│       │   ├── Wave/
│       │   ├── Towers/
│       │   ├── Hero/
│       │   └── Capture/
│       ├── Meta/
│       │   ├── Progress/
│       │   ├── Shanhaijing/
│       │   └── Economy/
│       ├── Services/
│       │   ├── Auth/             # IAuthService、UgsAuthService、DevAuthService
│       │   ├── CloudSave/        # ICloudSaveService、UgsCloudSaveService、假远端
│       │   ├── Ugs/              # UgsConfig 与 Resources/UgsConfig.asset（Project ID 占位）
│       │   ├── Ads/
│       │   ├── Iap/
│       │   └── Analytics/
│       └── Content/              # 导入后的资产与加载器，不是源 JSON
├── ProjectSettings/
├── Packages/
└── AddressableAssetsData/        # 启用 Addressables 之后；平台构建状态 bin 已忽略
```

`Assets/Game/` 与架构四层同名，避免把 UI、模拟和 SDK 放进同一个脚本目录。

源数据留在仓库根的 `content/`。`Assets/Game/Content/` 只放导入结果和加载代码。这样 JSON 的 diff 不混在 `.meta` 里。

以下内容在工程 PR 里仍然不要提交：

- `Library/`、`Temp/`、`Obj/`、`Logs/`、`UserSettings/`、`Build/`
- Addressables 的 `addressables_content_state.bin` 与 `ServerData/`
- 任何只为占位而建、离开编辑器就无法合并的场景实验

`docs/`、`content/`、`tools/` 留在根上。CloudSave 的本地缓存和离线假远端都写在运行时目录，不作为仓库里的另一套进度源。有 Dashboard Project ID 时，`UgsAuthService` 做 UGS Anonymous / Guest，再经 `ICloudSaveService` 交给 `UgsCloudSaveService`。未配置时用 Dev/Fake。Apple / Google Sign-In 与账号绑定不放进 M1。微信小游戏是二期（方案 D），v1 不另建客户端目录。
