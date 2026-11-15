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
	for dir in ["beasts", "relics", "battles", "keepers", "formations"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/%s" % [OUT, dir]))
	_save(ElementChart.new(), "element_chart.tres")
	for b in _beasts():
		_save(b, "beasts/%s.tres" % b.id)
	for r in _relics():
		_save(r, "relics/%s.tres" % r.id)
	for battle in _battles():
		_save(battle, "battles/%s.tres" % battle.id)
	for k in _keepers():
		_save(k, "keepers/%s.tres" % k.id)
	for f in _formations():
		_save(f, "formations/%s.tres" % f.element)
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
		_beast(&"xiangliu", "相柳", "Xiangliu, the Nine-Headed Serpent", Elements.SHUI, R.AREA, Q.BOSS,
			"共工之臣曰相柳氏，九首，以食于九山……禹杀相柳，其血腥，不可以树五谷种。",
			[30000, 42.0, 10, 15, 15], [0, 0, 0.0, 10, 600.0]),
		_beast(&"dingsha_tu", "鼎煞（土）", "Cauldron Wraith (Earth)", Elements.TU, R.RANGED, Q.MINION,
			"九鼎崩裂时溢出的浊气。", [340, 105.0, 1, 1, 0], [0, 0, 0.0, 10, 600.0]),
		_beast(&"dingsha_shui", "鼎煞（水）", "Cauldron Wraith (Water)", Elements.SHUI, R.RANGED, Q.MINION,
			"九鼎崩裂时溢出的浊气。", [280, 125.0, 1, 1, 0], [0, 0, 0.0, 10, 600.0]),
		_beast(&"dingsha_huo", "鼎煞（火）", "Cauldron Wraith (Fire)", Elements.HUO, R.RANGED, Q.MINION,
			"九鼎崩裂时溢出的浊气。", [360, 115.0, 1, 1, 0], [0, 0, 0.0, 10, 600.0]),
	]


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
			_skill("射日", "一箭射中场上生命最高的敌人。", &"smite_strongest", 9, 200, 1800.0, 0.0)),
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


func _relics() -> Array[RelicDef]:
	var hetu := RelicDef.new()
	hetu.id = &"hetu"
	hetu.display_name = "河图"
	hetu.description = "每场战斗额外获得 1 张临时镇鼎符。"
	hetu.effects = [_effect(&"on_battle_start", &"add_talismans", 1)]
	var luoshu := RelicDef.new()
	luoshu.id = &"luoshu"
	luoshu.display_name = "洛书"
	luoshu.description = "所有异兽伤害 +10%。"
	luoshu.effects = [_effect(&"passive", &"global_damage_pct", 0.1)]
	return [hetu, luoshu]


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
		_battle(&"jizhou_boss", "冀州 · 相柳", K.BOSS, [
			_wave(80, [_spawn(&"dingsha_shui", 12, 7)]),
			_wave(150, [_spawn(&"dingsha_tu", 12, 6, 1.4), _spawn(&"fuzhu", 1, 6)]),
			_wave(150, [_spawn(&"dingsha_huo", 12, 6, 1.7), _spawn(&"bifang", 1, 6)]),
			_wave(150, [_spawn(&"dingsha_shui", 14, 5, 1.8), _spawn(&"huashe", 1, 5, 1.4)]),
			_wave(150, [_spawn(&"dingsha_tu", 10, 5, 2.1), _spawn(&"dingsha_huo", 10, 5, 2.1)]),
			_wave(150, [_spawn(&"xiangliu", 1, 10), _spawn(&"dingsha_shui", 12, 15, 2.3), _spawn(&"dingsha_huo", 10, 15, 2.3)]),
		]),
	]
