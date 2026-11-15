class_name WaveDef
extends Resource
## 一波。gap_ticks_before：第一波是开战到第一只的等待；之后是上一波最后一只到本波第一只的间隔。

@export var gap_ticks_before: int = 0
@export var spawns: Array[SpawnEntry] = []
