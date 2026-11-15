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
