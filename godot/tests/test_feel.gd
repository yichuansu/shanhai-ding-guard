extends TestCase
## 手感与节奏系统：局内升级、提前召唤、波次预告、暴击、难度递增。


func _two_wave_battle(gap: int) -> BattleDef:
	var b := Fixtures.straight_battle(&"foe", 1, 5)
	var s := SpawnEntry.new()
	s.beast_id = &"foe"
	s.count = 3
	var w := WaveDef.new()
	w.gap_ticks_before = gap
	w.spawns = [s]
	b.waves.append(w)
	return b


func test_upgrade_costs_scale_and_boost_tower() -> void:
	var foe := Fixtures.beast(&"foe", Elements.TU, 100000, 1.0)
	var ally := Fixtures.beast(&"ally", Elements.HUO)
	var battle := Fixtures.straight_battle(&"foe")
	battle.starting_spirit = 100
	var sim := BattleSim.create(battle, Fixtures.library([foe, ally]), ElementChart.new(), Fixtures.setup([&"ally"] as Array[StringName]))
	sim.begin()
	sim.queue_deploy(1, 0)
	sim.step()
	var t: TowerUnit = sim.towers[0]
	var base := sim.damage_against(t, sim.enemies[0])
	check_eq(sim.upgrade_cost(0), 10, "部署费 5 × 2")
	var spirit_before := sim.spirit
	sim.queue_upgrade(0)
	sim.step()
	check_eq(t.level, 2)
	check_eq(sim.spirit, spirit_before - 10, "扣升级费（本拍无自然回复）")
	check_near(sim.damage_against(t, sim.enemies[0]), base * 1.6, 0.01, "Lv.2 伤害 ×1.6")
	check_eq(sim.upgrade_cost(0), 18, "Lv.2→3：5 × 3.5 向上取整")
	sim.queue_upgrade(0)
	sim.step()
	check_eq(sim.upgrade_cost(0), -1, "满级")
	check_near(sim.tower_range(t), ally.attack_range * 1.2, 0.01, "Lv.3 射程 ×1.2")
	check_eq(sim.recall_refund(0), 16, "返还一半投入：(5+10+18)/2")


func test_upgrade_needs_enough_spirit() -> void:
	var foe := Fixtures.beast(&"foe", Elements.TU, 100000, 1.0)
	var ally := Fixtures.beast(&"ally", Elements.HUO)
	var battle := Fixtures.straight_battle(&"foe")
	battle.starting_spirit = 8
	var sim := BattleSim.create(battle, Fixtures.library([foe, ally]), ElementChart.new(), Fixtures.setup([&"ally"] as Array[StringName]))
	sim.begin()
	sim.queue_deploy(1, 0)
	sim.step()
	sim.queue_upgrade(0)
	sim.step()
	check_eq((sim.towers[0] as TowerUnit).level, 1, "灵气不够不升级")


func test_early_call_skips_countdown_and_pays() -> void:
	var foe := Fixtures.beast(&"foe", Elements.TU, 10, 2000.0)
	var battle := _two_wave_battle(100)
	battle.spirit_income_interval_ticks = 0
	var sim := BattleSim.create(battle, Fixtures.library([foe]), ElementChart.new(), Fixtures.setup([] as Array[StringName], 20))
	sim.begin()
	check(_run_until(sim, func() -> bool: return sim.wave_gap_remaining() > 0), "进入波前倒计时")
	var remaining := sim.wave_gap_remaining()
	check_eq(sim.next_wave_preview(), {&"foe": 3}, "预告下一波")
	var bonus := sim.early_call_bonus()
	check_eq(bonus, ceili(remaining / 10.0 * BattleSim.EARLY_CALL_SPIRIT_PER_SECOND), "按剩余秒数给灵气")
	var spirit_before := sim.spirit
	sim.queue_call_wave()
	sim.step()
	check_eq(sim.spirit, spirit_before + bonus, "拿到奖励")
	check_eq(sim.wave_gap_remaining(), 0, "倒计时跳过")
	check_eq(sim.enemies.filter(func(e: EnemyUnit) -> bool: return e.wave_index == 1).size(), 1, "召唤的这一拍就出第二波")
	sim.queue_call_wave()
	var after := sim.spirit
	sim.step()
	check_eq(sim.spirit, after, "不在倒计时中召唤无效")


func test_crit_is_deterministic_and_happens() -> void:
	var results: Array[String] = []
	for run in 2:
		var foe := Fixtures.beast(&"foe", Elements.TU, 100000, 20.0)
		var ally := Fixtures.beast(&"ally", Elements.HUO)
		ally.crit_chance = 0.5
		ally.crit_multiplier = 3.0
		ally.attack_interval_ticks = 1
		var sim := BattleSim.create(Fixtures.straight_battle(&"foe"), Fixtures.library([foe, ally]), ElementChart.new(), Fixtures.setup([&"ally"] as Array[StringName]))
		sim.begin()
		sim.queue_deploy(1, 0)
		var crits := 0
		var normals := 0
		var log := ""
		for i in 600:
			sim.step()
			for ev in sim.events:
				if ev["type"] == "hit":
					log += "1" if ev["crit"] else "0"
					if ev["crit"]:
						crits += 1
						check_near(float(ev["damage"]), 30.0, 0.01, "暴击 ×3")
					else:
						normals += 1
		check(crits > 10 and normals > 10, "暴击和普通都会出现（%d/%d）" % [crits, normals])
		results.append(log)
	check_eq(results[0], results[1], "同种子暴击序列一致")


func test_difficulty_scales_with_layer() -> void:
	var r := RunState.new_run(5, [] as Array[StringName])
	var first := r.map.layers[0][0]
	check_near(r.difficulty_scale(first), 1.0, 0.0001, "第一层 ×1")
	check_near(r.difficulty_scale(r.map.boss_id()), 1.0 + RunState.DIFFICULTY_PER_LAYER * (r.map.layers.size() - 1), 0.0001, "首领层最高")
	var foe := Fixtures.beast(&"foe", Elements.TU, 100, 10.0)
	var setup := Fixtures.setup([] as Array[StringName])
	setup.hp_scale = 1.5
	var sim := BattleSim.create(Fixtures.straight_battle(&"foe"), Fixtures.library([foe]), ElementChart.new(), setup)
	sim.begin()
	sim.step()
	check_eq(sim.enemies[0].max_hp, 150, "血量按倍率放大")


func _run_until(sim: BattleSim, predicate: Callable, max_ticks: int = 500) -> bool:
	for i in max_ticks:
		if predicate.call():
			return true
		sim.step()
	return predicate.call()
