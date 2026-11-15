class_name ElementChart
extends Resource
## 五行倍率表。关系固定在 Elements 里，这里只放可调的数字。

@export var advantage_multiplier: float = 1.5
@export var disadvantage_multiplier: float = 0.7
## 相邻且"生"我的异兽，给我的伤害加成。
@export var generate_bonus: float = 0.2


func multiplier(attacker: StringName, defender: StringName) -> float:
	if Elements.overcomes(attacker, defender):
		return advantage_multiplier
	if Elements.overcomes(defender, attacker):
		return disadvantage_multiplier
	return 1.0
