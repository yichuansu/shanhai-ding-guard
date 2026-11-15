class_name BattleDef
extends Resource
## 一张战场：路径、鼎位、波次。坐标是 1920×1080 设计像素，原点左上。
## 以后改为在关卡场景里用 Path2D / Marker2D 绘制再烘焙到这里。

enum Kind { NORMAL, ELITE, BOSS }

@export var id: StringName
@export var display_name: String = ""
@export var kind: Kind = Kind.NORMAL
@export var path_points: PackedVector2Array = PackedVector2Array()
@export var slots: PackedVector2Array = PackedVector2Array()
## 两个鼎位中心距离不超过它即视为相邻（相生、光环）。
@export var adjacency_radius: float = 270.0
@export var starting_spirit: int = 12
## 每隔多少 tick 自然回 1 点灵气。
@export var spirit_income_interval_ticks: int = 10
@export var waves: Array[WaveDef] = []
