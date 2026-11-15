class_name SaveStore
extends RefCounted
## 本地 JSON 存档。先写临时文件再替换，替换期间保留 .bak，读不到主文件时回退到 .bak。
## 云存档以后实现同一组函数的远端版本，玩法代码不感知差别。


static func save_json(path: String, data: Dictionary) -> Error:
	var tmp := path + ".tmp"
	var bak := path + ".bak"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
		var err := DirAccess.rename_absolute(path, bak)
		if err != OK:
			return err
	var result := DirAccess.rename_absolute(tmp, path)
	if result == OK and FileAccess.file_exists(bak):
		DirAccess.remove_absolute(bak)
	return result


static func load_json(path: String) -> Dictionary:
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(candidate))
		if parsed is Dictionary:
			return parsed
	return {}


static func delete(path: String) -> void:
	for candidate in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(candidate)
