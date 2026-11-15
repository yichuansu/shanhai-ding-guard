extends TestCase
## 所有脚本都能编译、所有场景都能加载。场景脚本只在切换场景时才编译，单元测试覆盖不到，靠这里兜底。


func test_all_scripts_compile() -> void:
	for path in _files("res://", ".gd"):
		var script := load(path) as GDScript
		check(script != null and script.can_instantiate(), "%s 编译失败" % path)


func test_all_scenes_load() -> void:
	for path in _files("res://scenes", ".tscn"):
		var scene := load(path) as PackedScene
		check(scene != null and scene.can_instantiate(), "%s 加载失败" % path)


func _files(dir: String, ext: String) -> PackedStringArray:
	var out := PackedStringArray()
	for sub in DirAccess.get_directories_at(dir):
		if sub.begins_with("."):
			continue
		out.append_array(_files(dir.path_join(sub), ext))
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(ext) and not f.begins_with("_"):
			out.append(dir.path_join(f))
	return out
