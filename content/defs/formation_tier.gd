class_name FormationTier
extends Resource
## 五行阵的一档：场上该五行异兽达到 count 只时生效。只取达到的最高一档。

@export var count: int = 2
@export var effects: Array[EffectDef] = []
