extends SceneTree
## 生成灰盒内容 .tres。只在初始化或重置灰盒数据时运行，会覆盖 res://content 下的同名文件：
##   godot --headless --path . --script res://tools/seed_graybox_content.gd
## 之后内容以 .tres 为准，在编辑器 Inspector 里改。

const OUT := "res://content"

## 冀州 01 的航点，原单位是 16×9 高度单位（左下原点），这里换算成 1920×1080 设计像素（左上原点）。
const JIZHOU_WAYPOINTS := [
	[1.470, 0.870], [1.240, 0.820], [0.980, 0.860], [0.700, 0.790], [0.480, 0.800],
	[0.390, 0.700], [0.400, 0.600], [0.600, 0.550], [0.880, 0.610], [1.160, 0.570],
	[1.420, 0.580], [1.520, 0.480], [1.360, 0.380], [1.060, 0.400], [0.740, 0.340],
	[0.440, 0.390], [0.270, 0.300], [0.330, 0.170], [0.660, 0.190], [1.000, 0.140],
	[1.300, 0.200], [1.530, 0.230],
]
const JIZHOU_SLOTS := [
	Vector2(713, 335), Vector2(929, 324), Vector2(1188, 324), Vector2(670, 594),
	Vector2(1404, 562), Vector2(1220, 756), Vector2(562, 778),
]


func _initialize() -> void:
	for dir in ["beasts", "relics", "battles", "keepers", "formations", "fusions", "events"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/%s" % [OUT, dir]))
	_save(ElementChart.new(), "element_chart.tres")
	var all_beasts := _beasts()
	for b in all_beasts:
		if b.rarity == BeastDef.Rarity.RARE:
			b.region = &""
	all_beasts.append_array(_qingzhou_beasts())
	for b in all_beasts:
		_save(b, "beasts/%s.tres" % b.id)
	for r in _relics():
		_save(r, "relics/%s.tres" % r.id)
	for battle in _battles():
		_save(battle, "battles/%s.tres" % battle.id)
	for k in _keepers():
		_save(k, "keepers/%s.tres" % k.id)
	for f in _formations():
		_save(f, "formations/%s.tres" % f.element)
	for r in _fusions():
		_save(r, "fusions/%s.tres" % r.id)
	for ev in _events():
		_save(ev, "events/%s.tres" % ev.id)
	print("灰盒内容已生成。")
	quit()


func _save(res: Resource, rel: String) -> void:
	var err := ResourceSaver.save(res, "%s/%s" % [OUT, rel])
	if err != OK:
		push_error("保存失败 %s: %d" % [rel, err])


func _effect(trigger: StringName, op: StringName, amount: float, duration: int = 0, radius: float = 0.0, desc: String = "", scope: StringName = &"") -> EffectDef:
	var e := EffectDef.new()
	e.element_scope = scope
	e.trigger = trigger
	e.op = op
	e.amount = amount
	e.duration_ticks = duration
	e.radius = radius
	e.description = desc
	return e


func _beast(id: StringName, name: String, en: String, element: StringName, role: BeastDef.Role, rarity: BeastDef.Rarity, lore: String, enemy: Array, tower: Array, traits: Array[EffectDef] = []) -> BeastDef:
	var b := BeastDef.new()
	b.id = id
	b.contact_damage = 15.0 if rarity == BeastDef.Rarity.ELITE else 5.0
	b.display_name = name
	b.name_en = en
	b.element = element
	b.role = role
	b.rarity = rarity
	b.lore = lore
	b.max_hp = enemy[0]
	b.move_speed = enemy[1]
	b.leak_damage = enemy[2]
	b.spirit_reward = enemy[3]
	b.shell_reward = enemy[4]
	b.capturable = rarity == BeastDef.Rarity.COMMON or rarity == BeastDef.Rarity.ELITE
	b.deploy_cost = tower[0]
	b.damage = tower[1]
	b.attack_range = tower[2]
	b.attack_interval_ticks = tower[3]
	b.projectile_speed = tower[4]
	b.traits = traits
	return b


## 数值对照同类热门塔防的节奏（放大 10 倍便于出大数字）：
##   杂兵 2–5 下打死，普通异兽要几只塔合力，精英要集火，首领要全队加技能。
##   攻击节奏按 Kingdom Rush 式原型分化：快射 0.4 秒、常规 0.8 秒、范围 1.5 秒、重击 2 秒。
##   灵气按明日方舟式费用经济：开局 15，每秒 +1，部署 6–8，升级 ×2 / ×3.5。
func _beasts() -> Array[BeastDef]:
	var R := BeastDef.Role
	var Q := BeastDef.Rarity
	# enemy: [max_hp, move_speed, leak_damage, spirit_reward, shell_reward]
	# tower: [deploy_cost, damage, attack_range, attack_interval_ticks, projectile_speed]
	return [
		_crit(_beast(&"dangkang", "当康", "Dangkang, the Harvest Boar", Elements.TU, R.AUSPICIOUS, Q.COMMON,
			"有兽焉，其状如豚而有牙，其名曰当康，其鸣自叫，见则天下大穰。",
			[1300, 90.0, 1, 3, 3], [6, 35, 250.0, 10, 650.0],
			[_effect(&"on_kill_nearby", &"bonus_shells", 1, 0, 320.0, "见则天下大穰：附近敌人被击杀时额外得 1 贝币")]), 0.05),
		_crit(_guard(_beast(&"lili", "狸力", "Lili, the Spurred Digger", Elements.TU, R.GUARD, Q.COMMON,
			"有兽焉，其状如豚，有距，其音如狗吠，其名曰狸力，见则其县多土功。",
			[2100, 70.0, 1, 3, 3], [7, 55, 200.0, 10, 700.0]), 900, 2), 0.05),
		_crit(_guard(_beast(&"fuzhu", "夫诸", "Fuzhu, the Four-Horned White Deer", Elements.SHUI, R.GUARD, Q.COMMON,
			"有兽焉，其状如白鹿而四角，名曰夫诸，见则其邑大水。",
			[1700, 85.0, 1, 3, 3], [7, 40, 200.0, 10, 650.0],
			[_effect(&"on_hit", &"slow", 0.7, 10, 0.0, "见则其邑大水：命中后减速 30%，1 秒")]), 650, 1), 0.05),
		_crit(_beast(&"bifang", "毕方", "Bifang, the One-Legged Fire Crane", Elements.HUO, R.RANGED, Q.COMMON,
			"有鸟焉，其状如鹤，一足，赤文青质而白喙，名曰毕方，见则其邑有讹火。",
			[1150, 120.0, 1, 3, 3], [7, 60, 290.0, 8, 700.0],
			[_effect(&"on_hit", &"burn", 12.0, 20, 0.0, "见则其邑有讹火：命中后每 0.1 秒灼烧 12，持续 2 秒"),
			_effect(&"on_hit", &"ignite_nearby", 8.0, 20, 160.0, "讹火：火星溅到附近另一个敌人身上")]), 0.1),
		_crit(_beast(&"huashe", "化蛇", "Huashe, the Flood Serpent", Elements.SHUI, R.AREA, Q.COMMON,
			"其中多化蛇，其状如人面而豺身，鸟翼而蛇行，其音如叱呼，见则其邑大水。",
			[1450, 100.0, 1, 3, 3], [8, 110, 270.0, 15, 600.0],
			[_effect(&"on_hit", &"slow", 0.6, 15, 0.0, "见则其邑大水：命中后减速 40%，1.5 秒"),
			_effect(&"on_hit", &"splash", 0.6, 0, 140.0, "大水：周围敌人受到 60% 伤害")]), 0.1),
		_crit(_beast(&"wenyao", "文鳐鱼", "Wenyao, the Winged Carp", Elements.SHUI, R.AUSPICIOUS, Q.COMMON,
			"是多文鳐鱼，状如鲤鱼，鱼身而鸟翼，苍文而白首赤喙，见则天下大穰。",
			[1000, 130.0, 1, 3, 3], [6, 35, 260.0, 9, 650.0],
			[_effect(&"on_wave_end", &"heal_ding", 1, 0, 0.0, "见则天下大穰：每清一波回复 1 点鼎耐久")]), 0.05),
		_crit(_beast(&"jingwei", "精卫", "Jingwei, the Sea-Filling Bird", Elements.MU, R.RANGED, Q.COMMON,
			"有鸟焉，其状如乌，文首，白喙，赤足，名曰精卫……常衔西山之木石，以堙于东海。",
			[1000, 125.0, 1, 3, 3], [6, 38, 300.0, 4, 900.0],
			[_effect(&"passive", &"bonus_vs_element", 0.5, 0, 0.0, "衔木石以堙东海：对水属敌人伤害 +50%", Elements.SHUI)]), 0.1),
		_crit(_beast(&"mingshe", "鸣蛇", "Mingshe, the Four-Winged Drought Snake", Elements.JIN, R.RANGED, Q.COMMON,
			"其中多鸣蛇，其状如蛇而四翼，其音如磬，见则其邑大旱。",
			[1450, 105.0, 1, 3, 3], [8, 280, 360.0, 20, 800.0],
			[_effect(&"on_hit", &"dry", 0.8, 0, 0.0, "见则其邑大旱：命中减速中的敌人时额外造成 80% 伤害并蒸干水泽")]), 0.2, 2.5),
		_crit(_beast(&"zhuyan", "朱厌", "Zhuyan, the War-Omen Ape", Elements.JIN, R.AUSPICIOUS, Q.ELITE,
			"有兽焉，其状如猿，而白首赤足，名曰朱厌，见则大兵。",
			[4800, 85.0, 2, 6, 5], [8, 50, 250.0, 9, 650.0],
			[_effect(&"passive", &"adjacent_damage_pct", 0.25, 0, 0.0, "见则大兵：相邻异兽伤害 +25%")]), 0.1),
		_abilities(_beast(&"xiangliu", "相柳", "Xiangliu, the Nine-Headed Serpent", Elements.SHUI, R.AREA, Q.BOSS,
			"共工之臣曰相柳氏，九首，以食于九山……禹杀相柳，其血腥，不可以树五谷种。",
			[14000, 42.0, 10, 15, 15], [0, 0, 0.0, 10, 600.0]), [
				_ability(&"periodic", &"stun_towers", 0.0, 35, 90, 2, &"", "毒涎：每 9 秒喷向最近的两只异兽，使其 3.5 秒无法攻击"),
				_ability(&"hp_below", &"summon", 0.66, 0, 0, 5, &"dingsha_shui", "九首：血量降到三分之二时召出 5 只鼎煞"),
				_ability(&"hp_below", &"summon", 0.33, 0, 0, 6, &"dingsha_shui", "九首：血量降到三分之一时再召出 6 只"),
			]),
		_crit(_beast(&"fenghuang", "凤皇", "Fenghuang, the Five-Hued Phoenix", Elements.HUO, R.RANGED, Q.RARE,
			"丹穴之山……有鸟焉，其状如鸡，五采而文，名曰凤皇……是鸟也，饮食自然，自歌自舞，见则天下安宁。",
			[3000, 100.0, 1, 3, 3], [9, 120, 330.0, 8, 850.0],
			[_effect(&"on_hit", &"burn", 20.0, 20, 0.0, "五采之火：命中后每 0.1 秒灼烧 20，持续 2 秒"),
			_effect(&"passive", &"adjacent_damage_pct", 0.2, 0, 0.0, "见则天下安宁：相邻异兽伤害 +20%")]), 0.15),
		_crit(_beast(&"yinglong", "应龙", "Yinglong, the Winged Rain Dragon", Elements.SHUI, R.AREA, Q.RARE,
			"应龙处南极，杀蚩尤与夸父，不得复上，故下数旱，旱而为应龙之状，乃得大雨。",
			[3000, 100.0, 1, 3, 3], [10, 200, 310.0, 14, 750.0],
			[_effect(&"on_hit", &"splash", 0.8, 0, 170.0, "乃得大雨：周围敌人受到 80% 伤害"),
			_effect(&"on_hit", &"slow", 0.5, 20, 0.0, "命中后减速 50%，2 秒")]), 0.1),
		_crit(_beast(&"bo", "驳", "Bo, the Tiger-Eating Horse", Elements.JIN, R.RANGED, Q.RARE,
			"有兽焉，其状如马而白身黑尾，一角，虎牙爪，音如鼓音，其名曰驳，是食虎豹，可以御兵。",
			[3000, 100.0, 1, 3, 3], [10, 520, 390.0, 20, 950.0]), 0.25, 2.5),
		_crit(_guard(_beast(&"kui", "夔", "Kui, the One-Legged Thunder Ox", Elements.TU, R.GUARD, Q.RARE,
			"东海中有流波山……其上有兽，状如牛，苍身而无角，一足……其声如雷，其名曰夔。黄帝得之，以其皮为鼓……声闻五百里，以威天下。",
			[3000, 100.0, 1, 3, 3], [10, 90, 220.0, 12, 700.0],
			[_effect(&"on_hit", &"stagger", 0.25, 10, 0.0, "其声如雷：命中时 25% 概率震慑敌人 1 秒")]), 1600, 3), 0.05),
		_beast(&"dingsha_tu", "鼎煞（土）", "Cauldron Wraith (Earth)", Elements.TU, R.RANGED, Q.MINION,
			"九鼎崩裂时溢出的浊气。", [340, 105.0, 1, 1, 0], [0, 0, 0.0, 10, 600.0]),
		_beast(&"dingsha_shui", "鼎煞（水）", "Cauldron Wraith (Water)", Elements.SHUI, R.RANGED, Q.MINION,
			"九鼎崩裂时溢出的浊气。", [280, 125.0, 1, 1, 0], [0, 0, 0.0, 10, 600.0]),
		_beast(&"dingsha_huo", "鼎煞（火）", "Cauldron Wraith (Fire)", Elements.HUO, R.RANGED, Q.MINION,
			"九鼎崩裂时溢出的浊气。", [360, 115.0, 1, 1, 0], [0, 0, 0.0, 10, 600.0]),
	]


func _abilities(b: BeastDef, list: Array[EffectDef]) -> BeastDef:
	b.abilities = list
	return b


func _ability(trigger: StringName, op: StringName, amount: float, duration: int, interval: int, count: int, param: StringName, desc: String) -> EffectDef:
	var e := _effect(trigger, op, amount, duration, 0.0, desc)
	e.interval_ticks = interval
	e.count = count
	e.param_id = param
	return e


func _run_effect(op: StringName, amount: float = 0.0, param: StringName = &"") -> EffectDef:
	var e := _effect(&"run", op, amount)
	e.param_id = param
	return e


func _region(b: BeastDef, region: StringName) -> BeastDef:
	b.region = region
	return b


## 青州：东方之州，五行属木。异兽取自《东山经》《海外东经》。
func _qingzhou_beasts() -> Array[BeastDef]:
	var R := BeastDef.Role
	var Q := BeastDef.Rarity
	var list: Array[BeastDef] = [
		_crit(_guard(_beast(&"lingling", "軨軨", "Lingling, the Tiger-Striped Ox", Elements.SHUI, R.GUARD, Q.COMMON,
			"空桑之山……有兽焉，其状如牛而虎文，其音如钦，其名曰軨軨，其鸣自叫，见则天下大水。",
			[1700, 80.0, 1, 3, 3], [7, 60, 200.0, 10, 700.0],
			[_effect(&"on_hit", &"slow", 0.7, 10, 0.0, "见则天下大水：命中后减速 30%，1 秒")]), 1100, 2), 0.05),
		_crit(_beast(&"zhuru", "朱獳", "Zhuru, the Fish-Finned Fox", Elements.HUO, R.RANGED, Q.COMMON,
			"耿山……有兽焉，其状如狐而鱼翼，其名曰朱獳，其鸣自叫，见则其国有恐。",
			[1200, 115.0, 1, 3, 3], [7, 75, 300.0, 8, 750.0],
			[_effect(&"on_hit", &"stagger", 0.15, 10, 0.0, "见则其国有恐：命中时 15% 概率吓得敌人呆立 1 秒")]), 0.1),
		_crit(_beast(&"bibi", "獙獙", "Bibi, the Winged Drought Fox", Elements.HUO, R.AREA, Q.COMMON,
			"姑逢之山……有兽焉，其状如狐而有翼，其音如鸿雁，其名曰獙獙，见则天下大旱。",
			[1300, 110.0, 1, 3, 3], [8, 120, 270.0, 14, 650.0],
			[_effect(&"on_hit", &"splash", 0.6, 0, 140.0, "大旱：周围敌人受到 60% 伤害"),
			_effect(&"on_hit", &"dry", 0.6, 0, 0.0, "见则天下大旱：命中减速中的敌人时额外造成 60% 伤害并蒸干水泽")]), 0.1),
		_crit(_beast(&"lihu", "鵹鹕", "Lihu, the Human-Footed Mandarin Duck", Elements.TU, R.AUSPICIOUS, Q.COMMON,
			"卢其之山……其中多鵹鹕，其状如鸳鸯而人足，其鸣自訆，见则其国多土功。",
			[1000, 120.0, 1, 3, 3], [6, 40, 250.0, 10, 650.0],
			[_effect(&"passive", &"spirit_income", 1, 40, 0.0, "见则其国多土功：每 4 秒额外 +1 灵气")]), 0.05),
		_crit(_beast(&"jiegou", "絜钩", "Jiegou, the Rat-Tailed Plague Duck", Elements.MU, R.RANGED, Q.COMMON,
			"硜山……有鸟焉，其状如凫而鼠尾，善登木，其名曰絜钩，见则其国多疫。",
			[900, 135.0, 1, 3, 3], [6, 34, 290.0, 4, 950.0],
			[_effect(&"on_hit", &"burn", 6.0, 15, 0.0, "见则其国多疫：命中后染疫，每 0.1 秒受 6 点伤害，持续 1.5 秒")]), 0.1),
		_crit(_beast(&"heyu", "合窳", "Heyu, the Man-Faced Boar", Elements.SHUI, R.RANGED, Q.COMMON,
			"剡山……有兽焉，其状如彘而人面，黄身而赤尾，其名曰合窳，其音如婴儿。是兽也，食人，亦食虫蛇，见则天下大水。",
			[1500, 95.0, 1, 3, 3], [8, 160, 320.0, 12, 800.0],
			[_effect(&"passive", &"bonus_vs_element", 0.6, 0, 0.0, "亦食虫蛇：对木属敌人伤害 +60%", Elements.MU)]), 0.15),
		_crit(_beast(&"youyou", "峳峳", "Youyou, the Four-Horned Cunning Horse", Elements.JIN, R.AUSPICIOUS, Q.COMMON,
			"碧山……有兽焉，其状如马而羊目，四角，牛尾，其音如獆狗，其名曰峳峳，见则其国多狡客。",
			[1300, 105.0, 1, 3, 3], [7, 60, 260.0, 10, 700.0],
			[_effect(&"passive", &"capture_threshold_bonus", 0.05, 0, 0.0, "见则其国多狡客：捕获线 +5%")]), 0.1),
		_crit(_beast(&"longzhi", "蠪蛭", "Longzhi, the Nine-Headed Fox", Elements.MU, R.RANGED, Q.ELITE,
			"凫丽之山……有兽焉，其状如狐，而九尾、九首、虎爪，名曰蠪蛭，其音如婴儿，是食人。",
			[6000, 90.0, 2, 6, 5], [9, 90, 300.0, 9, 800.0],
			[_effect(&"on_hit", &"splash", 0.4, 0, 120.0, "九首：周围敌人受到 40% 伤害")]), 0.1),
		_abilities(_beast(&"fei", "蜚", "Fei, the One-Eyed Plague Ox", Elements.JIN, R.AREA, Q.BOSS,
			"太山……有兽焉，其状如牛而白首，一目而蛇尾，其名曰蜚，行水则竭，行草则死，见则天下大疫。",
			[18000, 40.0, 10, 15, 15], [0, 0, 0.0, 10, 600.0]), [
				_ability(&"aura", &"weaken_towers", 0.35, 0, 0, 0, &"", "行草则死：身边 260 范围内的异兽伤害 -35%"),
				_ability(&"periodic", &"drain_spirit", 4.0, 0, 80, 0, &"", "见则天下大疫：每 8 秒吸走 4 点灵气"),
				_ability(&"hp_below", &"summon", 0.5, 0, 0, 3, &"jiegou", "疫鸟随行：血量减半时召出 3 只絜钩（可以捕获）"),
			]),
		_beast(&"dingsha_mu", "鼎煞（木）", "Cauldron Wraith (Wood)", Elements.MU, R.RANGED, Q.MINION,
			"九鼎崩裂时溢出的浊气。", [380, 120.0, 1, 1, 0], [0, 0, 0.0, 10, 600.0]),
		_beast(&"dingsha_jin", "鼎煞（金）", "Cauldron Wraith (Metal)", Elements.JIN, R.RANGED, Q.MINION,
			"九鼎崩裂时溢出的浊气。", [420, 105.0, 1, 1, 0], [0, 0, 0.0, 10, 600.0]),
	]
	for b in list:
		b.region = &"qingzhou"
	# 精英的接触伤害与冀州一致
	list[7].contact_damage = 15.0
	var fei_aura: EffectDef = list[8].abilities[0]
	fei_aura.radius = 260.0
	list.append(_region(_crit(_beast(&"goumang", "句芒", "Goumang, God of the East and Wood", Elements.MU, R.AUSPICIOUS, Q.RARE,
		"东方句芒，鸟身人面，乘两龙。",
		[3000, 100.0, 1, 3, 3], [10, 80, 300.0, 8, 850.0],
		[_effect(&"passive", &"spirit_income", 1, 25, 0.0, "东方木神：每 2.5 秒额外 +1 灵气"),
		_effect(&"passive", &"adjacent_damage_pct", 0.3, 0, 0.0, "春生万物：相邻异兽伤害 +30%")]), 0.1), &""))
	list.append(_region(_crit(_beast(&"tianwu", "天吴", "Tianwu, the Eight-Headed Water Lord", Elements.SHUI, R.AREA, Q.RARE,
		"朝阳之谷，神曰天吴，是为水伯……其为兽也，八首人面，八足八尾，皆青黄。",
		[3000, 100.0, 1, 3, 3], [11, 260, 320.0, 16, 750.0],
		[_effect(&"on_hit", &"splash", 0.7, 0, 180.0, "水伯：周围敌人受到 70% 伤害"),
		_effect(&"on_hit", &"slow", 0.6, 15, 0.0, "命中后减速 40%，1.5 秒")]), 0.15), &""))
	return list


func _crit(b: BeastDef, chance: float, mult: float = 2.0) -> BeastDef:
	b.crit_chance = chance
	b.crit_multiplier = mult
	return b


func _guard(b: BeastDef, hp: int, block: int) -> BeastDef:
	b.guard_hp = hp
	b.block_count = block
	return b


func _skill(name: String, desc: String, op: StringName, cost: int, cooldown: int, amount: float, radius: float, duration: int = 0) -> SkillDef:
	var s := SkillDef.new()
	s.display_name = name
	s.description = desc
	s.op = op
	s.spirit_cost = cost
	s.cooldown_ticks = cooldown
	s.amount = amount
	s.radius = radius
	s.duration_ticks = duration
	return s


func _keeper(id: StringName, order: int, name: String, desc: String, beasts: Array[StringName], talismans: int, passives: Array[EffectDef], skill: SkillDef) -> KeeperDef:
	var k := KeeperDef.new()
	k.id = id
	k.order = order
	k.display_name = name
	k.description = desc
	k.starting_beasts = beasts
	k.starting_talismans = talismans
	k.passives = passives
	k.skill = skill
	return k


func _keepers() -> Array[KeeperDef]:
	return [
		_keeper(&"zhudingjiang", 1, "铸鼎匠", "禹铸九鼎时的匠人后裔。镇守异兽更结实。",
			[&"jingwei", &"lili"] as Array[StringName], 5,
			[_effect(&"passive", &"guard_hp_pct", 0.3, 0, 0.0, "镇守异兽生命 +30%")],
			_skill("鼎鸣", "敲击铜鼎，震伤范围内所有敌人。", &"damage_area", 8, 150, 450.0, 220.0)),
		_keeper(&"wuzhu", 2, "巫祝", "通晓异兽之名的巫。更容易收服异兽。",
			[&"jingwei", &"huashe"] as Array[StringName], 6,
			[_effect(&"passive", &"capture_threshold_bonus", 0.1, 0, 0.0, "捕获血线 +10%"),
			_effect(&"on_battle_start", &"add_talismans", 1, 0, 0.0, "每场额外 1 张临时镇鼎符")],
			_skill("定身符", "范围内敌人定身 3 秒。", &"freeze_area", 6, 180, 0.0, 220.0, 30)),
		_keeper(&"yiyi", 3, "羿裔", "射日之羿的后人。伤害更高，但镇鼎符更少。",
			[&"bifang", &"mingshe"] as Array[StringName], 4,
			[_effect(&"passive", &"global_damage_pct", 0.05, 0, 0.0, "全体伤害 +5%")],
			_skill("射日", "一箭射中场上生命最高的敌人。", &"smite_strongest", 9, 260, 1200.0, 0.0)),
	]


func _tier(count: int, effects: Array[EffectDef]) -> FormationTier:
	var t := FormationTier.new()
	t.count = count
	t.effects = effects
	return t


func _formation(element: StringName, name: String, desc: String, tiers: Array[FormationTier]) -> FormationDef:
	var f := FormationDef.new()
	f.element = element
	f.display_name = name
	f.description = desc
	f.tiers = tiers
	return f


## 阵名取自《尚书·洪范》："水曰润下，火曰炎上，木曰曲直，金曰从革，土爰稼穑。"
func _formations() -> Array[FormationDef]:
	return [
		_formation(Elements.JIN, "从革", "金属异兽伤害提升。", [
			_tier(2, [_effect(&"passive", &"element_damage_pct", 0.15)]),
			_tier(4, [_effect(&"passive", &"element_damage_pct", 0.4)]),
		]),
		_formation(Elements.MU, "曲直", "额外回复灵气。", [
			_tier(2, [_effect(&"passive", &"spirit_income", 1, 40)]),
			_tier(4, [_effect(&"passive", &"spirit_income", 1, 15)]),
		]),
		_formation(Elements.SHUI, "润下", "水属异兽的攻击附带减速。", [
			_tier(2, [_effect(&"on_hit", &"slow", 0.8, 10)]),
			_tier(4, [_effect(&"on_hit", &"slow", 0.6, 15)]),
		]),
		_formation(Elements.HUO, "炎上", "火属异兽的攻击附带灼烧。", [
			_tier(2, [_effect(&"on_hit", &"burn", 10.0, 15)]),
			_tier(4, [_effect(&"on_hit", &"burn", 25.0, 20)]),
		]),
		_formation(Elements.TU, "稼穑", "清波时修复铜鼎；四只时镇守更结实。", [
			_tier(2, [_effect(&"on_wave_end", &"heal_ding", 1)]),
			_tier(4, [_effect(&"on_wave_end", &"heal_ding", 1), _effect(&"passive", &"guard_hp_pct", 0.5)]),
		]),
	]


func _relic(id: StringName, name: String, desc: String, price: int, effects: Array[EffectDef]) -> RelicDef:
	var r := RelicDef.new()
	r.id = id
	r.display_name = name
	r.description = desc
	r.price = price
	r.effects = effects
	return r


## 法宝取自《山海经》里的奇物，效果从原文的"服之……""佩之……"化来。
func _relics() -> Array[RelicDef]:
	return [
		_relic(&"hetu", "河图", "每场战斗额外获得 1 张临时镇鼎符。", 30,
			[_effect(&"on_battle_start", &"add_talismans", 1)]),
		_relic(&"luoshu", "洛书", "所有异兽伤害 +10%。", 35,
			[_effect(&"passive", &"global_damage_pct", 0.1)]),
		_relic(&"ditai_qi", "帝台之棋", "帝台之石，所以祷百神者也。每场战斗开局灵气 +6。", 28,
			[_effect(&"on_battle_start", &"add_spirit", 6)]),
		_relic(&"migu", "迷穀", "佩之不迷。提前召唤的灵气奖励翻倍。", 25,
			[_effect(&"passive", &"early_call_mult", 1.0)]),
		_relic(&"zhuyu", "祝余", "食之不饥。每 3 秒额外 +1 灵气。", 30,
			[_effect(&"passive", &"spirit_income", 1, 30)]),
		_relic(&"yugao", "玉膏", "黄帝是食是飨。获得时铜鼎耐久上限 +2。", 22,
			[_effect(&"on_pickup", &"ding_max", 2)]),
		_relic(&"lushu", "鹿蜀皮", "佩之宜子孙。战斗获得的贝币 +30%。", 25,
			[_effect(&"passive", &"shell_bonus_pct", 0.3)]),
	]


func _fusion(id: StringName, a: StringName, b: StringName, result: StringName, desc: String) -> FusionRecipe:
	var f := FusionRecipe.new()
	f.id = id
	f.a = a
	f.b = b
	f.result = result
	f.description = desc
	return f


## 配方按五行相生："生"的一方加"被生"的一方，融成被生一方五行的稀有异兽。
func _fusions() -> Array[FusionRecipe]:
	return [
		_fusion(&"mu_huo_fenghuang", &"jingwei", &"bifang", &"fenghuang", "木生火：精卫衔木，毕方引火，化为凤皇。"),
		_fusion(&"jin_shui_yinglong", &"mingshe", &"huashe", &"yinglong", "金生水：鸣蛇之旱遇化蛇之水，旱极而为应龙，乃得大雨。"),
		_fusion(&"tu_jin_bo", &"dangkang", &"mingshe", &"bo", "土生金：当康丰年之土，鸣蛇如磬之金，化为御兵之驳。"),
		_fusion(&"huo_tu_kui", &"bifang", &"lili", &"kui", "火生土：毕方之火锻狸力之土，化为声如雷的夔。"),
		_fusion(&"shui_mu_goumang", &"lingling", &"jiegou", &"goumang", "水生木：軨軨引来大水，絜钩登木而栖，春木生发，化为东方之神句芒。"),
		_fusion(&"jin_shui_tianwu", &"youyou", &"heyu", &"tianwu", "金生水：峳峳四角如金，合窳见则大水，化为八首的水伯天吴。"),
	]


func _option(label: String, hint: String, cost: int, chance: float, outcomes: Array[EffectDef], fails: Array[EffectDef] = [], ok_text: String = "", fail_text: String = "") -> EventOption:
	var o := EventOption.new()
	o.label = label
	o.hint = hint
	o.cost_shells = cost
	o.success_chance = chance
	o.outcomes = outcomes
	o.fail_outcomes = fails
	o.success_text = ok_text
	o.fail_text = fail_text
	return o


func _event(id: StringName, title: String, source: String, situation: String, options: Array[EventOption]) -> EventDef:
	var e := EventDef.new()
	e.id = id
	e.title = title
	e.source_text = source
	e.situation = situation
	e.options = options
	return e


func _events() -> Array[EventDef]:
	return [
		_event(&"qingqiu_hu", "青丘之狐",
			"又东三百里，曰青丘之山……有兽焉，其状如狐而九尾，其音如婴儿，能食人；食者不蛊。",
			"夜宿青丘，林间传来婴儿般的啼声，九条尾影在月下晃动。",
			[_option("献上贝币，求它庇佑", "花 8 贝币：镇鼎符 +1，修鼎 2", 8, 1.0,
				[_run_effect(&"gain_talismans", 1), _run_effect(&"heal_ding", 2)], [], "九尾狐收下供奉，绕鼎三匝而去。"),
			_option("循声追去", "一半可能得到法宝，一半可能被咬伤铜鼎", 0, 0.5,
				[_run_effect(&"gain_relic")], [_run_effect(&"lose_ding", 3)],
				"狐影消失处留下一件宝物。", "林中扑出一张巨口，铜鼎被啃出裂痕。"),
			_option("绕道而行", "什么也不发生", 0, 1.0, [], [], "你没有理会那啼声。")]),
		_event(&"mi_yugao", "峚山玉膏",
			"西北四百二十里，曰峚山……其中多白玉，是有玉膏，其原沸沸汤汤，黄帝是食是飨。",
			"山涧里白玉如脂，玉膏正汩汩涌出。",
			[_option("以玉膏涂鼎", "铜鼎耐久上限 +2", 0, 1.0, [_run_effect(&"ding_max", 2)], [], "玉膏渗进鼎身，纹路愈发温润。"),
			_option("采白玉换钱", "贝币 +12", 0, 1.0, [_run_effect(&"gain_shells", 12)], [], "你背走了一袋白玉。")]),
		_event(&"zhaoyao_zhuyu", "招摇祝余",
			"南山经之首曰䧿山。其首曰招摇之山……有草焉，其状如韭而青华，其名曰祝余，食之不饥。",
			"招摇山坡上长满青花如韭的草。",
			[_option("采祝余", "获得法宝祝余（已有则得贝币）", 0, 1.0, [_run_effect(&"gain_relic", 0, &"zhuyu")], [], "你采了一大把祝余。"),
			_option("继续赶路", "贝币 +4", 0, 1.0, [_run_effect(&"gain_shells", 4)], [], "路边拾到几枚贝币。")]),
		_event(&"ditai_qi", "帝台之棋",
			"休与之山，其上有石焉，名曰帝台之棋，五色而文，其状如鹑卵。帝台之石，所以祷百神者也，服之不蛊。",
			"山顶散落着五色斑斓、状如鹌鹑蛋的石子。",
			[_option("以石祷神", "随机一只异兽升一阶", 0, 1.0, [_run_effect(&"tier_up_random")], [], "石子在掌心发烫，一只异兽的气息变强了。"),
			_option("把石子做成符", "镇鼎符 +2", 0, 1.0, [_run_effect(&"gain_talismans", 2)], [], "你把石子磨成了两张镇鼎符。")]),
		_event(&"liubo_kui", "流波山之夔",
			"东海中有流波山，入海七千里。其上有兽，状如牛，苍身而无角，一足，出入水则必风雨，其光如日月，其声如雷，其名曰夔。",
			"海上风雨大作，雷声中一头独足苍牛踏浪而来。",
			[_option("以鼎为鼓，与之相搏", "铜鼎耐久 -4，夔加入阵容（阵容满则离去）", 0, 1.0,
				[_run_effect(&"lose_ding", 4), _run_effect(&"gain_beast", 0, &"kui")], [], "鼎声与雷声相应，夔低下了头。"),
			_option("远远观望", "贝币 +6", 0, 1.0, [_run_effect(&"gain_shells", 6)], [], "风雨过后，沙滩上留下几枚贝币。")]),
		_event(&"migu_tree", "迷穀之木",
			"有木焉，其状如穀而黑理，其华四照，其名曰迷穀，佩之不迷。",
			"一棵黑纹古树开着四面放光的花。",
			[_option("折一枝佩上", "获得法宝迷穀（已有则得贝币）", 0, 1.0, [_run_effect(&"gain_relic", 0, &"migu")], [], "花枝的光照亮了前路。"),
			_option("伐木卖钱", "贝币 +10", 0, 1.0, [_run_effect(&"gain_shells", 10)], [], "你卖掉了木材。")]),
		_event(&"niuyang_lushu", "杻阳鹿蜀",
			"又东三百七十里，曰杻阳之山……有兽焉，其状如马而白首，其文如虎而赤尾，其音如谣，其名曰鹿蜀，佩之宜子孙。",
			"一匹白首虎纹的马在山谷里唱着歌谣般的长鸣。",
			[_option("用贝币换它脱下的皮", "花 10 贝币：获得法宝鹿蜀皮", 10, 1.0, [_run_effect(&"gain_relic", 0, &"lushu")], [], "鹿蜀留下一张带虎纹的皮毛。"),
			_option("驻足听它唱完", "修鼎 3", 0, 1.0, [_run_effect(&"heal_ding", 3)], [], "歌声里，铜鼎的裂痕似乎合拢了些。")]),
	]


func _spawn(id: StringName, count: int, interval: int, hp_mult: float = 1.0) -> SpawnEntry:
	var s := SpawnEntry.new()
	s.beast_id = id
	s.count = count
	s.interval_ticks = interval
	s.hp_multiplier = hp_mult
	return s


func _wave(gap: int, spawns: Array[SpawnEntry]) -> WaveDef:
	var w := WaveDef.new()
	w.gap_ticks_before = gap
	w.spawns = spawns
	return w


func _battle(id: StringName, name: String, kind: BattleDef.Kind, waves: Array[WaveDef]) -> BattleDef:
	var b := BattleDef.new()
	b.id = id
	b.display_name = name
	b.kind = kind
	var pts := PackedVector2Array()
	for p: Array in JIZHOU_WAYPOINTS:
		pts.append(Vector2(roundf(p[0] * 1080.0), roundf((1.0 - p[1]) * 1080.0)))
	b.path_points = pts
	b.slots = PackedVector2Array(JIZHOU_SLOTS)
	b.waves = waves
	return b


## 青州的海岸路线：从西边上岸，在礁石间折返，最后到东南角的鼎。
const QINGZHOU_PATH := [
	Vector2(60, 600), Vector2(380, 560), Vector2(520, 360), Vector2(840, 300), Vector2(1000, 470),
	Vector2(860, 650), Vector2(560, 700), Vector2(430, 860), Vector2(800, 880), Vector2(1180, 820),
	Vector2(1300, 600), Vector2(1180, 420), Vector2(1340, 260), Vector2(1640, 300), Vector2(1760, 520),
	Vector2(1600, 720), Vector2(1760, 860),
]
const QINGZHOU_SLOTS := [
	Vector2(640, 480), Vector2(300, 420), Vector2(1000, 300), Vector2(1080, 640),
	Vector2(700, 780), Vector2(1440, 440), Vector2(1480, 620), Vector2(1620, 880),
]


func _qz_battle(id: StringName, name: String, kind: BattleDef.Kind, waves: Array[WaveDef]) -> BattleDef:
	var b := BattleDef.new()
	b.id = id
	b.display_name = name
	b.kind = kind
	b.region = &"qingzhou"
	b.path_points = PackedVector2Array(QINGZHOU_PATH)
	b.slots = PackedVector2Array(QINGZHOU_SLOTS)
	b.waves = waves
	return b


## 普通战 5 波、精英 5 波、首领 6 波。第一波前 8 秒准备，之后每波前 15 秒倒计时，可提前召唤换灵气。
## 杂兵成群（每波 8–14 只），中间夹 1–2 只可捕获的异兽，波次血量逐步 ×1.0 → ×1.6。
func _battles() -> Array[BattleDef]:
	var K := BattleDef.Kind
	return [
		_battle(&"jizhou_b01", "冀州 · 田野", K.NORMAL, [
			_wave(80, [_spawn(&"dingsha_tu", 8, 10)]),
			_wave(150, [_spawn(&"dingsha_tu", 10, 8), _spawn(&"dangkang", 1, 8)]),
			_wave(150, [_spawn(&"dingsha_shui", 10, 8, 1.4), _spawn(&"huashe", 1, 8)]),
			_wave(150, [_spawn(&"dingsha_tu", 8, 7, 1.7), _spawn(&"dingsha_shui", 8, 7, 1.7), _spawn(&"lili", 1, 7)]),
			_wave(150, [_spawn(&"dingsha_tu", 12, 6, 2.1), _spawn(&"dangkang", 1, 6, 1.4), _spawn(&"huashe", 1, 6, 1.4)]),
		]),
		_battle(&"jizhou_b02", "冀州 · 河滩", K.NORMAL, [
			_wave(80, [_spawn(&"dingsha_shui", 9, 9)]),
			_wave(150, [_spawn(&"dingsha_shui", 10, 8), _spawn(&"wenyao", 1, 8)]),
			_wave(150, [_spawn(&"dingsha_tu", 10, 8, 1.4), _spawn(&"fuzhu", 1, 8)]),
			_wave(150, [_spawn(&"dingsha_shui", 12, 6, 1.7), _spawn(&"mingshe", 1, 6)]),
			_wave(150, [_spawn(&"dingsha_tu", 8, 6, 2.1), _spawn(&"dingsha_shui", 8, 6, 2.1), _spawn(&"lili", 1, 6, 1.4), _spawn(&"wenyao", 1, 6, 1.4)]),
		]),
		_battle(&"jizhou_b03", "冀州 · 焦土", K.NORMAL, [
			_wave(80, [_spawn(&"dingsha_huo", 8, 10)]),
			_wave(150, [_spawn(&"dingsha_huo", 10, 8), _spawn(&"bifang", 1, 8)]),
			_wave(150, [_spawn(&"dingsha_tu", 10, 8, 1.4), _spawn(&"jingwei", 1, 8)]),
			_wave(150, [_spawn(&"dingsha_huo", 12, 6, 1.7), _spawn(&"dangkang", 1, 6)]),
			_wave(150, [_spawn(&"dingsha_huo", 8, 6, 2.1), _spawn(&"dingsha_tu", 8, 6, 2.1), _spawn(&"bifang", 1, 6, 1.4), _spawn(&"jingwei", 1, 6, 1.4)]),
		]),
		_battle(&"jizhou_elite01", "冀州 · 兵兆", K.ELITE, [
			_wave(80, [_spawn(&"dingsha_tu", 10, 8)]),
			_wave(150, [_spawn(&"dingsha_huo", 10, 7, 1.4), _spawn(&"mingshe", 1, 7)]),
			_wave(150, [_spawn(&"dingsha_shui", 12, 6, 1.7), _spawn(&"huashe", 1, 6)]),
			_wave(150, [_spawn(&"dingsha_tu", 10, 6, 1.8), _spawn(&"zhuyan", 1, 6)]),
			_wave(150, [_spawn(&"dingsha_huo", 10, 5, 2.3), _spawn(&"dingsha_shui", 10, 5, 2.3), _spawn(&"mingshe", 2, 20, 1.7)]),
		]),
		_qz_battle(&"qingzhou_b01", "青州 · 空桑", K.NORMAL, [
			_wave(80, [_spawn(&"dingsha_mu", 10, 9)]),
			_wave(150, [_spawn(&"dingsha_mu", 10, 8), _spawn(&"jiegou", 1, 8)]),
			_wave(150, [_spawn(&"dingsha_jin", 10, 8, 1.4), _spawn(&"lingling", 1, 8)]),
			_wave(150, [_spawn(&"dingsha_mu", 12, 6, 1.7), _spawn(&"zhuru", 1, 6)]),
			_wave(150, [_spawn(&"dingsha_mu", 8, 6, 2.1), _spawn(&"dingsha_jin", 8, 6, 2.1), _spawn(&"heyu", 1, 6, 1.4), _spawn(&"jiegou", 1, 6, 1.4)]),
		]),
		_qz_battle(&"qingzhou_b02", "青州 · 姑逢", K.NORMAL, [
			_wave(80, [_spawn(&"dingsha_jin", 9, 9)]),
			_wave(150, [_spawn(&"dingsha_jin", 10, 8), _spawn(&"youyou", 1, 8)]),
			_wave(150, [_spawn(&"dingsha_mu", 10, 8, 1.4), _spawn(&"bibi", 1, 8)]),
			_wave(150, [_spawn(&"dingsha_jin", 12, 6, 1.7), _spawn(&"lihu", 1, 6)]),
			_wave(150, [_spawn(&"dingsha_jin", 8, 6, 2.1), _spawn(&"dingsha_mu", 8, 6, 2.1), _spawn(&"bibi", 1, 6, 1.4), _spawn(&"youyou", 1, 6, 1.4)]),
		]),
		_qz_battle(&"qingzhou_b03", "青州 · 剡山", K.NORMAL, [
			_wave(80, [_spawn(&"dingsha_mu", 9, 9)]),
			_wave(150, [_spawn(&"dingsha_shui", 10, 8), _spawn(&"heyu", 1, 8)]),
			_wave(150, [_spawn(&"dingsha_mu", 10, 8, 1.4), _spawn(&"lihu", 1, 8)]),
			_wave(150, [_spawn(&"dingsha_jin", 12, 6, 1.7), _spawn(&"lingling", 1, 6)]),
			_wave(150, [_spawn(&"dingsha_mu", 8, 6, 2.1), _spawn(&"dingsha_shui", 8, 6, 2.1), _spawn(&"zhuru", 1, 6, 1.4), _spawn(&"heyu", 1, 6, 1.4)]),
		]),
		_qz_battle(&"qingzhou_elite01", "青州 · 凫丽", K.ELITE, [
			_wave(80, [_spawn(&"dingsha_mu", 10, 8)]),
			_wave(150, [_spawn(&"dingsha_jin", 10, 7, 1.4), _spawn(&"zhuru", 1, 7)]),
			_wave(150, [_spawn(&"dingsha_mu", 12, 6, 1.7), _spawn(&"bibi", 1, 6)]),
			_wave(150, [_spawn(&"dingsha_jin", 10, 6, 1.8), _spawn(&"longzhi", 1, 6)]),
			_wave(150, [_spawn(&"dingsha_mu", 10, 5, 2.3), _spawn(&"dingsha_jin", 10, 5, 2.3), _spawn(&"heyu", 2, 20, 1.7)]),
		]),
		_qz_battle(&"qingzhou_boss", "青州 · 蜚", K.BOSS, [
			_wave(80, [_spawn(&"dingsha_mu", 12, 7)]),
			_wave(150, [_spawn(&"dingsha_jin", 12, 6, 1.2), _spawn(&"lingling", 1, 6)]),
			_wave(150, [_spawn(&"dingsha_mu", 12, 6, 1.4), _spawn(&"zhuru", 1, 6)]),
			_wave(150, [_spawn(&"dingsha_jin", 14, 5, 1.5), _spawn(&"bibi", 1, 5, 1.2)]),
			_wave(150, [_spawn(&"dingsha_mu", 10, 5, 1.7), _spawn(&"dingsha_jin", 10, 5, 1.7)]),
			_wave(150, [_spawn(&"fei", 1, 10), _spawn(&"dingsha_mu", 12, 15, 1.9), _spawn(&"dingsha_jin", 10, 15, 1.9)]),
		]),
		_battle(&"jizhou_boss", "冀州 · 相柳", K.BOSS, [
			_wave(80, [_spawn(&"dingsha_shui", 12, 7)]),
			_wave(150, [_spawn(&"dingsha_tu", 12, 6, 1.4), _spawn(&"fuzhu", 1, 6)]),
			_wave(150, [_spawn(&"dingsha_huo", 12, 6, 1.7), _spawn(&"bifang", 1, 6)]),
			_wave(150, [_spawn(&"dingsha_shui", 14, 5, 1.8), _spawn(&"huashe", 1, 5, 1.4)]),
			_wave(150, [_spawn(&"dingsha_tu", 10, 5, 2.1), _spawn(&"dingsha_huo", 10, 5, 2.1)]),
			_wave(150, [_spawn(&"xiangliu", 1, 10), _spawn(&"dingsha_shui", 12, 15, 2.3), _spawn(&"dingsha_huo", 10, 15, 2.3)]),
		]),
	]
