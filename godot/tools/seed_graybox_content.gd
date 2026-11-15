extends SceneTree
## 生成灰盒内容 .tres。只在初始化或重置灰盒数据时运行，会覆盖 res://content 下的同名文件：
##   godot --headless --path godot --script res://tools/seed_graybox_content.gd
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
	for dir in ["beasts", "relics", "battles"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/%s" % [OUT, dir]))
	_save(ElementChart.new(), "element_chart.tres")
	for b in _beasts():
		_save(b, "beasts/%s.tres" % b.id)
	for r in _relics():
		_save(r, "relics/%s.tres" % r.id)
	for battle in _battles():
		_save(battle, "battles/%s.tres" % battle.id)
	print("灰盒内容已生成。")
	quit()


func _save(res: Resource, rel: String) -> void:
	var err := ResourceSaver.save(res, "%s/%s" % [OUT, rel])
	if err != OK:
		push_error("保存失败 %s: %d" % [rel, err])


func _effect(trigger: StringName, op: StringName, amount: float, duration: int = 0, radius: float = 0.0, desc: String = "") -> EffectDef:
	var e := EffectDef.new()
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


func _beasts() -> Array[BeastDef]:
	var R := BeastDef.Role
	var Q := BeastDef.Rarity
	# enemy: [max_hp, move_speed, leak_damage, spirit_reward, shell_reward]
	# tower: [deploy_cost, damage, attack_range, attack_interval_ticks, projectile_speed]
	return [
		_beast(&"dangkang", "当康", "Dangkang, the Harvest Boar", Elements.TU, R.AUSPICIOUS, Q.COMMON,
			"有兽焉，其状如豚而有牙，其名曰当康，其鸣自叫，见则天下大穰。",
			[110, 95.0, 1, 2, 2], [5, 6, 240.0, 10, 650.0],
			[_effect(&"on_kill_nearby", &"bonus_shells", 1, 0, 300.0, "见则天下大穰：附近敌人被击杀时额外得 1 贝币")]),
		_beast(&"lili", "狸力", "Lili, the Spurred Digger", Elements.TU, R.GUARD, Q.COMMON,
			"有兽焉，其状如豚，有距，其音如狗吠，其名曰狸力，见则其县多土功。",
			[170, 75.0, 1, 2, 2], [6, 15, 170.0, 9, 700.0]),
		_beast(&"bifang", "毕方", "Bifang, the One-Legged Fire Crane", Elements.HUO, R.RANGED, Q.COMMON,
			"有鸟焉，其状如鹤，一足，赤文青质而白喙，名曰毕方，见则其邑有讹火。",
			[90, 120.0, 1, 2, 2], [6, 9, 300.0, 8, 650.0],
			[_effect(&"on_hit", &"burn", 1.5, 20, 0.0, "见则其邑有讹火：命中后灼烧 2 秒")]),
		_beast(&"huashe", "化蛇", "Huashe, the Flood Serpent", Elements.SHUI, R.AREA, Q.COMMON,
			"其中多化蛇，其状如人面而豺身，鸟翼而蛇行，其音如叱呼，见则其邑大水。",
			[120, 100.0, 1, 2, 2], [7, 7, 260.0, 10, 600.0],
			[_effect(&"on_hit", &"slow", 0.6, 15, 0.0, "见则其邑大水：命中后减速 40%，1.5 秒")]),
		_beast(&"wenyao", "文鳐鱼", "Wenyao, the Winged Carp", Elements.SHUI, R.AUSPICIOUS, Q.COMMON,
			"是多文鳐鱼，状如鲤鱼，鱼身而鸟翼，苍文而白首赤喙，见则天下大穰。",
			[80, 130.0, 1, 2, 2], [5, 6, 260.0, 9, 650.0],
			[_effect(&"on_wave_end", &"heal_ding", 1, 0, 0.0, "见则天下大穰：每清一波回复 1 点鼎耐久")]),
		_beast(&"jingwei", "精卫", "Jingwei, the Sea-Filling Bird", Elements.MU, R.RANGED, Q.COMMON,
			"有鸟焉，其状如乌，文首，白喙，赤足，名曰精卫……常衔西山之木石，以堙于东海。",
			[80, 125.0, 1, 2, 2], [5, 10, 320.0, 8, 700.0]),
		_beast(&"mingshe", "鸣蛇", "Mingshe, the Four-Winged Drought Snake", Elements.JIN, R.RANGED, Q.COMMON,
			"其中多鸣蛇，其状如蛇而四翼，其音如磬，见则其邑大旱。",
			[115, 105.0, 1, 2, 2], [7, 12, 280.0, 9, 650.0]),
		_beast(&"zhuyan", "朱厌", "Zhuyan, the War-Omen Ape", Elements.JIN, R.AUSPICIOUS, Q.ELITE,
			"有兽焉，其状如猿，而白首赤足，名曰朱厌，见则大兵。",
			[320, 85.0, 2, 4, 5], [7, 8, 240.0, 9, 650.0],
			[_effect(&"passive", &"adjacent_damage_pct", 0.25, 0, 0.0, "见则大兵：相邻异兽伤害 +25%")]),
		_beast(&"xiangliu", "相柳", "Xiangliu, the Nine-Headed Serpent", Elements.SHUI, R.AREA, Q.BOSS,
			"共工之臣曰相柳氏，九首，以食于九山……禹杀相柳，其血腥，不可以树五谷种。",
			[1600, 42.0, 5, 10, 15], [0, 0, 0.0, 10, 600.0]),
		_beast(&"dingsha_tu", "鼎煞（土）", "Cauldron Wraith (Earth)", Elements.TU, R.RANGED, Q.MINION,
			"九鼎崩裂时溢出的浊气。", [45, 110.0, 1, 1, 0], [0, 0, 0.0, 10, 600.0]),
		_beast(&"dingsha_shui", "鼎煞（水）", "Cauldron Wraith (Water)", Elements.SHUI, R.RANGED, Q.MINION,
			"九鼎崩裂时溢出的浊气。", [40, 125.0, 1, 1, 0], [0, 0, 0.0, 10, 600.0]),
		_beast(&"dingsha_huo", "鼎煞（火）", "Cauldron Wraith (Fire)", Elements.HUO, R.RANGED, Q.MINION,
			"九鼎崩裂时溢出的浊气。", [50, 115.0, 1, 1, 0], [0, 0, 0.0, 10, 600.0]),
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


func _battles() -> Array[BattleDef]:
	var K := BattleDef.Kind
	return [
		_battle(&"jizhou_b01", "冀州 · 田野", K.NORMAL, [
			_wave(20, [_spawn(&"dingsha_tu", 5, 18)]),
			_wave(50, [_spawn(&"dingsha_tu", 4, 16), _spawn(&"dangkang", 1, 16)]),
			_wave(50, [_spawn(&"dingsha_shui", 6, 14), _spawn(&"huashe", 1, 14)]),
		]),
		_battle(&"jizhou_b02", "冀州 · 河滩", K.NORMAL, [
			_wave(20, [_spawn(&"dingsha_shui", 6, 16)]),
			_wave(50, [_spawn(&"dingsha_shui", 4, 14), _spawn(&"wenyao", 1, 14)]),
			_wave(50, [_spawn(&"dingsha_tu", 5, 14), _spawn(&"lili", 1, 14), _spawn(&"mingshe", 1, 14)]),
		]),
		_battle(&"jizhou_b03", "冀州 · 焦土", K.NORMAL, [
			_wave(20, [_spawn(&"dingsha_huo", 5, 16)]),
			_wave(50, [_spawn(&"dingsha_huo", 5, 14), _spawn(&"bifang", 1, 14)]),
			_wave(50, [_spawn(&"dingsha_tu", 6, 12), _spawn(&"jingwei", 1, 12), _spawn(&"dangkang", 1, 12)]),
		]),
		_battle(&"jizhou_elite01", "冀州 · 兵兆", K.ELITE, [
			_wave(20, [_spawn(&"dingsha_tu", 6, 14)]),
			_wave(50, [_spawn(&"dingsha_huo", 5, 12), _spawn(&"zhuyan", 1, 12)]),
			_wave(50, [_spawn(&"dingsha_shui", 8, 10), _spawn(&"mingshe", 2, 20)]),
		]),
		_battle(&"jizhou_boss", "冀州 · 相柳", K.BOSS, [
			_wave(20, [_spawn(&"dingsha_shui", 8, 12)]),
			_wave(40, [_spawn(&"xiangliu", 1, 10), _spawn(&"dingsha_shui", 10, 20)]),
		]),
	]
