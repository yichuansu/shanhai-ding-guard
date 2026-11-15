class_name FormationDef
extends Resource
## 一个五行的阵法。

@export var element: StringName = &"huo"
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var tiers: Array[FormationTier] = []
