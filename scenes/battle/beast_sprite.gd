class_name BeastSprite
extends Node2D
## 一只异兽的精灵：单张图 + 程序动作（参考皮影戏的简洁动作）。
## 原点是脚底中心；图朝右画，朝左时水平翻转。
## 动作：待机呼吸、行走颠簸、攻击前冲、受击闪白抖动、死亡倒下淡出。

signal finished_dying

const SHADER := preload("res://art/shaders/beast_flash.gdshader")
const TINT_FROZEN := Color(0.56, 0.79, 0.98, 0.45)
const TINT_STUNNED := Color(0.42, 0.11, 0.6, 0.5)

var facing := 1.0
var moving := false
var height := 110.0

var _sprite := Sprite2D.new()
var _mat := ShaderMaterial.new()
var _time := 0.0
var _attack_t := 1.0
var _attack_dir := Vector2.RIGHT
var _hit_t := 1.0
var _dying := false
var _die_t := 0.0
var _level_scale := 1.0


func _init() -> void:
	_mat.shader = SHADER
	_sprite.material = _mat
	_sprite.centered = false
	add_child(_sprite)


func setup(texture: Texture2D, display_height: float) -> void:
	_sprite.texture = texture
	height = display_height
	_sprite.offset = Vector2(-texture.get_width() / 2.0, -texture.get_height())
	reset()


func reset() -> void:
	_time = randf() * 10.0
	_attack_t = 1.0
	_hit_t = 1.0
	_dying = false
	_die_t = 0.0
	_level_scale = 1.0
	modulate = Color.WHITE
	visible = true
	set_tint(Color(1, 1, 1, 0))
	_mat.set_shader_parameter("flash", 0.0)


func set_level(level: int) -> void:
	_level_scale = 1.0 + 0.07 * (level - 1)


func set_tint(tint: Color) -> void:
	_mat.set_shader_parameter("tint", tint)


func attack(direction: Vector2) -> void:
	_attack_t = 0.0
	if direction.length() > 0.1:
		_attack_dir = direction.normalized()
		facing = 1.0 if direction.x >= 0.0 else -1.0


func hit() -> void:
	_hit_t = 0.0


func die() -> void:
	_dying = true
	_die_t = 0.0


func _process(delta: float) -> void:
	if _sprite.texture == null:
		return
	_time += delta
	_attack_t = minf(_attack_t + delta, 1.0)
	_hit_t = minf(_hit_t + delta, 1.0)
	var base := height / _sprite.texture.get_height() * _level_scale
	var sx := 1.0
	var sy := 1.0
	var offset := Vector2.ZERO
	var rot := 0.0
	if moving and not _dying:
		var step := absf(sin(_time * 7.0))
		offset.y -= step * height * 0.06
		rot = sin(_time * 7.0) * 0.05
		sy = 1.0 - (1.0 - step) * 0.04
	else:
		sy = 1.0 + sin(_time * 2.4) * 0.025
		sx = 1.0 - sin(_time * 2.4) * 0.012
	if _attack_t < 0.25:
		# 先后坐蓄力，再前冲，再回位
		var k := _attack_t / 0.25
		var lunge := sin(k * PI) * (1.0 if k > 0.25 else -0.4)
		offset += _attack_dir * lunge * height * 0.16
		sx *= 1.0 + 0.12 * sin(k * PI)
		sy *= 1.0 - 0.08 * sin(k * PI)
	if _hit_t < 0.18:
		var k := 1.0 - _hit_t / 0.18
		offset.x += sin(_hit_t * 90.0) * 4.0 * k
		_mat.set_shader_parameter("flash", k * 0.85)
	else:
		_mat.set_shader_parameter("flash", 0.0)
	if _dying:
		_die_t += delta
		var k := clampf(_die_t / 0.45, 0.0, 1.0)
		rot = facing * k * 1.2
		offset.y += k * height * 0.15
		modulate.a = 1.0 - k
		if k >= 1.0:
			_dying = false
			visible = false
			finished_dying.emit()
	_sprite.position = offset
	_sprite.rotation = rot
	_sprite.scale = Vector2(base * sx * facing, base * sy)
	queue_redraw()


func _draw() -> void:
	if _sprite.texture == null:
		return
	# 脚下的影子
	var w := height * 0.42 * _level_scale
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, w, Color(0, 0, 0, 0.18 * modulate.a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
