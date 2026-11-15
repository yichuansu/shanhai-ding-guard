# 山海守鼎 · Godot 工程

捕获异兽当塔的肉鸽塔防。本目录是 Godot 重制版的工程根目录。上一级的 Unity 工程只作参考，不再开发。

- 引擎：Godot **4.7.2**（GDScript，静态类型），渲染器 Compatibility
- 基准分辨率：1920×1080，`canvas_items` + `expand`，横屏
- 平台顺序：Windows / macOS / Steam Deck → iOS / Android

## 运行

```bash
# 首次或改了 class_name 之后：导入工程，生成全局类缓存
godot --headless --path godot --import

# 打开编辑器
godot --path godot -e

# 无头测试
godot --headless --path godot --script res://tests/run_tests.gd

# 平衡模拟：每张战场 × 每种双异兽阵容
godot --headless --path godot --script res://tools/simulate_battles.gd
```

灰盒操作：路线图上点亮着的节点前进。战斗中先点下方阵容选中异兽，再点空鼎位部署；点已部署的鼎位收回（返还一半灵气）；敌人血量低于 25% 时出现金色"可收"圈，点它消耗镇鼎符捕获。

## 分层

```
scenes/   表现与输入（Node、绘制、HUD）      ──┐ 读状态、提交意图
autoload/ 局外流程（Game）与内容单例（Content） │
run/      一局：路线图、阵容、经济、存档字段    │
meta/     跨局：图鉴、统计、设置                │
sim/      守鼎战权威模拟（10Hz tick）         ◄─┘
content/  数据定义（Resource）与 .tres 内容
core/     随机流、时钟、五行关系、阵容实例
services/ 本地存档（以后加云存档）
```

依赖只能向下：

| 层 | 可以依赖 | 不可以依赖 |
| --- | --- | --- |
| `core/` | 无 | 其他所有层 |
| `content/` | `core/` | `sim/`、`run/`、场景 |
| `sim/` | `core/`、`content/` | Node、输入、渲染、`autoload/`、`run/` |
| `run/`、`meta/` | `core/`、`content/` | 场景、`autoload/` |
| `autoload/` | 以上全部、`services/` | 具体场景脚本 |
| `scenes/` | 全部 | — |

`sim/`、`run/`、`meta/` 都是 `RefCounted`，不进场景树，所以测试和平衡工具能在无头模式下直接跑。

## 关键约定

**确定性。** 所有随机都走 `RngStream`。一局一个主种子，路线图用 `map:<州>`、每场战斗用 `battle:<州>:<节点>` 派生子种子。同种子同操作必然同结果，这是每日挑战、问题复现和平衡模拟的基础。存档只保存种子和进度，路线图读档时重建。

**模拟与表现分离。** `BattleSim` 每拍按固定顺序推进（见文件顶部注释）。表现层只读公开字段，用 `queue_deploy / queue_recall / queue_capture` 提交意图，下一拍生效。`SimClock` 把墙钟换成 tick，倍速只改每帧跑几拍，不改单次结算。`BattleView` 用 `SimClock.alpha()` 在两拍之间插值。

**效果系统。** 异兽特性（"见则"）、五行阵、法宝都是 `EffectDef`（trigger + op + 参数）。目前支持的组合列在 `sim/battle_sim.gd` 顶部。新增效果：在那里加一个 op 的处理，然后在数据里引用，不写针对某只异兽的特例代码。

**单位。** 长度用 1920×1080 设计像素，原点左上。速度在数据里按"每秒"填写，模拟里除以 10。

**内容。** 数据以 `content/` 下的 `.tres` 为准，在编辑器 Inspector 里改。`tools/seed_graybox_content.gd` 只用于生成或重置灰盒数据，会覆盖同名文件。`ContentLibrary` 加载时校验 id 重复、引用缺失、出怪数量等问题，`test_content.gd` 会在 CI 里拦住坏数据。

**存档。** `SaveStore` 先写 `.tmp` 再替换，替换期间保留 `.bak`。`RunState` 和 `Profile` 都带 `schema`，版本不认识时返回 null 或空档案，不会读出半个坏档。

## 目录

| 路径 | 内容 |
| --- | --- |
| `core/rng_stream.gd` | 可派生的随机流 |
| `core/sim_clock.gd` | 墙钟 → tick，倍速、暂停、插值系数 |
| `core/elements.gd` | 五行克生关系、显示名、五色 |
| `core/beast_instance.gd` | 阵容中的一只异兽（id + 阶位） |
| `content/defs/` | `BeastDef`、`EffectDef`、`RelicDef`、`BattleDef`、`WaveDef`、`SpawnEntry`、`ElementChart` |
| `content/content_library.gd` | 加载与校验 |
| `sim/battle_sim.gd` | 守鼎战模拟 |
| `sim/wave_director.gd` | 出怪节奏（间隔按字面值） |
| `sim/auto_player.gd` | 自动策略，测试和平衡用 |
| `run/run_map.gd` | 分支路线图生成 |
| `run/run_state.gd` | 一局状态与序列化 |
| `meta/profile.gd` | 图鉴、统计、设置 |
| `services/save_store.gd` | 原子写入的本地 JSON |
| `autoload/game.gd` | 局外流程、节点结算、场景切换 |
| `scenes/` | 启动、路线图、战斗（灰盒绘制） |
| `tests/` | 无头测试（`run_tests.gd` 入口） |
| `tools/` | 灰盒内容生成、平衡模拟 |

## 美术接入预留

灰盒全部用色块绘制。接入正式美术时：

- 异兽精灵放 `art/beasts/<beast_id>/`，`BeastDef` 增加 `sprite_frames` 字段（`SpriteFrames`，动作名 `idle / move / attack / hit / death`）。同一套资源既用于敌人也用于塔。
- `BattleView._draw()` 换成按 id 池化的 `AnimatedSprite2D`，仍只读 `BattleSim`，用 `events` 触发命中、捕获、击杀特效。
- 战场改成 `TileMapLayer` 地形 + 装饰物件；路径和鼎位在关卡场景里用 `Path2D`、`Marker2D` 绘制，再烘焙到 `BattleDef`。

## 还没做的（按改版方案的阶段）

- P1：守鼎人主动技能、镇守型异兽的阻挡、五行阵（2/4/6）、更多效果 op
- P2：奖励三选一、集市 / 炼鼎 / 奇遇的正式界面、融合配方、首领机制、路线图连线
- 中文字体：目前依赖系统字体回退，移动端需要内置字体（如 Noto Sans SC）
- 导出预设（Windows / macOS / Android）与真机验证
