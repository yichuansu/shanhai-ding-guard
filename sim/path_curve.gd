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


## 点到路径的最近处：x = 沿路径距离，y = 点到路径的直线距离。
func closest(point: Vector2) -> Vector2:
	var best_along := 0.0
	var best_gap := INF
	for i in range(1, points.size()):
		var a := points[i - 1]
		var b := points[i]
		var ab := b - a
		var len_sq := ab.length_squared()
		var t := 0.0 if len_sq <= 0.0 else clampf((point - a).dot(ab) / len_sq, 0.0, 1.0)
		var gap := point.distance_to(a + ab * t)
		if gap < best_gap:
			best_gap = gap
			best_along = _cumulative[i - 1] + sqrt(len_sq) * t
	return Vector2(best_along, best_gap)


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
