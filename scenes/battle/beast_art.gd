class_name BeastArt
extends RefCounted
## 按命名约定找美术资源，没有就返回 null（表现层退回灰盒色块）：
##   异兽：res://art/beasts/<beast_id>/body.png   朝右画，脚底贴图片底边
##   道具：res://art/props/<name>.png             例如 ding.png
## 图片规格见 docs/ART_SPEC.md。

## 战斗中的显示高度（1080p 像素），按稀有度分档。
const HEIGHT_BY_RARITY := {
	BeastDef.Rarity.MINION: 70.0,
	BeastDef.Rarity.COMMON: 110.0,
	BeastDef.Rarity.ELITE: 140.0,
	BeastDef.Rarity.BOSS: 200.0,
	BeastDef.Rarity.RARE: 125.0,
}

static var _cache: Dictionary = {}


static func beast_texture(beast_id: StringName) -> Texture2D:
	return _load("res://art/beasts/%s/body.png" % beast_id)


static func prop_texture(prop: String) -> Texture2D:
	return _load("res://art/props/%s.png" % prop)


static func display_height(def: BeastDef) -> float:
	return HEIGHT_BY_RARITY.get(def.rarity, 110.0)


static func has_art(beast_id: StringName) -> bool:
	return beast_texture(beast_id) != null


static func _load(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]
