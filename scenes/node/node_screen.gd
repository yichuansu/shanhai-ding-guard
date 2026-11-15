extends Control
## 非战斗节点的通用界面：战后奖励、集市、炼鼎、奇遇、祭祀。
## 规则都在 RunRules 里，这里只负责摆按钮、显示结果、存档。
## 阵容已满又要加入新异兽时，先进入"选择放生"状态，选完再执行原来的操作。

const PAPER := Color("efe9dc")
const INK := Color("1c2421")
const MUTED := Color("59655f")
const ACCENT := Color("1f5a4e")
const BRONZE := Color("9c6a27")

var _mode := ""
var _header: Label
var _title: Label
var _body: VBoxContainer
var _message: Label
var _footer: HBoxContainer
## 等待选择放生对象的操作：Callable(release_uid: int) -> String
var _pending_release: Callable
var _event_result := ""


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
	root.add_theme_constant_override("separation", 22)
	add_child(root)
	_header = _label(24, MUTED)
	root.add_child(_header)
	_title = _label(44, INK)
	root.add_child(_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 18)
	scroll.add_child(_body)
	_message = _label(26, ACCENT)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_message)
	_footer = HBoxContainer.new()
	_footer.add_theme_constant_override("separation", 16)
	root.add_child(_footer)
	_mode = Game.node_mode()
	if _mode == "":
		Game.goto_map.call_deferred()
		return
	_refresh()


func _refresh() -> void:
	var run := Game.run
	var names: PackedStringArray = []
	for b in run.roster:
		names.append(_beast_label(b))
	_header.text = "鼎 %d/%d · 贝币 %d · 镇鼎符 %d · 法宝 %d · 阵容（%d/%d）：%s" % [
		run.ding_hp, run.ding_max, run.shells, run.talismans, run.relic_ids.size(),
		run.roster.size(), run.roster_cap, "、".join(names)]
	_clear(_body)
	_clear(_footer)
	if _pending_release.is_valid():
		_build_release_picker()
		return
	match _mode:
		"reward":
			_build_reward()
		"shop":
			_build_shop()
		"forge":
			_build_forge()
		"event":
			_build_event()
		"rest":
			_build_rest()


# ---------- 奖励 ----------

func _build_reward() -> void:
	var reward := Game.run.pending_reward
	if reward.is_empty():
		_title.text = "战利品"
		_footer.add_child(_button("返回路线图", _leave, 280))
		return
	var is_relic: bool = reward["kind"] == "relic"
	_title.text = "战利品：选一件法宝" if is_relic else "战利品：选一只异兽加入阵容"
	var row := _row()
	var options: Array = reward["options"]
	for i in options.size():
		var id := StringName(options[i])
		var text := _relic_card(id) if is_relic else _beast_card(id)
		row.add_child(_card(text, _on_pick_reward.bind(i)))
	_footer.add_child(_button("跳过（+%d 贝币）" % int(reward["skip_shells"]), _on_skip_reward, 320))


func _on_pick_reward(index: int) -> void:
	var reward := Game.run.pending_reward
	if reward["kind"] == "beast" and Game.run.is_roster_full():
		_ask_release(func(uid: int) -> String: return RunRules.pick_reward(Game.run, Content.lib, index, uid))
		return
	_done(RunRules.pick_reward(Game.run, Content.lib, index))


func _on_skip_reward() -> void:
	_done(RunRules.skip_reward(Game.run))


# ---------- 集市 ----------

func _build_shop() -> void:
	_title.text = "集市"
	var node_id := Game.run.current_node
	var offers := RunRules.shop_offers(Game.run, Content.lib, node_id, Game.unlocked_beasts())
	var beasts := _row()
	var goods := _row()
	for i in offers.size():
		var o := offers[i]
		var sold: bool = o["kind"] in ["beast", "relic"] and RunRules.is_sold(Game.run, node_id, i)
		var text := ""
		match o["kind"]:
			"beast":
				text = _beast_card(StringName(o["id"]))
			"relic":
				text = _relic_card(StringName(o["id"]))
			"talismans":
				text = "镇鼎符 ×%d\n\n捕获异兽用" % int(o["amount"])
			"repair":
				text = "修鼎\n\n铜鼎耐久 +%d" % int(o["amount"])
		text += "\n\n%s" % ("已售出" if sold else "%d 贝币" % int(o["price"]))
		var card := _card(text, _on_buy.bind(i))
		card.disabled = sold or Game.run.shells < int(o["price"]) or (o["kind"] == "repair" and Game.run.ding_hp >= Game.run.ding_max)
		(beasts if o["kind"] == "beast" else goods).add_child(card)
	_body.add_child(_label(24, MUTED, "放生（免费）：点下面的异兽把它放归山林，腾出阵容位置"))
	var release_row := _row()
	for b in Game.run.roster:
		var btn := _button("放生 " + _beast_label(b), _on_release.bind(b.uid), 200)
		btn.disabled = Game.run.roster.size() <= 1
		release_row.add_child(btn)
	_footer.add_child(_button("离开集市", _leave, 280))


func _on_buy(index: int) -> void:
	var node_id := Game.run.current_node
	var offers := RunRules.shop_offers(Game.run, Content.lib, node_id, Game.unlocked_beasts())
	if offers[index]["kind"] == "beast" and Game.run.is_roster_full():
		_ask_release(func(uid: int) -> String: return RunRules.buy(Game.run, Content.lib, node_id, index, Game.unlocked_beasts(), uid))
		return
	_show(RunRules.buy(Game.run, Content.lib, node_id, index, Game.unlocked_beasts()))


func _on_release(uid: int) -> void:
	_show(RunRules.release(Game.run, Content.lib, uid))


# ---------- 炼鼎 ----------

func _build_forge() -> void:
	_title.text = "炼鼎"
	if Game.run.node_resolved:
		_body.add_child(_label(28, INK, "鼎火已熄。"))
		_footer.add_child(_button("返回路线图", _leave, 280))
		return
	_body.add_child(_label(24, MUTED, "只能炼一次：把两只同种同阶的异兽合成高一阶，或者按五行相生配方融合出稀有异兽。"))
	var merges := RunRules.merge_candidates(Game.run)
	var fusions := RunRules.fusion_candidates(Game.run, Content.lib)
	var row := _row()
	for pair in merges:
		var a := Game.run.instance_by_uid(pair[0])
		var text := "升阶\n\n%s ×2\n→ %s ★%d" % [_name(a.beast_id), _name(a.beast_id), a.tier + 1]
		row.add_child(_card(text, _on_merge.bind(pair[0], pair[1])))
	for f in fusions:
		var recipe: FusionRecipe = f["recipe"]
		var text := "融合\n\n%s + %s\n→ %s\n\n%s" % [_name(recipe.a), _name(recipe.b), _name(recipe.result), recipe.description]
		row.add_child(_card(text, _on_fuse.bind(recipe.id)))
	if merges.is_empty() and fusions.is_empty():
		_body.add_child(_label(26, INK, "阵容里没有能合成的组合。"))
	_body.add_child(_label(24, MUTED, "全部配方："))
	for recipe in Content.lib.fusion_list():
		_body.add_child(_label(22, MUTED, "· %s + %s → %s　%s" % [_name(recipe.a), _name(recipe.b), _name(recipe.result), recipe.description]))
	_footer.add_child(_button("不炼了，离开", _leave, 280))


func _on_merge(a: int, b: int) -> void:
	_show(RunRules.merge(Game.run, Content.lib, a, b))


func _on_fuse(recipe_id: StringName) -> void:
	_show(RunRules.fuse(Game.run, Content.lib, recipe_id))


# ---------- 奇遇 ----------

func _build_event() -> void:
	var ev := RunRules.event_for_node(Game.run, Content.lib, Game.run.current_node)
	if ev == null:
		_title.text = "奇遇"
		_footer.add_child(_button("返回路线图", _leave, 280))
		return
	_title.text = "奇遇 · " + ev.title
	var source := _label(28, BRONZE, "「%s」" % ev.source_text)
	source.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(source)
	var situation := _label(26, INK, ev.situation)
	situation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(situation)
	if Game.run.node_resolved:
		if _event_result != "":
			_body.add_child(_label(28, ACCENT, _event_result))
		_footer.add_child(_button("返回路线图", _leave, 280))
		return
	for i in ev.options.size():
		var opt := ev.options[i]
		var btn := _button("%s　（%s）" % [opt.label, opt.hint], _on_event_option.bind(i), 1000)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.disabled = Game.run.shells < opt.cost_shells
		_body.add_child(btn)


func _on_event_option(index: int) -> void:
	_event_result = RunRules.resolve_event(Game.run, Content.lib, Game.run.current_node, index)
	_show("")


# ---------- 祭祀 ----------

func _build_rest() -> void:
	_title.text = "祭祀"
	if Game.run.node_resolved:
		_body.add_child(_label(28, INK, "祭礼已毕。"))
		_footer.add_child(_button("返回路线图", _leave, 280))
		return
	_body.add_child(_label(24, MUTED, "在两种祭礼中选一种。"))
	var row := _row()
	row.add_child(_card("祭地修鼎\n\n铜鼎耐久 +%d" % RunRules.REST_HEAL, func() -> void: _show(RunRules.rest_heal(Game.run))))
	row.add_child(_card("祭天加固\n\n铜鼎耐久上限 +%d" % RunRules.REST_FORTIFY, func() -> void: _show(RunRules.rest_fortify(Game.run))))


# ---------- 放生选择 ----------

func _ask_release(action: Callable) -> void:
	_pending_release = action
	_message.text = RunRules.ROSTER_FULL
	_refresh()


func _build_release_picker() -> void:
	_title.text = "阵容已满：选一只放生"
	var row := _row()
	for b in Game.run.roster:
		var def: BeastDef = Content.lib.beasts.get(b.beast_id)
		row.add_child(_card("%s\n%s · %s" % [_beast_label(b), Elements.DISPLAY[def.element], _role(def)], _on_release_picked.bind(b.uid)))
	_footer.add_child(_button("取消", func() -> void:
		_pending_release = Callable()
		_message.text = ""
		_refresh(), 200))


func _on_release_picked(uid: int) -> void:
	var action := _pending_release
	_pending_release = Callable()
	var released := _beast_label(Game.run.instance_by_uid(uid))
	var result: String = action.call(uid)
	if _mode == "reward" and Game.run.pending_reward.is_empty():
		_done("放生 %s；%s" % [released, result])
	else:
		_show("放生 %s；%s" % [released, result])


# ---------- 公共 ----------

func _show(text: String) -> void:
	if text != "":
		_message.text = text
	Game.last_report = text if text != "" else _event_result
	Game.save()
	_refresh()


## 奖励领完直接回路线图。
func _done(text: String) -> void:
	if text == RunRules.ROSTER_FULL:
		_show(text)
		return
	Game.last_report = text
	Game.save()
	Game.goto_map()


func _leave() -> void:
	Game.save()
	Game.goto_map()


func _beast_card(id: StringName) -> String:
	var def: BeastDef = Content.lib.beasts.get(id)
	if def == null:
		return String(id)
	var lines := PackedStringArray([
		def.display_name,
		"%s · %s · 灵气 %d" % [Elements.DISPLAY[def.element], _role(def), def.deploy_cost],
		"伤害 %d · 每 %.1f 秒 · 射程 %d" % [def.damage, def.attack_interval_ticks / BattleSim.TICKS_PER_SECOND, int(def.attack_range)],
	])
	if def.guard_hp > 0:
		lines.append("镇守：生命 %d，同时挡 %d 只" % [def.guard_hp, def.block_count])
	for t in def.traits:
		lines.append(t.description)
	return "\n".join(lines)


func _relic_card(id: StringName) -> String:
	var r: RelicDef = Content.lib.relics.get(id)
	return String(id) if r == null else "%s\n\n%s" % [r.display_name, r.description]


func _role(def: BeastDef) -> String:
	return ["远击", "范围", "镇守", "祥瑞"][def.role]


func _name(id: StringName) -> String:
	return RunRules.beast_name(Content.lib, id)


func _beast_label(b: BeastInstance) -> String:
	return "%s%s" % [_name(b.beast_id), "" if b.tier == 1 else "★%d" % b.tier]


func _row() -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 18)
	row.add_theme_constant_override("v_separation", 18)
	_body.add_child(row)
	return row


func _card(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(400, 230)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.pressed.connect(callback)
	return b


func _button(text: String, callback: Callable, width: int = 200) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 60)
	b.pressed.connect(callback)
	return b


func _label(size: int, color: Color, text: String = "") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
