extends Node
## 局外流程：档案、当前一局、场景切换。场景层通过它推进，模拟层不引用它。

const PROFILE_PATH := "user://profile.json"
const RUN_PATH := "user://run.json"
const STARTING_BEASTS: Array[StringName] = [&"jingwei", &"bifang"]

const SCENE_MAP := "res://scenes/map/map_screen.tscn"
const SCENE_BATTLE := "res://scenes/battle/battle_screen.tscn"
const SCENE_NODE := "res://scenes/node/node_screen.tscn"
const SCENE_BESTIARY := "res://scenes/bestiary/bestiary_screen.tscn"
const SCENE_START := "res://scenes/start/start_screen.tscn"
const SCENE_ART_PREVIEW := "res://scenes/art_preview/art_preview.tscn"

var profile: Profile
var run: RunState
var pending_node_id := -1
## 最近一场战斗的结算文字，路线图上显示。
var last_report := ""


const UI_THEME := "res://assets/ui_theme.tres"


func _ready() -> void:
	# 界面主题在运行时挂到根窗口，而不是写进工程设置：
	# 工程设置里的主题会在启动时、资源导入之前加载，全新克隆第一次打开会报字体缺失。
	if ResourceLoader.exists(UI_THEME):
		get_tree().root.theme = load(UI_THEME)
	profile = Profile.from_dict(SaveStore.load_json(PROFILE_PATH))
	var data := SaveStore.load_json(RUN_PATH)
	if not data.is_empty():
		run = RunState.from_dict(data)


func has_active_run() -> bool:
	return run != null and not run.finished


func start_new_run(seed_value: int = -1, keeper_id: StringName = &"", ascension_level: int = 0) -> void:
	if seed_value < 0:
		seed_value = int(Time.get_unix_time_from_system()) ^ (Time.get_ticks_usec() & 0xffff)
	if keeper_id == &"" or not Content.lib.keepers.has(keeper_id):
		var ids := Content.lib.keeper_ids()
		keeper_id = ids[0] if not ids.is_empty() else &""
	var keeper: KeeperDef = Content.lib.keepers.get(keeper_id)
	var level := clampi(ascension_level, 0, profile.max_ascension(keeper_id))
	if keeper != null:
		run = RunState.new_run(seed_value, keeper.starting_beasts, keeper_id, keeper.starting_talismans, level)
	else:
		run = RunState.new_run(seed_value, STARTING_BEASTS)
	profile.runs_started += 1
	last_report = "新的一局开始：%s · 鼎劫第 %d 级。种子 %d" % [keeper.display_name if keeper else "无守鼎人", level, seed_value]
	save()


func node_type(node_id: int) -> MapNode.Type:
	return run.map.nodes[node_id].type


## 进入节点：战斗节点切到战斗场景，其余切到节点界面（集市 / 炼鼎 / 奇遇 / 祭祀）。
func enter_node(node_id: int) -> String:
	if run.pending_reward.size() > 0:
		get_tree().change_scene_to_file(SCENE_NODE)
		return ""
	if not run.enter_node(node_id):
		return "现在去不了这个节点。"
	var node := run.map.nodes[node_id]
	if node.is_combat():
		pending_node_id = node_id
		save()
		get_tree().change_scene_to_file(SCENE_BATTLE)
		return ""
	save()
	get_tree().change_scene_to_file(SCENE_NODE)
	return ""


## 已解锁进奖励池的异兽：图鉴里捕获过的 + 本局守鼎人的开局异兽。
func unlocked_beasts() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: String in profile.bestiary:
		out.append(StringName(key))
	var keeper: KeeperDef = Content.lib.keepers.get(run.keeper_id)
	if keeper != null:
		for id in keeper.starting_beasts:
			if not out.has(id):
				out.append(id)
	return out


## 节点界面当前该显示什么："reward" 或节点类型名。
func node_mode() -> String:
	if run == null:
		return ""
	if not run.pending_reward.is_empty():
		return "reward"
	match run.current_node_type():
		MapNode.Type.SHOP:
			return "shop"
		MapNode.Type.FORGE:
			return "forge"
		MapNode.Type.EVENT:
			return "event"
		MapNode.Type.REST:
			return "rest"
	return ""


## 战斗结束后：有奖励先去领，否则回路线图。
func after_battle() -> void:
	if run != null and not run.pending_reward.is_empty():
		get_tree().change_scene_to_file(SCENE_NODE)
	else:
		goto_map()


func battle_def_for_node(node_id: int) -> BattleDef:
	var kind := BattleDef.Kind.NORMAL
	match node_type(node_id):
		MapNode.Type.ELITE:
			kind = BattleDef.Kind.ELITE
		MapNode.Type.BOSS:
			kind = BattleDef.Kind.BOSS
	var options := Content.lib.battles_of_kind(kind, run.region())
	if options.is_empty():
		options = Content.lib.battles_of_kind(kind)
	var rng := RngStream.new(run.battle_seed(node_id))
	return options[rng.next_int(0, options.size() - 1)]


func make_battle_setup(node_id: int) -> BattleSetup:
	return run.make_battle_setup(Content.lib, node_id)


func finish_battle(sim: BattleSim) -> void:
	var keepers_before := KeeperUnlocks.unlocked_ids(Content.lib, profile)
	var newly: PackedStringArray = []
	for id: StringName in sim.encountered:
		profile.record_seen(id)
	if sim.outcome == BattleSim.Outcome.WON:
		for id: StringName in sim.encountered:
			var def: BeastDef = Content.lib.beasts.get(id)
			if def != null and def.rarity == BeastDef.Rarity.BOSS:
				profile.record_defeat(id)
	for id in sim.captured_beasts:
		if profile.record_capture(id):
			newly.append(RunRules.beast_name(Content.lib, id))
	var summary := {
		"won": sim.outcome == BattleSim.Outcome.WON,
		"ding_hp": sim.ding_hp,
		"shells": sim.shells_earned,
		"talismans_spent": sim.run_talismans_spent(),
		"captured": sim.captured_beasts,
	}
	var lines := RunRules.apply_battle_result(run, Content.lib, pending_node_id, summary, unlocked_beasts())
	if not newly.is_empty():
		lines.append("图鉴新增：" + "、".join(newly))
	if run.won:
		profile.runs_won += 1
		var unlocked_level := profile.record_win(run.keeper_id, run.ascension)
		if unlocked_level > 0:
			lines.append("解锁鼎劫第 %d 级：%s" % [unlocked_level, Ascension.LEVEL_TEXT[unlocked_level - 1]])
	for id in KeeperUnlocks.unlocked_ids(Content.lib, profile):
		if not keepers_before.has(id):
			lines.append("解锁新守鼎人：%s！" % (Content.lib.keepers[id] as KeeperDef).display_name)
	pending_node_id = -1
	last_report = "；".join(lines)
	save()


func goto_map() -> void:
	get_tree().change_scene_to_file(SCENE_MAP)


## 阵容里出现过的异兽（奖励、集市、炼鼎、奇遇得到的）都记入图鉴。
func sync_bestiary() -> PackedStringArray:
	var newly := PackedStringArray()
	if run == null:
		return newly
	for b in run.roster:
		if not profile.has_captured(b.beast_id) and profile.record_obtained(b.beast_id):
			newly.append(RunRules.beast_name(Content.lib, b.beast_id))
	return newly


func goto_start() -> void:
	get_tree().change_scene_to_file(SCENE_START)


func goto_art_preview() -> void:
	get_tree().change_scene_to_file(SCENE_ART_PREVIEW)


func goto_bestiary() -> void:
	get_tree().change_scene_to_file(SCENE_BESTIARY)


func save() -> void:
	sync_bestiary()
	SaveStore.save_json(PROFILE_PATH, profile.to_dict())
	if run != null:
		SaveStore.save_json(RUN_PATH, run.to_dict())
