class_name RunState
extends RefCounted
## 一局的全部状态。路线图由种子重建，存档只保存种子和进度。

const SCHEMA := 1
const DEFAULT_DING := 10
const DEFAULT_TALISMANS := 5
const DEFAULT_ROSTER_CAP := 6

var seed_value := 0
var keeper_id: StringName = &""
var act := 0
var map: RunMap
var current_node := -1
var visited := PackedInt32Array()
var roster: Array[BeastInstance] = []
var roster_cap := DEFAULT_ROSTER_CAP
var shells := 0
var talismans := DEFAULT_TALISMANS
var ding_hp := DEFAULT_DING
var ding_max := DEFAULT_DING
var relic_ids: Array[StringName] = []
var finished := false
var won := false
var _next_uid := 1


static func new_run(seed_in: int, starting_beasts: Array[StringName], keeper: StringName = &"", starting_talismans: int = DEFAULT_TALISMANS) -> RunState:
	var r := RunState.new()
	r.seed_value = seed_in
	r.keeper_id = keeper
	r.talismans = starting_talismans
	r._build_map()
	for id in starting_beasts:
		r.add_beast(id)
	return r


func map_rng() -> RngStream:
	return RngStream.new(RngStream.derive_seed(seed_value, "map:%d" % act))


func battle_seed(node_id: int) -> int:
	return RngStream.derive_seed(seed_value, "battle:%d:%d" % [act, node_id])


func available_nodes() -> PackedInt32Array:
	if finished:
		return PackedInt32Array()
	return map.available_from(current_node)


func enter_node(node_id: int) -> bool:
	if not available_nodes().has(node_id):
		return false
	current_node = node_id
	visited.append(node_id)
	return true


## 阵容满了返回 null。
func add_beast(beast_id: StringName, tier: int = 1) -> BeastInstance:
	if roster.size() >= roster_cap:
		return null
	var inst := BeastInstance.make(_next_uid, beast_id, tier)
	_next_uid += 1
	roster.append(inst)
	return inst


## 两只同种同阶合成高一阶。成功返回新实例。
func merge_first_pair() -> BeastInstance:
	for i in roster.size():
		for j in range(i + 1, roster.size()):
			var a := roster[i]
			var b := roster[j]
			if a.beast_id == b.beast_id and a.tier == b.tier and a.tier < BeastInstance.MAX_TIER:
				a.tier += 1
				roster.remove_at(j)
				return a
	return null


func to_dict() -> Dictionary:
	var roster_data: Array = []
	for b in roster:
		roster_data.append(b.to_dict())
	var relics: Array = []
	for id in relic_ids:
		relics.append(String(id))
	return {
		"schema": SCHEMA,
		"seed": seed_value,
		"keeper": String(keeper_id),
		"act": act,
		"current_node": current_node,
		"visited": Array(visited),
		"roster": roster_data,
		"roster_cap": roster_cap,
		"shells": shells,
		"talismans": talismans,
		"ding_hp": ding_hp,
		"ding_max": ding_max,
		"relics": relics,
		"finished": finished,
		"won": won,
		"next_uid": _next_uid,
	}


## 版本不认识时返回 null，由调用方决定丢弃还是迁移。
static func from_dict(d: Dictionary) -> RunState:
	if int(d.get("schema", -1)) != SCHEMA:
		return null
	var r := RunState.new()
	r.seed_value = int(d.get("seed", 0))
	r.keeper_id = StringName(str(d.get("keeper", "")))
	r.act = int(d.get("act", 0))
	r._build_map()
	r.current_node = int(d.get("current_node", -1))
	for v: Variant in d.get("visited", []):
		r.visited.append(int(v))
	for b: Variant in d.get("roster", []):
		r.roster.append(BeastInstance.from_dict(b))
	r.roster_cap = int(d.get("roster_cap", DEFAULT_ROSTER_CAP))
	r.shells = int(d.get("shells", 0))
	r.talismans = int(d.get("talismans", DEFAULT_TALISMANS))
	r.ding_hp = int(d.get("ding_hp", DEFAULT_DING))
	r.ding_max = int(d.get("ding_max", DEFAULT_DING))
	for id: Variant in d.get("relics", []):
		r.relic_ids.append(StringName(str(id)))
	r.finished = bool(d.get("finished", false))
	r.won = bool(d.get("won", false))
	r._next_uid = int(d.get("next_uid", r.roster.size() + 1))
	return r


func _build_map() -> void:
	map = RunMap.generate(map_rng())
