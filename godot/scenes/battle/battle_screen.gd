extends Node2D
## 守鼎战控制器：驱动 SimClock → BattleSim，把点击翻译成意图，刷新 HUD。
## 操作：点下方阵容选中异兽 → 点空鼎位部署；点已部署的鼎位收回（返还一半灵气）；
## 点带"可收"金圈的敌人消耗镇鼎符捕获。

const SLOT_PICK_RADIUS := 56.0
const ENEMY_PICK_PADDING := 24.0

var sim: BattleSim
var clock := SimClock.new()
var selected_uid := -1

@onready var view: BattleView = $View

var _status: Label
var _roster_bar: HBoxContainer
var _speed_button: Button
var _pause_button: Button
var _result_panel: PanelContainer
var _result_label: Label
var _finished := false


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
	if sim == null or _finished:
		return
	var ticks := clock.advance(delta)
	for i in ticks:
		sim.step()
		view.on_events(sim.events)
		if not sim.is_running():
			break
	_refresh_hud()
	if not sim.is_running():
		_show_result()


func _unhandled_input(event: InputEvent) -> void:
	if sim == null or _finished:
		return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var pos := get_global_mouse_position()
	for e in sim.enemies:
		if not e.is_capturable():
			continue
		if sim.enemy_position(e).distance_to(pos) <= 22.0 + ENEMY_PICK_PADDING + (20.0 if e.def.rarity >= BeastDef.Rarity.ELITE else 0.0):
			sim.queue_capture(e.id)
			get_viewport().set_input_as_handled()
			return
	for i in sim.battle.slots.size():
		if sim.battle.slots[i].distance_to(pos) > SLOT_PICK_RADIUS:
			continue
		if sim.towers.has(i):
			sim.queue_recall(i)
		elif selected_uid >= 0:
			sim.queue_deploy(selected_uid, i)
			_select(-1)
		get_viewport().set_input_as_handled()
		return


func _build_hud(def: BattleDef) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var top := HBoxContainer.new()
	top.position = Vector2(40, 24)
	top.add_theme_constant_override("separation", 20)
	layer.add_child(top)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 26)
	_status.add_theme_color_override("font_color", Color("1c2421"))
	top.add_child(_status)
	_pause_button = _button("暂停", _toggle_pause)
	top.add_child(_pause_button)
	_speed_button = _button("", _toggle_speed)
	top.add_child(_speed_button)
	var title := Label.new()
	title.text = def.display_name
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("59655f"))
	top.add_child(title)
	_roster_bar = HBoxContainer.new()
	_roster_bar.position = Vector2(40, 960)
	_roster_bar.add_theme_constant_override("separation", 12)
	layer.add_child(_roster_bar)
	_result_panel = PanelContainer.new()
	_result_panel.position = Vector2(660, 400)
	_result_panel.custom_minimum_size = Vector2(600, 240)
	_result_panel.visible = false
	layer.add_child(_result_panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 20)
	_result_panel.add_child(box)
	_result_label = Label.new()
	_result_label.add_theme_font_size_override("font_size", 36)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_result_label)
	box.add_child(_button("返回路线图", _leave))
	_rebuild_roster()


func _rebuild_roster() -> void:
	for child in _roster_bar.get_children():
		child.queue_free()
	for inst in sim.roster:
		var def := sim.beast_def(inst.beast_id)
		var b := Button.new()
		b.toggle_mode = true
		b.button_pressed = inst.uid == selected_uid
		b.custom_minimum_size = Vector2(170, 80)
		b.text = "%s·%s\n灵气 %d" % [def.display_name, Elements.DISPLAY[def.element], def.deploy_cost]
		b.disabled = sim.is_deployed(inst.uid)
		b.pressed.connect(_select.bind(inst.uid))
		_roster_bar.add_child(b)


func _select(uid: int) -> void:
	selected_uid = -1 if uid == selected_uid else uid
	view.selected_uid = selected_uid
	_rebuild_roster()


func _refresh_hud() -> void:
	_status.text = "鼎 %d/%d   灵气 %d   镇鼎符 %d   第 %d/%d 波   已收服 %d" % [
		sim.ding_hp, sim.ding_max, sim.spirit, sim.talismans,
		sim.current_wave_number(), sim.wave_count(), sim.captured_beasts.size()]
	_speed_button.text = "%d 倍速" % int(clock.speed)
	_pause_button.text = "继续" if clock.paused else "暂停"
	for ev in sim.events:
		if ev["type"] in ["deployed", "recalled"]:
			_rebuild_roster()
			break


func _show_result() -> void:
	_finished = true
	_result_label.text = "守住了！" if sim.outcome == BattleSim.Outcome.WON else "鼎破了……"
	_result_panel.visible = true
	Game.finish_battle(sim)


func _toggle_pause() -> void:
	clock.paused = not clock.paused


func _toggle_speed() -> void:
	clock.speed = 2.0 if clock.speed < 2.0 else 1.0
	Game.profile.sim_speed = clock.speed


func _leave() -> void:
	Game.goto_map()


func _button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(120, 56)
	b.pressed.connect(callback)
	return b
