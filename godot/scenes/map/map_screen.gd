extends Control
## 灰盒路线图：每层一列按钮，只有可前往的节点能点。正式版换成卷轴式地图。

var _header: Label
var _report: Label
var _columns: HBoxContainer


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
	_columns = HBoxContainer.new()
	_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_columns.add_theme_constant_override("separation", 16)
	root.add_child(_columns)
	_report = _label(22)
	_report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_report)
	var new_run := Button.new()
	new_run.text = "放弃并开新局"
	new_run.custom_minimum_size = Vector2(260, 64)
	new_run.pressed.connect(_on_new_run)
	root.add_child(new_run)
	_refresh()


func _refresh() -> void:
	var run := Game.run
	var names: PackedStringArray = []
	for b in run.roster:
		var def: BeastDef = Content.lib.beasts.get(b.beast_id)
		var label := def.display_name if def else String(b.beast_id)
		names.append("%s%s" % [label, "" if b.tier == 1 else "★%d" % b.tier])
	_header.text = "冀州 · 鼎 %d/%d · 贝币 %d · 镇鼎符 %d · 法宝 %d · 阵容（%d/%d）：%s" % [
		run.ding_hp, run.ding_max, run.shells, run.talismans, run.relic_ids.size(),
		run.roster.size(), run.roster_cap, "、".join(names)]
	var status := ""
	if run.finished:
		status = "本局胜利！" if run.won else "本局失败。"
		status += " 点下方按钮开新局。"
	_report.text = "%s %s" % [Game.last_report, status]
	for child in _columns.get_children():
		child.queue_free()
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


func _on_node(id: int) -> void:
	var message := Game.enter_node(id)
	if message != "":
		_refresh()


func _on_new_run() -> void:
	Game.start_new_run()
	_refresh()


func _label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("1c2421"))
	return l
