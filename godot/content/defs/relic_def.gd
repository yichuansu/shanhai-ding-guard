class_name RelicDef
extends Resource
## 法宝：一局内常驻的效果集合。

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var effects: Array[EffectDef] = []
