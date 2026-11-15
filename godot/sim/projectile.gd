class_name Projectile
extends RefCounted
## 飞弹。发射时快照伤害与命中特效，命中拍才结算。

var id := 0
var slot := 0
var target_id := 0
var position := Vector2.ZERO
var prev_position := Vector2.ZERO
var aim := Vector2.ZERO
var speed := 0.0
var damage := 0.0
var element: StringName = &"none"
var on_hit: Array[EffectDef] = []
var crit := false
var done := false
