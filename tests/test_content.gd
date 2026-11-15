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


func test_keepers_and_formations() -> void:
	var lib := ContentLibrary.load_from()
	check_eq(lib.keeper_ids().size(), 3, "三位守鼎人")
	check_eq(lib.keeper_ids()[0], &"zhudingjiang", "按 order 排序")
	for id in lib.keeper_ids():
		var k: KeeperDef = lib.keepers[id]
		check(k.skill != null and k.skill.cooldown_ticks > 0, "%s 有技能" % id)
		check(k.starting_beasts.size() >= 2, "%s 开局至少两只异兽" % id)
	check_eq(lib.formation_list().size(), 5, "五行各一阵")


func test_every_keeper_can_win_first_battle() -> void:
	var lib := ContentLibrary.load_from()
	var battle: BattleDef = lib.battles[&"jizhou_b01"]
	for id in lib.keeper_ids():
		var k: KeeperDef = lib.keepers[id]
		var setup := Fixtures.setup(k.starting_beasts)
		setup.keeper = k
		setup.formations = lib.formation_list()
		var sim := BattleSim.create(battle, lib.beasts, lib.chart, setup)
		AutoPlayer.new().play(sim)
		check_eq(sim.outcome, BattleSim.Outcome.WON, "%s 的开局阵容能守住第一场" % k.display_name)


func test_p2_content() -> void:
	var lib := ContentLibrary.load_from()
	check(lib.relics.size() >= 7, "至少 7 件法宝")
	check(lib.events.size() >= 7, "至少 7 个奇遇")
	check(lib.fusions.size() >= 4, "至少四个融合配方")
	for id in lib.event_ids():
		var ev: EventDef = lib.events[id]
		check(ev.source_text != "" and ev.options.size() >= 2, "%s 有原文和至少两个选项" % id)
	var xiangliu: BeastDef = lib.beasts[&"xiangliu"]
	check(xiangliu.abilities.size() >= 2, "相柳有首领技能")


## 内置字体只是子集。内容里出现子集外的字，手机上会显示成方框，这里拦住。
## 失败时运行 tools/subset_font.py 重新裁剪字体。
func test_font_covers_all_content_text() -> void:
	var font: FontFile = load("res://assets/fonts/NotoSansSC-Subset.ttf")
	var lib := ContentLibrary.load_from()
	var texts := PackedStringArray()
	for id: StringName in lib.beasts:
		var b: BeastDef = lib.beasts[id]
		texts.append_array([b.display_name, b.lore])
		for t in b.traits + b.abilities:
			texts.append(t.description)
	for id: StringName in lib.relics:
		var r: RelicDef = lib.relics[id]
		texts.append_array([r.display_name, r.description])
	for id: StringName in lib.events:
		var ev: EventDef = lib.events[id]
		texts.append_array([ev.title, ev.source_text, ev.situation])
		for o in ev.options:
			texts.append_array([o.label, o.hint, o.success_text, o.fail_text])
	for id: StringName in lib.keepers:
		var k: KeeperDef = lib.keepers[id]
		texts.append_array([k.display_name, k.description, k.skill.display_name, k.skill.description])
	for id: StringName in lib.fusions:
		texts.append((lib.fusions[id] as FusionRecipe).description)
	for id: StringName in lib.battles:
		texts.append((lib.battles[id] as BattleDef).display_name)
	var missing := {}
	for text in texts:
		for i in text.length():
			var code := text.unicode_at(i)
			if code >= 0x20 and code != 0x0A and not font.has_char(code):
				missing[text[i]] = true
	check(missing.is_empty(), "字体缺字：%s" % "".join(PackedStringArray(missing.keys())))
