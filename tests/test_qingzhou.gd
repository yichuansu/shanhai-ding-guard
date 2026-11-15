extends TestCase
## 第二州青州：两幕流程、按州选战场、蜚的光环与吸灵气、图鉴分栏。

var lib := ContentLibrary.load_from()


func _summary(won: bool) -> Dictionary:
	return {"won": won, "ding_hp": 4, "shells": 5, "talismans_spent": 0, "captured": [] as Array[StringName]}


func test_first_boss_advances_to_next_region() -> void:
	var run := RunState.new_run(77, [&"jingwei", &"bifang"] as Array[StringName])
	check_eq(run.region(), &"jizhou")
	var old_map_size := run.map.nodes.size()
	run.enter_node(run.map.layers[0][0])
	var lines := RunRules.apply_battle_result(run, lib, run.map.boss_id(), _summary(true), [] as Array[StringName])
	check(not run.finished, "打完冀州首领还没通关")
	check_eq(run.act, 1)
	check_eq(run.region(), &"qingzhou")
	check_eq(run.current_node, -1, "新州从头走")
	check(run.visited.is_empty(), "清空走过的节点")
	check_eq(run.ding_hp, 4 + ceili((run.ding_max - 4) * RunState.ACT_HEAL_RATIO), "回复一半已损失耐久")
	check_eq(run.pending_reward.get("kind"), "relic", "首领给法宝三选一")
	check("".join(lines).contains("青州"), "结算提示前往青州")
	check(run.map.nodes.size() > 0 and old_map_size > 0, "重建了路线图")


func test_difficulty_continues_across_regions() -> void:
	var run := RunState.new_run(5, [] as Array[StringName])
	var jizhou_first := run.difficulty_scale(run.map.layers[0][0])
	run.advance_act()
	var qingzhou_first := run.difficulty_scale(run.map.layers[0][0])
	check_near(qingzhou_first, jizhou_first + RunState.DIFFICULTY_PER_ACT, 0.0001, "青州第一层比冀州第一层高一个州间台阶")
	check(run.difficulty_scale(run.map.boss_id()) > qingzhou_first, "青州内逐层递增")
	check_near(run.boss_scale(), 1.0 + RunState.DIFFICULTY_PER_ACT, 0.0001, "首领只随州数放大")


func test_run_state_round_trip_keeps_act() -> void:
	var run := RunState.new_run(9, [&"jingwei"] as Array[StringName])
	run.advance_act()
	var first := run.available_nodes()[0]
	run.enter_node(first)
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())))
	check_eq(restored.act, 1)
	check_eq(restored.region(), &"qingzhou")
	check_eq(restored.map.nodes.size(), run.map.nodes.size(), "按州重建同一张路线图")
	check_eq(restored.available_nodes(), run.available_nodes())


func test_shop_sold_state_is_per_region() -> void:
	var run := RunState.new_run(11, [&"jingwei"] as Array[StringName])
	run.shells = 200
	var shop := -1
	for n in run.map.nodes:
		if n.type == MapNode.Type.SHOP:
			shop = n.id
	RunRules.buy(run, lib, shop, 0, [] as Array[StringName])
	check(RunRules.is_sold(run, shop, 0), "冀州集市售出")
	run.advance_act()
	check(not RunRules.is_sold(run, shop, 0), "进入青州后，同编号节点的集市是新的")


func test_battles_are_picked_by_region() -> void:
	for region in Regions.ORDER:
		for kind in [BattleDef.Kind.NORMAL, BattleDef.Kind.ELITE, BattleDef.Kind.BOSS]:
			var list := lib.battles_of_kind(kind, region)
			check(not list.is_empty(), "%s 有 %d 类战场" % [region, kind])
			for b in list:
				check_eq(b.region, region)
	var boss: BattleDef = lib.battles_of_kind(BattleDef.Kind.BOSS, &"qingzhou")[0]
	var has_fei := false
	for w in boss.waves:
		for s in w.spawns:
			if s.beast_id == &"fei":
				has_fei = true
	check(has_fei, "青州首领战出现蜚")


func test_qingzhou_path_slots_are_clear_of_path() -> void:
	var battle: BattleDef = lib.battles[&"qingzhou_b01"]
	var path := PathCurve.new(battle.path_points)
	for slot in battle.slots:
		var gap := path.closest(slot).y
		check(gap >= 70.0, "鼎位 %s 不压在路上（距路 %.0f）" % [slot, gap])
		check(gap <= 230.0, "鼎位 %s 离路不太远（距路 %.0f）" % [slot, gap])
	for p in battle.path_points:
		check(p.x >= 0 and p.x <= 1920 and p.y >= 0 and p.y <= 1080, "路径点在画面内")


func test_aura_weakens_nearby_towers() -> void:
	var boss := Fixtures.beast(&"boss", Elements.JIN, 100000, 10.0)
	boss.rarity = BeastDef.Rarity.BOSS
	var aura := EffectDef.new()
	aura.trigger = &"aura"
	aura.op = &"weaken_towers"
	aura.amount = 0.4
	aura.radius = 300.0
	boss.abilities = [aura]
	var ally := Fixtures.beast(&"ally", Elements.HUO)
	var sim := BattleSim.create(Fixtures.straight_battle(&"boss"), Fixtures.library([boss, ally]), ElementChart.new(), Fixtures.setup([&"ally"] as Array[StringName]))
	sim.begin()
	sim.queue_deploy(1, 0)
	sim.step()
	var t: TowerUnit = sim.towers[0]
	var e := sim.enemies[0]
	var far := sim.damage_against(t, e)
	e.distance = 500.0
	check_near(sim.aura_weakening(t.position), 0.4, 0.0001, "光环范围内")
	check_near(sim.damage_against(t, e), far * 0.6, 0.01, "伤害打六折")


func test_drain_spirit() -> void:
	var boss := Fixtures.beast(&"boss", Elements.JIN, 100000, 10.0)
	boss.rarity = BeastDef.Rarity.BOSS
	var drain := EffectDef.new()
	drain.trigger = &"periodic"
	drain.op = &"drain_spirit"
	drain.amount = 5.0
	drain.interval_ticks = 10
	boss.abilities = [drain]
	var battle := Fixtures.straight_battle(&"boss")
	battle.spirit_income_interval_ticks = 0
	var sim := BattleSim.create(battle, Fixtures.library([boss]), ElementChart.new(), Fixtures.setup([] as Array[StringName]))
	sim.begin()
	var start := sim.spirit
	for i in 25:
		sim.step()
	check_eq(sim.spirit, start - 10, "每 10 拍吸走 5 点")
	sim.spirit = 2
	for i in 10:
		sim.step()
	check_eq(sim.spirit, 0, "灵气不会被吸成负数")


func test_qingzhou_content() -> void:
	var fei: BeastDef = lib.beasts[&"fei"]
	check_eq(fei.region, &"qingzhou")
	check_eq(fei.abilities.size(), 3, "蜚有三个机制")
	for id in [&"goumang", &"tianwu"]:
		check_eq((lib.beasts[id] as BeastDef).rarity, BeastDef.Rarity.RARE, "%s 是稀有异兽" % id)
	for id in Bestiary.section_ids(lib, "qingzhou"):
		check((lib.beasts[id] as BeastDef).lore != "", "%s 有原文" % id)


func test_boss_leak_always_loses_even_with_wave_heal() -> void:
	var boss := Fixtures.beast(&"boss", Elements.JIN, 100000, 1000.0)
	boss.rarity = BeastDef.Rarity.BOSS
	boss.leak_damage = 10
	var battle := Fixtures.straight_battle(&"boss")
	var relic := RelicDef.new()
	relic.id = &"heal"
	var heal := EffectDef.new()
	heal.trigger = &"on_wave_end"
	heal.op = &"heal_ding"
	heal.amount = 5
	relic.effects = [heal]
	var setup := Fixtures.setup([] as Array[StringName], 30)
	setup.relics = [relic]
	var sim := BattleSim.create(battle, Fixtures.library([boss]), ElementChart.new(), setup)
	sim.begin()
	while sim.is_running():
		sim.step()
	check_eq(sim.outcome, BattleSim.Outcome.LOST, "铜鼎有 30 耐久，首领漏到鼎前仍然判负")


func test_wave_heal_cannot_revive_broken_ding() -> void:
	var foe := Fixtures.beast(&"foe", Elements.TU, 100000, 1000.0)
	foe.leak_damage = 3
	var relic := RelicDef.new()
	relic.id = &"heal"
	var heal := EffectDef.new()
	heal.trigger = &"on_wave_end"
	heal.op = &"heal_ding"
	heal.amount = 5
	relic.effects = [heal]
	var setup := Fixtures.setup([] as Array[StringName], 3)
	setup.relics = [relic]
	var sim := BattleSim.create(Fixtures.straight_battle(&"foe"), Fixtures.library([foe]), ElementChart.new(), setup)
	sim.begin()
	while sim.is_running():
		sim.step()
	check_eq(sim.outcome, BattleSim.Outcome.LOST, "鼎破的那一拍清波，回复不能把鼎救回来")
