extends Node
## 启动：读档后进入路线图。没有进行中的一局就开新局。


func _ready() -> void:
	if not Game.has_active_run():
		Game.start_new_run()
	Game.goto_map.call_deferred()
