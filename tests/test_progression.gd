extends TestCase
## 守鼎人解锁与鼎劫难度。

var lib := ContentLibrary.load_from()


func test_ascension_mods_are_cumulative() -> void:
	var m0 := Ascension.mods(0)
	check_near(m0["hp_mult"], 1.0, 0.0001, "0 级没有修正")
	check_eq(m0["reward_choices"], 3)
	var m10 := Ascension.mods(10)
	check_near(m10["hp_mult"], 1.2, 0.0001, "1 级和 9 级各 +10%")
	check_eq(m10["spirit_delta"], -3)
	check_eq(m10["ding_max_delta"], -2)
	check_near(m10["speed_mult"], 1.1, 0.0001)
	check_eq(m10["capture_limit"], 2)
	check_eq(m10["reward_choices"], 2)
	check_near(m10["rest_heal_mult"], 0.5, 0.0001)
	check_eq(Ascension.LEVEL_TEXT.size(), Ascension.MAX_LEVEL, "每级都有说明")
	check_eq(Ascension.rules_up_to(3).size(), 3)
	check_eq(Ascension.mods(5), Ascension.mods(5), "同级结果一致")
	check_eq(Ascension.mods(99), Ascension.mods(10), "超出上限按最高级")


func test_run_applies_ascension() -> void:
	var easy := RunState.new_run(3, [&"jingwei"] as Array[StringName], &"zhudingjiang", 5, 0)
	var hard := RunState.new_run(3, [&"jingwei"] as Array[StringName], &"zhudingjiang", 5, 10)
	check_eq(hard.ding_max, easy.ding_max - 2, "3 级起铜鼎上限 -2")
	check_eq(hard.ding_hp, hard.ding_max)
	var node := easy.map.layers[0][0]
	var e := easy.make_battle_setup(lib, node)
	var h := hard.make_battle_setup(lib, node)
	check_near(h.hp_scale, e.hp_scale * 1.2, 0.0001, "敌人血量 ×1.2")
	check_near(h.boss_hp_scale, e.boss_hp_scale * 1.15, 0.0001, "首领血量 ×1.15")
	check_eq(h.spirit_delta, -3)
	check_near(h.speed_scale, 1.1, 0.0001)
	check_eq(h.talismans, 2, "最多 2 张镇鼎符")
	var restored := RunState.from_dict(JSON.parse_string(JSON.stringify(hard.to_dict())))
	check_eq(restored.ascension, 10, "存读档保留鼎劫等级")


func test_rules_respect_ascension() -> void:
	var easy := RunState.new_run(4, [&"jingwei"] as Array[StringName], &"zhudingjiang", 5, 0)
	var hard := RunState.new_run(4, [&"jingwei"] as Array[StringName], &"zhudingjiang", 5, 10)
	var shop := -1
	for n in easy.map.nodes:
		if n.type == MapNode.Type.SHOP:
			shop = n.id
	var cheap := RunRules.shop_offers(easy, lib, shop, [] as Array[StringName])
	var dear := RunRules.shop_offers(hard, lib, shop, [] as Array[StringName])
	for i in cheap.size():
		check(int(dear[i]["price"]) >= ceili(int(cheap[i]["price"]) * 1.25) - 1, "集市涨价")
	var node := hard.map.layers[0][0]
	check_eq((RunRules.roll_reward(hard, lib, node, [] as Array[StringName])["options"] as Array).size(), 2, "奖励只剩两个选项")
	check_eq(RunRules.rest_heal_amount(hard), ceili(RunRules.REST_HEAL * 0.5), "祭祀修鼎减半")
	check_eq(RunRules.rest_heal_amount(easy), RunRules.REST_HEAL)


func test_sim_applies_spirit_and_speed() -> void:
	var foe := Fixtures.beast(&"foe", Elements.TU, 100, 100.0)
	var battle := Fixtures.straight_battle(&"foe")
	var setup := Fixtures.setup([] as Array[StringName])
	setup.spirit_delta = -3
	setup.speed_scale = 1.5
	var sim := BattleSim.create(battle, Fixtures.library([foe]), ElementChart.new(), setup)
	check_eq(sim.spirit, battle.starting_spirit - 3, "开局灵气 -3")
	sim.begin()
	sim.step()
	check_near(sim.enemies[0].distance, 15.0, 0.001, "移速 ×1.5：每拍 15")


func test_profile_ascension_progress() -> void:
	var p := Profile.new()
	check_eq(p.max_ascension(&"zhudingjiang"), 0)
	check_eq(p.record_win(&"zhudingjiang", 0), 1, "0 级通关解锁 1 级")
	check_eq(p.record_win(&"zhudingjiang", 0), -1, "重复通关 0 级不再解锁")
	check_eq(p.record_win(&"zhudingjiang", 1), 2)
	check_eq(p.max_ascension(&"wuzhu"), 0, "各守鼎人分开记录")
	p.ascension["yiyi"] = Ascension.MAX_LEVEL
	check_eq(p.record_win(&"yiyi", Ascension.MAX_LEVEL), -1, "最高级封顶")
	var r := Profile.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	check_eq(r.max_ascension(&"zhudingjiang"), 2, "存读档保留")


func test_keeper_unlocks() -> void:
	var p := Profile.new()
	var unlocked := KeeperUnlocks.unlocked_ids(lib, p)
	check_eq(unlocked, [&"zhudingjiang"] as Array[StringName], "一开始只有铸鼎匠")
	var wuzhu: KeeperDef = lib.keepers[&"wuzhu"]
	check_eq(KeeperUnlocks.progress_text(wuzhu, lib, p), "图鉴收录 0/8")
	for id in [&"jingwei", &"bifang", &"huashe", &"mingshe", &"dangkang", &"lili", &"fuzhu", &"wenyao"]:
		p.record_capture(id)
	check(KeeperUnlocks.is_unlocked(wuzhu, lib, p), "收录 8 只解锁巫祝")
	check_eq(KeeperUnlocks.progress_text(wuzhu, lib, p), "", "解锁后不显示进度")
	var yiyi: KeeperDef = lib.keepers[&"yiyi"]
	check(not KeeperUnlocks.is_unlocked(yiyi, lib, p), "没打过相柳不解锁羿裔")
	p.record_defeat(&"xiangliu")
	check(KeeperUnlocks.is_unlocked(yiyi, lib, p), "击败相柳解锁羿裔")
	for id in lib.keeper_ids():
		var k: KeeperDef = lib.keepers[id]
		if k.unlock_kind != &"":
			check(k.unlock_hint != "", "%s 有解锁说明" % id)
