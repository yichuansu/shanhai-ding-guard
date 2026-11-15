class_name EnemyUnit
extends RefCounted
## 场上的一只敌方异兽（模拟内部状态，表现层只读）。

var id := 0
var def: BeastDef
var wave_index := 0
var max_hp := 1
var hp := 1.0
var distance := 0.0
var prev_distance := 0.0
## 已在途、注定命中的伤害。索敌时跳过"当前生命 - 预定 ≤ 0"的敌人。
var reserved_damage := 0.0
var slow_multiplier := 1.0
var slow_ticks := 0
var burn_per_tick := 0.0
var burn_ticks := 0
var alive := true
var leaked := false
var captured := false


func is_capturable() -> bool:
	return alive and def.capturable and hp <= max_hp * def.capture_threshold
