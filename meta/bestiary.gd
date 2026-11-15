class_name Bestiary
extends RefCounted
## 山海经图鉴的条目与收录进度。纯数据，界面只负责显示。

enum State { UNKNOWN, SEEN, COLLECTED, DEFEATED }

## 栏目：每个州一栏，加上相生炼成和首领。栏目 id 就是州 id。
static func sections() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for region in Regions.ORDER:
		out.append({"id": String(region), "title": "%s异兽" % Regions.display(region),
			"hint": "在%s的战斗中把它们打到捕获线以下，用镇鼎符收服" % Regions.display(region)})
	out.append({"id": "rare", "title": "相生炼成", "hint": "在炼鼎节点按五行相生配方融合得到"})
	out.append({"id": "boss", "title": "首领", "hint": "击败后记入图鉴"})
	return out


## 某一栏的异兽 id（按五行、再按 id 排序）。鼎煞等杂兵不入图鉴。
static func section_ids(lib: ContentLibrary, section: String) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in lib.beasts:
		var b: BeastDef = lib.beasts[id]
		var match_section := false
		match section:
			"rare":
				match_section = b.rarity == BeastDef.Rarity.RARE
			"boss":
				match_section = b.rarity == BeastDef.Rarity.BOSS
			_:
				match_section = String(b.region) == section and (b.rarity == BeastDef.Rarity.COMMON or b.rarity == BeastDef.Rarity.ELITE)
		if match_section:
			out.append(id)
	out.sort_custom(func(a: StringName, c: StringName) -> bool:
		var ea := Elements.ALL.find((lib.beasts[a] as BeastDef).element)
		var ec := Elements.ALL.find((lib.beasts[c] as BeastDef).element)
		return ea < ec or (ea == ec and String(a) < String(c)))
	return out


static func state_of(lib: ContentLibrary, profile: Profile, id: StringName) -> State:
	var def: BeastDef = lib.beasts.get(id)
	if def != null and def.rarity == BeastDef.Rarity.BOSS:
		if profile.defeat_count(id) > 0:
			return State.DEFEATED
		return State.SEEN if profile.has_seen(id) else State.UNKNOWN
	if profile.has_captured(id):
		return State.COLLECTED
	return State.SEEN if profile.has_seen(id) else State.UNKNOWN


static func is_complete(state: State) -> bool:
	return state == State.COLLECTED or state == State.DEFEATED


## [收录数, 总数]
static func progress(lib: ContentLibrary, profile: Profile, section: String = "") -> Vector2i:
	var done := 0
	var total := 0
	for s: Dictionary in sections():
		if section != "" and s["id"] != section:
			continue
		for id in section_ids(lib, s["id"]):
			total += 1
			if is_complete(state_of(lib, profile, id)):
				done += 1
	return Vector2i(done, total)


## 稀有异兽的配方提示：两种原料都收录才显示原料名。没有配方返回空。
static func recipe_hint(lib: ContentLibrary, profile: Profile, id: StringName) -> String:
	for recipe in lib.fusion_list():
		if recipe.result != id:
			continue
		var a_known := profile.has_captured(recipe.a)
		var b_known := profile.has_captured(recipe.b)
		var a_name := RunRules.beast_name(lib, recipe.a) if a_known else "？？？"
		var b_name := RunRules.beast_name(lib, recipe.b) if b_known else "？？？"
		var line := "炼成：%s + %s" % [a_name, b_name]
		if a_known and b_known:
			line += "　" + recipe.description
		return line
	return ""
