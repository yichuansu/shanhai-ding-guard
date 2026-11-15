class_name RunRules
extends RefCounted
## 一局里非战斗部分的规则：战后结算与奖励、集市、炼鼎、奇遇、祭祀、法宝获取。
## 全是静态函数，只读写 RunState 与内容库，不依赖场景树，便于测试。
## 所有随机都由"种子 + 节点 id + 用途"派生，同一局同一节点结果固定（读档重进不会刷新商品）。
##
## unlocked：已解锁进奖励池的异兽 id（图鉴捕获过的 + 守鼎人开局的），由调用方从档案里算好传入。

const SKIP_REWARD_SHELLS := 6
const REWARD_CHOICES := 3
const SHOP_BEASTS := 3
const SHOP_RELICS := 2
const BEAST_PRICE := 14
const TALISMAN_PACK := 2
const TALISMAN_PACK_PRICE := 6
const REPAIR_AMOUNT := 3
const REPAIR_PRICE := 8
const REST_HEAL := 4
const REST_FORTIFY := 2
const ROSTER_FULL := "阵容已满，先选一只放生。"


# ---------- 战后 ----------

## summary：{"won": bool, "ding_hp": int, "shells": int, "talismans_spent": int, "captured": Array[StringName]}
## 返回结算文字。胜利且不是首领战时生成 pending_reward。
static func apply_battle_result(run: RunState, lib: ContentLibrary, node_id: int, summary: Dictionary, unlocked: Array[StringName]) -> PackedStringArray:
	var lines := PackedStringArray()
	run.ding_hp = clampi(int(summary.get("ding_hp", run.ding_hp)), 0, run.ding_max)
	var shells := int(summary.get("shells", 0))
	var bonus := relic_passive_sum(run, lib, &"shell_bonus_pct")
	if bonus > 0.0:
		shells = roundi(shells * (1.0 + bonus))
	run.shells += shells
	run.talismans = maxi(run.talismans - int(summary.get("talismans_spent", 0)), 0)
	lines.append("获得贝币 %d" % shells)
	for id: StringName in summary.get("captured", []):
		var name := beast_name(lib, id)
		if run.add_beast(id) == null:
			lines.append("%s 已记入图鉴，但阵容已满，只能放生" % name)
		else:
			lines.append("收服 %s" % name)
	if not bool(summary.get("won", false)):
		run.finished = true
		lines.append("鼎破，本局结束。")
		return lines
	var t := run.map.nodes[node_id].type
	if t != MapNode.Type.BOSS:
		run.pending_reward = roll_reward(run, lib, node_id, unlocked)
		return lines
	var region_name := Regions.display(run.region())
	if Regions.is_last_act(run.act):
		run.finished = true
		run.won = true
		lines.append("%s之鼎已修复。九州之中，已有 %d 鼎重归安宁，本局胜利！" % [region_name, Regions.ORDER.size()])
		return lines
	var relics := unowned_relics(run, lib)
	if not relics.is_empty():
		var rng := RngStream.new(run.battle_seed(node_id)).derive("boss_reward")
		rng.shuffle(relics)
		run.pending_reward = {"kind": "relic", "options": _strings(relics.slice(0, REWARD_CHOICES)), "skip_shells": SKIP_REWARD_SHELLS * 3}
	var heal := run.advance_act()
	lines.append("%s之鼎已修复！铜鼎回复 %d 点耐久，前往%s。" % [region_name, heal, Regions.display(run.region())])
	return lines


static func roll_reward(run: RunState, lib: ContentLibrary, node_id: int, unlocked: Array[StringName]) -> Dictionary:
	var rng := RngStream.new(run.battle_seed(node_id)).derive("reward")
	if run.map.nodes[node_id].type == MapNode.Type.ELITE:
		var relics := unowned_relics(run, lib)
		if not relics.is_empty():
			rng.shuffle(relics)
			return {"kind": "relic", "options": _strings(relics.slice(0, REWARD_CHOICES)), "skip_shells": SKIP_REWARD_SHELLS * 2}
	var pool := reward_pool(lib, unlocked)
	rng.shuffle(pool)
	return {"kind": "beast", "options": _strings(pool.slice(0, REWARD_CHOICES)), "skip_shells": SKIP_REWARD_SHELLS}


## 选第 index 个奖励。阵容满时必须给 release_uid（放生哪只），否则不生效并返回提示。
static func pick_reward(run: RunState, lib: ContentLibrary, index: int, release_uid: int = -1) -> String:
	var options: Array = run.pending_reward.get("options", [])
	if index < 0 or index >= options.size():
		return ""
	var id := StringName(options[index])
	var message := ""
	if run.pending_reward["kind"] == "relic":
		message = grant_relic(run, lib, id)
	else:
		if run.is_roster_full():
			if release_uid < 0 or run.remove_beast(release_uid) == null:
				return ROSTER_FULL
		run.add_beast(id)
		message = "%s 加入阵容" % beast_name(lib, id)
	run.pending_reward = {}
	return message


static func skip_reward(run: RunState) -> String:
	var shells := int(run.pending_reward.get("skip_shells", 0))
	run.shells += shells
	run.pending_reward = {}
	return "跳过奖励，拾得 %d 贝币" % shells


static func reward_pool(lib: ContentLibrary, unlocked: Array[StringName]) -> Array[StringName]:
	var commons := lib.common_beast_ids()
	var pool: Array[StringName] = []
	for id in commons:
		if unlocked.has(id):
			pool.append(id)
	return pool if pool.size() >= REWARD_CHOICES else commons


# ---------- 法宝 ----------

static func unowned_relics(run: RunState, lib: ContentLibrary) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in lib.relic_ids():
		if not run.relic_ids.has(id):
			out.append(id)
	return out


static func grant_relic(run: RunState, lib: ContentLibrary, id: StringName) -> String:
	var relic: RelicDef = lib.relics.get(id)
	if relic == null or run.relic_ids.has(id):
		return ""
	run.relic_ids.append(id)
	var notes := PackedStringArray(["获得法宝 %s：%s" % [relic.display_name, relic.description]])
	for eff in relic.effects:
		if eff.trigger == &"on_pickup":
			var note := apply_run_effect(run, lib, eff, null)
			if note != "":
				notes.append(note)
	return "；".join(notes)


static func relic_passive_sum(run: RunState, lib: ContentLibrary, op: StringName) -> float:
	var total := 0.0
	for id in run.relic_ids:
		var relic: RelicDef = lib.relics.get(id)
		if relic == null:
			continue
		for eff in relic.effects:
			if eff.trigger == &"passive" and eff.op == op:
				total += eff.amount
	return total


## 一局级效果（奇遇结果、法宝 on_pickup）。rng 可为 null（不需要随机时）。
static func apply_run_effect(run: RunState, lib: ContentLibrary, eff: EffectDef, rng: RngStream) -> String:
	match eff.op:
		&"gain_shells":
			run.shells += int(eff.amount)
			return "贝币 +%d" % int(eff.amount)
		&"heal_ding":
			var before := run.ding_hp
			run.ding_hp = mini(run.ding_max, run.ding_hp + int(eff.amount))
			return "鼎耐久 %d → %d" % [before, run.ding_hp]
		&"lose_ding":
			run.ding_hp = maxi(run.ding_hp - int(eff.amount), 1)
			return "鼎耐久 -%d" % int(eff.amount)
		&"ding_max":
			run.ding_max += int(eff.amount)
			run.ding_hp += int(eff.amount)
			return "鼎耐久上限 +%d" % int(eff.amount)
		&"gain_talismans":
			run.talismans += int(eff.amount)
			return "镇鼎符 +%d" % int(eff.amount)
		&"gain_relic":
			var id := eff.param_id
			if id == &"" or run.relic_ids.has(id):
				var pool := unowned_relics(run, lib)
				if pool.is_empty():
					run.shells += 10
					return "法宝都已到手，改得贝币 10"
				id = pool[0] if rng == null else pool[rng.next_int(0, pool.size() - 1)]
			return grant_relic(run, lib, id)
		&"gain_beast":
			if run.add_beast(eff.param_id) == null:
				return "阵容已满，%s 离去了" % beast_name(lib, eff.param_id)
			return "%s 加入阵容" % beast_name(lib, eff.param_id)
		&"tier_up_random":
			var candidates: Array[BeastInstance] = []
			for b in run.roster:
				if b.tier < BeastInstance.MAX_TIER:
					candidates.append(b)
			if candidates.is_empty():
				return "没有可以提升的异兽"
			var pick := candidates[0] if rng == null else candidates[rng.next_int(0, candidates.size() - 1)]
			pick.tier += 1
			return "%s 升到 %d 阶" % [beast_name(lib, pick.beast_id), pick.tier]
	return ""


# ---------- 集市 ----------

## 商品：[{kind: beast|relic|talismans|repair, id, price, amount}]
static func shop_offers(run: RunState, lib: ContentLibrary, node_id: int, unlocked: Array[StringName]) -> Array[Dictionary]:
	var rng := RngStream.new(run.battle_seed(node_id)).derive("shop")
	var offers: Array[Dictionary] = []
	var pool := reward_pool(lib, unlocked)
	rng.shuffle(pool)
	for id in pool.slice(0, SHOP_BEASTS):
		offers.append({"kind": "beast", "id": String(id), "price": BEAST_PRICE + rng.next_int(-2, 2)})
	var relics := unowned_relics(run, lib)
	rng.shuffle(relics)
	for id in relics.slice(0, SHOP_RELICS):
		offers.append({"kind": "relic", "id": String(id), "price": (lib.relics[id] as RelicDef).price})
	offers.append({"kind": "talismans", "id": "", "price": TALISMAN_PACK_PRICE, "amount": TALISMAN_PACK})
	offers.append({"kind": "repair", "id": "", "price": REPAIR_PRICE, "amount": REPAIR_AMOUNT})
	return offers


static func is_sold(run: RunState, node_id: int, index: int) -> bool:
	return (run.shop_bought.get(_shop_key(run, node_id), []) as Array).has(index)


## 不同州的路线图节点 id 会重复，售出记录按"州序号:节点"区分。
static func _shop_key(run: RunState, node_id: int) -> String:
	return "%d:%d" % [run.act, node_id]


static func buy(run: RunState, lib: ContentLibrary, node_id: int, index: int, unlocked: Array[StringName], release_uid: int = -1) -> String:
	var offers := shop_offers(run, lib, node_id, unlocked)
	if index < 0 or index >= offers.size():
		return ""
	var o := offers[index]
	var repeatable: bool = o["kind"] == "talismans" or o["kind"] == "repair"
	if not repeatable and is_sold(run, node_id, index):
		return "已经卖掉了"
	if run.shells < int(o["price"]):
		return "贝币不够"
	var message := ""
	match o["kind"]:
		"beast":
			if run.is_roster_full():
				if release_uid < 0 or run.remove_beast(release_uid) == null:
					return ROSTER_FULL
			run.add_beast(StringName(o["id"]))
			message = "买下 %s" % beast_name(lib, StringName(o["id"]))
		"relic":
			message = grant_relic(run, lib, StringName(o["id"]))
		"talismans":
			run.talismans += int(o["amount"])
			message = "镇鼎符 +%d" % int(o["amount"])
		"repair":
			if run.ding_hp >= run.ding_max:
				return "铜鼎完好，不用修"
			run.ding_hp = mini(run.ding_max, run.ding_hp + int(o["amount"]))
			message = "修鼎，耐久 %d/%d" % [run.ding_hp, run.ding_max]
	run.shells -= int(o["price"])
	if not repeatable:
		var key := _shop_key(run, node_id)
		var bought: Array = run.shop_bought.get(key, [])
		bought.append(index)
		run.shop_bought[key] = bought
	return message


## 放生。至少留一只。
static func release(run: RunState, lib: ContentLibrary, uid: int) -> String:
	if run.roster.size() <= 1:
		return "至少要留一只异兽"
	var b := run.remove_beast(uid)
	return "" if b == null else "放生 %s" % beast_name(lib, b.beast_id)


# ---------- 炼鼎 ----------

## 可以合成升阶的组合：[[uid_a, uid_b], ...]（同种同阶、未满阶）。
static func merge_candidates(run: RunState) -> Array[Array]:
	var out: Array[Array] = []
	var used := {}
	for i in run.roster.size():
		for j in range(i + 1, run.roster.size()):
			var a := run.roster[i]
			var b := run.roster[j]
			if used.has(a.uid) or used.has(b.uid):
				continue
			if a.beast_id == b.beast_id and a.tier == b.tier and a.tier < BeastInstance.MAX_TIER:
				out.append([a.uid, b.uid])
				used[a.uid] = true
				used[b.uid] = true
	return out


static func merge(run: RunState, lib: ContentLibrary, uid_a: int, uid_b: int) -> String:
	var a := run.instance_by_uid(uid_a)
	var b := run.instance_by_uid(uid_b)
	if a == null or b == null or a == b or a.beast_id != b.beast_id or a.tier != b.tier or a.tier >= BeastInstance.MAX_TIER:
		return ""
	a.tier += 1
	run.remove_beast(uid_b)
	run.node_resolved = true
	return "%s 升到 %d 阶" % [beast_name(lib, a.beast_id), a.tier]


## 可以融合的配方：[{recipe: FusionRecipe, a_uid, b_uid}]
static func fusion_candidates(run: RunState, lib: ContentLibrary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for recipe in lib.fusion_list():
		var a := _first_of(run, recipe.a, -1)
		var b := _first_of(run, recipe.b, a.uid if a != null else -1)
		if a != null and b != null:
			out.append({"recipe": recipe, "a_uid": a.uid, "b_uid": b.uid})
	return out


static func fuse(run: RunState, lib: ContentLibrary, recipe_id: StringName) -> String:
	for c in fusion_candidates(run, lib):
		var recipe: FusionRecipe = c["recipe"]
		if recipe.id != recipe_id:
			continue
		var a := run.instance_by_uid(c["a_uid"])
		var b := run.instance_by_uid(c["b_uid"])
		var tier := maxi(a.tier, b.tier)
		run.remove_beast(a.uid)
		run.remove_beast(b.uid)
		run.add_beast(recipe.result, tier)
		run.node_resolved = true
		return "%s 与 %s 融为 %s！" % [beast_name(lib, recipe.a), beast_name(lib, recipe.b), beast_name(lib, recipe.result)]
	return ""


# ---------- 奇遇 ----------

static func event_for_node(run: RunState, lib: ContentLibrary, node_id: int) -> EventDef:
	var ids := lib.event_ids()
	if ids.is_empty():
		return null
	var fresh: Array[StringName] = []
	for id in ids:
		if not run.seen_events.has(id):
			fresh.append(id)
	var pool := fresh if not fresh.is_empty() else ids
	var rng := RngStream.new(run.battle_seed(node_id)).derive("event")
	return lib.events[pool[rng.next_int(0, pool.size() - 1)]]


static func resolve_event(run: RunState, lib: ContentLibrary, node_id: int, option_index: int) -> String:
	if run.node_resolved:
		return ""
	var ev := event_for_node(run, lib, node_id)
	if ev == null or option_index < 0 or option_index >= ev.options.size():
		return ""
	var opt := ev.options[option_index]
	if run.shells < opt.cost_shells:
		return "贝币不够"
	run.shells -= opt.cost_shells
	var rng := RngStream.new(run.battle_seed(node_id)).derive("event_roll")
	var success := opt.success_chance >= 1.0 or rng.next_float() < opt.success_chance
	var notes := PackedStringArray()
	var text := opt.success_text if success else opt.fail_text
	if text != "":
		notes.append(text)
	for eff in (opt.outcomes if success else opt.fail_outcomes):
		var note := apply_run_effect(run, lib, eff, rng)
		if note != "":
			notes.append(note)
	run.seen_events.append(ev.id)
	run.node_resolved = true
	return "；".join(notes) if not notes.is_empty() else "无事发生。"


# ---------- 祭祀 ----------

static func rest_heal(run: RunState) -> String:
	if run.node_resolved:
		return ""
	var before := run.ding_hp
	run.ding_hp = mini(run.ding_max, run.ding_hp + REST_HEAL)
	run.node_resolved = true
	return "祭祀修鼎：耐久 %d → %d" % [before, run.ding_hp]


static func rest_fortify(run: RunState) -> String:
	if run.node_resolved:
		return ""
	run.ding_max += REST_FORTIFY
	run.ding_hp += REST_FORTIFY
	run.node_resolved = true
	return "祭天加固：耐久上限 +%d（%d/%d）" % [REST_FORTIFY, run.ding_hp, run.ding_max]


# ---------- 工具 ----------

static func beast_name(lib: ContentLibrary, id: StringName) -> String:
	var def: BeastDef = lib.beasts.get(id)
	return def.display_name if def != null else String(id)


static func _first_of(run: RunState, beast_id: StringName, exclude_uid: int) -> BeastInstance:
	for b in run.roster:
		if b.beast_id == beast_id and b.uid != exclude_uid:
			return b
	return null


static func _strings(ids: Array) -> Array:
	var out: Array = []
	for id: Variant in ids:
		out.append(String(id))
	return out
