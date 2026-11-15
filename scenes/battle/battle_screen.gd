extends Node2D
## 守鼎战控制器：驱动 SimClock → BattleSim，把点击翻译成意图，刷新 HUD，按事件播音效和震屏。
## 操作：
##   点下方阵容选中异兽 → 点空鼎位部署（悬停鼎位可预览射程）
##   点已部署的异兽 → 右下角弹出升级 / 收回
##   点带"可收"金圈的敌人 → 消耗镇鼎符捕获
##   点技能按钮 → 再点战场释放（金色圈是范围，右键取消）
##   右上角倒计时期间可"提前召唤"下一波，剩余时间越多奖励灵气越多

const SLOT_PICK_RADIUS := 56.0
const ENEMY_PICK_PADDING := 24.0
const SHAKE_DECAY := 6.0

var sim: BattleSim
var clock := SimClock.new()
var selected_uid := -1
var selected_slot := -1

@onready var view: BattleView = $View
@onready var camera: Camera2D = $Camera

var _status: Label
var _roster_bar: HBoxContainer
var _speed_button: Button
var _pause_button: Button
var _skill_button: Button
var _formation_label: Label
var _wave_label: Label
var _call_button: Button
var _tower_panel: PanelContainer
var _tower_title: Label
var _upgrade_button: Button
var _recall_button: Button
var _result_panel: PanelContainer
var _result_label: Label
var _skill_aiming := false
var _finished := false
var _shake := 0.0
var _roster_dirty := true


func _ready() -> void:
	var node_id := Game.pending_node_id
	if node_id < 0:
		Game.goto_map.call_deferred()
		return
	var def := Game.battle_def_for_node(node_id)
	sim = BattleSim.create(def, Content.lib.beasts, Content.lib.chart, Game.make_battle_setup(node_id))
	if sim.error != "":
		push_error(sim.error)
		Game.goto_map.call_deferred()
		return
	clock.speed = Game.profile.sim_speed
	view.sim = sim
	view.clock = clock
	_build_hud(def)
	sim.begin()
	_refresh_hud()


func _process(delta: float) -> void:
	if sim == null:
		return
	_shake = maxf(_shake - delta * SHAKE_DECAY, 0.0)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 18.0 * _shake * _shake
	if _finished:
		return
	var ticks := clock.advance(delta)
	for i in ticks:
		sim.step()
		view.on_events(sim.events)
		_react(sim.events)
		if not sim.is_running():
			break
	_refresh_hud()
	if not sim.is_running():
		_show_result()


func _react(events: Array[Dictionary]) -> void:
	for ev in events:
		match ev["type"]:
			"hit":
				Sfx.play("crit" if bool(ev.get("crit", false)) else "hit")
			"killed":
				Sfx.play("kill")
			"captured":
				Sfx.play("capture")
				_shake = maxf(_shake, 0.4)
			"leaked":
				Sfx.play("leak")
				_shake = 1.0
			"deployed", "recalled":
				Sfx.play("deploy")
				_roster_dirty = true
			"upgraded":
				Sfx.play("upgrade")
			"skill":
				Sfx.play("skill")
				_shake = maxf(_shake, 0.5)
			"wave_called":
				Sfx.play("wave")
			"guard_broken":
				_shake = maxf(_shake, 0.3)
			"towers_stunned":
				Sfx.play("skill")
				_shake = maxf(_shake, 0.4)
			"spirit_drained":
				Sfx.play("skill")
			"summoned":
				Sfx.play("leak")
				_shake = maxf(_shake, 0.7)
			"spawned":
				pass


func _unhandled_input(event: InputEvent) -> void:
	if sim == null or _finished:
		return
	if event is InputEventMouseMotion:
		var p := get_global_mouse_position()
		if _skill_aiming:
			view.aim_position = p
		view.hover_slot = _slot_at(p)
		return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		_set_aiming(false)
		_select_slot(-1)
		_select(-1)
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var pos := get_global_mouse_position()
	if _skill_aiming:
		sim.queue_skill(pos)
		_set_aiming(false)
		get_viewport().set_input_as_handled()
		return
	for e in sim.enemies:
		if not sim.can_capture(e):
			continue
		var center := sim.enemy_position(e)
		var reach := 22.0 + ENEMY_PICK_PADDING + (20.0 if e.def.rarity >= BeastDef.Rarity.ELITE else 0.0)
		if BeastArt.has_art(e.def.id):
			# 有美术时点在身体上，而不是脚底
			var h := BeastArt.display_height(e.def)
			center += Vector2(0, -h * 0.45)
			reach = h * 0.5 + ENEMY_PICK_PADDING
		if center.distance_to(pos) <= reach:
			sim.queue_capture(e.id)
			get_viewport().set_input_as_handled()
			return
	var slot := _slot_at(pos)
	if slot >= 0:
		if sim.towers.has(slot):
			_select(-1)
			_select_slot(-1 if slot == selected_slot else slot)
		elif selected_uid >= 0:
			sim.queue_deploy(selected_uid, slot)
			_select(-1)
		get_viewport().set_input_as_handled()
		return
	_select_slot(-1)


func _slot_at(pos: Vector2) -> int:
	for i in sim.battle.slots.size():
		if sim.battle.slots[i].distance_to(pos) <= SLOT_PICK_RADIUS:
			return i
	return -1


func _build_hud(def: BattleDef) -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	# CanvasLayer 会切断主题继承，所以在下面包一层全屏 Control 显式挂上界面主题。
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.theme = get_tree().root.theme
	canvas.add_child(layer)
	var top := HBoxContainer.new()
	top.position = Vector2(40, 24)
	top.add_theme_constant_override("separation", 20)
	layer.add_child(top)
	_status = _label(26, Color("1c2421"))
	top.add_child(_status)
	_pause_button = _button("暂停", _toggle_pause)
	top.add_child(_pause_button)
	_speed_button = _button("", _toggle_speed)
	top.add_child(_speed_button)
	if sim.keeper != null and sim.keeper.skill != null:
		_skill_button = _button("", _on_skill_pressed)
		_skill_button.custom_minimum_size = Vector2(260, 56)
		_skill_button.tooltip_text = sim.keeper.skill.description
		top.add_child(_skill_button)
	var title := _label(22, Color("59655f"))
	title.text = def.display_name
	top.add_child(title)

	_formation_label = _label(22, Color("1f5a4e"))
	_formation_label.position = Vector2(40, 92)
	layer.add_child(_formation_label)

	var wave_box := VBoxContainer.new()
	wave_box.position = Vector2(40, 140)
	wave_box.custom_minimum_size = Vector2(340, 0)
	wave_box.add_theme_constant_override("separation", 8)
	layer.add_child(wave_box)
	_wave_label = _label(22, Color("1c2421"))
	_wave_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wave_label.custom_minimum_size = Vector2(340, 0)
	wave_box.add_child(_wave_label)
	_call_button = _button("", _on_call_pressed)
	_call_button.custom_minimum_size = Vector2(320, 56)
	wave_box.add_child(_call_button)

	_roster_bar = HBoxContainer.new()
	_roster_bar.position = Vector2(40, 960)
	_roster_bar.add_theme_constant_override("separation", 12)
	layer.add_child(_roster_bar)

	_tower_panel = PanelContainer.new()
	_tower_panel.position = Vector2(1460, 300)
	_tower_panel.custom_minimum_size = Vector2(400, 0)
	_tower_panel.visible = false
	layer.add_child(_tower_panel)
	var tbox := VBoxContainer.new()
	tbox.add_theme_constant_override("separation", 10)
	_tower_panel.add_child(tbox)
	_tower_title = _label(24, Color("1c2421"))
	tbox.add_child(_tower_title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	tbox.add_child(row)
	_upgrade_button = _button("", _on_upgrade_pressed)
	_upgrade_button.custom_minimum_size = Vector2(220, 56)
	row.add_child(_upgrade_button)
	_recall_button = _button("", _on_recall_pressed)
	_recall_button.custom_minimum_size = Vector2(140, 56)
	row.add_child(_recall_button)

	_result_panel = PanelContainer.new()
	_result_panel.position = Vector2(660, 400)
	_result_panel.custom_minimum_size = Vector2(600, 240)
	_result_panel.visible = false
	layer.add_child(_result_panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 20)
	_result_panel.add_child(box)
	_result_label = _label(40, Color("1c2421"))
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_result_label)
	box.add_child(_button("继续", _leave))


func _rebuild_roster() -> void:
	_roster_dirty = false
	for child in _roster_bar.get_children():
		child.queue_free()
	for inst in sim.roster:
		var def := sim.beast_def(inst.beast_id)
		var b := Button.new()
		b.toggle_mode = true
		b.button_pressed = inst.uid == selected_uid
		b.custom_minimum_size = Vector2(176, 84)
		var tag := "·镇守" if def.guard_hp > 0 else ""
		b.text = "%s·%s%s%s\n灵气 %d" % [def.display_name, Elements.DISPLAY[def.element], tag, "" if inst.tier == 1 else " ★%d" % inst.tier, def.deploy_cost]
		var lines: PackedStringArray = ["伤害 %d · 每 %.1f 秒 · 射程 %d" % [def.damage, def.attack_interval_ticks / BattleSim.TICKS_PER_SECOND, int(def.attack_range)]]
		for t in def.traits:
			lines.append(t.description)
		b.tooltip_text = "\n".join(lines)
		b.disabled = sim.is_deployed(inst.uid)
		b.pressed.connect(_select.bind(inst.uid))
		_roster_bar.add_child(b)


func _select(uid: int) -> void:
	selected_uid = -1 if uid == selected_uid else uid
	view.selected_uid = selected_uid
	if selected_uid >= 0:
		_select_slot(-1)
	_roster_dirty = true


func _select_slot(slot: int) -> void:
	selected_slot = slot
	view.selected_slot = slot


func _refresh_hud() -> void:
	if _roster_dirty:
		_rebuild_roster()
	_status.text = "鼎 %d/%d   灵气 %d   镇鼎符 %d   第 %d/%d 波   已收服 %d" % [
		maxi(sim.ding_hp, 0), sim.ding_max, sim.spirit, sim.talismans,
		sim.current_wave_number(), sim.wave_count(), sim.captured_beasts.size()]
	_speed_button.text = "%d 倍速" % int(clock.speed)
	_pause_button.text = "继续" if clock.paused else "暂停"
	if _skill_button != null:
		var skill := sim.keeper.skill
		if _skill_aiming:
			_skill_button.text = "选择位置（右键取消）"
		elif sim.skill_cooldown > 0:
			_skill_button.text = "%s %.1f 秒" % [skill.display_name, sim.skill_cooldown / BattleSim.TICKS_PER_SECOND]
		else:
			_skill_button.text = "%s（灵气 %d）" % [skill.display_name, skill.spirit_cost]
		_skill_button.disabled = not sim.skill_ready() and not _skill_aiming
	var parts: PackedStringArray = []
	for f in Content.lib.formation_list():
		if sim.active_formations.has(f.element):
			parts.append("%s阵·%s（%d）" % [Elements.DISPLAY[f.element], f.display_name, sim.active_formations[f.element]])
	_formation_label.text = "五行阵：" + ("、".join(parts) if not parts.is_empty() else "未成阵（同五行 2 只成阵）")
	_refresh_wave_panel()
	_refresh_tower_panel()


func _refresh_wave_panel() -> void:
	var preview := sim.next_wave_preview()
	var gap := sim.wave_gap_remaining()
	if preview.is_empty():
		_wave_label.text = "最后一波了，守住！"
		_call_button.visible = false
		return
	var names: PackedStringArray = []
	for id: StringName in preview:
		var def := sim.beast_def(id)
		names.append("%s×%d" % [def.display_name if def else String(id), preview[id]])
	if gap > 0:
		_wave_label.text = "第 %d 波 %.0f 秒后到来：%s" % [sim.current_wave_number(), ceilf(gap / BattleSim.TICKS_PER_SECOND), "、".join(names)]
		_call_button.visible = true
		var bonus := sim.early_call_bonus()
		_call_button.text = "提前召唤  +%d 灵气" % bonus if bonus > 0 else "立即召唤"
	else:
		_wave_label.text = "第 %d 波来袭：%s" % [sim.current_wave_number(), "、".join(names)]
		_call_button.visible = false


func _refresh_tower_panel() -> void:
	if selected_slot < 0 or not sim.towers.has(selected_slot):
		_tower_panel.visible = false
		if selected_slot >= 0:
			_select_slot(-1)
		return
	var t: TowerUnit = sim.towers[selected_slot]
	_tower_panel.visible = true
	_tower_title.text = "%s · Lv.%d · 伤害 %d · 射程 %d" % [t.def.display_name, t.level,
		int(t.def.damage * BattleSim.LEVEL_DAMAGE_MULT[t.level] * BattleSim.TIER_DAMAGE_MULT[t.instance.tier]), int(sim.tower_range(t))]
	var cost := sim.upgrade_cost(selected_slot)
	if cost < 0:
		_upgrade_button.text = "已满级"
		_upgrade_button.disabled = true
	else:
		_upgrade_button.text = "升到 Lv.%d（灵气 %d）" % [t.level + 1, cost]
		_upgrade_button.disabled = sim.spirit < cost
	_recall_button.text = "收回 +%d" % sim.recall_refund(selected_slot)


func _show_result() -> void:
	_finished = true
	var won := sim.outcome == BattleSim.Outcome.WON
	_result_label.text = "守住了！" if won else "鼎破了……"
	_result_panel.visible = true
	_tower_panel.visible = false
	Sfx.play("victory" if won else "defeat")
	Game.finish_battle(sim)


func _on_skill_pressed() -> void:
	if sim.keeper.skill.op == &"smite_strongest":
		sim.queue_skill(Vector2.ZERO)
		return
	_set_aiming(not _skill_aiming)


func _on_call_pressed() -> void:
	sim.queue_call_wave()


func _on_upgrade_pressed() -> void:
	if selected_slot >= 0:
		sim.queue_upgrade(selected_slot)


func _on_recall_pressed() -> void:
	if selected_slot >= 0:
		sim.queue_recall(selected_slot)
		_select_slot(-1)


func _set_aiming(on: bool) -> void:
	_skill_aiming = on
	view.skill_aim = on
	view.aim_position = get_global_mouse_position()


func _toggle_pause() -> void:
	clock.paused = not clock.paused


func _toggle_speed() -> void:
	clock.speed = 2.0 if clock.speed < 2.0 else 1.0
	Game.profile.sim_speed = clock.speed


func _leave() -> void:
	Game.after_battle()


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(120, 56)
	b.pressed.connect(callback)
	return b
