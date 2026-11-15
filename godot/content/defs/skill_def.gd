class_name SkillDef
extends Resource
## 守鼎人的主动技能：点选战场上一个位置释放。
## op：damage_area（范围伤害）、freeze_area（范围定身）、smite_strongest（打击场上当前生命最高的敌人）。

@export var display_name: String = ""
@export_multiline var description: String = ""
@export var op: StringName = &"damage_area"
@export var spirit_cost: int = 6
@export var cooldown_ticks: int = 150
@export var amount: float = 0.0
@export var radius: float = 200.0
@export var duration_ticks: int = 0
