class_name RelicDef
extends Resource
## 法宝：一局内常驻的效果集合。

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
## 每场战斗生效的效果；trigger 为 on_pickup 的效果在获得时对整局生效一次。
@export var effects: Array[EffectDef] = []
## 集市售价（贝币）。
@export var price: int = 30
