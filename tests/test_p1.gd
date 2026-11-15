extends TestCase
## P1 机制：镇守拦截、五行阵、守鼎人技能与被动、新增效果。


func _effect(trigger: StringName, op: StringName, amount: float, duration: int = 0, radius: float = 0.0, scope: StringName = &"") -> EffectDef:
	var e := EffectDef.new()
	e.trigger = trigger
	e.op = op
	e.amount = amount
	e.duration_ticks = duration
	e.radius = radius
	e.element_scope = scope
	return e


func _guard_beast() -> BeastDef:
	var g := Fixtures.beast(&"guard", Elements.TU)
	g.damage = 0
	g.guard_hp = 20
	g.block_count = 1
	g.guard_recover_ticks = 10
	return g


func _make(defs: Array[BeastDef], battle: BattleDef, setup: BattleSetup) -> BattleSim:
	var sim := BattleSim.create(battle, Fixtures.library(defs), ElementChart.new(), setup)
	check_eq(sim.error, "", "创建模拟")
	return sim


func _run_until(sim: BattleSim, predicate: Callable, max_ticks: int = 500) -> bool:
	for i in max_ticks:
		if predicate.call():
			return true
		sim.step()
	return predicate.call()


func test_path_closest_point() -> void:
	var p := PathCurve.new(PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100)]))
	check_eq(p.closest(Vector2(50, 30)), Vector2(50, 30))
	check_eq(p.closest(Vector2(130, 60)), Vector2(160, 30))


func test_guard_blocks_takes_damage_breaks_and_recovers() -> void:
	var foe := Fixtures.beast(&"foe", Elements.TU, 1000, 100.0)
	foe.contact_damage = 2.0
	var battle := Fixtures.straight_battle(&"foe")
	var sim := _make([foe, _guard_beast()], battle, Fixtures.setup([&"guard"] as Array[StringName]))
	sim.begin()
	sim.queue_deploy(1, 0)
	sim.step()
	var g: TowerUnit = sim.towers[0]
	check(g.guard_active, "鼎位离路径 120，在拦截范围内")
	check_near(g.block_distance, 500.0, 0.01, "拦截点在路径 500 处")
	check(_run_until(sim, func() -> bool: return not sim.enemies.is_empty() and sim.enemies[0].blocked_by == 0), "敌人被挡下")
	var e := sim.enemies[0]
	check_near(e.distance, 500.0, 0.01, "停在拦截点")
	sim.step()
	check_near(e.distance, 500.0, 0.01, "被挡住不前进")
	check(g.guard_hp < 20.0, "镇守被攻击")
	check(_run_until(sim, func() -> bool: return g.guard_down_ticks > 0), "镇守被打垮")
	check_eq(e.blocked_by, -1, "打垮后放行")
	var released_at := e.distance
	sim.step()
	check(e.distance > released_at, "放行后继续前进")
	check(_run_until(sim, func() -> bool: return g.guard_down_ticks == 0, 20), "一段时间后恢复")
	check_near(g.guard_hp, 20.0, 0.01, "恢复满血")


func test_guard_capacity_and_boss_not_blocked() -> void:
	var foe := Fixtures.beast(&"foe", Elements.TU, 1000, 100.0)
	foe.contact_damage = 0.0
	var boss := Fixtures.beast(&"boss", Elements.TU, 1000, 100.0)
	boss.rarity = BeastDef.Rarity.BOSS
	var battle := Fixtures.straight_battle(&"foe", 2, 3)
	var s := SpawnEntry.new()
	s.beast_id = &"boss"
	s.count = 1
	battle.waves[0].spawns.append(s)
	var sim := _make([foe, boss, _guard_beast()], battle, Fixtures.setup([&"guard"] as Array[StringName]))
	sim.begin()
	sim.queue_deploy(1, 0)
	for i in 80:
		sim.step()
	var blocked := 0
	var boss_unit: EnemyUnit = null
	for e in sim.enemies:
		if e.blocked_by >= 0:
			blocked += 1
		if e.def.id == &"boss":
			boss_unit = e
	check_eq(blocked, 1, "一次只挡 block_count 只")
	check(boss_unit == null or boss_unit.distance > 500.0, "首领不会被挡")


func test_recalling_guard_releases_enemies() -> void:
	var foe := Fixtures.beast(&"foe", Elements.TU, 1000, 100.0)
	foe.contact_damage = 0.0
	var sim := _make([foe, _guard_beast()], Fixtures.straight_battle(&"foe"), Fixtures.setup([&"guard"] as Array[StringName]))
	sim.begin()
	sim.queue_deploy(1, 0)
	_run_until(sim, func() -> bool: return not sim.enemies.is_empty() and sim.enemies[0].blocked_by == 0)
	sim.queue_recall(0)
	sim.step()
	check_eq(sim.enemies[0].blocked_by, -1, "收回镇守后放行")


func test_guard_out_of_reach_cannot_block() -> void:
	var foe := Fixtures.beast(&"foe", Elements.TU)
	var g := _guard_beast()
	g.guard_reach = 50.0
	var sim := _make([foe, g], Fixtures.straight_battle(&"foe"), Fixtures.setup([&"guard"] as Array[StringName]))
	sim.begin()
	sim.queue_deploy(1, 0)
	sim.step()
	check(not (sim.towers[0] as TowerUnit).guard_active, "离路径 120 > 50，不能拦截")


func _formation_setup(roster: Array[StringName]) -> BattleSetup:
	var huo := FormationDef.new()
	huo.element = Elements.HUO
	var t2 := FormationTier.new()
	t2.count = 2
	t2.effects = [_effect(&"passive", &"element_damage_pct", 0.2), _effect(&"on_hit", &"burn", 1.0, 5)]
	var t3 := FormationTier.new()
	t3.count = 3
	t3.effects = [_effect(&"passive", &"element_damage_pct", 0.5)]
	huo.tiers = [t2, t3]
	var setup := Fixtures.setup(roster)
	setup.formations = [huo]
	return setup


func test_formation_tiers_follow_deployed_count() -> void:
	var foe := Fixtures.beast(&"foe", Elements.MU)
	var defs: Array[BeastDef] = [foe, Fixtures.beast(&"h1", Elements.HUO), Fixtures.beast(&"h2", Elements.HUO), Fixtures.beast(&"h3", Elements.HUO), Fixtures.beast(&"j1", Elements.JIN)]
	var battle := Fixtures.straight_battle(&"foe")
	battle.slots = PackedVector2Array([Vector2(100, 380), Vector2(400, 380), Vector2(700, 380), Vector2(1000, 380)])
	battle.starting_spirit = 50
	var sim := _make(defs, battle, _formation_setup([&"h1", &"h2", &"h3", &"j1"] as Array[StringName]))
	sim.begin()
	sim.queue_deploy(1, 0)
	sim.queue_deploy(4, 3)
	sim.step()
	check(not sim.active_formations.has(Elements.HUO), "一只火不成阵")
	sim.queue_deploy(2, 1)
	sim.step()
	check_eq(sim.active_formations.get(Elements.HUO), 2, "两只火：一档")
	var h1: TowerUnit = sim.towers[0]
	var j1: TowerUnit = sim.towers[3]
	check_near(h1.damage_bonus, 0.2, 0.0001, "火阵只加火")
	check_near(j1.damage_bonus, 0.0, 0.0001, "金不受火阵影响")
	check_eq(sim._on_hit_effects_for(h1).size(), 1, "火阵灼烧只给火属")
	check_eq(sim._on_hit_effects_for(j1).size(), 0)
	sim.queue_deploy(3, 2)
	sim.step()
	check_eq(sim.active_formations.get(Elements.HUO), 3, "三只火：二档")
	check_near(h1.damage_bonus, 0.5, 0.0001, "只取最高一档，不叠加")
	sim.queue_recall(2)
	sim.step()
	check_eq(sim.active_formations.get(Elements.HUO), 2, "收回后降档")


func test_spirit_income_and_heal_effects() -> void:
	var foe := Fixtures.beast(&"foe", Elements.TU, 10, 1000.0)
	var battle := Fixtures.straight_battle(&"foe", 1, 5, 5000.0)
	battle.spirit_income_interval_ticks = 0
	var relic := RelicDef.new()
	relic.id = &"r"
	relic.effects = [_effect(&"passive", &"spirit_income", 2, 5), _effect(&"on_wave_end", &"heal_ding", 3)]
	var setup := Fixtures.setup([] as Array[StringName], 10)
	setup.ding_hp = 5
	setup.relics = [relic]
	var sim := _make([foe], battle, setup)
	sim.begin()
	var start := sim.spirit
	for i in 10:
		sim.step()
	check_eq(sim.spirit, start + 4, "每 5 拍 +2")
	while sim.is_running():
		sim.step()
	check_eq(sim.ding_hp, 7, "漏 1 后清波回 3：5 - 1 + 3")


func test_keeper_damage_skill_costs_and_cools_down() -> void:
	var foe := Fixtures.beast(&"foe", Elements.TU, 100, 10.0)
	var keeper := KeeperDef.new()
	keeper.skill = SkillDef.new()
	keeper.skill.op = &"damage_area"
	keeper.skill.amount = 40.0
	keeper.skill.radius = 200.0
	keeper.skill.spirit_cost = 6
	keeper.skill.cooldown_ticks = 20
	var setup := Fixtures.setup([] as Array[StringName])
	setup.keeper = keeper
	var sim := _make([foe], Fixtures.straight_battle(&"foe", 2, 1), setup)
	sim.begin()
	sim.step()
	sim.step()
	var spirit_before := sim.spirit
	sim.queue_skill(Vector2(0, 500))
	sim.step()
	check_eq(sim.spirit, spirit_before - 6, "扣灵气")
	for e in sim.enemies:
		check_near(e.hp, 60.0, 0.01, "范围内敌人受伤")
	check(not sim.skill_ready(), "进入冷却")
	sim.queue_skill(Vector2(0, 500))
	sim.step()
	check_near(sim.enemies[0].hp, 60.0, 0.01, "冷却中再放无效")


func test_freeze_and_smite_skills() -> void:
	var foe := Fixtures.beast(&"foe", Elements.TU, 100, 100.0)
	var big := Fixtures.beast(&"big", Elements.TU, 500, 100.0)
	var battle := Fixtures.straight_battle(&"foe")
	var s := SpawnEntry.new()
	s.beast_id = &"big"
	battle.waves[0].spawns.append(s)
	var keeper := KeeperDef.new()
	keeper.skill = SkillDef.new()
	keeper.skill.op = &"freeze_area"
	keeper.skill.radius = 2000.0
	keeper.skill.duration_ticks = 5
	keeper.skill.spirit_cost = 0
	keeper.skill.cooldown_ticks = 1
	var setup := Fixtures.setup([] as Array[StringName])
	setup.keeper = keeper
	var sim := _make([foe, big], battle, setup)
	sim.begin()
	for i in 12:
		sim.step()
	sim.queue_skill(Vector2(500, 500))
	sim.step()
	var d := sim.enemies[0].distance
	sim.step()
	check_near(sim.enemies[0].distance, d, 0.001, "定身中不移动")
	keeper.skill.op = &"smite_strongest"
	keeper.skill.amount = 100.0
	sim.queue_skill(Vector2.ZERO)
	sim.step()
	var big_unit: EnemyUnit = null
	for e in sim.enemies:
		if e.def.id == &"big":
			big_unit = e
	check(big_unit != null and is_equal_approx(big_unit.hp, 400.0), "射日打中生命最高的")


func test_keeper_capture_bonus() -> void:
	var foe := Fixtures.beast(&"foe", Elements.TU, 100, 10.0)
	var keeper := KeeperDef.new()
	keeper.passives = [_effect(&"passive", &"capture_threshold_bonus", 0.1)]
	var setup := Fixtures.setup([] as Array[StringName])
	setup.keeper = keeper
	var sim := _make([foe], Fixtures.straight_battle(&"foe"), setup)
	sim.begin()
	sim.step()
	var e := sim.enemies[0]
	e.hp = 34.0
	check(sim.can_capture(e), "34% 在 25%+10% 血线内")
	e.hp = 36.0
	check(not sim.can_capture(e), "36% 超出")


func test_splash_ignite_and_bonus_vs_element() -> void:
	var foe := Fixtures.beast(&"foe", Elements.SHUI, 1000, 30.0)
	var ally := Fixtures.beast(&"ally", Elements.JIN)
	ally.traits = [
		_effect(&"on_hit", &"splash", 0.5, 0, 200.0),
		_effect(&"on_hit", &"ignite_nearby", 3.0, 10, 200.0),
		_effect(&"passive", &"bonus_vs_element", 0.5, 0, 0.0, Elements.SHUI),
	]
	var battle := Fixtures.straight_battle(&"foe", 2, 2)
	var sim := _make([foe, ally], battle, Fixtures.setup([&"ally"] as Array[StringName]))
	sim.begin()
	sim.queue_deploy(1, 0)
	sim.step()
	check_near(sim.damage_against(sim.towers[0], sim.enemies[0]), 15.0, 0.001, "对水 +50%")
	check(_run_until(sim, func() -> bool:
		return sim.enemies.size() == 2 and (sim.enemies[0].hp < 1000.0 or sim.enemies[1].hp < 1000.0)), "命中")
	var damaged := 0
	var burning := 0
	for e in sim.enemies:
		if e.hp < 1000.0:
			damaged += 1
		if e.burn_ticks > 0:
			burning += 1
	check_eq(damaged, 2, "溅射波及另一只")
	check_eq(burning, 1, "引燃附近另一只")


func test_dry_consumes_slow_for_bonus_damage() -> void:
	var foe := Fixtures.beast(&"foe", Elements.TU, 1000, 30.0)
	var ally := Fixtures.beast(&"ally", Elements.HUO)
	ally.traits = [_effect(&"on_hit", &"dry", 1.0)]
	var sim := _make([foe, ally], Fixtures.straight_battle(&"foe"), Fixtures.setup([&"ally"] as Array[StringName]))
	sim.begin()
	sim.queue_deploy(1, 0)
	_run_until(sim, func() -> bool: return not sim.enemies.is_empty())
	var e := sim.enemies[0]
	e.slow_ticks = 100000
	e.slow_multiplier = 0.1
	check(_run_until(sim, func() -> bool: return e.hp < 1000.0), "命中")
	check_near(e.hp, 980.0, 0.01, "减速中的敌人吃双倍")
	check_eq(e.slow_ticks, 0, "减速被蒸干")
