class_name RunState
extends RefCounted
## 一局的全部状态。路线图由种子重建，存档只保存种子和进度。

const SCHEMA := 1
const DEFAULT_DING := 10
const DEFAULT_TALISMANS := 5
const DEFAULT_ROSTER_CAP := 6
## 每深入路线图一层，敌人血量 +12%（同类肉鸽的幕内递增）。按整局模拟调参：
## 自动玩家整局通关率约 37%，冀州首领倒下约 18%（守鼎人之间强弱仍不均，待调）。
const DIFFICULTY_PER_LAYER := 0.12
## 每进入下一州，敌人血量在第一层的基础上再加这么多（新州的异兽本身也更强）。
const DIFFICULTY_PER_ACT := 0.2
## 进入下一州时，回复已损失铜鼎耐久的这一比例。
const ACT_HEAL_RATIO := 0.5

var seed_value := 0
var keeper_id: StringName = &""
## 本局的鼎劫等级。
var ascension := 0
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
## 战后待领取的奖励：{"kind": "beast" | "relic", "options": [id...], "skip_shells": int}，空表示没有。
var pending_reward: Dictionary = {}
## 当前非战斗节点是否已处理（奇遇已选、炼鼎 / 祭祀已用）。进入新节点时重置。
var node_resolved := false
## 集市已售出的商品：节点 id(String) -> [商品序号...]
var shop_bought: Dictionary = {}
## 本局见过的奇遇，尽量不重复。
var seen_events: Array[StringName] = []
var _next_uid := 1


static func new_run(seed_in: int, starting_beasts: Array[StringName], keeper: StringName = &"", starting_talismans: int = DEFAULT_TALISMANS, ascension_level: int = 0) -> RunState:
	var r := RunState.new()
	r.seed_value = seed_in
	r.keeper_id = keeper
	r.talismans = starting_talismans
	r.ascension = clampi(ascension_level, 0, Ascension.MAX_LEVEL)
	r.ding_max = DEFAULT_DING + int(Ascension.mods(r.ascension)["ding_max_delta"])
	r.ding_hp = r.ding_max
	r._build_map()
	for id in starting_beasts:
		r.add_beast(id)
	return r


func map_rng() -> RngStream:
	return RngStream.new(RngStream.derive_seed(seed_value, "map:%d" % act))


func battle_seed(node_id: int) -> int:
	return RngStream.derive_seed(seed_value, "battle:%d:%d" % [act, node_id])


func difficulty_scale(node_id: int) -> float:
	return 1.0 + DIFFICULTY_PER_ACT * act + DIFFICULTY_PER_LAYER * map.nodes[node_id].layer


func boss_scale() -> float:
	return (1.0 + DIFFICULTY_PER_ACT * act) * float(Ascension.mods(ascension)["boss_hp_mult"])


## 本场战斗的完整配置（不含内容库查找以外的场景依赖），Game 和整局模拟共用。
func make_battle_setup(lib: ContentLibrary, node_id: int) -> BattleSetup:
	var m := Ascension.mods(ascension)
	var setup := BattleSetup.new()
	setup.roster = roster.duplicate()
	for id in relic_ids:
		if lib.relics.has(id):
			setup.relics.append(lib.relics[id])
	setup.ding_hp = ding_hp
	setup.ding_max = ding_max
	setup.talismans = mini(talismans, int(m["capture_limit"]))
	setup.seed_value = battle_seed(node_id)
	setup.keeper = lib.keepers.get(keeper_id)
	setup.formations = lib.formation_list()
	setup.hp_scale = difficulty_scale(node_id) * float(m["hp_mult"])
	setup.boss_hp_scale = boss_scale()
	setup.spirit_delta = int(m["spirit_delta"])
	setup.speed_scale = float(m["speed_mult"])
	return setup


func region() -> StringName:
	return Regions.for_act(act)


## 进入下一州：重建路线图，从头走，回复一半已损失的铜鼎耐久。返回回复量。
func advance_act() -> int:
	act += 1
	_build_map()
	current_node = -1
	visited = PackedInt32Array()
	node_resolved = false
	var heal := ceili((ding_max - ding_hp) * ACT_HEAL_RATIO)
	ding_hp += heal
	return heal


func available_nodes() -> PackedInt32Array:
	if finished:
		return PackedInt32Array()
	return map.available_from(current_node)


func enter_node(node_id: int) -> bool:
	if not available_nodes().has(node_id):
		return false
	current_node = node_id
	visited.append(node_id)
	node_resolved = false
	return true


func current_node_type() -> MapNode.Type:
	return map.nodes[current_node].type if current_node >= 0 else MapNode.Type.BATTLE


func instance_by_uid(uid: int) -> BeastInstance:
	for b in roster:
		if b.uid == uid:
			return b
	return null


func remove_beast(uid: int) -> BeastInstance:
	for i in roster.size():
		if roster[i].uid == uid:
			var b := roster[i]
			roster.remove_at(i)
			return b
	return null


func is_roster_full() -> bool:
	return roster.size() >= roster_cap


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
		"ascension": ascension,
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
		"pending_reward": pending_reward,
		"node_resolved": node_resolved,
		"shop_bought": shop_bought,
		"seen_events": seen_events.map(func(e: StringName) -> String: return String(e)),
	}


## 版本不认识时返回 null，由调用方决定丢弃还是迁移。
static func from_dict(d: Dictionary) -> RunState:
	if int(d.get("schema", -1)) != SCHEMA:
		return null
	var r := RunState.new()
	r.seed_value = int(d.get("seed", 0))
	r.keeper_id = StringName(str(d.get("keeper", "")))
	r.ascension = int(d.get("ascension", 0))
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
	var pr: Dictionary = d.get("pending_reward", {})
	if not pr.is_empty():
		var opts: Array = []
		for o: Variant in pr.get("options", []):
			opts.append(str(o))
		r.pending_reward = {"kind": str(pr.get("kind", "")), "options": opts, "skip_shells": int(pr.get("skip_shells", 0))}
	r.node_resolved = bool(d.get("node_resolved", false))
	var sb: Dictionary = d.get("shop_bought", {})
	for key: String in sb:
		var bought: Array = []
		for i: Variant in sb[key]:
			bought.append(int(i))
		r.shop_bought[key] = bought
	for e: Variant in d.get("seen_events", []):
		r.seen_events.append(StringName(str(e)))
	return r


func _build_map() -> void:
	map = RunMap.generate(map_rng())
