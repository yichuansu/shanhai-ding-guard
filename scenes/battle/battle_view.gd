class_name BattleView
extends Node2D
## 灰盒战场绘制：只读 BattleSim，在两拍之间插值。不修改模拟状态。
## 打击反馈（跳字、闪白、击杀爆散、开火后坐、捕获入鼎、漏怪红闪）全在这里，靠 sim.events 驱动。
## 正式美术接入时，用精灵节点替换这里的 _draw，接口不变。

const PAPER := Color("efe9dc")
const PATH_COLOR := Color("cdbd96")
const SLOT_COLOR := Color("8a7f6a")
const DING_COLOR := Color("6d5a3a")
const CAPTURE_COLOR := Color("d4a017")
const TEXT_DARK := Color("1c2421")
const CRIT_COLOR := Color("ffb300")
const SPIRIT_COLOR := Color("1f8f7a")
const FLASH_FRAMES := 6
const RECOIL_TICKS := 2.0
const FONT: Font = preload("res://assets/fonts/NotoSansSC-Subset.ttf")

var sim: BattleSim
var clock: SimClock
var selected_uid := -1
## 选中的已部署鼎位（显示射程和升级面板）。
var selected_slot := -1
## 鼠标悬停的鼎位（选了阵容异兽时预览射程）。
var hover_slot := -1
## 技能瞄准中：跟随鼠标画范围圈。
var skill_aim := false
var aim_position := Vector2.ZERO

var _flashes: Dictionary = {}
## 飘字：{text, position, color, size, life, max_life, rise}
var _popups: Array[Dictionary] = []
## 击杀爆散：{position, color, life, max_life, radius}
var _bursts: Array[Dictionary] = []
## 技能扩散圈：{position, radius, life}
var _rings: Array[Dictionary] = []
## 捕获：{from, life, max_life, color}
var _captures: Array[Dictionary] = []
## 毒涎飞线：{from, to, life, max_life}
var _venoms: Array[Dictionary] = []
var _ding_flash := 0.0
var _time := 0.0


func on_events(events: Array[Dictionary]) -> void:
	for ev in events:
		match ev["type"]:
			"hit":
				_flashes[ev["enemy_id"]] = FLASH_FRAMES
				var dmg := int(round(float(ev["damage"])))
				if bool(ev.get("crit", false)):
					_popup("%d!" % dmg, ev["position"] + Vector2(0, -36), CRIT_COLOR, 40, 0.9, 70.0)
				elif dmg >= 1:
					_popup(str(dmg), ev["position"] + Vector2(randf_range(-14, 14), -28), Color.WHITE, 26, 0.6, 50.0)
			"killed":
				var col: Color = Elements.COLORS.get(ev.get("element", &"none"), Color.GRAY)
				var big := int(ev.get("rarity", 0)) >= BeastDef.Rarity.COMMON
				_bursts.append({"position": ev["position"], "color": col, "life": 0.45, "max_life": 0.45, "radius": 70.0 if big else 44.0})
				if int(ev.get("spirit", 0)) > 0:
					_popup("+%d 灵" % int(ev["spirit"]), ev["position"] + Vector2(0, 10), SPIRIT_COLOR, 22, 0.8, 40.0)
			"captured":
				_captures.append({"from": ev["position"], "life": 0.8, "max_life": 0.8, "color": CAPTURE_COLOR})
				_popup("收服！", ev["position"] + Vector2(0, -50), CAPTURE_COLOR, 44, 1.2, 60.0)
			"leaked":
				_ding_flash = 0.5
				_popup("-%d" % int(ev["damage"]), ev["position"] + Vector2(0, -70), Color("e53935"), 48, 1.0, 50.0)
			"skill":
				_rings.append({"position": ev["position"], "radius": maxf(float(ev["radius"]), 80.0), "life": 0.5})
			"upgraded":
				var t: TowerUnit = sim.towers.get(ev["slot"])
				if t != null:
					_popup("Lv.%d" % int(ev["level"]), t.position + Vector2(0, -60), CAPTURE_COLOR, 34, 1.0, 50.0)
			"wave_called":
				if int(ev["bonus"]) > 0:
					_popup("提前召唤 +%d 灵" % int(ev["bonus"]), sim.path.points[0] + Vector2(-60, 60), SPIRIT_COLOR, 30, 1.4, 40.0)
			"towers_stunned":
				for slot: int in ev["slots"]:
					var st: TowerUnit = sim.towers.get(slot)
					if st != null:
						_venoms.append({"from": ev["position"], "to": st.position, "life": 0.5, "max_life": 0.5})
						_popup("毒涎！", st.position + Vector2(0, -60), Color("8e24aa"), 32, 1.0, 40.0)
			"summoned":
				_popup("九首！召出 %d 只" % int(ev["count"]), ev["position"] + Vector2(0, -80), Color("e53935"), 40, 1.4, 50.0)
				_bursts.append({"position": ev["position"], "color": Color("8e24aa"), "life": 0.6, "max_life": 0.6, "radius": 120.0})
			"guard_broken":
				var g: TowerUnit = sim.towers.get(ev["slot"])
				if g != null:
					_popup("溃！", g.position + Vector2(0, -60), Color("e53935"), 34, 1.0, 40.0)


func _popup(text: String, pos: Vector2, color: Color, size: int, life: float, rise: float) -> void:
	_popups.append({"text": text, "position": pos, "color": color, "size": size, "life": life, "max_life": life, "rise": rise})


func _process(delta: float) -> void:
	_time += delta
	for id: int in _flashes.keys():
		_flashes[id] -= 1
		if _flashes[id] <= 0:
			_flashes.erase(id)
	for list: Array in [_popups, _bursts, _rings, _captures, _venoms]:
		for item: Dictionary in list:
			item["life"] -= delta
	_popups = _popups.filter(func(p: Dictionary) -> bool: return p["life"] > 0.0)
	_bursts = _bursts.filter(func(b: Dictionary) -> bool: return b["life"] > 0.0)
	_rings = _rings.filter(func(r: Dictionary) -> bool: return r["life"] > 0.0)
	_captures = _captures.filter(func(c: Dictionary) -> bool: return c["life"] > 0.0)
	_venoms = _venoms.filter(func(v: Dictionary) -> bool: return v["life"] > 0.0)
	_ding_flash = maxf(_ding_flash - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	var a := clock.alpha() if clock != null else 1.0
	var now := float(sim.tick) + a
	draw_rect(Rect2(Vector2(-600, -400), Vector2(3120, 1880)), PAPER)
	draw_polyline(sim.path.points, PATH_COLOR, 56.0, true)
	_draw_ding()
	_draw_slots()
	_draw_guard_links()
	_draw_towers(now)
	_draw_enemies(a)
	for p in sim.projectiles:
		var col: Color = Elements.COLORS.get(p.element, Color.GRAY)
		var pos := p.prev_position.lerp(p.position, a)
		var dir := (p.position - p.prev_position)
		if dir.length() > 0.1:
			draw_line(pos - dir.normalized() * 22.0, pos, Color(col, 0.45), 6.0 if p.crit else 4.0)
		draw_circle(pos, 11.0 if p.crit else 8.0, CRIT_COLOR if p.crit else col.darkened(0.2))
	_draw_effects()


func _draw_ding() -> void:
	var ding_pos := sim.path.points[sim.path.points.size() - 1]
	var col := DING_COLOR.lerp(Color("e53935"), _ding_flash * 1.6)
	var r := 50.0 + _ding_flash * 20.0
	draw_circle(ding_pos, r, col)
	draw_string(FONT, ding_pos + Vector2(-60, 12), "鼎 %d" % maxi(sim.ding_hp, 0), HORIZONTAL_ALIGNMENT_CENTER, 120, 30, Color.WHITE)


func _draw_slots() -> void:
	for i in sim.battle.slots.size():
		var pos := sim.battle.slots[i]
		var free := not sim.towers.has(i)
		draw_arc(pos, 42.0, 0.0, TAU, 40, SLOT_COLOR, 4.0)
		if selected_uid >= 0 and free:
			var pulse := 0.5 + 0.5 * sin(_time * 6.0)
			draw_arc(pos, 50.0, 0.0, TAU, 40, Color(CAPTURE_COLOR, 0.4 + 0.6 * pulse), 3.0)
	if selected_uid >= 0 and hover_slot >= 0 and not sim.towers.has(hover_slot):
		var inst := sim.instance_by_uid(selected_uid)
		if inst != null:
			var def := sim.beast_def(inst.beast_id)
			_draw_range(sim.battle.slots[hover_slot], def.attack_range, Elements.COLORS.get(def.element, Color.GRAY))
	if selected_slot >= 0 and sim.towers.has(selected_slot):
		var t: TowerUnit = sim.towers[selected_slot]
		_draw_range(t.position, sim.tower_range(t), Elements.COLORS.get(t.def.element, Color.GRAY))


func _draw_range(center: Vector2, radius: float, col: Color) -> void:
	draw_circle(center, radius, Color(col, 0.10))
	draw_arc(center, radius, 0.0, TAU, 64, Color(col, 0.6), 3.0)


func _draw_guard_links() -> void:
	for t: TowerUnit in sim.towers.values():
		if t.is_guard and t.guard_active:
			var block_pos := sim.path.position_at(t.block_distance)
			var guard_col := SLOT_COLOR if t.guard_ready() else Color(0.4, 0.4, 0.4, 0.5)
			draw_dashed_line(t.position, block_pos, guard_col, 3.0, 10.0)
			draw_rect(Rect2(block_pos - Vector2(14, 14), Vector2(28, 28)), guard_col)


func _draw_towers(now: float) -> void:
	for t: TowerUnit in sim.towers.values():
		var col: Color = Elements.COLORS.get(t.def.element, Color.GRAY)
		if t.is_guard and not t.guard_ready() and t.guard_active:
			col = col.darkened(0.5)
		if t.stunned_ticks > 0:
			col = col.lerp(Color("6a1b9a"), 0.6)
		var since := now - float(t.last_fire_tick)
		var recoil := 1.0 + 0.18 * clampf(1.0 - since / RECOIL_TICKS, 0.0, 1.0)
		var half := 34.0 * recoil
		if t.slot == selected_slot:
			draw_rect(Rect2(t.position - Vector2(half + 6, half + 6), Vector2((half + 6) * 2, (half + 6) * 2)), CAPTURE_COLOR, false, 4.0)
		draw_rect(Rect2(t.position - Vector2(half, half), Vector2(half * 2, half * 2)), col)
		draw_string(FONT, t.position + Vector2(-34, 12), t.def.display_name.left(1), HORIZONTAL_ALIGNMENT_CENTER, 68, int(34 * recoil), Color.WHITE)
		# 等级点
		for i in t.level:
			draw_circle(t.position + Vector2(-16 + i * 16, -46), 6.0, CAPTURE_COLOR)
		if t.stunned_ticks > 0:
			draw_arc(t.position, 46.0, 0.0, TAU, 32, Color("8e24aa"), 5.0)
		if t.instance.tier > 1:
			draw_string(FONT, t.position + Vector2(20, -38), "★%d" % t.instance.tier, HORIZONTAL_ALIGNMENT_LEFT, 60, 20, TEXT_DARK)
		if t.is_guard and t.guard_active:
			var gbar := Rect2(t.position + Vector2(-34, 40), Vector2(68, 7))
			draw_rect(gbar, Color(0, 0, 0, 0.35))
			var ratio := 0.0 if t.guard_hp_max <= 0.0 else clampf(t.guard_hp / t.guard_hp_max, 0.0, 1.0)
			draw_rect(Rect2(gbar.position, Vector2(gbar.size.x * ratio, gbar.size.y)), Color("8d6e63"))


func _draw_enemies(a: float) -> void:
	for e in sim.enemies:
		if not e.alive:
			continue
		var pos := sim.path.position_at(lerpf(e.prev_distance, e.distance, a))
		var radius := 44.0 if e.def.rarity == BeastDef.Rarity.BOSS else (30.0 if e.def.rarity == BeastDef.Rarity.ELITE else (26.0 if e.def.rarity == BeastDef.Rarity.COMMON else 18.0))
		var col: Color = Elements.COLORS.get(e.def.element, Color.GRAY)
		if _flashes.has(e.id):
			col = col.lerp(Color.WHITE, 0.7)
			pos += Vector2(randf_range(-3, 3), randf_range(-3, 3))
		draw_circle(pos, radius, col)
		if e.burn_ticks > 0:
			draw_arc(pos, radius + 3.0, 0.0, TAU, 32, Color("ff7043"), 3.0)
		if e.slow_ticks > 0:
			draw_arc(pos, radius + 7.0, 0.0, TAU, 32, Color("4fc3f7"), 2.0)
		if e.def.rarity != BeastDef.Rarity.MINION:
			draw_string(FONT, pos + Vector2(-radius, 9), e.def.display_name.left(1), HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 24, Color.WHITE)
		var bar := Rect2(pos + Vector2(-radius, -radius - 14), Vector2(radius * 2.0, 6))
		draw_rect(bar, Color(0, 0, 0, 0.35))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(e.hp / e.max_hp, 0.0, 1.0), bar.size.y)), Color("4caf50"))
		if e.frozen_ticks > 0:
			draw_arc(pos, radius + 4.0, 0.0, TAU, 40, Color("90caf9"), 5.0)
		if sim.can_capture(e) and sim.talismans > 0:
			var pulse := 0.5 + 0.5 * sin(_time * 8.0)
			draw_arc(pos, radius + 10.0 + pulse * 4.0, 0.0, TAU, 40, CAPTURE_COLOR, 5.0)
			draw_string(FONT, pos + Vector2(-40, -radius - 22), "可收", HORIZONTAL_ALIGNMENT_CENTER, 80, 22, CAPTURE_COLOR)


func _draw_effects() -> void:
	var ding_pos := sim.path.points[sim.path.points.size() - 1]
	for b in _bursts:
		var k: float = 1.0 - b["life"] / b["max_life"]
		var r: float = b["radius"] * (0.4 + k)
		draw_arc(b["position"], r, 0.0, TAU, 32, Color(b["color"], 1.0 - k), 6.0 * (1.0 - k) + 1.0)
		for i in 6:
			var ang := TAU * i / 6.0 + float(b["radius"])
			draw_circle(b["position"] + Vector2.from_angle(ang) * r * 0.9, 6.0 * (1.0 - k), Color(b["color"], 1.0 - k))
	for c in _captures:
		var k: float = 1.0 - c["life"] / c["max_life"]
		var eased: float = k * k
		var pos: Vector2 = c["from"].lerp(ding_pos, eased)
		for i in 5:
			var trail: Vector2 = c["from"].lerp(ding_pos, maxf(eased - i * 0.05, 0.0))
			draw_circle(trail, 14.0 - i * 2.0, Color(0.1, 0.1, 0.1, 0.6 - i * 0.1))
		draw_circle(pos, 18.0, Color(c["color"], 1.0 - k * 0.5))
	for v in _venoms:
		var k: float = 1.0 - v["life"] / v["max_life"]
		var tip: Vector2 = (v["from"] as Vector2).lerp(v["to"], minf(k * 2.0, 1.0))
		draw_line(v["from"], tip, Color(0.56, 0.14, 0.67, 1.0 - k), 8.0 * (1.0 - k) + 2.0)
		draw_circle(tip, 12.0, Color(0.56, 0.14, 0.67, 1.0 - k))
	for r in _rings:
		var k: float = 1.0 - r["life"] / 0.5
		draw_arc(r["position"], r["radius"] * (0.6 + 0.6 * k), 0.0, TAU, 48, Color(1, 0.85, 0.3, 1.0 - k), 10.0 * (1.0 - k) + 2.0)
	if skill_aim and sim.keeper != null and sim.keeper.skill != null and sim.keeper.skill.radius > 0.0:
		draw_circle(aim_position, sim.keeper.skill.radius, Color(1, 0.85, 0.3, 0.15))
		draw_arc(aim_position, sim.keeper.skill.radius, 0.0, TAU, 48, Color(1, 0.85, 0.3, 0.8), 3.0)
	for p in _popups:
		var k: float = 1.0 - p["life"] / p["max_life"]
		var scale_in := 1.0 + 0.6 * clampf(1.0 - k * 6.0, 0.0, 1.0)
		var pos: Vector2 = p["position"] + Vector2(0, -p["rise"] * k)
		var size := int(p["size"] * scale_in)
		var alpha := clampf(p["life"] / (p["max_life"] * 0.4), 0.0, 1.0)
		draw_string_outline(FONT, pos + Vector2(-120, 0), p["text"], HORIZONTAL_ALIGNMENT_CENTER, 240, size, 6, Color(0, 0, 0, 0.55 * alpha))
		draw_string(FONT, pos + Vector2(-120, 0), p["text"], HORIZONTAL_ALIGNMENT_CENTER, 240, size, Color(p["color"], alpha))
