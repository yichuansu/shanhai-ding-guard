class_name SpawnEntry
extends Resource
## 一组出怪：同一种异兽连续出 count 只，相邻两只相隔 interval_ticks。

@export var beast_id: StringName
@export var count: int = 1
@export var interval_ticks: int = 15
@export var hp_multiplier: float = 1.0
