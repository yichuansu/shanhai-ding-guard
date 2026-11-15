class_name Profile
extends RefCounted
## 跨局的玩家档案：图鉴、统计、设置。

const SCHEMA := 1

## beast_id(String) -> {"captures": int}
var bestiary: Dictionary = {}
var runs_started := 0
var runs_won := 0
var sim_speed := 1.0


## 返回是否首次捕获。
func record_capture(beast_id: StringName) -> bool:
	var key := String(beast_id)
	var first := not bestiary.has(key)
	if first:
		bestiary[key] = {"captures": 0}
	bestiary[key]["captures"] = int(bestiary[key]["captures"]) + 1
	return first


func has_captured(beast_id: StringName) -> bool:
	return bestiary.has(String(beast_id))


func to_dict() -> Dictionary:
	return {
		"schema": SCHEMA,
		"bestiary": bestiary,
		"runs_started": runs_started,
		"runs_won": runs_won,
		"settings": {"sim_speed": sim_speed},
	}


static func from_dict(d: Dictionary) -> Profile:
	var p := Profile.new()
	if int(d.get("schema", -1)) != SCHEMA:
		return p
	var raw: Dictionary = d.get("bestiary", {})
	for key: String in raw:
		p.bestiary[key] = {"captures": int((raw[key] as Dictionary).get("captures", 1))}
	p.runs_started = int(d.get("runs_started", 0))
	p.runs_won = int(d.get("runs_won", 0))
	p.sim_speed = float((d.get("settings", {}) as Dictionary).get("sim_speed", 1.0))
	return p
