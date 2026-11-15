class_name BattleView
extends Node2D
## 灰盒战场绘制：只读 BattleSim，在两拍之间插值。不修改模拟状态。
## 正式美术接入时，用精灵节点替换这里的 _draw，接口不变。

const PAPER := Color("efe9dc")
const PATH_COLOR := Color("cdbd96")
const SLOT_COLOR := Color("8a7f6a")
const DING_COLOR := Color("6d5a3a")
const CAPTURE_COLOR := Color("d4a017")
const TEXT_DARK := Color("1c2421")
const FLASH_FRAMES := 6

var sim: BattleSim
var clock: SimClock
var selected_uid := -1
var _flashes: Dictionary = {}


func on_events(events: Array[Dictionary]) -> void:
	for ev in events:
		if ev["type"] == "hit":
			_flashes[ev["enemy_id"]] = FLASH_FRAMES


func _process(_delta: float) -> void:
	for id: int in _flashes.keys():
		_flashes[id] -= 1
		if _flashes[id] <= 0:
			_flashes.erase(id)
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	var font := ThemeDB.fallback_font
	var a := clock.alpha() if clock != null else 1.0
	draw_rect(Rect2(Vector2(-600, -400), Vector2(3120, 1880)), PAPER)
	draw_polyline(sim.path.points, PATH_COLOR, 56.0, true)
	var ding_pos := sim.path.points[sim.path.points.size() - 1]
	draw_circle(ding_pos, 50.0, DING_COLOR)
	draw_string(font, ding_pos + Vector2(-60, 14), "鼎 %d" % sim.ding_hp, HORIZONTAL_ALIGNMENT_CENTER, 120, 30, Color.WHITE)
	for i in sim.battle.slots.size():
		var pos := sim.battle.slots[i]
		draw_arc(pos, 42.0, 0.0, TAU, 40, SLOT_COLOR, 4.0)
		if selected_uid >= 0 and not sim.towers.has(i):
			draw_arc(pos, 50.0, 0.0, TAU, 40, CAPTURE_COLOR, 2.0)
	for t: TowerUnit in sim.towers.values():
		var col: Color = Elements.COLORS.get(t.def.element, Color.GRAY)
		draw_rect(Rect2(t.position - Vector2(34, 34), Vector2(68, 68)), col)
		draw_string(font, t.position + Vector2(-34, 12), t.def.display_name.left(1), HORIZONTAL_ALIGNMENT_CENTER, 68, 34, Color.WHITE)
		if t.instance.tier > 1:
			draw_string(font, t.position + Vector2(-34, -40), "★%d" % t.instance.tier, HORIZONTAL_ALIGNMENT_CENTER, 68, 22, TEXT_DARK)
	for e in sim.enemies:
		if not e.alive:
			continue
		var pos := sim.path.position_at(lerpf(e.prev_distance, e.distance, a))
		var radius := 44.0 if e.def.rarity == BeastDef.Rarity.BOSS else (30.0 if e.def.rarity == BeastDef.Rarity.ELITE else 22.0)
		var col: Color = Elements.COLORS.get(e.def.element, Color.GRAY)
		if _flashes.has(e.id):
			col = col.lightened(0.6)
		draw_circle(pos, radius, col)
		if e.def.rarity != BeastDef.Rarity.MINION:
			draw_string(font, pos + Vector2(-radius, 9), e.def.display_name.left(1), HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 24, Color.WHITE)
		var bar := Rect2(pos + Vector2(-radius, -radius - 14), Vector2(radius * 2.0, 6))
		draw_rect(bar, Color(0, 0, 0, 0.35))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(e.hp / e.max_hp, 0.0, 1.0), bar.size.y)), Color("4caf50"))
		if e.is_capturable() and sim.talismans > 0:
			draw_arc(pos, radius + 10.0, 0.0, TAU, 40, CAPTURE_COLOR, 5.0)
			draw_string(font, pos + Vector2(-40, -radius - 22), "可收", HORIZONTAL_ALIGNMENT_CENTER, 80, 22, CAPTURE_COLOR)
	for p in sim.projectiles:
		var col: Color = Elements.COLORS.get(p.element, Color.GRAY)
		draw_circle(p.prev_position.lerp(p.position, a), 8.0, col.darkened(0.2))
