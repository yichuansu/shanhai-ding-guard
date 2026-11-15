extends Node
## 局外流程：档案、当前一局、场景切换。场景层通过它推进，模拟层不引用它。

const PROFILE_PATH := "user://profile.json"
const RUN_PATH := "user://run.json"
const STARTING_BEASTS: Array[StringName] = [&"jingwei", &"bifang"]
const REST_HEAL := 3
const SHOP_TALISMAN_PRICE := 5
const SHOP_TALISMAN_COUNT := 2
const EVENT_SHELLS := 4

const SCENE_MAP := "res://scenes/map/map_screen.tscn"
const SCENE_BATTLE := "res://scenes/battle/battle_screen.tscn"

var profile: Profile
var run: RunState
var pending_node_id := -1
## 最近一场战斗的结算文字，路线图上显示。
var last_report := ""


func _ready() -> void:
	profile = Profile.from_dict(SaveStore.load_json(PROFILE_PATH))
	var data := SaveStore.load_json(RUN_PATH)
	if not data.is_empty():
		run = RunState.from_dict(data)


func has_active_run() -> bool:
	return run != null and not run.finished


func start_new_run(seed_value: int = -1, keeper_id: StringName = &"") -> void:
	if seed_value < 0:
		seed_value = int(Time.get_unix_time_from_system()) ^ (Time.get_ticks_usec() & 0xffff)
	if keeper_id == &"" or not Content.lib.keepers.has(keeper_id):
		var ids := Content.lib.keeper_ids()
		keeper_id = ids[0] if not ids.is_empty() else &""
	var keeper: KeeperDef = Content.lib.keepers.get(keeper_id)
	if keeper != null:
		run = RunState.new_run(seed_value, keeper.starting_beasts, keeper_id, keeper.starting_talismans)
	else:
		run = RunState.new_run(seed_value, STARTING_BEASTS)
	profile.runs_started += 1
	last_report = "新的一局开始：%s。种子 %d" % [keeper.display_name if keeper else "无守鼎人", seed_value]
	save()


func node_type(node_id: int) -> MapNode.Type:
	return run.map.nodes[node_id].type


## 进入节点。战斗节点切到战斗场景；其他节点先用灰盒占位效果，返回提示文字。
func enter_node(node_id: int) -> String:
	if not run.enter_node(node_id):
		return "现在去不了这个节点。"
	var node := run.map.nodes[node_id]
	if node.is_combat():
		pending_node_id = node_id
		save()
		get_tree().change_scene_to_file(SCENE_BATTLE)
		return ""
	var message := _resolve_noncombat(node)
	last_report = message
	save()
	return message


func battle_def_for_node(node_id: int) -> BattleDef:
	var kind := BattleDef.Kind.NORMAL
	match node_type(node_id):
		MapNode.Type.ELITE:
			kind = BattleDef.Kind.ELITE
		MapNode.Type.BOSS:
			kind = BattleDef.Kind.BOSS
	var options := Content.lib.battles_of_kind(kind)
	if options.is_empty():
		options = Content.lib.battles_of_kind(BattleDef.Kind.NORMAL)
	var rng := RngStream.new(run.battle_seed(node_id))
	return options[rng.next_int(0, options.size() - 1)]


func make_battle_setup(node_id: int) -> BattleSetup:
	var setup := BattleSetup.new()
	setup.roster = run.roster.duplicate()
	for id in run.relic_ids:
		if Content.lib.relics.has(id):
			setup.relics.append(Content.lib.relics[id])
	setup.ding_hp = run.ding_hp
	setup.ding_max = run.ding_max
	setup.talismans = mini(run.talismans, BattleSim.CAPTURE_LIMIT_PER_BATTLE)
	setup.seed_value = run.battle_seed(node_id)
	setup.keeper = Content.lib.keepers.get(run.keeper_id)
	setup.formations = Content.lib.formation_list()
	return setup


func finish_battle(sim: BattleSim) -> void:
	var lines: PackedStringArray = []
	run.ding_hp = clampi(sim.ding_hp, 0, run.ding_max)
	run.shells += sim.shells_earned
	run.talismans = maxi(run.talismans - sim.run_talismans_spent(), 0)
	lines.append("获得贝币 %d" % sim.shells_earned)
	for id in sim.captured_beasts:
		var def: BeastDef = Content.lib.beasts.get(id)
		var name := def.display_name if def else String(id)
		var first := profile.record_capture(id)
		if run.add_beast(id) == null:
			lines.append("%s 已收入图鉴，但阵容已满，只能放生" % name)
		else:
			lines.append("收服 %s%s" % [name, "（图鉴新增）" if first else ""])
	if sim.outcome == BattleSim.Outcome.LOST:
		run.finished = true
		lines.append("鼎破，本局结束。")
	else:
		var t := node_type(pending_node_id)
		if t == MapNode.Type.ELITE:
			var relic := _grant_random_relic()
			if relic != null:
				lines.append("获得法宝 %s" % relic.display_name)
		if t == MapNode.Type.BOSS:
			run.finished = true
			run.won = true
			profile.runs_won += 1
			lines.append("冀州之鼎已修复。灰盒版本只有一州，本局胜利。")
	pending_node_id = -1
	last_report = "；".join(lines)
	save()


func goto_map() -> void:
	get_tree().change_scene_to_file(SCENE_MAP)


func save() -> void:
	SaveStore.save_json(PROFILE_PATH, profile.to_dict())
	if run != null:
		SaveStore.save_json(RUN_PATH, run.to_dict())


func _resolve_noncombat(node: MapNode) -> String:
	match node.type:
		MapNode.Type.REST:
			var before := run.ding_hp
			run.ding_hp = mini(run.ding_max, run.ding_hp + REST_HEAL)
			return "祭祀：鼎耐久 %d → %d" % [before, run.ding_hp]
		MapNode.Type.SHOP:
			if run.shells >= SHOP_TALISMAN_PRICE:
				run.shells -= SHOP_TALISMAN_PRICE
				run.talismans += SHOP_TALISMAN_COUNT
				return "集市：花 %d 贝币买了 %d 张镇鼎符（灰盒占位）" % [SHOP_TALISMAN_PRICE, SHOP_TALISMAN_COUNT]
			return "集市：贝币不够（灰盒占位）"
		MapNode.Type.FORGE:
			var merged := run.merge_first_pair()
			if merged == null:
				return "炼鼎：没有可以合成的同种异兽（灰盒占位）"
			return "炼鼎：%s 升到 %d 阶" % [merged.beast_id, merged.tier]
		MapNode.Type.EVENT:
			run.shells += EVENT_SHELLS
			return "奇遇：拾得 %d 贝币（灰盒占位，正式版是山海经事件）" % EVENT_SHELLS
	return ""


func _grant_random_relic() -> RelicDef:
	var pool: Array[StringName] = []
	var ids := Content.lib.relics.keys()
	ids.sort()
	for id: StringName in ids:
		if not run.relic_ids.has(id):
			pool.append(id)
	if pool.is_empty():
		return null
	var rng := RngStream.new(run.battle_seed(pending_node_id)).derive("relic")
	var pick := pool[rng.next_int(0, pool.size() - 1)]
	run.relic_ids.append(pick)
	return Content.lib.relics[pick]
