class_name WaveDirector
extends RefCounted
## 按波次表出怪，每 tick 最多出一只。间隔按字面值：interval_ticks=5 即第 1、6、11 拍出怪。

var wave_index := 0
var finished_spawning := false
var total_per_wave := PackedInt32Array()
var spawned_per_wave := PackedInt32Array()

var _waves: Array[WaveDef]
var _entry_index := 0
var _spawned_in_entry := 0
var _cooldown := 0


func _init(waves: Array[WaveDef]) -> void:
	_waves = waves
	for wave in waves:
		var total := 0
		for spawn in wave.spawns:
			total += spawn.count
		total_per_wave.append(total)
		spawned_per_wave.append(0)
	if waves.is_empty():
		finished_spawning = true
	else:
		_cooldown = waves[0].gap_ticks_before
		_skip_empty_waves()


## 返回本拍要生成的敌人：[{beast_id, hp_multiplier, wave_index}]。
func step() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if finished_spawning:
		return out
	if _cooldown > 0:
		_cooldown -= 1
		return out
	var wave := _waves[wave_index]
	var entry := wave.spawns[_entry_index]
	out.append({
		"beast_id": entry.beast_id,
		"hp_multiplier": entry.hp_multiplier,
		"wave_index": wave_index,
	})
	spawned_per_wave[wave_index] += 1
	_spawned_in_entry += 1
	if _spawned_in_entry < entry.count:
		_cooldown = maxi(entry.interval_ticks - 1, 0)
		return out
	_spawned_in_entry = 0
	_entry_index += 1
	if _entry_index < wave.spawns.size():
		_cooldown = maxi(entry.interval_ticks - 1, 0)
		return out
	_entry_index = 0
	wave_index += 1
	if wave_index >= _waves.size():
		finished_spawning = true
	else:
		_cooldown = maxi(_waves[wave_index].gap_ticks_before - 1, 0)
		_skip_empty_waves()
	return out


func wave_fully_spawned(index: int) -> bool:
	return spawned_per_wave[index] >= total_per_wave[index]


func _skip_empty_waves() -> void:
	while wave_index < _waves.size() and _waves[wave_index].spawns.is_empty():
		wave_index += 1
	if wave_index >= _waves.size():
		finished_spawning = true
