class_name Ascension
extends RefCounted
## 鼎劫：通关后逐级解锁的难度。每级在前一级基础上加一条规则（参考 Slay the Spire 的进阶）。
## 每位守鼎人各自记录：在第 N 级通关，就为这位守鼎人解锁第 N+1 级。

const MAX_LEVEL := 10

## 第 i 项是第 i+1 级新增的规则。
const LEVEL_TEXT := [
	"敌人血量 +10%",
	"每场开局灵气 -3",
	"铜鼎耐久上限 -2",
	"敌人移速 +10%",
	"集市价格 +25%",
	"每场最多用 2 张镇鼎符",
	"首领血量 +15%",
	"战后奖励只给两个选项",
	"敌人血量再 +10%",
	"祭祀修鼎减半",
]


## 某一级的全部修正（含之前各级）。
static func mods(level: int) -> Dictionary:
	var lv := clampi(level, 0, MAX_LEVEL)
	return {
		"hp_mult": 1.0 + (0.1 if lv >= 1 else 0.0) + (0.1 if lv >= 9 else 0.0),
		"spirit_delta": -3 if lv >= 2 else 0,
		"ding_max_delta": -2 if lv >= 3 else 0,
		"speed_mult": 1.1 if lv >= 4 else 1.0,
		"shop_price_mult": 1.25 if lv >= 5 else 1.0,
		"capture_limit": 2 if lv >= 6 else 3,
		"boss_hp_mult": 1.15 if lv >= 7 else 1.0,
		"reward_choices": 2 if lv >= 8 else 3,
		"rest_heal_mult": 0.5 if lv >= 10 else 1.0,
	}


## 到这一级为止生效的规则列表。
static func rules_up_to(level: int) -> PackedStringArray:
	var out := PackedStringArray()
	for i in clampi(level, 0, MAX_LEVEL):
		out.append("%d. %s" % [i + 1, LEVEL_TEXT[i]])
	return out
