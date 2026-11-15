extends Node
## 全局内容库。玩法逻辑通过参数拿 ContentLibrary，只有场景层直接用这个单例。

var lib: ContentLibrary


func _ready() -> void:
	lib = ContentLibrary.load_from()
	for e in lib.errors:
		push_error("内容错误: " + e)
