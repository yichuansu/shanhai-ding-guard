extends Control
## 开局界面：选守鼎人和鼎劫等级。未解锁的守鼎人显示解锁条件和进度。

const PAPER := Color("efe9dc")
const INK := Color("1c2421")
const MUTED := Color("59655f")
const ACCENT := Color("1f5a4e")
const BRONZE := Color("9c6a27")

var _selected: StringName = &""
var _level := 0
var _cards: HBoxContainer
var _level_label: Label
var _rules: Label
var _start: Button
var _note: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = PAPER
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 80
	root.offset_right = -80
	root.offset_top = 40
	root.offset_bottom = -40
	root.add_theme_constant_override("separation", 24)
	add_child(root)
	var title := _label(48, INK, "选择守鼎人")
	root.add_child(title)
	var stats := _label(22, MUTED, "已开局 %d 次 · 通关 %d 次 · 图鉴收录 %d/%d" % [Game.profile.runs_started, Game.profile.runs_won,
		Bestiary.progress(Content.lib, Game.profile).x, Bestiary.progress(Content.lib, Game.profile).y])
	root.add_child(stats)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 20)
	root.add_child(_cards)

	var asc_row := HBoxContainer.new()
	asc_row.add_theme_constant_override("separation", 16)
	root.add_child(asc_row)
	asc_row.add_child(_label(30, INK, "鼎劫"))
	asc_row.add_child(_button("－", func() -> void: _set_level(_level - 1), 70))
	_level_label = _label(30, BRONZE)
	_level_label.custom_minimum_size = Vector2(320, 0)
	asc_row.add_child(_level_label)
	asc_row.add_child(_button("＋", func() -> void: _set_level(_level + 1), 70))
	_rules = _label(22, MUTED)
	_rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rules.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_rules)

	_note = _label(22, Color("b04f2c"))
	root.add_child(_note)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	root.add_child(bottom)
	_start = _button("开始", _on_start, 260)
	bottom.add_child(_start)
	if Game.has_active_run():
		bottom.add_child(_button("继续当前一局", Game.goto_map, 260))
	bottom.add_child(_button("山海经图鉴", Game.goto_bestiary, 260))
	bottom.add_child(_button("美术预览", Game.goto_art_preview, 260))

	var unlocked := KeeperUnlocks.unlocked_ids(Content.lib, Game.profile)
	_selected = unlocked[0] if not unlocked.is_empty() else &""
	if Game.run != null and unlocked.has(Game.run.keeper_id):
		_selected = Game.run.keeper_id
	_level = Game.profile.max_ascension(_selected)
	_refresh()


func _refresh() -> void:
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	for id in Content.lib.keeper_ids():
		_cards.add_child(_keeper_card(id))
	var max_level := Game.profile.max_ascension(_selected)
	_level = clampi(_level, 0, max_level)
	_level_label.text = "第 %d 级（已解锁到第 %d 级）" % [_level, max_level]
	var rules := Ascension.rules_up_to(_level)
	var next_hint := ""
	if max_level < Ascension.MAX_LEVEL:
		next_hint = "\n用这位守鼎人在第 %d 级通关，解锁第 %d 级：%s" % [max_level, max_level + 1, Ascension.LEVEL_TEXT[max_level]]
	_rules.text = ("本级规则：\n" + "\n".join(rules) if not rules.is_empty() else "第 0 级：没有额外规则。") + next_hint
	var keeper: KeeperDef = Content.lib.keepers.get(_selected)
	_start.disabled = keeper == null or not KeeperUnlocks.is_unlocked(keeper, Content.lib, Game.profile)
	_note.text = "开始新的一局会放弃当前进行中的一局。" if Game.has_active_run() else ""


func _keeper_card(id: StringName) -> Button:
	var k: KeeperDef = Content.lib.keepers[id]
	var unlocked := KeeperUnlocks.is_unlocked(k, Content.lib, Game.profile)
	var lines := PackedStringArray([k.display_name, ""])
	if unlocked:
		lines.append(k.description)
		lines.append("技能 · %s：%s（灵气 %d）" % [k.skill.display_name, k.skill.description, k.skill.spirit_cost])
		for p in k.passives:
			lines.append("被动：" + p.description)
		var names := PackedStringArray()
		for b in k.starting_beasts:
			names.append(RunRules.beast_name(Content.lib, b))
		lines.append("开局：%s · 镇鼎符 %d" % ["、".join(names), k.starting_talismans])
		lines.append("鼎劫最高第 %d 级" % Game.profile.max_ascension(id))
	else:
		lines.append("未解锁")
		lines.append(k.unlock_hint)
		lines.append("进度：" + KeeperUnlocks.progress_text(k, Content.lib, Game.profile))
	var b := Button.new()
	b.text = "\n".join(lines)
	b.custom_minimum_size = Vector2(560, 380)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.toggle_mode = true
	b.button_pressed = id == _selected
	b.disabled = not unlocked
	b.pressed.connect(func() -> void:
		_selected = id
		_level = Game.profile.max_ascension(id)
		_refresh())
	return b


func _set_level(level: int) -> void:
	_level = level
	_refresh()


func _on_start() -> void:
	Game.start_new_run(-1, _selected, _level)
	Game.goto_map()


func _label(size: int, color: Color, text: String = "") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, callback: Callable, width: int = 200) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 60)
	b.pressed.connect(callback)
	return b
