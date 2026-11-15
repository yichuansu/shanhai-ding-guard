class_name RngStream
extends RefCounted
## 可复现的随机流。玩法里所有随机都必须走这里，不得调用全局 randf/randi。
## 一局一个主种子，路线、战斗、奖励用 derive() 按标签派生子流，互不干扰。

var seed_value: int
var _rng := RandomNumberGenerator.new()


func _init(seed_in: int) -> void:
	seed_value = seed_in
	_rng.seed = seed_in


static func derive_seed(parent: int, label: String) -> int:
	return ("%d:%s" % [parent, label]).hash()


func derive(label: String) -> RngStream:
	return RngStream.new(derive_seed(seed_value, label))


func next_float() -> float:
	return _rng.randf()


## 闭区间 [lo, hi]。
func next_int(lo: int, hi: int) -> int:
	return _rng.randi_range(lo, hi)


func chance(p: float) -> bool:
	return _rng.randf() < p


## weights 的键按插入顺序遍历，保证同种子结果一致。
func weighted_pick(weights: Dictionary) -> Variant:
	var total := 0.0
	for w: float in weights.values():
		total += maxf(w, 0.0)
	if total <= 0.0:
		return null
	var roll := _rng.randf() * total
	for key: Variant in weights.keys():
		roll -= maxf(float(weights[key]), 0.0)
		if roll < 0.0:
			return key
	return weights.keys().back()


func shuffle(items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: Variant = items[i]
		items[i] = items[j]
		items[j] = tmp
