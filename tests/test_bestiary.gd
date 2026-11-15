extends TestCase
## 山海经图鉴：栏目划分、收录状态、进度、配方提示、档案存读。

var lib := ContentLibrary.load_from()


func test_sections() -> void:
	var jizhou := Bestiary.section_ids(lib, "jizhou")
	check(jizhou.has(&"jingwei") and jizhou.has(&"zhuyan"), "冀州栏含普通和精英")
	check(not jizhou.has(&"dingsha_tu"), "杂兵不入图鉴")
	check(not jizhou.has(&"fenghuang") and not jizhou.has(&"xiangliu"), "稀有和首领不在冀州栏")
	check_eq(Bestiary.section_ids(lib, "rare").size(), lib.fusions.size(), "每个配方一只稀有异兽")
	var bosses := Bestiary.section_ids(lib, "boss")
	check(bosses.has(&"xiangliu") and bosses.has(&"fei"), "首领栏有相柳和蜚")
	var qingzhou := Bestiary.section_ids(lib, "qingzhou")
	check(qingzhou.has(&"jiegou") and qingzhou.has(&"longzhi"), "青州栏含普通和精英")
	check(not qingzhou.has(&"jingwei") and not jizhou.has(&"jiegou"), "两州互不混入")
	check_eq(Bestiary.sections().size(), Regions.ORDER.size() + 2, "每州一栏 + 稀有 + 首领")
	var first: BeastDef = lib.beasts[jizhou[0]]
	check_eq(first.element, Elements.MU, "按五行顺序排（木在前）")


func test_state_transitions() -> void:
	var p := Profile.new()
	check_eq(Bestiary.state_of(lib, p, &"bifang"), Bestiary.State.UNKNOWN)
	p.record_seen(&"bifang")
	check_eq(Bestiary.state_of(lib, p, &"bifang"), Bestiary.State.SEEN)
	p.record_capture(&"bifang")
	check_eq(Bestiary.state_of(lib, p, &"bifang"), Bestiary.State.COLLECTED)
	check_eq(Bestiary.state_of(lib, p, &"xiangliu"), Bestiary.State.UNKNOWN)
	p.record_seen(&"xiangliu")
	check_eq(Bestiary.state_of(lib, p, &"xiangliu"), Bestiary.State.SEEN, "首领遇见未击败")
	p.record_defeat(&"xiangliu")
	check_eq(Bestiary.state_of(lib, p, &"xiangliu"), Bestiary.State.DEFEATED)


func test_obtained_counts_as_collected_without_capture() -> void:
	var p := Profile.new()
	check(p.record_obtained(&"fenghuang"), "首次获得")
	check(not p.record_obtained(&"fenghuang"), "再次获得不算首次")
	check_eq(Bestiary.state_of(lib, p, &"fenghuang"), Bestiary.State.COLLECTED)
	check_eq(p.capture_count(&"fenghuang"), 0, "获得不算捕获次数")


func test_progress() -> void:
	var p := Profile.new()
	var empty := Bestiary.progress(lib, p)
	check_eq(empty.x, 0)
	var total := 0
	for s: Dictionary in Bestiary.sections():
		total += Bestiary.section_ids(lib, s["id"]).size()
	check_eq(empty.y, total, "总数 = 各栏之和")
	p.record_capture(&"jingwei")
	p.record_obtained(&"bo")
	p.record_defeat(&"xiangliu")
	p.record_seen(&"mingshe")
	check_eq(Bestiary.progress(lib, p).x, 3, "遇见不算收录")
	check_eq(Bestiary.progress(lib, p, "rare"), Vector2i(1, lib.fusions.size()))


func test_recipe_hint_hides_unknown_ingredients() -> void:
	var p := Profile.new()
	var hint := Bestiary.recipe_hint(lib, p, &"fenghuang")
	check(hint.contains("？？？ + ？？？"), "原料都没收录时全部隐藏")
	p.record_capture(&"jingwei")
	hint = Bestiary.recipe_hint(lib, p, &"fenghuang")
	check(hint.contains("精卫") and hint.contains("？？？"), "只显示已收录的原料")
	p.record_capture(&"bifang")
	hint = Bestiary.recipe_hint(lib, p, &"fenghuang")
	check(hint.contains("毕方") and hint.contains("木生火"), "都收录后显示完整配方")
	check_eq(Bestiary.recipe_hint(lib, p, &"jingwei"), "", "普通异兽没有配方")


func test_profile_round_trip() -> void:
	var p := Profile.new()
	p.record_capture(&"jingwei")
	p.record_capture(&"jingwei")
	p.record_obtained(&"kui")
	p.record_seen(&"huashe")
	p.record_defeat(&"xiangliu")
	var r := Profile.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	check_eq(r.capture_count(&"jingwei"), 2)
	check(r.has_captured(&"kui") and r.capture_count(&"kui") == 0, "获得记录保留")
	check(r.has_seen(&"huashe") and not r.has_captured(&"huashe"), "遇见记录保留")
	check_eq(r.defeat_count(&"xiangliu"), 1)


func test_old_profile_still_loads() -> void:
	var old := {"schema": 1, "bestiary": {"dangkang": {"captures": 3}}, "runs_started": 2}
	var p := Profile.from_dict(old)
	check_eq(p.capture_count(&"dangkang"), 3, "旧档案的捕获次数保留")
	check(p.has_seen(&"dangkang"), "收录过的自动算遇见")


func test_sim_records_encountered_including_summons() -> void:
	var boss := Fixtures.beast(&"boss", Elements.SHUI, 1000, 20.0)
	boss.rarity = BeastDef.Rarity.BOSS
	var summon := EffectDef.new()
	summon.trigger = &"hp_below"
	summon.op = &"summon"
	summon.amount = 0.9
	summon.count = 1
	summon.param_id = &"minion"
	boss.abilities = [summon]
	var minion := Fixtures.beast(&"minion", Elements.SHUI, 10, 50.0)
	var sim := BattleSim.create(Fixtures.straight_battle(&"boss"), Fixtures.library([boss, minion]), ElementChart.new(), Fixtures.setup([] as Array[StringName]))
	sim.begin()
	sim.step()
	sim.enemies[0].hp = 100.0
	sim.step()
	check(sim.encountered.has(&"boss") and sim.encountered.has(&"minion"), "出场和召唤的都记为遇见")
