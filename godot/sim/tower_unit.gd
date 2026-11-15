class_name TowerUnit
extends RefCounted
## 部署在鼎位上的我方异兽。

var slot := 0
var instance: BeastInstance
var def: BeastDef
var position := Vector2.ZERO
var cooldown := 0
## 相生与光环带来的伤害加成，鼎位变化时重算。
var damage_bonus := 0.0

# 镇守型才用到下面的字段。
var is_guard := false
## 能否拦截：鼎位离路径够近。
var guard_active := false
var block_distance := 0.0
var guard_hp := 0.0
var guard_hp_max := 0.0
var guard_down_ticks := 0
var blocked: Array[int] = []


func guard_ready() -> bool:
	return guard_active and guard_down_ticks == 0
