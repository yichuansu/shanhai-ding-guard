extends TestCase
## P2：战后奖励、集市、炼鼎、奇遇、祭祀、法宝获取、首领机制。

var lib := ContentLibrary.load_from()


func _run(beasts: Array[StringName] = [&"jingwei", &"bifang"]) -> RunState:
	return RunState.new_run(321, beasts, &"zhudingjiang")


func _node_of(run: RunState, t: MapNode.Type) -> int:
	for n in run.map.nodes:
		if n.type == t:
			return n.id
	return -1


func _summary(won: bool, shells: int = 5, captured: Array[StringName] = []) -> Dictionary:
	return {"won": won, "ding_hp": 8, "shells": shells, "talismans_spent": 1, "captured": captured}


func test_normal_battle_rewards_three_distinct_beasts() -> void:
	var run := _run()
	var node := run.map.layers[0][0]
	var lines := RunRules.apply_battle_result(run, lib, node, _summary(true), [] as Array[StringName])
	check(lines.size() > 0, "有结算文字")
	check_eq(run.ding_hp, 8)
	check_eq(run.talismans, RunState.DEFAULT_TALISMANS - 1)
	var r := run.pending_reward
	check_eq(r["kind"], "beast")
	var opts: Array = r["options"]
	check_eq(opts.size(), 3)
	var unique := {}
	for o: String in opts:
		unique[o] = true
		check((lib.beasts[StringName(o)] as BeastDef).rarity == BeastDef.Rarity.COMMON, "奖励只出普通异兽")
	check_eq(unique.size(), 3, "三个选项不重复")
	var again := _run()
	RunRules.apply_battle_result(again, lib, node, _summary(true), [] as Array[StringName])
	check_eq(again.pending_reward, r, "同种子同节点奖励一致")


func test_unlocked_pool_is_preferred() -> void:
	var pool := RunRules.reward_pool(lib, [&"jingwei", &"bifang", &"huashe"] as Array[StringName])
	check_eq(pool.size(), 3, "解锁满 3 只时只从解锁里出")
	check_eq(RunRules.reward_pool(lib, [&"jingwei"] as Array[StringName]), lib.common_beast_ids(), "不足 3 只时用全部普通异兽")


func test_pick_and_skip_reward() -> void:
	var run := _run()
	run.pending_reward = {"kind": "beast", "options": ["huashe", "mingshe", "lili"], "skip_shells": 6}
	RunRules.pick_reward(run, lib, 1)
	check_eq(run.roster.back().beast_id, &"mingshe", "选中的加入阵容")
	check(run.pending_reward.is_empty(), "奖励领完清空")
	run.pending_reward = {"kind": "beast", "options": ["huashe"], "skip_shells": 6}
	var shells := run.shells
	RunRules.skip_reward(run)
	check_eq(run.shells, shells + 6)


func test_full_roster_requires_release() -> void:
	var run := _run([&"jingwei", &"jingwei", &"jingwei", &"jingwei", &"jingwei", &"jingwei"] as Array[StringName])
	run.pending_reward = {"kind": "beast", "options": ["huashe"], "skip_shells": 6}
	check_eq(RunRules.pick_reward(run, lib, 0), RunRules.ROSTER_FULL, "满了不放生不能领")
	check(not run.pending_reward.is_empty(), "奖励还在")
	RunRules.pick_reward(run, lib, 0, run.roster[0].uid)
	check_eq(run.roster.size(), 6)
	check_eq(run.roster.back().beast_id, &"huashe", "放生一只后加入")


func test_elite_rewards_relics_and_pickup_effects() -> void:
	var run := _run()
	var elite := _node_of(run, MapNode.Type.ELITE)
	if elite < 0:
		return
	RunRules.apply_battle_result(run, lib, elite, _summary(true), [] as Array[StringName])
	check_eq(run.pending_reward["kind"], "relic", "精英给法宝")
	var max_before := run.ding_max
	RunRules.grant_relic(run, lib, &"yugao")
	check_eq(run.ding_max, max_before + 2, "玉膏：获得时上限 +2")
	check_eq(RunRules.grant_relic(run, lib, &"yugao"), "", "同一法宝不重复获得")


func test_battle_result_shell_bonus_loss_and_boss() -> void:
	var run := _run()
	run.relic_ids.append(&"lushu")
	RunRules.apply_battle_result(run, lib, run.map.layers[0][0], _summary(true, 10), [] as Array[StringName])
	check_eq(run.shells, 13, "鹿蜀皮 +30%")
	var lost := _run()
	RunRules.apply_battle_result(lost, lib, lost.map.layers[0][0], _summary(false), [] as Array[StringName])
	check(lost.finished and not lost.won and lost.pending_reward.is_empty(), "失败结束本局，没有奖励")
	var boss := _run()
	boss.act = Regions.ORDER.size() - 1
	boss._build_map()
	RunRules.apply_battle_result(boss, lib, boss.map.boss_id(), _summary(true), [] as Array[StringName])
	check(boss.finished and boss.won, "打败最后一州的首领本局胜利")


func test_shop_buy_marks_sold_and_charges() -> void:
	var run := _run()
	run.shells = 100
	var node := _node_of(run, MapNode.Type.SHOP)
	var offers := RunRules.shop_offers(run, lib, node, [] as Array[StringName])
	check_eq(offers.size(), RunRules.SHOP_BEASTS + RunRules.SHOP_RELICS + 2, "3 异兽 + 2 法宝 + 镇鼎符 + 修鼎")
	check_eq(offers, RunRules.shop_offers(run, lib, node, [] as Array[StringName]), "商品固定")
	var price := int(offers[0]["price"])
	RunRules.buy(run, lib, node, 0, [] as Array[StringName])
	check_eq(run.shells, 100 - price)
	check(RunRules.is_sold(run, node, 0), "标记售出")
	check_eq(RunRules.buy(run, lib, node, 0, [] as Array[StringName]), "已经卖掉了")
	var t_index := offers.size() - 2
	var talismans := run.talismans
	RunRules.buy(run, lib, node, t_index, [] as Array[StringName])
	RunRules.buy(run, lib, node, t_index, [] as Array[StringName])
	check_eq(run.talismans, talismans + 2 * RunRules.TALISMAN_PACK, "镇鼎符可以重复买")
	run.shells = 0
	check_eq(RunRules.buy(run, lib, node, 1, [] as Array[StringName]), "贝币不够")
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())))
	check(RunRules.is_sold(restored, node, 0), "读档后售出状态还在")


func test_forge_merge_and_fusion() -> void:
	var run := _run([&"jingwei", &"jingwei", &"bifang"] as Array[StringName])
	var merges := RunRules.merge_candidates(run)
	check_eq(merges.size(), 1, "两只精卫可合成")
	var fusions := RunRules.fusion_candidates(run, lib)
	check_eq(fusions.size(), 1, "精卫 + 毕方 可融合")
	run.roster[0].tier = 2
	check_eq(RunRules.merge_candidates(run).size(), 0, "阶位不同不能合成")
	var msg := RunRules.fuse(run, lib, &"mu_huo_fenghuang")
	check(msg != "", "融合成功")
	check_eq(run.roster.size(), 2, "两只变一只")
	check_eq(run.roster.back().beast_id, &"fenghuang")
	check_eq(run.roster.back().tier, 2, "取两者较高阶位")
	check(run.node_resolved, "炼鼎用掉")


func test_rare_beasts_never_in_rewards() -> void:
	for id in lib.common_beast_ids():
		check((lib.beasts[id] as BeastDef).rarity != BeastDef.Rarity.RARE, "%s 不是稀有" % id)
	for recipe in lib.fusion_list():
		var result: BeastDef = lib.beasts[recipe.result]
		check_eq(result.rarity, BeastDef.Rarity.RARE, "%s 的产物是稀有异兽" % recipe.id)
		check(Elements.generates((lib.beasts[recipe.a] as BeastDef).element, result.element), "%s 符合相生" % recipe.id)


func test_event_resolution() -> void:
	var run := _run()
	var node := _node_of(run, MapNode.Type.EVENT)
	if node < 0:
		return
	var ev := RunRules.event_for_node(run, lib, node)
	check(ev != null, "选出奇遇")
	check_eq(RunRules.event_for_node(run, lib, node), ev, "同节点同奇遇")
	run.shells = 50
	var msg := RunRules.resolve_event(run, lib, node, 0)
	check(msg != "", "有结果文字")
	check(run.seen_events.has(ev.id), "记为见过")
	check_eq(RunRules.resolve_event(run, lib, node, 0), "", "同一节点只能选一次")


func test_event_effects_apply() -> void:
	var run := _run()
	var ev: EventDef = lib.events[&"mi_yugao"]
	var max_before := run.ding_max
	for eff in ev.options[0].outcomes:
		RunRules.apply_run_effect(run, lib, eff, null)
	check_eq(run.ding_max, max_before + 2, "玉膏涂鼎")
	var kui: EventDef = lib.events[&"liubo_kui"]
	run.ding_hp = 10
	for eff in kui.options[0].outcomes:
		RunRules.apply_run_effect(run, lib, eff, null)
	check_eq(run.roster.back().beast_id, &"kui", "夔加入")
	run.ding_hp = 2
	RunRules.apply_run_effect(run, lib, kui.options[0].outcomes[0], null)
	check_eq(run.ding_hp, 1, "奇遇不会直接把鼎打破")


func test_rest_choices() -> void:
	var run := _run()
	run.ding_hp = 3
	RunRules.rest_heal(run)
	check_eq(run.ding_hp, 3 + RunRules.REST_HEAL)
	check_eq(RunRules.rest_fortify(run), "", "祭祀只能选一次")
	var other := _run()
	RunRules.rest_fortify(other)
	check_eq(other.ding_max, RunState.DEFAULT_DING + RunRules.REST_FORTIFY)


func test_boss_stuns_towers_and_summons() -> void:
	var boss := Fixtures.beast(&"boss", Elements.SHUI, 1000, 20.0)
	boss.rarity = BeastDef.Rarity.BOSS
	var stun := EffectDef.new()
	stun.trigger = &"periodic"
	stun.op = &"stun_towers"
	stun.interval_ticks = 10
	stun.duration_ticks = 5
	stun.count = 1
	var summon := EffectDef.new()
	summon.trigger = &"hp_below"
	summon.op = &"summon"
	summon.amount = 0.5
	summon.count = 3
	summon.param_id = &"minion"
	boss.abilities = [stun, summon]
	var minion := Fixtures.beast(&"minion", Elements.SHUI, 10, 2000.0)
	var ally := Fixtures.beast(&"ally", Elements.JIN)
	ally.damage = 0
	var sim := BattleSim.create(Fixtures.straight_battle(&"boss"), Fixtures.library([boss, minion, ally]), ElementChart.new(), Fixtures.setup([&"ally"] as Array[StringName], 50))
	sim.begin()
	sim.queue_deploy(1, 0)
	var stunned := false
	for i in 30:
		sim.step()
		for ev in sim.events:
			if ev["type"] == "towers_stunned":
				stunned = true
	check(stunned, "首领定期定住异兽")
	check((sim.towers[0] as TowerUnit).stunned_ticks >= 0, "定身计时有效")
	var b := sim.enemies[0]
	b.hp = 400.0
	sim.step()
	check_eq(sim.enemies.size(), 4, "血量过半召出 3 只")
	sim.step()
	check_eq(sim.enemies.size() - 1, sim.enemies.filter(func(e: EnemyUnit) -> bool: return e.def.id == &"minion").size(), "其余都是随从")
	b.hp = 300.0
	sim.step()
	check(sim.enemies.filter(func(e: EnemyUnit) -> bool: return e.def.id == &"minion").size() <= 3, "同一血线只触发一次")
	b.hp = 0.0
	b.alive = false
	sim._resolve(b)
	while sim.is_running():
		sim.step()
	check_eq(sim.outcome, BattleSim.Outcome.WON, "召唤物计入波次，全部结算后判胜")


func test_stunned_tower_does_not_fire() -> void:
	var foe := Fixtures.beast(&"foe", Elements.TU, 100000, 30.0)
	var ally := Fixtures.beast(&"ally", Elements.HUO)
	var sim := BattleSim.create(Fixtures.straight_battle(&"foe"), Fixtures.library([foe, ally]), ElementChart.new(), Fixtures.setup([&"ally"] as Array[StringName]))
	sim.begin()
	sim.queue_deploy(1, 0)
	sim.step()
	(sim.towers[0] as TowerUnit).stunned_ticks = 1000
	var fired := 0
	for i in 300:
		sim.step()
		for ev in sim.events:
			if ev["type"] == "fired":
				fired += 1
	check_eq(fired, 0, "被定住不开火")


func test_relic_battle_effects() -> void:
	var foe := Fixtures.beast(&"foe", Elements.TU, 10, 2000.0)
	var battle := Fixtures.straight_battle(&"foe", 1, 5)
	var s := SpawnEntry.new()
	s.beast_id = &"foe"
	var w := WaveDef.new()
	w.gap_ticks_before = 100
	w.spawns = [s]
	battle.waves.append(w)
	var setup := Fixtures.setup([] as Array[StringName], 20)
	setup.relics = [lib.relics[&"ditai_qi"], lib.relics[&"migu"]]
	var sim := BattleSim.create(battle, Fixtures.library([foe]), ElementChart.new(), setup)
	var start := sim.spirit
	sim.begin()
	check_eq(sim.spirit, start + 6, "帝台之棋：开局 +6")
	while sim.wave_gap_remaining() == 0 and sim.is_running():
		sim.step()
	var gap := sim.wave_gap_remaining()
	check_eq(sim.early_call_bonus(), ceili(gap / 10.0 * BattleSim.EARLY_CALL_SPIRIT_PER_SECOND * 2.0), "迷穀：提前召唤奖励翻倍")


func test_stagger_freezes_non_boss() -> void:
	var foe := Fixtures.beast(&"foe", Elements.TU, 100000, 30.0)
	var ally := Fixtures.beast(&"ally", Elements.JIN)
	var eff := EffectDef.new()
	eff.trigger = &"on_hit"
	eff.op = &"stagger"
	eff.amount = 1.0
	eff.duration_ticks = 10
	ally.traits = [eff]
	var sim := BattleSim.create(Fixtures.straight_battle(&"foe"), Fixtures.library([foe, ally]), ElementChart.new(), Fixtures.setup([&"ally"] as Array[StringName]))
	sim.begin()
	sim.queue_deploy(1, 0)
	var frozen := false
	for i in 300:
		sim.step()
		if not sim.enemies.is_empty() and sim.enemies[0].frozen_ticks > 0:
			frozen = true
			break
	check(frozen, "震慑生效")
