class_name Fixtures
extends RefCounted
## 测试用的最小内容：一条直线路径、一个鼎位、可控的异兽。


static func beast(id: StringName, element: StringName, hp: int = 100, speed: float = 100.0) -> BeastDef:
	var b := BeastDef.new()
	b.id = id
	b.display_name = String(id)
	b.element = element
	b.max_hp = hp
	b.move_speed = speed
	b.deploy_cost = 5
	b.damage = 10
	b.attack_range = 400.0
	b.attack_interval_ticks = 5
	b.projectile_speed = 1000.0
	b.spirit_reward = 2
	b.shell_reward = 1
	return b


static func straight_battle(enemy_id: StringName, count: int = 1, interval: int = 10, length: float = 1000.0) -> BattleDef:
	var b := BattleDef.new()
	b.id = &"test_battle"
	b.path_points = PackedVector2Array([Vector2(0, 500), Vector2(length, 500)])
	b.slots = PackedVector2Array([Vector2(500, 380), Vector2(700, 380)])
	b.adjacency_radius = 250.0
	b.starting_spirit = 20
	var s := SpawnEntry.new()
	s.beast_id = enemy_id
	s.count = count
	s.interval_ticks = interval
	var w := WaveDef.new()
	w.spawns = [s]
	b.waves = [w]
	return b


static func setup(roster_ids: Array[StringName], ding: int = 10, talismans: int = 3) -> BattleSetup:
	var s := BattleSetup.new()
	var uid := 1
	for id in roster_ids:
		s.roster.append(BeastInstance.make(uid, id))
		uid += 1
	s.ding_hp = ding
	s.ding_max = ding
	s.talismans = talismans
	s.seed_value = 42
	return s


static func library(defs: Array[BeastDef]) -> Dictionary:
	var d := {}
	for b in defs:
		d[b.id] = b
	return d
