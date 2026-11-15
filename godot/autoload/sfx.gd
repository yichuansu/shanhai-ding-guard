extends Node
## 音效播放：固定数量的播放器轮流用；同一音效有最短间隔，密集命中时不会叠成噪音。
## 音效文件在 res://assets/sfx/<名字>.wav，换成正式音效时替换同名文件即可。

const POOL_SIZE := 16
## 名字 -> [最短间隔秒, 音量 dB, 音高随机幅度]
const SOUNDS := {
	"hit": [0.04, -12.0, 0.15],
	"crit": [0.06, -6.0, 0.1],
	"kill": [0.05, -9.0, 0.15],
	"deploy": [0.05, -4.0, 0.05],
	"upgrade": [0.1, -5.0, 0.0],
	"capture": [0.2, -2.0, 0.0],
	"leak": [0.3, -3.0, 0.05],
	"wave": [0.5, -4.0, 0.0],
	"skill": [0.2, -3.0, 0.0],
	"victory": [1.0, -3.0, 0.0],
	"defeat": [1.0, -3.0, 0.0],
}

var enabled := true
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_played: Dictionary = {}


func _ready() -> void:
	for name: String in SOUNDS:
		var path := "res://assets/sfx/%s.wav" % name
		if ResourceLoader.exists(path):
			_streams[name] = load(path)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func play(name: String) -> void:
	if not enabled or not _streams.has(name):
		return
	var cfg: Array = SOUNDS[name]
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(name, -10.0)) < float(cfg[0]):
		return
	_last_played[name] = now
	var p := _players[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = _streams[name]
	p.volume_db = cfg[1]
	p.pitch_scale = 1.0 + randf_range(-cfg[2], cfg[2])
	p.play()
