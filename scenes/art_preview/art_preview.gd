extends Node2D
## 美术预览：不进战斗也能看每只异兽的图和动作。左边选异兽，下边切动作。
## 左大图看细节，右边是战斗中的实际尺寸，放在路面上对比。没有美术的显示灰盒色块。

const PAPER := Color("efe9dc")
const PATH_COLOR := Color("cdbd96")
const BIG := 420.0

var _selected: StringName = &""
var _big := BeastSprite.new()
var _small := BeastSprite.new()
var _info: Label
var _list: VBoxContainer
var _moving := false


func _ready() -> void:
	add_child(_big)
	add_child(_small)
	_big.position = Vector2(820, 860)
	_small.position = Vector2(1500, 760)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var ui := Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = get_tree().root.theme
	canvas.add_child(ui)
	var back := Button.new()
	back.text = "返回"
	back.position = Vector2(30, 24)
	back.custom_minimum_size = Vector2(140, 56)
	back.pressed.connect(Game.goto_start)
	ui.add_child(back)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(30, 100)
	scroll.size = Vector2(330, 940)
	ui.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	for id in _ordered_ids():
		var def: BeastDef = Content.lib.beasts[id]
		var b := Button.new()
		b.text = ("✓ " if BeastArt.has_art(id) else "　 ") + def.display_name
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(300, 50)
		b.pressed.connect(_select.bind(id))
		_list.add_child(b)
	var actions := HBoxContainer.new()
	actions.position = Vector2(420, 980)
	actions.add_theme_constant_override("separation", 12)
	ui.add_child(actions)
	for pair in [["待机", _idle], ["行走", _move], ["攻击", _attack], ["受击", _hit], ["死亡", _die], ["转身", _turn]]:
		var b := Button.new()
		b.text = pair[0]
		b.custom_minimum_size = Vector2(130, 56)
		b.pressed.connect(pair[1])
		actions.add_child(b)
	_info = Label.new()
	_info.position = Vector2(420, 24)
	_info.size = Vector2(1460, 200)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_font_size_override("font_size", 22)
	_info.add_theme_color_override("font_color", Color("1c2421"))
	ui.add_child(_info)
	var ids := _ordered_ids()
	_select(ids[0] if not ids.is_empty() else &"")


func _ordered_ids() -> Array[StringName]:
	var with_art: Array[StringName] = []
	var without: Array[StringName] = []
	for s in Bestiary.sections():
		for id in Bestiary.section_ids(Content.lib, s["id"]):
			(with_art if BeastArt.has_art(id) else without).append(id)
	return with_art + without


func _select(id: StringName) -> void:
	_selected = id
	var def: BeastDef = Content.lib.beasts.get(id)
	if def == null:
		return
	var tex := BeastArt.beast_texture(id)
	for s in [_big, _small]:
		s.visible = tex != null
	if tex != null:
		_big.setup(tex, BIG)
		_small.setup(tex, BeastArt.display_height(def))
	var status := "已有美术：res://art/beasts/%s/body.png" % id if tex != null else "还没有美术（战斗中显示色块）。把处理好的图放到 res://art/beasts/%s/body.png" % id
	_info.text = "%s　%s · %s\n%s\n战斗显示高度 %d 像素" % [def.display_name, Elements.DISPLAY[def.element], def.name_en, status, int(BeastArt.display_height(def))]
	_idle()
	queue_redraw()


func _idle() -> void:
	_set_moving(false)


func _move() -> void:
	_set_moving(true)


func _set_moving(on: bool) -> void:
	_moving = on
	_big.moving = on
	_small.moving = on
	_big.reset()
	_small.reset()


func _attack() -> void:
	for s in [_big, _small]:
		s.attack(Vector2(s.facing, -0.2))


func _hit() -> void:
	_big.hit()
	_small.hit()


func _die() -> void:
	_big.die()
	_small.die()


func _turn() -> void:
	_big.facing = -_big.facing
	_small.facing = -_small.facing


func _draw() -> void:
	draw_rect(Rect2(Vector2(-200, -200), Vector2(2400, 1500)), PAPER)
	draw_line(Vector2(420, 862), Vector2(1220, 862), Color(0.35, 0.33, 0.28, 0.4), 3.0)
	draw_polyline(PackedVector2Array([Vector2(1260, 760), Vector2(1740, 760)]), PATH_COLOR, 56.0)
	var def: BeastDef = Content.lib.beasts.get(_selected)
	if def != null and not BeastArt.has_art(_selected):
		var col: Color = Elements.COLORS.get(def.element, Color.GRAY)
		draw_circle(Vector2(820, 700), 160, col)
		draw_circle(Vector2(1500, 735), 26, col)
