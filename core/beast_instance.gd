class_name BeastInstance
extends RefCounted
## 阵容里的一只异兽：引用 BeastDef，加上本局内的阶位。

const MAX_TIER := 3

var uid := 0
var beast_id: StringName
var tier := 1


static func make(uid_in: int, beast_id_in: StringName, tier_in: int = 1) -> BeastInstance:
	var b := BeastInstance.new()
	b.uid = uid_in
	b.beast_id = beast_id_in
	b.tier = clampi(tier_in, 1, MAX_TIER)
	return b


func to_dict() -> Dictionary:
	return {"uid": uid, "beast_id": String(beast_id), "tier": tier}


static func from_dict(d: Dictionary) -> BeastInstance:
	return make(int(d.get("uid", 0)), StringName(str(d.get("beast_id", ""))), int(d.get("tier", 1)))
