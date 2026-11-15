class_name ContentLibrary
extends RefCounted
## 读取 res://content 下的全部内容 Resource，并做引用校验。纯数据，不依赖场景树。

const DEFAULT_ROOT := "res://content"

var beasts: Dictionary = {}
var relics: Dictionary = {}
var battles: Dictionary = {}
var chart: ElementChart
var errors: PackedStringArray = PackedStringArray()


static func load_from(root: String = DEFAULT_ROOT) -> ContentLibrary:
	var lib := ContentLibrary.new()
	lib._load_dir(root + "/beasts", lib.beasts)
	lib._load_dir(root + "/relics", lib.relics)
	lib._load_dir(root + "/battles", lib.battles)
	var chart_path := root + "/element_chart.tres"
	if ResourceLoader.exists(chart_path):
		lib.chart = load(chart_path) as ElementChart
	if lib.chart == null:
		lib.errors.append("缺少 element_chart.tres")
		lib.chart = ElementChart.new()
	lib._validate()
	return lib


func battles_of_kind(kind: BattleDef.Kind) -> Array[BattleDef]:
	var out: Array[BattleDef] = []
	var ids := battles.keys()
	ids.sort()
	for id: StringName in ids:
		var b: BattleDef = battles[id]
		if b.kind == kind:
			out.append(b)
	return out


func _load_dir(path: String, into: Dictionary) -> void:
	if not DirAccess.dir_exists_absolute(path):
		errors.append("目录不存在: " + path)
		return
	for file in ResourceLoader.list_directory(path):
		if not (file.ends_with(".tres") or file.ends_with(".res")):
			continue
		var res := load(path + "/" + file)
		var raw_id: Variant = res.get("id") if res != null else null
		var id: StringName = StringName(raw_id) if raw_id != null else &""
		if id == &"":
			errors.append("缺少 id: %s/%s" % [path, file])
			continue
		if into.has(id):
			errors.append("重复 id: " + String(id))
			continue
		into[id] = res


func _validate() -> void:
	for id: StringName in beasts:
		var b: BeastDef = beasts[id]
		if not Elements.is_valid(b.element):
			errors.append("%s 五行无效: %s" % [id, b.element])
		if b.attack_interval_ticks < 1:
			errors.append("%s attack_interval_ticks 必须 ≥ 1" % id)
	for id: StringName in battles:
		var battle: BattleDef = battles[id]
		if battle.path_points.size() < 2:
			errors.append("%s 路径点少于 2 个" % id)
		if battle.waves.is_empty():
			errors.append("%s 没有波次" % id)
		for wave in battle.waves:
			for spawn in wave.spawns:
				if not beasts.has(spawn.beast_id):
					errors.append("%s 引用了不存在的异兽 %s" % [id, spawn.beast_id])
				if spawn.count < 1:
					errors.append("%s 出怪数量必须 ≥ 1" % id)
