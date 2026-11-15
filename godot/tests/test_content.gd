extends TestCase
## 内容数据的校验与平衡冒烟测试。数值调整导致这里失败时，先确认是不是有意的。


func test_content_loads_without_errors() -> void:
	var lib := ContentLibrary.load_from()
	check_eq(lib.errors, PackedStringArray(), "内容无错误")
	check(lib.beasts.size() >= 10, "至少 10 只异兽")
	check(not lib.battles_of_kind(BattleDef.Kind.NORMAL).is_empty(), "有普通战")
	check(not lib.battles_of_kind(BattleDef.Kind.ELITE).is_empty(), "有精英战")
	check(not lib.battles_of_kind(BattleDef.Kind.BOSS).is_empty(), "有首领战")


func test_starting_beasts_exist() -> void:
	var lib := ContentLibrary.load_from()
	for id in [&"jingwei", &"bifang"]:
		check(lib.beasts.has(id), "起始异兽 %s 存在" % id)


func test_every_normal_beast_is_capturable_and_minions_are_not() -> void:
	var lib := ContentLibrary.load_from()
	for id: StringName in lib.beasts:
		var b: BeastDef = lib.beasts[id]
		var expected := b.rarity == BeastDef.Rarity.COMMON or b.rarity == BeastDef.Rarity.ELITE
		check_eq(b.capturable, expected, String(id))


func test_balance_smoke_first_battle() -> void:
	var lib := ContentLibrary.load_from()
	var battle: BattleDef = lib.battles[&"jizhou_b01"]
	var idle := BattleSim.create(battle, lib.beasts, lib.chart, Fixtures.setup([] as Array[StringName]))
	AutoPlayer.new().play(idle)
	check_eq(idle.outcome, BattleSim.Outcome.LOST, "不部署必输")
	var sim := BattleSim.create(battle, lib.beasts, lib.chart, Fixtures.setup([&"jingwei", &"bifang"] as Array[StringName]))
	AutoPlayer.new().play(sim)
	check_eq(sim.outcome, BattleSim.Outcome.WON, "起始阵容能守住第一场")
	check(sim.tick < 1500, "第一场不超过约 2.5 分钟（%d 拍）" % sim.tick)
