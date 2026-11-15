class_name EffectDef
extends Resource
## 触发点 + 操作。异兽特性、五行阵、法宝共用这一种数据。
## 支持的 trigger / op 组合见 sim/battle_sim.gd 顶部注释，新增组合只改那里。

@export var trigger: StringName = &"on_hit"
@export var op: StringName = &""
@export var amount: float = 0.0
@export var duration_ticks: int = 0
@export var radius: float = 0.0
@export_multiline var description: String = ""
