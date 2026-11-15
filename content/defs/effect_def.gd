class_name EffectDef
extends Resource
## 触发点 + 操作。异兽特性、五行阵、法宝共用这一种数据。
## 支持的 trigger / op 组合见 sim/battle_sim.gd 顶部注释，新增组合只改那里。

@export var trigger: StringName = &"on_hit"
@export var op: StringName = &""
@export var amount: float = 0.0
@export var duration_ticks: int = 0
@export var radius: float = 0.0
## 非空时只作用于该五行的异兽（五行阵用），或作为目标五行（bonus_vs_element 用）。
@export var element_scope: StringName = &""
## 周期效果的间隔（敌人技能 periodic 用）。
@export var interval_ticks: int = 0
## 数量（召唤数、定身的塔数等）。
@export var count: int = 0
## 引用的 id（召唤哪种异兽、获得哪件法宝等）。
@export var param_id: StringName = &""
@export_multiline var description: String = ""
