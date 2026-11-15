extends SceneTree
## 无头测试入口：
##   godot --headless --path godot --import
##   godot --headless --path godot --script res://tests/run_tests.gd
## 发现 res://tests/test_*.gd 里所有 test_ 开头的方法并逐个运行。有失败则退出码为 1。


func _initialize() -> void:
	var files := Array(DirAccess.get_files_at("res://tests"))
	files.sort()
	var total := 0
	var failed := 0
	for file: String in files:
		if not (file.begins_with("test_") and file.ends_with(".gd")) or file == "test_case.gd":
			continue
		var script: GDScript = load("res://tests/" + file)
		if script == null or not script.can_instantiate():
			total += 1
			failed += 1
			print("  FAIL ", file, " 无法加载（语法错误？）")
			continue
		for method: Dictionary in script.get_script_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			var inst: TestCase = script.new()
			inst.current = "%s::%s" % [file.get_basename(), name]
			inst.call(name)
			total += 1
			if inst.failures.is_empty():
				print("  ok   ", inst.current)
			else:
				failed += 1
				print("  FAIL ", inst.current)
				for f in inst.failures:
					print("       ", f)
	print("\n%d 个测试，%d 个失败。" % [total, failed])
	quit(1 if failed > 0 else 0)
