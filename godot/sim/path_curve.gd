class_name PathCurve
extends RefCounted
## 折线路径。敌人只记"沿路径走了多远"，位置由这里换算。

var points: PackedVector2Array
var length := 0.0
var _cumulative := PackedFloat64Array()


func _init(pts: PackedVector2Array) -> void:
	points = pts
	_cumulative.append(0.0)
	for i in range(1, pts.size()):
		_cumulative.append(_cumulative[i - 1] + pts[i - 1].distance_to(pts[i]))
	length = _cumulative[_cumulative.size() - 1]


func position_at(distance: float) -> Vector2:
	if distance <= 0.0:
		return points[0]
	if distance >= length:
		return points[points.size() - 1]
	for i in range(1, _cumulative.size()):
		if distance <= _cumulative[i]:
			var seg := _cumulative[i] - _cumulative[i - 1]
			var t := 0.0 if seg <= 0.0 else (distance - _cumulative[i - 1]) / seg
			return points[i - 1].lerp(points[i], t)
	return points[points.size() - 1]
