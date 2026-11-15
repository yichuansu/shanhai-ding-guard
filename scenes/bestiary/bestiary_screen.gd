extends Control
## 山海经图鉴：左边按栏目列出异兽卡片，右边显示选中异兽的原文、数值和特性。
## 未遇见只显示"？？？"；遇见未收服显示名字和五行；收录后显示全部。

const PAPER := Color("efe9dc")
const INK := Color("1c2421")
const MUTED := Color("59655f")
const BRONZE := Color("9c6a27")
const ACCENT := Color("1f5a4e")
const LOCKED := Color("b3ada1")
const CARD_SIZE := Vector2(196, 220)
const ROLES := ["远击", "范围", "镇守", "祥瑞"]
const RARITIES := ["杂兵", "普通", "精英", "首领", "稀有"]

var _section := "jizhou"
var _selected: StringName = &""
var _title: Label
var _tabs: HBoxContainer
var _grid: HFlowContainer
var _detail: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = PAPER
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 60
	root.offset_right = -60
	root.offset_top = 36
	root.offset_bottom = -36
	root.add_theme_constant_override("separation", 20)
	add_child(root)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 24)
	root.add_child(top)
	var back := Button.new()
	back.text = "返回"
	back.custom_minimum_size = Vector2(140, 60)
	back.pressed.connect(Game.goto_map)
	top.add_child(back)
	_title = _label(40, INK)
	top.add_child(_title)

	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 12)
	root.add_child(_tabs)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 28)
	root.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_grid = HFlowContainer.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(_grid)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)
	body.add_child(panel)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(detail_scroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 14)
	detail_scroll.add_child(_detail)
	_refresh()


func _refresh() -> void:
	var lib := Content.lib
	var profile := Game.profile
	var total := Bestiary.progress(lib, profile)
	_title.text = "山海经图鉴　收录 %d / %d" % [total.x, total.y]
	_clear(_tabs)
	for s: Dictionary in Bestiary.SECTIONS:
		var p := Bestiary.progress(lib, profile, s["id"])
		var tab := Button.new()
		tab.toggle_mode = true
		tab.button_pressed = s["id"] == _section
		tab.text = "%s %d/%d" % [s["title"], p.x, p.y]
		tab.custom_minimum_size = Vector2(240, 56)
		tab.pressed.connect(_on_tab.bind(s["id"]))
		_tabs.add_child(tab)
	_clear(_grid)
	var ids := Bestiary.section_ids(lib, _section)
	if _selected == &"" or not ids.has(_selected):
		_selected = ids[0] if not ids.is_empty() else &""
	for id in ids:
		_grid.add_child(_card(id))
	_show_detail(_selected)


func _on_tab(section: String) -> void:
	_section = section
	_selected = &""
	_refresh()


func _on_card(id: StringName) -> void:
	_selected = id
	_refresh()


func _card(id: StringName) -> Button:
	var def: BeastDef = Content.lib.beasts[id]
	var state := Bestiary.state_of(Content.lib, Game.profile, id)
	var b := Button.new()
	b.custom_minimum_size = CARD_SIZE
	b.clip_text = true
	var col: Color = Elements.COLORS.get(def.element, Color.GRAY)
	var tag := ""
	match state:
		Bestiary.State.UNKNOWN:
			b.text = "？\n\n？？？\n尚未遇见"
			col = LOCKED
		Bestiary.State.SEEN:
			b.text = "%s\n\n%s\n%s" % [Elements.DISPLAY[def.element], def.display_name, "尚未击败" if def.rarity == BeastDef.Rarity.BOSS else "尚未收服"]
			col = col.lerp(LOCKED, 0.65)
		Bestiary.State.COLLECTED:
			tag = "收服 ×%d" % Game.profile.capture_count(id) if Game.profile.capture_count(id) > 0 else "已获得"
			b.text = "%s\n\n%s\n%s" % [def.display_name.left(1), def.display_name, tag]
		Bestiary.State.DEFEATED:
			b.text = "%s\n\n%s\n击败 ×%d" % [def.display_name.left(1), def.display_name, Game.profile.defeat_count(id)]
	var text_col := INK if col.get_luminance() > 0.55 else Color("f5f1e8")
	for s in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = col if s != "hover" else col.lightened(0.08)
		box.set_corner_radius_all(8)
		if id == _selected:
			box.border_color = BRONZE
			box.set_border_width_all(5)
		b.add_theme_stylebox_override(s, box)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, text_col)
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(_on_card.bind(id))
	return b


func _show_detail(id: StringName) -> void:
	_clear(_detail)
	if id == &"":
		return
	var lib := Content.lib
	var def: BeastDef = lib.beasts[id]
	var state := Bestiary.state_of(lib, Game.profile, id)
	var known := Bestiary.is_complete(state)
	var section_hint := ""
	for s: Dictionary in Bestiary.SECTIONS:
		if s["id"] == _section:
			section_hint = s["hint"]
	if state == Bestiary.State.UNKNOWN:
		_detail.add_child(_label(52, MUTED, "？？？"))
		_detail.add_child(_wrap(26, MUTED, "尚未遇见。" + section_hint + "。"))
		_add_recipe_hint(id)
		return
	_detail.add_child(_label(52, INK, def.display_name))
	if known:
		_detail.add_child(_label(22, MUTED, def.name_en))
	_detail.add_child(_label(26, ACCENT, "%s · %s · %s" % [Elements.DISPLAY[def.element], ROLES[def.role], RARITIES[def.rarity]]))
	if not known:
		_detail.add_child(_wrap(26, MUTED, ("尚未击败。" if def.rarity == BeastDef.Rarity.BOSS else "尚未收服。") + section_hint + "。收录后可读原文。"))
		_add_recipe_hint(id)
		return
	_detail.add_child(_wrap(28, BRONZE, "「%s」" % def.lore))
	if def.rarity != BeastDef.Rarity.BOSS:
		_detail.add_child(_label(24, INK, "作为守鼎异兽"))
		_detail.add_child(_wrap(22, MUTED, "灵气 %d · 伤害 %d · 每 %.1f 秒 · 射程 %d%s" % [def.deploy_cost, def.damage,
			def.attack_interval_ticks / BattleSim.TICKS_PER_SECOND, int(def.attack_range),
			" · 暴击 %d%%" % roundi(def.crit_chance * 100.0) if def.crit_chance > 0.0 else ""]))
		if def.guard_hp > 0:
			_detail.add_child(_wrap(22, MUTED, "镇守：生命 %d，同时挡 %d 只" % [def.guard_hp, def.block_count]))
		for t in def.traits:
			_detail.add_child(_wrap(22, ACCENT, "· " + t.description))
	if def.rarity != BeastDef.Rarity.RARE:
		_detail.add_child(_label(24, INK, "作为敌人"))
		_detail.add_child(_wrap(22, MUTED, "生命 %d · 速度 %d · 漏到鼎前扣 %d%s" % [def.max_hp, int(def.move_speed), def.leak_damage,
			" · 可捕获" if def.capturable else ""]))
		for ab in def.abilities:
			_detail.add_child(_wrap(22, Color("8e24aa"), "· " + ab.description))
	_add_recipe_hint(id)
	var record := ""
	match state:
		Bestiary.State.COLLECTED:
			var n := Game.profile.capture_count(id)
			record = "亲手收服 %d 次" % n if n > 0 else "通过奖励、集市、炼鼎或奇遇获得"
		Bestiary.State.DEFEATED:
			record = "击败 %d 次" % Game.profile.defeat_count(id)
	_detail.add_child(_label(22, MUTED, record))


func _add_recipe_hint(id: StringName) -> void:
	var hint := Bestiary.recipe_hint(Content.lib, Game.profile, id)
	if hint != "":
		_detail.add_child(_wrap(24, BRONZE, hint))


func _label(size: int, color: Color, text: String = "") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _wrap(size: int, color: Color, text: String) -> Label:
	var l := _label(size, color, text)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(700, 0)
	return l


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
