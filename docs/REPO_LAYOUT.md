# 仓库布局

本文件描述两套目录：现在就有的文档与数据，以及微信导出方案 A–D 锁定之后才创建的工程。引擎族已于 2026-11-08 锁定为 Unity 6 LTS。当前提交只创建第一套。

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
│   └── REPO_LAYOUT.md
├── content/
│   └── examples/           # schema 形状样例，数值为 null
│       ├── tower_jin.json
│       ├── enemy_dangkang.json
│       └── level_jizhou_01_waves.json
└── tools/                  # 未来的校验与导入脚本，目前只有 .gitkeep
```

约定：

- `docs/` 是技术文档。产品设计全文不放这里。
- `content/examples/` 给程序和策划对齐字段名。正式数值进 M1 时写入正式表，或在替换样例时于提交说明里写清楚。
- `tools/` 预留给 JSON 校验、以及把 JSON 导入引擎资产的脚本。本 PR 不放可执行脚本。
- 没有 `Assets/`、没有 `.meta`、没有 `.unity` 场景。这是故意的，方便先合并文档。

## 以后（路径锁定之后）

完整工程在方案 A–D 书面选定后才放到仓库根目录，与 `docs/`、`content/` 并列。缓存目录继续被 `.gitignore` 排除。下面是方案仍沿 Unity / 团结引擎时的目录。方案 C 会改掉 `Assets/` 这一支。方案 B 才会另加微信客户端目录，现在不建。

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
│       │   ├── Auth/
│       │   ├── CloudSave/
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

`docs/`、`content/`、`tools/` 留在根上。Godot 不在导出方案里。微信导出未选定前，不提交 `Assets/` 工程。CloudSave 的本地缓存写在运行时目录，不作为仓库里的另一套进度源。
