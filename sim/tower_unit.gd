class_name TowerUnit
extends RefCounted
## 部署在鼎位上的我方异兽。

var slot := 0
var instance: BeastInstance
var def: BeastDef
var position := Vector2.ZERO
var cooldown := 0
## 局内等级 1..3，战斗结束即失效（和阵容阶位 ★ 是两回事）。
var level := 1
## 本场在这只异兽上花掉的灵气（部署 + 升级），收回时返还一半。
var invested := 0
## 开火后的后坐动画用，表现层读。
var last_fire_tick := -100
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
