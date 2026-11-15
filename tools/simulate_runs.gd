extends SceneTree
## 整局模拟：自动玩家从开局一路打到首领（或鼎破），检验流程和整局难度曲线。
##   godot --headless --path . --script res://tools/simulate_runs.gd
##
## 策略（偏保守的普通玩家）：路线上优先战斗和精英以外的节点各走一点；战斗用 AutoPlayer；
## 奖励选第一个；集市先买异兽再买法宝；炼鼎能融合就融合、否则升阶；奇遇选第一个；祭祀残血修鼎、否则加固。

const SEEDS := 20

## 诊断：进各州首领战时的铜鼎耐久、首领本体是否漏到鼎前。
var _boss_entry: Dictionary = {}
var _boss_leaks: Dictionary = {}


func _initialize() -> void:
	var lib := ContentLibrary.load_from()
	print("守鼎人\t通关\t平均到达层\t平均最终阵容\t平均剩余鼎\t死在")
	for kid in lib.keeper_ids():
		var wins := 0
		var layers := 0
		var roster := 0
		var ding := 0
		var deaths := {}
		for s in SEEDS:
			var result := _play(lib, kid, 1000 + s)
			if result["won"]:
				wins += 1
				ding += int(result["ding"])
			else:
				var where: String = result["died_at"]
				deaths[where] = int(deaths.get(where, 0)) + 1
			layers += int(result["layer"])
			roster += int(result["roster"])
		var diag := PackedStringArray()
		for region: String in _boss_entry:
			var entries: Array = _boss_entry[region]
			var total := 0
			for v: int in entries:
				total += v
			diag.append("进%s首领 %d 次、平均鼎 %.1f、首领漏到鼎前 %d 次" % [region, entries.size(), float(total) / maxi(entries.size(), 1), int(_boss_leaks.get(region, 0))])
		_boss_entry.clear()
		_boss_leaks.clear()
		print("%s\t%d/%d\t%.1f\t%.1f\t%.1f\t%s\n    %s" % [(lib.keepers[kid] as KeeperDef).display_name, wins, SEEDS,
			float(layers) / SEEDS, float(roster) / SEEDS, float(ding) / maxi(wins, 1), str(deaths), "；".join(diag)])
	quit()


func _play(lib: ContentLibrary, keeper_id: StringName, seed_value: int) -> Dictionary:
	var keeper: KeeperDef = lib.keepers[keeper_id]
	var run := RunState.new_run(seed_value, keeper.starting_beasts, keeper_id, keeper.starting_talismans)
	var unlocked: Array[StringName] = keeper.starting_beasts.duplicate()
	var rng := RngStream.new(seed_value).derive("route")
	var layer := 0
	while not run.finished:
		var options := run.available_nodes()
		if options.is_empty():
			break
		var node_id := options[rng.next_int(0, options.size() - 1)]
		run.enter_node(node_id)
		var node := run.map.nodes[node_id]
		layer = node.layer + run.act * (run.map.layers.size() - 1)
		match node.type:
			MapNode.Type.BATTLE, MapNode.Type.ELITE, MapNode.Type.BOSS:
				var summary := _battle(lib, run, node_id)
				for id: StringName in summary["captured"]:
					if not unlocked.has(id):
						unlocked.append(id)
				RunRules.apply_battle_result(run, lib, node_id, summary, unlocked)
				if not run.pending_reward.is_empty():
					RunRules.pick_reward(run, lib, 0, run.roster[0].uid if run.is_roster_full() else -1)
				if run.finished and not run.won:
					return {"won": false, "layer": layer, "roster": run.roster.size(), "died_at": "%s%s" % [Regions.display(Regions.for_act(run.act)), MapNode.DISPLAY[node.type]], "ding": 0}
			MapNode.Type.SHOP:
				var offers := RunRules.shop_offers(run, lib, node_id, unlocked)
				for i in offers.size():
					if offers[i]["kind"] in ["beast", "relic"] and run.shells >= int(offers[i]["price"]) and not run.is_roster_full():
						RunRules.buy(run, lib, node_id, i, unlocked)
				if run.ding_hp < run.ding_max - 2:
					RunRules.buy(run, lib, node_id, offers.size() - 1, unlocked)
			MapNode.Type.FORGE:
				var fusions := RunRules.fusion_candidates(run, lib)
				if not fusions.is_empty():
					RunRules.fuse(run, lib, (fusions[0]["recipe"] as FusionRecipe).id)
				else:
					var merges := RunRules.merge_candidates(run)
					if not merges.is_empty():
						RunRules.merge(run, lib, merges[0][0], merges[0][1])
			MapNode.Type.EVENT:
				RunRules.resolve_event(run, lib, node_id, 0)
			MapNode.Type.REST:
				if run.ding_hp <= run.ding_max - RunRules.REST_HEAL:
					RunRules.rest_heal(run)
				else:
					RunRules.rest_fortify(run)
	return {"won": run.won, "layer": layer, "roster": run.roster.size(), "died_at": "", "ding": run.ding_hp}


func _battle(lib: ContentLibrary, run: RunState, node_id: int) -> Dictionary:
	var kind := BattleDef.Kind.NORMAL
	match run.map.nodes[node_id].type:
		MapNode.Type.ELITE:
			kind = BattleDef.Kind.ELITE
		MapNode.Type.BOSS:
			kind = BattleDef.Kind.BOSS
	var options := lib.battles_of_kind(kind, run.region())
	var battle := options[RngStream.new(run.battle_seed(node_id)).next_int(0, options.size() - 1)]
	var setup := BattleSetup.new()
	setup.roster = run.roster.duplicate()
	for id in run.relic_ids:
		setup.relics.append(lib.relics[id])
	setup.ding_hp = run.ding_hp
	setup.ding_max = run.ding_max
	setup.talismans = mini(run.talismans, BattleSim.CAPTURE_LIMIT_PER_BATTLE)
	setup.seed_value = run.battle_seed(node_id)
	setup.keeper = lib.keepers.get(run.keeper_id)
	setup.formations = lib.formation_list()
	setup.hp_scale = run.difficulty_scale(node_id)
	setup.boss_hp_scale = run.boss_scale()
	var sim := BattleSim.create(battle, lib.beasts, lib.chart, setup)
	var region := Regions.display(run.region())
	if kind == BattleDef.Kind.BOSS:
		if not _boss_entry.has(region):
			_boss_entry[region] = []
		_boss_entry[region].append(run.ding_hp)
	sim.begin()
	var ap := AutoPlayer.new()
	while sim.is_running() and sim.tick < 30000:
		ap.act(sim)
		sim.step()
		if kind == BattleDef.Kind.BOSS:
			for ev in sim.events:
				if ev["type"] == "leaked" and bool(ev["boss"]):
					_boss_leaks[region] = int(_boss_leaks.get(region, 0)) + 1
	return {"won": sim.outcome == BattleSim.Outcome.WON, "ding_hp": sim.ding_hp, "shells": sim.shells_earned,
		"talismans_spent": sim.run_talismans_spent(), "captured": sim.captured_beasts}
