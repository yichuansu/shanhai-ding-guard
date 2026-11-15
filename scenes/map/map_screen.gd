extends Control
## 灰盒路线图：每层一列按钮，节点之间画连线，只有可前往的节点能点。正式版换成卷轴式地图。

const LINE_FAINT := Color(0.35, 0.33, 0.28, 0.25)
const LINE_TAKEN := Color("1f5a4e")
const LINE_OPEN := Color("c9a25a")

var _header: Label
var _report: Label
var _columns: HBoxContainer
var _lines: Control
## node_id -> Button
var _buttons: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("efe9dc")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 60
	root.offset_right = -60
	root.offset_top = 40
	root.offset_bottom = -40
	root.add_theme_constant_override("separation", 24)
	add_child(root)
	_header = _label(30)
	root.add_child(_header)
	var area := Control.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(area)
	_lines = Control.new()
	_lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines.draw.connect(_draw_lines)
	area.add_child(_lines)
	_columns = HBoxContainer.new()
	_columns.set_anchors_preset(Control.PRESET_FULL_RECT)
	_columns.add_theme_constant_override("separation", 60)
	area.add_child(_columns)
	area.resized.connect(_lines.queue_redraw)
	_report = _label(22)
	_report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_report)
	var keepers := HBoxContainer.new()
	keepers.add_theme_constant_override("separation", 16)
	root.add_child(keepers)
	var progress := Bestiary.progress(Content.lib, Game.profile)
	var bestiary := Button.new()
	bestiary.text = "山海经图鉴 %d/%d" % [progress.x, progress.y]
	bestiary.custom_minimum_size = Vector2(280, 64)
	bestiary.pressed.connect(Game.goto_bestiary)
	keepers.add_child(bestiary)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(40, 0)
	keepers.add_child(gap)
	var hint := _label(22)
	hint.text = "开新局，选择守鼎人："
	keepers.add_child(hint)
	for id in Content.lib.keeper_ids():
		var k: KeeperDef = Content.lib.keepers[id]
		var b := Button.new()
		b.text = "%s · %s" % [k.display_name, k.skill.display_name if k.skill else ""]
		b.tooltip_text = "%s\n技能：%s" % [k.description, k.skill.description if k.skill else ""]
		b.custom_minimum_size = Vector2(220, 64)
		b.pressed.connect(_on_new_run.bind(id))
		keepers.add_child(b)
	if not Game.run.pending_reward.is_empty():
		Game.after_battle.call_deferred()
		return
	_refresh()


func _refresh() -> void:
	var run := Game.run
	var names: PackedStringArray = []
	for b in run.roster:
		var def: BeastDef = Content.lib.beasts.get(b.beast_id)
		var label := def.display_name if def else String(b.beast_id)
		names.append("%s%s" % [label, "" if b.tier == 1 else "★%d" % b.tier])
	var keeper: KeeperDef = Content.lib.keepers.get(run.keeper_id)
	_header.text = ("%s · " % keeper.display_name if keeper else "") + "冀州 · 鼎 %d/%d · 贝币 %d · 镇鼎符 %d · 法宝 %d · 阵容（%d/%d）：%s" % [
		run.ding_hp, run.ding_max, run.shells, run.talismans, run.relic_ids.size(),
		run.roster.size(), run.roster_cap, "、".join(names)]
	var status := ""
	if run.finished:
		status = "本局胜利！" if run.won else "本局失败。"
		status += " 点下方按钮开新局。"
	_report.text = "%s %s" % [Game.last_report, status]
	for child in _columns.get_children():
		_columns.remove_child(child)
		child.queue_free()
	_buttons.clear()
	var available := run.available_nodes()
	for layer in run.map.layers:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 18)
		_columns.add_child(col)
		for id in layer:
			var node := run.map.nodes[id]
			var b := Button.new()
			var mark := "✓ " if run.visited.has(id) else ""
			b.text = mark + MapNode.DISPLAY[node.type]
			b.custom_minimum_size = Vector2(150, 72)
			b.disabled = not available.has(id)
			b.pressed.connect(_on_node.bind(id))
			col.add_child(b)
			_buttons[id] = b
	_lines.queue_redraw.call_deferred()


func _draw_lines() -> void:
	var run := Game.run
	if run == null:
		return
	var origin := _lines.get_global_rect().position
	for n in run.map.nodes:
		var from: Button = _buttons.get(n.id)
		if from == null:
			continue
		for t in n.next:
			var to: Button = _buttons.get(t)
			if to == null:
				continue
			var a := from.get_global_rect()
			var b := to.get_global_rect()
			var p0 := Vector2(a.end.x, a.get_center().y) - origin
			var p1 := Vector2(b.position.x, b.get_center().y) - origin
			var col := LINE_FAINT
			var width := 3.0
			if run.visited.has(n.id) and run.visited.has(t):
				col = LINE_TAKEN
				width = 6.0
			elif n.id == run.current_node and not run.finished:
				col = LINE_OPEN
				width = 5.0
			_lines.draw_line(p0, p1, col, width, true)


func _on_node(id: int) -> void:
	var message := Game.enter_node(id)
	if message != "":
		_refresh()


func _on_new_run(keeper_id: StringName) -> void:
	Game.start_new_run(-1, keeper_id)
	_refresh()


func _label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("1c2421"))
	return l
