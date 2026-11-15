extends TestCase


func _sim(defs: Array[BeastDef], battle: BattleDef, roster: Array[StringName], talismans: int = 3) -> BattleSim:
	var sim := BattleSim.create(battle, Fixtures.library(defs), ElementChart.new(), Fixtures.setup(roster, 10, talismans))
	check_eq(sim.error, "", "创建模拟")
	return sim


func test_no_towers_means_every_enemy_leaks() -> void:
	var enemy := Fixtures.beast(&"foe", Elements.TU, 100, 200.0)
	var sim := _sim([enemy], Fixtures.straight_battle(&"foe", 3, 5), [])
	sim.begin()
	while sim.is_running():
		sim.step()
	check_eq(sim.ding_hp, 7, "3 只各漏 1")
	check_eq(sim.outcome, BattleSim.Outcome.WON, "鼎没破、怪出完就算守住")


func test_ding_breaks_when_leaks_exceed_hp() -> void:
	var enemy := Fixtures.beast(&"foe", Elements.TU, 100, 300.0)
	var sim := _sim([enemy], Fixtures.straight_battle(&"foe", 12, 3), [])
	sim.begin()
	while sim.is_running():
		sim.step()
	check_eq(sim.outcome, BattleSim.Outcome.LOST)
	check(sim.ding_hp <= 0, "鼎耐久归零")


func test_deploy_costs_spirit_and_kills_award_rewards() -> void:
	var enemy := Fixtures.beast(&"foe", Elements.HUO, 30, 50.0)
	var tower := Fixtures.beast(&"ally", Elements.HUO)
	var sim := _sim([enemy, tower], Fixtures.straight_battle(&"foe", 1, 5), [&"ally"])
	sim.begin()
	sim.queue_deploy(1, 0)
	sim.step()
	check(sim.towers.has(0), "部署成功")
	check_eq(sim.spirit, 15, "20 - 5")
	while sim.is_running():
		sim.step()
	check_eq(sim.outcome, BattleSim.Outcome.WON)
	check_eq(sim.shells_earned, 1, "击杀掉 1 贝币")
	check_eq(sim.ding_hp, 10, "没有漏怪")


func test_element_advantage_changes_damage() -> void:
	var foe := Fixtures.beast(&"foe", Elements.TU)
	var mu := Fixtures.beast(&"mu_t", Elements.MU)
	var sim := _sim([foe, mu], Fixtures.straight_battle(&"foe"), [&"mu_t"])
	sim.begin()
	sim.queue_deploy(1, 0)
	sim.step()
	var t: TowerUnit = sim.towers[0]
	check_near(sim.damage_against(t, sim.enemies[0]), 15.0, 0.001, "木克土 ×1.5")


func test_generating_neighbour_adds_bonus() -> void:
	var foe := Fixtures.beast(&"foe", Elements.JIN)
	var mu := Fixtures.beast(&"mu_t", Elements.MU)
	var huo := Fixtures.beast(&"huo_t", Elements.HUO)
	var sim := _sim([foe, mu, huo], Fixtures.straight_battle(&"foe"), [&"mu_t", &"huo_t"])
	sim.begin()
	sim.queue_deploy(1, 0)
	sim.queue_deploy(2, 1)
	sim.step()
	var huo_tower: TowerUnit = sim.towers[1]
	var mu_tower: TowerUnit = sim.towers[0]
	check_near(huo_tower.damage_bonus, 0.2, 0.0001, "木生火：火 +20%")
	check_near(mu_tower.damage_bonus, 0.0, 0.0001, "火不生木")


func test_capture_requires_threshold_and_talisman() -> void:
	var foe := Fixtures.beast(&"foe", Elements.TU, 100, 20.0)
	var sim := _sim([foe], Fixtures.straight_battle(&"foe"), [], 1)
	sim.begin()
	sim.step()
	var e := sim.enemies[0]
	sim.queue_capture(e.id)
	sim.step()
	check(e.alive, "满血不能捕获")
	e.hp = 20.0
	sim.queue_capture(e.id)
	sim.step()
	check(not e.alive and e.captured, "低于 25% 可捕获")
	check_eq(sim.captured_beasts, [&"foe"] as Array[StringName])
	check_eq(sim.talismans, 0)
	check_eq(sim.shells_earned, 0, "捕获不给击杀奖励")
	check_eq(sim.outcome, BattleSim.Outcome.WON, "捕获后场上清空即胜")


func test_recall_refunds_half() -> void:
	var foe := Fixtures.beast(&"foe", Elements.TU, 100, 10.0)
	var ally := Fixtures.beast(&"ally", Elements.HUO)
	var sim := _sim([foe, ally], Fixtures.straight_battle(&"foe"), [&"ally"])
	sim.begin()
	sim.queue_deploy(1, 0)
	sim.step()
	var before := sim.spirit
	sim.queue_recall(0)
	sim.step()
	check(not sim.towers.has(0), "已收回")
	check(sim.spirit >= before + 2, "返还 floor(5×0.5)=2")


func test_burn_and_slow_effects_apply_on_hit() -> void:
	var foe := Fixtures.beast(&"foe", Elements.TU, 1000, 30.0)
	var ally := Fixtures.beast(&"ally", Elements.JIN)
	ally.traits = [_effect(&"on_hit", &"burn", 2.0, 10), _effect(&"on_hit", &"slow", 0.5, 10)]
	var sim := _sim([foe, ally], Fixtures.straight_battle(&"foe"), [&"ally"])
	sim.begin()
	sim.queue_deploy(1, 0)
	var e: EnemyUnit = null
	for i in 200:
		sim.step()
		if not sim.enemies.is_empty():
			e = sim.enemies[0]
		if e != null and e.burn_ticks > 0:
			break
	check(e != null and e.burn_ticks > 0, "灼烧生效")
	check(e != null and e.slow_ticks > 0 and is_equal_approx(e.slow_multiplier, 0.5), "减速生效")


func test_relic_effects() -> void:
	var foe := Fixtures.beast(&"foe", Elements.HUO)
	var ally := Fixtures.beast(&"ally", Elements.HUO)
	var relic := RelicDef.new()
	relic.id = &"r"
	relic.effects = [_effect(&"passive", &"global_damage_pct", 0.1), _effect(&"on_battle_start", &"add_talismans", 1)]
	var setup := Fixtures.setup([&"ally"], 10, 2)
	setup.relics = [relic]
	var sim := BattleSim.create(Fixtures.straight_battle(&"foe"), Fixtures.library([foe, ally]), ElementChart.new(), setup)
	sim.begin()
	check_eq(sim.talismans, 3, "河图类效果：+1 张临时符")
	sim.queue_deploy(1, 0)
	sim.step()
	check_near(sim.damage_against(sim.towers[0], sim.enemies[0]), 11.0, 0.001, "全体 +10%")
	sim.talismans_used = 2
	check_eq(sim.run_talismans_spent(), 1, "临时符不消耗库存")


func test_same_setup_is_deterministic() -> void:
	var lib := ContentLibrary.load_from()
	var results: Array[String] = []
	for i in 2:
		var setup := Fixtures.setup([&"jingwei", &"bifang", &"huashe"])
		var sim := BattleSim.create(lib.battles[&"jizhou_b01"], lib.beasts, lib.chart, setup)
		AutoPlayer.new().play(sim)
		results.append("%d|%d|%d|%d|%s" % [sim.tick, sim.outcome, sim.ding_hp, sim.shells_earned, str(sim.captured_beasts)])
	check_eq(results[0], results[1], "同输入同结果")


func _effect(trigger: StringName, op: StringName, amount: float, duration: int = 0) -> EffectDef:
	var e := EffectDef.new()
	e.trigger = trigger
	e.op = op
	e.amount = amount
	e.duration_ticks = duration
	return e
