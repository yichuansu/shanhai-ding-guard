class_name KeeperUnlocks
extends RefCounted
## 守鼎人解锁条件。条件写在 KeeperDef 上：
##   unlock_kind = ""          一开始就能用
##   unlock_kind = "bestiary"  图鉴收录满 unlock_value 只
##   unlock_kind = "defeat"    击败过首领 unlock_param


static func is_unlocked(keeper: KeeperDef, lib: ContentLibrary, profile: Profile) -> bool:
	match keeper.unlock_kind:
		&"bestiary":
			return Bestiary.progress(lib, profile).x >= keeper.unlock_value
		&"defeat":
			return profile.defeat_count(keeper.unlock_param) > 0
	return true


## 解锁进度，例如"图鉴收录 5/8"。已解锁或无条件时返回空。
static func progress_text(keeper: KeeperDef, lib: ContentLibrary, profile: Profile) -> String:
	if is_unlocked(keeper, lib, profile):
		return ""
	match keeper.unlock_kind:
		&"bestiary":
			return "图鉴收录 %d/%d" % [Bestiary.progress(lib, profile).x, keeper.unlock_value]
		&"defeat":
			return "击败%s" % RunRules.beast_name(lib, keeper.unlock_param)
	return ""


static func unlocked_ids(lib: ContentLibrary, profile: Profile) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in lib.keeper_ids():
		if is_unlocked(lib.keepers[id], lib, profile):
			out.append(id)
	return out
