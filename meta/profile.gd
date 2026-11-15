class_name Profile
extends RefCounted
## 跨局的玩家档案：图鉴、统计、设置。

const SCHEMA := 1

## 收录过的异兽：beast_id(String) -> {"captures": int, "obtained": bool}
## captures 是亲手捕获的次数；obtained 表示通过奖励、集市、炼鼎、奇遇得到过。两者任一即算收录。
var bestiary: Dictionary = {}
## 战斗中遇见过的异兽：beast_id(String) -> true
var seen: Dictionary = {}
## 击败过的首领：beast_id(String) -> 次数
var defeated: Dictionary = {}
## 鼎劫进度：keeper_id(String) -> 已解锁的最高等级（0 表示只能打 0 级）
var ascension: Dictionary = {}
var runs_started := 0
var runs_won := 0
var sim_speed := 1.0


## 返回是否首次收录。
func record_capture(beast_id: StringName) -> bool:
	var key := String(beast_id)
	var first := not bestiary.has(key)
	_entry(key)["captures"] = int(_entry(key)["captures"]) + 1
	seen[key] = true
	return first


## 通过捕获以外的途径得到。返回是否首次收录。
func record_obtained(beast_id: StringName) -> bool:
	var key := String(beast_id)
	var first := not bestiary.has(key)
	_entry(key)["obtained"] = true
	seen[key] = true
	return first


func record_seen(beast_id: StringName) -> void:
	seen[String(beast_id)] = true


func record_defeat(beast_id: StringName) -> void:
	var key := String(beast_id)
	defeated[key] = int(defeated.get(key, 0)) + 1
	seen[key] = true


func has_captured(beast_id: StringName) -> bool:
	return bestiary.has(String(beast_id))


func has_seen(beast_id: StringName) -> bool:
	return seen.has(String(beast_id))


func capture_count(beast_id: StringName) -> int:
	return int((bestiary.get(String(beast_id), {}) as Dictionary).get("captures", 0))


func defeat_count(beast_id: StringName) -> int:
	return int(defeated.get(String(beast_id), 0))


func max_ascension(keeper_id: StringName) -> int:
	return int(ascension.get(String(keeper_id), 0))


## 用某位守鼎人在某一级通关。返回新解锁的等级，没有新解锁返回 -1。
func record_win(keeper_id: StringName, level: int) -> int:
	var key := String(keeper_id)
	var next := mini(level + 1, Ascension.MAX_LEVEL)
	if next > max_ascension(keeper_id):
		ascension[key] = next
		return next
	return -1


func _entry(key: String) -> Dictionary:
	if not bestiary.has(key):
		bestiary[key] = {"captures": 0, "obtained": false}
	return bestiary[key]


func to_dict() -> Dictionary:
	return {
		"schema": SCHEMA,
		"bestiary": bestiary,
		"seen": seen.keys(),
		"defeated": defeated,
		"ascension": ascension,
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
		var e: Dictionary = raw[key]
		p.bestiary[key] = {"captures": int(e.get("captures", 0)), "obtained": bool(e.get("obtained", false))}
		p.seen[key] = true
	for key: Variant in d.get("seen", []):
		p.seen[str(key)] = true
	var dr: Dictionary = d.get("defeated", {})
	for key: String in dr:
		p.defeated[key] = int(dr[key])
	var asc: Dictionary = d.get("ascension", {})
	for key: String in asc:
		p.ascension[key] = int(asc[key])
	p.runs_started = int(d.get("runs_started", 0))
	p.runs_won = int(d.get("runs_won", 0))
	p.sim_speed = float((d.get("settings", {}) as Dictionary).get("sim_speed", 1.0))
	return p
