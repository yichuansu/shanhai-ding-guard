extends Node
## 启动：有进行中的一局就回路线图，否则去选守鼎人。


func _ready() -> void:
	if Game.has_active_run():
		Game.goto_map.call_deferred()
	else:
		Game.goto_start.call_deferred()
